pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."
import "DisplayModel.js" as Model

// Settings › Display › Night light. Omarchy's night light is hyprsunset at a
// warm temperature (omarchy-toggle-nightlight: 4000 K on, 6500 K off); this
// drives the same hyprsunset the same way, with a temperature of the user's
// choice, and keeps Omarchy's indicator in step (`omarchy-shell nightlight
// refresh`). The schedule runs here rather than in hyprsunset.conf, which is
// the user's file: it only acts when the schedule crosses a boundary, so a
// manual switch holds until the next one. hyprsunset tints every screen; it
// has no per-screen setting.
QtObject {
  id: root

  readonly property var cfg: Config.o.display
  property bool on: false
  property int temperature: 0            // hyprsunset's current value, 0 if unknown

  function set(wanted) {
    on = wanted
    apply.command = ["sh", "-c", `
      pgrep -x hyprsunset >/dev/null || { setsid uwsm-app -- hyprsunset >/dev/null 2>&1 & }
      # A freshly started hyprsunset applies its default at the end of its
      # boot, so resend until it sticks (as omarchy-toggle-nightlight does).
      for _ in 1 2 3 4 5 6 7 8 9 10; do
        hyprctl hyprsunset temperature "$1" >/dev/null 2>&1
        sleep 0.2
        [ "$(hyprctl hyprsunset temperature 2>/dev/null | grep -oE '[0-9]+' | head -n1)" = "$1" ] && break
      done
      omarchy-shell -q nightlight refresh >/dev/null 2>&1 || true
    `, "night", String(wanted ? cfg.nightTemp : 6500)]
    apply.running = true
  }
  function setTemperature(k) {
    Config.set("display.nightTemp", k)
    if (on) tempLater.restart()
  }
  // A dragged slider: apply once it settles, not on every step.
  property Timer tempLater: Timer { interval: 250; onTriggered: if (root.on) root.set(true) }
  property Process apply: Process { onExited: root.status.running = true }

  // Omarchy's own reading of it (`--status`), so a toggle from its menu or
  // the utilities quick toggle shows here too.
  property Process status: Process {
    command: ["omarchy-toggle-nightlight", "--status"]
    stdout: StdioCollector {
      onStreamFinished: {
        try { const j = JSON.parse(text); root.on = !!j.enabled; root.temperature = j.temperature || 0 } catch (e) {}
        root.tick()                    // against what is really on, never a stale guess
      }
    }
  }

  // ------------------------------------------------------------ schedule
  property var lastWanted: null
  function tick() {
    const d = new Date()
    const w = Model.nightWanted(d.getHours() * 60 + d.getMinutes(), cfg.nightSchedule, cfg.nightFrom, cfg.nightTo, Sys.sunsetIso, Sys.sunriseIso)
    if (w !== null && w !== lastWanted && w !== on) set(w)
    lastWanted = w
  }
  // A schedule change counts as a boundary: apply what it says now.
  property Connections cfgWatch: Connections {
    target: root.cfg
    function onNightScheduleChanged() { root.lastWanted = null; root.status.running = true }
    function onNightFromChanged() { root.lastWanted = null; root.status.running = true }
    function onNightToChanged() { root.lastWanted = null; root.status.running = true }
  }
  property Timer clock: Timer {
    interval: 30000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.status.running = true
  }
}
