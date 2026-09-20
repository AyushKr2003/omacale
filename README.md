# Omacale

A [Caelestia](https://github.com/caelestia-dots/shell)-style desktop shell for [Omarchy](https://omarchy.org).

Omacale ships as a single Omarchy shell **bar plugin** (`omacale.bar`). It runs inside the Omarchy shell you already have: no second Quickshell process, no C++ build, and no edits to your Hyprland config.

## Features

- **Frame and drawers**: a screen frame with slide-out drawers, drawn as one shader (ported from Caelestia's `blob.frag`)
- **Material 3 colours**: generated from your Omarchy theme accent, so `omarchy theme set` recolours the whole shell
- **Bar**: workspaces as shapes, window title, tray, clock, status icons, and hover popouts for Wi-Fi, Bluetooth and battery
- **Dashboard**: weather, calendar, system stats, and a media player with synced lyrics and an audio visualiser
- **Launcher**: app search, Omarchy actions, and wallpaper and theme carousels (`>wallpaper`, `>theme`)
- **Notification popups**: Caelestia-style toasts — hover to pause, swipe to dismiss, drag to expand — on their own overlay layer, so they stay visible over fullscreen windows and video
- **Sidebar**: grouped notifications, quick toggles, keep-awake, and a screen recorder
- **Session menu**: logout, reboot, shutdown and more
- **Settings**: a port of Caelestia's Nexus app covering style, panels, network, Bluetooth, keybinds and more. Changes apply live.

Omarchy stays the engine. Data and actions come from `omarchy-*` commands, Omarchy's state files and Quickshell services.

## Requirements

- Omarchy with the shell running
- `jq`
- `ttf-material-symbols-variable` (Material Symbols Rounded font)
- `cava` (optional, for the media visualiser; the installer offers it)

## Install

```bash
git clone https://github.com/AyushKr2003/omacale.git
cd omacale
./install.sh
```

This copies the plugin to `~/.config/omarchy/plugins/omacale.bar`, sets it as your bar and restarts the Omarchy shell once.

```bash
./uninstall.sh                   # restore your previous setup
scripts/omacale status           # what's installed
scripts/omacale doctor           # health check
scripts/omacale install --dry-run
scripts/omacale install --dev    # symlink for live editing
```

### Notification popups

Omarchy's notification daemon draws its own toasts, and two notification servers can't run side by side. So the installer offers to clone the daemon (`omarchy plugin clone`, the supported route) and patch the clone to give its toast window up — the daemon itself, DND and history keep running as before. Uninstall puts the stock daemon back.

```bash
scripts/notif-popups status      # who draws the toasts
scripts/notif-popups install     # hand them to Omacale
scripts/notif-popups remove      # give them back to Omarchy
```

Omacale only draws toasts once the daemon has stood down, so the two can never both be on screen. Turn them off without undoing the clone in Settings › Panels › Notifications.

If `omarchy update` reshapes the notification plugin, the clone keeps running the older copy; `scripts/omacale doctor` flags it, and `scripts/notif-popups remove && scripts/notif-popups install` re-clones from the new one.

Uninstall restores your previous state exactly. Install touches the plugin directory, `bar.id` in `~/.config/omarchy/shell.json`, Omacale's own settings and state directories, and — if you accept the popups — the notification clone above. It never edits `~/.config/hypr` or anything under `/usr`.

## Usage

Drive it from Hyprland bindings or the command line:

```bash
omarchy-shell omacale launcher | dashboard | session | sidebar | utilities | settings | close
omarchy-shell omacale wallpapers | themes
```

Suggested keybinds live in [`omacale.bar/keybinds.lua`](omacale.bar/keybinds.lua). Print them with `scripts/omacale binds`, or copy them from Settings › Keybinds.

| Key | Action |
|---|---|
| `SUPER + A` | Launcher |
| `SUPER + D` | Dashboard |
| `SUPER + SHIFT + I` | Settings |
| `SUPER + SHIFT + ESCAPE` | Session menu |

Settings are saved to `~/.config/omacale/settings.json`.

### Optional: Caelestia's window styling

[`omacale.bar/omacale.lua`](omacale.bar/omacale.lua) adds Caelestia's animations, rounding, gaps, blur and shadow to Hyprland. Load it from `~/.config/hypr/looknfeel.lua`:

```lua
pcall(dofile, os.getenv("HOME") .. "/.config/omarchy/plugins/omacale.bar/omacale.lua")
```

## Development

```bash
rsync -a omacale.bar/ ~/.config/omarchy/plugins/omacale.bar/
omarchy-restart-shell
```

See [`CLAUDE.md`](CLAUDE.md) for the architecture, conventions and debugging gotchas. Run `tests/test-restore.sh` to check the install and uninstall logic in a throwaway `HOME`.

## Not yet ported

OSD styling, the lock screen, wallpaper-derived colours and drawer "jelly" deformation. Omarchy's own OSD and lock screen keep working underneath.

Toasts carry Caelestia's close/open/copy row but not a sender's own action buttons or inline reply: Omarchy's notification records keep only the one default action (`execArgv`), so there is nothing to draw the rest from.

## Credits

Design, shader and assets come from [caelestia-dots/shell](https://github.com/caelestia-dots/shell) (GPL-3.0). Google Sans Flex and Rubik are under the SIL Open Font License.
