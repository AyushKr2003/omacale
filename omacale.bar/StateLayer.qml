import QtQuick
import QtQuick.Effects

// Caelestia StateLayer: 8% hover veil plus a radial ripple on press, both
// clipped to the parent's rounded shape. Like Caelestia's, each corner is
// picked up from the parent, so a ConnectedRect row (large outer corners,
// tight inner ones) gets a highlight of exactly its own shape.
MouseArea {
  id: root
  property bool disabled
  property color color: Colours.m3onSurface
  property real radius: parent && parent.radius !== undefined ? parent.radius : 0
  property real topLeftRadius: parent && parent.topLeftRadius !== undefined ? parent.topLeftRadius : radius
  property real topRightRadius: parent && parent.topRightRadius !== undefined ? parent.topRightRadius : radius
  property real bottomLeftRadius: parent && parent.bottomLeftRadius !== undefined ? parent.bottomLeftRadius : radius
  property real bottomRightRadius: parent && parent.bottomRightRadius !== undefined ? parent.bottomRightRadius : radius
  function clampR(r) { return Math.max(0, Math.min(r, width / 2, height / 2)) }
  property real pressX: width / 2
  property real pressY: height / 2
  property real ripple: 0

  anchors.fill: parent
  enabled: !disabled
  hoverEnabled: true
  cursorShape: disabled ? Qt.ArrowCursor : Qt.PointingHandCursor

  onPressed: function(e) {
    pressX = e.x; pressY = e.y
    fade.stop(); circle.opacity = 0.1; ripple = 0; grow.restart()
  }
  onReleased: fade.start()
  onCanceled: fade.start()

  Anim { id: grow; target: root; property: "ripple"; to: Math.hypot(root.width, root.height) * 1.1; type: "standard"; duration: Tk.durations.slowEffects * 2 }
  Anim { id: fade; target: circle; property: "opacity"; to: 0; type: "slowEffects" }

  Rectangle {
    anchors.fill: parent
    topLeftRadius: root.clampR(root.topLeftRadius)
    topRightRadius: root.clampR(root.topRightRadius)
    bottomLeftRadius: root.clampR(root.bottomLeftRadius)
    bottomRightRadius: root.clampR(root.bottomRightRadius)
    color: root.color
    opacity: root.containsMouse && !root.disabled ? 0.08 : 0
    Behavior on opacity { Anim { type: "effects" } }
  }

  Item {
    anchors.fill: parent
    visible: circle.opacity > 0
    layer.enabled: visible
    layer.effect: MultiEffect {
      maskEnabled: true
      maskSource: mask
      maskThresholdMin: 0.5
      maskSpreadAtMin: 1
    }
    Rectangle {
      id: circle
      opacity: 0
      width: root.ripple * 2; height: width; radius: width / 2
      x: root.pressX - root.ripple; y: root.pressY - root.ripple
      color: root.color
    }
  }
  Rectangle {
    id: mask
    anchors.fill: parent
    topLeftRadius: root.clampR(root.topLeftRadius)
    topRightRadius: root.clampR(root.topRightRadius)
    bottomLeftRadius: root.clampR(root.bottomLeftRadius)
    bottomRightRadius: root.clampR(root.bottomRightRadius)
    visible: false
    layer.enabled: true
  }
}
