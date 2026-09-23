import QtQuick
import QtQuick.Layouts
import "../.."

// Label + M3 switch row (Caelestia popout Toggle).
RowLayout {
  id: root
  property string label
  property bool checked
  signal toggled(bool checked)
  Layout.fillWidth: true
  Layout.rightMargin: Tk.padding.small
  spacing: Tk.spacing.medium
  MText { Layout.fillWidth: true; text: root.label }
  MSwitch { checked: root.checked; onToggled: c => root.toggled(c) }
}
