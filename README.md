# Hycli for Omarchy

A bar widget for [Hycli](https://github.com/Hybirdss/Hycli), the tool that
turns websites into a typed CLI and MCP server for AI agents.

- **Bar**: bird glyph, plus the number of preparations still running
  (accent colour while busy, dimmed while the engine is stopped).
  Left click opens the panel, right click opens the dashboard, middle click refreshes.
- **Panel**: engine state and address, start/stop, and the eight most recent
  pieces of work with phase, progress and the latest note.
  Keys: `d` dashboard, `s` start/stop, `r` refresh, `Enter` dashboard.
- **Notifications** when a preparation finishes or fails (can be turned off).

The plugin only calls the `hycli` CLI (`status`, `jobs ls`, `open`, `stop`). It
never talks to the dashboard's HTTP API or reads its session secrets;
`hycli open` gives the browser its own launch address.

## Requirements

This plugin does not include Hycli. Install it first from the
[Hycli releases](https://github.com/Hybirdss/Hycli/releases): extract the
`linux-x64` (or `linux-arm64`) archive and put `hycli` on your `PATH`, or set
its path in the widget settings below.

## Install

```bash
omarchy plugin add https://github.com/mechurisr/omarchy-hycli.git --enable
```

## Removing

```bash
omarchy plugin remove mechurisr.hycli
```

The plugin writes no files of its own. Hycli itself, and its data, are left
as they are.

## Settings

| Key | Default | |
| --- | --- | --- |
| `binary` | `hycli` | Path to the executable, if it is not on `PATH`. |
| `notify` | `true` | Desktop notification when work finishes. |

```sh
omarchy bar set mechurisr.hycli binary ~/.local/bin/hycli
```

## IPC

```sh
qs -p /usr/share/omarchy/shell ipc call mechurisr.hycli open|close|toggle|refresh|dashboard|status
```
