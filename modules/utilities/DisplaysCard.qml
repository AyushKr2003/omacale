import QtQuick
import QtQuick.Layouts
import Quickshell
import "../.."

// Brightness for every screen (no Caelestia original; drawn like its
// utilities cards). Only with more than one screen, so a laptop on its own
// keeps Caelestia's drawer. Each slider is Omarchy's brightness for that
// display (backlight or DDC/CI); a display that reports none has no slider.
Rectangle {
  id: root

  Component.onCompleted: DisplayService.hold()
  Component.onDestruction: DisplayService.release()

  readonly property var levels: DisplayService.brightness
  readonly property var names: Quickshell.screens.map(s => s.name).filter(n => levels[n] !== undefined)
  visible: Quickshell.screens.length > 1 && names.length > 0

  implicitHeight: visible ? col.implicitHeight + Tk.padding.large * 2 : 0
  radius: Tk.rounding.large
  color: Colours.m3surfaceContainer

  ColumnLayout {
    id: col
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.margins: Tk.padding.large
    spacing: Tk.spacing.small

    RowLayout {
      spacing: Tk.spacing.medium
      MIcon { text: "brightness_6"; size: Tk.iconSize.medium; color: Colours.m3onSurfaceVariant }
      MText { Layout.fillWidth: true; text: "Displays"; font.pointSize: Tk.body.medium }
      // Same brightness on every display (display.linkBrightness).
      IconButton {
        type: "text"
        toggle: true
        icon: "link"
        checked: DisplayService.linked
        onClicked: Config.set("display.linkBrightness", !DisplayService.linked)
      }
    }
    // Linked: one slider, at the first display's level until it is moved.
    RowLayout {
      visible: DisplayService.linked
      Layout.fillWidth: true
      spacing: Tk.spacing.medium
      MText { Layout.preferredWidth: Tk.px(80); text: "All displays"; color: Colours.m3onSurfaceVariant; font.pointSize: Tk.body.small; elide: Text.ElideRight }
      MSlider {
        Layout.fillWidth: true
        implicitHeight: Tk.px(26)
        value: (root.levels[root.names[0]] || 0) / 100
        onMoved: v => DisplayService.setBrightness(root.names[0], v * 100)
      }
      MText { Layout.preferredWidth: Tk.px(36); horizontalAlignment: Text.AlignRight; text: Math.round(root.levels[root.names[0]] || 0) + "%"; color: Colours.m3onSurfaceVariant; font.pointSize: Tk.body.small }
    }
    Repeater {
      model: DisplayService.linked ? [] : root.names
      RowLayout {
        required property string modelData
        Layout.fillWidth: true
        spacing: Tk.spacing.medium
        MText { Layout.preferredWidth: Tk.px(80); text: modelData; color: Colours.m3onSurfaceVariant; font.pointSize: Tk.body.small; elide: Text.ElideRight }
        MSlider {
          Layout.fillWidth: true
          implicitHeight: Tk.px(26)
          value: (root.levels[modelData] || 0) / 100
          onMoved: v => DisplayService.setBrightness(modelData, Math.max(1, v * 100))
        }
        MText { Layout.preferredWidth: Tk.px(36); horizontalAlignment: Text.AlignRight; text: Math.round(root.levels[modelData] || 0) + "%"; color: Colours.m3onSurfaceVariant; font.pointSize: Tk.body.small }
        // Dark for now (Settings › Display › Turn off for now) and back.
        IconButton {
          readonly property bool off: DisplayService.blanked.indexOf(modelData) >= 0
          type: "text"
          toggle: true
          checked: off
          icon: "power_settings_new"
          disabled: !off && !DisplayService.canBlank(modelData)
          onClicked: off ? DisplayService.wake(modelData) : DisplayService.blank(modelData)
        }
      }
    }
  }
}
