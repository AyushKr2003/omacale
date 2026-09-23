pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."
// IdleService: Manages Omarchy idle behavior / keep awake mode.
// Integrates directly with Omarchy's indicators/stay-awake and idle engine.
QtObject {
  id: root

  property bool enabled: false
  property var enabledSince: null

  function run(cmd) { Quickshell.execDetached(["bash", "-c", cmd]) }

  function toggle() {
    if (enabled) disable()
    else enable()
  }

  function enable() {
    enabled = true
    enabledSince = new Date()
    run("mkdir -p \"$HOME/.local/state/omarchy/indicators\" && touch \"$HOME/.local/state/omarchy/indicators/stay-awake\" && omarchy-shell idle enable 2>/dev/null || true")
  }

  function disable() {
    enabled = false
    enabledSince = null
    run("rm -f \"$HOME/.local/state/omarchy/indicators/stay-awake\" && omarchy-shell idle disable 2>/dev/null || true")
  }

  property Process probe: Process {
    command: ["bash", "-c",
      "mkdir -p \"$HOME/.local/state/omarchy/indicators\"; " +
      "if [[ -f $HOME/.local/state/omarchy/indicators/stay-awake ]]; then echo 1; else echo 0; fi"]
    stdout: SplitParser {
      onRead: line => {
        const on = String(line).trim() === "1"
        if (root.enabled !== on) {
          root.enabled = on
          if (on && !root.enabledSince) root.enabledSince = new Date()
          else if (!on) root.enabledSince = null
        }
      }
    }
  }

  property FileView indicatorWatcher: FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/indicators"
    watchChanges: true
    printErrors: false
    onFileChanged: root.probe.running = true
  }

  property Timer checkTimer: Timer {
    interval: 3000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.probe.running = true
  }
}
