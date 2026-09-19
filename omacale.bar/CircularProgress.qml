import QtQuick
import QtQuick.Shapes

// Caelestia components/controls/CircularProgress.qml: a progress arc (wavy
// when `wavy`, as Caelestia's WavyLine arc path draws it), a gap, the
// remaining track, and a dot marking the end.
Item {
  id: root
  property real value: 0
  property real startAngle: -90
  property real sweepAngle: 360
  property int strokeWidth: Tk.padding.small
  property int padding: 0
  property int spacing: Tk.spacing.small
  property color fgColour: Colours.m3primary
  property color bgColour: Colours.m3secondaryContainer
  property bool hasEndIndicator: true
  property bool wavy: false
  property real waveFrequency: 8
  property bool wavePaused: false
  property int waveDuration: 2000
  property real implicitSize: 60
  // Not readonly: animated
  property real clampedVal: Math.max(1 / 360, Math.min(1, isNaN(value) ? 0 : value))
  property real waveAmplitude: wavy ? 0.5 : 0
  property real waveProgress: 0

  readonly property real size: Math.min(width, height)
  readonly property real arcRadius: (size - padding - strokeWidth * (1 + waveAmplitude * 2)) / 2
  readonly property real gapAngle: ((spacing + strokeWidth) / Math.max(1, arcRadius)) * (180 / Math.PI)
  readonly property real dotAngleRad: (startAngle + sweepAngle - gapAngle * (sweepAngle < 360 ? 0 : 1)) * Math.PI / 180
  // For consumers sizing around the ring
  readonly property real thickness: strokeWidth * (1 + waveAmplitude) * 2

  implicitWidth: implicitSize
  implicitHeight: implicitSize

  Behavior on clampedVal { Anim {} }
  Behavior on waveAmplitude { Anim { type: "effects" } }
  NumberAnimation on waveProgress {
    running: root.visible && root.waveAmplitude > 0
    paused: running && root.wavePaused
    from: 0
    to: 1
    duration: root.waveDuration
    loops: Animation.Infinite
  }

  // Filled part of the arc, as WavyLine::paintArc samples it.
  readonly property var wavePoints: {
    const amp = strokeWidth * waveAmplitude
    const r0 = arcRadius, cx = size / 2, cy = size / 2
    const start = startAngle * Math.PI / 180
    const draw = sweepAngle * Math.PI / 180 * clampedVal
    const n = Math.max(64, Math.ceil(r0 * draw / 2))
    const len = r0 * sweepAngle * Math.PI / 180
    const phase = waveProgress * 2 * Math.PI
    const pts = []
    for (let i = 0; i <= n; i++) {
      const t = start + i * draw / n
      const r = r0 + amp * Math.sin(waveFrequency * 2 * Math.PI * (i * draw / n * r0) / Math.max(1, len) + phase)
      pts.push(Qt.point(cx + r * Math.cos(t), cy + r * Math.sin(t)))
    }
    return pts
  }

  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      fillColor: "transparent"
      strokeColor: root.bgColour
      strokeWidth: Math.min(1, remainingArc.sweepAngle) * root.strokeWidth
      capStyle: ShapePath.RoundCap
      PathAngleArc {
        id: remainingArc
        radiusX: root.arcRadius; radiusY: root.arcRadius
        centerX: root.size / 2; centerY: root.size / 2
        startAngle: root.startAngle + root.clampedVal * root.sweepAngle + root.gapAngle
        sweepAngle: Math.max(1 / 360, root.sweepAngle * (1 - root.clampedVal) - root.gapAngle * (root.sweepAngle < 360 ? 1 : 2))
      }
      Behavior on strokeColor { CAnim {} }
    }
    ShapePath {
      fillColor: "transparent"
      strokeColor: root.fgColour
      strokeWidth: root.strokeWidth
      capStyle: ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin
      PathPolyline { path: root.wavePoints }
      Behavior on strokeColor { CAnim {} }
    }
  }

  Rectangle {
    visible: root.hasEndIndicator
    readonly property real s: Math.min(1, remainingArc.sweepAngle) * Math.min(4, root.strokeWidth)
    width: s; height: s; radius: s / 2
    x: root.size / 2 + root.arcRadius * Math.cos(root.dotAngleRad) - width / 2
    y: root.size / 2 + root.arcRadius * Math.sin(root.dotAngleRad) - height / 2
    opacity: Math.min(1, remainingArc.sweepAngle)
    color: root.fgColour
  }
}
