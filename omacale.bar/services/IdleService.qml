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

  // Keep awake is the presence of Omarchy's indicator file, so read it
  // rather than asking a shell whether it exists: this used to be a
  // `bash -c` every 3s for the whole session to answer "no" each time.
  function setEnabled(on) {
    if (root.enabled === on)
      return
    root.enabled = on
    if (on && !root.enabledSince)
      root.enabledSince = new Date()
    else if (!on)
      root.enabledSince = null
  }

  property FileView indicator: FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/indicators/stay-awake"
    printErrors: false
    onLoaded: root.setEnabled(true)
    onLoadFailed: root.setEnabled(false)
  }

  // The indicator file is created and deleted rather than written, so the
  // watch has to be on the directory holding it.
  property FileView indicatorWatcher: FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/indicators"
    watchChanges: true
    printErrors: false
    onFileChanged: root.indicator.reload()
  }

  // Safety net for a change the directory watch misses (the directory itself
  // being created, most of all -- a machine that has never used keep awake
  // has nothing there to watch).
  property Timer checkTimer: Timer {
    interval: 30000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.indicator.reload()
  }
}
