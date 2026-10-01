pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower
import ".."

// Caelestia's Toaster and Toast (plugin/src/Caelestia/toaster.cpp), which are
// C++, as QML: a list of small toasts, newest first, each closing on its own
// after a timeout and leaving the list once every view drawing it has
// finished its exit animation (Toast.lock / unlock).
//
// The toasts themselves come from all over Caelestia's services (Notifs,
// Audio, GameMode, Players, BatteryMonitor); here they are raised in one
// place, from Omacale's services, under Caelestia's utilities.toasts
// settings. Not ported: battery level warnings (Omarchy's battery service
// already notifies), VPN (Omacale has none) and the keyboard layout limit
// (Omacale adds no layouts).
QtObject {
  id: root

  // Caelestia's Toast.Type.
  readonly property int info: 0
  readonly property int success: 1
  readonly property int warning: 2
  readonly property int error: 3

  // Newest first, as Toaster::toast pushes to the front.
  property var toasts: []

  readonly property var cfg: Config.o.utilities.toasts

  function typeOf(name) {
    const n = String(name || "").toLowerCase()
    return n === "success" ? success : n === "warning" || n === "warn" ? warning : n === "error" ? error : info
  }

  function toast(title, message, icon, type, timeout) {
    const t = toastComp.createObject(root, {
      title: String(title || ""),
      message: String(message || ""),
      icon: String(icon || ""),
      type: type || info,
      timeout: timeout || 0
    })
    const list = [t]
    for (let i = 0; i < toasts.length; i++) list.push(toasts[i])
    toasts = list
    return t
  }

  function remove(t) {
    const list = []
    let found = false
    for (let i = 0; i < toasts.length; i++) {
      if (toasts[i] === t) found = true
      else list.push(toasts[i])
    }
    if (!found) return
    toasts = list
    t.destroy()
  }

  property Component toastComp: Component {
    QtObject {
      id: t

      property string title
      property string message
      property string icon
      property int type: 0
      property int timeout: 0
      property bool closed: false
      // The views still animating this toast out (Toast::lock).
      property var locks: []

      // toaster.cpp: a type's own icon and timeout when none is given.
      readonly property string iconName: icon !== "" ? icon
        : type === root.success ? "check_circle_unread" : type === root.warning ? "warning" : type === root.error ? "error" : "info"
      readonly property int lifetime: timeout > 0 ? timeout : type === root.warning ? 7000 : type === root.error ? 10000 : 5000

      function close() {
        closed = true
        if (locks.length === 0) root.remove(t)
      }
      function lock(sender) {
        if (locks.indexOf(sender) < 0) locks = locks.concat([sender])
      }
      function unlock(sender) {
        const i = locks.indexOf(sender)
        if (i < 0) return
        const next = locks.slice()
        next.splice(i, 1)
        locks = next
        if (closed && locks.length === 0) root.remove(t)
      }

      property Timer timer: Timer {
        interval: t.lifetime
        running: true
        onTriggered: t.close()
      }
    }
  }

  // ------------------------------------------------------------ sources
  //
  // Each waits for its service's first real value: a toast at login for
  // the state things were already in is noise.
  property bool armed: false
  property Timer armTimer: Timer {
    interval: 3000
    running: true
    onTriggered: root.armed = true
  }

  // Caelestia services/Notifs.qml onDndChanged.
  property Connections dndConn: Connections {
    target: NotifService
    function onDndChanged() {
      if (!root.armed || !root.cfg.dndChanged) return
      if (NotifService.dnd)
        root.toast("Do not disturb enabled", "Popup notifications are now disabled", "do_not_disturb_on")
      else
        root.toast("Do not disturb disabled", "Popup notifications are now enabled", "do_not_disturb_off")
    }
  }

  // Caelestia services/Audio.qml onSinkChanged / onSourceChanged.
  property string sinkName: ""
  property string sourceName: ""
  readonly property string currentSink: AudioService.sink && AudioService.sink.ready ? AudioService.deviceName(AudioService.sink) : ""
  readonly property string currentSource: AudioService.source && AudioService.source.ready ? AudioService.deviceName(AudioService.source) : ""
  onCurrentSinkChanged: {
    if (currentSink === "") return
    if (armed && sinkName !== "" && sinkName !== currentSink && cfg.audioOutputChanged)
      toast("Audio output changed", "Now using: " + currentSink, "volume_up")
    sinkName = currentSink
  }
  onCurrentSourceChanged: {
    if (currentSource === "") return
    if (armed && sourceName !== "" && sourceName !== currentSource && cfg.audioInputChanged)
      toast("Audio input changed", "Now using: " + currentSource, "mic")
    sourceName = currentSource
  }

  // Caelestia services/GameMode.qml onEnabledChanged.
  property Connections gameConn: Connections {
    target: GameMode
    function onEnabledChanged() {
      if (!root.armed || !root.cfg.gameModeChanged) return
      if (GameMode.enabled)
        root.toast("Game mode enabled", "Disabled Hyprland animations, blur, gaps and shadows", "gamepad")
      else
        root.toast("Game mode disabled", "Hyprland settings restored", "gamepad")
    }
  }

  // Caelestia modules/BatteryMonitor.qml onOnBatteryChanged (the charger
  // half; Omarchy's battery service sends the low-battery warnings).
  property Connections powerConn: Connections {
    target: UPower
    function onOnBatteryChanged() {
      if (!root.armed || !root.cfg.chargingChanged || !UPower.displayDevice || !UPower.displayDevice.ready || !UPower.displayDevice.isLaptopBattery) return
      if (UPower.onBattery)
        root.toast("Charger unplugged", "Battery is discharging", "power_off")
      else
        root.toast("Charger plugged in", "Battery is charging", "power")
    }
  }

  // Caelestia services/Players.qml: a new track on the active player.
  // Off by default, as in Caelestia.
  property string nowPlayingKey: ""
  readonly property string trackKey: {
    const p = Sys.player
    if (!p || !p.trackTitle || !p.trackArtist) return ""
    return Sys.playerName(p) + "\u0000" + p.trackTitle + "\u0000" + p.trackArtist
  }
  onTrackKeyChanged: {
    if (trackKey === "" || trackKey === nowPlayingKey) return
    nowPlayingKey = trackKey
    if (armed && cfg.nowPlaying && Sys.player)
      toast("Now playing", Sys.player.trackArtist + " - " + Sys.player.trackTitle, "music_note")
  }
}
