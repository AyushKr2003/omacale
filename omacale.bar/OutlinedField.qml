import QtQuick
import QtQuick.Shapes

// Caelestia components/controls/StyledTextField.qml (outlined type): an M3
// outlined field whose placeholder floats up into a notch cut in the outline
// once the field has focus or text.
Item {
  id: root
  property alias text: input.text
  property alias field: input
  property string placeholderText
  property int horizontalPadding: Tk.padding.large
  property int verticalPadding: Tk.padding.large
  property int radius: Tk.rounding.small
  readonly property real clampedRadius: Math.min(horizontalPadding, Math.min(width, height) / 2, radius)
  readonly property bool raised: input.activeFocus || input.text !== ""
  readonly property real smallFontScale: Tk.label.small / input.font.pointSize
  signal editingFinished()
  signal accepted()

  implicitWidth: 250
  implicitHeight: input.contentHeight + verticalPadding * 2

  Shape {
    id: bg
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
    asynchronous: true
    ShapePath {
      id: path
      readonly property real outlineGap: placeholder.width * root.smallFontScale + Tk.spacing.extraSmall * 2
      property real outlineGapScale: root.raised && root.placeholderText !== "" ? 1 : 0
      readonly property real inset: strokeWidth / 2
      readonly property real r: root.clampedRadius
      strokeWidth: input.activeFocus ? 2 : 1
      strokeColor: input.activeFocus ? Colours.m3primary : Colours.m3outline
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap
      startX: path.inset + root.horizontalPadding - path.r + path.outlineGap * (1 - path.outlineGapScale) / 2 + path.outlineGap * path.outlineGapScale
      startY: path.inset
      PathLine { x: bg.width - path.inset - path.r; y: path.inset }
      PathArc { x: bg.width - path.inset; y: path.inset + path.r; radiusX: path.r; radiusY: path.r }
      PathLine { x: bg.width - path.inset; y: bg.height - path.inset - path.r }
      PathArc { x: bg.width - path.inset - path.r; y: bg.height - path.inset; radiusX: path.r; radiusY: path.r }
      PathLine { x: path.inset + path.r; y: bg.height - path.inset }
      PathArc { x: path.inset; y: bg.height - path.inset - path.r; radiusX: path.r; radiusY: path.r }
      PathLine { x: path.inset; y: path.inset + path.r }
      PathArc { x: path.inset + path.r; y: path.inset; radiusX: path.r; radiusY: path.r }
      PathLine { x: path.inset + root.horizontalPadding - path.r + path.outlineGap * (1 - path.outlineGapScale) / 2; y: path.inset }
      Behavior on outlineGapScale { Anim { type: "effects" } }
      Behavior on strokeWidth { Anim {} }
      Behavior on strokeColor { CAnim {} }
    }
  }

  StateLayer {
    radius: root.clampedRadius
    cursorShape: Qt.IBeamCursor
    disabled: input.activeFocus
    onClicked: input.forceActiveFocus()
  }

  MTextField {
    id: input
    anchors.fill: parent
    anchors.leftMargin: root.horizontalPadding
    anchors.rightMargin: root.horizontalPadding
    clip: true
    onEditingFinished: root.editingFinished()
    onAccepted: root.accepted()
  }

  MText {
    id: placeholder
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: root.horizontalPadding
    renderType: Text.QtRendering
    text: root.placeholderText
    font.pointSize: input.font.pointSize
    color: input.activeFocus ? Colours.m3primary : input.text ? Colours.m3outline : Colours.m3onSurfaceVariant
    states: State {
      name: "small"
      when: root.raised
      PropertyChanges {
        placeholder.scale: root.smallFontScale
        placeholder.anchors.leftMargin: -(1 - root.smallFontScale) * placeholder.width / 2 + root.horizontalPadding - Tk.spacing.extraSmall
      }
      AnchorChanges { target: placeholder; anchors.verticalCenter: root.top }
    }
    transitions: Transition {
      Anim { properties: "scale,leftMargin"; type: "effects" }
      AnchorAnimation { duration: Tk.durations.defaultEffects; easing.type: Easing.BezierSpline; easing.bezierCurve: Tk.curves.defaultEffects }
    }
  }
}
