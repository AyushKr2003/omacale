import QtQuick
import QtQuick.Shapes

// Caelestia CircularProgress (non-wavy variant): a progress arc, a gap, the
// remaining track, and a dot marking the end.
Item {
  id: root
  property real value: 0
  property real startAngle: -90
  property real sweepAngle: 360
  property int strokeWidth: Tk.padding.small
  property int spacing: Tk.spacing.small
  property color fgColour: Colours.m3primary
  property color bgColour: Colours.m3secondaryContainer
  property real implicitSize: 60
  property real clampedVal: Math.max(1 / 360, Math.min(1, isNaN(value) ? 0 : value))

  readonly property real size: Math.min(width, height)
  readonly property real arcRadius: (size - strokeWidth) / 2
  readonly property real gapAngle: ((spacing + strokeWidth) / Math.max(1, arcRadius)) * (180 / Math.PI)
  readonly property real thickness: strokeWidth

  implicitWidth: implicitSize
  implicitHeight: implicitSize

  Behavior on clampedVal { Anim {} }

  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      fillColor: "transparent"
      strokeColor: root.bgColour
      strokeWidth: root.strokeWidth
      capStyle: ShapePath.RoundCap
      PathAngleArc {
        radiusX: root.arcRadius; radiusY: root.arcRadius
        centerX: root.size / 2; centerY: root.size / 2
        startAngle: root.startAngle + root.clampedVal * root.sweepAngle + root.gapAngle
        sweepAngle: Math.max(1 / 360, root.sweepAngle * (1 - root.clampedVal) - root.gapAngle * (root.sweepAngle < 360 ? 1 : 2))
      }
    }
    ShapePath {
      fillColor: "transparent"
      strokeColor: root.fgColour
      strokeWidth: root.strokeWidth
      capStyle: ShapePath.RoundCap
      PathAngleArc {
        radiusX: root.arcRadius; radiusY: root.arcRadius
        centerX: root.size / 2; centerY: root.size / 2
        startAngle: root.startAngle
        sweepAngle: root.clampedVal * root.sweepAngle
      }
    }
  }
  Rectangle {
    readonly property real a: (root.startAngle + root.sweepAngle - root.gapAngle * (root.sweepAngle < 360 ? 0 : 1)) * Math.PI / 180
    width: Math.min(4, root.strokeWidth); height: width; radius: width / 2
    x: root.size / 2 + root.arcRadius * Math.cos(a) - width / 2
    y: root.size / 2 + root.arcRadius * Math.sin(a) - height / 2
    color: root.fgColour
  }
}
