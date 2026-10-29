pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import "../.."

// App groups have no Caelestia original. They use its Nexus app rows inside
// the existing bar popout, which supplies the frame, motion and key cursor.
ColumnLayout {
  id: root
  property string groupId: ""
  property var host
  property var screen
  signal closeRequested()
  signal appActivated()
  readonly property var group: TaskbarApps.pins.find(i => i.type === "group" && i.id === groupId) || null
  readonly property var members: group ? group.apps.filter(id => TaskbarApps.entry(id)) : []
  width: Tk.px(320)
  spacing: Tk.spacing.small
  onGroupChanged: if (!group) closeRequested()
  Connections { target: Config.o.bar.apps; function onEnabledChanged() { if (!Config.o.bar.apps.enabled) root.closeRequested() } }
  RowLayout {
    Layout.fillWidth: true
    MText { Layout.fillWidth: true; text: root.group ? root.group.name : ""; font.pointSize: Tk.title.medium; weight: Font.Medium; elide: Text.ElideRight }
    IconButton { icon: "close"; onClicked: root.closeRequested() }
  }
  FadeFlickable {
    Layout.fillWidth: true
    implicitHeight: Math.min(rows.implicitHeight, (root.screen ? root.screen.height : Tk.px(800)) * 0.55)
    contentHeight: rows.implicitHeight
    ColumnLayout {
      id: rows
      width: parent.width
      spacing: Tk.spacing.extraSmall / 2
      Repeater {
        id: rep
        model: root.members
        ConnectedRect {
          id: member
          required property string modelData
          required property int index
          readonly property var app: TaskbarApps.entry(modelData)
          readonly property var item: ({ type: "app", app: modelData })
          Layout.fillWidth: true
          first: index === 0
          last: index === rep.count - 1
          implicitHeight: row.implicitHeight + Tk.padding.medium * 2
          StateLayer {
            onClicked: { root.appActivated(); root.closeRequested(); TaskbarApps.activate(member.item, root.host, false) }
          }
          RowLayout {
            id: row
            anchors.fill: parent
            anchors.margins: Tk.padding.medium
            spacing: Tk.spacing.medium
            IconImage { implicitSize: Tk.iconSize.large; source: TaskbarApps.icon(member.item) }
            MText { Layout.fillWidth: true; text: member.app ? member.app.name : member.modelData; elide: Text.ElideRight }
            MIcon { visible: TaskbarApps.windowsFor(member.item).length > 0; text: "circle"; fill: 1; size: Tk.iconSize.small / 2; color: Colours.m3primary }
          }
        }
      }
      MText {
        visible: root.members.length === 0
        Layout.fillWidth: true
        text: "No available apps. Add apps in Settings › Taskbar › Apps."
        color: Colours.m3onSurfaceVariant
        wrapMode: Text.WordWrap
      }
    }
  }
}
