import QtQuick
import QtQuick.Layouts
import "../.."

// Caelestia PR #2149 modules/bar/popouts/ConnectionRow.qml: a row of the
// network and bluetooth lists. Rows of a list are joined (small corners
// between them, large at the ends); the connected one is secondaryContainer
// with a primary icon, and a spinner rings the icon while connecting.
Rectangle {
  id: root
  property string icon
  property string title
  property string subtitle
  property bool active
  property bool loading
  property bool warning
  property bool first
  property bool last
  default property alias trailing: trailingRow.data

  implicitHeight: layout.implicitHeight + Tk.padding.small * 2
  color: active ? Colours.m3secondaryContainer : Colours.m3surfaceContainer
  topLeftRadius: first ? Tk.rounding.large : Tk.rounding.extraSmall
  topRightRadius: first ? Tk.rounding.large : Tk.rounding.extraSmall
  bottomLeftRadius: last ? Tk.rounding.large : Tk.rounding.extraSmall
  bottomRightRadius: last ? Tk.rounding.large : Tk.rounding.extraSmall
  Behavior on color { CAnim {} }

  RowLayout {
    id: layout
    anchors.fill: parent
    anchors.margins: Tk.padding.small
    anchors.leftMargin: Tk.padding.medium
    spacing: Tk.spacing.medium

    Rectangle {
      implicitHeight: iconLabel.implicitHeight + Tk.padding.small * 2
      implicitWidth: implicitHeight
      radius: height / 2
      color: root.active ? Colours.m3primary : Colours.m3surfaceContainerHighest
      Behavior on color { CAnim {} }

      MIcon {
        id: iconLabel
        anchors.centerIn: parent
        animate: true
        text: root.icon
        size: Tk.iconSize.medium
        color: root.active ? Colours.m3onPrimary : Colours.m3onSurfaceVariant
        fill: root.active ? 1 : 0
        Behavior on fill { Anim { type: "effects" } }
      }
      Loader {
        anchors.fill: parent
        active: root.loading
        sourceComponent: LoadingIndicator {
          implicitSize: parent.height
          colour: root.active ? Colours.m3onPrimary : Colours.m3primary
        }
      }
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: 0

      MText {
        Layout.fillWidth: true
        text: root.title
        color: root.active ? Colours.m3onSecondaryContainer : Colours.m3onSurface
        font.pointSize: Tk.body.medium
        elide: Text.ElideRight
      }
      MText {
        Layout.fillWidth: true
        visible: text !== ""
        animate: true
        text: root.subtitle
        color: root.warning ? Colours.m3error : root.active ? Qt.alpha(Colours.m3onSecondaryContainer, 0.8) : Colours.m3onSurfaceVariant
        font.pointSize: Tk.body.small
        elide: Text.ElideRight
      }
    }

    RowLayout {
      id: trailingRow
      spacing: Tk.spacing.extraSmall
    }
  }
}
