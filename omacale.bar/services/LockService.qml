pragma Singleton
import QtQuick
import Quickshell
import ".."

// The state of the lock-screen handover, and the actions that change it
// (scripts/lock-screen). Omarchy's lock plugin keeps owning the session lock
// and PAM; the handover only decides who draws the surface -- see
// scripts/lock-screen and assets/lock/LockView.qml. Handover keeps the clone
// in step with Omarchy updates and gives the lock back if it breaks.
//
// Settings › Panels › Lock screen is the switch: turning it on installs the
// handover if it is not there yet, and turning it off hands the drawing
// straight back (the clone stays, drawing Omarchy's own view, so nothing is
// torn down behind a lock that may be up).
Handover {
  id: root

  script: String(Qt.resolvedUrl("../scripts/lock-screen")).replace("file://", "")
  configKey: "lock"
  title: "Lock screen"
  stockPaths: [
    Quickshell.env("OMARCHY_PATH") + "/shell/plugins/lock/Service.qml",
    Quickshell.env("OMARCHY_PATH") + "/shell/plugins/lock/LockView.qml"
  ]

  readonly property string view: fields.view || "omarchy"   // "omacale vN" | "omarchy" | "missing"
  readonly property string expects: fields.expects || ""    // the wrapper this Omacale would write

  // An older wrapper still says "omacale", but loads Omacale's UI from a path
  // that has since moved, so it would quietly draw the stock view instead.
  // Requiring the current version makes the upgrade re-install itself.
  readonly property bool installed: clone !== "" && cloneEnabled
    && view === (expects === "" ? view : expects) && view.startsWith("omacale")
  readonly property bool wanted: Config.o.lock.enabled

  function preview() {
    Quickshell.execDetached(["omarchy-shell", "lock", "preview"])
  }

  // Turning the setting on is what installs the handover. Tried once per
  // shell session: a clone that will not install should not be retried on
  // every toggle of a switch that is already on, and one the watchdog handed
  // back is only reinstalled from Settings. The check is a handler rather
  // than a bound property because performing it changes what it reads, which
  // as a binding is a loop.
  property bool attempted: false
  function maybeInstall() {
    if (!ready || !wanted || installed || busy || attempted || fellBack)
      return
    attempted = true
    install()
  }
  onReadyChanged: maybeInstall()
  onWantedChanged: maybeInstall()
}
