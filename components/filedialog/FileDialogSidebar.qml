pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../.."

// Caelestia components/filedialog/Sidebar.qml: the places list.
Rectangle {
  id: root

  required property var dialog

  implicitWidth: dialog.sidebarWidth
  implicitHeight: inner.implicitHeight + Tk.padding.medium * 2

  color: Colours.m3surfaceContainer

  ColumnLayout {
    id: inner

    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: Tk.padding.medium
    spacing: Tk.spacing.extraSmall

    MText {
      Layout.alignment: Qt.AlignHCenter
      Layout.topMargin: Tk.padding.extraSmall / 2
      Layout.bottomMargin: Tk.spacing.medium
      text: root.dialog.selectFolder ? "Folders" : "Files"
      font.pointSize: Tk.body.large
      weight: Font.Bold
    }

    Repeater {
      model: ["Home", "Downloads", "Desktop", "Documents", "Music", "Pictures", "Videos"].concat(root.dialog.selectFolder ? ["File system"] : [])

      Rectangle {
        id: place

        required property string modelData
        readonly property bool selected: modelData === "File system" ? root.dialog.path === "/" : modelData === root.dialog.cwd[root.dialog.cwd.length - 1]

        Layout.fillWidth: true
        implicitHeight: placeInner.implicitHeight + Tk.padding.medium * 2

        radius: Tk.rounding.full
        color: Qt.alpha(Colours.m3secondaryContainer, selected ? 1 : 0)

        StateLayer {
          color: place.selected ? Colours.m3onSecondaryContainer : Colours.m3onSurface
          onClicked: root.dialog.cwd = place.modelData === "File system" ? [""] : place.modelData === "Home" ? ["Home"] : ["Home", place.modelData]
        }

        RowLayout {
          id: placeInner

          anchors.fill: parent
          anchors.margins: Tk.padding.medium
          anchors.leftMargin: Tk.padding.large
          anchors.rightMargin: Tk.padding.large
          spacing: Tk.spacing.medium

          MIcon {
            text: ({
              Home: "home",
              Downloads: "file_download",
              Desktop: "desktop_windows",
              Documents: "description",
              Music: "music_note",
              Pictures: "image",
              Videos: "video_library",
              "File system": "computer"
            })[place.modelData] || "folder"
            color: place.selected ? Colours.m3onSecondaryContainer : Colours.m3onSurface
            size: Tk.iconSize.medium
            fill: place.selected ? 1 : 0

            Behavior on fill { Anim { type: "effects" } }
          }

          MText {
            Layout.fillWidth: true
            text: place.modelData
            color: place.selected ? Colours.m3onSecondaryContainer : Colours.m3onSurface
            elide: Text.ElideRight
          }
        }
      }
    }
  }
}
