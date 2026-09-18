import QtQuick
import QtQuick.Layouts

ConnectedRect {
  id: root
  property var row
  property var settings
  readonly property bool value: !!Config.get(row.key)

  implicitHeight: Math.max(lbl.implicitHeight, sw.implicitHeight) + Tk.padding.medium * 2

  StateLayer {
    radius: Math.min(root.topLeftRadius, root.bottomLeftRadius)
    onClicked: Config.set(root.row.key, !root.value)
  }
  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: Tk.padding.largeIncreased
    anchors.rightMargin: Tk.padding.largeIncreased
    spacing: Tk.spacing.medium
    RowLabel { id: lbl; Layout.fillWidth: true; text: root.row.label; subtext: root.row.where ? root.row.where + (root.row.subtext ? " · " + root.row.subtext : "") : (root.row.subtext || "") }
    MSwitch { id: sw; checked: root.value; onToggled: c => Config.set(root.row.key, c) }
  }
}
