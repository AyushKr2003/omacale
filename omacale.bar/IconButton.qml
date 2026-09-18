import QtQuick

// Caelestia IconButton. type: "filled" | "tonal" | "text".
Rectangle {
  id: root
  property string icon
  property string type: "filled"
  property bool checked: false
  property bool toggle: false
  property bool disabled: false
  property bool round: true
  property real iconSize: Tk.iconSize.medium
  property int padding: type === "text" ? Tk.padding.extraSmall / 2 : Tk.padding.small
  property color activeColour: type === "filled" ? Colours.m3primary : Colours.m3secondary
  property color inactiveColour: type === "filled" && !toggle ? Colours.m3primary
    : type === "filled" ? Colours.m3surfaceContainer
    : type === "tonal" ? Colours.m3secondaryContainer : "transparent"
  property color activeOnColour: type === "filled" ? Colours.m3onPrimary : type === "tonal" ? Colours.m3onSecondary : Colours.m3primary
  property color inactiveOnColour: type === "filled" && !toggle ? Colours.m3onPrimary
    : type === "tonal" ? Colours.m3onSecondaryContainer : Colours.m3onSurfaceVariant
  readonly property bool on: toggle ? checked : false
  readonly property color onColour: disabled ? Qt.alpha(Colours.m3onSurface, 0.38) : (on ? activeOnColour : inactiveOnColour)
  property bool fillWidth: false
  signal clicked()

  implicitHeight: { const h = label.implicitHeight + padding * 2; return h % 2 ? h + 1 : h }
  implicitWidth: implicitHeight
  radius: state.pressed ? Tk.rounding.small : (round || on ? height / 2 : Tk.rounding.medium)
  color: disabled ? Qt.alpha(Colours.m3onSurface, type === "text" ? 0 : 0.1) : (on ? activeColour : inactiveColour)
  Behavior on radius { Anim { type: "fastSpatial" } }
  Behavior on color { CAnim {} }

  StateLayer {
    id: state
    color: root.onColour
    disabled: root.disabled
    onClicked: root.clicked()
  }
  MIcon {
    id: label
    anchors.centerIn: parent
    anchors.verticalCenterOffset: 1
    text: root.icon
    size: root.iconSize
    color: root.onColour
    fill: !root.toggle || root.on ? 1 : 0
    Behavior on fill { Anim { type: "effects" } }
  }
}
