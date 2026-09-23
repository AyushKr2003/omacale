import QtQuick
import "../.."

// Caelestia IconButton. type: "filled" | "tonal" | "text".
Rectangle {
  id: root
  property string icon
  property string type: "filled"
  property bool checked: false
  property bool internalChecked: checked
  onCheckedChanged: internalChecked = checked
  property bool toggle: false
  // ButtonRow: pressing bulges the button by 24px and neighbours yield.
  property bool shapeMorph: false
  property real shapeMorphExpansion: shapeMorph && state.pressed ? 24 : 0
  Behavior on shapeMorphExpansion { Anim { type: "fastSpatial" } }
  property bool disabled: false
  property bool round: true
  property real iconSize: Tk.iconSize.medium
  property int iconWeight: Font.Normal
  property int padding: type === "text" ? Tk.padding.extraSmall / 2 : Tk.padding.small
  property color activeColour: type === "filled" ? Colours.m3primary : Colours.m3secondary
  property color inactiveColour: type === "filled" && !toggle ? Colours.m3primary
    : type === "filled" ? Colours.m3surfaceContainer
    : type === "tonal" ? Colours.m3secondaryContainer : "transparent"
  property color activeOnColour: type === "filled" ? Colours.m3onPrimary : type === "tonal" ? Colours.m3onSecondary : Colours.m3primary
  property color inactiveOnColour: type === "filled" && !toggle ? Colours.m3onPrimary
    : type === "tonal" ? Colours.m3onSecondaryContainer : Colours.m3onSurfaceVariant
  readonly property bool on: toggle ? internalChecked : false
  readonly property alias stateLayer: state
  readonly property color onColour: disabled ? Qt.alpha(Colours.m3onSurface, 0.38) : (on ? activeOnColour : inactiveOnColour)
  property bool fillWidth: false
  signal clicked()

  implicitHeight: { const h = label.implicitHeight + padding * 2; return h % 2 ? h + 1 : h }
  implicitWidth: implicitHeight
  radius: state.pressed ? Tk.rounding.small : on ? Tk.rounding.medium : round ? height / 2 : Tk.rounding.large
  color: disabled ? Qt.alpha(Colours.m3onSurface, type === "text" ? 0 : 0.1) : (on ? activeColour : inactiveColour)
  Behavior on radius { Anim { type: "effects" } }
  Behavior on color { CAnim {} }

  StateLayer {
    id: state
    color: root.onColour
    shapeMorph: root.shapeMorph
    disabled: root.disabled
    onClicked: { if (root.toggle) root.internalChecked = !root.internalChecked; root.clicked() }
  }
  MIcon {
    id: label
    anchors.centerIn: parent
    anchors.verticalCenterOffset: 1
    text: root.icon
    size: root.iconSize
    weight: root.iconWeight
    color: root.onColour
    fill: !root.toggle || root.on ? 1 : 0
    Behavior on fill { Anim { type: "effects" } }
  }
}
