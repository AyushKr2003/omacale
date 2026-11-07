pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import "../../.."

// Caelestia Nexus apps/AllApps.qml, with a toggle rather than navigation.
ColumnLayout {
  id: root
  property var row
  property var settings
  property bool first
  property bool last
  property string query: ""
  readonly property string groupId: settings ? settings.taskbarGroup : ""
  readonly property var group: TaskbarApps.pins.find(i => i.id === groupId && i.type === "group") || null
  readonly property bool valid: groupId === "" || !!group
  readonly property var chosen: groupId === "" ? TaskbarApps.pins.filter(i => i.type === "app").map(i => i.app) : group ? group.apps : []
  spacing: Tk.spacing.extraSmall / 2
  MText { Layout.fillWidth: true; text: root.group ? "Apps in “" + root.group.name + "”" : root.valid ? "Apps pinned individually to the taskbar" : "This group was removed. Go back to create another."; color: Colours.m3onSurfaceVariant; wrapMode: Text.WordWrap }
  OutlinedField { Layout.fillWidth: true; Layout.bottomMargin: Tk.spacing.small; placeholderText: "Search installed apps"; onTextChanged: root.query = text }
  Repeater {
    id: apps
    // Stable while toggling a pin; updating only membership cannot destroy
    // the pressed row or reset the search scroll position.
    model: TaskbarApps.available.filter(e => (e.name + " " + e.id).toLowerCase().indexOf(root.query.toLowerCase()) >= 0).slice().sort((a, b) => a.name.localeCompare(b.name))
    ConnectedRect {
      id: app
      required property var modelData
      required property int index
      Layout.fillWidth: true
      first: index === 0
      last: index === apps.count - 1
      implicitHeight: contents.implicitHeight + Tk.padding.medium * 2
      readonly property bool chosen: root.chosen.indexOf(modelData.id.replace(/\.desktop$/, "")) >= 0
      function toggle() {
        if (!root.valid) return
        if (root.groupId) TaskbarApps.setMember(root.groupId, modelData.id, !chosen)
        else TaskbarApps.pin(modelData.id, !chosen)
      }
      StateLayer { disabled: !root.valid; onClicked: app.toggle() }
      RowLayout {
        id: contents
        anchors.fill: parent
        anchors.margins: Tk.padding.medium
        spacing: Tk.spacing.medium
        IconImage { implicitSize: Tk.iconSize.large; source: IconFiles.source(app.modelData.icon, "application-x-executable") }
        MText { Layout.fillWidth: true; text: app.modelData.name; elide: Text.ElideRight }
        MSwitch { checked: app.chosen; disabled: !root.valid; onToggled: app.toggle() }
      }
    }
  }
  MText { visible: apps.count === 0; text: "No matching apps"; color: Colours.m3outline }
}
