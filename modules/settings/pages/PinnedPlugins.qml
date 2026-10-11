import QtQuick
import QtQuick.Layouts
import "../../.."

// Settings › Taskbar › Plugins: the plugin pill, and for each third-party
// widget whether it is pinned in the pill, waits behind its chevron, or is
// left out of the bar (bar.plugins.hidden, like the tray's hiddenIcons).
// Enabling a plugin is Settings › Plugins; this only decides where its widget
// goes. The modes and the pill switch are kept in step by PluginService.
ColumnLayout {
  id: root
  property var row
  property var settings
  property bool first
  property bool last

  readonly property var widgets: PluginService.barWidgets
  readonly property var modes: [
    { value: "pinned", label: "Pinned", icon: "push_pin" },
    { value: "overflow", label: "Behind chevron", icon: "expand_less" },
    { value: "hidden", label: "Hidden", icon: "visibility_off" }
  ]
  readonly property var subtexts: ({
    pinned: "Always in the bar",
    overflow: "Shows when you hover the pill's chevron",
    hidden: "Not in the bar. The plugin keeps running"
  })

  spacing: Tk.spacing.extraSmall / 2
  Component.onCompleted: PluginService.refresh()

  RowToggle {
    Layout.fillWidth: true
    first: true
    last: true
    text: "Show plugins"
    subtext: "The pill of third-party widgets in the bar"
    checked: Config.o.bar.plugins.enabled
    onToggled: c => PluginService.setBarShown(c)
  }

  SectionHeader { row: ({ text: "Widgets" }) }

  MText {
    Layout.fillWidth: true
    visible: root.widgets.length === 0
    text: "No third-party bar widgets are enabled. Add them in Settings › Plugins."
    color: Colours.m3outline
    wrapMode: Text.WordWrap
  }

  Repeater {
    id: rep
    model: root.widgets

    RowSelect {
      id: wr
      required property var modelData
      required property int index
      readonly property string mode: PluginService.barMode(modelData.id)
      Layout.fillWidth: true
      first: index === 0
      last: index === rep.count - 1
      settings: root.settings
      row: ({ label: modelData.name, subtext: root.subtexts[mode], options: root.modes })
      value: mode
      onPicked: v => PluginService.setBarMode(modelData.id, v)
    }
  }
}
