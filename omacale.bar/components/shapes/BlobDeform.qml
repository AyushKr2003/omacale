import QtQuick
import "../.."

// Caelestia's jelly: BlobRect's deformation physics
// (plugin/src/Caelestia/Blobs/blobrect.cpp updatePhysics / checkAtRest).
// Follows a rect's centre; while it moves, the rect is stretched along its
// velocity and squeezed across it (area kept), through an underdamped spring
// on each of the symmetric 2x2 matrix's three components, so it wobbles
// once as it settles.
//
// `vec` feeds the blob shader (dN); `matrixAt()` is the same deformation
// for the drawer's content, as Caelestia's `panel.transform`.
Item {
  id: root

  // The rect's centre, in any fixed frame (the window).
  property real cx
  property real cy
  // ContentWindow.qml PanelBg: deformAmount * appearance.deformScale / 10000.
  property real amount: 0.15
  readonly property real deformScale: amount * Math.max(0, Config.o.appearance.deformScale) / 10000
  // blobrect.hpp defaults.
  property real stiffness: 200
  property real damping: 16

  property real m00: 1
  property real m01: 0
  property real m11: 1
  readonly property vector4d vec: Qt.vector4d(m00, m01, m11, 0)

  // The deformation about (ox, oy), in the coordinates of an item that is
  // drawn in the rect: T(o) * M * T(-o), row-major as Qt.matrix4x4 takes it.
  function matrixAt(ox, oy) {
    return Qt.matrix4x4(m00, m01, 0, ox - (m00 * ox + m01 * oy),
                        m01, m11, 0, oy - (m01 * ox + m11 * oy),
                        0, 0, 1, 0,
                        0, 0, 0, 1)
  }

  visible: false
  width: 0
  height: 0

  property real _v00: 0
  property real _v01: 0
  property real _v11: 0
  property bool _active: false
  property bool _hasPrev: false
  property real _px: 0
  property real _py: 0
  property int _still: 0

  onCxChanged: kick()
  onCyChanged: kick()
  onDeformScaleChanged: if (deformScale <= 0) reset()

  function kick() {
    if (deformScale <= 0 || ticker.running) return
    // The first frame after rest only takes a position (blobrect.cpp: a
    // skipped frame resets the previous position).
    _hasPrev = false
    _still = 0
    ticker.start()
  }

  function reset() {
    m00 = 1; m01 = 0; m11 = 1
    _v00 = 0; _v01 = 0; _v11 = 0
    _active = false
    ticker.stop()
  }

  function step(dt) {
    if (!_hasPrev || dt > 0.1 || dt < 0.001) {
      _px = cx; _py = cy; _hasPrev = true
      if (_active) checkAtRest(0)
      return
    }
    const velX = (cx - _px) / dt
    const velY = (cy - _py) / dt
    _px = cx; _py = cy
    const speed = Math.hypot(velX, velY)

    if (!_active) {
      if (speed < 5) {
        // Nothing moving and nothing to settle: stop ticking until the
        // centre moves again.
        if (++_still > 2) ticker.stop()
        return
      }
      _active = true
    }
    _still = 0

    // Target: R(a) * diag(stretch, 1 / stretch) * R(a)^T along the velocity.
    let t00 = 1, t01 = 0, t11 = 1
    if (speed > 5) {
      const stretch = 1 + Math.min(speed * deformScale, 0.35)
      const compress = 1 / stretch
      const c = velX / speed, s = velY / speed
      t00 = stretch * c * c + compress * s * s
      t01 = (stretch - compress) * c * s
      t11 = stretch * s * s + compress * c * c
    }

    // Implicit damping: stable for any dt (see blobrect.cpp).
    const inv = 1 / (1 + damping * dt)
    _v00 = (_v00 - stiffness * (m00 - t00) * dt) * inv
    _v01 = (_v01 - stiffness * (m01 - t01) * dt) * inv
    _v11 = (_v11 - stiffness * (m11 - t11) * dt) * inv
    m00 += _v00 * dt
    m01 += _v01 * dt
    m11 += _v11 * dt

    checkAtRest(speed)
  }

  function checkAtRest(speed) {
    const eps = 0.002
    const atRest = Math.abs(m00 - 1) < eps && Math.abs(m01) < eps && Math.abs(m11 - 1) < eps
      && Math.abs(_v00) < eps && Math.abs(_v01) < eps && Math.abs(_v11) < eps && speed < 5
    // blobrect.cpp updatePolish: snap once the deformation is imperceptible.
    const faint = Math.abs(m00 - 1) + Math.abs(m01) + Math.abs(m11 - 1) < 0.004
      && Math.abs(_v00) + Math.abs(_v01) + Math.abs(_v11) < 0.05 && speed < 5
    if (atRest || faint) {
      m00 = 1; m01 = 0; m11 = 1
      _v00 = 0; _v01 = 0; _v11 = 0
      _active = false
    }
  }

  FrameAnimation {
    id: ticker
    onTriggered: root.step(frameTime)
  }
}
