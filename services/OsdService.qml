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
  // each call show() on an Audio or brightness change. hold is how long it
  // stays out (ms; 0 is the hideDelay setting, -1 until dismissed): an
  // Omarchy OSD can ask for longer, or to stay until it is closed.
  signal requested(int hold)
  // Omarchy's `osd close` while the sliders were the last OSD shown.
  signal dismissed()

  // The runtime directory, which only this user can read or write. Without
  // one there is no claim and nothing is forwarded, so Omarchy draws every
  // OSD: no /tmp fallback another user could plant files in.
  readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || ""

  // Omacale's bar claims the OSD for this shell process (Bar.qml, on load and
  // unload); the patched clone only takes payloads while the claim names its
  // own process, so a bar that failed to load, or a claim a crashed shell
  // left behind, gives every OSD back to Omarchy.
  function claim(on) {
    if (runtimeDir === "") return
    // The forward file is created here, before anything is forwarded: a
    // watch on a file that doesn't exist yet (a fresh runtime directory after
    // a reboot) never sees it appear.
    if (on) forwarded.setText("{}")
    claimFile.setText(JSON.stringify({ pid: on ? Quickshell.processId : 0 }))
  }
  property FileView claimFile: FileView {
    path: root.runtimeDir === "" ? "" : root.runtimeDir + "/omacale-osd-claim.json"
    atomicWrites: true
    printErrors: false
  }

  readonly property var cfg: Config.o.osd
  // The keys only come here once Omarchy's OSD has stepped aside for them.
  // Until then a volume key already draws Omarchy's OSD, so a Pipewire change
  // opens nothing here (two OSDs for one key press); the drawer still opens
  // on hover.
  readonly property bool keysHandedOver: OsdHandover.active && cfg.enabled

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
  // included, but not on the values arriving at login -- here only once the
  // handover is in, see keysHandedOver.
  property bool armed: false
  property Timer armTimer: Timer {
    interval: 3000
    running: true
    onTriggered: root.armed = true
  }
  function changed() {
    if (armed && keysHandedOver) {
      lastShown = "sliders"
      requested(0)
    }
  }
  onVolumeChanged: changed()
  onMutedChanged: changed()
  onSourceVolumeChanged: if (cfg.enableMicrophone) changed()
  onSourceMutedChanged: if (cfg.enableMicrophone) changed()

  // ---------------------------------------------------------- toasts
  //
  // Every other Omarchy OSD -- media, keyboard backlight, mic mute, the
  // output switcher, input devices, power, app launches, `omarchy osd -m` --
  // as one of Caelestia's utilities toasts (Toaster), when osd.toasts is on.
  // Keyed by kind, so a key that repeats updates its toast. Omarchy's icon
  // names are its own (OsdModel.iconFor), so they are mapped to Material
  // Symbols here; a literal glyph only has a name for the two Omarchy sends.

  // The toast body is StyledText (Caelestia's), and a track title or device
  // name is anyone's text.
  function esc(text) {
    return String(text).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;")
  }

  readonly property var mediaTitles: ({
    "play": "Playing", "pause": "Paused", "next": "Next track",
    "previous": "Previous track", "source": "Media source"
  })
  readonly property var mediaIcons: ({
    "play": "play_arrow", "pause": "pause", "next": "skip_next",
    "previous": "skip_previous", "source": "queue_music"
  })

  // { title, body, icon, group } for a payload.
  function describe(p) {
    const key = String(p.iconKey || "")
    const message = String(p.message || "")
    // With a value, the message is Omarchy's "60%".
    const plain = (title, icon, group) => p.hasProgress
      ? { title: title, body: message, icon: icon, group: group }
      : { title: message || title, body: "", icon: icon, group: group }
    if (key.indexOf("volume") === 0)
      return p.hasProgress
        ? plain("Volume", key === "volume-muted" ? "volume_off" : "volume_up", "volume")
        : { title: "Audio output changed", body: "Now using: " + message, icon: "volume_up", group: "output" }
    if (key.indexOf("microphone") === 0 || key.indexOf("mic") === 0)
      return plain("Microphone", /(muted|off)$/.test(key) ? "mic_off" : "mic", "microphone")
    if (key === "brightness" || key === "display") return plain("Brightness", "light_mode", "brightness")
    if (key === "keyboard") return plain("Keyboard backlight", "keyboard", "keyboard")
    if (key === "touchpad") return plain("Touchpad", "touchpad_mouse", key)
    if (key === "touch" || key === "touchscreen") return plain("Touchscreen", "touch_app", key)
    if (key === "shutdown" || key === "power" || key === "poweroff") return plain("Shutting down", "power_settings_new", "power")
    if (key === "reboot" || key === "restart") return plain("Rebooting", "restart_alt", "power")
    if (key === "logout" || key === "sign-out" || key === "leave") return plain("Logging out", "logout", "power")
    const media = /^(media|player)(-(play|pause|next|previous|source))?$/.exec(key)
    if (media) {
      const action = media[3] || ""
      return { title: mediaTitles[action] || "Media", body: message, icon: mediaIcons[action] || "music_note", group: "media" }
    }
    if (key === String.fromCodePoint(0xF01DA)) return plain("Downloading", "download", "download")
    if (key === String.fromCodePoint(0xF14DE)) return plain("Launching", "rocket_launch", "launch")
    return plain(p.hasProgress ? "Progress" : "", "info", "other:" + key)
  }

  // What the last OSD shown was: "sliders", or the toast (Omarchy has one
  // OSD, and `osd close` hides whatever it shows).
  property var lastShown: null

  // Omarchy's 1200ms default is an OSD's, far shorter than a toast's; only
  // a longer one (power 5000, downloads 8000) or 0 (until closed) is kept.
  function holdFor(p) {
    const duration = Number(p.duration)
    return duration === 0 ? -1 : duration > 1200 ? Math.min(duration, 600000) : 0
  }

  // A message is one elided line; more than this is never drawn.
  function clip(text) {
    const t = String(text || "")
    return t.length > 300 ? t.slice(0, 300) + "…" : t
  }

  function toastFor(p) {
    const d = describe(p)
    if (d.title === "" && d.body === "") return
    lastShown = Toaster.toast(clip(d.title), esc(clip(d.body)), d.icon, Toaster.info, holdFor(p), "osd:" + d.group)
  }

  function close() {
    const shown = lastShown
    lastShown = null
    if (shown === "sliders") dismissed()
    else if (shown && !shown.closed) shown.close()
  }

  // The patched Omarchy OSD writes each payload it leaves to Omacale here
  // instead of drawing it: { seq, at, kind, iconKey, message, hasProgress,
  // value, max, duration }. kind is a slider (volume, microphone,
  // brightness), toast, output (the output switcher with osd.toasts off,
  // which is Toaster's own device-change toast) or close (Omarchy's
  // `osd close`). A key press shows the sliders even when it changes
  // nothing, e.g. volume up at 100%.
  // seq restarts whenever the clone is reloaded, so a payload is told apart
  // by seq and time together.
  property string lastKey: ""
  property FileView forwarded: FileView {
    path: root.runtimeDir === "" ? "" : root.runtimeDir + "/omacale-osd.json"
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
      const key = p ? p.seq + "@" + p.at : ""
      if (!p || p.seq === undefined || key === root.lastKey) return
      root.lastKey = key
      if (p.kind === "brightness") {
        const max = Math.max(1, Number(p.max) || 100)
        root.brightness = Math.max(0, Math.min(1, Number(p.value) / max))
        root.hasBrightness = true
      }
      // A payload left over from before this shell started is a level, not
      // a key press. The clone only passes on what it didn't draw, so this
      // doesn't wait for keysHandedOver.
      const fresh = Date.now() - Number(p.at || 0) < 2000
      if (!fresh) return
      if (p.kind === "close") {
        root.close()
        return
      }
      if (!root.armed || !root.cfg.enabled) return
      if (p.kind === "toast") root.toastFor(p)
      else if (p.kind === "volume" || p.kind === "microphone" || p.kind === "brightness") {
        root.lastShown = "sliders"
        root.requested(root.holdFor(p))
      }
    }
  }
}
