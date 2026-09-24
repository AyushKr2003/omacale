import QtQuick
import ".."

// M3 focus indicator (m3.material.io, states › focus): a 3dp outline in the
// secondary colour, 2dp outside the focused control, following its shape.
// Drawn only for the KeyNav cursor; the pointer never sets `shown`.
Rectangle {
  id: ring

  property Item target
  property bool shown: false
  // The control's own corner radius; the ring's follows it, outset.
  property real innerRadius: 0
  readonly property real gap: 2
  readonly property real thickness: 3

  anchors.centerIn: target
  width: (target ? target.width : 0) + (gap + thickness) * 2
  height: (target ? target.height : 0) + (gap + thickness) * 2
  radius: Math.min(height / 2, innerRadius > 0 ? innerRadius + gap + thickness : 0)
  color: "transparent"
  border.width: thickness
  border.color: Colours.m3secondary
  opacity: shown ? 1 : 0
  visible: opacity > 0
  scale: shown ? 1 : 1.06
  Behavior on opacity { Anim { type: "effects" } }
  Behavior on scale { Anim { type: "fastSpatial" } }
}
