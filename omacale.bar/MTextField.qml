import QtQuick

// Caelestia components/controls/TextFieldBase.qml: primary-tinted selection
// that keeps the text colour, and a thin primary cursor that glides between
// positions and only blinks once typing pauses.
TextInput {
  id: root
  property int weight: Font.Normal

  color: Colours.m3onSurface
  selectionColor: Qt.alpha(Colours.m3primary, 0.4)
  selectedTextColor: color
  selectByMouse: true
  font.family: Tk.sans
  font.pointSize: Tk.body.small
  font.weight: weight
  property int opsz: Tk.body.small
  onFontChanged: () => { const s = Math.max(1, Math.floor(root.font.pointSize)); if (s !== root.opsz) root.opsz = s }
  font.variableAxes: ({ "ROND": 25, "wght": weight, "opsz": opsz })
  renderType: echoMode === TextInput.Password ? Text.QtRendering : Text.NativeRendering
  verticalAlignment: TextInput.AlignVCenter
  cursorDelegate: Item {}
  Behavior on color { CAnim {} }

  Rectangle {
    id: cursor
    property bool disableBlink
    x: root.cursorRectangle.x
    y: root.cursorRectangle.y
    implicitWidth: 1.5
    implicitHeight: root.cursorRectangle.height
    color: Colours.m3primary
    radius: Tk.rounding.large
    opacity: 0

    Connections {
      target: root
      function onCursorPositionChanged() {
        if (root.activeFocus && root.cursorVisible) {
          cursor.opacity = 1
          cursor.disableBlink = true
          enableBlink.restart()
        }
      }
    }
    Timer { id: enableBlink; interval: 500; onTriggered: cursor.disableBlink = false }
    Timer {
      running: root.activeFocus && root.cursorVisible && !cursor.disableBlink
      repeat: true
      triggeredOnStart: true
      interval: 500
      onTriggered: cursor.opacity = cursor.opacity === 1 ? 0 : 1
    }
    Binding { when: !root.activeFocus || !root.cursorVisible; cursor.opacity: 0 }
    Behavior on x {
      NumberAnimation {
        // Damped variant of the fast spatial curve
        duration: Tk.durations.fastEffects
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.2, 1, 0.21, 1, 1, 1]
      }
    }
    Behavior on opacity { Anim { type: "standardSmall" } }
  }
}
