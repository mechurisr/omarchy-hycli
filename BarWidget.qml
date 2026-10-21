import QtQuick
import qs.Commons
import qs.Ui

// Bar pill: the Hycli glyph, plus the number of preparations still running.
// Dimmed while the engine is stopped. Left click opens the panel, right click
// opens the dashboard, middle click refreshes.
BarWidget {
  id: root
  moduleName: "mechurisr.hycli"

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function togglePanel() {
    if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle()
  }

  // Shape contract for shell.summon/hide/toggle routing.
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item && panelLoader.item.openFromHotkey) panelLoader.item.openFromHotkey()
  }

  function close() {
    if (panelLoader.item && panelLoader.item.close) panelLoader.item.close()
  }

  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: panelLoader.item && !root.vertical ? panelLoader.item.label : "󱗆"
    active: panelLoader.item ? panelLoader.item.busy : false
    opacity: panelLoader.item && !panelLoader.item.engineRunning ? 0.55 : 1
    tooltipText: ""

    onPressed: function(b) {
      if (!panelLoader.item) return
      if (b === Qt.MiddleButton) panelLoader.item.refresh()
      else if (b === Qt.RightButton) panelLoader.item.openDashboard()
      else root.togglePanel()
    }

    Accessible.role: Accessible.Button
    Accessible.name: "Hycli"
  }
}
