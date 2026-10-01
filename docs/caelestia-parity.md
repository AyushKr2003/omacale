# Caelestia parity: what the C++ plugin does, and where Omacale stands

A survey of Caelestia's C++ plugin (`plugin/src/Caelestia/`, caelestia-dots/shell) against Omacale, made for the 0.43.0 change. Omacale can't ship a C++ plugin (it runs inside the Omarchy shell, with no build step), so every C++ piece has to be QML, a shader, a small script, or something Omarchy already provides.

## C++ plugin inventory

| Caelestia (C++) | What it does | Omacale |
|---|---|---|
| `Blobs/` (`blobgroup`, `blobrect`, `blobshape`, `blobinvertedrect`, `blobmaterial`) | SDF frame and drawers, corner fill, jelly deformation | `shaders/blob.frag`, `BlobSurface`, `BlobFill.js`, `BlobDeform`. Now ten rects (`r0`..`r9`); `r9` is the new OSD |
| `toaster` (`Toaster`, `Toast`) | Status toasts with type, timeout and view locks | **New:** `services/Toaster.qml`, a QML port, plus `Toasts` / `ToastItem` |
| `Components/buttonrow` | Connected M3 button groups | `ButtonRow.qml` |
| `Components/sparklineitem` | Resource graphs | `components/shapes/Sparkline.qml` |
| `Components/wavyline` | Media progress wave | `components/shapes/WavyLine.qml` |
| `Components/visualiserbars` | Audio visualiser bars | `VisualiserBars.qml` + `shaders/visualiser.frag` |
| `Components/circularindicatormanager`, `linearindicatormanager` | M3 indeterminate progress | `CircularProgress.qml`, `MProgress.qml`, `LoadingIndicator.qml` |
| `Components/animatedrepeater`, `lazylistview` | Animated / lazy lists | `MListView` / `FadeListView` with transitions; drawers are built on demand instead |
| `Config/` (`tokens`, `appearanceconfig`, the `*config` nodes) | Tokens and live settings | `core/Tk.qml`, `core/Config.qml`, `core/Defaults.js` |
| `Settings/` (schema, quarantine, batching) | Settings file with validation | `core/Config.qml` (JSON with defaults merged) |
| `Images/imageanalyser` | Wallpaper luminance for text colour | `core/WallLuminance.qml` |
| `Images/cachingimageprovider`, `imagecacher` | Thumbnail cache | Omarchy's `omarchy-theme-bg-cache` |
| `qalculator` | Launcher calculator (libqalculate) | `services/Calc.js` (own evaluator, same output forms) |
| `Services/cpu`, `memory`, `gpu`, `storage`, `diskinfo`, `sensorslib`, `networkusage` | Dashboard resources | `services/Sys.qml` + `scripts/gpu.sh` |
| `Services/cavaprovider`, `audiocollector`, `audioprovider` | Visualiser input | `scripts/cava.sh` |
| `Services/lyrics`, `lyriccandidate` | Synced lyrics | `scripts/lyrics.sh` |
| `Services/hyprdevices`, `hyprextras` | Keyboard layouts, Hyprland options | `services/KbService.qml`, Hyprland IPC |
| `Services/beattracker` | Beat-reactive visuals | Not ported (no Omacale feature uses it) |
| `Services/sessionmanager` | Logout / power | `omarchy system ...` |
| `Models/appdb` | App list with launch-frequency ranking | `services/AppService.qml` (Omarchy's filtered app list; no frequency ranking) |
| `Models/filesystemmodel` | Wallpaper folder listing, file dialog | `scripts/switcher.sh` (Omarchy's backgrounds); no file dialog |
| `I18n/` | Translations | Not ported (Omarchy is English-only) |
| `requests`, `cutils` | HTTP, misc helpers | `scripts/weather.sh`, inline JS |

## Caelestia features that were missing

| Feature | Status |
|---|---|
| Volume / brightness OSD (`modules/osd`) | **Added** in 0.43.0: `modules/osd/Osd.qml`, `FilledSlider`, `OsdService`, drawer `r9`, Settings › Panels › OSD |
| Utilities toasts (`modules/utilities/toasts`) | **Added** in 0.43.0, with Settings › Notifications › Toasts and IPC `toast` |
| Inline notification replies | Caelestia has none either, so this isn't a parity gap |
| Area picker / screenshot UI (`modules/areapicker`) | Not ported; Omarchy's `omarchy capture` already owns screenshots |
| Battery level warnings and hibernate (`BatteryMonitor`) | Not ported; Omarchy's battery service sends the warnings |
| VPN toggle and toasts | Not ported; Omarchy has no VPN service to back it |
| Nexus › Language and region | Not ported |

## The OSD and Omarchy

Omarchy's `omarchy.osd` is summoned in-process by the media keys and `BrightnessKeys`, so there is no event to listen to and no setting to turn it off for one kind. Two OSDs at once would be worse than none, so Omacale takes it over the same way it takes the notification toasts: a clone (`scripts/osd-handover`) patched to drop volume payloads and forward brightness ones to Omacale through a runtime file. It only does so while Omacale is the bar, the OSD is on in Settings, and nothing is fullscreen; otherwise the stock OSD draws. Every other kind (keyboard backlight, mic mute, ...) stays Omarchy's.

## Deviations

- The OSD and toasts are in the frame's `top`-layer window, so a fullscreen window covers them. Over fullscreen, the stock OSD draws instead; toasts don't show, and Caelestia's "show over fullscreen" option is omitted.
- The OSD clone drops Omarchy's volume message payloads (the device-switch text). The audio output/input toasts cover that.
- `m3success*` roles are added to `Colours` (Caelestia's success palette); with the Omarchy palette they come from the theme's green.

## Checked against Omarchy master

At omacom/omarchy `8b4eae6`, `notif-popups`' patch still applies to the notifications `Service.qml`, and `osd-handover`'s applies to `Osd.qml` (sha `dc7dc42c…`).
