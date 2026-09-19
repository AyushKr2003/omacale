import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire

// Quick toggles card (Caelestia utilities/cards/Toggles.qml): a title and one
// or two ButtonRows of round icon buttons that morph to a squircle when on and
// bulge when pressed.
Rectangle {
  id: root

  property var host
  property var scope

  property bool nightlightOn: false
  property bool vpnActive: false

  readonly property var adapter: Bluetooth.defaultAdapter
  readonly property var micSrc: Pipewire.defaultAudioSource
  readonly property bool micOn: micSrc && micSrc.audio ? !micSrc.audio.muted : true

  // Same order as Caelestia's default list, plus Omarchy's night light.
  // Static definitions: the model must not change when a state flips, or the
  // Repeater would rebuild the buttons mid-press.
  readonly property var toggles: [
    { id: "wifi", icon: "wifi", toggle: true },
    { id: "bluetooth", icon: "bluetooth", toggle: true },
    { id: "mic", icon: "mic", toggle: true },
    { id: "settings", icon: "settings", toggle: false },
    { id: "gameMode", icon: "gamepad", toggle: true },
    { id: "dnd", icon: "notifications_off", toggle: true },
    { id: "nightlight", icon: "nightlight", toggle: true },
    { id: "vpn", icon: "vpn_key", toggle: true }
  ]
  function isOn(id) {
    switch (id) {
      case "wifi": return Sys.wifi || Sys.ethernet
      case "bluetooth": return adapter ? adapter.enabled : false
      case "mic": return micOn
      case "gameMode": return GameMode.enabled
      case "dnd": return NotifService.dnd
      case "nightlight": return nightlightOn
      case "vpn": return vpnActive
    }
    return false
  }
  readonly property int splitIndex: Math.ceil(toggles.length / 2)
  readonly property bool needExtraRow: toggles.length > 6

  function activate(id) {
    if (id === "wifi") Sys.run("nmcli radio wifi " + (Sys.wifi ? "off" : "on"))
    else if (id === "bluetooth") { if (adapter) adapter.enabled = !adapter.enabled }
    else if (id === "mic") {
      if (micSrc && micSrc.audio) micSrc.audio.muted = !micSrc.audio.muted
      else Sys.run("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle")
    }
    else if (id === "settings") { if (host) host.toggle("settings") }
    else if (id === "gameMode") GameMode.toggle()
    else if (id === "dnd") NotifService.toggleDnd()
    else if (id === "nightlight") { Sys.run("omarchy toggle nightlight"); nlProbe.running = true }
    else if (id === "vpn") {
      Sys.run("omarchy-launch-vpn || omarchy-shell tailscale toggle 2>/dev/null || nmcli connection down id vpn 2>/dev/null || true")
      vpnProbe.running = true
    }
  }

  Process {
    id: nlProbe
    command: ["bash", "-c", "[[ -f $HOME/.local/state/omarchy/toggles/nightlight ]] && echo 1 || echo 0"]
    stdout: SplitParser { onRead: line => root.nightlightOn = String(line).trim() === "1" }
  }
  Timer { interval: 3000; running: true; repeat: true; triggeredOnStart: true; onTriggered: nlProbe.running = true }
  Process {
    id: vpnProbe
    command: ["bash", "-c", "nmcli -t -f TYPE con show --active 2>/dev/null | grep -qE 'vpn|wireguard|tailscale' && echo 1 || echo 0"]
    stdout: SplitParser { onRead: line => root.vpnActive = String(line).trim() === "1" }
  }
  Timer { interval: 5000; running: true; repeat: true; triggeredOnStart: true; onTriggered: vpnProbe.running = true }

  implicitHeight: layout.implicitHeight + Tk.padding.extraLargeIncreased
  radius: Tk.rounding.large
  color: Colours.m3surfaceContainer

  ColumnLayout {
    id: layout
    anchors.fill: parent
    anchors.margins: Tk.padding.large
    spacing: Tk.spacing.medium

    MText {
      text: "Quick toggles"
      font.pointSize: Tk.body.medium
    }

    ToggleRow { model: root.needExtraRow ? root.toggles.slice(0, root.splitIndex) : root.toggles }
    ToggleRow { visible: root.needExtraRow; model: root.needExtraRow ? root.toggles.slice(root.splitIndex) : [] }
  }

  component ToggleRow: ButtonRow {
    property alias model: repeater.model
    Layout.fillWidth: true
    spacing: Tk.spacing.small

    Repeater {
      id: repeater
      delegate: IconButton {
        required property var modelData
        icon: modelData.icon
        checked: root.isOn(modelData.id)
        toggle: modelData.toggle
        fillWidth: true
        shapeMorph: true
        round: true
        inactiveColour: Colours.m3surfaceContainerHighest
        inactiveOnColour: Colours.m3onSurfaceVariant
        onClicked: root.activate(modelData.id)
      }
    }
  }
}
