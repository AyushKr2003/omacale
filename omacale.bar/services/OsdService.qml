pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// What Caelestia's OSD shows (modules/osd/Wrapper.qml), for every screen's
// drawer: the speaker and microphone from Pipewire (AudioService), and the
// display brightness, which Omacale has no model of its own for. Caelestia
// keeps one (services/Brightness.qml); here the level comes from Omarchy, in
// the payloads its brightness keys send the OSD, passed on by the patched
// OSD clone (scripts/osd-handover) through a file in the runtime directory,
// and is set back through omarchy-brightness-display.
QtObject {
  id: root

  // Every screen's drawer shows itself on this, as Caelestia's Wrappers
  // each call show() on an Audio or brightness change.
  signal requested()

  readonly property var cfg: Config.o.osd
  // The keys only come here once Omarchy's OSD has stepped aside for them;
  // without the handover the drawer still opens on hover.
  readonly property bool keysHandedOver: OsdHandover.installed && cfg.enabled

  readonly property real volume: AudioService.volume
  readonly property bool muted: AudioService.muted
  readonly property real sourceVolume: AudioService.sourceVolume
  readonly property bool sourceMuted: AudioService.sourceMuted

  // 0..1; unknown (and the slider hidden) until Omarchy has reported a level.
  property real brightness: 0
  property bool hasBrightness: false

  function setVolume(v) { AudioService.setVolume(v) }
  function setSourceVolume(v) { AudioService.setSourceVolume(v) }
  function stepVolume(d) { setVolume(volume + d * Config.o.services.volumeStep / 100) }
  function stepSourceVolume(d) { setSourceVolume(sourceVolume + d * Config.o.services.volumeStep / 100) }

  // Dragging the slider: one write in flight at a time, the last value wins.
  property real pendingBrightness: -1
  function setBrightness(v) {
    const b = Math.max(0.01, Math.min(1, v))
    brightness = b
    pendingBrightness = b
    if (!setProc.running) flushBrightness()
  }
  function stepBrightness(d) { setBrightness(brightness + d * Config.o.services.brightnessStep / 100) }
  function flushBrightness() {
    if (pendingBrightness < 0) return
    setProc.command = ["omarchy-brightness-display", "--no-osd", Math.round(pendingBrightness * 100) + "%"]
    pendingBrightness = -1
    setProc.running = true
  }
  property Process setProc: Process {
    onExited: root.flushBrightness()
  }

  // The level at start: `omarchy-brightness-display` with no step prints the
  // focused display's percentage (backlight, DDC or Apple), or fails on a
  // machine with no controllable display.
  property Process readProc: Process {
    command: ["omarchy-brightness-display"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        const n = parseInt(String(text).trim(), 10)
        if (isFinite(n) && n >= 0 && n <= 100) {
          root.brightness = n / 100
          root.hasBrightness = true
        }
      }
    }
  }

  // Caelestia shows the OSD on every volume change, the slider in a popout
  // included, but not on the values arriving at login.
  property bool armed: false
  property Timer armTimer: Timer {
    interval: 3000
    running: true
    onTriggered: root.armed = true
  }
  function changed() { if (armed && cfg.enabled) requested() }
  onVolumeChanged: changed()
  onMutedChanged: changed()
  onSourceVolumeChanged: if (cfg.enableMicrophone) changed()
  onSourceMutedChanged: if (cfg.enableMicrophone) changed()

  // The patched Omarchy OSD writes a display brightness payload here instead
  // of drawing it: { seq, kind, value, max, at }.
  property int lastSeq: -1
  property FileView forwarded: FileView {
    path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/omacale-osd.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      let p = null
      try {
        p = JSON.parse(text())
      } catch (e) {
        return
      }
      if (!p || p.kind !== "brightness" || p.seq === root.lastSeq) return
      root.lastSeq = p.seq
      const max = Math.max(1, Number(p.max) || 100)
      root.brightness = Math.max(0, Math.min(1, Number(p.value) / max))
      root.hasBrightness = true
      // A payload left over from before this shell started is a level, not
      // a key press.
      if (Date.now() - Number(p.at || 0) < 2000) root.changed()
    }
  }
}
