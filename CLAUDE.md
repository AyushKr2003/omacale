# CLAUDE.md — Omacale

Guidance for Claude Code when working on Omacale (`shell/omacale/`).

## What this is

Omacale is a **Caelestia-style desktop shell for Omarchy**, shipped as one Omarchy shell **bar plugin** (`omacale.bar`). We copy Caelestia's UI and UX; Omarchy is the engine underneath.

- **UI/UX source of truth:** `shell/caelestia_shell/` (a checkout of Caelestia). When something looks or feels different from Caelestia, Caelestia is right and Omacale is the bug.
- **Engine:** Omarchy (`/usr/share/omarchy`, source in `omarchy-repo/`). Data, actions and state come from Omarchy commands and state files.
- **Runtime:** inside the already-running Omarchy shell (Quickshell). **Never start a second Quickshell process.** No C++ build, no changes to the user's Hyprland config beyond the optional `keybinds.lua` and `omacale.lua` snippets.

Other directories under `shell/` (`lacuna-shell`, `ruixen-shell`, `Shibumi-Shell`) are unrelated references. Don't pull from them unless asked.

## The two rules

### 1. Match Caelestia, don't approximate it

Before building or changing any UI, read the Caelestia original and port its structure, not just its look:

| Omacale | Caelestia original (`shell/caelestia_shell/`) |
|---|---|
| `Sidebar.qml` (+ inline `NotifDock`) | `modules/sidebar/Content.qml`, `NotifDock.qml` |
| `NotifGroup.qml`, `NotifItem.qml` | `modules/sidebar/NotifGroup.qml`, `Notif.qml`, `NotifActionList.qml` |
| `NotifPopups.qml` (stack + `ExtraIndicator`), `NotifToast.qml` | `modules/notifications/Content.qml`, `Wrapper.qml`, `Notification.qml`, `components/widgets/ExtraIndicator.qml` |
| `Utilities.qml` (+ inline delete dialog) | `modules/utilities/Content.qml`, `Wrapper.qml`, `RecordingDeleteModal.qml` |
| `QuickToggles.qml` | `modules/utilities/cards/Toggles.qml` |
| `IdleInhibitCard.qml` | `modules/utilities/cards/IdleInhibit.qml` |
| `RecordCard.qml`, `RecordingList.qml` | `modules/utilities/cards/Record.qml`, `RecordingList.qml` |
| `ButtonRow.qml`, `IconButton.qml` | `plugin/src/Caelestia/Components/buttonrow.cpp`, `components/controls/ButtonBase.qml`, `IconButton.qml` |
| `SplitSelect.qml` | `components/controls/SplitButton.qml` |
| `MSwitch.qml`, `MSlider.qml`, `CircularProgress.qml`, `MTextField.qml`, `OutlinedField.qml` | `components/controls/StyledSwitch.qml`, `StyledSlider.qml`, `CircularProgress.qml`, `TextFieldBase.qml`, `StyledTextField.qml` (outlined) |
| `MFlickable.qml`, `MListView.qml`, `FadeFlickable.qml`, `FadeListView.qml`, `MScrollBar.qml` | `components/containers/StyledFlickable.qml`, `StyledListView.qml`, `VerticalFadeFlickable.qml`, `VerticalFadeListView.qml`, `components/controls/StyledScrollBar.qml` |
| `Elevation.qml` | `components/effects/Elevation.qml` |
| `StateLayer.qml`, `Anim.qml`, `CAnim.qml` | `components/StateLayer.qml`, `Anim.qml`, `CAnim.qml` |
| `PopoutContent.qml` (one component per bar popout; `wirelesspassword` and `winfo`, like `traymenu`, are sticky, and hold the keyboard: see `ScreenScope.popoutSticky` / `popoutHeld`) | `modules/bar/popouts/Content.qml`, `Network.qml`, `WirelessPassword.qml`, `kblayout/KbLayout.qml`, `Bluetooth.qml`, `Battery.qml`, `AudioPopout.qml`, `LockStatus.qml`, `TrayMenu.qml`, `ActiveWindow.qml` |
| `Workspaces.qml`, `SpecialWorkspaces.qml`, `ActiveIndicator.qml` | `modules/bar/components/workspaces/Workspaces.qml`, `SpecialWorkspaces.qml`, `ActiveIndicator.qml` |
| `WindowInfo.qml`, `WinfoPreview.qml`, `WinfoDetails.qml`, `WinfoButtons.qml` (the held `winfo` popout, detached from `activewindow`; also IPC `windowInfo`) | `modules/windowinfo/WindowInfo.qml`, `Preview.qml`, `Details.qml`, `Buttons.qml`, and `bar/popouts/Wrapper.qml` `detach("winfo")`. One deliberate difference: Kill closes the panel, since it follows the active window and would otherwise turn to the next one |
| `KbService.qml` | `modules/bar/popouts/kblayout/KbLayoutModel.qml`, the layout half of `services/Hypr.qml` |
| `Tk.qml` | Caelestia `Tokens` (`plugin/src/Caelestia/Config/tokens.hpp`, `appearanceconfig.hpp`) |
| `Colours.qml` | Caelestia `Colours` (M3 palette from the Omarchy theme accent; or, with Settings › Style › Palette › Omarchy, the theme's own colours on the M3 roles) |
| `WallLuminance.qml` | Caelestia's `ImageAnalyser` (`plugin/src/Caelestia/Images/imageanalyser.cpp`), feeding `Colours.wallLuminance` |
| `ScreenScope.qml` + `shaders/blob.frag` | `modules/drawers/` (`Panels.qml`, `Backgrounds`) and its `blob.frag` |
| `Dashboard.qml`, `Launcher.qml`, `Session.qml`, `Settings.qml` (Nexus) | `modules/dashboard`, `launcher`, `session`, `nexus` |
| `LockUi.qml`, `LockContent.qml` | `modules/lock/LockSurface.qml`, `Content.qml` |
| `LockCenter.qml`, `LockPassword.qml`, `LockMessage.qml` | `modules/lock/Center.qml`, `center/Clock.qml`, `ProfilePic.qml`, `PasswordInput.qml`, `InputField.qml`, `StateMessage.qml` |
| `LockWeather.qml`, `LockFetch.qml`, `LockMedia.qml`, `LockResources.qml`, `LockNotifs.qml` | `modules/lock/WeatherInfo.qml` (+ `weather/`), `Fetch.qml`, `Media.qml`, `Resources.qml`, `NotifDock.qml` |
| `NetworkPage.qml`, `NetworkDetail.qml` | `modules/nexus/pages/NetworkPage.qml`, `common/NetworkList.qml`, `network/NetworkDetailPage.qml` |
| `BluetoothPage.qml`, `BtPairing.qml`, `BtDevice.qml`, `BtDeviceRow.qml` | `modules/nexus/pages/BluetoothPage.qml`, `bluetooth/BluetoothPairing.qml`, `BtDeviceInfo.qml` |
| `AudioPage.qml`, `AppVolumes.qml`, `AudioDeviceList.qml`, `AudioSlider.qml`, `AudioService.qml` | `modules/nexus/pages/AudioPage.qml`, `audio/AppVolumes.qml`, `common/AudioDeviceList.qml`, `SliderRow.qml`, `services/Audio.qml` |
| `WallpaperGrid.qml` (Settings `wallpapers` / `themes` sub-pages; Settings › Wallpaper & style itself is the colours page from `SettingsModel.js`) | `modules/nexus/pages/WallpaperAndStyle.qml`, `wallandstyle/WallpaperSelect.qml`, `common/WallItem.qml` |
| `AppsPage.qml`, `AllApps.qml`, `AppInfo.qml` | `modules/nexus/pages/AppsPage.qml`, `apps/AllApps.qml`, `apps/AppInfo.qml` |
| `TrayIcons.qml`, `PinnedPlugins.qml` (Settings › Taskbar › Tray / Plugins) | no Caelestia original for the pinning; the hidden-tray list is Caelestia's `bar.tray.hiddenIcons` given a UI |
| `PluginsPage.qml`, `PluginInfo.qml`, `PluginService.qml` | no Caelestia original: Settings › Plugins follows Shibumi's plugin catalog (`hancore.shibumi.control-center/PluginCatalogPage.qml`), drawn with Nexus rows like `AllApps` / `AppInfo` |
| `IconTextButton.qml` | `components/controls/IconTextButton.qml` |
| `KeyNav.qml` (+ the cursor in `PopoutContent.qml`, `StateLayer.focused`) | no Caelestia original (its popouts are pointer-only): Omarchy's `Ui/PanelKeyCatcher.qml` keys, drawn with M3's focus state (the hover veil at 10%, the switch's circle around its handle, the slider's pressed handle) plus M3's focus indicator, `FocusRing`: a 3px `m3secondary` outline 2px outside the control, following its radius. The veil alone was too faint to find the cursor |
| `ItemList.qml`, `RowButton.qml`, `InfoRow.qml`, `RowToggle.qml`, `BigButton.qml` | `modules/nexus/common/ItemList.qml`, `RowButton.qml`, `InfoRow.qml`, `ToggleRow.qml`, `components/controls/ButtonBase.qml` |
| `services/Calc.js` (+ the `>calc ` mode and calc row in `Launcher.qml`) | `modules/launcher/items/CalcItem.qml`, `AppList.qml` (calc state). Caelestia's engine is libqalculate (`plugin/src/Caelestia/qalculator.cpp`); `Calc.js` is our own evaluator, since Omarchy has none, and prints the same `parsed = result` / `error: ...` forms |
| `WallpaperList.qml`, `WallpaperItem.qml` (+ the `>wallpaper `/`>theme ` modes in `Launcher.qml`) | `modules/launcher/WallpaperList.qml`, `items/WallpaperItem.qml`, `ContentList.qml` |
| `Wallpapers.qml` | `services/Wallpapers.qml`, `modules/launcher/services/Schemes.qml` |
| `MenuService.qml` (+ the `:` mode in `Launcher.qml`) | no Caelestia original: the Omarchy menu, drawn as launcher rows. The engine is Omarchy's own `MenuModel.js`, loaded in place -- see below |
| `Overview.qml`, `OverviewWindow.qml` | no Caelestia original: the workspace overview is ported from the `omarchy-overview` plugin and redrawn in Caelestia's tokens. Its live preview follows Caelestia's `modules/windowinfo/Preview.qml` (a `ScreencopyView` inside a clipping rect). Window icons come from `WindowIcons.qml`, the plugin's fallback chain (`services/FallbackIcon.qml`, `OverviewWindow.iconName`: TUI from the title, web-app class, class, initial class, titles, themed name, default terminal/browser) plus exact matches on Omarchy's web-app URLs and `TUI.*` commands |
| `Background.qml`, `DesktopClock.qml`, `Visualiser.qml`, `VisualiserBars.qml` + `shaders/visualiser.frag` (Settings › Panels › Desktop) | `modules/background/Background.qml`, `DesktopClock.qml`, `Visualiser.qml`, `plugin/src/Caelestia/Components/visualiserbars.cpp`. The wallpaper stays Omarchy's, so each piece is its own `bottom`-layer surface sized to what it draws, the plate/bar blur is a Hyprland layer rule (`Bar.applyDesktopBlur`), and the bars are one shader quad rather than a QPainter texture. Surfaces on a layer stack in creation order: the visualiser is parked at 1px (never destroyed) while auto-hidden, and the clock is (re)created after it so it stays on top |
| `omacale.bar/omacale.lua` | caelestia-dots `hypr/variables.lua`, `hypr/hyprland/animations.lua`, `decoration.lua`, `general.lua`, `rules.lua` (a separate repo, not in `caelestia_shell/`) |

Conventions that keep the port faithful:

- **Use `Tk.*` tokens for every size, gap, radius, font and duration.** Never hardcode a pixel value that Caelestia gets from `Tokens` (`Tk.padding.large`, `Tk.rounding.medium`, `Tk.spacing.small`, `Tk.body.medium`, ...).
- **Use `Colours.m3*` for colours** (`m3surfaceContainer`, `m3onSurfaceVariant`, ...). Never hardcode colours. The `m3surface*` roles are Caelestia's `tPalette` (transparency applied). Where Caelestia writes `Colours.palette.m3surfaceX`, use Omacale's opaque `Colours.palette.m3surfaceX`, and port `Colours.layer(Colours.palette.m3surfaceX, n)` as is; `Colours.layer(c)` of any opaque role gives its `tPalette` value.
- **Use the ported primitives**, not raw Qt ones: `MText` (sets Caelestia's `opsz` axis; give title/headline/label.large/medium text `weight: Font.Medium` as Caelestia's font tokens do), `MTextField` for any text input, `MFlickable`/`MListView`/`FadeFlickable`/`FadeListView` for scroll views (no `StopAtBounds`), `MScrollBar` where Caelestia has `StyledScrollBar`.
- **Motion goes through `Anim { type: ... }` / `CAnim`**, using Caelestia's curves and durations. Don't use raw `NumberAnimation` unless porting a specific Caelestia animation that does.
- **Keep Caelestia's structure**: same card order, same nesting, same margins (`Tokens.padding.large` insets, `Layout.topMargin` tricks, `nonAnimHeight` / animated `implicitHeight`). Copy the arithmetic, including odd bits like `padding.extraLargeIncreased`.
- **Drawers are shader shapes.** A drawer's background is not a QML item. It is a rect (`r0`..`r7`) fed to `blob.frag` in `ScreenScope.qml`, with an attach-edge bitmask (`attachA` for `r0`..`r3`, `attachB` for `r4`..`r7`). Adding a drawer means adding a rect to the shader and recompiling the `.qsb`; `r4` (Settings) and `r7` (the overview) are the floating, centred ones, with an attach of 0 and the frame's scrim behind them. The drawer's QML (`Sidebar`, `Utilities`, ...) draws only its content, inset by `padding.large` (minus the frame border on the frame side).
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
| Notification popups | the live files above are the toast stack, one per toast on screen, each carrying the `deadline` the daemon expires it on; `omarchy-shell notifications popupsHidden/pause/resume/dismissKey/invokeKey/dismissAll` (the last four keyed by the file stem). All of it needs the headless daemon clone -- see below |
| Wi-Fi / ethernet (`NetService`) | `Quickshell.Networking` (NetworkManager) as Omarchy's `plugins/panels/network`; `omarchy-network-status --verbose` for link details; `omarchy-shell shell summon omarchy.wifiqr` to share |
| Bluetooth (`BtService`) | `Quickshell.Bluetooth` as Omarchy's `plugins/panels/bluetooth`; `omarchy-bluetooth-power on/off`, `omarchy-bluetooth-device pair/connect/disconnect/forget` |
| Audio (`AudioService`) | `Quickshell.Services.Pipewire` as Omarchy's `plugins/panels/audio`; `omarchy-audio-sink-availability`, `omarchy-audio-output-sink` (volume on the sink behind a tuning), `omarchy-audio-{output,input}-set-default` |
| Default apps (Settings › Apps) | `omarchy-default-{terminal,browser,editor}` (no arg prints the current one) |
| Bar scroll volume / brightness | `omarchy-audio-output-volume +N`, `omarchy-brightness-display +N%` (Omarchy's OSD and sink resolution) |
| Keep awake | `~/.local/state/omarchy/indicators/stay-awake`, `omarchy-shell idle enable/disable` |
| System update (`UpdateService`) | `omarchy-update-available` every 6h (exit 0 = pending), `omarchy-launch-floating-terminal-with-presentation omarchy-update` detached, re-checked once `$XDG_RUNTIME_DIR/omarchy-update.lock` is free |
| Screen recording | `omarchy capture screenrecording [--stop-recording]` |
| Night light | `omarchy toggle nightlight`, state in `~/.local/state/omarchy/toggles/nightlight` |
| Power / session | `omarchy system lock/logout/reboot/shutdown` |
| Lock screen (`LockService`) | Omarchy's `omarchy.lock` plugin, cloned and given Omacale's view by `omacale.bar/scripts/lock-screen`; its service keeps the `WlSessionLock`, PAM, the blank timers and the `lock` IPC. `omarchy-shell lock preview` / `hidePreview` is the dev loop |
| Theme | `omarchy theme set`, `omarchy-theme-*` (Colours re-seed from the theme accent) |
| Wallpaper / theme switcher (`Wallpapers`) | `omarchy-theme-bg-set`, `omarchy-theme-set`; live preview via `omarchy-shell background set`; thumbnails from Omarchy's `omarchy-theme-bg-cache` (`~/.cache/omarchy/image-selector`) |
| Omarchy menu (`MenuService`) | `$OMARCHY_PATH/default/omarchy/omarchy-menu.jsonc` + `~/.config/omarchy/extensions/omarchy-menu.jsonc`, parsed, searched and guarded by Omarchy's own `shell/plugins/menu/MenuModel.js`, which is loaded in place (never copied) |
| Plugins (`PluginService`, Settings › Plugins) | `omarchy plugin list --json` (enabled, canDisable, clonedFrom) + `omarchy-plugin-catalog` (manifests); `omarchy plugin enable/disable/add/update/remove`. Enable/disable only rewrite `shell.json`; add/update/remove write into the plugins folder, which reloads Omacale, so they run detached and reopen `settingsPage plugins`. Omacale's own lock/notification clones are shown but locked |
| Keyboard layouts (`KbService`) | no Omarchy command: Hyprland's `getoption input:kb_layout`, `devices` (re-read on the `activelayout` event), `switchxkblayout all <i>`; names from `/usr/share/X11/xkb/rules/base.lst` |
| Bar hide | `omarchy toggle bar`; `omarchy.bar` IPC `syncHidden` |
| Panel hotkeys (`SUPER+CTRL+A/B/W/P`, `1..9`) | the host's bar contract, implemented in `Bar.qml`: `summonBarWidget` / `hideBarWidget` / `isBarWidgetOpen` / `panelWidgetIdAt` (+ `switchPanelFrom` via the facade). `widgetTargets` maps Omarchy ids to Omacale popouts; audio (`onBar`) only opens while its icon is on the status bar. Unmapped on purpose, so their hotkeys do nothing: `omarchy.monitor`, and `omarchy.clock`/`omarchy.weather` (`SUPER+CTRL+ALT+D`; the dashboard has its own binds). `panelWidgetIdAt` (`SUPER+CTRL+1..9`) counts only the third-party widgets in the plugin pill, top to bottom, whatever the section; Tab from a hosted panel cycles those too. Also IPC `omacale popout <name>` |
| Launching UIs | `omarchy-launch-editor`, `omarchy-launch-browser`, ... (there is no `omarchy-launch-wifi`/`-bluetooth`; use the settings pages above) |
| Keybinds | `o.bind(...)` in `~/.config/hypr/bindings.lua` (see `omacale.bar/keybinds.lua`) |
| Look'n'feel | `hl.config` / `hl.curve` / `hl.animation` / `o.window` in `omacale.bar/omacale.lua`, loaded by the user from `~/.config/hypr/looknfeel.lua` with `pcall(dofile, ...)` |

Current own scripts (`omacale.bar/scripts/`), each filling a real gap: `notifs.py` (merge Omarchy's notification JSON into one list), `weather.sh`, `gpu.sh`, `lyrics.sh`, `cava.sh`, `switcher.sh` (lists the backgrounds/themes Omarchy's pickers show, since Omarchy only feeds them to its own image menu; `menu off` only removes a menu-route block older versions wrote). Before adding another, check `omarchy-repo/bin`, `omarchy-repo/shell` and `/usr/share/omarchy/bin`.

## Layout

The plugin mirrors Caelestia's own layout, so the port table above maps onto
directories: a Caelestia file under `modules/sidebar/` is ported to Omacale's
`modules/sidebar/`.

```
shell/omacale/
  omacale.bar/        the plugin (this is what gets installed)
    Bar.qml             plugin entry: IpcHandler "omacale", per-screen ScreenScope, fonts.
                        Stays at the root: it is the manifest's entryPoint and the
                        qmldir beside it is what makes the whole module resolve
    qmldir  manifest.json  keybinds.lua  omacale.lua
    core/               Tk Colours Config Defaults.js WallLuminance -- tokens, palette,
                        live settings; everything else reads these
    services/           singletons wrapping Omarchy data: Sys, GameMode, Wallpapers,
                        WindowIcons and the *Service ones (Audio, Bt, Net, Notif,
                        Record, Idle, Lock, Plugin, Menu, App)
    components/         shared primitives: MText MIcon Anim StateLayer SectionHeader ...
      controls/           IconButton MSwitch MSlider MTextField ButtonRow SplitSelect ...
      containers/         MFlickable MListView FadeFlickable FadeListView
      effects/            Elevation ShaderMaskEffect
      shapes/             MShape ShapeGeom.js ConnectedRect WavyLine Sparkline
    modules/            one directory per feature, as Caelestia does
      bar/                BarContent BarWidgetSlot PluginBarFacade PopoutContent
        workspaces/         Workspaces SpecialWorkspaces ActiveIndicator
      drawers/            ScreenScope: per-monitor frame + drawer geometry, input mask,
                          gestures, plus the overlay-layer window the toasts live in
      background/         desktop clock + visualiser (bottom-layer surfaces, not drawers)
      dashboard/ launcher/ sidebar/ notifications/ utilities/ lock/ overview/ session/
      settings/           Settings SettingsPage SettingsModel.js
        rows/               Row* -- the settings row types
        common/             ItemList RowButton InfoRow RowLabel
        cards/              StylePreview SeedPicker LogoPicker Keybinds/Lock/LookNFeel/About
        pages/              Network Bluetooth Audio Apps Plugins Wallpaper Tray ...
    shaders/blob.frag   SDF frame/drawer background; blob.frag.qsb is the compiled output.
                        Stays at the root: three modules at three depths load it
    scripts/            our own helper scripts (last resort)
    scripts/lock-screen   hands Omarchy's lock plugin its Caelestia view (Settings runs it)
    scripts/notif-popups  clones Omarchy's notification daemon and patches the clone headless
    scripts/handover.py   shared by both: rebuild a clone from stock, health checks
    assets/lock/LockView.qml  the wrapper written into the lock clone
    assets/
  scripts/omacale     installer / uninstaller (records + restores exact prior state)
  scripts/gen-logos.py  dev-only: regenerates components/Logos.js (needs fontTools)
  scripts/upstream-check  dev-only: which Omarchy files Omacale depends on changed (tests/upstream.lock)
  install.sh uninstall.sh  tests/test-restore.sh  README.md
```

- **Every QML type must be registered in `omacale.bar/qmldir`**, with its path
  (`Name 1.0 modules/bar/Name.qml`; singletons as `singleton Name 1.0 services/Name.qml`),
  or it will be "unavailable". The qmldir is flat: type names are unique across the whole
  plugin regardless of directory, so moving a file only changes its qmldir line.
- **Every file outside the root needs `import ".."` back to the module**, with one `..`
  per level (`import "../../.."` from `modules/settings/pages/`). A file only implicitly
  sees its *own* directory, so without that import every `Tk`, `Colours` and `MText` in it
  is unavailable. Siblings in the same subdirectory resolve twice (implicitly and through
  the qmldir); that is not ambiguous and needs nothing.
- **Relative URLs resolve against the file's own directory.** `Qt.resolvedUrl("scripts/x")`
  in `services/` must be `"../scripts/x"`. That covers `scripts/`, `assets/`, `shaders/`,
  `omacale.lua` and `keybinds.lua`.
- **`SettingsPage.qml` loads its rows, cards and pages by path, not by type** (the `files`
  map), so those paths are relative to `modules/settings/` and must be updated when one of
  them moves -- a type rename alone won't do it. A wrong path fails as a bare
  "No such file or directory" with no type name.
- **IPC** is the `omacale` target in `Bar.qml`: `launcher`, `dashboard`, `session`, `settings`, `sidebar`, `utilities`, `toggles`, `overview`, `dashboardTab(tab: string)`, `settingsPage(page: string)`, `popout(name: string)`, `barFocus`, `wallpapers`, `themes`, `menu`, `windowInfo`, `close`. IPC functions **must have typed args and a typed return (`: void`, `: string`, ...)** or Quickshell drops the whole target. Call with `omarchy-shell omacale <fn>` (or `qs -p /usr/share/omarchy/shell ipc call omacale <fn>`).
- **`components/Logos.js` is generated.** To add or change a bar logo, edit `OPTIONS` in `scripts/gen-logos.py` and rerun it (`pip install fonttools` in a venv). It stores trimmed outlines that `LogoIcon` rasterises as SVG at whole-pixel sizes; don't draw logos as font glyphs or scaled Shapes, which pad, fringe and blur at bar size.
- Shader change: edit the `.frag` (`blob.frag`, `visualiser.frag`), then rebuild its `.qsb` and commit both:
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

After every `omarchy update`, run `scripts/upstream-check`. It compares the Omarchy files Omacale reaches into (the cloned plugins, `BackgroundMedia`, `MenuModel.js`, the launcher hides, `PluginBarApi`/`KeyboardPanel`) and the members the host calls on a custom bar (`shell.bar.*`, `bar.*(` in `shell/Ui`) with `tests/upstream.lock`, and names the Omacale area to re-test for each change. Once re-tested, `--record` and commit the lock. A reach-in added to Omacale belongs in its `DEPENDS` list.

### Gotchas that have bitten us

- **A QML load error silently keeps the OLD UI**, and after a restart the shell **falls back to the stock `omarchy.bar`** ("bar option omacale.bar failed to load"). Live auto-reload ("Local plugin changed, reloading") does not report the error clearly. If a change doesn't show up, `omarchy-restart-shell` and read the log for `Type X unavailable` / `Invalid property assignment`.
- **`Behavior on` a `readonly` property is a load error.** Make it a plain `property`.
- **Never name a property `on<Capital>...`** (e.g. `onSpecial`). QML treats `on<Capital>` as a signal-handler prefix: it loads without a warning, but in the Omarchy shell bindings to it never updated, even though Caelestia's `Workspaces.qml` uses that name. Rename it (`inSpecial`).
- Row/Column with a child whose width depends on the parent's `implicitWidth` causes `polish() loop` warnings; give the child its natural width.
- A Repeater whose `model` array is rebuilt on every state change destroys its delegates (lost presses, lost expanded state). Keep models static and look state up from the delegate, or store UI state in a singleton (see `NotifService.expandedApps`).
- **`Repeater.itemAt()` is not a binding dependency, and `count` is the model size before the delegates exist.** A binding that resolves a delegate (`rep.itemAt(activeIndex)`) gets `null` on its first evaluation and then never re-runs unless one of its *other* dependencies changes. At login the workspaces active pill was invisible for that reason -- nothing moved `activeId`, so the binding stayed null until the first workspace switch. Have the delegates bump a counter in `Component.onCompleted` and read it in the binding (`Workspaces.listGen`, `SpecialWorkspaces.listGen`).
- `omacale` IPC calls **toggle**; a second call closes the drawer.
- `'r6' / 'join' does not have a matching property` in the log is harmless: `Settings.qml` and `StylePreview.qml` reuse `blob.frag.qsb` without those uniforms, which then default to zero.
- **Qt's `hh` is only 12-hour when the same format string has `AP`.** `Qt.formatTime(d, "hh")` alone is 24-hour. Use `Sys.hour(d)` / `Sys.time(d)`, never a bare `"hh"`.
- A PathView/ListView bound to a plain JS array resets `currentIndex` when the array is reassigned, after any `onValuesChanged` handler has run. Set the index in `onModelChanged` (see `WallpaperList.recentre`).
- Hyprland animation leaves set explicitly by Omarchy's `looknfeel.lua` (`fadeIn`, `fadeLayersIn`, ...) don't inherit a parent leaf you set later; override them by name (see `omacale.lua`).
- **`notifs.py` normalizes every record** to the fields and defaults of Omarchy's `NotificationLogic.historyEntry` and passes unknown fields through; a record it can't read is skipped, never the whole list. A format change is logged once per process. `NotifService.readDnd` likewise warns once if `notifications.json` isn't `version: 3`.
- Don't drive real notifications/recording in tests destructively: `RecordService.remove`, `NotifService.clearAll` and `dismiss` delete real files. `switcher.sh menu off` edits the real `~/.config/omarchy/extensions/omarchy-menu.jsonc`; test it with `HOME` pointed at a scratch dir.
- **The menu engine is loaded, not vendored.** `omarchy.menu` has no data IPC (only toggle/summon/close/refresh), but its engine is plain JS with no shell dependencies, so `MenuService` builds a wrapper with `Qt.createQmlObject(src, root, "file://$OMARCHY_PATH/shell/plugins/menu/<anything>.qml")` -- that URL is what resolves the wrapper's relative `import "MenuModel.js"`, and the file it names never has to exist. Do it that way, not with a top-level `import`: a missing Omarchy would then be a QML load error, which takes the whole bar down with it. Search order, scoring and route resolution stay Omarchy's. What can't be read from Omarchy is its `providers` map (a property of the plugin Item), so `fonts` and `power-profiles` are restated in `MenuService` and have to be kept in step; `apps` is backed by the launcher's own `DesktopEntries` list.
- **The `when:`/`checked:`/`disabled:` guards are one bash run** built by the engine (`guardScript`), and it queries pacman -- the better part of a second. The menu draws on the last answers and redraws when the new ones land, and `MenuService` won't re-run it more than once every 5s, so typing `:` over and over doesn't.
- **Don't write to Omarchy's menu extension (`omarchy-menu.jsonc`).** The user doesn't want Omacale inserting anything there; the old Style › Switcher block was removed for this reason.
- **The lock plugin caches `LockUi.qml`.** Editing it and rsyncing does nothing until the shell restarts (the lock clone's Loader holds the compiled component). `omarchy-restart-shell`, then `omarchy-shell lock preview` — which is also the only safe way to look at the lock, since nothing but the real password can dismiss a real one. Preview passes `inputEnabled: false` and an empty `passwordText`, so the field cannot be typed into there.
- **A workspace switch takes the keyboard off the panel; take the focus grab again.** Hyprland gives the keyboard to a window on the workspace you switch to, and to *nothing at all* when that workspace is empty -- an `OnDemand` layer surface is never offered it back, so a panel that switches workspaces stops receiving keys (it looked like "focus leaves after a few presses", and an empty workspace killed it outright). `WlrKeyboardFocus.Exclusive` keeps the keys, but when it is dropped Hyprland restores focus to the last window and drags its workspace back with it, so a panel that closed on an empty workspace bounced you off it. What works is OnDemand plus re-taking the `HyprlandFocusGrab` after every switch: `ScreenScope.regrab()` (clear `active`, rebind it a frame later), which `Overview.walk()` calls on each arrow press.
- **Never hide a parent on its children's `visible`.** A child's `visible` reads its *effective* visibility, so a container hidden because its children report hidden latches hidden forever. Collapse the child to zero size instead (Column skips it), and if the container must leave a layout, hide an empty placeholder and draw the container on top of it -- see `pluginPlace` / `pluginPill` in `BarContent.qml`. Zero-size items and negative `Layout` margins do *not* drop ColumnLayout spacing.
- **Hosted 3rd-party widgets are scaled, not restyled.** `BarWidgetSlot` lays each one out in Omarchy's units (`Bar.pluginBarSize`) and scales by `Bar.pluginIconScale` so its mark matches the status icons; a short wide label is turned 90°, a long one gets a category icon. Their text is switched to `Text.CurveRendering`: Native and distance-field text both take GTK's subpixel AA (via `QT_QPA_PLATFORMTHEME=gtk3`) and fringe red/blue once turned, and a layer doesn't stop it.
- **Any write inside `~/.config/omarchy/plugins/` reloads every plugin, and a reload unloads the whole custom bar** (`pluginBarLoader.active: !shell.pluginReloading`), so a plugin that writes into its own folder makes Omacale flicker forever (daz.toggl-track logs there). Find the writer with `inotifywait -m -r ~/.config/omarchy/plugins/`; that is the plugin's bug, reported upstream, not worked around here (see "Scope"). Hosted widgets are created with `bar`/`moduleName`/`settings` as initial properties (not a Loader) so their `onCompleted` sees real settings, and the plugin list only changes identity when its contents do, so a registry bump doesn't rebuild every widget.
- **The bar's crowding is one shared budget, not a cap per group.** The active window title is the flexible space; `BarContent.budget` is `title + tray + plugins - titleMin`, which is invariant to what they collapse to, so the budget can't oscillate. Over budget, the tray goes compact (`trayOverBudget`) and the plugin pill scrolls. A pinned widget that paints nothing (an indicator whose service is stopped, e.g. the location widget) keeps its cell with a dimmed stand-in that opens it, since it would otherwise be missing with no way to reach its panel; unpinned, it collapses. Pinning stores the *unpinned* ids (`bar.plugins.unpinned`), so the default (empty) needs no seeding -- a pinned list would have to be written before the plugin registry finishes loading, and would miss the late ones.
- **The pointer leaving the bar reaches nothing.** The window's input mask means no event arrives, and Qt keeps the hover state (`containsMouse` never goes false, `HoverHandler.hovered` never clears). `ScreenScope.updatePointer()` is the one path for popouts and the collapsible groups; while a group is open it is also fed by polling `hyprctl cursorpos` (Quickshell has no cursor API). A poll that restarts a collapse timer shorter than the poll interval never fires -- start it only when it isn't running.
- **A hosted panel's geometry is wrong because it measures the bar by its window.** Omarchy's `Ui/KeyboardPanel` takes its bar width from the anchor window, which for Omacale is the whole screen, so the card's x, the room it thinks is left for the card (`screenW - barW - gap - margin`, which clamps to its 120px floor and cuts the content off) and the click-forwarding "bar strip" are all wrong. `gap` is the one writable term in all three, so `BarWidgetSlot` binds it to `Tk.barWidth + spacing - barW`: every sum comes out right, and it degrades to a plain gap if the anchor window is ever bar-sized. Don't hardcode a card width instead -- each panel asks for its own (380-560 across Omarchy's own panels).
- **Drawers are built on demand and destroyed after they close**, as Caelestia's Wrappers do (`Loader { active: open || visible }` in `ScreenScope`; the handles `dash`, `launch`, `sess`, `util`, `nexus`, `overviewContent`, `sidebarPanel` are `null` while closed). Kept loaded they cost ~150 MB idle. Three traps when touching them: (1) `onActiveChanged` *does* fire when a drawer is created open (the `active` binding lands after the default), so never add a `Component.onCompleted: if (active)` twin -- the dashboard's `Sys.resourcesWanted` hold was taken twice that way and stats polled forever; (2) a `Loader` is a focus scope, so a drawer that takes keys needs `focus: <open>` on its Loader, and its own `forceActiveFocus()` deferred with `Qt.callLater` (it isn't in the window yet during creation); (3) inside the inline component, a drawer's own `scope` property shadows ScreenScope's id -- use `screenScope`. State that should survive a close (dashboard tab, settings page) lives on the scope (`dashTab`, `nexusPage`, `nexusStack`). Memory freed on close stays with the process (glibc keeps its heap), so the saving is largest before the drawers are first used.
- **A keyboard-opened popout is held (`ScreenScope.popoutKeys`) and primes focus.** `win` is always mapped, so OnDemand alone never hands it the keyboard: `primeFocus()` sets Exclusive for 120ms, then OnDemand plus `pop.forceActiveFocus()`, as Omarchy's `KeyboardPanel` does. That Exclusive→OnDemand switch **clears the `HyprlandFocusGrab`**, which used to `closeAll()` the popout the moment it opened; for 400ms after a prime (`primeSettle`) a cleared grab is re-taken instead. Pointer-opened popouts never set `popoutKeys`, so hover/click stay Caelestia's.
- **Keyboard navigation is a cursor over `navTarget`s, not `activeFocus` per control.** `PopoutContent.navTargets()` walks the page for items with `navTarget` (`StateLayer`, `MSwitch`, `MSlider`) in reading order on every key; `step()` moves by index, so a Repeater rebuilding rows under it (networks, devices) costs only the highlight. Enter/Space call `navActivate()` (`StateLayer` ripples and emits `clicked(null)`, so an `onClicked` that reads its mouse argument would break -- keep them argument-free), Left/Right call `navAdjust()` where there is one. Page keys are `navText(t)` on the page's root and `navDelete()` on a row. A destroyed cursor target is replaced by whatever now sits at `cursorIndex` (`cursorRestore`), so a refresh doesn't drop the highlight. `focused` is only set while `keyMode`, so the pointer never sees it. Controls only count once visible, a few frames into the popout's entry, so the first stop is found by `cursorSeek`, not at load.
- **The drawers share one keyboard cursor, `ScreenScope`'s `drawerNav` (`NavCursor`).** The dashboard opened by shortcut (`dashShortcut`), the sidebar, and utilities opened by shortcut (`utilShortcut`) make `drawerKeys` true, which primes the keyboard onto `drawerKeyItem`; hover-opened drawers never take keys. The cursor moves *spatially* (h/l sideways across cards and grids, j/k up and down), walks only each drawer's `navRoots` (the dashboard's are the tab bar and the page on show -- its other tabs sit clipped beside it in the strip), reveals stops in vertical Flickables, and appears on the first key rather than on open, so mouse users never see it. The sidebar and utilities share a panel, so while the sidebar is open utilities is a root too. Settings keeps its own focus and Escape, and hands every other key to `drawerKey` through `keyHook`. A switch whose whole row is the toggle (`RowToggle`) sets `MSwitch.inRow`, so the row is the one stop. A stop can act on focus alone (`navOnFocus`): the dashboard's tabs open as the cursor lands on them, the first key lands on the current tab rather than the first, and a tab change keeps a cursor that is still on the tab bar (`onRootsChanged` only clears a cursor outside the new roots). Drawer keys: Tab / 1..4 dashboard tabs, `n`/`p` media, `d` DND and Shift+X clear all in the sidebar, `x` dismisses a notification or group and deletes a recording (through its dialog), `/` search and Backspace back in Settings.
- **The bar focus mode (`SUPER+CTRL+0`, IPC `barFocus`) is `ScreenScope.barFocus` plus `BarContent.navStops()`.** Stops are rebuilt on every key, top to bottom (logo, workspace cells via `Workspaces.navItems()`, active window, plugin-pill slots, tray items, clock, status icons, power), each with its `act`. The cursor is one pill in `BarContent` (`barCursor`) that moves between them, not a focus state per item: Caelestia's workspace `ActiveIndicator` stretch (the leading edge on defaultSpatial, the trailing one 1.5x slower), drawn as an M3 focus indicator (2px `m3primary` outline, 14% tint), `Tk.barInner` wide so it sits on the pills, and hugging its item's height. Anything that opens a drawer or a hosted panel leaves bar focus first (`leaveFor`, `openPlugin`); a popout opened from it is `popoutKeys`, and Escape there (`popout = ""`) gives the keys back to the bar. A workspace switch from the bar goes through `ScreenScope.switchWorkspace`, which re-takes the grab Hyprland clears on the switch (`wsSettle`) instead of reading it as a click away. The compact tray and plugin overflow open while the cursor is in them.
- **`Sys.activeToplevel` is null right after a shell restart** until Hyprland sends a focus event, so the active window counts as absent (bar says "Desktop", `togglePanelAt left 1` finds nothing) until focus moves once.
- **The toasts are not a drawer.** Every other panel is a rect in `blob.frag` inside `win`, which is on Hyprland's `top` layer — a fullscreen window covers it and it hides with the bar. Notifications must never be hidden, so `ScreenScope` gives them a second `PanelWindow` on `WlrLayer.Overlay` (namespace `omacale-notifications`), with each toast a card of its own. Anything that must outlive fullscreen belongs there, not in the frame — and remember to add the namespace to a rule that matches `omacale` (the blur rule in `Bar.qml` does).

## The notification daemon clone

Omarchy's `omarchy.notifications` service owns the D-Bus name *and* draws the toasts, a second notification server is not allowed beside it, and Hyprland 0.56 has no layer rule that can hide a surface. So Omacale can only draw toasts if that daemon gives its window up.

`omacale.bar/scripts/notif-popups install` does it the supported way: `omarchy plugin clone omarchy.notifications` (which disables the stock plugin, enables the clone and routes IPC to it), then a small idempotent patch of the clone.

- The patch replaces the popup-UI block with a headless lifetime manager and adds IPC. **The expiry timer used to live inside the toast delegate**, so deleting the window without replacing that timer leaves every popup on screen forever.
- The clone writes `deadline` into each live popup file, so the daemon's timer and Omacale's countdown ring run off one clock. Omacale never invents a deadline when one is there.
- `notif-popups` refuses to patch a `Service.qml` it doesn't recognise rather than half-edit the notification daemon, and a refused sync leaves the working clone exactly as it is (`status` says `patch: refused`); `tests/test-restore.sh` cases P and R cover that. If `omarchy update` reshapes the popup UI, update the anchors in that script, re-test the toasts, and set `VERIFIED_AGAINST` to the new stock `Service.qml` sha.
- The patch is always applied to a **fresh** copy of stock `Service.qml`, never on top of the last patched one; every other stock file is copied verbatim (see "Handovers follow Omarchy updates").
- `NotifService.popupsSupported` comes from the clone's `popupsHidden` IPC, and Omacale draws nothing without it — that is what stops two toasts appearing at once. Don't bypass the gate.
- Install records `installedNotifClone`; uninstall runs `notif-popups remove` **before** `restore_shell_json`, because `omarchy plugin remove` writes `shell.json` too and the snapshot has to be the last word on it.
- Don't hand-delete the clone directory: `omarchy plugin remove` is what takes `omarchy.notifications` back out of `disabledPlugins[]`. Removing the directory alone leaves no notification daemon at all.

## Handovers follow Omarchy updates

Both clones are build artifacts: `scripts/handover.py` rebuilds them from `/usr/share/omarchy` plus our delta (every stock file copied, files upstream removed deleted, the manifest's `schemaVersion`/`kinds`/`keepLoaded`/`entryPoints`/`omarchy.capabilities` taken from stock, identity kept). `status` reports `stale:` and `stale-files:` against exactly that.

- **`services/Handover.qml` is the watchdog** (`LockService` and `NotifHandover` are instances of it). It runs the script's `watchdog` 20s after start, 5s after a watched stock file changes, and when `UpdateService` sees an update it launched finish. `watchdog` re-syncs a stale clone (the lock only while unlocked), then health-checks it: lock = `lock status` with `passwordPam: true` (a live lock counts as healthy); notifications = `ping` and `popupsHidden`. A failure is retried at 0/3/8s, and "the shell itself isn't answering" is `unknown`, never a failure -- a plugin that hasn't registered its IPC yet is not broken.
- **A failed health check hands the plugin back to Omarchy automatically** (`remove`), sets `<lock|notifs>.autoFellBack` in Config so the next start doesn't reinstall into the same fault, and sends a notification. Installing from Settings clears it. Fail safe, never fail closed.
- **The stock files are replaced, not edited, by pacman**, so the `FileView` watches point at unlinked inodes afterwards; `Handover` recreates them (`watchers.active` off and on) after every change.
- Both services are `keepLoaded`, so a re-sync writes the new files but the running service is replaced on the next shell restart; Settings says so.
- **No post-update hook.** Omacale must work standalone, so it never writes into `~/.config/omarchy/hooks/`.
- **The handover scripts live in the plugin, so they must not write bytecode there**: `sys.dont_write_bytecode` before importing `handover`, and `tests/test-restore.sh` exports `PYTHONDONTWRITEBYTECODE`. A `__pycache__` under `~/.config/omarchy/plugins` reloads every plugin.

## The lock screen handover

Omarchy's `omarchy.lock` service owns the session lock, PAM, the stranded-lock recovery, the blank-on-idle timers and the `lock` IPC that `omarchy system lock`, `omarchy-system-sleep-lock` and the lid binding call. A second `WlSessionLock` is not allowed beside it, and none of that is worth reimplementing, so Omacale takes only the view.

`omacale.bar/scripts/lock-screen install` does it the supported way: `omarchy plugin clone omarchy.lock`, then, in the clone, Omarchy's `Service.qml` copied in verbatim, its view kept as `StockLockView.qml`, and `LockView.qml` replaced by `assets/lock/LockView.qml`.

- **`Service.qml` is never patched**, only copied, so every `install` re-syncs the clone with the installed Omarchy. `status` reports `stale: yes` when they differ, and `scripts/omacale doctor` checks it.
- **The wrapper imports nothing from Omacale.** It loads `LockUi.qml` by URL and falls back to `StockLockView` when the setting is off, Omacale is gone, or the UI fails to load. A relative import would turn a broken Omacale into a machine with no lock screen. Keep it that way.
- **The wrapper is versioned (`omacale:lock-view vN`), and moving `LockUi.qml` means bumping it.** The wrapper lives in the *clone*, written at install time, so an already-installed machine keeps the old one across an upgrade — and because it loads the UI by URL, a stale wrapper doesn't error, it just silently draws the stock lock. `lock-screen status` prints both the installed `view:` and the `expects:` that this Omacale would write, and `LockService.installed` requires them to match, so a mismatch re-installs the handover by itself. Bump `MARKER` in `scripts/lock-screen` and the marker on line 1 of `assets/lock/LockView.qml` together, whenever the wrapper's content changes. The clone's Loader caches the compiled view, so the re-install applies on the *next* shell restart.
- **The contract is checked before any write**: every property and signal handler the stock `Service.qml` sets on its `LockView` must exist on the wrapper, or the script refuses (`tests/test-restore.sh` case Q covers both directions). Adding a property upstream means updating `assets/lock/LockView.qml`, and `LockUi.qml` if it wants it.
- **`LockUi.qml` reaches everything through `view`** (the wrapper) and never assumes it is set: the Loader assigns it a frame late.
- **Video backgrounds are a poster plus OWE's feed**, as in the stock view: the shell's `BackgroundMedia` draws stills only, so `LockUi` gives it `view.videoPosterPath` and loads the live feed from `view.feedSurfaceUrl` (the clone's `LockFeedSurface.qml`, `import Owe.LockFeed`). The feed is never blurred. In `lock preview` screenshots only the poster shows, for the stock view too; the moving feed is only visible on a real lock.
- The install and the removal both apply live — the shell enables the clone and reloads plugin files itself — so neither restarts the shell. `LockService` runs them and is what Settings › Panels › Lock screen drives; `Config.o.lock.enabled` alone decides which view draws, so turning Omacale off never tears anything down mid-lock.
- Uninstall runs `lock-screen remove` **before** `restore_shell_json`, for the same reason as the notification clone: `omarchy plugin remove` writes `shell.json` too.

## Scope: what Omacale changes, and what it doesn't

- **Everything Omacale needs lives in this repo.** Don't edit files outside `shell/omacale/` (the user's `~/.config/hypr/*.lua`, `autostart.lua`, `shell.json` by hand, other dotfiles) to make Omacale work. Hyprland-side settings go in `omacale.bar/omacale.lua` (look'n'feel, env) or `omacale.bar/keybinds.lua` (binds), which the user loads themselves -- and only when there is no way to do it inside the shell.
- **Host plugins generically; don't special-case one.** Hosting fixes must hold for any well-behaved Omarchy widget (sizing, visibility, teardown, settings at creation). When a single third-party plugin misbehaves because of its own bug (writes into its plugin folder, reads settings too early, ...), say so and leave it -- there can be hundreds of plugins, and per-plugin compat code doesn't scale. No plugin names in Omacale code.

## Style for new code

- Match the surrounding QML: 2-space indent, `Tk`/`Colours` tokens, `MText`/`MIcon` for text/icons (`MText.weight`, not `font.weight`), `StateLayer` for interactive surfaces, `IconButton` for round buttons.
- Comments explain *why* or which Caelestia file is being ported, not what the line does. Reference the Caelestia file in a header comment for each ported component.
- Prefer editing an existing Omacale component over adding a parallel one.

## Versioning

The version lives in `omacale.bar/manifest.json`, `scripts/omacale` (`VERSION`) and the fallback in `Bar.qml`; bump all three together (minor for features, patch for fixes).

**Bump it on every change that reaches the user, without being asked** -- a fix, a feature, anything that changes what the shell does. A docs-only or comment-only change doesn't need one.

## Git

Omacale is its own repo (`AyushKr2003/omacale`), checked out as the `shell/omacale` submodule of omarchy-dotfiles, which fetches it on `install.sh`. Commit and push inside `shell/omacale`, then commit the moved submodule pointer in omarchy-dotfiles.

**Commit finished work without being asked**: once a change is done and verified, bump the version and commit it, in `shell/omacale` first and then the submodule pointer in omarchy-dotfiles. Don't push unless asked.

Commit messages follow the repo's style (`fix: ...`, `feat: ...`), with the version bump in the same commit as the change it belongs to. Don't commit `shell/caelestia_shell` changes; it's a reference checkout.
