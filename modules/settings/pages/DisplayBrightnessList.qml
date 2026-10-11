import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../.."

// Settings › Display › Brightness: every screen's brightness (Omarchy's
// backlight or DDC/CI), with its "turn off for now" button, as the utilities
// Displays card; one "All screens" slider while they share one brightness.
// A screen that reports no brightness has no row.
ColumnLayout {
  id: root
  property var row
  property var settings
  property bool first
  property bool last
  spacing: Tk.spacing.extraSmall / 2
  Component.onCompleted: DisplayService.hold()
  Component.onDestruction: DisplayService.release()

  readonly property var levels: DisplayService.brightness
  readonly property var names: Quickshell.screens.map(s => s.name).filter(n => levels[n] !== undefined)
  readonly property var rows: DisplayService.linked ? (names.length ? [""] : []) : names

  Repeater {
    model: root.rows
    ConnectedRect {
      id: br
      required property string modelData
      required property int index
      readonly property string name: modelData || root.names[0]
      readonly property bool off: DisplayService.blanked.indexOf(name) >= 0
      Layout.fillWidth: true
      first: index === 0
      last: index === root.rows.length - 1
      implicitHeight: bl.implicitHeight + Tk.padding.medium * 2
      RowLayout {
        id: bl
        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Tk.padding.largeIncreased; anchors.rightMargin: Tk.padding.medium
        spacing: Tk.spacing.medium
        MIcon { text: "brightness_6"; size: Tk.iconSize.medium; color: Colours.m3onSurfaceVariant }
        MText { Layout.preferredWidth: Tk.px(90); text: br.modelData || "All screens"; elide: Text.ElideRight }
        MSlider {
          Layout.fillWidth: true
          implicitHeight: Tk.px(30)
          value: (root.levels[br.name] || 0) / 100
          onMoved: v => DisplayService.setBrightness(br.name, Math.max(1, v * 100))
        }
        MText { Layout.preferredWidth: Tk.px(40); horizontalAlignment: Text.AlignRight; text: Math.round(root.levels[br.name] || 0) + "%"; color: Colours.m3onSurfaceVariant }
        IconButton {
          visible: !!br.modelData
          type: "text"
          toggle: true
          checked: br.off
          icon: "power_settings_new"
          disabled: !br.off && !DisplayService.canBlank(br.name)
          onClicked: br.off ? DisplayService.wake(br.name) : DisplayService.blank(br.name)
        }
      }
    }
  }
}
