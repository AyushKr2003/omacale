pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// The state of the lock-screen handover, and the two actions that change it
// (scripts/lock-screen). Omarchy's lock plugin keeps owning the session lock
// and PAM; the handover only decides who draws the surface -- see
// scripts/lock-screen and assets/lock/LockView.qml.
//
// Settings › Panels › Lock screen is the switch: turning it on installs the
// handover if it is not there yet, and turning it off hands the drawing
// straight back (the clone stays, drawing Omarchy's own view, so nothing is
// torn down behind a lock that may be up).
QtObject {
  id: root

  readonly property string script: String(Qt.resolvedUrl("../scripts/lock-screen")).replace("file://", "")

  property bool ready: false
  property string clone: ""         // the clone's plugin id, "" when there is none
  property bool cloneEnabled: false
  property string view: "omarchy"   // "omacale vN" | "omarchy" | "missing"
  property string expects: ""       // the wrapper this Omacale would write
  property bool stale: false        // the clone's copy of Omarchy's service is old
  property bool busy: false
  property string error: ""

  // An older wrapper still says "omacale", but loads Omacale's UI from a path
  // that has since moved, so it would quietly draw the stock view instead.
  // Requiring the current version makes the upgrade re-install itself.
  readonly property bool installed: clone !== "" && cloneEnabled
    && view === (expects === "" ? view : expects) && view.startsWith("omacale")
  readonly property bool wanted: Config.o.lock.enabled

  function refresh() {
    if (!statusProc.running)
      statusProc.running = true
  }
  function install() {
    if (busy)
      return
    busy = true
    error = ""
    installProc.running = true
  }
  function remove() {
    if (busy)
      return
    busy = true
    error = ""
    removeProc.running = true
  }
  function preview() {
    Quickshell.execDetached(["omarchy-shell", "lock", "preview"])
  }

  // Turning the setting on is what installs the handover. Tried once per
  // shell session: a clone that will not install should not be retried on
  // every toggle of a switch that is already on. The check is a handler
  // rather than a bound property because performing it changes what it
  // reads, which as a binding is a loop.
  property bool attempted: false
  function maybeInstall() {
    if (!ready || !wanted || installed || busy || attempted)
      return
    attempted = true
    install()
  }
  onReadyChanged: maybeInstall()
  onWantedChanged: maybeInstall()

  property Process statusProc: Process {
    command: ["python3", root.script, "status"]
    stdout: StdioCollector {
      onStreamFinished: {
        let clone = "", enabled = false, view = "omarchy", stale = false, expects = ""
        for (const line of String(text).split("\n")) {
          const i = line.indexOf(":")
          if (i < 0)
            continue
          const key = line.slice(0, i).trim()
          const value = line.slice(i + 1).trim()
          if (key === "clone" && value !== "none") {
            clone = value.split(" ")[0]
            enabled = value.indexOf("(enabled)") >= 0
          } else if (key === "view") {
            view = value
          } else if (key === "stale") {
            stale = value === "yes"
          } else if (key === "expects") {
            expects = value
          }
        }
        root.clone = clone
        root.cloneEnabled = enabled
        root.view = view
        root.expects = expects
        root.stale = stale
        root.ready = true
      }
    }
  }

  property Process installProc: Process {
    command: ["python3", root.script, "install"]
    stderr: StdioCollector {
      onStreamFinished: if (String(text).trim())
        root.error = String(text).trim()
    }
    onExited: code => {
      root.busy = false
      if (code !== 0 && !root.error)
        root.error = "The handover failed; run scripts/lock-screen install in a terminal to see why."
      root.refresh()
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
        root.error = "Could not give the lock screen back; run scripts/lock-screen remove in a terminal to see why."
      root.refresh()
    }
  }

  Component.onCompleted: refresh()
}
