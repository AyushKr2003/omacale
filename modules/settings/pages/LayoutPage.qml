import QtQuick
import QtQuick.Layouts
import "../../.."
import "../../../core/BarLayout.js" as BarLayout

// Settings › Taskbar › Layout: the bar's start, center and end sections
// (bar.layout), Noctalia-style; no Caelestia original. The arrows move an
// item one step, and across sections at their edges; the eye is the item's
// existing switch (Status icons › Network, Clock › Show, ...); a widget taken
// out of the plugin group gets an undo that puts it back instead.
ColumnLayout {
  id: root
  property var row
  property var settings
  property bool first
  property bool last

  readonly property var layout: {
    void Config.o.bar.layout.start; void Config.o.bar.layout.center; void Config.o.bar.layout.end
    void PluginService.barWidgets
    return PluginService.barLayout()
  }
  readonly property bool vertical: Tk.barVertical
  // Widgets still in the plugin group, which can be given a place of their own.
  readonly property var groupWidgets: PluginService.barWidgets.filter(p =>
    !BarLayout.SECTIONS.some(s => root.layout[s].indexOf("plugin:" + p.id) >= 0)
    && PluginService.barMode(p.id) !== "hidden")

  function info(id) {
    if (BarLayout.isPlugin(id)) {
      const p = PluginService.byId(BarLayout.pluginOf(id))
      return { label: p ? p.name : BarLayout.pluginOf(id), icon: "extension", sub: "Plugin, on its own", key: "", plugin: true }
    }
    return BarLayout.ITEMS[id]
  }
  function moveItem(id, dir) { PluginService.setBarLayout(BarLayout.move(layout, id, dir)) }

  spacing: Tk.spacing.extraSmall / 2
  Component.onCompleted: PluginService.refresh()

  Repeater {
    model: BarLayout.SECTIONS

    ColumnLayout {
      id: sec
      required property string modelData
      required property int index
      readonly property var ids: root.layout[modelData]
      Layout.fillWidth: true
      spacing: Tk.spacing.extraSmall / 2

      SectionHeader { first: sec.index === 0; row: ({ text: BarLayout.sectionLabel(sec.modelData, root.vertical) }) }
      MText {
        Layout.fillWidth: true
        visible: sec.ids.length === 0
        text: "Empty. Move an item here with the arrows."
        color: Colours.m3outline
        wrapMode: Text.WordWrap
      }

      Repeater {
        id: rowsRep
        model: sec.ids

        ConnectedRect {
          id: r
          required property string modelData
          required property int index
          readonly property var it: root.info(modelData)
          readonly property bool isShown: PluginService.itemShown(modelData)
          Layout.fillWidth: true
          first: index === 0
          last: index === rowsRep.count - 1
          implicitHeight: rl.implicitHeight + Tk.padding.medium * 2

          RowLayout {
            id: rl
            anchors.fill: parent
            anchors.topMargin: Tk.padding.medium
            anchors.bottomMargin: Tk.padding.medium
            anchors.leftMargin: Tk.padding.largeIncreased
            anchors.rightMargin: Tk.padding.medium
            spacing: Tk.spacing.medium
            MIcon { text: r.it.icon; size: Tk.iconSize.medium; color: Colours.m3onSurfaceVariant; opacity: r.isShown ? 1 : 0.45 }
            RowLabel {
              Layout.fillWidth: true
              opacity: r.isShown ? 1 : 0.45
              text: r.it.label
              subtext: r.isShown ? r.it.sub : "Hidden"
            }
            IconButton {
              type: "text"
              icon: "arrow_upward"
              disabled: !BarLayout.canMove(root.layout, r.modelData, -1)
              onClicked: root.moveItem(r.modelData, -1)
            }
            IconButton {
              type: "text"
              icon: "arrow_downward"
              disabled: !BarLayout.canMove(root.layout, r.modelData, 1)
              onClicked: root.moveItem(r.modelData, 1)
            }
            IconButton {
              visible: !r.it.plugin
              type: "text"
              icon: r.isShown ? "visibility" : "visibility_off"
              disabled: !r.it.key
              onClicked: PluginService.setItemShown(r.modelData, !r.isShown)
            }
            IconButton {
              visible: !!r.it.plugin
              type: "text"
              icon: "undo"
              onClicked: PluginService.putBackWidget(BarLayout.pluginOf(r.modelData))
            }
          }
        }
      }
    }
  }

  SectionHeader { row: ({ text: "More" }) }
  RowSelect {
    Layout.fillWidth: true
    first: true
    last: false
    visible: root.groupWidgets.length > 0
    settings: root.settings
    row: ({
      label: "Take a plugin out of the group",
      subtext: "It gets a place of its own in the bar",
      options: [{ value: "", label: "Choose", icon: "add" }].concat(root.groupWidgets.map(p => ({ value: p.id, label: p.name, icon: "extension" })))
    })
    value: ""
    onPicked: v => { if (v) PluginService.takeOutWidget(v) }
  }

  // Reset, confirmed by a second click as Settings › About's "Reset all settings".
  property bool confirmReset: false
  Timer { id: confirmTimer; interval: 3000; onTriggered: root.confirmReset = false }
  ConnectedRect {
    Layout.fillWidth: true
    first: root.groupWidgets.length === 0
    last: true
    color: root.confirmReset ? Colours.m3errorContainer : Colours.m3surfaceContainer
    implicitHeight: rr.implicitHeight + Tk.padding.medium * 2
    StateLayer {
      color: Colours.m3error
      onClicked: {
        if (root.confirmReset) { PluginService.setBarLayout({ start: [], center: [], end: [] }); root.confirmReset = false }
        else { root.confirmReset = true; confirmTimer.restart() }
      }
    }
    RowLayout {
      id: rr
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Tk.padding.largeIncreased
      anchors.rightMargin: Tk.padding.largeIncreased
      spacing: Tk.spacing.medium
      MIcon { text: root.confirmReset ? "warning" : "restart_alt"; size: Tk.iconSize.medium; fill: 1; color: Colours.m3error }
      RowLabel {
        Layout.fillWidth: true
        text: root.confirmReset ? "Click again to reset the layout" : "Reset layout"
        subtext: "Every item back where it was, plugins back in the group"
      }
    }
  }
}
