# Omacale

A [Caelestia](https://github.com/caelestia-dots/shell)-style desktop shell for [Omarchy](https://omarchy.org).

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)

![Omacale preview](preview.webp)

Omacale is a single Omarchy bar plugin (`omacale.bar`). It runs inside Omarchy's own shell: no extra daemon, no build step, no required Hyprland changes. Caelestia provides the look; Omarchy stays the engine.

## Features

- **Frame and drawers**: Caelestia's shader-drawn screen frame, with dashboard, launcher, sidebar, utilities, session and settings sliding out of it.
- **Material 3 colours** generated from your Omarchy theme.
- **Bar**: workspaces, active window (live preview and window actions), tray, clock, status icons and popouts. Crowded items collapse on their own. It can sit on any edge of the screen (Settings › Taskbar › Position: left, right, top, bottom, or follow Omarchy's own bar position); the frame, drawers and popouts follow it.
- **Launcher**: apps, calculator (`>calc`), clipboard history (`>clipboard`), wallpaper and theme pickers (`>wallpaper`, `>theme`), and the Omarchy menu (`:`).
- **Dashboard**: weather, calendar, system resources, and media with synced lyrics.
- **Notifications**: toasts that stay above fullscreen windows, plus a history sidebar.
- **OSD**: Caelestia's sliders slide out of the right edge when you change the volume or brightness, or when you hover there, and every other Omarchy OSD (media, microphone, keyboard backlight, input devices, power, app launches) shows as a Caelestia toast.
- **Status toasts**: Caelestia's small toasts above the utilities corner for do not disturb, game mode, the charger, and audio device changes (Settings › Notifications › Toasts).
- **Workspace overview** with live previews and drag-and-drop.
- **Lock screen**: Caelestia's design on top of Omarchy's own lock and PAM.
- **Desktop clock and audio visualiser** (optional).
- **Plugin manager** and hosting for third-party Omarchy bar widgets. Each widget can be pinned, kept behind the plugin pill's chevron, or hidden from the bar (Settings › Taskbar › Plugins).
- **Keyboard-driven**: every panel works with `h` `j` `k` `l`, Enter and Escape.
- **Settings app** for everything above, applied live.
- **UI scale**: follows Omarchy's font size (`[font] base-size` in `~/.config/omarchy/shell.toml`) or a size of your own, with separate text, padding, spacing and rounding scales. Unlike Caelestia, the drawers and bar scale with it too, so a smaller UI also takes less room. With `omacale.lua` loaded, Hyprland's gaps and window rounding follow as well: window corners stay concentric with the frame (window radius = frame radius − gap).

## Requirements

- Omarchy, with its shell running
- `jq`
- Material Symbols Rounded font (added by the installer if missing)
- `cava` (optional, for the visualiser)

## Install

```bash
git clone https://github.com/AyushKr2003/omacale.git
cd omacale
./install.sh
```

The installer copies the plugin to `~/.config/omarchy/plugins/omacale.bar`, makes it the active bar, and records your previous setup so it can be restored.

To update, pull and run the installer again. It upgrades in place: new plugin files, the notification and lock-screen handovers rebuilt for your Omarchy, and a shell restart. Your settings are kept, and `./uninstall.sh` still restores the setup from before the first install.

```bash
git pull
./install.sh
```

| Command | Purpose |
|---|---|
| `./uninstall.sh` | Restore your previous bar exactly |
| `scripts/omacale status` | Show what is installed |
| `scripts/omacale doctor` | Check the installation |
| `scripts/omacale install --dry-run` | Preview an install |
| `scripts/omacale install --dev` | Symlink the plugin for development |

### Optional setup

- **Keybindings**: copy them from **Settings › Keybinds**, or paste [`keybinds.lua`](keybinds.lua) into `~/.config/hypr/bindings.lua`.
- **Window styling** (Caelestia borders, animations and shadows): add to `~/.config/hypr/looknfeel.lua`:

  ```lua
  pcall(dofile, os.getenv("HOME") .. "/.config/omarchy/plugins/omacale.bar/omacale.lua")
  ```

- **Notification toasts** and the **volume and brightness OSD**: offered during install, on by default (`--osd` / `--no-osd` skip the question for the OSD).
- **Lock screen**: off unless you say yes at the prompt or pass `--lock-screen` (see [Omarchy integration](#omarchy-integration) for why).
- Change any of them later in **Settings › Notifications**, **Settings › Panels › Lock screen** and **Settings › Panels › OSD**.
- **Removing Omacale**: use `./uninstall.sh`. `omarchy plugin remove omacale.bar` removes only the bar and leaves Omacale's copies of the notification, lock and OSD plugins in place (they fall back to Omarchy's own drawing, but stay installed).

## Usage

### Keybindings

| Key | Action |
|---|---|
| `SUPER + A` | Launcher |
| `SUPER + D` | Dashboard |
| `SUPER + N` | Notifications sidebar |
| `SUPER + U` | Quick toggles |
| `SUPER + TAB` | Workspace overview |
| `SUPER + SHIFT + I` | Settings |
| `SUPER + SHIFT + ESCAPE` | Session menu |
| `SUPER + CTRL + 0` | Bar focus: move through the bar with the keyboard |
| `SUPER + CTRL + W` / `B` / `P` / `A` | Network / Bluetooth / Power / Audio popout (Omarchy's own keys) |
| `SUPER + CTRL + 1..9` | Third-party bar widgets, in bar order (Omarchy's own keys) |

### Keyboard navigation

A focus ring appears only when you use the keys, so mouse use is unchanged.

| Key | Action |
|---|---|
| `h` `j` `k` `l` / arrows | Move |
| `Enter` / `Space` | Activate |
| `Tab` / `Shift + Tab` | Next / previous popout or tab |
| `x` | Remove (network, device, notification, recording) |
| `Escape` | Close, or go back to the bar |

<details>
<summary>Keys for each panel</summary>

| Panel | Keys |
|---|---|
| Bar focus | `1..9` switch workspace; `Menu` or `Shift + F10` opens a tray item's menu |
| Tray menu | `→` open submenu, `←` back, a letter jumps to an entry |
| Network | `r` rescan |
| Audio | `m` mute; `←` / `→` on the slider change the volume |
| Dashboard | Moving along the tabs opens them; `1..4` jump to a tab; `n` / `p` change track |
| Sidebar | `d` do not disturb, `Shift + X` clear all |
| Settings | `/` search, `Backspace` previous page |
| Launcher `:` menu | Type to filter; `Enter` / `→` open, `Backspace` / `←` back |
| Launcher `>clipboard` | Type to filter; `Enter` paste, `Shift + Enter` copy, `Alt + Enter` open, `Delete` remove, `Shift + Delete` clear all |

</details>

### Command line

```bash
omarchy-shell omacale <launcher|dashboard|sidebar|utilities|overview|session|settings|close>
omarchy-shell omacale <wallpapers|themes|menu|clipboard|windowInfo|barFocus>
omarchy-shell omacale dashboardTab <dashboard|media|performance|weather>
omarchy-shell omacale settingsPage <page>
omarchy-shell omacale popout <network|bluetooth|audio|battery|kblayout|lockstatus|update|activewindow>
omarchy-shell omacale scale <omarchy|0.5-2|50%-200%>                  # empty prints the current scale
omarchy-shell omacale toast <info|success|warning|error> <title> <message> <icon>
```

## Omarchy integration

Omacale changes how things look, never how they work underneath.

- **Notifications**: Omarchy's daemon keeps the server, do not disturb and history. Omacale only draws the toasts, and only while it is the running bar with **Show popups** on. Otherwise (a bar that failed to load, another bar, Show popups off) Omarchy's own toasts come back within a second, without a restart.
- **Lock screen**: Omarchy keeps the session lock, PAM and idle timers. Omacale only draws the view, and Omarchy's view comes back if Omacale is off or missing. That view runs inside Omarchy's lock service and is given what is typed into the password field, to draw it; Omarchy otherwise keeps third-party code away from its authentication services. That is why the lock screen is opt-in. It also only installs on an Omarchy lock service Omacale was verified against; after an Omarchy update that changes it, Omarchy's own lock screen is restored until an Omacale update catches up. On the lock screen, notifications are hidden by default and, when shown, are read-only: no actions, links, copying or dismissing.
- **OSD**: Omarchy keeps the keys and the brightness control and still decides when an OSD is shown; Omacale draws them all, volume and brightness as sliders and the rest as toasts (or only the sliders, with Settings › Panels › OSD › Other OSD messages off). It hands them back while a window is fullscreen, and when Omacale isn't the bar.
- **Scale**: by default Omacale follows the size set in Omarchy's `shell.toml` (`[font] base-size`, `[spacing] scale`), so the stock bar and Omacale grow and shrink together.
- **Updates**: when `omarchy update` changes those plugins, Omacale rebuilds its copies from the new version. If a copy stops working, Omarchy's original is restored automatically and you get a notification.

<details>
<summary>Manage the handovers by hand</summary>

```bash
scripts/notif-popups <status|install|remove|health>
scripts/lock-screen  <status|install|remove|health>
scripts/osd-handover <status|install|remove|health>
```

</details>

## Development

```bash
./scripts/omacale install --dev                                          # live-editing symlink
rsync -a --exclude .git ./ ~/.config/omarchy/plugins/omacale.bar/ && omarchy-restart-shell
bash tests/test-restore.sh                                               # test suite
scripts/upstream-check                                                   # what changed in Omarchy since last verified
```

Architecture, conventions and design tokens are documented in [`CLAUDE.md`](CLAUDE.md).

## Limitations

- The OSD sliders and the toasts live in the frame, so a fullscreen window hides them. Over a fullscreen window Omarchy's own OSD shows instead.
- Caelestia's battery level warnings aren't ported, since Omarchy's battery service already sends them. Its VPN and keyboard layout toasts aren't either, since Omacale has neither feature.
- The lock screen shows the wallpaper by default. With **Use the wallpaper** off it shows a blurred snapshot of the screen, as Caelestia does; if the snapshot can't be taken (the display is off, say), it falls back to the wallpaper. With a video wallpaper, the blur applies to its still frame only.
- Notifications support their default action only; there are no inline replies (Caelestia has none either).

## Credits

- UI and shaders: [caelestia-dots/shell](https://github.com/caelestia-dots/shell) (GPL-3.0)
- Workspace overview: adapted from [omarchy-overview](https://github.com/AyushKr2003/omarchy-overview) and [quickshell-overview](https://github.com/Shanu-Kumawat/quickshell-overview)
- Fonts: Google Sans Flex and Rubik (SIL Open Font License)

## License

[GPL-3.0](LICENSE)
