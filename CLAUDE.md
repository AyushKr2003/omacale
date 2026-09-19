# CLAUDE.md — Omacale

Guidance for Claude Code when working on Omacale (`shell/omacale/`).

## What this is

Omacale is a **Caelestia-style desktop shell for Omarchy**, shipped as one Omarchy shell **bar plugin** (`omacale.bar`). We copy Caelestia's UI and UX; Omarchy is the engine underneath.

- **UI/UX source of truth:** `shell/caelestia_shell/` (a checkout of Caelestia). When something looks or feels different from Caelestia, Caelestia is right and Omacale is the bug.
- **Engine:** Omarchy (`/usr/share/omarchy`, source in `omarchy-repo/`). Data, actions and state come from Omarchy commands and state files.
- **Runtime:** inside the already-running Omarchy shell (Quickshell). **Never start a second Quickshell process.** No C++ build, no changes to the user's Hyprland config beyond the optional `keybinds.lua` snippet.

Other directories under `shell/` (`lacuna-shell`, `ruixen-shell`, `Shibumi-Shell`) are unrelated references. Don't pull from them unless asked.

## The two rules

### 1. Match Caelestia, don't approximate it

Before building or changing any UI, read the Caelestia original and port its structure, not just its look:

| Omacale | Caelestia original (`shell/caelestia_shell/`) |
|---|---|
| `Sidebar.qml` (+ inline `NotifDock`) | `modules/sidebar/Content.qml`, `NotifDock.qml` |
| `NotifGroup.qml`, `NotifItem.qml` | `modules/sidebar/NotifGroup.qml`, `Notif.qml`, `NotifActionList.qml` |
| `Utilities.qml` | `modules/utilities/Content.qml`, `Wrapper.qml` |
| `QuickToggles.qml` | `modules/utilities/cards/Toggles.qml` |
| `IdleInhibitCard.qml` | `modules/utilities/cards/IdleInhibit.qml` |
| `RecordCard.qml`, `RecordingList.qml` | `modules/utilities/cards/Record.qml`, `RecordingList.qml` |
| `ButtonRow.qml`, `IconButton.qml` | `plugin/src/Caelestia/Components/buttonrow.cpp`, `components/controls/ButtonBase.qml`, `IconButton.qml` |
| `SplitSelect.qml` | `components/controls/SplitButton.qml` |
| `StateLayer.qml`, `Anim.qml`, `CAnim.qml` | `components/StateLayer.qml`, `Anim.qml`, `CAnim.qml` |
| `Tk.qml` | Caelestia `Tokens` (`plugin/src/Caelestia/Config/tokens.hpp`, `appearanceconfig.hpp`) |
| `Colours.qml` | Caelestia `Colours` (M3 palette from the Omarchy theme accent) |
| `ScreenScope.qml` + `shaders/blob.frag` | `modules/drawers/` (`Panels.qml`, `Backgrounds`) and its `blob.frag` |
| `Dashboard.qml`, `Launcher.qml`, `Session.qml`, `Settings.qml` (Nexus) | `modules/dashboard`, `launcher`, `session`, `nexus` |

Conventions that keep the port faithful:

- **Use `Tk.*` tokens for every size, gap, radius, font and duration.** Never hardcode a pixel value that Caelestia gets from `Tokens` (`Tk.padding.large`, `Tk.rounding.medium`, `Tk.spacing.small`, `Tk.body.medium`, ...).
- **Use `Colours.m3*` for colours** (`m3surfaceContainer`, `m3onSurfaceVariant`, ...). Never hardcode colours.
- **Motion goes through `Anim { type: ... }` / `CAnim`**, using Caelestia's curves and durations. Don't use raw `NumberAnimation` unless porting a specific Caelestia animation that does.
- **Keep Caelestia's structure**: same card order, same nesting, same margins (`Tokens.padding.large` insets, `Layout.topMargin` tricks, `nonAnimHeight` / animated `implicitHeight`). Copy the arithmetic, including odd bits like `padding.extraLargeIncreased`.
- **Drawers are shader shapes.** A drawer's background is not a QML item. It is a rect (`r0`..`r6`) fed to `blob.frag` in `ScreenScope.qml`, with an attach-edge bitmask. The drawer's QML (`Sidebar`, `Utilities`, ...) draws only its content, inset by `padding.large` (minus the frame border on the frame side).
- If Caelestia has a feature Omarchy can't back (e.g. recorder pause), **omit it** rather than faking it, and note it in the README/PR.

### 2. Omarchy is the engine; write our own script only when Omarchy has nothing

Order of preference when Omacale needs data or needs to do something:

1. **An Omarchy command or shell IPC**: `omarchy <group> <action>`, `omarchy-*` binaries in `/usr/share/omarchy/bin`, `omarchy-shell <target> <fn>`.
2. **Omarchy state/config files**: `~/.local/state/omarchy/...`, `~/.config/omarchy/...`.
3. **Quickshell built-ins**: `Quickshell.Services.Pipewire`, `Bluetooth`, `Mpris`, `UPower`, Hyprland IPC.
4. **Our own script**, only if 1-3 don't cover it. Put it in `omacale.bar/scripts/`, keep it small and read-only where possible, and say in a comment why Omarchy doesn't provide it.

