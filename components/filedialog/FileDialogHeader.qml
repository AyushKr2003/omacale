pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../.."

// Caelestia components/filedialog/HeaderBar.qml: up a folder, and the path as
// breadcrumbs, each one but the last a way back to it.
Rectangle {
  id: root

  required property var dialog

  implicitWidth: inner.implicitWidth + Tk.padding.medium * 2
  implicitHeight: inner.implicitHeight + Tk.padding.medium * 2

  color: Colours.m3surfaceContainer

  RowLayout {
    id: inner

    anchors.fill: parent
    anchors.margins: Tk.padding.medium
    spacing: Tk.spacing.small

    Item {
      implicitWidth: implicitHeight
      implicitHeight: upIcon.implicitHeight + Tk.padding.small

      StateLayer {
        radius: Tk.rounding.medium
        disabled: root.dialog.cwd.length === 1
        onClicked: root.dialog.cwd = root.dialog.cwd.slice(0, -1)
      }

      MIcon {
        id: upIcon
        anchors.centerIn: parent
        text: "drive_folder_upload"
        color: root.dialog.cwd.length === 1 ? Colours.m3outline : Colours.m3onSurface
        size: Tk.iconSize.medium
        grade: 200
      }
    }

    Rectangle {
      Layout.fillWidth: true

      radius: Tk.rounding.medium
      color: Colours.m3surfaceContainerHigh
      clip: true

      implicitHeight: pathComponents.implicitHeight + pathComponents.anchors.margins * 2

      RowLayout {
        id: pathComponents

        anchors.fill: parent
        anchors.margins: Tk.padding.extraSmall / 2
        anchors.leftMargin: 0
        spacing: Tk.spacing.small

        Repeater {
          model: root.dialog.cwd

          RowLayout {
            id: folder

            required property string modelData
            required property int index
            readonly property bool last: index === root.dialog.cwd.length - 1
            readonly property bool home: index === 0 && modelData === "Home"

            spacing: 0

            MText {
              Layout.rightMargin: Tk.spacing.small
              visible: folder.index > 0
              text: "/"
              color: Colours.m3onSurfaceVariant
              weight: Font.Bold
            }

            Item {
              implicitWidth: (folder.home ? homeIcon.implicitWidth + Tk.padding.extraSmall : 0) + folderName.implicitWidth + Tk.padding.medium * 2
              implicitHeight: folderName.implicitHeight + Tk.padding.small

              StateLayer {
                visible: !folder.last
                radius: Tk.rounding.medium
                onClicked: root.dialog.cwd = root.dialog.cwd.slice(0, folder.index + 1)
              }

              MIcon {
                id: homeIcon
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Tk.padding.medium
                visible: folder.home
                text: "home"
                color: root.dialog.cwd.length === 1 ? Colours.m3onSurface : Colours.m3onSurfaceVariant
                fill: 1
              }

              MText {
                id: folderName
                anchors.left: folder.home ? homeIcon.right : parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: folder.home ? Tk.padding.extraSmall : Tk.padding.medium
                text: folder.modelData
                color: folder.last ? Colours.m3onSurface : Colours.m3onSurfaceVariant
                weight: Font.Bold
              }
            }
          }
        }

        Item { Layout.fillWidth: true }
      }
    }
  }
}
