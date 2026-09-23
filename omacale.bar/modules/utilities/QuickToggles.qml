import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../.."

// Quick toggles card (Caelestia utilities/cards/Toggles.qml): a title and one
// or two ButtonRows of round icon buttons that morph to a squircle when on and
// bulge when pressed. Which buttons show comes from Settings › Utilities, like
// Caelestia's `utilities.quickToggles`; more than six wrap onto a second row.
// Caelestia's VPN toggle is left out: Omarchy has no VPN provider for it.
Rectangle {
  id: root

  property var host
  property var scope

  property bool nightlightOn: false

  readonly property var micSrc: Pipewire.defaultAudioSource
  readonly property bool micOn: micSrc && micSrc.audio ? !micSrc.audio.muted : true

  readonly property var all: [
    { id: "wifi", icon: "wifi", toggle: true },
    { id: "bluetooth", icon: "bluetooth", toggle: true },
    { id: "mic", icon: "mic", toggle: true },
    { id: "settings", icon: "settings", toggle: false },
    { id: "gameMode", icon: "gamepad", toggle: true },
    { id: "dnd", icon: "notifications_off", toggle: true },
    { id: "nightlight", icon: "nightlight", toggle: true }
  ]
  // Only changes when the settings do, never when a toggle's state flips, so
  // the Repeater keeps its buttons mid-press.
  readonly property var toggles: {
    const on = Config.o.utilities.toggles
    return all.filter(t => !on || on[t.id] !== false)
  }
  readonly property int splitIndex: Math.ceil(toggles.length / 2)
  readonly property bool needExtraRow: toggles.length > 6

  function isOn(id) {
    switch (id) {
      case "wifi": return NetService.wifiEnabled
      case "bluetooth": return BtService.enabled
      case "mic": return micOn
      case "gameMode": return GameMode.enabled
      case "dnd": return NotifService.dnd
      case "nightlight": return nightlightOn
    }
    return false
  }

  function activate(id) {
    if (id === "wifi") NetService.setWifiEnabled(!NetService.wifiEnabled)
    else if (id === "bluetooth") BtService.setEnabled(!BtService.enabled)
    else if (id === "mic") {
      if (micSrc && micSrc.audio) micSrc.audio.muted = !micSrc.audio.muted
      else Sys.run("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle")
    }
    else if (id === "settings") openSettings("")
    else if (id === "gameMode") GameMode.toggle()
    else if (id === "dnd") NotifService.toggleDnd()
    else if (id === "nightlight") { Sys.run("omarchy toggle nightlight"); nlProbe.running = true }
  }

  // Caelestia closes the utilities drawer and opens its settings window;
  // `page` opens it on one page (right-click on Wi-Fi / Bluetooth).
  function openSettings(page) {
    if (scope) { scope.utilities = false; scope.sidebar = false }
    if (host) host.toggle("settings", page)
  }
  readonly property var settingsPages: ({ wifi: "network", bluetooth: "bluetooth" })

  Process {
    id: nlProbe
    command: ["bash", "-c", "[[ -f $HOME/.local/state/omarchy/toggles/nightlight ]] && echo 1 || echo 0"]
    stdout: SplitParser { onRead: line => root.nightlightOn = String(line).trim() === "1" }
  }
  Timer { interval: 3000; running: root.toggles.some(t => t.id === "nightlight"); repeat: true; triggeredOnStart: true; onTriggered: nlProbe.running = true }

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
        // A muted mic shows mic_off, as the bar's microphone icon does.
        icon: modelData.id === "mic" && !root.micOn ? "mic_off" : modelData.icon
        checked: root.isOn(modelData.id)
        toggle: modelData.toggle
        fillWidth: true
        shapeMorph: true
        round: true
        inactiveColour: Colours.layer(Colours.palette.m3surfaceContainerHighest, 2)
        inactiveOnColour: Colours.m3onSurfaceVariant
        onClicked: root.activate(modelData.id)

        // Right-click jumps to the matching settings page. Only the right
        // button is taken, so left clicks still reach the button below.
        MouseArea {
          anchors.fill: parent
          enabled: !!root.settingsPages[parent.modelData.id]
          acceptedButtons: Qt.RightButton
          onClicked: root.openSettings(root.settingsPages[parent.modelData.id])
        }
      }
    }
  }
}
