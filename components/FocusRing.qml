import QtQuick
import ".."

// M3 focus indicator (m3.material.io, states › focus): a 3dp outline in the
// secondary colour, 2dp outside the focused control, following its shape.
// Drawn only for the KeyNav cursor; the pointer never sets `shown`.
//
// Must be a child or sibling of `target` (it anchors to it). Each corner
// follows the control's own, so a connected row or the half of a split
// button gets a ring of its exact shape. Where a clipping ancestor leaves no
// room outside the control (a row filling a clipped list or card), M3's
// inner indicator is drawn instead -- the same outline just inside the edge --
// rather than an outer one with its sides cut off.
Rectangle {
  id: ring

  property Item target
  property bool shown: false
  // The control's corner radii; the ring's follow them, outset.
  property real innerRadius: 0
  property real topLeftInner: innerRadius
  property real topRightInner: innerRadius
  property real bottomLeftInner: innerRadius
  property real bottomRightInner: innerRadius
  // Force the inner indicator; otherwise it is picked when shown.
  property bool inset: false
  readonly property real gap: 2
  readonly property real thickness: 3

  property bool autoInset: false
  readonly property bool inner: inset || autoInset
  // Settles from a few px away, the same distance on every side whatever the
  // control's size (a scale would fly a wide row far outside). An inner ring
  // comes from further in, so its clipping ancestor never cuts it on the way.
  property real grow: shown ? 0 : 4
  readonly property real off: inner ? -grow : gap + thickness + grow

  // Concentric with the control's corner, `off` further out.
  function outer(r) { return Math.min(height / 2, width / 2, r > 0 ? r + off : 0) }
  // Would any clipping ancestor cut the outer ring off? A layer crops to its
  // item as a clip does: the fading scroll views (FadeFlickable, FadeListView)
  // are masked layers, and their rows fill them edge to edge.
  function measure() {
    if (!target || !shown) return
    const o = gap + thickness
    for (let p = target.parent; p; p = p.parent) {
      if (!p.clip && !(p.layer && p.layer.enabled)) continue
      const r = target.mapToItem(p, -o, -o)
      if (r.x < 0 || r.y < 0 || r.x + target.width + 2 * o > p.width || r.y + target.height + 2 * o > p.height) {
        autoInset = true
        return
      }
    }
    autoInset = false
  }
  // Again once the cursor has scrolled the stop into view.
  onShownChanged: { measure(); if (shown) settle.restart() }
  Timer { id: settle; interval: Tk.durations.normal + 50; onTriggered: ring.measure() }
  Connections {
    target: ring.shown ? ring.target : null
    function onWidthChanged() { ring.measure() }
    function onHeightChanged() { ring.measure() }
  }

  anchors.centerIn: target
  width: (target ? target.width : 0) + off * 2
  height: (target ? target.height : 0) + off * 2
  topLeftRadius: outer(topLeftInner)
  topRightRadius: outer(topRightInner)
  bottomLeftRadius: outer(bottomLeftInner)
  bottomRightRadius: outer(bottomRightInner)
  color: "transparent"
  border.width: thickness
  border.color: Colours.m3secondary
  opacity: shown ? 1 : 0
  visible: opacity > 0
  Behavior on opacity { Anim { type: "effects" } }
  Behavior on grow { Anim { type: "fastSpatial" } }
}
