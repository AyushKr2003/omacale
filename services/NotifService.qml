pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// Omacale Notification Service.
// Synchronizes with Omarchy's notification server by reading the state and history
// JSON records in ~/.local/state/omarchy/notifications/. This ensures 100% data fidelity
// with Omarchy's native notification daemon without DBus protocol conflicts.
QtObject {
  id: root

  property var notifications: []
  property var groups: []
  readonly property int count: notifications.length
  property bool dnd: false
  property bool loading: false
  property string lastRaw: ""

  // Which app groups are expanded. Lives here (not in the delegates) because
  // the group list is rebuilt whenever the history changes.
  // Unset apps start collapsed: notifs.openExpanded is for the toasts only
  // (Caelestia sidebar Props.qml vs Notification.qml).
  property var expandedApps: ({})
  function isExpanded(app) { return !!expandedApps[app] }
  function setExpanded(app, on) {
    const next = Object.assign({}, expandedApps)
    next[app] = on
    expandedApps = next
  }

  // Caelestia Icons.getNotifIcon
  readonly property var iconRules: [
    [["reboot"], "restart_alt"], [["recording"], "screen_record"], [["battery"], "power"],
    [["screenshot"], "screenshot_monitor"], [["welcome"], "waving_hand"], [["time", "a break"], "schedule"],
    [["installed"], "download"], [["update"], "update"], [["unable to"], "deployed_code_alert"],
    [["profile"], "person"], [["file"], "folder_copy"]
  ]
  function notifIcon(summary, urgency) {
    const t = String(summary || "").toLowerCase()
    for (const r of iconRules) if (r[0].some(n => t.indexOf(n) !== -1)) return r[1]
    return urgency === 2 ? "release_alert" : "chat"
  }

  // ------------------------------------------------------------- bodies
  //
  // A body is the sender's text, and the formats that would draw it richly
  // fetch images: Markdown's ![](url) and <img src> make the shell GET a
  // sender-chosen URL as soon as the body is shown (open tracking, requests
  // into the local network). So bodies are drawn as Omarchy's own toasts draw
  // them -- StyledText of NotificationLogic.styledBody(), which drops every
  // image tag in whole tags (see its comments) -- and with Omarchy's logic
  // loaded in place, never copied, as MenuService loads MenuModel.js. An
  // Omarchy without styledBody (before 4.0.4) gets plain text: nothing rich,
  // nothing fetched.
  readonly property string omarchyPath: Quickshell.env("OMARCHY_PATH") || "/usr/share/omarchy"
  property var bodyLogic: null
  readonly property bool richBodies: bodyLogic !== null
  function loadBodyLogic() {
    const src = 'import QtQuick\nimport "NotificationLogic.js" as L\nQtObject {\n'
      + '  readonly property bool ok: typeof L.styledBody === "function"\n'
      + '  function styled(b, a, i) { return L.styledBody(b, a, i) }\n'
      + '}'
    try {
      const o = Qt.createQmlObject(src, root, "file://" + omarchyPath + "/shell/plugins/notifications/OmacaleBodyLogic.qml")
      if (o.ok) bodyLogic = o
      else { o.destroy(); console.warn("Omacale: this Omarchy has no NotificationLogic.styledBody; notification bodies are plain text") }
    } catch (e) {
      console.warn("Omacale: Omarchy's notification logic could not be loaded; notification bodies are plain text:", e)
    }
  }
  Component.onCompleted: loadBodyLogic()
  readonly property int bodyFormat: richBodies ? Text.StyledText : Text.PlainText
  // The body as `bodyFormat` text.
  function bodyMarkup(n) {
    const b = n ? String(n.body || "") : ""
    return richBodies ? bodyLogic.styled(b, n.app || "", n.appIcon || "") : b
  }
  // One line of it for a collapsed card, always drawn as plain text, so
  // markup shows as nothing rather than as tags.
  function bodyLine(n) {
    const b = n ? String(n.body || "") : ""
    return (richBodies ? b.replace(/<[^>]*>?/g, "") : b).replace(/\s+/g, " ").trim()
  }

  // `run` is for fixed command strings only. Anything carrying a value from a
  // notification (its title, its file, its key) goes through `exec` as argv,
  // never a shell string: the sender controls those, and quoting them for
  // bash (JSON.stringify included) still leaves $() and backticks live.
  function run(cmd) { Quickshell.execDetached(["bash", "-c", cmd]) }
  function exec(argv) { Quickshell.execDetached(argv) }

  // The click action, as Omarchy's NotificationLogic.parseExecArgv reads it:
  // `execArgv` is a JSON argv array (omarchy-notification-send --exec), run
  // as argv with no shell. A malformed one (not an array of strings, an empty
  // or leading-dash program) runs nothing. Returns whether it ran.
  function runAction(n) {
    let argv
    try { argv = JSON.parse(String(n && n.execArgv || "")) } catch (e) { return false }
    if (!Array.isArray(argv) || argv.length === 0) return false
    if (argv.some(a => typeof a !== "string")) return false
    if (!argv[0] || argv[0].charAt(0) === "-") return false
    exec(argv)
    return true
  }

  // A link in a body is the sender's, and its text can say anything: open
  // only web and mail links, never file://, ssh://, app schemes and the like
  // (stock Omarchy opens none). Returns whether it opened.
  function linkAllowed(link) { return /^(https?:\/\/|mailto:)\S+$/i.test(String(link || "").trim()) }
  function openLink(link) {
    if (!linkAllowed(link)) return false
    Qt.openUrlExternally(String(link).trim())
    return true
  }

  // Omarchy's records store numbers as strings.
  function urgencyOf(n) { return n ? Number(n.urgency) || 0 : 0 } // 0 low, 1 normal, 2 critical
  function timestampOf(n) { return n ? Number(n.timestamp) || 0 : 0 }

  // Caelestia NotifData.timeStr: the notification's age, "now", "5m", "2h", "1d".
  property real now: Date.now()
  property Timer nowTimer: Timer {
    interval: 5000
    running: true
    repeat: true
    onTriggered: root.now = Date.now()
  }
  function timeStr(n) {
    const t = timestampOf(n)
    if (!t) return ""
    const ageMins = Math.floor(Math.max(0, now - t) / 60000)
    if (ageMins < 1) return "now"
    const h = Math.floor(ageMins / 60), d = Math.floor(h / 24)
    if (d > 0) return d + "d"
    if (h > 0) return h + "h"
    return ageMins + "m"
  }

  function reload() {
    if (probe.running) return
    loading = true
    probe.running = true
  }

  // ------------------------------------------------------------- popups
  //
  // The toast stack (NotifPopups / NotifToast), read from the live popup
  // files Omarchy's daemon keeps for exactly as long as a toast is showing.
  //
  // Omacale may only draw them once the daemon is the patched clone
  // (scripts/notif-popups), which gives up its own toast window while this
  // bar claims the toasts. Until then popupsSupported is false and Omacale
  // draws nothing, so the two can never both be up.
  property bool popupsSupported: false
  onPopupsSupportedChanged: if (!popupsSupported) popups = []
  readonly property bool popupsOn: !!(Config.o.notifs && Config.o.notifs.popups && Config.o.notifs.popups.enabled)
  readonly property bool popupsEnabled: popupsSupported && popupsOn
  property var popups: []

  // The claim the patched daemon reads (about once a second): this shell
  // process, and whether "Show popups" is on. Bar.qml claims as it loads and
  // releases as it unloads, so a bar that failed to load, another bar or
  // "Show popups" off all give the toasts back to Omarchy's own window, as
  // does a claim left behind by a crashed shell (its pid is gone). Only the
  // runtime directory, which only this user can write: no /tmp fallback.
  readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || ""
  property bool claimed: false
  function claimPopups(on) {
    if (on && !claimed) probeAfterClaim.restart()
    claimed = on
    if (runtimeDir === "") return
    claimFile.setText(JSON.stringify({ pid: on ? Quickshell.processId : 0, popups: on && popupsOn }))
  }
  onPopupsOnChanged: if (claimed) { claimPopups(true); probePopups() }
  // The daemon reads the claim about once a second.
  property Timer probeAfterClaim: Timer { interval: 1500; onTriggered: root.probePopups() }
  property FileView claimFile: FileView {
    path: root.runtimeDir === "" ? "" : root.runtimeDir + "/omacale-notifs-claim.json"
    atomicWrites: true
    printErrors: false
  }

  // Popups the user has dealt with, held until their file is really gone so
  // a reload during the daemon's round trip can't put the toast back.
  property var dismissedKeys: ({})

  // Omarchy's own popup durations (its Service.qml durationFor): critical
  // toasts never expire, the rest get at least 5s/8s and at most 30s.
  function popupDuration(n) {
    const urgency = urgencyOf(n)
    if (urgency === 2) return 0
    const floor = urgency === 0 ? 5000 : 8000
    const asked = Math.round(Number(n.expireTimeout) || 0)
    return Math.min(30000, Math.max(floor, asked > 0 ? asked : 0))
  }

  // The daemon stamps `deadline` onto every live popup file, so its timer and
  // our countdown ring run off one clock. The estimate below only covers a
  // daemon that hasn't been patched (where we don't draw toasts anyway).
  function popupDeadline(n) {
    const written = Number(n ? n.deadline : 0) || 0
    if (written > 0) return written
    const d = popupDuration(n)
    return d > 0 ? timestampOf(n) + d : 0
  }

  // Hover pause. The daemon owns expiry, so the pause has to reach it; it
  // hands the time back on resume by rewriting each popup's deadline, which
  // arrives here through the watcher like any other change.
  property bool popupsPaused: false
  property real popupPausedAt: 0
  function pausePopups(on) {
    if (!!on === popupsPaused) return
    popupsPaused = !!on
    if (popupsPaused) popupPausedAt = Date.now()
    run("omarchy-shell -q notifications " + (popupsPaused ? "pause" : "resume") + " >/dev/null 2>&1 || true")
  }

  // What the countdown rings read: frozen while the stack is paused.
  property real popupNow: Date.now()
  readonly property real popupClock: popupsPaused ? popupPausedAt : popupNow

  function markDismissed(keys) {
    if (!keys.length) return
    const next = Object.assign({}, dismissedKeys)
    for (let i = 0; i < keys.length; i++) next[keys[i]] = true
    dismissedKeys = next
    const list = []
    for (let i = 0; i < popups.length; i++) if (!next[popups[i]._key]) list.push(popups[i])
    popups = list
  }

  function hidePopup(n) { if (n && n._key) markDismissed([n._key]) }

  function dismissPopup(n) {
    if (!n || !n._key) return
    hidePopup(n)
    exec(["omarchy-shell", "-q", "notifications", "dismissKey", String(n._key)])
  }

  // The daemon's own click behaviour: run execArgv, else the sender's
  // "default" action, else focus the sending app -- then dismiss.
  function invokePopup(n) {
    if (!n || !n._key) return
    hidePopup(n)
    exec(["omarchy-shell", "-q", "notifications", "invokeKey", String(n._key)])
  }

  function dismissAllPopups() {
    const keys = []
    for (let i = 0; i < popups.length; i++) keys.push(popups[i]._key)
    markDismissed(keys)
    run("omarchy-shell -q notifications dismissAll >/dev/null 2>&1 || true")
  }

  // Which toasts are open. Kept here, not in the delegates: the watcher
  // hands us a fresh record on every change and a rebuilt delegate would
  // otherwise collapse itself (same reason as expandedApps above).
  property var expandedPopups: ({})
  function popupExpanded(key) {
    return key in expandedPopups ? expandedPopups[key] : Config.o.notifs.openExpanded
  }
  function setPopupExpanded(key, on) {
    const next = Object.assign({}, expandedPopups)
    next[key] = on
    expandedPopups = next
  }

  // Everything a toast draws. Unchanged means its delegate can stay.
  function sameRecord(a, b) {
    return !!a && !!b && a.summary === b.summary && a.body === b.body
      && a.image === b.image && a.appIcon === b.appIcon
      && a.deadline === b.deadline && a.urgency === b.urgency
  }

  function samePopups(a, b) {
    if (a.length !== b.length) return false
    for (let i = 0; i < a.length; i++) if (a[i] !== b[i]) return false
    return true
  }

  function applyPopups(list) {
    const byKey = {}
    for (let i = 0; i < popups.length; i++) byKey[popups[i]._key] = popups[i]

    const kept = []
    const live = {}
    for (let i = 0; i < list.length; i++) {
      const n = list[i]
      live[n._key] = true
      if (dismissedKeys[n._key]) continue
      // Hand back the very object the toast is already bound to when nothing
      // it draws has changed, so ScriptModel keeps that delegate alive.
      const prev = byKey[n._key]
      kept.push(sameRecord(prev, n) ? prev : n)
    }

    // Forget a dismissed or expanded key once its file is gone for good.
    let dismissedNext = null
    for (const key in dismissedKeys) {
      if (live[key]) continue
      if (!dismissedNext) dismissedNext = Object.assign({}, dismissedKeys)
      delete dismissedNext[key]
    }
    if (dismissedNext) dismissedKeys = dismissedNext

    let expandedNext = null
    for (const key in expandedPopups) {
      if (live[key]) continue
      if (!expandedNext) expandedNext = Object.assign({}, expandedPopups)
      delete expandedNext[key]
    }
    if (expandedNext) expandedPopups = expandedNext

    if (!samePopups(popups, kept)) popups = kept
  }

  // The daemon deletes an expired popup's file, which is what really takes
  // the toast away. Dropping it here the moment its deadline passes only
  // saves the round trip, so the toast leaves on the beat instead of a
  // watcher tick later.
  function sweepPopups() {
    if (popupsPaused || popups.length === 0) return
    const now = Date.now()
    const gone = []
    for (let i = 0; i < popups.length; i++) {
      const deadline = popupDeadline(popups[i])
      if (deadline > 0 && now >= deadline) gone.push(popups[i]._key)
    }
    markDismissed(gone)
  }

  function toggleDnd() {
    run("omarchy toggle notification silencing || omarchy-shell notifications toggleDnd")
    // The watcher picks the new value up, but only once Omarchy has written
    // it; re-read on a short beat so the switch doesn't sit on the old state.
    dndSettle.restart()
  }

  function dismiss(item) {
    if (!item) return
    if (item._file) exec(["rm", "-f", "--", String(item._file)])
    if (item.summary) exec(["omarchy-shell", "-q", "notifications", "dismiss", String(item.summary)])
    // Optimistic local update
    const next = []
    for (let i = 0; i < notifications.length; i++) {
      if (notifications[i]._file !== item._file) next.push(notifications[i])
    }
    notifications = next
    rebuildGroups()
  }

  function dismissGroup(appName) {
    if (!appName) return
    const toDelete = []
    const next = []
    for (let i = 0; i < notifications.length; i++) {
      if ((notifications[i].app || "System") === appName) {
        if (notifications[i]._file) toDelete.push(String(notifications[i]._file))
      } else {
        next.push(notifications[i])
      }
    }
    if (toDelete.length) exec(["rm", "-f", "--"].concat(toDelete))
    notifications = next
    rebuildGroups()
  }

  function clearAll() {
    run("rm -f $HOME/.local/state/omarchy/notifications/*.json $HOME/.local/state/omarchy/notifications/history/*.json && omarchy-shell notifications clear 2>/dev/null || true")
    notifications = []
    groups = []
  }

  function rebuildGroups() {
    const map = new Map()
    for (let i = 0; i < notifications.length; i++) {
      const n = notifications[i]
      const app = n.app || "System"
      if (!map.has(app)) {
        map.set(app, {
          app: app,
          appIcon: n.appIcon || "",
          image: n.image || "",
          items: []
        })
      }
      const g = map.get(app)
      if (!g.appIcon && n.appIcon) g.appIcon = n.appIcon
      if (!g.image && n.image) g.image = n.image
      g.items.push(n)
    }
    groups = Array.from(map.values())
  }

  property Process probe: Process {
    command: ["python3", root.notifsScript]
    stdout: StdioCollector {
      onStreamFinished: {
        root.loading = false
        if (text === root.lastRaw) return
        root.lastRaw = text
        try {
          const list = JSON.parse(text) || []
          root.notifications = list
          root.rebuildGroups()
        } catch (e) {}
      }
    }
  }

  readonly property string notifsScript: Qt.resolvedUrl("../scripts/notifs.py").toString().replace("file://", "")

  // Does the daemon still draw its own toasts? Omacale's only answer when it
  // does is to stay out of the way. Asked at start and again whenever
  // NotifHandover installs, re-syncs or removes the clone.
  function probePopups() {
    if (!popupSupportProbe.running)
      popupSupportProbe.running = true
  }
  // Omacale draws only once the daemon says its own window is off
  // (`popupsHidden`), so the two stacks are never up together. A patched
  // daemon (`omacalePopups`, the patch since v2) turns its window off about a
  // second after it reads the claim, so until it does it is asked again.
  property bool popupsPatched: false
  property Process popupSupportProbe: Process {
    running: true
    // Not `-q`: that swallows the answer we are asking for.
    command: ["bash", "-c", "omarchy-shell notifications omacalePopups 2>/dev/null; echo; omarchy-shell notifications popupsHidden 2>/dev/null || true"]
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = String(text).split("\n").map(l => l.trim())
        root.popupsPatched = lines.some(l => l.indexOf("omacale:headless-popups v") === 0)
        root.popupsSupported = lines.indexOf("yes") >= 0
      }
    }
  }
  property Timer popupSupportRetry: Timer {
    interval: 1500
    repeat: true
    running: root.popupsPatched && root.claimed && root.popupsOn && !root.popupsSupported
    onTriggered: root.probePopups()
  }

  // One long-lived reader of the live popup directory: a toast has to appear
  // the moment its file does, and respawning a probe at that rate would cost
  // far more than the watcher's own polling.
  property Process popupWatcher: Process {
    running: root.popupsEnabled
    onRunningChanged: if (!running) root.popups = []
    command: ["python3", root.notifsScript, "watch"]
    stdout: SplitParser {
      onRead: line => {
        try {
          root.applyPopups(JSON.parse(line) || [])
        } catch (e) {}
      }
    }
  }

  property Timer popupSweep: Timer {
    interval: 200
    running: root.popups.length > 0
    repeat: true
    onTriggered: root.sweepPopups()
  }

  // Drives the countdown rings; only ticks while a toast is actually ticking.
  property Timer popupTick: Timer {
    interval: 50
    running: root.popups.length > 0 && !root.popupsPaused
    repeat: true
    onTriggered: root.popupNow = Date.now()
  }

  // DND state, parsed from the file the watcher already holds. It used to be
  // a `bash -c` running `jq` for this one boolean, which is a process pair
  // (~4ms) for something QML can read straight out of the FileView.
  // Omarchy's notifications.json is `{ version: 3, dnd }` (its
  // NotificationLogic.parseSettings). A newer shape still reads as "DND off"
  // rather than breaking anything, but says so once in the log.
  property bool dndFormatWarned: false
  function readDnd(t) {
    try {
      const parsed = JSON.parse(t)
      if (!dndFormatWarned && (parsed.version !== 3 || typeof parsed.dnd !== "boolean")) {
        dndFormatWarned = true
        console.warn("Omacale: notifications.json is version " + parsed.version + ", expected 3; reading dnd as " + !!parsed.dnd)
      }
      root.dnd = !!parsed.dnd
    } catch (e) {
      root.dnd = false
    }
  }

  property FileView dndWatcher: FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/notifications.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.readDnd(text())
    onLoadFailed: root.dnd = false
  }

  property Timer dndSettle: Timer {
    interval: 250
    repeat: true
    triggeredOnStart: true
    property int left: 0
    onRunningChanged: if (running) left = 6
    onTriggered: {
      root.dndWatcher.reload()
      if (--left <= 0) stop()
    }
  }

  property FileView notifWatcher: FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/notifications"
    watchChanges: true
    printErrors: false
    onFileChanged: root.reload()
  }

  property FileView historyWatcher: FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/notifications/history"
    watchChanges: true
    printErrors: false
    onFileChanged: root.reload()
  }

  // Safety net only. The two FileViews above watch the live and history
  // directories and do fire on a notification being written, moved or
  // deleted, so this is here for a change inotify can miss (a directory
  // replaced wholesale), not as the way notifications arrive. It ran every
  // 3s, which re-read and re-parsed every notification on disk -- ~21ms of
  // python a go, for the whole session, to find nothing had changed.
  property Timer pollTimer: Timer {
    interval: 30000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.reload()
  }
}
