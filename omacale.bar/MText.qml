import QtQuick

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
  font.variableAxes: Object.assign({ "wght": weight }, axes)

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
