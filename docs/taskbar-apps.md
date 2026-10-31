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
- **Add folder** opens the existing Omacale picker in directory mode. Choose a
  folder and confirm **Select folder**; its name is used automatically and can
  be edited afterwards. It opens in the default file manager. This is a directory
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
  one. Right-click opens that item's action menu, including pin/unpin, new
  window, close all windows and quit application. Menu or Shift+F10 opens the
  same menu from the bar's keyboard cursor.
- Saved pins come first, followed by a divider and the remaining running apps.
  Unpinned running apps are dimmed until hovered or active. The divider is
  absent when either section is empty.
- Drag pins to reorder them; drag a running app into the pin section to pin it.
  An insertion line previews the drop; releasing outside cancels it. Hidden or
  unavailable pins keep their saved position. Near a clipped edge, moving the
  pointer scrolls the list to reveal more targets.
- **Use available space** lets the section grow with its contents up to the
  bar's shared space budget. Turn it off to choose **Visible slots** (1–100).
  The tray and plugin pill keep their minimum space and overflow scrolls on the
  bar's own axis. **Show settings button** is off by default; Settings › Taskbar
  › Apps always remains available.
- Super+Ctrl+0 reaches the section through the existing bar focus cursor. Moving
  through it scrolls hidden slots into view. Enter on a group opens the existing
  keyboard-driven popout; Escape returns to the bar. Outside-click closes it.

Unavailable or hidden app pins are kept in settings and left out of the bar.
They reappear when the app is available again. Other special-workspace windows
and child/transient windows stay out; Omarchy's `special:minimized` windows can
be restored. App identification uses desktop-entry lookup and the explicit
terminal app IDs used by Omarchy's TUI launcher.

**Close all windows** asks each matched window to close normally. **Quit
application** additionally stops an otherwise lingering window-owner process
after all of its windows close. An open window or a new save dialog prevents
termination. Shared browser processes are retained, and web-app shortcuts never
terminate the browser process. Quit is available while the app has windows to
identify it; it does not search for background processes by name.

The quit helper runs only on explicit selection, through the unmodified Omakit
Run block with an eight-second deadline and bounded output. It validates fresh
compositor window/PID/class identities, opens pidfds, protects the shell and
other users, and sends SIGTERM only after the close flow succeeds. It does not
use SIGKILL, process-name matching, a shell string or a periodic process probe.

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
  "useAvailableSpace": true,
  "showSettings": false,
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
AppLibrary when exposed. Bar capability proxies have no AppLibrary, so terminal
entries use Omarchy's TUI launcher through `Util.execArgv`; other entries use the
existing launcher's desktop-entry execution. Existing Sys helpers perform window
actions, with native bare hexadecimal addresses normalized to Lua selectors. Paths never become
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

## Desktop verification — 2026-10-29

The feature was imported with Git into the requested checkout and installed as a
regular copy in the already-running Omarchy shell. The original feature and
recovery commits retain their authorship. No release version/changelog was changed.

Environment: one real eDP-1 display, 2560×1600 at compositor scale 1.6; Omacale UI
scales 0.85 and 1.2; Qt 6.12.0; locally built, package-managed Quickshell
`0.3.2.r7.g2b4501a-5.2`. The previous official package and configuration are saved
outside the plugin tree. The local runtime patch belongs to omarchy-pkgs, not this
contributor change.

| Check | Observed result |
| --- | --- |
| Default/off | No Apps entry or gap; real screenshots and status checked on left, right, top and bottom. |
| Pins/settings | Pinned Foot and Omacalc through the picker; reordered, removed, created/renamed a group and edited its members through the UI. |
| Directory shortcut | Added a path containing spaces, `#` and `?`; Strata, the configured directory handler, opened the exact directory. |
| Launch/windows | Foot launched, middle-click created another window, subsequent clicks focused/cycled the real windows. A real window moved to `special:minimized` was restored to the current workspace and focused. |
| Terminal apps | Neovim launched in Ghostty as `org.omarchy.nvim`; refocusing retained one window. The previous raw-command fallback had started orphan commands; those test processes were cleaned up. |
| Web apps | YouTube launched in Brave. Matching the Chrome desktop class to Brave's class fixed duplicate launches; later clicks focused/cycled the two existing test windows without adding another. |
| Group input | Pointer and bar-keyboard opening, keyboard activation, Escape, outside click, removal while open and disabling while open checked on the compositor. Screenshots confirm closing/focus release. |
| Group scrolling | A long list of installed apps scrolled inside the existing popout. |
| Edges/style | Group popouts viewed on all four real edges; glass, Morph and Liquid viewed on the left edge. |
| Crowding/scale | 23–24 saved items, 25 visible app items at 120% UI scale on the real display; section capped and scrolled while power/clock remained reachable. |
| Keyboard scrolling | Found and fixed a stale shared focus-ring rectangle. The Qt regression fails without the explicit Flickable offset dependency (768 versus 305); the corrected desktop screenshot puts the ring on the revealed tune button. |
| Wheel scrolling | Real wheel input scrolled the constrained Apps section in both directions. |
| Persistence | A controlled shell restart preserved the captured five-item configuration, membership, order, enabled state and slot cap exactly. |
| Successful rollback | Repeated real restore/start cycles restored the exact prior plugin and kept unrelated settings. |
| Failed-preview recovery | An injected readiness failure after real publication restarted and restored the prior plugin; its digest matched, the original error was saved, and exactly one Omacale shell answered afterwards. |
| Runtime evidence | No new Quickshell crash reports during the corrected runtime/feature trials; no bulk deployment reload storm. Relevant feature logs checked alongside screenshots. |

