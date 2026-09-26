import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// One handover of an Omarchy plugin to Omacale -- a clone that Omacale
// rebuilds from the installed Omarchy (scripts/handover.py) -- and the
// watchdog that keeps it in step with `omarchy update` while the shell runs.
// LockService and NotifHandover are this with their own script.
//
// `omarchy update` only restarts the shell when a migration asks for it, so
// drift is caught here, not at startup alone: the stock files are watched
// (pacman replaces them, so the watch is re-armed after every change), and
// the check runs again when an update launched from the bar lets go of its
// lock, and once shortly after the shell starts. Each check is the script's
// `watchdog`: re-sync a stale clone, then check its health, and hand the
// plugin back to Omarchy if it is broken. Omacale's look can be lost to a bad
// update; the lock screen and the notification daemon must never be.
QtObject {
  id: root

  // Set by the handover.
  property string script
  property var installArgs: ["install"]
  // Where `autoFellBack` lives in Config ("lock" / "notifs").
  property string configKey
  // Stock files whose change means an Omarchy update landed.
  property var stockPaths: []
  // What a notice calls it ("Lock screen", "Notification popups").
  property string title

  // `status`, as the script printed it.
  property bool ready: false
  property var fields: ({})
  readonly property string clone: fields.clone && fields.clone !== "none" ? fields.clone.split(" ")[0] : ""
  readonly property bool cloneEnabled: String(fields.clone || "").indexOf("(enabled)") >= 0
  readonly property bool stale: fields.stale === "yes"
  readonly property string staleFiles: fields["stale-files"] || ""

  property bool busy: false
  property string error: ""

  // What the last watchdog run did ("synced", "refused", "fellback",
  // "skipped-locked"), and why, for Settings.
  property string lastAction: ""
  property string lastReason: ""

  // The watchdog handed the plugin back to Omarchy. Kept in Config so the
  // next shell start doesn't install it again straight into the same fault;
  // installing from Settings clears it. It holds only for the Omacale version
  // it happened under: an upgrade may be the fix (a wrapper that didn't fit
  // this Omarchy), so a new version gets one try, and if that breaks too the
  // watchdog falls back again and records it. Until the manifest is read,
  // any mark counts.
  readonly property bool fellBack: !!Config.get(configKey + ".autoFellBack")
    && (version === "" || Config.get(configKey + ".fellBackVersion") === version)

  // This Omacale's version, from its manifest.
  property string version: ""
  property FileView manifest: FileView {
    path: String(Qt.resolvedUrl("../manifest.json")).replace("file://", "")
    printErrors: false
    onLoaded: {
      try {
        root.version = JSON.parse(text()).version || ""
      } catch (e) {
        root.version = ""
      }
    }
  }

  // After anything that may have changed which daemon or view is running.
  signal changed

  function parse(text) {
    const out = {}
    for (const line of String(text).split("\n")) {
      const i = line.indexOf(":")
      if (i > 0)
        out[line.slice(0, i).trim()] = line.slice(i + 1).trim()
    }
    return out
  }

  function refresh() {
    if (!statusProc.running)
      statusProc.running = true
  }
  function install() {
    if (busy)
      return
    busy = true
    error = ""
    lastAction = ""
    Config.set(configKey + ".autoFellBack", false)
    installProc.running = true
  }
  function remove() {
    if (busy)
      return
    busy = true
    error = ""
    lastAction = ""
    removeProc.running = true
  }
  function check() {
    if (!ready || busy || clone === "" || fellBack)
      return
    busy = true
    watchdogProc.running = true
  }

  property Process statusProc: Process {
    command: ["python3", root.script, "status"]
    stdout: StdioCollector {
      onStreamFinished: {
        root.fields = root.parse(text)
        root.ready = true
      }
    }
  }

  property Process installProc: Process {
    command: ["python3", root.script].concat(root.installArgs)
    stderr: StdioCollector {
      onStreamFinished: if (String(text).trim())
        root.error = String(text).trim()
    }
    onExited: code => {
      root.busy = false
      if (code !== 0 && !root.error)
        root.error = "The handover failed; run " + root.script + " install in a terminal to see why."
      root.refresh()
      root.changed()
    }
  }

  property Process removeProc: Process {
    command: ["python3", root.script, "remove"]
    stderr: StdioCollector {
      onStreamFinished: if (String(text).trim())
        root.error = String(text).trim()
    }
    onExited: code => {
      root.busy = false
      if (code !== 0 && !root.error)
        root.error = "Could not give it back to Omarchy; run " + root.script + " remove in a terminal to see why."
      root.refresh()
      root.changed()
    }
  }

  property Process watchdogProc: Process {
    command: ["python3", root.script, "watchdog"]
    stdout: StdioCollector {
      onStreamFinished: {
        const r = root.parse(text)
        const action = r.action || "none"
        if (action !== "none") {
          root.lastAction = action
          root.lastReason = r.reason || r.refused || ""
        }
        if (action === "fellback") {
          Config.set(root.configKey + ".autoFellBack", true)
          Config.set(root.configKey + ".fellBackVersion", root.version)
          // Through whichever daemon is up by then -- after a notification
          // fallback that is Omarchy's own, back a moment after the removal.
          Quickshell.execDetached(["bash", "-c", "sleep 3; notify-send -a Omacale -u critical \"$1\" \"$2\"", "notify",
            root.title + " handed back to Omarchy",
            "After an Omarchy update, Omacale's version stopped working (" + root.lastReason + "). Omarchy's own is back; the next Omacale update tries again, or reinstall from Omacale's settings."])
        }
      }
    }
    onExited: {
      root.busy = false
      root.refresh()
      if (root.lastAction === "synced" || root.lastAction === "fellback")
        root.changed()
    }
  }

  // Shortly after start rather than at it: the plugin being checked may not
  // have registered its IPC yet, and that is not the same as broken.
  property Timer startCheck: Timer {
    interval: 20000
    running: root.ready
    onTriggered: root.check()
  }

  // pacman lands a package over several seconds; check once it has settled.
  property Timer settle: Timer {
    interval: 5000
    onTriggered: {
      // The watched files were replaced, not edited, so the old watches
      // point at unlinked inodes. Recreate them.
      root.watchers.active = false
      root.watchers.active = true
      root.check()
    }
  }

  property Instantiator watchers: Instantiator {
    model: root.stockPaths
    delegate: FileView {
      required property string modelData
      path: modelData
      watchChanges: true
      printErrors: false
      onFileChanged: root.settle.restart()
    }
  }

  property Connections updates: Connections {
    target: UpdateService
    function onFinished() {
      root.settle.restart()
    }
  }

  Component.onCompleted: refresh()
}
