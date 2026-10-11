# Changelog

What changed in each version of Omacale, newest first. Versions are the ones in `manifest.json`. Each version bump adds its own entry in the same commit.

## 0.49.0 - 2026-10-11

### Added
- **style**: Omacale's wallpaper and theme pickers open from every entry point (Settings, the `:` menu, the binds), and **From wallpaper** builds a whole Omarchy theme from your wallpaper with aether (#12)
- **colours**: The Omarchy palette matches Omarchy's own panels exactly, light or dark by Omarchy's rule; a custom seed is dropped on a theme switch unless you turn that off (#13)
- **colours**: Opt-in: Omarchy's own menus, popups and notifications in Omacale's Material colours (#14)
- **screens**: With several screens, each bar has its own edge or none, and the desktop clock, toasts and OSD can be kept to the screens you choose (#15)
- **display**: Settings › Display (Super+Ctrl+D): arrangement, resolution and scale, profiles, a display menu, brightness per screen, night light, workspaces per screen (#16)
- **taskbar**: One list for the whole bar, with Omarchy's own widgets in it, a chevron to tuck items behind, and joined pills (#17)

### Fixed
- **icons**: App icons show when the GTK icon theme isn't installed (#11)
- **install**: An upgrade checks the icon font too (#18)

## 0.48.1 - 2026-10-11

### Fixed
- **install**: Reselect the bar and honor --dev on upgrade

## 0.48.0 - 2026-10-11

### Added
- **bar**: Hide third-party widgets from the bar (#7)
- **bar**: Noctalia-style bar layout -- start/center/end sections, drag and drop in Settings › Taskbar › Layout (#8)
- **session**: Omarchy-ready session menu -- Super+Esc / power key, Lock, Screensaver, your own picture (#9)

## 0.45.7 - 2026-10-11

### Fixed
- **notifs**: Install the notification handover when popups are on

## 0.45.6 - 2026-10-11

### Fixed
- **launcher**: Keep the launcher out of its own screenshot

## 0.45.5 - 2026-10-11

### Fixed
- **visualiser**: Run cava whenever the bars are shown

## 0.45.4 - 2026-10-05

### Fixed
- **dashboard**: Only reuse the GPU name for the adapter it came from

## 0.45.3 - 2026-10-04

### Added
- **hypr**: Jelly windows on the drawers' spring

## 0.45.2 - 2026-10-04

### Fixed
- **bar**: Show web apps with the browser glyph, not the terminal

## 0.45.1 - 2026-10-04

### Fixed
- **lock**: Caelestia's unlock, drawn above the lock

## 0.45.0 - 2026-10-03

### Added
- **lock**: Play the unlock animation, mirrored from the opening

## 0.44.4 - 2026-10-03

### Fixed
- **overview**: Grow from its own centre, or slide out of its edge

## 0.44.3 - 2026-10-02

### Fixed
- **overview**: Settings' detach motion for the overview

## 0.44.2 - 2026-10-02

### Fixed
- **settings**: Caelestia's Nexus size, colours and detach motion

## 0.44.1 - 2026-10-02

### Fixed
- Own file dialog for the profile picture, not GTK's

## 0.44.0 - 2026-10-01

### Added
- Caelestia's OSD and toasts for every Omarchy OSD, with a hardened OSD handover

## 0.43.5 - 2026-10-01

### Fixed
- Load notification images from local files only

## 0.43.4 - 2026-10-01

### Fixed
- Draw notification bodies without fetching anything

## 0.43.3 - 2026-10-01

### Fixed
- Validate the server on new 802.1X Wi-Fi profiles

## 0.43.2 - 2026-10-01

### Fixed
- Never pass notification or file values through a shell

## 0.43.1 - 2026-10-01

### Fixed
- Move the plugin to the repository root

## 0.43.0 - 2026-10-01

### Added
- Size bar popouts to Caelestia's widths, list nearby Wi-Fi

## 0.42.0 - 2026-10-01

### Added
- Refine the whole UI against Caelestia, pixel by pixel

## 0.41.0 - 2026-09-30

### Added
- **drawers**: Caelestia's blob corner fill, jelly and bounce

## 0.40.0 - 2026-09-30

### Added
- **bar**: Setting to hide the clock entirely

## 0.39.1 - 2026-09-30

### Fixed
- **bar**: Hovering another tray icon shows that icon's menu

## 0.39.0 - 2026-09-29

### Added
- **launcher**: Clipboard rows in the style of Caelestia PR #1298, with a delete button each

## 0.38.7 - 2026-09-29

### Fixed
- **launcher**: Clipboard text preview keeps the same space below the text as above

## 0.38.6 - 2026-09-29

### Added
- **launcher**: Clipboard text preview is only as tall as its text, up to the launcher

## 0.38.5 - 2026-09-29

### Fixed
- **launcher**: Clipboard image preview is never taller than the launcher

## 0.38.4 - 2026-09-29

### Added
- **launcher**: Clipboard preview panel takes the image's aspect ratio

## 0.38.3 - 2026-09-29

### Fixed
- **launcher**: Clipboard preview on the panel's own surface, no inner background

## 0.38.2 - 2026-09-29

### Fixed
- **launcher**: Clipboard preview shows only the entry, no header, buttons or key hints

## 0.38.1 - 2026-09-29

### Added
- **launcher**: Clipboard preview in its own panel beside the launcher, as Caelestia PR #1298

## 0.38.0 - 2026-09-29

### Added
- **launcher**: Clipboard history as a launcher mode, >clipboard, backed by Omarchy's clipboard

## 0.37.1 - 2026-09-28

### Added
- **bar**: With a bottom bar, utilities on top and the notification sidebar under it

## 0.37.0 - 2026-09-28

### Added
- **bar**: Put the bar on any edge: left, right, top, bottom, or follow Omarchy

## 0.36.1 - 2026-09-28

### Fixed
- **bar**: Keep the frame and drawers when the bar is hidden or a window is maximized

## 0.35.12 - 2026-09-27

### Added
- **launcher,settings**: Omarchy-style scroll fade with the selection kept clear of it

## 0.35.11 - 2026-09-27

### Fixed
- **overview**: Hide the workspace number behind window previews

## 0.35.10 - 2026-09-27

### Fixed
- **settings**: Match Nexus nav colour, search gap and card header spacing

## 0.35.9 - 2026-09-27

### Fixed
- Snap centred drawers to whole pixels so faded lists stay sharp

## 0.35.8 - 2026-09-27

### Fixed
- **settings**: Frame the panel in the bar's surface colour

## 0.35.7 - 2026-09-27

### Fixed
- Keep the keyboard focus ring on its control's shape

## 0.35.6 - 2026-09-27

### Fixed
- Scale the settings panel with the UI scale, as the lock card is

## 0.35.5 - 2026-09-27

### Fixed
- Keep spacing, padding and icons on the pixel grid at fractional UI scales

## 0.35.4 - 2026-09-26

### Fixed
- Work on stable Omarchy 4.0.x

## 0.35.3 - 2026-09-26

### Added
- The clock's calendar icon gives way first on a short bar

## 0.35.2 - 2026-09-26

### Fixed
- The mouse wheel scrolls an overfull plugin pill and tray

## 0.35.1 - 2026-09-26

### Fixed
- Short screens keep the clock, status icons and power on the bar

## 0.35.0 - 2026-09-26

### Added
- Install.sh upgrades an existing install in place

## 0.34.6 - 2026-09-26

### Fixed
- Upgrading repairs a lock handover that failed to load

## 0.34.5 - 2026-09-26

### Fixed
- Lock screen loads on stable Omarchy 4.0.x

## 0.34.4 - 2026-09-26

### Fixed
- Lock handover loads on Omarchy before the OWE lock feed

## 0.34.3 - 2026-09-25

### Added
- **launcher**: Show both wallpapers when there are exactly two

## 0.34.2 - 2026-09-25

### Fixed
- The keep awake switch toggles keep awake again

## 0.34.1 - 2026-09-25

### Fixed
- Robust drawer keyboard navigation in the dashboard and sidebar

## 0.34.0 - 2026-09-25

### Added
- Hyprland gaps and window rounding follow the UI scale

## 0.33.1 - 2026-09-25

### Fixed
- A slightly larger active window title in the bar

## 0.33.0 - 2026-09-25

### Added
- A UI scale, following Omarchy's font size by default

## 0.32.1 - 2026-09-24

### Fixed
- A mouse nudge no longer takes the keyboard from a drawer mid-navigation

## 0.32.0 - 2026-09-24

### Added
- Keyboard control for the dashboard, sidebar, utilities and settings

## 0.31.0 - 2026-09-24

### Added
- Bar focus mode with keyboard tray menus

## 0.30.0 - 2026-09-24

### Added
- Key navigation inside every popout, with an M3 focus ring

## 0.29.0 - 2026-09-24

### Added
- Omarchy's panel hotkeys open Omacale popouts with the keyboard

## 0.28.1 - 2026-09-24

### Added
- Upstream-check drift report and tolerant notification reading

## 0.28.0 - 2026-09-24

### Added
- Handovers rebuild from Omarchy on update, with a health watchdog and automatic fallback

## 0.27.3 - 2026-09-24

### Fixed
- Lock screen draws video backgrounds as poster + live feed

## 0.27.2 - 2026-09-24

### Fixed
- Window shadow matches Omacale's frame shadow

## 0.27.1 - 2026-09-24

### Fixed
- Installer adds the Material Symbols icon font when missing

## 0.27.0 - 2026-09-24

### Added
- Pending Omarchy update status icon

## 0.26.1 - 2026-09-23

### Added
- Wider, adjustable gap for the detached overview

## 0.26.0 - 2026-09-23

### Added
- Detached option for the top/bottom overview

## 0.25.0 - 2026-09-23

### Added
- Overview position setting: top, middle or bottom

## 0.24.0 - 2026-09-23

### Added
- Desktop clock and audio visualiser on the wallpaper

## 0.23.0 - 2026-09-23

### Changed
- Build drawers on demand, as Caelestia does

## 0.22.2 - 2026-09-23

### Fixed
- Keep the recordings list in step with the folder

## 0.22.1 - 2026-09-23

### Fixed
- Show mic_off on the muted quick toggle

## 0.22.0 - 2026-09-23

### Added
- Window info panel

## 0.21.0 - 2026-09-23

### Added
- Launcher calculator

## 0.20.0 - 2026-09-23

### Added
- Keyboard layout status icon and popout

## 0.19.0 - 2026-09-23

### Added
- Wi-Fi password popout

## 0.18.0 - 2026-09-23

### Changed
- Stop polling for things nothing is looking at

## 0.17.0 - 2026-09-23

### Changed
- Lay omacale.bar out like Caelestia

## 0.16.3 - 2026-09-23

### Fixed
- Hide the apps Omarchy hides

## 0.16.2 - 2026-09-23

### Fixed
- Drop the active window title when a special is toggled away

## 0.16.1 - 2026-09-23

### Fixed
- Match the drawers' velocity, not just their curve

## 0.16.0 - 2026-09-23

### Added
- Give Hyprland windows the drawers' motion

## 0.15.2 - 2026-09-22

### Fixed
- **bar**: Stop hosted panels being cut off

## 0.15.1 - 2026-09-22

### Fixed
- **bar**: Keep a pinned widget in the bar when it paints nothing

## 0.15.0 - 2026-09-22

### Added
- **bar**: Manage a crowded bar

## 0.14.1 - 2026-09-22

### Added
- **launcher**: Fade the list's edges while it can scroll

## 0.14.0 - 2026-09-22

### Added
- **overview**: Layered window icon fallbacks

## 0.13.0 - 2026-09-22

### Added
- **settings**: Plugins page to manage Omarchy plugins

## 0.12.16 - 2026-09-22

### Fixed
- **bar**: Host many 3rd-party widgets robustly

## 0.12.15 - 2026-09-22

### Fixed
- **bar**: Size 3rd-party widgets like the status icons

## 0.12.14 - 2026-09-22

### Added
- Restate o.rebind helper in keybinds.lua

## 0.12.4 - 2026-09-21

### Added
- Apply concentric corner radii to overview workspace and window cards

## 0.12.3 - 2026-09-21

### Added
- Align overview workspace card and window preview border radii

## 0.12.0 - 2026-09-20

### Added
- Walk the Omarchy menu in the launcher with ":"

## Before 0.12.0 - 2026-09-19

### Added
- The first port of Caelestia to Omarchy: the shader-drawn frame and drawers, the bar, dashboard, launcher, sidebar, quick toggles, network and Bluetooth settings, and the Settings app.
