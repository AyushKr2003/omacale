import QtQuick
import QtQuick.Layouts
import Quickshell

// Settings › Connected devices › Pair new device. Port of Caelestia's nexus
// bluetooth/BluetoothPairing.qml: scans while visible and lists nearby
// devices; tapping one pairs, trusts and connects it (omarchy-bluetooth-device).
ColumnLayout {
  id: root
  property var row
  property var settings
  property bool first
  property bool last

  readonly property bool live: !settings || settings.active === undefined || settings.active
  spacing: Tk.spacing.extraSmall / 2

  property bool held: false
  function syncHold() { const want = visible && live; if (want !== held) { held = want; BtService.holdDiscovery(want) } }
  onVisibleChanged: syncHold()
  onLiveChanged: syncHold()
  Component.onCompleted: syncHold()
  Component.onDestruction: if (held) BtService.holdDiscovery(false)

  SectionHeader {
    Layout.fillWidth: true
    first: true
    row: ({ text: BtService.adapter && BtService.adapter.discovering ? "Available devices · searching…" : "Available devices" })
  }

  ItemList {
    first: true
    last: true
    showList: BtService.enabled
    scanning: BtService.enabled && !!BtService.adapter && BtService.adapter.discovering
    placeholderIcon: BtService.enabled ? "bluetooth_searching" : "bluetooth_disabled"
    placeholderText: BtService.enabled ? "Looking for devices…" : "Bluetooth disabled"
    model: ScriptModel { values: BtService.discovered }
    delegate: BtDeviceRow { showSettings: false }
  }

  MText {
    Layout.fillWidth: true
    Layout.topMargin: Tk.spacing.medium
    leftPadding: Tk.padding.small
    text: "Make sure the device is in pairing mode. It moves to your saved devices once it's paired."
    color: Colours.m3outline
    font.pointSize: Tk.label.medium
    wrapMode: Text.WordWrap
  }
}
