import QtQuick
import QtQuick.Layouts
import "../.."

// Caelestia modules/windowinfo/Details.qml: title and class over a divider,
// then one icon row per Hyprland client field.
ColumnLayout {
  id: root

  required property var client
  readonly property var ipc: client ? client.lastIpcObject : null

  anchors.fill: parent
  spacing: Tk.spacing.small

  Label {
    Layout.topMargin: Tk.padding.extraLargeIncreased
    text: root.client ? root.client.title : "No active client"
    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
    font.pointSize: Tk.body.large
    weight: Font.Medium
  }

  Label {
    text: root.ipc && root.ipc.class !== undefined ? root.ipc.class : "No active client"
    color: Colours.m3tertiary
    font.pointSize: Tk.body.large
  }

  Rectangle {
    Layout.fillWidth: true
    Layout.preferredHeight: 1
    Layout.leftMargin: Tk.padding.extraLargeIncreased
    Layout.rightMargin: Tk.padding.extraLargeIncreased
    Layout.topMargin: Tk.spacing.medium
    Layout.bottomMargin: Tk.spacing.largeIncreased
    color: Colours.m3secondary
  }

  Detail {
    icon: "location_on"
    text: root.client && root.client.address ? "Address: 0x" + root.client.address : "Address: unknown"
    color: Colours.m3primary
  }
  Detail {
    icon: "location_searching"
    text: "Position: " + (root.ipc && root.ipc.at ? root.ipc.at[0] + ", " + root.ipc.at[1] : "-1, -1")
  }
  Detail {
    icon: "resize"
    text: "Size: " + (root.ipc && root.ipc.size ? root.ipc.size[0] + " x " + root.ipc.size[1] : "-1 x -1")
    color: Colours.m3tertiary
  }
  Detail {
    icon: "workspaces"
    text: "Workspace: " + (root.client && root.client.workspace ? root.client.workspace.name + " (" + root.client.workspace.id + ")" : "-1 (-1)")
    color: Colours.m3secondary
  }
  Detail {
    icon: "desktop_windows"
    text: {
      const mon = root.client ? root.client.monitor : null
      return mon ? "Monitor: " + mon.name + " (" + mon.id + ") at " + mon.x + ", " + mon.y : "Monitor: unknown"
    }
  }
  Detail {
    icon: "page_header"
    text: root.ipc && root.ipc.initialTitle ? "Initial title: " + root.ipc.initialTitle : "Initial title: unknown"
    color: Colours.m3tertiary
  }
  Detail {
    icon: "category"
    text: root.ipc && root.ipc.initialClass ? "Initial class: " + root.ipc.initialClass : "Initial class: unknown"
  }
  Detail {
    icon: "account_tree"
    text: "Process id: " + (root.ipc && root.ipc.pid !== undefined ? root.ipc.pid : -1)
    color: Colours.m3primary
  }
  Detail {
    icon: "picture_in_picture_center"
    text: root.ipc && root.ipc.floating ? "Floating: yes" : "Floating: no"
    color: Colours.m3secondary
  }
  Detail {
    icon: "gradient"
    text: root.ipc && root.ipc.xwayland ? "Xwayland: yes" : "Xwayland: no"
  }
  Detail {
    icon: "keep"
    text: root.ipc && root.ipc.pinned ? "Pinned: yes" : "Pinned: no"
    color: Colours.m3secondary
  }
  Detail {
    icon: "fullscreen"
    text: {
      const fs = root.ipc ? root.ipc.fullscreen : undefined
      if (fs === 0) return "Fullscreen state: off"
      if (fs === 1) return "Fullscreen state: maximised"
      if (fs !== undefined) return "Fullscreen state: on"
      return "Fullscreen state: unknown"
    }
    color: Colours.m3tertiary
  }

  Item { Layout.fillHeight: true }

  component Detail: RowLayout {
    id: detail
    required property string icon
    required property string text
    property alias color: detailIcon.color
    Layout.leftMargin: Tk.padding.large
    Layout.rightMargin: Tk.padding.large
    Layout.fillWidth: true
    spacing: Tk.spacing.medium
    MIcon {
      id: detailIcon
      Layout.alignment: Qt.AlignVCenter
      text: detail.icon
    }
    MText {
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignVCenter
      text: detail.text
      elide: Text.ElideRight
      font.pointSize: Tk.body.medium
    }
  }

  component Label: MText {
    Layout.leftMargin: Tk.padding.large
    Layout.rightMargin: Tk.padding.large
    Layout.fillWidth: true
    elide: Text.ElideRight
    horizontalAlignment: Text.AlignHCenter
    animate: true
  }
}
