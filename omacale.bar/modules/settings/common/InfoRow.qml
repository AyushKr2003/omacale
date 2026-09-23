import QtQuick
import QtQuick.Layouts
import "../../.."

// Caelestia nexus/common/InfoRow.qml: a read-only label / value row.
ConnectedRect {
  id: root
  property string icon
  property string label
  property string subtext
  property string value

  Layout.fillWidth: true
  implicitHeight: row.implicitHeight + Tk.padding.medium * 2

  RowLayout {
    id: row
    anchors.fill: parent
    anchors.margins: Tk.padding.medium
    anchors.leftMargin: Tk.padding.largeIncreased
    anchors.rightMargin: Tk.padding.largeIncreased
    spacing: Tk.spacing.medium

    MIcon { visible: root.icon !== ""; text: root.icon; size: Tk.iconSize.small; color: Colours.m3onSurfaceVariant }
    RowLabel { Layout.fillWidth: true; text: root.label; subtext: root.subtext }
    MText {
      Layout.maximumWidth: root.width / 2
      horizontalAlignment: Text.AlignRight
      text: root.value
      color: Colours.m3onSurfaceVariant
      elide: Text.ElideRight
    }
  }
}
