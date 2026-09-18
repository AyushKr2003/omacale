import QtQuick
import QtQuick.Layouts

ConnectedRect {
  id: root
  property var row
  property var settings
  readonly property string value: String(Config.get(row.key))

  implicitHeight: Math.max(lbl.implicitHeight, field.height) + Tk.padding.medium * 2

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: Tk.padding.largeIncreased
    anchors.rightMargin: Tk.padding.largeIncreased
    spacing: Tk.spacing.medium
    RowLabel { id: lbl; Layout.fillWidth: true; text: root.row.label; subtext: root.row.where ? root.row.where + (root.row.subtext ? " · " + root.row.subtext : "") : (root.row.subtext || "") }
    Rectangle {
      id: field
      width: 220; height: 40
      radius: height / 2
      color: Colours.m3surfaceContainerHighest
      border.width: input.activeFocus ? 2 : 0
      border.color: Colours.m3primary
      TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: Tk.padding.large
        anchors.rightMargin: Tk.padding.large
        verticalAlignment: TextInput.AlignVCenter
        text: root.value
        color: Colours.m3onSurface
        selectionColor: Colours.m3secondary
        selectedTextColor: Colours.m3onSecondary
        font.family: Tk.sans; font.pointSize: Tk.body.small
        clip: true
        selectByMouse: true
        onEditingFinished: Config.set(root.row.key, text.trim() || (root.row.key === "launcher.actionPrefix" ? ">" : ""))
        MText { anchors.verticalCenter: parent.verticalCenter; visible: !input.text; text: root.row.placeholder || ""; color: Colours.m3outline }
      }
    }
  }
}
