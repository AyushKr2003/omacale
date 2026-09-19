pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

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
  // Unset apps follow notifs.openExpanded.
  property var expandedApps: ({})
  function isExpanded(app) { return app in expandedApps ? expandedApps[app] : Config.o.notifs.openExpanded }
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

  function run(cmd) { Quickshell.execDetached(["bash", "-c", cmd]) }

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

  function toggleDnd() {
    run("omarchy toggle notification silencing || omarchy-shell notifications toggleDnd")
    dndProbe.running = true
  }

  function dismiss(item) {
    if (!item) return
    if (item._file) {
      run("rm -f " + JSON.stringify(item._file))
    }
    if (item.summary) {
      run("omarchy-shell notifications dismiss " + JSON.stringify(item.summary) + " 2>/dev/null || true")
    }
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
        if (notifications[i]._file) toDelete.push(JSON.stringify(notifications[i]._file))
      } else {
        next.push(notifications[i])
      }
    }
    if (toDelete.length) {
      run("rm -f " + toDelete.join(" "))
    }
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
    command: ["bash", "-c", Qt.resolvedUrl("scripts/notifs.py").toString().replace("file://", "")]
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

  // DND state probe
  property Process dndProbe: Process {
    command: ["bash", "-c",
      "if [[ -f $HOME/.local/state/omarchy/notifications.json ]]; then " +
      "jq -r '.dnd // false' $HOME/.local/state/omarchy/notifications.json 2>/dev/null; " +
      "else echo false; fi"]
    stdout: SplitParser {
      onRead: line => root.dnd = String(line).trim() === "true"
    }
  }

  property FileView dndWatcher: FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/notifications.json"
    watchChanges: true
    printErrors: false
    onFileChanged: root.dndProbe.running = true
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

  property Timer pollTimer: Timer {
    interval: 3000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      root.reload()
      if (!root.dndProbe.running) root.dndProbe.running = true
    }
  }
}