Later pins added during acceptance were preserved. Temporary test groups/folders,
UI scale and edge changes were removed/restored. Private desktop captures remain
local under the preview state directory; they are not contributor-PR attachments.
Multiple monitors were unavailable and were not simulated. Native race freedom is
argued from ownership and regression tests, not from a finite number of starts.

### Regression coverage and existing failures

The three focused JS suites pass. Qt UI has **27 passing cases** using actual
components and mocked host services, including bare native addresses, a bar host
without the menu AppLibrary capability, cross-browser web-app classes, folded
space allocation and the scrolled shared cursor. The real FolderListModel and
picker controls cover directory-only listings, empty-folder selection, navigation,
cancel, automatic pin names, and unchanged image-file filtering. A Qt
FolderListModel double-decoding quirk is handled locally so literal `#`, `?` and
`%` in directory names survive listing. Preview has **28 passing tests**,
including empty inventory, failed post-quit verification, supervisor retry backoff,
failed publication, settings without a prior Apps dictionary, later installed
edits, diagnostics-write failures and cleanup failures after publication.

The interaction follow-up also covers right-click menus, pin/unpin, optional
settings, available-space/manual sizing, separator/emphasis state, real Qt
pointer drags on both axes, and a dragged running app becoming a pin. The
quit helper has **8 process tests** using disposable processes: full closure,
background termination, unselected/shared processes, web-app isolation,
unsaved/new dialog handling, changed identities and shell protection.

The source build and native regression compile actual patched C++ and moc code,
exercise 400,000 concurrent interceptions, four private scanner threads, explicit
and implicit late modules, singletons and preprocessor directives. This is
separate from Qt UI's mocked host integration.

Repository bind, theme-mode, shell-toml and screen tests also passed. On both this
feature and an untouched `aacad54` archive, facade checking lacks
`notePopoutCard`, `popoutCardFor`, `traySectionDragActive`, and
`traySectionPopoutOpen`; restore testing stops at the notification-daemon patch.
Upstream checking also encounters the baseline non-executable facade test.
Those existing host compatibility failures have not been relabeled as Apps bugs.

Sol-loop used one harness-selected native `gpt-6.1-sol` route, five rounds (the
last two for newly found UI-state/recovery defects), with all findings resolved.
The harness accepted that explicit model route; the child did not independently
expose provider/model metadata or usage. No usage figures are inferred.

## Contributor PR draft

**Title:** feat: add optional taskbar apps, groups and directory shortcuts

**Description:**

Adds an opt-in Apps entry to the existing taskbar, with ordered app pins, named
app groups and directory shortcuts. It uses the existing layout, settings,
controls and keyboard popout, works on every edge, recognizes running windows,
cycles/restores them and launches terminal entries through Omarchy.

A controlled development preview stages outside watched directories and stops
the shell/supervisor before publication and rollback. Recovery preserves later
settings/installed edits and retains the original error even if diagnostics fail.
The Quickshell scanner repair is maintained as a separate package change.

Validation: taskbar-apps/layout/settings JS suites, 27 actual-component Qt cases,
28 preview regressions, native C++ build/stress/module tests, and the real desktop
checks above. Existing facade/notification-restore failures reproduce on the
baseline. Multi-monitor acceptance remains unverified because one display was
available. Release versioning remains with the maintainer.

No branch has been pushed and no public PR has been opened.
