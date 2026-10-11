import QtQuick
import QtQuick.Layouts
import "../../.."
import "../../../services/DisplayModel.js" as Model

// Settings › Display › Night light: on/off and warmth (services/NightLight.qml,
// Omarchy's hyprsunset). The schedule rows are plain settings below it.
ColumnLayout {
  id: root
  property var row
  property var settings
  property bool first
  property bool last
  spacing: Tk.spacing.extraSmall / 2

  RowToggle {
    Layout.fillWidth: true
    first: true
    text: "Night light"
    subtext: "Warmer colours on every screen (hyprsunset can't tint one screen alone)"
    checked: NightLight.on
    onToggled: c => NightLight.set(c)
  }
  ConnectedRect {
    Layout.fillWidth: true
    last: true
    implicitHeight: nt.implicitHeight + Tk.padding.medium * 2
    RowLayout {
      id: nt
      anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Tk.padding.largeIncreased; anchors.rightMargin: Tk.padding.largeIncreased
      spacing: Tk.spacing.medium
      MIcon { text: "thermostat"; size: Tk.iconSize.medium; color: Colours.m3onSurfaceVariant }
      MText { text: "Warmth"; Layout.preferredWidth: Tk.px(70) }
      MSlider {
        Layout.fillWidth: true
        implicitHeight: Tk.px(30)
        // Left is warm: the slider runs 6000 K -> 2500 K.
        value: 1 - Model.kelvinPos(Config.o.display.nightTemp)
        onMoved: v => NightLight.setTemperature(Model.kelvinAt(1 - v))
      }
      MText { Layout.preferredWidth: Tk.px(56); horizontalAlignment: Text.AlignRight; text: Config.o.display.nightTemp + " K"; color: Colours.m3onSurfaceVariant }
    }
  }
}
