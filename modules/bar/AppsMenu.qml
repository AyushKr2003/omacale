pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import "../.."

// App actions share the bar's existing keyboard popout and Nexus row controls.
ColumnLayout {
  id: root
  property var appItem: null
  property var host
  signal closeRequested()
  signal appActivated()
  signal groupRequested(string id)
  width: Tk.px(270)
  spacing: Tk.spacing.extraSmall / 2
  readonly property bool isApp: !!appItem && appItem.type === "app"
  readonly property bool pinned: TaskbarApps.isSaved(appItem)
  readonly property bool running: isApp && TaskbarApps.windowsFor(appItem).length > 0
  readonly property var actions: {
    if (!appItem) return []
    const out = [{id:"open", icon:isApp ? "open_in_new" : appItem.type === "group" ? "apps" : "folder_open", label:running ? "Focus window" : "Open"}]
    if (isApp && running) out.push({id:"new",icon:"add",label:"New window"})
    out.push({id:"pin",icon:pinned ? "keep_off" : "keep",label:pinned ? "Unpin from taskbar" : "Pin to taskbar"})
    if (!isApp) out.push({id:"edit",icon:"edit",label:appItem.type === "group" ? "Edit group" : "Rename folder"})
    if (running) {
      out.push({id:"close",icon:"close",label:"Close all windows"})
      out.push({id:"quit",icon:"power_settings_new",label:TaskbarApps.quitting ? "Quitting application…" : "Quit application",disabled:TaskbarApps.quitting})
    }
    return out
  }
  Connections {
    target: Config.o.bar.apps
    function onEnabledChanged() { if (!Config.o.bar.apps.enabled) root.closeRequested() }
  }
  function invoke(action) {
    const item = appItem
    if (!item) return
    if (action === "pin") {
      if (isApp) TaskbarApps.pin(item.app, !pinned)
      else TaskbarApps.remove(item.id)
      root.closeRequested()
    } else if (action === "edit") {
      const targetHost = host
      root.appActivated()
      root.closeRequested()
      targetHost.toggle("settings", "taskbarApps")
    } else if (action === "open" && item.type === "group") {
      root.groupRequested(item.id)
    } else {
      root.appActivated()
      if (action === "close") TaskbarApps.closeWindows(item)
      else if (action === "quit") TaskbarApps.quit(item)
      else TaskbarApps.activate(item, host, action === "new")
      root.closeRequested()
    }
  }
  RowLayout {
    Layout.fillWidth: true
    Layout.margins: Tk.padding.small
    spacing: Tk.spacing.small
    IconImage { visible: root.isApp; implicitSize: Tk.px(28); source: TaskbarApps.icon(root.appItem) }
    MIcon { visible: !root.isApp; text: root.appItem && root.appItem.type === "group" ? "apps" : "folder" }
    MText { Layout.fillWidth: true; text: TaskbarApps.label(root.appItem); weight: Font.Medium; elide: Text.ElideRight }
  }
  Repeater {
    model: root.actions
    ConnectedRect {
      id: row
      required property var modelData
      required property int index
      objectName: "taskbarAction_" + modelData.id
      Layout.fillWidth: true
      first: index === 0
      last: index === root.actions.length - 1
      implicitHeight: content.implicitHeight + Tk.padding.small * 2
      StateLayer { disabled: !!row.modelData.disabled; onClicked: root.invoke(row.modelData.id) }
      RowLayout {
        id: content
        anchors.fill: parent
        anchors.margins: Tk.padding.small
        spacing: Tk.spacing.small
        MIcon { text: row.modelData.icon; color: row.modelData.id === "quit" ? Colours.m3error : Colours.m3onSurfaceVariant }
        MText { Layout.fillWidth: true; text: row.modelData.label; color: row.modelData.id === "quit" ? Colours.m3error : Colours.m3onSurface }
      }
    }
  }
}
