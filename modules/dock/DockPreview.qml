import QtQuick
import Quickshell.Wayland
import Quickshell.Widgets
import "../.."

// One window in the dock's previews: its live surface, letterboxed in a
// rounded card, its title under it and a close button over its corner.
// The preview follows the overview's (OverviewWindow.qml), itself Caelestia's
// windowinfo/Preview.qml: a ScreencopyView inside a clipping rect.
Item {
  id: root

  property var win: ({})
  property bool live: true

  signal activated
  signal closeRequested

  readonly property real ratio: win.size && win.size[0] > 0 && win.size[1] > 0 ? win.size[0] / win.size[1] : 16 / 9

  implicitWidth: Tk.px(220)
  implicitHeight: shot.height + title.implicitHeight + Tk.spacing.extraSmall

  Rectangle {
    id: card
    anchors.fill: parent
    anchors.margins: -Tk.padding.extraSmall
    radius: Tk.rounding.medium
    color: mouse.containsMouse ? Colours.m3surfaceContainerHigh : "transparent"
    Behavior on color { CAnim {} }
  }

  ClippingRectangle {
    id: shot
    width: parent.width
    height: Math.round(width * 9 / 16)
    radius: Tk.rounding.small
    color: Colours.m3surfaceContainer

    ScreencopyView {
      anchors.centerIn: parent
      width: Math.min(parent.width, parent.height * root.ratio)
      height: Math.min(parent.height, parent.width / root.ratio)
      captureSource: root.win.toplevel ? root.win.toplevel.wayland : null
      live: root.live
    }
  }

  MText {
    id: title
    anchors.top: shot.bottom
    anchors.topMargin: Tk.spacing.extraSmall
    width: parent.width
    text: root.win.title || ""
    elide: Text.ElideRight
    font.pointSize: Tk.label.large
    color: Colours.m3onSurfaceVariant
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.activated()
  }

  IconButton {
    anchors.top: shot.top
    anchors.right: shot.right
    anchors.margins: Tk.padding.extraSmall
    visible: mouse.containsMouse || hovered
    readonly property bool hovered: stateLayer.containsMouse
    type: "tonal"
    icon: "close"
    iconSize: Tk.iconSize.small
    onClicked: root.closeRequested()
  }
}
