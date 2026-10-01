import QtQuick
import ".."

// Caelestia components/controls/LoadingIndicator.qml: M3's loading
// indicator, a shape that morphs into the next every 650ms while it turns.
// Each morph springs (Caelestia: stiffness 180, damping 0.6, which settles
// in ~350ms): the shape swings a further 60 degrees and swells by up to 14%
// on the way. Omacale's LoadingIndicator is Caelestia's CircularIndicator.
Item {
  id: root
  property real implicitSize: Tk.px(38)
  property color colour: Colours.m3primary
  // Without the pentagon, which isn't centred, when an icon sits inside.
  property bool containsIcon: false
  property bool animated: visible
  readonly property var shapes: containsIcon
    ? ["softBurst", "cookie9", "pill", "sunny", "cookie4", "oval"]
    : ["softBurst", "cookie9", "pentagon", "pill", "sunny", "cookie4", "oval"]
  property int shapeIndex: 0
  property real cRotation: 0
  property real lRotation: 0
  property real thisLRotation: 0
  readonly property int springMs: 350

  implicitWidth: implicitSize
  implicitHeight: implicitSize

  MShape {
    id: shape
    anchors.centerIn: parent
    implicitSize: root.implicitSize
    shape: root.shapes[0]
    color: root.colour
    // The morph itself never overshoots (Caelestia clamps it).
    morphDuration: root.springMs
    morphCurve: Tk.curves.standardDecel
    rotation: root.cRotation + root.lRotation + root.thisLRotation
  }

  Timer {
    interval: 650
    repeat: true
    running: root.animated
    onTriggered: {
      root.lRotation = (root.lRotation + root.thisLRotation) % 360
      root.thisLRotation = 0
      root.shapeIndex = (root.shapeIndex + 1) % root.shapes.length
      shape.shape = root.shapes[root.shapeIndex]
      swing.restart()
      swell.restart()
    }
  }
  // The rotation follows the spring, overshoot and all.
  NumberAnimation {
    id: swing
    target: root; property: "thisLRotation"
    from: 0; to: 60
    duration: root.springMs
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Tk.curves.fastSpatial
  }
  // The swell tracks the spring's velocity: up fast, then back.
  SequentialAnimation {
    id: swell
    NumberAnimation { target: shape; property: "scale"; to: 1.14; duration: root.springMs * 0.3; easing.type: Easing.OutQuad }
    NumberAnimation { target: shape; property: "scale"; to: 1; duration: root.springMs * 0.7; easing.type: Easing.InOutQuad }
  }
  NumberAnimation on cRotation {
    running: root.animated
    from: 0; to: 360
    duration: 4666
    loops: Animation.Infinite
  }
}
