import QtQuick
import "../core/LiquidMath.js" as M
import ".."

// A value on a spring, for liquid motion (core/Liquid.qml): pleamar's
// `prop x = 0 ~spring(k, c)` with `impulse`. It follows `target`, keeps its
// velocity when the target changes mid-way (so it turns without a jolt), and
// only ticks while it moves, as BlobDeform does. Not `live`, it sits on its
// target.
Item {
  id: root

  property real target: 0
  property real value: 0
  property real velocity: 0
  property real stiffness: 170
  property real damping: 18
  property bool live: true
  // A target the spring stops at instead of swinging past (a drawer that is
  // shut must not bounce back into view); NaN for none.
  property real absorb: NaN
  property real epsilon: 0.0005
  readonly property bool moving: ticker.running

  visible: false
  width: 0
  height: 0

  Component.onCompleted: value = target
  onTargetChanged: kick()
  onLiveChanged: if (!live) snap()

  function snap() {
    ticker.stop()
    value = target
    velocity = 0
  }
  function kick() {
    if (!live) { snap(); return }
    if (!ticker.running) ticker.start()
  }
  // A shove: adds to the velocity (pleamar's `impulse`).
  function impulse(v) {
    if (!live || !isFinite(v) || v === 0) return
    velocity += v
    if (!ticker.running) ticker.start()
  }

  function step(dt) {
    // A dropped frame must not fling it: at most a 20 fps step.
    dt = Math.min(Math.max(dt, 0), 0.05)
    if (dt <= 0) return
    const r = M.step(value, velocity, target, stiffness, damping, dt)
    let x = r[0], v = r[1]
    if (isFinite(absorb) && target === absorb
        && ((value <= absorb && x >= absorb) || (value >= absorb && x <= absorb))) {
      x = absorb
      v = 0
    }
    if (Math.abs(x - target) < epsilon && Math.abs(v) < epsilon * 20) {
      x = target
      v = 0
      ticker.stop()
    }
    value = x
    velocity = v
  }

  FrameAnimation {
    id: ticker
    onTriggered: root.step(frameTime)
  }
}
