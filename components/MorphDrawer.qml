import QtQuick
import ".."

// One drawer's morph motion (core/Morph.qml), Omacale's own -- no Caelestia
// original; Serpantinum's page intro (volume/VolumePopup.qml introMain).
// `p` is 0 away / 1 in, on OutExpo in and InQuart out; the drawer's content
// takes `fade` on its opacity, `grow` as a centred Scale and `rise` as a
// Translate. While not `active` they are 1, 1 and 0.
Item {
  id: root

  property bool open: false
  readonly property bool active: Morph.enabled

  property real p: open ? 1 : 0
  Behavior on p {
    id: pB
    enabled: root.active
    NumberAnimation {
      duration: pB.targetValue > 0.5 ? Morph.introIn : Morph.introOut
      easing.type: pB.targetValue > 0.5 ? Easing.OutExpo : Easing.InQuart
    }
  }

  readonly property real fade: active ? p : 1
  readonly property real grow: active ? Morph.scaleFrom + (1 - Morph.scaleFrom) * p : 1
  readonly property real rise: active ? Morph.rise * (1 - p) : 0

  visible: false
  width: 0
  height: 0
}
