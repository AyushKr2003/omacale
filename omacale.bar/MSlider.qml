import QtQuick

// Caelestia StyledSlider: filled track, a gap, a tall handle bar, a gap,
// then the remaining track ending in a dot.
Item {
  id: root
  property real value: 0
  property int radius: Tk.rounding.medium
  property bool interactive: true
  property color fgColour: Colours.m3primary
  property color bgColour: Colours.m3secondaryContainer
  property bool wavy: false
  property bool animateWave: true
  property real waveFrequency: 5
  readonly property bool dragging: mouse.pressed
  property real pos: dragging ? mouse.dragPos : Math.max(0, Math.min(1, value))
  signal moved(real value)

  implicitWidth: 200
  implicitHeight: 12

  property real filledWidth: (width - handle.width - Tk.spacing.extraSmall) * pos
  Behavior on filledWidth { enabled: !root.dragging; Anim {} }

  WavyLine {
    visible: root.wavy
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    width: Math.max(root.height * 0.7, root.filledWidth)
    height: implicitHeight
    lineWidth: root.height * 0.7
    fullLength: root.width
    frequency: root.waveFrequency
    running: root.animateWave
    color: root.fgColour
  }
  Rectangle {
    id: filled
    visible: !root.wavy
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    width: root.filledWidth
    height: root.height
    radius: root.radius
    topRightRadius: Tk.rounding.extraSmall / 2
    bottomRightRadius: Tk.rounding.extraSmall / 2
    color: root.fgColour
  }
  Rectangle {
    id: handle
    x: root.filledWidth + Tk.spacing.extraSmall
    anchors.verticalCenter: parent.verticalCenter
    width: 4
    height: {
      const t = Math.max(0, Math.min(1, (root.height - 12) / 16))
      const lerp = (a, b) => a + (b - a) * t
      return root.height * (mouse.pressed ? lerp(3.5, 1.5) : lerp(3, 1.2))
    }
    radius: 2
    color: root.fgColour
    Behavior on height { Anim { type: "fastSpatial" } }
  }
  Rectangle {
    id: remaining
    anchors.left: handle.right
    anchors.right: parent.right
    anchors.leftMargin: Tk.spacing.extraSmall
    anchors.verticalCenter: parent.verticalCenter
    opacity: Math.min(width, 12) / 12
    height: root.height * (root.height <= 12 ? opacity : Math.min(opacity * 2, 1))
    radius: root.radius
    topLeftRadius: Tk.rounding.extraSmall / 2
    bottomLeftRadius: Tk.rounding.extraSmall / 2
    color: root.bgColour
  }
  Rectangle {
    anchors.right: parent.right
    anchors.rightMargin: 4 * remaining.opacity
    anchors.verticalCenter: parent.verticalCenter
    width: 4 * remaining.opacity; height: width; radius: width / 2
    opacity: remaining.opacity
    color: root.fgColour
  }
  MouseArea {
    id: mouse
    property real dragPos: 0
    enabled: root.interactive
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    height: Math.max(root.height, handle.height)
    preventStealing: true
    cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
    function at(x) { return Math.max(0, Math.min(1, x / width)) }
    onPressed: function(e) { dragPos = at(e.x); root.moved(dragPos) }
    onPositionChanged: function(e) { if (pressed) { dragPos = at(e.x); root.moved(dragPos) } }
  }
}
