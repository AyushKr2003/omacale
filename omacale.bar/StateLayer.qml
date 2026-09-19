import QtQuick
import QtQuick.Shapes

// Caelestia components/StateLayer.qml: an 8% hover veil plus a ripple drawn
// as a radial gradient inside the parent's rounded shape. The ripple grows to
// 1.3x the distance from the press to the farthest corner, keeps a soft edge
// until it has nearly filled the shape, and only fades once it has finished
// growing (so a quick click still shows the whole ripple). Each corner radius
// is picked up from the parent, so a ConnectedRect row gets a highlight of
// exactly its own shape.
MouseArea {
  id: root
  property bool disabled
  property bool showHoverBackground: true
  property bool manualPressOverride
  property bool manualHoverOverride
  property bool shapeMorph
  property color color: Colours.m3onSurface
  property real radius: parent && parent.radius !== undefined ? parent.radius : 0
  property real topLeftRadius: parent && parent.topLeftRadius !== undefined ? parent.topLeftRadius : radius
  property real topRightRadius: parent && parent.topRightRadius !== undefined ? parent.topRightRadius : radius
  property real bottomLeftRadius: parent && parent.bottomLeftRadius !== undefined ? parent.bottomLeftRadius : radius
  property real bottomRightRadius: parent && parent.bottomRightRadius !== undefined ? parent.bottomRightRadius : radius
  property real stateOpacity: containsMouse || manualHoverOverride ? 0.08 : 0
  property real pressX: width / 2
  property real pressY: height / 2
  property real circleRadius
  property real endRadiusAtPress
  readonly property real endRadius: {
    const d = (x, y) => (pressX - x) ** 2 + (pressY - y) ** 2
    return (Math.sqrt(Math.max(d(0, 0), d(width, 0), d(0, height), d(width, height))) + (shapeMorph ? 24 : 0)) * 1.3
  }

  function clamp(r) { return Math.max(0, Math.min(r, width / 2, height / 2)) }
  function press(x, y) {
    pressX = x
    pressY = y
    fadeAnim.complete()
    circleRadius = 0
    circle.opacity = 0.1
    rippleAnim.restart()
    endRadiusAtPress = endRadius
  }
  function maybeFade() {
    if (!(pressed || manualPressOverride) && circleRadius > endRadiusAtPress * 0.99 && !fadeAnim.running) fadeAnim.start()
  }

  anchors.fill: parent
  enabled: !disabled
  hoverEnabled: true
  cursorShape: disabled ? Qt.ArrowCursor : Qt.PointingHandCursor

  onPressed: e => press(e.x, e.y)
  onPressedChanged: if (!(pressed || manualPressOverride) && !rippleAnim.running && circle.opacity > 0) fadeAnim.start()
  onManualPressOverrideChanged: maybeFade()
  onCircleRadiusChanged: maybeFade()

  Anim {
    id: rippleAnim
    alwaysRunToEnd: true
    target: root
    property: "circleRadius"
    to: root.endRadius
    type: "standard"
    duration: Tk.durations.slowEffects * 2
  }
  Anim { id: fadeAnim; target: circle; property: "opacity"; to: 0; type: "slowEffects" }

  Rectangle {
    anchors.fill: parent
    visible: root.showHoverBackground
    opacity: root.stateOpacity
    color: root.color
    topLeftRadius: root.clamp(root.topLeftRadius)
    topRightRadius: root.clamp(root.topRightRadius)
    bottomLeftRadius: root.clamp(root.bottomLeftRadius)
    bottomRightRadius: root.clamp(root.bottomRightRadius)
  }

  Shape {
    id: circle
    readonly property real tl: root.clamp(root.topLeftRadius)
    readonly property real tr: root.clamp(root.topRightRadius)
    readonly property real bl: root.clamp(root.bottomLeftRadius)
    readonly property real br: root.clamp(root.bottomRightRadius)
    anchors.fill: parent
    opacity: 0
    visible: opacity > 0
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      strokeWidth: 0
      strokeColor: "transparent"
      fillGradient: RadialGradient {
        centerX: root.pressX
        centerY: root.pressY
        centerRadius: Math.max(0.01, root.circleRadius)
        focalX: centerX
        focalY: centerY
        GradientStop { position: 0; color: Qt.alpha(root.color, 1) }
        GradientStop {
          position: Math.max(0.01, Math.min(0.99, 1 - 0.2 * root.endRadius / Math.max(0.01, root.circleRadius)))
          color: Qt.alpha(root.color, 1)
        }
        GradientStop {
          position: 1
          color: Qt.alpha(root.color, Math.max(0, Math.min(1, (root.circleRadius / root.endRadius - 0.9) / 0.1)))
        }
      }
      startX: circle.tl
      startY: 0
      PathLine { x: root.width - circle.tr; y: 0 }
      PathArc { relativeX: circle.tr; relativeY: circle.tr; radiusX: circle.tr; radiusY: circle.tr }
      PathLine { x: root.width; y: root.height - circle.br }
      PathArc { relativeX: -circle.br; relativeY: circle.br; radiusX: circle.br; radiusY: circle.br }
      PathLine { x: circle.bl; y: root.height }
      PathArc { relativeX: -circle.bl; relativeY: -circle.bl; radiusX: circle.bl; radiusY: circle.bl }
      PathLine { x: 0; y: circle.tl }
      PathArc { x: circle.tl; y: 0; radiusX: circle.tl; radiusY: circle.tl }
    }
  }

  Behavior on stateOpacity { Anim { type: "effects" } }
}
