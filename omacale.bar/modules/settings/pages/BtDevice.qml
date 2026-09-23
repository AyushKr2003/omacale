import QtQuick
import QtQuick.Layouts
import "../../.."

// Settings › Connected devices › device. Port of Caelestia's nexus
// bluetooth/BtDeviceInfo.qml: Forget / Connect buttons, per-device switches
// and battery / address info.
ColumnLayout {
  id: root
  property var row
  property var settings
  property bool first
  property bool last

  readonly property var dev: BtService.selected
  readonly property bool connected: !!(dev && dev.connected)
  readonly property string action: BtService.pendingOf(dev)
  spacing: Tk.spacing.extraSmall / 2

  // A forgotten device disappears from BlueZ; leave the page with it.
  onDevChanged: if (!dev && root.settings) root.settings.back()

  RowLayout {
    Layout.fillWidth: true
    Layout.bottomMargin: Tk.spacing.large
    spacing: Tk.spacing.medium
    Rectangle {
      implicitWidth: implicitHeight
      implicitHeight: headIcon.implicitHeight + Tk.padding.medium * 2
      radius: height / 2
      color: root.connected ? Colours.m3primary : Colours.m3secondaryContainer
      MIcon {
        id: headIcon
        anchors.centerIn: parent
        text: Sys.bluetoothIcon(root.dev ? root.dev.icon : "")
        size: Tk.iconSize.large
        fill: root.connected ? 1 : 0
        color: root.connected ? Colours.m3onPrimary : Colours.m3onSecondaryContainer
      }
    }
    RowLabel {
      Layout.fillWidth: true
      textSize: Tk.title.medium
      text: BtService.label(root.dev)
      subtext: root.action !== "" ? root.action.charAt(0).toUpperCase() + root.action.slice(1) + "…" : root.connected ? "Connected" : "Saved"
    }
  }

  RowLayout {
    Layout.fillWidth: true
    Layout.bottomMargin: Tk.spacing.large - root.spacing
    spacing: Tk.spacing.small
    BigButton {
      icon: "delete"
      text: "Forget"
      bg: Colours.m3errorContainer
      fg: Colours.m3onErrorContainer
      disabled: root.action !== ""
      onClicked: BtService.forget(root.dev)
    }
    BigButton {
      icon: root.connected ? "link_off" : "link"
      text: root.connected ? "Disconnect" : "Connect"
      bg: Colours.m3primaryContainer
      fg: Colours.m3onPrimaryContainer
      disabled: root.action !== ""
      onClicked: BtService.toggle(root.dev)
    }
  }

  RowToggle {
    Layout.fillWidth: true
    first: true
    text: "Trusted"
    subtext: "Allow this device to connect automatically"
    checked: !!(root.dev && root.dev.trusted)
    onToggled: c => { if (root.dev) root.dev.trusted = c }
  }
  RowToggle {
    Layout.fillWidth: true
    text: "Blocked"
    subtext: "Prevent this device from connecting"
    checked: !!(root.dev && root.dev.blocked)
    onToggled: c => { if (root.dev) root.dev.blocked = c }
  }
  RowToggle {
    Layout.fillWidth: true
    last: true
    text: "Wake allowed"
    subtext: "Allow this device to wake the system"
    checked: !!(root.dev && root.dev.wakeAllowed)
    onToggled: c => { if (root.dev) root.dev.wakeAllowed = c }
  }

  SectionHeader { Layout.fillWidth: true; row: ({ text: "Information" }) }
  InfoRow {
    first: true
    visible: !!(root.dev && root.dev.batteryAvailable)
    icon: "battery_full"
    label: "Battery"
    value: root.dev && root.dev.batteryAvailable ? Math.round(root.dev.battery * 100) + "%" : ""
  }
  InfoRow {
    first: !(root.dev && root.dev.batteryAvailable)
    last: true
    icon: "memory"
    label: "Address"
    value: root.dev ? root.dev.address : "—"
  }
}
