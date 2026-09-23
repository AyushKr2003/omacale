import QtQuick
import ".."

// Caelestia StyledText: Google Sans Flex, rounded axis, cross-fade on change.
Text {
  id: root
  property bool animate: false
  // Variable fonts: weight must go through the wght axis too, otherwise
  // setting any axis resets it to the font's default instance.
  property int weight: Font.Normal
  property var axes: ({ "ROND": 25 })

  renderType: Text.NativeRendering
  textFormat: Text.PlainText
  color: Colours.m3onSurface
  font.family: Tk.sans
  font.pointSize: Tk.body.small
  font.weight: weight
  // Caelestia's font builder also pins the optical size to the point size
  // (Config/font.cpp), which changes Google Sans Flex's glyph shapes.
  // Tracked outside the font binding: reading font.pointSize in it loops.
  property int opsz: Tk.body.small
  onFontChanged: () => { const s = Math.max(1, Math.floor(root.font.pointSize)); if (s !== root.opsz) root.opsz = s }
  font.variableAxes: Object.assign({ "wght": weight, "opsz": opsz }, axes)

  Behavior on color { CAnim {} }
  Behavior on text {
    enabled: root.animate
    SequentialAnimation {
      Anim { target: root; property: "opacity"; to: 0; type: "fastEffects" }
      PropertyAction {}
      Anim { target: root; property: "opacity"; to: 1; type: "effects" }
    }
  }
}
