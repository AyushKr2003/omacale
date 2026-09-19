import QtQuick
import QtQuick.Layouts

// Caelestia components/controls/IconTextButton.qml (on ButtonBase): a pill
// with an icon and a label. type: "filled" | "tonal" | "text".
Rectangle {
  id: root
  property string icon
  property string text
  property string type: "filled"
  property bool disabled: false
  property bool isRound: true
  property bool shapeMorph: false
  property real shapeMorphExpansion: shapeMorph && state.pressed ? 24 : 0
  Behavior on shapeMorphExpansion { Anim { type: "fastSpatial" } }
  property real fontSize: Tk.body.medium
  property int horizontalPadding: Tk.padding.medium
  property int verticalPadding: Tk.padding.small
  property bool fillWidth: false
  signal clicked()

  readonly property color onColour: disabled ? Qt.alpha(Colours.m3onSurface, 0.38)
    : type === "filled" ? Colours.m3onPrimary : type === "tonal" ? Colours.m3onSecondaryContainer : Colours.m3primary

  implicitWidth: row.implicitWidth + horizontalPadding * 2
  implicitHeight: row.implicitHeight + verticalPadding * 2
  radius: state.pressed ? Tk.rounding.small : isRound ? height / 2 : Tk.rounding.large
  color: type === "text" ? "transparent" : disabled ? Qt.alpha(Colours.m3onSurface, 0.1)
    : type === "filled" ? Colours.m3primary : Colours.m3secondaryContainer
  Behavior on radius { Anim { type: "fastSpatial" } }
  Behavior on color { CAnim {} }

  StateLayer {
    id: state
    color: root.onColour
    shapeMorph: root.shapeMorph
    disabled: root.disabled
    onClicked: root.clicked()
  }
  RowLayout {
    id: row
    anchors.centerIn: parent
    spacing: Tk.spacing.small
    MIcon {
      Layout.alignment: Qt.AlignVCenter
      text: root.icon
      size: Math.round(root.fontSize * 1.2)
      color: root.onColour
    }
    MText {
      Layout.alignment: Qt.AlignVCenter
      Layout.topMargin: 1
      text: root.text
      color: root.onColour
      font.pointSize: root.fontSize
    }
  }
}
