# Taskbar apps

Settings › Taskbar › Apps enables a dock inside the existing bar. It is **off
by default**, and no app entry is instantiated while it is off. It neither
reconfigures nor disables Omarchy's separate dock.

## Using it

- **Pin apps** opens a searchable picker of apps visible to Omarchy and Omacale's
  launcher. An app can also be pinned from Settings › Apps › All apps › App info.
- **Import launcher favourites** copies the current list. Later edits to either
  list are independent.
- **Add a group** creates a named container; **Choose apps** edits its members.
  The bar shows up to four small app icons. Click it for a scrollable app list.
- **Add a folder** pins an absolute directory path, or one starting with `~/`.
  Its name is optional. It opens in the default file manager. This is a directory
  shortcut, separate from the app containers above.
- Move pinned items up/down, rename groups and directory shortcuts, or remove
  them on the same page. Move the entire Apps section using Taskbar › Bar, like
  any other built-in item. Configuration remains available while it is disabled.
- **Show running apps** appends unpinned running apps. Group members are kept
  inside their group; they are not appended again. Explicit standalone pins can
  coexist with membership in a group.
- Click an app to launch it, focus its window or cycle its windows. Without an
  active window of that app, prefer the current workspace. Middle-click opens
  another instance. A dot marks running apps; a filled surface marks the active
  one. Right-click a slot, or use the tune button, to open its settings.
- **Visible slots** caps the section's length, including its tune button. It
  shrinks further according to the bar's shared budget and scrolls on its own
  axis. The tray and plugin pill keep their minimum space.
- Super+Ctrl+0 reaches the section through the existing bar focus cursor. Moving
  through it scrolls hidden slots into view. Enter on a group opens the existing
  keyboard-driven popout; Escape returns to the bar. Outside-click closes it.

Unavailable or hidden app pins are kept in settings and left out of the bar.
They reappear when the app is available again. Other special-workspace windows
and child/transient windows stay out; Omarchy's `special:minimized` windows can
be restored. App identification uses desktop-entry lookup and the explicit
terminal app IDs used by Omarchy's TUI launcher.

## Development preview

Run from a normal desktop terminal, with an existing Omacale installation:

```bash
python3 /path/to/feature-checkout/scripts/taskbar-preview.py start
```

Optionally import/fast-forward the feature branch into a separate clean checkout:

```bash
python3 /path/to/feature-checkout/scripts/taskbar-preview.py start --checkout /path/to/omacale
```

The helper prepares the complete plugin in a hidden staging directory, checks
that the desktop is unlocked, gracefully stops the existing Omarchy shell and
confirms that its instances have exited. Only then does it replace the plugin
by directory renames and update settings. It starts the shell through Omarchy's
existing restart command and waits for `taskbarAppsStatus` to report an actual
instantiated app entry on a screen, rather than accepting the core's early ping.
The settings page then opens. If available, `grim` captures the desktop.

A native crash reported during startup aborts the preview. Failures are printed
before recovery and saved to `failure.json`; recovery also stops the shell
before replacing any files. No notification, lock or OSD handovers are changed.
A locked or unknown lock state prevents stopping the shell.

To restore the previous plugin, app settings and bar layout:

```bash
python3 /path/to/feature-checkout/scripts/taskbar-preview.py restore
```

Unrelated settings changes are kept; a modified checkout is left on its current
branch to protect edits. Backups and diagnostics are under
`$XDG_STATE_HOME/omacale/taskbar-preview` (normally `~/.local/state/omacale/taskbar-preview`).

### Incident and validation limits

The first helper copied into the **running** plugin and restarted immediately.
The real log records 314 local-plugin reload requests in about 20 ms. The repo
already documents that killing the shell mid-reload has caused segmentation
faults. The preview produced a native crash in QML import loading on Quickshell
0.3.2 / Qt 6.12.0 (`comparesEqual(QDir const&, QDir const&)`, then
`QQmlImports::resolveType`). The recorded recovery completed, installed files
matched the backup and the checkout returned to `main`.

The revised stop-before-publish transaction removes that demonstrated unsafe
sequence. Regression tests enforce the ordering on install **and** rollback,
exercise a failed rename/copy, preserve local edits, wait for late bar startup
and abort on a new crash report. They use temporary repositories and fake
desktop commands. The revised live transaction has not yet been executed in
the restricted development session, and the exact native trigger is not proven.
Do not treat these tests as proof that the native crash cannot recur.

