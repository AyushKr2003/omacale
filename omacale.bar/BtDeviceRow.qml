import QtQuick
import QtQuick.Layouts

// One device in a Bluetooth ItemList (Caelestia BluetoothPage /
// BluetoothPairing delegates): round icon, name, state, and a settings
// button or spinner. Click connects / disconnects (or pairs, when new).
Item {
  id: root
  required property var modelData
  property bool showSettings: true
  signal openSettings()

  readonly property var dev: modelData
  readonly property bool connected: !!(dev && dev.connected)
  readonly property string action: BtService.pendingOf(dev)
  readonly property bool loading: action !== "" || !!(dev && dev.pairing)

  width: ListView.view ? ListView.view.width : 0
  implicitHeight: row.implicitHeight + Tk.padding.medium * 2

  StateLayer {
    radius: Tk.rounding.extraSmall
    disabled: root.loading
    onClicked: BtService.toggle(root.dev)
  }

  RowLayout {
    id: row
    anchors.fill: parent
    anchors.margins: Tk.padding.medium
    anchors.leftMargin: Tk.padding.largeIncreased
    anchors.rightMargin: Tk.padding.largeIncreased
    spacing: Tk.spacing.medium

    Rectangle {
      implicitWidth: implicitHeight
      implicitHeight: icon.implicitHeight + Tk.padding.small * 2
      radius: height / 2
      color: root.connected ? Colours.m3primary : Colours.m3secondaryContainer
      Behavior on color { CAnim {} }
      MIcon {
        id: icon
        anchors.centerIn: parent
        text: Sys.bluetoothIcon(root.dev ? root.dev.icon : "")
        size: Tk.iconSize.medium
        fill: root.connected ? 1 : 0
        color: root.connected ? Colours.m3onPrimary : Colours.m3onSecondaryContainer
        opacity: root.loading ? 0.5 : 1
      }
    }
    ColumnLayout {
      Layout.fillWidth: true
      spacing: 0
      opacity: root.loading ? 0.5 : 1
      Behavior on opacity { Anim { type: "effects" } }
      MText { Layout.fillWidth: true; text: BtService.label(root.dev); elide: Text.ElideRight }
      MText {
        Layout.fillWidth: true
        text: root.action === "connecting" ? (BtService.remembered(root.dev) ? "Connecting…" : "Pairing…")
          : root.action === "disconnecting" ? "Disconnecting…"
          : root.action === "forgetting" ? "Forgetting…"
          : !root.connected ? (BtService.remembered(root.dev) ? "Saved" : "Tap to pair")
          : root.dev.batteryAvailable ? "Connected • " + Math.round(root.dev.battery * 100) + "%"
          : "Connected"
        color: Colours.m3outline
        font.pointSize: Tk.label.small
        elide: Text.ElideRight
        animate: true
      }
    }
    Item {
      Layout.fillHeight: true
      implicitWidth: Math.max(gear.implicitWidth, spin.implicitWidth)
      visible: root.showSettings || root.loading
      LoadingIndicator { id: spin; anchors.centerIn: parent; visible: root.loading }
      IconButton {
        id: gear
        anchors.centerIn: parent
        visible: !root.loading && root.showSettings
        type: "text"
        icon: "settings"
        padding: Tk.padding.small
        inactiveOnColour: root.connected ? Colours.m3primary : Colours.m3onSurfaceVariant
        onClicked: root.openSettings()
      }
    }
  }
}
