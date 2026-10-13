import QtQuick
import "../../core/LiquidMath.js" as M
import "../.."

// One drawer's liquid motion (core/Liquid.qml), Omacale's own -- no
// Caelestia original; Vitreus's drawers (vitreus.plm `dk`/`dc`/`*.bell`,
// pages/bar_shapes.plm `box drawer`). `off` is the drawer's 0-open / 1-away
// on a spring that overshoots past open and stops at away; `rect()` is its
// shader rect (narrowed, bulged, sagged, wobbled, or dropping), `corner()`
// its rounding, `neck` the extra blend that goes in its BlobDeform. While
// not `active`, ScreenScope keeps Caelestia's curves and none of this is
// read.
Item {
  id: root

  // Its key in liquid.drawers.
  property string name
  property bool open: false
  // The frame edge it comes out of: top, bottom, left, right, or none
  // (floating).
  property string edge: "top"
  // Whether the drop style applies (edge drawers that slide on their own).
  property bool canDrop: false
  // Slower on the way out, as Caelestia's slowSpatial (Settings, the
  // floating overview).
  property real slow: 1
  // px per px: the style preview draws a miniature.
  property real unit: 1
  // How far a dropping drawer reaches into the frame to melt into it.
  property real bury: Tk.border
  // On whenever liquid motion is, whatever liquid.drawers says (the preview).
  property bool force: false

  readonly property bool active: force ? Liquid.enabled : Liquid.on(name)
  readonly property bool drop: active && canDrop && Liquid.drop
  readonly property real off: spring.value
  readonly property real p: 1 - off
  readonly property real neck: active ? M.neck(Liquid.neckWidth * unit, p) : 0
  readonly property real sag: active ? Math.max(0, sagSpring.value) : 0
  readonly property real wobble: active ? wobbleSpring.value : 0
  readonly property var contentScale: active ? M.contentScale(edge, p, Liquid.params, wobble, drop) : [1, 1]
  readonly property real contentOpacity: M.contentOpacity(p, drop)

  function rect(r) {
    return active && r ? M.shape(r, edge, p, Liquid.params, sag, wobble, drop, bury * unit) : r
  }
  // A radius for BlobSurface.corners (-1 is the surface's own).
  function corner(r, base) {
    return active && Liquid.rounding && r ? M.radius(r, base, p) : -1
  }

  visible: false
  width: 0
  height: 0

  Spring {
    id: spring
    live: root.active
    target: root.open ? 0 : 1
    absorb: 1
    stiffness: Liquid.stiffness / (root.slow * root.slow)
    damping: Liquid.damping / root.slow
  }
  // Vitreus `impulse sag 220; impulse wobble -260` when a drawer lands: it
  // hangs a few px low and eases back, and shakes once.
  Spring {
    id: sagSpring
    live: root.active
    stiffness: Liquid.hang[0]
    damping: Liquid.hang[1]
  }
  Spring {
    id: wobbleSpring
    live: root.active
    stiffness: Liquid.splash[0]
    damping: Liquid.splash[1]
  }
  property bool landed: true
  onOpenChanged: landed = !open
  onOffChanged: {
    if (landed || !open || !active || off > 0.03) return
    landed = true
    sagSpring.impulse(Liquid.sag * unit)
    wobbleSpring.impulse(-Liquid.wobble)
  }
}