## Settings and ownership

`bar.apps` defaults to:

```json
{
  "enabled": false,
  "showRunning": true,
  "maxShown": 8,
  "items": []
}
```

`items` is an ordered array persisted by the existing Config/JsonAdapter:

```json
[
  { "id": "app:firefox", "type": "app", "app": "firefox" },
  {
    "id": "group:work", "type": "group", "name": "Work",
    "apps": ["code", "org.gnome.Nautilus"]
  },
  {
    "id": "folder:projects", "type": "folder", "name": "Projects",
    "path": "/home/example/Projects"
  }
]
```

Desktop IDs are stored without the `.desktop` suffix. App pin IDs are derived
from their desktop IDs. Group and directory IDs stay stable when renamed.
Unknown types, relative directory paths, malformed items and duplicate IDs are
ignored. Missing apps remain saved. An empty group remains editable.

`core/TaskbarApps.js` holds pure normalization, editing, item ordering and
window-selection rules. `services/TaskbarApps.qml` supplies shared reactive data
and actions. It does not poll. Its window list is empty without subscribing to
Hyprland windows while the feature is disabled. Launches use Omarchy's injected
AppLibrary; existing Sys helpers perform window actions. Paths never become
shell commands: `xdg-open` receives one percent-encoded file URL.

`AppsEntry` keeps a keyed ListModel, so window updates and reorders preserve
slots and in-progress pointer presses. The usual bar entry registration,
section layout, screen edge, space budget and keyboard cursor apply.
`AppsGroup` lives inside the existing PopoutContent/ScreenScope frame, including
its glass and motion styles; clicking a group holds the popout's keyboard using
the established `openPopoutKeys` path.

## Automated verification

```bash
node tests/test-taskbar-apps.js
node tests/test-layout.js
node tests/test-settings.js
python3 tests/test-taskbar-ui.py
python3 tests/test-taskbar-preview.py
```

The Qt 6 test runner loads the actual new components, tokens and controls in an
offscreen window with mock Config, desktop-entry, Hyprland and host services.
Warnings fail the test. It checks loading and switching edges, capped lengths,
slot identity across window changes, group opening/closing/removal, launch and
window-cycle actions, minimized/TUI windows and safe folder argv. It does not
start another Quickshell process or change the user's desktop/configuration.
It does **not** verify real JsonAdapter disk persistence, compositor IPC, icon
lookup, or the running shell's pointer/focus integration. The BarContent budget
and entry loader are exercised with the real AppsEntry and deterministic
stand-ins for the other built-ins, including 20 pins and keyboard scrolling.

## Desktop acceptance before marking the PR ready

Install from this branch using the repo's normal development workflow and
restart the existing Omarchy shell. Never run a second Quickshell process.
Back up settings first and restore the original state after checking.

- [ ] With no saved `bar.apps` keys, compare the bar with the previous version:
      no extra pill or gap, on each edge and with glass/motion on and off.
- [ ] Enable Apps; pin two apps, import favourites, create a group and directory
      shortcut (including spaces, `#` and `?`); exercise the real actions.
- [ ] Reorder and rename items; restart the shell and verify the saved array,
      membership, order and enabled state survive; reset the page/configuration.
- [ ] Launch a new app, focus and cycle multiple windows, middle-click, and
      restore a window minimized by Omarchy. Check TUI and web-app identities.
- [ ] Exercise mouse and keyboard groups, Escape/outside-click, pointer travel,
      per-screen edge changes, auto-hidden bars, removing an open group and
      disabling the section while it is open. Ensure keyboard focus is released.
- [ ] Fill the section, use a short screen and larger UI scale, move it between
      start/center/end and behind the chevron. Scroll with the wheel/keys and
      check that tray, plugin controls and power remain reachable.
- [ ] Inspect screenshots and shell logs for each edge, plus glass and both
      motion modes. Confirm no binding/polish loops, missing icons or stuck
      popouts. Exercise two monitors with different edges.

The restricted implementation session could not reach the Hyprland socket or
write to the installed plugin, so these live checks remain pending.

The pre-existing `tests/test-restore.sh` failure at the notification-daemon
patch and `tests/test-facade.sh` failure also reproduce on the unmodified base
checkout against the installed Omarchy. The facade lacks `notePopoutCard`,
`popoutCardFor`, `traySectionDragActive` and `traySectionPopoutOpen`. Those host
compatibility issues are outside this app-section change.
