import QtQuick
import QtQuick.Shapes
import "ShapeGeom.js" as Geom

// Material 3 expressive shapes (circle, cookies, sunny, gem, ...) as polar
// curves, so any shape can morph into any other by interpolating radii —
// a lightweight stand-in for Caelestia's M3Shapes MaterialShape.
Item {
  id: root

  property string shape: "circle"
  property color color: Colours.m3primary
  property real implicitSize: 32
  property int morphDuration: Tk.durations.defaultSpatial
  property var morphCurve: Tk.curves.defaultSpatial

  readonly property int samples: 96
  property var fromR: []
  property var toR: []
  property real t: 1

  implicitWidth: implicitSize
  implicitHeight: implicitSize

  Behavior on color { CAnim {} }

  function current() {
    if (!fromR.length) return toR
    return toR.map((r, i) => fromR[i] + (r - fromR[i]) * t)
  }

  onShapeChanged: {
    const next = Geom.radii(shape, samples)
    if (!toR.length) { toR = next; t = 1; return }
    fromR = current(); toR = next
    morph.restart()
  }
  Component.onCompleted: toR = Geom.radii(shape, samples)

  NumberAnimation on t {
    id: morph
    running: false
    from: 0; to: 1
    duration: root.morphDuration
    easing.type: Easing.BezierSpline
    easing.bezierCurve: root.morphCurve
  }

  readonly property var points: {
    const rs = current(), w = width / 2, h = height / 2, pts = []
    for (let i = 0; i < rs.length; i++) {
      const th = i / rs.length * 2 * Math.PI
      pts.push(Qt.point(w + rs[i] * w * Math.cos(th), h + rs[i] * h * Math.sin(th)))
    }
    if (pts.length) pts.push(pts[0])
    return pts
  }

  function contains(p) {
    const dx = p.x - width / 2, dy = p.y - height / 2
    const th = (Math.atan2(dy, dx) + 2 * Math.PI) % (2 * Math.PI)
    const rs = current()
    const r = rs[Math.round(th / (2 * Math.PI) * rs.length) % rs.length] || 1
    return Math.hypot(dx / (width / 2), dy / (height / 2)) <= r
  }

  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      strokeWidth: -1
      fillColor: root.color
      PathPolyline { path: root.points }
    }
  }
}
