import QtQuick
import ".."

// Morph motion's panel switch (core/Morph.qml), Omacale's own -- no
// Caelestia original; Serpantinum's master window (Main.qml executeSwitch:
// one panel that reshapes from the old page to the new one while the old
// content is dropped at once). While `running`, the panel left is gone at
// once (`off` 1), the one opened is open at once (`off` 0), and its rect
// travels from where the old one was (`rect`), its content following the
// rect's centre (`shiftX`/`shiftY`) and showing over the second half
// (`gate`).
Item {
  id: root

  property var fromRect: null
  property var fromNames: []
  property var toNames: []
  property bool running: false
  property real t: 1

  function start(rect, from, to) {
    fromRect = rect
    fromNames = from
    toNames = to
    t = 0
    running = true
    anim.restart()
  }
  function stop() {
    anim.stop()
    t = 1
    running = false
  }

  NumberAnimation {
    id: anim
    target: root
    property: "t"
    from: 0
    to: 1
    duration: Morph.slideIn
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Morph.curveIn
    onFinished: root.running = false
  }

  function isTo(n) { return running && toNames.indexOf(n) >= 0 }
  function off(n, v) { return !running ? v : toNames.indexOf(n) >= 0 ? 0 : fromNames.indexOf(n) >= 0 ? 1 : v }
  function rect(n, r) {
    if (!r || !isTo(n)) return r
    return [0, 1, 2, 3].map(i => fromRect[i] + (r[i] - fromRect[i]) * t)
  }
  function gate(n) { return isTo(n) ? Math.max(0, Math.min(1, (t - 0.5) / 0.5)) : 1 }
  function shiftX(n, r) { return isTo(n) && r ? (fromRect[0] + fromRect[2] / 2 - r[0] - r[2] / 2) * (1 - t) : 0 }
  function shiftY(n, r) { return isTo(n) && r ? (fromRect[1] + fromRect[3] / 2 - r[1] - r[3] / 2) * (1 - t) : 0 }

  visible: false
  width: 0
  height: 0
}
