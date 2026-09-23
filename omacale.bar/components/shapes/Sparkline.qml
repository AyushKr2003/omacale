import QtQuick
import QtQuick.Shapes
import "../.."

// Two filled line graphs (Caelestia SparklineItem), newest sample on the
// right. The vertical scale eases toward the running maximum.
Item {
  id: root
  property var line1: []
  property var line2: []
  property color line1Color: Colours.m3secondary
  property color line2Color: Colours.m3tertiary
  property real line1FillAlpha: 0.15
  property real line2FillAlpha: 0.2
  property int historyLength: 30
  property real lineWidth: 2
  property real maxValue: Math.max(1024, Math.max.apply(null, line1.concat(line2, [0])))
  property real shownMax: maxValue
  Behavior on shownMax { Anim {} }

  function pts(list) {
    const n = list.length, out = []
    if (n < 2) return out
    const step = width / (historyLength - 1)
    const x0 = width - (n - 1) * step
    for (let i = 0; i < n; i++) out.push(Qt.point(x0 + i * step, height - Math.min(1, list[i] / shownMax) * (height - lineWidth) - lineWidth / 2))
    return out
  }
  function area(list) {
    const p = pts(list)
    if (!p.length) return p
    return p.concat([Qt.point(p[p.length - 1].x, height), Qt.point(p[0].x, height), p[0]])
  }

  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
    ShapePath { strokeWidth: -1; fillColor: Qt.alpha(root.line1Color, root.line1FillAlpha); PathPolyline { path: root.area(root.line1) } }
    ShapePath { fillColor: "transparent"; strokeColor: root.line1Color; strokeWidth: root.lineWidth; capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin; PathPolyline { path: root.pts(root.line1) } }
    ShapePath { strokeWidth: -1; fillColor: Qt.alpha(root.line2Color, root.line2FillAlpha); PathPolyline { path: root.area(root.line2) } }
    ShapePath { fillColor: "transparent"; strokeColor: root.line2Color; strokeWidth: root.lineWidth; capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin; PathPolyline { path: root.pts(root.line2) } }
  }
}
