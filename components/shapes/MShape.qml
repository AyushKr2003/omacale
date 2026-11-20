import QtQuick
import QtQuick.Shapes
import "ShapeGeom.js" as Geom
import "../.."

// Material 3 expressive shapes (circle, cookies, sunny, gem, ...) as polar
// curves, so any shape can morph into any other by interpolating radii —
// a lightweight stand-in for Caelestia's M3Shapes MaterialShape.
Item {
  id: root

  property string shape: "circle"
  property color color: Colours.m3primary
  property real implicitSize: Tk.px(32)
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

  // Distance from the centre to the outline at a screen angle (degrees,
  // 0 = right, clockwise), honouring the item's rotation.
  function distanceAtAngle(deg) {
    const rs = current()
    if (!rs.length) return width / 2
    let a = ((deg - rotation) % 360 + 360) % 360
    const i = Math.round(a / 360 * rs.length) % rs.length
    const th = a * Math.PI / 180
    return rs[i] * Math.hypot(width / 2 * Math.cos(th), height / 2 * Math.sin(th))
  }

  function contains(p) {
    const dx = p.x - width / 2, dy = p.y - height / 2
    const th = (Math.atan2(dy, dx) + 2 * Math.PI) % (2 * Math.PI)
    const rs = current()
    const r = rs[Math.round(th / (2 * Math.PI) * rs.length) % rs.length] || 1
    return Math.hypot(dx / (width / 2), dy / (height / 2)) <= r
  }

  // Caelestia's MaterialShape::pathBounds(): the tight bounds of the drawn
  // outline, not the square the radii are interpolated in. Shapes like the
  // clam shell are shorter than they are wide, and a layout that reserves the
  // full square grows taller than the card it sits in.
  function pathBounds() {
    const pts = points
    if (!pts.length || width <= 0 || height <= 0)
      return Qt.rect(0, 0, implicitWidth, implicitHeight)
    let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity
    for (const p of pts) {
      minX = Math.min(minX, p.x)
      minY = Math.min(minY, p.y)
      maxX = Math.max(maxX, p.x)
      maxY = Math.max(maxY, p.y)
    }
    return Qt.rect(minX, minY, maxX - minX, maxY - minY)
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
