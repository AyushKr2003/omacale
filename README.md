# Omacale

A [Caelestia](https://github.com/caelestia-dots/shell)-style desktop shell for
[Omarchy](https://omarchy.org), built as a single Omarchy shell **bar plugin**
(`omacale.bar`). It runs inside the Omarchy shell you already have — no second
Quickshell process, no C++ build, no changes to Hyprland config.

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
- **Bar.** Caelestia's default order: tinted logo; workspaces as M3 shapes
  (a random expressive shape for the focused one, square with app icons for
  occupied, dot for empty) with the trailing active pill; rotated window
  title; tray; clock; status pill (network, Bluetooth and its devices,
  battery or power profile, caps/num lock); power.
- **Hover popouts.** Wi-Fi list with connect/disconnect, Bluetooth toggles
  and devices, battery with the power-profile switch, tray menus with
  submenus, and a live preview of the active window.
- **Dashboard.** Opens on hover at the top edge. Tabs: Dashboard (weather,
  user card, Rubik clock, calendar with a "sunny" today marker, CPU/RAM/disk
  rings, media with arc progress and bongo cat), Media, Performance, Weather.
- **Launcher.** Bottom drawer: search pill, 7 results, keyboard navigation;
  `>` lists Omarchy actions.
- **Session.** Right drawer: logout, shutdown, kurukuru, hibernate, reboot.
  Opens from the power button or by dragging in from the right edge.

## Install / uninstall

```bash
./install.sh            # or: scripts/omacale install
./uninstall.sh          # or: scripts/omacale uninstall
scripts/omacale status  # what's installed, what uninstall will restore
scripts/omacale doctor
scripts/omacale install --dry-run
scripts/omacale install --dev   # symlink the plugin for live editing
scripts/omacale install --no-restart   # skip the shell restart after install
```

Requires Omarchy with the shell running, `jq`, and the *Material Symbols Rounded*
font (`ttf-material-symbols-variable`). Install restarts the Omarchy shell once,
because the QML engine caches plugin code for the life of the process.

Drive the drawers from a Hyprland binding:

```
omarchy-shell omacale launcher | dashboard | session | close
```

## What it changes — and how it is undone

Omacale changes exactly three things, and records each before touching it:

| Thing | On install | On uninstall |
|---|---|---|
| `~/.config/omarchy/plugins/omacale.bar/` | created (an existing dir is set aside) | removed (your dir put back) |
| `bar.id` in `~/.config/omarchy/shell.json` | set to `omacale.bar` | put back to its previous value, or unset |
| `~/.local/state/omacale/` | snapshot of `shell.json` + install record | removed |

It never edits `~/.config/hypr`, themes, or anything under `/usr`. On uninstall,
if `shell.json` is otherwise unchanged it is restored **byte-for-byte** from the
snapshot; if you edited it in the meantime, only Omacale's entries are reverted
and your edits are kept. If `shell.json` did not exist before, it is removed
again. A failed install rolls itself back and leaves no state behind.

`tests/test-restore.sh` proves this in a throwaway `HOME` (25 checks: byte-exact
restore, later user edits, absent `shell.json`, a previously active custom bar,
a pre-existing plugin dir, dry-run, `--dev`, rollback on failure).

## Not yet ported from Caelestia

Notification sidebar, utilities drawer, OSD styling, lock screen, the
settings app ("Nexus"), wallpaper-derived colours (the seed here is the theme
accent), and the "jelly" deformation drawers show while they move. Omarchy's
own notifications, OSD and lock screen keep working underneath.

## Credits and licences

Design, shader and assets from [caelestia-dots/shell](https://github.com/caelestia-dots/shell)
(GPL-3.0; the gifs in `assets/` come from it). Google Sans Flex and Rubik are
under the SIL Open Font License (`assets/fonts/*-OFL.txt`).