Engine hooks Omacale already uses (reuse them, don't reinvent):

| Feature | Omarchy hook |
|---|---|
| Notifications | reads `~/.local/state/omarchy/notifications/` (+ `history/`), DND in `notifications.json`; `omarchy toggle notification silencing`; `omarchy-shell notifications dismiss/clear` |
| Keep awake | `~/.local/state/omarchy/indicators/stay-awake`, `omarchy-shell idle enable/disable` |
| Screen recording | `omarchy capture screenrecording [--stop-recording]` |
| Night light | `omarchy toggle nightlight`, state in `~/.local/state/omarchy/toggles/nightlight` |
| Power / session | `omarchy system lock/logout/reboot/shutdown` |
| Theme | `omarchy theme set`, `omarchy-theme-*` (Colours re-seed from the theme accent) |
| Bar hide | `omarchy toggle bar`; `omarchy.bar` IPC `syncHidden` |
| Launching UIs | `omarchy-launch-wifi/bluetooth/audio/vpn/editor` |
| Keybinds | `o.bind(...)` in `~/.config/hypr/bindings.lua` (see `omacale.bar/keybinds.lua`) |

Current own scripts (`omacale.bar/scripts/`), each filling a real gap: `notifs.py` (merge Omarchy's notification JSON into one list), `weather.sh`, `gpu.sh`, `lyrics.sh`, `cava.sh`. Before adding another, check `omarchy-repo/bin`, `omarchy-repo/shell` and `/usr/share/omarchy/bin`.

## Layout

```
shell/omacale/
  omacale.bar/        the plugin (this is what gets installed)
    Bar.qml             plugin entry: IpcHandler "omacale", per-screen ScreenScope, fonts
    ScreenScope.qml     per-monitor: frame + drawers geometry, input mask, gestures
    shaders/blob.frag   SDF frame/drawer background; blob.frag.qsb is the compiled output
    Tk.qml Colours.qml Config.qml Defaults.js   tokens, palette, live settings
    *Service.qml / GameMode.qml / Sys.qml       singletons wrapping Omarchy data
    scripts/            our own helper scripts (last resort)
    assets/  keybinds.lua  manifest.json  qmldir
  scripts/omacale     installer / uninstaller (records + restores exact prior state)
  install.sh uninstall.sh  tests/test-restore.sh  README.md
```

- **Every QML type must be registered in `omacale.bar/qmldir`** (`Name 1.0 Name.qml`; singletons as `singleton Name 1.0 Name.qml`), or it will be "unavailable".
- **IPC** is the `omacale` target in `Bar.qml`: `launcher`, `dashboard`, `session`, `settings`, `sidebar`, `utilities`, `toggles`, `dashboardTab(tab: string)`, `close`. IPC functions **must have typed args and `: void` return** or Quickshell drops the whole target. Call with `omarchy-shell omacale <fn>` (or `qs -p /usr/share/omarchy/shell ipc call omacale <fn>`).
- Shader change: edit `blob.frag`, then rebuild the `.qsb` and commit both:
  `/usr/lib/qt6/bin/qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o shaders/blob.frag.qsb shaders/blob.frag`

## Dev loop (verifying UI changes)

The shell loads the plugin from `~/.config/omarchy/plugins/omacale.bar` (a copy, unless installed with `--dev`, which symlinks).

```bash
cd ~/omarchy-dotfiles/shell/omacale/omacale.bar
rsync -a ./ ~/.config/omarchy/plugins/omacale.bar/       # sync source -> installed copy
omarchy-restart-shell                                     # clean restart (see gotcha below)
qs -p /usr/share/omarchy/shell ipc call omacale sidebar   # open a drawer (calls TOGGLE, don't double-call)
grim -g "1400,0 520x1080" /tmp/shot.png                   # screenshot the right edge, then look at it
qs log -p /usr/share/omarchy/shell 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -iE "WARN|ERROR"
qs -p /usr/share/omarchy/shell ipc call omacale close     # put the drawers away
```

Always screenshot and read the log; "no errors" without a screenshot proves little, and the reverse too.

### Gotchas that have bitten us

- **A QML load error silently keeps the OLD UI**, and after a restart the shell **falls back to the stock `omarchy.bar`** ("bar option omacale.bar failed to load"). Live auto-reload ("Local plugin changed, reloading") does not report the error clearly. If a change doesn't show up, `omarchy-restart-shell` and read the log for `Type X unavailable` / `Invalid property assignment`.
- **`Behavior on` a `readonly` property is a load error.** Make it a plain `property`.
- Row/Column with a child whose width depends on the parent's `implicitWidth` causes `polish() loop` warnings; give the child its natural width.
- A Repeater whose `model` array is rebuilt on every state change destroys its delegates (lost presses, lost expanded state). Keep models static and look state up from the delegate, or store UI state in a singleton (see `NotifService.expandedApps`).
- `omacale` IPC calls **toggle**; a second call closes the drawer.
- `'r6' / 'join' does not have a matching property` in the log is harmless: `Settings.qml` and `StylePreview.qml` reuse `blob.frag.qsb` without those uniforms, which then default to zero.
- Don't drive real notifications/recording in tests destructively: `RecordService.remove`, `NotifService.clearAll` and `dismiss` delete real files.

## Style for new code

- Match the surrounding QML: 2-space indent, `Tk`/`Colours` tokens, `MText`/`MIcon` for text/icons (`MText.weight`, not `font.weight`), `StateLayer` for interactive surfaces, `IconButton` for round buttons.
- Comments explain *why* or which Caelestia file is being ported, not what the line does. Reference the Caelestia file in a header comment for each ported component.
- Prefer editing an existing Omacale component over adding a parallel one.

## Git

Commit only when asked. Commit messages follow the repo's style (`fix: ...`, `feat: ...`). Don't commit `shell/caelestia_shell` changes; it's a reference checkout.
