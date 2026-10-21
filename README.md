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

The plugin only calls the `hycli` CLI (`status`, `jobs ls`, `open --no-open`,
`stop`) and never talks to the dashboard's HTTP API.

### Opening the dashboard

Hycli 0.1.0 reuses one dashboard launch token, and `hycli open` passes the
address with that token to `xdg-open` as an argument. On Linux, other users
can usually read process arguments from `/proc`, so they could take the
token and sign in to your dashboard. Hycli also accepts the launch address
only from a navigation you start yourself, so a redirect cannot deliver it
either. The plugin therefore never runs plain `hycli open`. To open the
dashboard it:

1. starts the engine with `hycli open --no-open`, which prints only the address;
2. opens that address without the token. If the browser still has its
   dashboard session, this is all it takes;
3. reads the launch token from Hycli's private `dashboard-session.json`
   (mode `0600`, under `$HYCLI_DATA_DIR`, `$XDG_DATA_HOME/hycli` or
   `~/.local/share/hycli`), copies the launch address to the clipboard with
   `wl-copy --sensitive`, and shows a notification. If the dashboard asks
   you to open Hycli, paste it into the address bar once.

The token is handled only by shell builtins and stdin, so no process gets it
as an argument. Omarchy's clipboard history skips content marked sensitive,
and the plugin clears the clipboard after two minutes if the address is
still on it. The panel also strips any token from the address it shows.

Running `hycli open` yourself, or another tool that does, still exposes the
token. The fix for that belongs in Hycli:
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

Opening the dashboard also needs `wl-copy` (`wl-clipboard`, included in
Omarchy).

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
