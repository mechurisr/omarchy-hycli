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
  They only say how many finished or stopped; titles and results stay in the
  panel, because notification text is passed as process arguments.

The plugin only calls the `hycli` CLI (`status`, `jobs ls`, `open`,
`open --no-open`, `stop`) and never talks to the dashboard's HTTP API.

### Opening the dashboard

The Dashboard button runs `hycli open`, which starts the engine if needed and
opens the dashboard signed in. Hycli 0.1.0 hands the browser that address,
launch token included, as a process argument, which other local users can
read from `/proc` while it runs. On a single-user machine that does not
matter; on a shared one, see
[Hybirdss/Hycli#54](https://github.com/Hybirdss/Hycli/issues/54).

## Requirements

This plugin does not include Hycli, and it runs whichever `hycli` executable
it finds. It was reviewed against Hycli 0.1.0. Install that exact release and
check the archive against the checksum pinned here before extracting it:

| Archive | SHA-256 |
| --- | --- |
| `hycli-0.1.0-linux-x64.tar.gz` | `7d980309bdaa6dac170157268b8e823e6c10060c0ff06c7de226594903411bd2` |
| `hycli-0.1.0-linux-arm64.tar.gz` | `a188b133c5e483884dfa63f2ef69091b7493d88e0a72323421a1cb429bdeeb07` |

```bash
arch=x64   # or arm64
case $arch in
  x64) sum=7d980309bdaa6dac170157268b8e823e6c10060c0ff06c7de226594903411bd2 ;;
  arm64) sum=a188b133c5e483884dfa63f2ef69091b7493d88e0a72323421a1cb429bdeeb07 ;;
esac
file=hycli-0.1.0-linux-$arch.tar.gz
curl -fLO "https://github.com/Hybirdss/Hycli/releases/download/v0.1.0/$file"
echo "$sum  $file" | sha256sum -c - &&
  tar -xzf "$file" &&
  install -Dm755 "hycli-0.1.0-linux-$arch/hycli" ~/.local/bin/hycli
```

Stop if `sha256sum` reports a mismatch. A different Hycli version may work,
but it is not the one this plugin was reviewed with. To use an executable
outside your `PATH`, set `binary` in the widget settings below.

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
| `notify` | `true` | Desktop notification when work finishes (counts only). |

```sh
omarchy bar set mechurisr.hycli binary ~/.local/bin/hycli
```

## IPC

```sh
qs -p /usr/share/omarchy/shell ipc call mechurisr.hycli open|close|toggle|refresh|dashboard|status
```
