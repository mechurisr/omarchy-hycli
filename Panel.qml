import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Hycli control panel.
//
// Everything goes through the hycli CLI, which reads the same private state
// the dashboard does: `status` for the engine, `jobs ls` for work. The
// dashboard's HTTP API is never called. Only opening the dashboard touches
// the launch token, and it keeps that token off every command line.
Panel {
  id: root
  moduleName: "mechurisr.hycli"
  ipcTarget: "mechurisr.hycli"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  // ------------------------------------------------------------ settings

  readonly property string binary: String(setting("binary", "hycli") || "hycli")
  readonly property bool notifyDone: setting("notify", true) !== false

  // ------------------------------------------------------------ state

  property bool engineRunning: false
  property string engineUrl: ""
  property var jobs: []
  property bool loaded: false
  property string lastError: ""
  property string pending: ""       // "start" | "stop" while the CLI works
  property double now: Date.now()
  property var lastStatus: ({})     // job id -> status, for finish notifications

  readonly property var active: jobs.filter(function(j) { return isWorking(j.status) })
  readonly property bool busy: active.length > 0

  readonly property string glyph: "󱗆"
  readonly property string label: busy ? glyph + " " + active.length : glyph

  readonly property var recent: {
    var list = jobs.slice()
    list.sort(function(a, b) { return String(b.updated_at).localeCompare(String(a.updated_at)) })
    return list.slice(0, 8)
  }

  function isWorking(status) {
    return status === "running" || status === "queued"
  }

  // ------------------------------------------------------ panel lifecycle

  function open() { openFromHotkey() }

  function openFromHotkey() {
    root.controller.show()
    refresh()
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.openFromHotkey()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  // ------------------------------------------------------------ commands

  function refresh() {
    if (poll.running) return
    poll.command = ["sh", "-c", '"$0" status; echo; echo "\x1e"; "$0" jobs ls', root.binary]
    poll.running = true
  }

  function applyPoll(text) {
    var parts = String(text || "").split("\x1e")
    try {
      var status = JSON.parse(parts[0])
      engineRunning = status.running === true
      // Newer Hycli builds append the launch token; never show it.
      engineUrl = String(status.url || "").replace(/[?#].*$/, "")
      jobs = JSON.parse(parts[1] || "[]")
      lastError = ""
    } catch (e) {
      lastError = loaded ? lastError : "hycli not found"
      engineRunning = false
      jobs = []
    }
    loaded = true
    now = Date.now()
    announceFinished()
  }

  // A preparation can take minutes; say when one stops, not when it starts.
  // notify-send takes its text as arguments, which other users can read from
  // /proc, so the notification only carries counts. Site and action titles
  // and summaries stay in the panel.
  function announceFinished() {
    var next = {}
    var done = 0, other = 0
    for (var i = 0; i < jobs.length; i++) {
      var j = jobs[i]
      var before = lastStatus[j.id]
      if (before && isWorking(before) && !isWorking(j.status)) {
        if (j.status === "completed") done++
        else other++
      }
      next[j.id] = j.status
    }
    lastStatus = next
    if (!notifyDone || done + other === 0) return
    var parts = []
    if (done) parts.push(done + " finished")
    if (other) parts.push(other + " stopped without finishing")
    Quickshell.execDetached(["notify-send", "-a", "Hycli",
      other ? "Hycli work stopped" : "Hycli work finished",
      parts.join(", ") + ". Open the Hycli panel for details."])
  }

  // `hycli open` would pass the launch address, token included, to xdg-open
  // as an argument, where other users can read it from /proc. The dashboard
  // only accepts that address from a navigation the user started, so a
  // redirect cannot carry it either. Open the plain address instead (enough
  // when the browser still has its session cookie) and put the launch
  // address on the clipboard, marked sensitive so clipboard history skips
  // it, and clear it after two minutes if it is still there. printf and [
  // are shell builtins and wl-copy reads stdin, so the token never reaches
  // an argv. (--paste-once does not work here: history watchers take it.)
  readonly property string openScript: `
out=$("$0" open --no-open) || exit
url=$(printf %s "$out" | sed -n 's|.*"url":"\\(http://127\\.0\\.0\\.1:[0-9]*\\)[^"]*".*|\\1|p')
[ -n "$url" ] || { echo "hycli: no dashboard address" >&2; exit 1; }
dir=\${HYCLI_DATA_DIR:-\${XDG_DATA_HOME:-$HOME/.local/share}/hycli}
launch=$(sed -n 's/.*"launch":"\\([0-9A-Za-z]*\\)".*/\\1/p' "$dir/dashboard-session.json" 2>/dev/null)
xdg-open "$url/" </dev/null >/dev/null 2>&1 || { echo "hycli: could not open the browser" >&2; exit 1; }
[ -n "$launch" ] || exit 0
addr="$url/?launch=$launch"
printf %s "$addr" | wl-copy --sensitive >/dev/null 2>&1 ||
  { echo "hycli: could not copy the launch address (is wl-copy installed?)" >&2; exit 1; }
notify-send -a Hycli "Launch address copied" "If the dashboard asks you to open Hycli, paste it into the address bar."
(sleep 120; [ "$(wl-paste -n 2>/dev/null)" = "$addr" ] && wl-copy --clear) </dev/null >/dev/null 2>&1 &
`

  function openDashboard() {
    run("open", ["sh", "-c", openScript, root.binary])
  }

  function startEngine() {
    run("start", [root.binary, "open", "--no-open"])
  }

  function stopEngine() {
    run("stop", [root.binary, "stop"])
  }

  function run(kind, command) {
    if (action.running) return
    pending = kind
    action.command = command
    action.running = true
  }

  Process {
    id: poll
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyPoll(text)
    }
  }

  Process {
    id: action
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var msg = String(text || "").trim()
        if (msg) root.lastError = msg.split("\n").pop().replace(/^hycli: /, "")
      }
    }
    onExited: function(code) {
      if (code === 0) root.lastError = ""
      root.pending = ""
      root.refresh()
    }
  }

  // Quick while something is happening or someone is looking, slow otherwise.
  Timer {
    interval: root.opened || root.busy || root.pending ? 3000 : 30000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  IpcHandler {
    target: root.ipcTarget

    function open(): void { root.openFromHotkey() }
    function close(): void { root.close() }
    function show(): void { root.openFromHotkey() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): void { root.refresh() }
    function dashboard(): void { root.openDashboard() }
    function status(): string {
      if (!root.loaded) return "loading"
      if (root.lastError && !root.engineRunning) return root.lastError
      return (root.engineRunning ? "running " + root.engineUrl : "stopped")
        + ", " + root.active.length + " working"
    }
  }

  // ------------------------------------------------------------ formatting

  function jobTitle(j) {
    var what = j.action_title || (j.kind === "prepare" ? "Prepare" : j.kind)
    return (j.site_title || "Hycli") + " · " + what
  }

  function statusText(j) {
    if (j.status === "running") {
      var step = j.progress_total > 0 ? " " + j.progress_done + "/" + j.progress_total : ""
      return (j.phase || "running") + step
    }
    if (j.error_code) return j.status + " · " + j.error_code.replace(/_/g, " ")
    return j.status
  }

  function lastNote(j) {
    var notes = j.notes || []
    return notes.length ? notes[notes.length - 1].message : (j.intent || "")
  }

  function relative(iso) {
    var t = Date.parse(iso)
    if (!t) return ""
    var s = Math.max(0, Math.round((now - t) / 1000))
    if (s < 60) return s + "s"
    if (s < 3600) return Math.round(s / 60) + "m"
    if (s < 86400) return Math.round(s / 3600) + "h"
    return Math.round(s / 86400) + "d"
  }

  // ------------------------------------------------------------ the panel

  readonly property color fg: root.bar ? root.bar.foreground : Commons.Color.foreground
  readonly property string fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
  readonly property color dim: Qt.darker(fg, 1.6)
  readonly property color accent: Commons.Color.accent
  readonly property color warn: Commons.Color.urgent

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent

      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onActivateRequested: root.openDashboard()
      onTextKey: function(text) {
        if (text === "r") root.refresh()
        else if (text === "d") root.openDashboard()
        else if (text === "s") root.engineRunning ? root.stopEngine() : root.startEngine()
      }

      Column {
        id: column
        width: parent.width
        spacing: Style.space(10)

        // ---------------------------------------------------- header

        Item {
          width: parent.width
          height: title.implicitHeight

          Text {
            id: title
            anchors.left: parent.left
            anchors.leftMargin: Style.space(4)
            text: "HYCLI"
            color: root.fg
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            font.bold: true
            font.letterSpacing: 1.5
          }

          Text {
            anchors.right: parent.right
            anchors.rightMargin: Style.space(4)
            anchors.verticalCenter: title.verticalCenter
            width: parent.width - title.width - Style.space(16)
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideLeft
            color: root.lastError ? root.warn : root.engineRunning ? root.accent : root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            text: root.pending === "start" ? "starting…"
              : root.pending === "stop" ? "stopping…"
              : root.lastError ? root.lastError
              : !root.loaded ? "…"
              : root.engineRunning ? "● " + root.engineUrl.replace(/^https?:\/\//, "")
              : "○ engine stopped"
          }
        }

        // ---------------------------------------------------- actions

        Row {
          spacing: Style.space(8)

          Button {
            text: "Dashboard"
            iconText: ""
            bordered: true
            foreground: root.fg
            fontFamily: root.fontFamily
            fontSize: Style.font.bodySmall
            enabled: !root.pending && root.lastError !== "hycli not found"
            onClicked: root.openDashboard()
          }

          Button {
            text: root.engineRunning ? "Stop engine" : "Start engine"
            iconText: root.engineRunning ? "" : ""
            bordered: true
            foreground: root.fg
            fontFamily: root.fontFamily
            fontSize: Style.font.bodySmall
            enabled: !root.pending && root.loaded && root.lastError !== "hycli not found"
            onClicked: root.engineRunning ? root.stopEngine() : root.startEngine()
          }
        }

        PanelSeparator { width: parent.width; foreground: root.fg }

        PanelSectionHeader {
          text: "RECENT WORK"
          foreground: root.dim
          fontFamily: root.fontFamily
        }

        Text {
          visible: root.recent.length === 0
          width: parent.width
          leftPadding: Style.space(4)
          wrapMode: Text.Wrap
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          text: root.lastError === "hycli not found"
            ? "Install hycli or set its path in the widget settings."
            : "Nothing yet. Prepare a website from the dashboard or with\nhycli prepare URL --intent \"…\""
        }

        Repeater {
          model: root.recent

          delegate: Rectangle {
            id: row
            required property var modelData
            readonly property bool working: root.isWorking(modelData.status)
            readonly property bool failed: !working && modelData.status !== "completed"

            width: column.width
            height: rowColumn.implicitHeight + Style.space(10)
            radius: Style.cornerRadius
            color: rowMouse.containsMouse ? Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.07) : "transparent"

            Column {
              id: rowColumn
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: Style.space(4)
              anchors.rightMargin: Style.space(4)
              spacing: Style.space(2)

              Item {
                width: parent.width
                height: rowTitle.implicitHeight

                Text {
                  id: rowTitle
                  anchors.left: parent.left
                  width: parent.width - rowWhen.width - Style.space(8)
                  elide: Text.ElideRight
                  color: root.fg
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  text: root.jobTitle(row.modelData)
                }

                Text {
                  id: rowWhen
                  anchors.right: parent.right
                  anchors.verticalCenter: rowTitle.verticalCenter
                  color: row.working ? root.accent : row.failed ? root.warn : root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  text: root.statusText(row.modelData) + "  " + root.relative(row.modelData.updated_at)
                }
              }

              Text {
                width: parent.width
                elide: Text.ElideRight
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                text: row.modelData.status === "completed" && row.modelData.summary
                  ? row.modelData.summary : root.lastNote(row.modelData)
              }

              // Progress through the preparation's workers.
              Rectangle {
                visible: row.working && row.modelData.progress_total > 0
                width: parent.width
                height: 2
                color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.12)

                Rectangle {
                  height: parent.height
                  width: parent.width * Math.min(1, row.modelData.progress_done / Math.max(1, row.modelData.progress_total))
                  color: root.accent
                  Behavior on width { NumberAnimation { duration: 300 } }
                }
              }
            }

            MouseArea {
              id: rowMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.openDashboard()
            }
          }
        }

        Text {
          width: parent.width
          leftPadding: Style.space(4)
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          text: "d dashboard · s start/stop · r refresh"
        }
      }
    }
  }
}
