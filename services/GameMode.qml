pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import ".."

// Game Mode: disables animations, shadows, blur, and window gaps for maximum performance.
// Toggling off calls `hyprctl reload` to restore the user's configured settings.
QtObject {
  id: root

  property bool enabled: false

  function toggle() {
    if (enabled) disable()
    else enable()
  }

  function enable() {
    enabled = true
    Quickshell.execDetached(["hyprctl", "--batch",
      "keyword animations:enabled 0; " +
      "keyword decoration:shadow:enabled 0; " +
      "keyword decoration:blur:enabled 0; " +
      "keyword general:gaps_in 0; " +
      "keyword general:gaps_out 0"
    ])
  }

  function disable() {
    enabled = false
    Quickshell.execDetached(["hyprctl", "reload"])
  }

  // Probe current state from Hyprland
  property Process probe: Process {
    command: ["hyprctl", "getoption", "animations:enabled", "-j"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const j = JSON.parse(text)
          if (j && j.bool === false) root.enabled = true
          else root.enabled = false
        } catch (e) {}
      }
    }
  }

  property Connections hyprConn: Connections {
    target: Hyprland
    function onRawEvent(e) {
      if (e.name === "configreloaded") root.probe.running = true
    }
  }

  Component.onCompleted: probe.running = true
}
