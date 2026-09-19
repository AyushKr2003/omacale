# Omacale

A [Caelestia](https://github.com/caelestia-dots/shell)-style desktop shell for
[Omarchy](https://omarchy.org), built as a single Omarchy shell **bar plugin**
(`omacale.bar`). It runs inside the Omarchy shell you already have — no second
Quickshell process, no C++ build, no changes to Hyprland config (an optional
look'n'feel file is there if you want Caelestia's window styling too).

It is a port of Caelestia's actual design, not an approximation:

- **Blob frame.** The screen frame and every drawer are one signed-distance
  field rendered by a shader ported from Caelestia's `blob.frag` (circular
  smooth-min fillets, "sink" pockets as drawers slide in, 28px drawer
  rounding, 25px frame rounding, soft 0.7 shadow).
- **Material 3 colours.** A tonal-spot scheme (surface ladder, primary,
  secondary, tertiary, error...) generated from the active Omarchy theme's
  accent, so `omarchy theme set` recolours the shell. Light themes get the
  light scheme.
- **Caelestia tokens.** Its spacing, padding, rounding, type scale, and
  expressive motion curves and durations, verbatim. Bundled Google Sans Flex
  (rounded axis) and Rubik; Material Symbols Rounded with fill and grade axes.
- **Bar.** Caelestia's default order: tinted logo (Omarchy mark, a distro
  glyph or a simple Material icon, picked in Settings › Panels › Taskbar); workspaces as M3 shapes
  (a random expressive shape for the focused one, square with app icons for
  occupied, dot for empty) with the trailing active pill; while a special
  workspace (Omarchy's scratchpad, Super+S) is open, the list blurs behind
  Caelestia's special-workspace strip (icons, ★, letters or shapes, window
  icons, tertiary pill;
  click to switch, scroll or click the active one to close); rotated window
  title; tray; clock; status pill (network, Bluetooth and its devices,
  battery or power profile, caps/num lock); power.
- **Hover popouts.** Wi-Fi list with connect/disconnect, Bluetooth toggles
  and devices, battery with the power-profile switch, tray menus with
  submenus, and a live preview of the active window.
- **Dashboard.** Opens on hover at the top edge, with Caelestia's four tabs:
  - **Dashboard**: weather, user card, Rubik clock, calendar with a "sunny"
    today marker, CPU/RAM/disk rings, media with arc progress and bongo cat.
  - **Media**: drifting background shapes, the cover art cut to a spinning
    cookie shape and ringed by a 60-bar audio visualiser, a wavy seek bar,
    shuffle/previous/play/next/repeat, synced lyrics (current line glows,
    click a line to seek), and a player selector.
  - **Performance**: CPU and GPU hero cards (usage ring, temperature bar, a
    usage shape that turns from cookie to sunny to burst as load rises),
    storage with a disk selector, a network sparkline with speeds and
    totals, memory, and a battery "tank" that fills with charge.
  - **Weather**: city, date, sunrise/sunset, current conditions, humidity,
    feels-like, wind, and a 7-day forecast.
- **Launcher.** Bottom drawer: search pill, 7 results, keyboard navigation;
  `>` lists Omarchy actions.
- **Wallpaper & theme switcher.** Caelestia's launcher carousel:
  `>wallpaper ` shows the current theme's backgrounds (Omarchy's own
  thumbnails), `>theme ` shows the installed Omarchy themes by their preview
  image. The centred item is full size, the rest shrink; ↑/↓, Tab or the
  scroll wheel move, typing filters, Enter or a click applies it
  (`omarchy-theme-bg-set` / `omarchy-theme-set`). Scrolling wallpapers
  previews each one live on the desktop; Escape puts the old one back. Open it
  with `omarchy-shell omacale wallpapers` / `themes`. Turn on **Settings ›
  Style › Switcher** and Omarchy's own Background and Theme pickers
  (`SUPER + CTRL + SPACE`, `SUPER + SHIFT + CTRL + SPACE`, Menu › Style, and
  the launcher's Theme/Background actions) open this carousel instead; turn it
  off to get Omarchy's pickers back.
- **Session.** Right drawer: logout, shutdown, kurukuru, hibernate, reboot.
  Opens from the power button or by dragging in from the right edge.
- **Sidebar & Quick Toggles (Utilities).** Right-edge control center:
  - **Notifications (Sidebar)**: Material 3 notification center grouped by app,
    showing live and recent Omarchy notifications with timestamps, urgency badges,
    action buttons, app clear, and a "clear all" floating action button. Includes
    Caelestia's dino empty state when all caught up. Opens with
    `omarchy-shell omacale sidebar` (`SUPER + N`), dragging in from the top-right
    screen edge, or clicking the notification bell on the bar.
  - **Quick Toggles (Utilities)**: Material 3 shape-morphing toggles for Wi-Fi,
    Bluetooth, microphone mute, Settings, Game Mode (Hyprland animation/blur/gap
    cut) and Do Not Disturb, in one row as in Caelestia. Night Light can be added
    in Settings › Panels › Utilities, where each toggle can be switched off. Includes a "Keep awake" idle
    inhibitor card with M3 switch and active duration chip, plus a screen recorder
    card with fullscreen/region selector, audio toggle, and recent recordings list.
    Slides up from the bottom-right corner: hover the bottom edge there, run
    `omarchy-shell omacale utilities` (`SUPER + U`), or open the sidebar, which
    it docks underneath. Opened by hover it closes when the cursor leaves.

- **Settings.** A port of Caelestia's "Nexus" settings app: navigation pane
  with search, connected row groups, M3 switches, steppers, sliders and
  split-button menus, sub-pages, and a pop-out into a real window. Everything
  applies live and is saved to `~/.config/omacale/settings.json` (created on
  your first change; hand edits reload live):
  - **Style**: live miniature of your shell, palette (Material, generated
    from a seed, or Omarchy, the theme's own colours), seed colour (theme accent, any
    theme colour, or hex), 9 Material scheme variants, light/dark/auto,
    transparency with Hyprland blur, and the wallpaper & theme switcher.
  - **Frame & motion**: border thickness, corner rounding, drawer blending,
    shadow, animation speed.
  - **Network**: Wi-Fi on/off, network list with inline password (and
    802.1X username) prompts, ethernet, share via Omarchy's QR card, and a
    details page (signal, band, IP, gateway, forget / disconnect). Same engine
    as Omarchy's network panel: Quickshell Networking + `omarchy-network-status`.
  - **Connected devices**: Bluetooth on/off (`omarchy-bluetooth-power`), saved
    devices with battery, pair new device, discoverable / pairable, and a
    per-device page (trusted, blocked, wake, forget). Actions go through
    `omarchy-bluetooth-device`.
  - **Panels**: taskbar (persistent or auto-hide, workspaces as shapes or
    numbers, indicator/trail, window icons, special workspace display, title, tray, clock, which status
    icons, popouts, scroll actions), dashboard (hover, tabs, seconds, bongo
    cat), launcher (prefix, max items, carousel size, vim keys, dangerous
    actions), session.
  - **Language & region**: one 12-hour clock switch for every time Omacale
    shows (bar, dashboard, weather, notifications, keep awake, recordings),
    weather location and units.
  - **Keybinds**: the bindings below with copy buttons, "Try this session",
    and "Open bindings.lua".
  - **Look'n'feel**: every value in `omacale.lua` with its live Hyprland
    state, a copy button per value (as its own `hl.config` line), the loader
    snippet, "Try this session" / "Revert", and "Open looknfeel.lua".
  - **About**: system info, open the settings file, reset everything.

  Open it with `omarchy-shell omacale settings`, `SUPER + SHIFT + I` (once
  bound), right-clicking the bar logo, or `>settings` in the launcher.
  `omarchy-shell omacale settingsPage network` (or `bluetooth`, `style`, ...)
  opens it on one page; the bar's Wi-Fi and Bluetooth popouts use this for
  their "Open settings" buttons.

## Helper scripts

Caelestia gets this data from its C++ plugin; Omacale uses small scripts in
`omacale.bar/scripts/` (bash, `curl`, `jq`):

| Script | Does |
|---|---|
| `weather.sh [city] [metric\|imperial]` | Open-Meteo forecast (Caelestia's source); location from Open-Meteo geocoding or ip-api |
| `lyrics.sh artist title [album] [secs]` | Synced lyrics from lrclib.net, skipping junk uploads and preferring the closest duration |
| `gpu.sh` | NVIDIA (`nvidia-smi`) or AMD (`gpu_busy_percent`) usage and temperature; never wakes a sleeping hybrid-laptop dGPU |
| `cava.sh [bars]` | Streams `cava` bar values for the media visualiser |
| `switcher.sh walls\|themes\|menu on\|off` | Lists the backgrounds (with Omarchy's cached thumbnails) and themes that Omarchy's pickers show, and adds/removes the switcher's menu override |

The visualiser needs `cava`. The installer offers to install it
(`--with-cava` / `--no-cava`) and records whether it did; uninstall only
removes `cava` if Omacale installed it.

## Look'n'feel (optional)

`omacale.bar/omacale.lua` brings Caelestia's Hyprland styling (from
caelestia-dots' `hypr/`) to Omarchy: Material 3 animation curves (emphasized
decelerate/accelerate, standard) for windows, layers, workspaces and special
workspaces; 15px window rounding; 5/10px gaps (20px for a lone window, 20px
between workspaces); 1px borders; blur (8px, 2 passes, popups and input
methods); a soft shadow tinted with the theme accent; 0.95 window opacity
through Omarchy's `default-opacity` tag; and fade/no-anim rules for Omacale's
own layers. Border colours stay with your Omarchy theme.

Load it from `~/.config/hypr/looknfeel.lua`, above your own tweaks so they
still win:

```lua
pcall(dofile, os.getenv("HOME") .. "/.config/omarchy/plugins/omacale.bar/omacale.lua")
```

`pcall` keeps Hyprland starting if Omacale is uninstalled, and `dofile`
re-reads the file on every `hyprctl reload`. The values sit in a `vars` table
at the top of the file, as in Caelestia's `variables.lua`.

Settings › Look'n'feel shows those values and copies the loader line. "Try
this session" runs the file with `hyprctl eval` (nothing is written to
`~/.config/hypr`); "Revert" is `hyprctl reload`, which also drops session-only
keybinds.

## Keybindings

`omacale.bar/keybinds.lua` holds Omarchy-style bindings (`o.bind`, the helper
from Omarchy's `default/hypr/helpers.lua`) on keys that are free in a stock
Omarchy install. Paste them into `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + A", "Omacale launcher", "omarchy-shell omacale launcher")
o.bind("SUPER + D", "Omacale dashboard", "omarchy-shell omacale dashboard")
o.bind("SUPER + SHIFT + ESCAPE", "Omacale session menu", "omarchy-shell omacale session")
o.bind("SUPER + SHIFT + I", "Omacale settings", "omarchy-shell omacale settings")
o.bind("SUPER + ALT + D", "Omacale media", "omarchy-shell omacale dashboardTab media")
o.bind("SUPER + ALT + P", "Omacale performance", "omarchy-shell omacale dashboardTab performance")
```

The file also has commented `o.rebind` lines to make Omacale take over
`SUPER + SPACE` and `SUPER + ESCAPE`. `SUPER + SHIFT + SPACE` (Omarchy's
"Toggle top bar") already hides the Omacale frame.

```bash
scripts/omacale binds          # print them
scripts/omacale binds --copy   # copy to the clipboard
scripts/omacale binds --try    # bind for this Hyprland session only
scripts/omacale binds --untry  # and remove them again
```

## Install / uninstall

```bash
./install.sh            # or: scripts/omacale install
./uninstall.sh          # or: scripts/omacale uninstall
scripts/omacale status  # what's installed, what uninstall will restore
scripts/omacale doctor
scripts/omacale settings        # open the settings panel
scripts/omacale install --dry-run
scripts/omacale install --dev   # symlink the plugin for live editing
scripts/omacale install --no-restart   # skip the shell restart after install
```

Requires Omarchy with the shell running, `jq`, and the *Material Symbols Rounded*
font (`ttf-material-symbols-variable`). Install restarts the Omarchy shell once,
because the QML engine caches plugin code for the life of the process.

Drive the drawers from a Hyprland binding:

```
omarchy-shell omacale launcher | dashboard | session | sidebar | utilities | toggles | close
omarchy-shell omacale wallpapers | themes     # the launcher's carousels
```

## What it changes — and how it is undone

Omacale changes exactly four things (more only if you opt in: `cava`, the switcher), and records each before touching it:

| Thing | On install | On uninstall |
|---|---|---|
| `~/.config/omarchy/plugins/omacale.bar/` | created (an existing dir is set aside) | removed (your dir put back) |
| `bar.id` in `~/.config/omarchy/shell.json` | set to `omacale.bar` | put back to its previous value, or unset |
| `~/.config/omacale/` | not created (appears on your first settings change) | removed, or restored if it existed before; `--keep-settings` keeps it |
| `~/.local/state/omacale/` | snapshot of `shell.json` + install record | removed |
| `cava` package (optional) | installed only if you say yes | removed only if Omacale installed it |
| `~/.config/omarchy/extensions/omarchy-menu.jsonc` (optional) | untouched; turning on Settings › Style › Switcher adds a marked block that points the Background/Theme routes at Omacale (falling back to Omarchy's pickers when Omacale isn't running), turning it off removes it | the block is removed; a file (or folder) Omacale created is deleted again |

It never edits `~/.config/hypr`, themes, or anything under `/usr`. Transparency's
blur and "Try this session" keybinds are runtime-only Hyprland state; if
either is live at uninstall time, uninstall runs `hyprctl reload` to drop it. On uninstall,
if `shell.json` is otherwise unchanged it is restored **byte-for-byte** from the
snapshot; if you edited it in the meantime, only Omacale's entries are reverted
and your edits are kept. If `shell.json` did not exist before, it is removed
again. A failed install rolls itself back and leaves no state behind.

`tests/test-restore.sh` proves this in a throwaway `HOME` (37 checks: byte-exact
restore, later user edits, absent `shell.json`, a previously active custom bar,
a pre-existing plugin dir, dry-run, `--dev`, rollback on failure, settings
created/pre-existing/kept, the switcher's menu block with and without an
existing extension file, the keybinds file, and `omacale.lua` parsing).

## Not yet ported from Caelestia

OSD styling, lock screen, wallpaper-derived colours (the seed here is the theme
accent), and the "jelly" deformation drawers show while they move. Omarchy's
own OSD and lock screen keep working underneath.

## Credits and licences

Design, shader and assets from [caelestia-dots/shell](https://github.com/caelestia-dots/shell)
(GPL-3.0; the gifs in `assets/` come from it). Google Sans Flex and Rubik are
under the SIL Open Font License (`assets/fonts/*-OFL.txt`).
