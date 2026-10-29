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

## Controlled development preview

The CLI was re-enabled only after repairing the reload transaction, adding its
failure regressions, building the native runtime correction separately, and
verifying the corrected runtime with the existing Omacale bar and notification
service. The runtime correction is not part of this plugin or a hidden feature
dependency; see the incident analysis below. Do not deploy bulk file changes
into a plugin while the shell is watching it.

From a clean, committed checkout with Omacale already selected:

```bash
python3 scripts/taskbar-preview.py start
python3 scripts/taskbar-preview.py restore
```

The helper backs up the installed plugin and changed settings. It prepares the
complete new version **outside the recursive plugin watch tree**, on the same
filesystem. Hidden folders inside the plugin tree are still watched by
inotify, even though the host filters their reload signals.

It gracefully stops the existing shell, waits for its Omarchy supervisor too,
and checks absence again immediately before directory renames. It uses
Omarchy's existing restart command and waits for `taskbarAppsStatus` to identify
an actual Apps entry in the loaded Omacale bar. A core ping alone is insufficient.
Install and rollback follow the same stop-before-publish rule. An empty
`quickshell list -a -j` may be the literal `No running instances.`; the parser
accepts it. All commands have deadlines and a transaction lock prevents overlap.

On failure, the original error is printed and saved before recovery. A failed
publish restarts the original shell; a successful publish followed by a failed
probe restores the backup. Recovery errors do not replace the original error.
Restore refuses to overwrite later edits to the installed plugin. Settings use
a three-way rollback: only preview-written leaves that still match are reverted,
while later or unrelated edits are kept. Backups, logs and screenshots are in
`$XDG_STATE_HOME/omacale/taskbar-preview` (normally
`~/.local/state/omacale/taskbar-preview`). An optional `--checkout` imports a
branch with Git and only fast-forwards; normal source selection should be done
before deployment.

### Incident analysis

Three separate concerns must not be conflated:

1. **Native race.** Official Quickshell `0.3.2.r7.g2b4501a-5` still contains
   Omarchy's scanner call from the URL interceptor. `-5` was a dependency rebuild,
   not a race fix. [Omarchy issue #16167](https://github.com/omacom/omarchy/issues/16167)
   remains open. The local package repair is maintained separately in
   `omarchy-pkgs`: interception only routes URLs; each network manager owns its
   late scanner, four mutable scanner collections and pragma QJSEngine. Initial
   generation intercepts are read-only. The built package and actual interceptor/
   scanner tests cover explicit and implicit local modules, conditionals,
   singletons and concurrent loading. A first pure-rewrite candidate broke
   implicit QML types on the desktop and was immediately rolled back. The
   corrected `5.2` package loads the original bar and notification service.
   Successful starts support this finding; the ownership change is the source
   argument for removing this specific race.
2. **Reload storm.** The first preview copied into the active plugin. The journal
   records 314 reload messages around 13:50 on 2026-10-29, immediately before a
   native import-loading crash. The host has one recursive plugin watcher and
   emits a signal per file event; its reload timer coalesces the later work, not
   those messages. The installed Omacale copy matched all 290 baseline files;
   no runtime bytecode/writer was found there. Staging outside the watch tree
   and publishing only after shell/supervisor exit removes this deployment cause.
3. **Recovery bug.** The next trial successfully stopped the shell, then parsed
   its non-JSON empty inventory as JSON and skipped restart. Regressions now cover
   that exact response, a query failure after quit, simultaneous recovery failure,
   supervisor backoff, publication failure and rollback ownership.

The startup crash at 14:49 has the same `comparesEqual(QDir, QDir)` / import-loader
stack in the original coredump/report. This is consistent with the confirmed
native race; it is not evidence of a separate Apps QML crash. No OOM was recorded.
The live feature acceptance results below are recorded independently from both
the mocked tests and native package tests.

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
shell commands: Qt opens one percent-encoded file URL with the default handler.

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
window-cycle actions, minimized/TUI windows. Pure JS tests cover encoded directory URLs. It does not
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
