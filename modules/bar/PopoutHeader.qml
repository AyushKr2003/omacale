import QtQuick
import QtQuick.Layouts
import "../.."

// Caelestia PR #2149 modules/bar/popouts/PopoutHeader.qml: the card heading
// the network and bluetooth popouts -- a round icon, a title and a status
// line, and the on/off switch.
Rectangle {
  id: root
  property string icon
  property string title
  property string subtitle
  property bool active
  property bool hasToggle
  property alias checked: toggle.checked
  signal toggled(bool checked)

  Layout.fillWidth: true
  implicitHeight: layout.implicitHeight + Tk.padding.large * 2
  radius: Tk.rounding.extraLarge
  color: Colours.m3surfaceContainer

  RowLayout {
    id: layout
    anchors.fill: parent
    anchors.margins: Tk.padding.large
    spacing: Tk.spacing.medium

    Rectangle {
      implicitHeight: iconLabel.implicitHeight + Tk.padding.small * 2
      implicitWidth: implicitHeight
      radius: height / 2
      color: root.active ? Colours.m3primary : Colours.m3secondaryContainer
      Behavior on color { CAnim {} }

      MIcon {
        id: iconLabel
        anchors.centerIn: parent
        animate: true
        text: root.icon
        size: Tk.iconSize.medium
        color: root.active ? Colours.m3onPrimary : Colours.m3onSecondaryContainer
        fill: root.active ? 1 : 0
        Behavior on fill { Anim { type: "effects" } }
      }
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: 0

      MText {
        Layout.fillWidth: true
        text: root.title
        font.pointSize: Tk.title.small
        weight: Font.Medium
        elide: Text.ElideRight
      }
      MText {
        Layout.fillWidth: true
        visible: text !== ""
        animate: true
        text: root.subtitle
        color: Colours.m3onSurfaceVariant
        font.pointSize: Tk.body.small
        elide: Text.ElideRight
      }
    }

    MSwitch {
      id: toggle
      visible: root.hasToggle
      onToggled: c => root.toggled(c)
    }
  }
}
