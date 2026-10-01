import QtQuick
import QtQuick.Shapes
import ".."

// Stand-in for Caelestia's LoadingIndicator: a spinning arc, shown while a
// connect / disconnect is in flight.
Item {
  id: root
  property real implicitSize: Math.round(Tk.iconSize.medium * 1.3)
  property color colour: Colours.m3primary
  readonly property real stroke: Math.max(2, Math.round(implicitSize / 8))
  implicitWidth: implicitSize
  implicitHeight: implicitSize

  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      fillColor: "transparent"
      strokeColor: root.colour
      strokeWidth: root.stroke
      capStyle: ShapePath.RoundCap
      PathAngleArc {
        centerX: root.width / 2; centerY: root.height / 2
        radiusX: (Math.min(root.width, root.height) - root.stroke) / 2; radiusY: radiusX
        startAngle: 0
        sweepAngle: 270
      }
    }
    RotationAnimation on rotation {
      running: root.visible
      loops: Animation.Infinite
      from: 0
      to: 360
      duration: Tk.durations.extraLarge
    }
  }
}
