import QtQuick
import QtQuick.Layouts
import "../../.."

// A colour setting as RRGGBB (no "#"): a swatch and a hex field, as the seed
// colour's (cards/SeedPicker.qml). Used as { type: "custom", comp: "colour",
// key, label, subtext }; a half-typed value is not saved.
ConnectedRect {
  id: root
  property var row
  property var settings
  property bool first
  property bool last
  readonly property string value: String(Config.get(row.key) || "")

  implicitHeight: rl.implicitHeight + Tk.padding.medium * 2

  RowLayout {
    id: rl
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: Tk.padding.largeIncreased
    anchors.rightMargin: Tk.padding.largeIncreased
    spacing: Tk.spacing.medium
    RowLabel { Layout.fillWidth: true; text: root.row.label; subtext: root.row.subtext || "" }
    Rectangle {
      Layout.preferredWidth: Tk.px(28)
      Layout.preferredHeight: Tk.px(28)
      radius: width / 2
      color: /^[0-9a-fA-F]{6}$/.test(root.value) ? "#" + root.value : "transparent"
      border.width: 1
      border.color: Colours.m3outlineVariant
    }
    Rectangle {
      Layout.preferredWidth: Tk.px(112)
      Layout.preferredHeight: Tk.px(36)
      radius: height / 2
      color: Colours.m3surfaceContainerHighest
      border.width: hex.activeFocus ? 2 : 0
      border.color: Colours.m3primary
      Row {
        anchors.fill: parent
        anchors.leftMargin: Tk.padding.medium
        spacing: Tk.spacing.small
        MIcon { anchors.verticalCenter: parent.verticalCenter; text: "tag"; size: Tk.iconSize.small; color: Colours.m3onSurfaceVariant }
        MTextField {
          id: hex
          anchors.verticalCenter: parent.verticalCenter
          width: Tk.px(64)
          text: root.value
          maximumLength: 6
          font.family: Tk.mono; font.pointSize: Tk.body.small
          validator: RegularExpressionValidator { regularExpression: /[0-9a-fA-F]{0,6}/ }
          onEditingFinished: if (text.length === 6) Config.set(root.row.key, text.toLowerCase()); else text = root.value
        }
      }
    }
  }
}
