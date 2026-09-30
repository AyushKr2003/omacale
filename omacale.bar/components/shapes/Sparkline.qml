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
  // Caelestia NetworkCard: the graph slides one step left over each update
  // interval, linearly, so it scrolls continuously instead of jumping; the
  // newest sample comes in from past the right edge.
  property int slideDuration: Config.o.services.resourceUpdateInterval
  property real slideProgress: 1
  onLine2Changed: slideAnim.restart()
  NumberAnimation { id: slideAnim; target: root; property: "slideProgress"; from: 0; to: 1; duration: root.slideDuration; easing.type: Easing.Linear }
  clip: true

  function pts(list) {
    const n = list.length, out = []
    if (n < 2) return out
    const step = width / (historyLength - 1)
    const x0 = width - (n - 1) * step - step * slideProgress + step
    for (let i = 0; i < n; i++) out.push(Qt.point(x0 + i * step, height - Math.min(1, list[i] / shownMax) * height))
    return out
  }
  function area(list) {
    const p = pts(list)
    if (!p.length) return p
    return p.concat([Qt.point(p[p.length - 1].x, height), Qt.point(p[0].x, height), p[0]])
  }

  // sparklineitem.cpp: each line is stroked, then filled over; line1 first.
  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
    ShapePath { fillColor: "transparent"; strokeColor: root.line1Color; strokeWidth: root.lineWidth; capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin; PathPolyline { path: root.pts(root.line1) } }
    ShapePath { strokeWidth: -1; fillColor: Qt.alpha(root.line1Color, root.line1FillAlpha); PathPolyline { path: root.area(root.line1) } }
    ShapePath { fillColor: "transparent"; strokeColor: root.line2Color; strokeWidth: root.lineWidth; capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin; PathPolyline { path: root.pts(root.line2) } }
    ShapePath { strokeWidth: -1; fillColor: Qt.alpha(root.line2Color, root.line2FillAlpha); PathPolyline { path: root.area(root.line2) } }
  }
}
