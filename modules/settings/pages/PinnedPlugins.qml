import QtQuick
import QtQuick.Layouts
import "../../.."

// Settings › Taskbar › Plugins: which third-party widgets sit in the bar's
// plugin pill, and which wait behind its chevron. Enabling a plugin is
// Settings › Plugins; this only decides how much room it takes.
ColumnLayout {
  id: root
  property var row
  property var settings
  property bool first
  property bool last

  readonly property var widgets: PluginService.plugins.filter(p =>
    !p.firstParty && p.enabled && p.kinds.indexOf("bar-widget") >= 0)
  readonly property var unpinned: Config.o.bar.plugins.unpinned

  function setPinned(id, on) {
    const l = Array.from(unpinned).filter(i => i !== id)
    Config.set("bar.plugins.unpinned", on ? l : l.concat([id]))
  }

  spacing: Tk.spacing.extraSmall / 2
  Component.onCompleted: PluginService.refresh()

  MText {
    Layout.fillWidth: true
    Layout.bottomMargin: Tk.spacing.small
    text: root.widgets.length === 0
      ? "No third-party bar widgets are enabled. Add them in Settings › Plugins."
      : "Pinned widgets always show in the pill. The rest wait behind its chevron, which opens when you hover it — they keep running either way."
    color: Colours.m3outline
    wrapMode: Text.WordWrap
  }

  Repeater {
    id: rep
    model: root.widgets

    ConnectedRect {
      id: pr
      required property var modelData
      required property int index
      readonly property bool isPinned: root.unpinned.indexOf(modelData.id) < 0
      Layout.fillWidth: true
      first: index === 0
      last: index === rep.count - 1
      implicitHeight: pl.implicitHeight + Tk.padding.medium * 2

      StateLayer { onClicked: root.setPinned(pr.modelData.id, !pr.isPinned) }
      RowLayout {
        id: pl
        anchors.fill: parent
        anchors.margins: Tk.padding.medium
        anchors.leftMargin: Tk.padding.largeIncreased
        anchors.rightMargin: Tk.padding.largeIncreased
        spacing: Tk.spacing.medium
        MIcon {
          text: pr.isPinned ? "push_pin" : "widgets"
          size: Tk.iconSize.medium
          fill: pr.isPinned ? 1 : 0
          color: pr.isPinned ? Colours.m3primary : Colours.m3outline
        }
        RowLabel {
          Layout.fillWidth: true
          text: pr.modelData.name
          subtext: pr.isPinned ? "Always in the bar" : "Behind the chevron"
        }
        MSwitch {
          checked: pr.isPinned
          onToggled: c => root.setPinned(pr.modelData.id, c)
        }
      }
    }
  }
}
