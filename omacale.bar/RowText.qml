import QtQuick
import QtQuick.Layouts

ConnectedRect {
  id: root
  property var row
  property var settings
  readonly property string value: String(Config.get(row.key))

  implicitHeight: Math.max(lbl.implicitHeight, field.implicitHeight) + Tk.padding.medium + Math.max(0, Tk.padding.large - field.verticalPadding) * 2

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: Tk.padding.largeIncreased
    anchors.rightMargin: Tk.padding.largeIncreased
    spacing: Tk.spacing.medium
    RowLabel { id: lbl; Layout.fillWidth: true; text: root.row.label; subtext: root.row.where ? root.row.where + (root.row.subtext ? " · " + root.row.subtext : "") : (root.row.subtext || "") }
    // Caelestia TextFieldRow: an outlined field, 250 wide, capped at half the row.
    OutlinedField {
      id: field
      Layout.preferredWidth: 250
      Layout.maximumWidth: root.width / 2
      Layout.alignment: Qt.AlignVCenter
      verticalPadding: Tk.padding.small
      text: root.value
      placeholderText: root.row.placeholder || ""
      onEditingFinished: Config.set(root.row.key, text.trim() || (root.row.key === "launcher.actionPrefix" ? ">" : root.row.key === "launcher.menuPrefix" ? ":" : ""))
    }
  }
}
