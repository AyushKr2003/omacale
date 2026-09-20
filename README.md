# Omacale

A [Caelestia](https://github.com/caelestia-dots/shell)-style desktop shell for [Omarchy](https://omarchy.org).

![Omacale preview](preview.png)

Omacale ships as a single Omarchy shell **bar plugin** (`omacale.bar`). It runs inside the Omarchy shell you already have: no second Quickshell process, no C++ build, and no edits to your Hyprland config.

## Features

- **Frame and drawers**: a screen frame with slide-out drawers, drawn as one shader (ported from Caelestia's `blob.frag`)
- **Material 3 colours**: generated from your Omarchy theme accent, so `omarchy theme set` recolours the whole shell
- **Bar**: workspaces as shapes, window title, tray, clock, status icons, and hover popouts for Wi-Fi, Bluetooth and battery
- **Dashboard**: weather, calendar, system stats, and a media player with synced lyrics and an audio visualiser
- **Launcher**: app search, Omarchy actions, and wallpaper and theme carousels (`>wallpaper`, `>theme`)
- **Notification popups**: Caelestia-style toasts — hover to pause, swipe to dismiss, drag to expand — on their own overlay layer, so they stay visible over fullscreen windows and video
- **Sidebar**: grouped notifications, quick toggles, keep-awake, and a screen recorder
- **Workspace overview**: the monitor's workspaces as a grid of live window previews, in a panel that grows out of the frame like Settings -- click a workspace to switch, click a window to focus it, drag a window onto another workspace, middle click to close it, or move the cursor with the arrow keys and commit with Enter (a number key jumps straight there)
- **Lock screen**: Caelestia's lock card — split clock, profile picture, shape-per-character password field, weather, fetch, media, resources and notifications — drawn inside Omarchy's own lock plugin, which keeps the session lock and the password check
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

### Lock screen

Omarchy's lock screen is a shell plugin (`omarchy.lock`) whose service owns the session lock, PAM, the stranded-lock recovery, the blank-on-idle timers and the `lock` IPC that `omarchy system lock`, the sleep lock and the lid binding call. None of that changes. The installer offers to clone that plugin (`omarchy plugin clone`, the same supported route as the popups) and swap **only the view** it draws for Caelestia's.

```bash
omacale.bar/scripts/lock-screen status    # who draws the lock screen
omacale.bar/scripts/lock-screen install   # hand it to Omacale
omacale.bar/scripts/lock-screen remove    # give it back to Omarchy
```

Settings › Panels › Lock screen is the switch, and it does the handover itself: turning it on installs the clone if it is missing, turning it off draws Omarchy's own view again immediately (no restart, and the session lock is never torn down). The card there also previews the lock, and each card on it — weather, fetch, media, resources, notifications — can be turned off. "Hide notification contents" shows *Unlock for notifications* instead of the notifications themselves.

The clone carries a verbatim copy of Omarchy's lock service, re-copied on every `lock-screen install`, so `omarchy update` fixes reach it after a reinstall; `scripts/omacale doctor` flags a clone that has fallen behind. Before writing anything the script checks that every property Omarchy's service drives its view with exists on Omacale's wrapper, and refuses if an update has changed that contract. If Omacale is turned off, missing or fails to load, the wrapper falls back to the view Omarchy shipped — the machine is never left without a lock screen.

Uninstall restores your previous state exactly. Install touches the plugin directory, `bar.id` in `~/.config/omarchy/shell.json`, Omacale's own settings and state directories, and — if you accept them — the notification and lock clones above. It never edits `~/.config/hypr` or anything under `/usr`.

## Usage

Drive it from Hyprland bindings or the command line:

```bash
omarchy-shell omacale launcher | dashboard | session | sidebar | utilities | overview | settings | close
omarchy-shell omacale wallpapers | themes
```

Suggested keybinds live in [`omacale.bar/keybinds.lua`](omacale.bar/keybinds.lua). Print them with `scripts/omacale binds`, or copy them from Settings › Keybinds.

| Key | Action |
|---|---|
| `SUPER + A` | Launcher |
| `SUPER + D` | Dashboard |
| `SUPER + SHIFT + I` | Settings |
| `SUPER + SHIFT + ESCAPE` | Session menu |

`SUPER + TAB` is Omarchy's own "Next workspace", so the overview's bind sits commented out at the bottom of `keybinds.lua` with the other replacements -- uncomment it, or bind the overview wherever you like:

```bash
omarchy-shell omacale overview
```

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

OSD styling, wallpaper-derived colours and drawer "jelly" deformation. Omarchy's own OSD keeps working underneath.

The lock screen shows the wallpaper rather than Caelestia's blurred screenshot of the desktop (a screencopy taken after the compositor is locked needs a capture warmed up beforehand), and has no fingerprint or face-unlock state of its own beyond the sensor hint: Omarchy's lock service runs those PAM flows itself. Caelestia's hourly forecast is Omacale's daily one, and its terminal-palette swatch row is drawn from the scheme's accents, since Omacale has no terminal palette.

Toasts carry Caelestia's close/open/copy row but not a sender's own action buttons or inline reply: Omarchy's notification records keep only the one default action (`execArgv`), so there is nothing to draw the rest from.

## License

Omacale is licensed under the [GNU General Public License v3.0](LICENSE). It is a derivative work of [caelestia-dots/shell](https://github.com/caelestia-dots/shell), which is also GPL-3.0.

## Credits

Design, shader and assets come from [caelestia-dots/shell](https://github.com/caelestia-dots/shell) (GPL-3.0). Google Sans Flex and Rubik are under the SIL Open Font License.

The workspace overview follows [omarchy-overview](https://github.com/AyushKr2003/omarchy-overview) (MIT), itself adapted from [Shanu-Kumawat/quickshell-overview](https://github.com/Shanu-Kumawat/quickshell-overview); Omacale's is a rewrite in Caelestia's tokens on Quickshell's Hyprland IPC.
