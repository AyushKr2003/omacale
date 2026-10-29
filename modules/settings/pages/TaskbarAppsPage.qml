pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import "../../../core/TaskbarApps.js" as Model
import "../../.."

// No Caelestia original for bar groups. The editor uses the same connected
// app rows and outlined fields as its Nexus Apps pages.
ColumnLayout {
  id: root
  property var row
  property var settings
  property bool first
  property bool last
  property string error: ""
  spacing: Tk.spacing.extraSmall / 2
  function choose(group) { settings.taskbarGroup = group; settings.push("taskbarAppPicker") }

  SectionHeader { first: true; row: ({ text: "Pinned items" }) }
  MText {
    Layout.fillWidth: true
    Layout.margins: Tk.padding.medium
    text: "Arrange apps, app groups and directory shortcuts below. The Apps section itself can be moved in Taskbar › Bar."
    color: Colours.m3onSurfaceVariant
    wrapMode: Text.WordWrap
  }
  Repeater {
    id: pins
    model: TaskbarApps.pins.map(i => i.id)
    ConnectedRect {
      id: pin
      required property string modelData
      required property int index
      readonly property var item: TaskbarApps.pins.find(i => i.id === modelData) || null
      Layout.fillWidth: true
      first: index === 0
      last: index === pins.count - 1
      implicitHeight: body.implicitHeight + Tk.padding.medium * 2
      ColumnLayout {
        id: body
        anchors.fill: parent
        anchors.margins: Tk.padding.medium
        spacing: Tk.spacing.small
        RowLayout {
          spacing: Tk.spacing.small
          IconImage {
            visible: !!pin.item && pin.item.type === "app"
            implicitSize: Tk.iconSize.large
            source: TaskbarApps.icon(pin.item)
          }
          MIcon { visible: !!pin.item && pin.item.type !== "app"; text: pin.item && pin.item.type === "group" ? "apps" : "folder"; color: Colours.m3primary }
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            MText { Layout.fillWidth: true; text: TaskbarApps.label(pin.item); elide: Text.ElideRight }
            MText {
              Layout.fillWidth: true
              text: !pin.item ? "" : pin.item.type === "folder" ? pin.item.path : pin.item.type === "group" ? pin.item.apps.length + " apps" : TaskbarApps.entry(pin.item.app) ? "Pinned app" : "Unavailable · kept for when it returns"
              color: Colours.m3outline
              font.pointSize: Tk.label.small
              elide: Text.ElideMiddle
            }
          }
          IconButton { type: "text"; icon: "arrow_upward"; disabled: pin.index === 0; onClicked: TaskbarApps.save(Model.move(TaskbarApps.pins, pin.modelData, -1)); Accessible.name: "Move up" }
          IconButton { type: "text"; icon: "arrow_downward"; disabled: pin.index === pins.count - 1; onClicked: TaskbarApps.save(Model.move(TaskbarApps.pins, pin.modelData, 1)); Accessible.name: "Move down" }
          IconButton { type: "text"; icon: "close"; onClicked: TaskbarApps.save(Model.remove(TaskbarApps.pins, pin.modelData)); Accessible.name: "Remove item" }
        }
        RowLayout {
          visible: !!pin.item && pin.item.type !== "app"
          OutlinedField {
            Layout.fillWidth: true
            text: pin.item ? pin.item.name || "" : ""
            placeholderText: "Name"
            onEditingFinished: TaskbarApps.rename(pin.modelData, text)
          }
          IconTextButton {
            visible: !!pin.item && pin.item.type === "group"
            icon: "edit"
            text: "Choose apps"
            type: "tonal"
            onClicked: root.choose(pin.modelData)
          }
        }
      }
    }
  }
  RowButton {
    first: true
    icon: "add"
    text: "Pin apps"
    subtext: "Choose from installed apps"
    onClicked: root.choose("")
  }
  RowButton {
    last: true
    icon: "favorite"
    text: "Import launcher favourites"
    subtext: "Copy current favourites; later edits are independent"
    onClicked: {
      const current = TaskbarApps.pins
      const known = current.filter(i => i.type === "app").map(i => i.app)
      TaskbarApps.save(current.concat(Model.ids(Config.o.launcher.favouriteApps).filter(id => known.indexOf(id) < 0).map(id => ({ type: "app", app: id }))))
    }
  }

  SectionHeader { row: ({ text: "Add a group" }) }
  RowLayout {
    Layout.fillWidth: true
    OutlinedField { id: groupName; Layout.fillWidth: true; placeholderText: "Group name, e.g. Work"; onAccepted: addGroup.clicked() }
    IconTextButton {
      id: addGroup
      icon: "add"
      text: "Add group"
      type: "tonal"
      disabled: !groupName.text.trim()
      onClicked: { TaskbarApps.newGroup(groupName.text); groupName.text = "" }
    }
  }

  SectionHeader { row: ({ text: "Add a folder" }) }
  MText { Layout.fillWidth: true; text: "Opens a directory in your default file manager."; color: Colours.m3onSurfaceVariant; wrapMode: Text.WordWrap }
  OutlinedField { id: folderName; Layout.fillWidth: true; placeholderText: "Name (optional)" }
  RowLayout {
    Layout.fillWidth: true
    OutlinedField { id: folderPath; Layout.fillWidth: true; placeholderText: "Absolute path or ~/Documents"; onAccepted: addFolder.clicked() }
    IconTextButton {
      id: addFolder
      icon: "add"
      text: "Add folder"
      type: "tonal"
      disabled: !folderPath.text.trim()
      onClicked: {
        if (TaskbarApps.newFolder(folderName.text, folderPath.text)) { folderName.text = ""; folderPath.text = ""; root.error = "" }
        else root.error = "Enter an absolute directory path or a path beginning with ~/."
      }
    }
  }
  MText { Layout.fillWidth: true; visible: root.error !== ""; text: root.error; color: Colours.m3error; wrapMode: Text.WordWrap }
}
