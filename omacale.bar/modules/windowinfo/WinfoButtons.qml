import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import "../.."

// Caelestia modules/windowinfo/Buttons.qml: move the window to a workspace
// (an expanding grid of the current group of ten), float/tile, pin/unpin
// (floating windows only), and kill. Hyprland's Lua dispatchers, as Caelestia
// sends when Hypr.usingLua, which is the only config Omarchy ships.
ColumnLayout {
  id: root

  required property var client
  readonly property var ipc: client ? client.lastIpcObject : null
  readonly property string target: client ? 'window = "address:0x' + client.address + '"' : ""
  property bool moveToWsExpanded
  signal killed()

  function dispatch(fn, extra) {
    if (!client) return
    Sys.hypr("hl.dsp.window." + fn + "({ " + target + (extra ? ", " + extra : "") + " })")
  }

  anchors.fill: parent
  spacing: Tk.spacing.small

  RowLayout {
    Layout.topMargin: Tk.padding.large
    Layout.leftMargin: Tk.padding.large
    Layout.rightMargin: Tk.padding.large
    spacing: Tk.spacing.medium

    MText {
      Layout.fillWidth: true
      text: "Move to workspace"
      elide: Text.ElideRight
    }

    Rectangle {
      color: Colours.m3primary
      radius: Tk.rounding.medium
      implicitWidth: moveToWsIcon.implicitWidth + Tk.padding.small
      implicitHeight: moveToWsIcon.implicitHeight + Tk.padding.extraSmall
      StateLayer {
        color: Colours.m3onPrimary
        onClicked: root.moveToWsExpanded = !root.moveToWsExpanded
      }
      MIcon {
        id: moveToWsIcon
        anchors.centerIn: parent
        animate: true
        text: root.moveToWsExpanded ? "expand_more" : "keyboard_arrow_right"
        color: Colours.m3onPrimary
        size: Tk.iconSize.large
      }
    }
  }

  GridLayout {
    id: wsGrid
    Layout.fillWidth: true
    Layout.leftMargin: Tk.padding.large
    Layout.rightMargin: Tk.padding.large
    Layout.bottomMargin: root.moveToWsExpanded ? Tk.spacing.medium : 0
    Layout.preferredHeight: root.moveToWsExpanded ? implicitHeight : 0
    opacity: root.moveToWsExpanded ? 1 : 0
    clip: true
    rowSpacing: Tk.spacing.small
    columnSpacing: Tk.spacing.small
    columns: 5

    Behavior on Layout.bottomMargin { Anim { type: "effects" } }
    Behavior on Layout.preferredHeight { Anim { type: "effects" } }
    Behavior on opacity { Anim { type: "effects" } }

    Repeater {
      model: 10
      Button {
        required property int index
        readonly property int activeWsId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
        readonly property int wsId: Math.floor((activeWsId - 1) / 10) * 10 + index + 1
        readonly property bool isCurrent: !!root.client && !!root.client.workspace && root.client.workspace.id === wsId
        color: isCurrent ? Colours.m3surfaceContainerHighest : Colours.m3tertiaryContainer
        onColor: isCurrent ? Colours.m3onSurface : Colours.m3onTertiaryContainer
        text: wsId
        disabled: isCurrent
        onClicked: root.dispatch("move", 'workspace = "' + wsId + '", follow = true')
      }
    }
  }

  RowLayout {
    Layout.fillWidth: true
    Layout.leftMargin: Tk.padding.large
    Layout.rightMargin: Tk.padding.large
    Layout.bottomMargin: Tk.padding.large
    spacing: root.ipc && root.ipc.floating ? Tk.spacing.medium : Tk.spacing.small

    Button {
      color: Colours.m3secondaryContainer
      onColor: Colours.m3onSecondaryContainer
      text: root.ipc && root.ipc.floating ? "Tile" : "Float"
      onClicked: root.dispatch("float", 'action = "toggle"')
    }

    Loader {
      asynchronous: true
      active: !!root.ipc && !!root.ipc.floating
      Layout.fillWidth: active
      Layout.leftMargin: active ? 0 : -parent.spacing
      Layout.rightMargin: active ? 0 : -parent.spacing
      sourceComponent: Button {
        color: Colours.m3secondaryContainer
        onColor: Colours.m3onSecondaryContainer
        text: root.ipc && root.ipc.pinned ? "Unpin" : "Pin"
        onClicked: root.dispatch("pin")
      }
    }

    Button {
      color: Colours.m3errorContainer
      onColor: Colours.m3onErrorContainer
      text: "Kill"
      // Unlike Caelestia, the panel closes: it follows the active window, so
      // it would otherwise turn straight to the next one, and a second click
      // on Kill would take that window too.
      onClicked: { root.dispatch("kill"); root.killed() }
    }
  }

  component Button: Rectangle {
    id: button
    property color onColor: Colours.m3onSurface
    property alias disabled: buttonLayer.disabled
    property alias text: buttonLabel.text
    signal clicked()

    radius: Tk.rounding.medium
    Layout.fillWidth: true
    implicitHeight: buttonLabel.implicitHeight + Tk.padding.small

    StateLayer {
      id: buttonLayer
      color: button.onColor
      onClicked: button.clicked()
    }
    MText {
      id: buttonLabel
      anchors.centerIn: parent
      animate: true
      color: button.onColor
      font.pointSize: Tk.body.medium
    }
  }
}
