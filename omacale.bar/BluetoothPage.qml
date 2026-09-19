import QtQuick
import QtQuick.Layouts
import Quickshell

// Settings › Connected devices. Port of Caelestia's nexus BluetoothPage.qml,
// backed by BtService (the engine behind Omarchy's own bluetooth panel).
ColumnLayout {
  id: root
  property var row
  property var settings
  property bool first
  property bool last

  readonly property var adapter: BtService.adapter
  spacing: Tk.spacing.extraSmall / 2

  RowToggle {
    Layout.fillWidth: true
    first: true
    text: "Bluetooth"
    labelSize: Tk.body.medium
    subtext: root.adapter ? "" : "No Bluetooth adapter found"
    disabled: !root.adapter
    checked: BtService.enabled
    onToggled: c => BtService.setEnabled(c)
  }

  ItemList {
    showList: BtService.enabled
    placeholderIcon: BtService.enabled ? "devices_other" : "bluetooth_disabled"
    placeholderText: BtService.enabled ? "No saved devices" : "Bluetooth disabled"
    model: ScriptModel { values: BtService.saved }
    delegate: BtDeviceRow {
      onOpenSettings: { BtService.selectedAddress = modelData.address; root.settings.push("btDevice") }
    }
  }

  RowButton {
    last: true
    icon: "add"
    text: "Pair new device"
    disabled: !BtService.enabled
    onClicked: root.settings.push("btPair")
  }

  RowToggle {
    Layout.fillWidth: true
    Layout.topMargin: Tk.spacing.large - root.spacing
    first: true
    text: "Discoverable"
    subtext: "Allow nearby devices to find this one"
    disabled: !BtService.enabled
    checked: !!(root.adapter && root.adapter.discoverable)
    onToggled: c => { if (root.adapter) root.adapter.discoverable = c }
  }
  RowToggle {
    Layout.fillWidth: true
    last: true
    text: "Pairable"
    subtext: "Allow nearby devices to pair with this one"
    disabled: !BtService.enabled
    checked: !!(root.adapter && root.adapter.pairable)
    onToggled: c => { if (root.adapter) root.adapter.pairable = c }
  }
}
