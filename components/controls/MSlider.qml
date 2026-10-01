import QtQuick
import "../.."

// Caelestia StyledSlider: filled track, a gap, a tall handle bar, a gap,
// then the remaining track ending in a dot.
Item {
  id: root
  property real value: 0
  property int radius: Tk.rounding.medium
  property bool interactive: true
  // false: only report the value on release (Caelestia seek bar)
  property bool interactionOnMove: true
  property color fgColour: enabled ? Colours.m3primary : Qt.alpha(Colours.m3onSurface, 0.38)
  property color bgColour: enabled ? Colours.m3secondaryContainer : Qt.alpha(Colours.m3onSurface, 0.1)
  property bool wavy: false
  property bool animateWave: true
  property real waveFrequency: 5
  readonly property bool dragging: mouse.pressed
  property real pos: dragging ? Math.max(0, Math.min(1, mouse.pressStartPos + mouse.dragMovement)) : Math.max(0, Math.min(1, value))
  signal moved(real value)

  // KeyNav cursor: the handle takes its pressed shape, and Left/Right step
  // the value (Omarchy's 5% volume step).
  property bool focused: false
  property real keyStep: 0.05
  readonly property bool navTarget: interactive && enabled
  function navActivate() {}
  function navAdjust(direction) { moved(Math.max(0, Math.min(1, value + keyStep * direction))) }

  implicitWidth: Tk.px(200)
  implicitHeight: Tk.px(12)

  property real filledWidth: (width - handle.width - Tk.spacing.extraSmall) * pos
  Behavior on filledWidth { id: widthBehavior; Anim {} }

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
    width: Tk.px(4)
    height: {
      const t = Math.max(0, Math.min(1, (root.height - 12) / 16))
      const lerp = (a, b) => a + (b - a) * t
      return root.height * (mouse.pressed || root.focused ? lerp(3.5, 1.5) : lerp(3, 1.2))
    }
    radius: Tk.px(2)
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
  FocusRing {
    target: root
    innerRadius: root.radius
    shown: root.focused
  }

  // Caelestia StyledSlider: dragging moves the value relative to where it
  // was grabbed; a click without a drag jumps there on release.
  MouseArea {
    id: mouse
    property real pressStartX
    property real pressStartPos
    property real dragMovement
    enabled: root.interactive
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    height: Math.max(root.height, handle.height)
    preventStealing: true
    cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
    onPressed: e => {
      widthBehavior.enabled = false
      pressStartX = e.x
      pressStartPos = Math.max(0, Math.min(1, root.value))
      dragMovement = 0
    }
    onPositionChanged: e => {
      if (!pressed) return
      dragMovement = (e.x - pressStartX) / width
      if (root.interactionOnMove) root.moved(root.pos)
    }
    onReleased: e => {
      const finalPos = dragMovement !== 0 ? root.pos : Math.max(0, Math.min(1, e.x / width))
      widthBehavior.enabled = true
      dragMovement = 0
      root.moved(finalPos)
    }
  }
}
