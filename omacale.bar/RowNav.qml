import QtQuick
import QtQuick.Layouts

// Caelestia NavRow: icon, label, status line, chevron; opens a sub-page.
ConnectedRect {
  id: root
  property var row
  property var settings
  readonly property string status: {
    if (row.subtext) return row.subtext
    if (row.status === "bar") return Config.o.bar.persistent ? "Always visible" : Config.o.bar.showOnHover ? "Reveal on hover" : "Hidden until toggled"
    if (row.status) return Config.get(row.status) ? "Enabled" : "Disabled"
    return ""
  }

  implicitHeight: rl.implicitHeight + Tk.padding.medium * 2

  StateLayer {
    radius: Math.min(root.topLeftRadius, root.bottomLeftRadius)
    onClicked: root.settings.push(root.row.page)
  }
  RowLayout {
    id: rl
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: Tk.padding.largeIncreased
    anchors.rightMargin: Tk.padding.largeIncreased
    spacing: Tk.spacing.medium
    MIcon { text: root.row.icon; size: Tk.iconSize.medium; fill: 1; color: Colours.m3onSurfaceVariant }
    RowLabel { Layout.fillWidth: true; text: root.row.label; subtext: root.status }
    MIcon { text: "chevron_right"; size: Tk.iconSize.medium; color: Colours.m3onSurfaceVariant }
  }
}
