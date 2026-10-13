import QtQuick
import "../../core/LiquidMath.js" as M
import "../.."

// Liquid motion's neck break (core/Liquid.qml, Settings › Motion ›
// Detach), Omacale's own: Vitreus's drop down the left strip (vitreus.plm
// `dj.*`, pages/bar_shapes.plm). A drawer that leaves the frame for the
// middle of the screen stays joined to it by a thread (`thread`, extra
// blend for its BlobDeform) that stretches and snaps; when it snaps the edge
// bounces, two ripples run along it and a small drop is left hanging for a
// moment (`bumps`, for BlobSurface.bumps). Going back, the edge gives as
// it is reached and ripples again as it closes over the drawer.
Item {
  id: root

  property bool active: false
  // How far it has left: 0 on the frame, 1 free.
  property real t: 0
  // The frame edge it leaves (left, right, top, bottom) and the point on
  // it it leaves from.
  property string edge: "left"
  property real ex: 0
  property real ey: 0
  property real unit: Tk.uiScale

  readonly property bool on: active && Liquid.neckBreak
  // Vitreus `dsl = max(0, dtrav * 1.3 - 0.3)`: it pulls a little before it goes.
  readonly property real out: M.clamp01(t * 1.3 - 0.3)
  readonly property real thread: on ? M.thread(52 * unit, out) : 0
  readonly property real sag: Math.max((26 * M.bell(out) + bounce.value) * unit, 0.3)
  readonly property var rip: M.ripples(prip, Liquid.stray ? pstray : 0, unit)
  readonly property real ripH: Liquid.ripples ? rip[1] : 0
  readonly property bool showing: on && (out > 0.02 || prip < 0.98 || pstray > 0.01 || Math.abs(bounce.value) > 0.2)

  // [edge bulge, ripple, ripple, stray drop], each [cx, cy, rx, ry, blend].
  readonly property var bumps: !showing ? [] : [
    ellipse(0, 0, sag, 30 * unit, 16 * unit * M.clamp01(sag / (6 * unit))),
    ellipse(-rip[0], 0, Math.max(ripH, 0.3), 9 * unit, 8 * unit * M.clamp01(ripH / (3 * unit))),
    ellipse(rip[0], 0, Math.max(ripH, 0.3), 9 * unit, 8 * unit * M.clamp01(ripH / (3 * unit))),
    ellipse(0, rip[2] * 0.7, Math.max(rip[2], 0.3), Math.max(rip[2], 0.3), 7 * unit * M.clamp01(rip[2] / (3 * unit)))
  ]

  // An ellipse `along` the edge from the point and `inward` off it, `across`
  // its radius off the edge and `alongR` along it.
  function ellipse(along, inward, across, alongR, blend) {
    const vert = edge === "left" || edge === "right"
    const sign = edge === "left" || edge === "top" ? 1 : -1
    return vert ? [ex + sign * inward, ey + along, across, alongR, blend]
      : [ex + along, ey + sign * inward, alongR, across, blend]
  }

  visible: false
  width: 0
  height: 0

  Spring {
    id: bounce
    live: root.on
    stiffness: Liquid.splash[0]
    damping: Liquid.splash[1]
  }
  property real prip: 1
  property real pstray: 0
  NumberAnimation { id: ripAnim; target: root; property: "prip"; from: 0; to: 1 }
  SequentialAnimation {
    id: strayAnim
    PropertyAction { target: root; property: "pstray"; value: 1 }
    PauseAnimation { duration: 60 }
    NumberAnimation { target: root; property: "pstray"; to: 0; duration: 700 * Tk.animScale; easing.type: Easing.OutCubic }
  }
  function ripple(ms) {
    ripAnim.duration = ms * Tk.animScale
    ripAnim.restart()
  }

  // Vitreus's moments: it lets go (the edge jumps back and bounces, two
  // ripples, a stray drop), it is reached again on the way back, and the
  // edge closes over it.
  property real lastOut: 0
  onOutChanged: {
    const was = lastOut
    lastOut = out
    if (!on) return
    if (was <= 0.84 && out > 0.84) {
      bounce.impulse(-280)
      if (Liquid.ripples) ripple(1100)
      if (Liquid.stray) strayAnim.restart()
    } else if (was >= 0.84 && out < 0.84) {
      bounce.impulse(80)
    } else if (was >= 0.06 && out < 0.06) {
      bounce.impulse(-200)
      if (Liquid.ripples) ripple(600)
    }
  }
}
