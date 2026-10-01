import QtQuick
import ".."

// Caelestia StyledProgressBar (determinate): filled track, a gap, the rest
// of the track, and a dot at the end.
Item {
  id: root
  property real value: 0
  property color fgColour: Colours.m3primary
  property color bgColour: Colours.m3secondaryContainer
  readonly property real v: Math.max(0, Math.min(1, isNaN(value) ? 0 : value))
  property real shown: v
  Behavior on shown { Anim {} }
  implicitWidth: Tk.px(200)
  implicitHeight: Tk.px(4)

  Rectangle {
    id: fill
    width: Math.max(height, (root.width - Tk.spacing.extraSmall) * root.shown)
    height: root.height
    radius: height / 2
    color: root.fgColour
  }
  Rectangle {
    anchors.left: fill.right
    anchors.leftMargin: Tk.spacing.extraSmall
    anchors.right: parent.right
    height: root.height
    radius: height / 2
    color: root.bgColour
    visible: width > height
  }
  Rectangle {
    anchors.right: parent.right
    anchors.rightMargin: root.height / 2 - width / 2 + 1
    anchors.verticalCenter: parent.verticalCenter
    width: Math.min(4, root.height); height: width; radius: width / 2
    color: root.fgColour
    visible: root.shown < 0.97
  }
}
