import QtQuick
import QtQuick.Layouts
import "../../.."

// Caelestia nexus/common/RowButton.qml: icon, label, optional subtext and a
// trailing icon, as one clickable row of a connected group.
ConnectedRect {
  id: root
  property string icon
  property string text
  property string subtext
  property string trailingIcon
  property bool disabled: false
  property color iconColour: Colours.m3onSurfaceVariant
  property color textColour: Colours.m3onSurface
  signal clicked()

  Layout.fillWidth: true
  implicitHeight: row.implicitHeight + Tk.padding.medium * 2

  StateLayer {
    disabled: root.disabled
    color: root.textColour
    onClicked: root.clicked()
  }
  RowLayout {
    id: row
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.margins: Tk.padding.largeIncreased
    spacing: Tk.spacing.medium
    opacity: root.disabled ? 0.5 : 1
    Behavior on opacity { Anim {} }

    MIcon { visible: root.icon !== ""; text: root.icon; size: Tk.iconSize.medium; fill: 1; color: root.iconColour }
    RowLabel { Layout.fillWidth: true; text: root.text; subtext: root.subtext }
    MIcon { visible: root.trailingIcon !== ""; text: root.trailingIcon; size: Tk.iconSize.medium; color: Colours.m3onSurfaceVariant }
  }
}
