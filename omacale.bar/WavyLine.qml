import QtQuick
import QtQuick.Shapes

// Material 3 expressive wavy progress line (Caelestia WavyLine). The wave
// scrolls while `running`; its phase is continuous across value changes.
Item {
  id: root
  property real lineWidth: 6
  property real frequency: 5          // waves across fullLength
  property real fullLength: width
  property real amplitude: lineWidth * 0.5
  property color color: Colours.m3primary
  property bool running: true
  property int period: 2000
  property real phase: 0

  implicitHeight: lineWidth + amplitude * 2

  NumberAnimation on phase {
    running: root.running && root.visible && root.width > 0
    from: 0; to: 1
    duration: root.period
    loops: Animation.Infinite
  }

  readonly property var points: {
    const pts = [], w = Math.max(0, width - lineWidth), mid = height / 2
    const k = 2 * Math.PI * frequency / Math.max(1, fullLength)
    for (let x = 0; x <= w + 0.01; x += 2)
      pts.push(Qt.point(lineWidth / 2 + x, mid + amplitude * Math.sin(k * x - phase * 2 * Math.PI)))
    if (!pts.length) pts.push(Qt.point(lineWidth / 2, mid))
    return pts
  }

  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      fillColor: "transparent"
      strokeColor: root.color
      strokeWidth: root.lineWidth
      capStyle: ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin
      PathPolyline { path: root.points }
    }
  }
}
