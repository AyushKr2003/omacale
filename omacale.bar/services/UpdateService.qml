pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."
// UpdateService: the stock bar's omarchy.system-update widget
// (shell/plugins/bar/widgets/SystemUpdate.qml), as one singleton. The stock
// widget runs its check once per bar surface; this runs it once for every
// screen. Same engine: `omarchy-update-available` (exit 0 = pending, one line
// per update) every 6h, and the update in Omarchy's floating terminal.
QtObject {
  id: root

  property bool available: false
  property var lines: []
  // An update was launched from here and hasn't released its lock yet.
  property bool running: false

  function refresh() {
    if (!check.running) check.running = true
  }

  // Detached: omarchy-update restarts the shell, and a Process child dies
  // with it -- that would kill the terminal mid-update.
  function update() {
    if (running) return
    Quickshell.execDetached(["omarchy-launch-floating-terminal-with-presentation", "omarchy-update"])
    running = true
    lockPoll.restart()
  }

  property Process check: Process {
    command: ["omarchy-update-available"]
    stdout: StdioCollector {
      onStreamFinished: root.lines = text.split("\n").filter(l => l.trim().length > 0)
    }
    onExited: code => root.available = code === 0
  }

  property Timer schedule: Timer {
    interval: 21600000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  // omarchy-update holds $XDG_RUNTIME_DIR/omarchy-update.lock for its whole
  // run (omarchy-update-lock). Polling the lock is a flock, not a pacman
  // query, so the re-check runs once, when the update (or a cancelled
  // confirm) lets go of it.
  property Timer lockPoll: Timer {
    interval: 15000
    repeat: true
    onTriggered: if (!lock.running) lock.running = true
  }
  property Process lock: Process {
    command: ["bash", "-c", "exec flock -n \"${XDG_RUNTIME_DIR:-/tmp}/omarchy-update.lock\" true"]
    onExited: code => {
      if (code !== 0) return
      root.lockPoll.stop()
      root.running = false
      root.refresh()
    }
  }
}
