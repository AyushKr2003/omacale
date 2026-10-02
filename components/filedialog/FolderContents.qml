pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import "../.."

// Caelestia components/filedialog/FolderContents.qml: the folder as a grid,
// images as thumbnails. Caelestia's FileSystemModel is C++ (Caelestia.Models);
// Qt's FolderListModel is the same listing (QDir, watched with inotify),
// directories first, hidden files left out.
Item {
  id: root

  required property var dialog
  readonly property Item currentItem: view.currentItem

  // The frame: the container colour with the grid's rounded hole cut out of it,
  // so the window's surface shows through (Caelestia's inverted Mask).
  Rectangle {
    anchors.fill: parent
    color: Colours.m3surfaceContainer

    layer.enabled: true
    layer.effect: MultiEffect {
      maskEnabled: true
      maskInverted: true
      maskThresholdMin: 0.5
      maskSpreadAtMin: 1
      maskSource: mask
    }
  }

  Item {
    id: mask
    anchors.fill: parent
    layer.enabled: true
    visible: false

    Rectangle {
      anchors.fill: parent
      anchors.margins: Tk.padding.extraSmall
      radius: Tk.rounding.medium
    }
  }

  ColumnLayout {
    anchors.centerIn: parent
    opacity: view.count === 0 && folderModel.status !== FolderListModel.Loading ? 1 : 0
    visible: opacity > 0

    MIcon {
      Layout.alignment: Qt.AlignHCenter
      text: "scan_delete"
      color: Colours.m3outline
      size: Tk.iconSize.extraLarge * 2
      weight: Font.Medium
    }

    MText {
      text: "This folder is empty"
      color: Colours.m3outline
      font.pointSize: Tk.body.large
      weight: Font.Medium
    }

    Behavior on opacity { Anim { type: "effects" } }
  }

  GridView {
    id: view

    anchors.fill: parent
    anchors.margins: Tk.padding.extraSmall + Tk.padding.medium

    cellWidth: root.dialog.itemWidth + Tk.spacing.small
    cellHeight: root.dialog.itemWidth + Tk.spacing.large + Tk.padding.medium * 2 + 1

    clip: true
    focus: true
    currentIndex: -1

    Keys.onEscapePressed: currentIndex = -1
    Keys.onReturnPressed: root.acceptCurrent()
    Keys.onEnterPressed: root.acceptCurrent()

    ScrollBar.vertical: MScrollBar { flickable: view }

    model: FolderListModel {
      id: folderModel
      folder: "file://" + root.dialog.path.split("/").map(encodeURIComponent).join("/")
      showDirsFirst: true
      showHidden: false
      showDotAndDotDot: false
      sortCaseSensitive: false
      onFolderChanged: view.currentIndex = -1
    }

    delegate: FileEntry {}

    add: Transition {
      Anim { properties: "opacity,scale"; from: 0; to: 1 }
    }

    remove: Transition {
      Anim { type: "effects"; property: "opacity"; to: 0 }
      Anim { property: "scale"; to: 0.5 }
    }

    displaced: Transition {
      Anim { type: "effects"; properties: "opacity,scale"; to: 1; easing.bezierCurve: Tk.curves.standardDecel }
      Anim { properties: "x,y" }
    }
  }

  FileDialogCurrent {
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.margins: Tk.padding.extraSmall

    currentItem: view.currentItem
  }

  function acceptCurrent() {
    if (dialog.selectionValid) dialog.accepted(view.currentItem.file.path)
  }

  readonly property var xdgDirs: ["Desktop", "Documents", "Downloads", "Music", "Pictures", "Public", "Templates", "Videos"]

  component FileEntry: Rectangle {
    id: item

    required property int index
    required property string fileName
    required property string filePath
    required property url fileUrl
    required property bool fileIsDir
    required property string fileSuffix

    readonly property var file: ({
      name: fileName,
      path: filePath,
      isDir: fileIsDir,
      suffix: fileSuffix,
      isImage: !fileIsDir && root.dialog.imageSuffixes.includes(fileSuffix.toLowerCase())
    })

    readonly property real nonAnimHeight: icon.height + name.anchors.topMargin + name.implicitHeight + Tk.padding.medium * 2

    implicitWidth: root.dialog.itemWidth
    implicitHeight: nonAnimHeight
    width: implicitWidth
    height: implicitHeight

    radius: Tk.rounding.large
    color: Qt.alpha(Colours.m3surfaceContainerHighest, GridView.isCurrentItem ? Colours.m3surfaceContainerHighest.a : 0)
    z: GridView.isCurrentItem || implicitHeight !== nonAnimHeight ? 1 : 0
    clip: true

    StateLayer {
      onClicked: {
        view.currentIndex = item.index
        view.forceActiveFocus()
      }
      onDoubleClicked: {
        if (item.fileIsDir)
          root.dialog.cwd = root.dialog.cwd.concat([item.fileName])
        else
          root.acceptCurrent()
      }
    }

    Image {
      id: icon

      readonly property int implicitSize: root.dialog.itemWidth - Tk.padding.medium * 2

      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      anchors.topMargin: Tk.padding.medium

      width: implicitSize
      height: implicitSize
      sourceSize.width: implicitSize
      sourceSize.height: implicitSize
      fillMode: Image.PreserveAspectFit
      asynchronous: true
      smooth: true

      source: {
        const file = item.file
        if (file.isImage) return item.fileUrl
        if (!file.isDir) return Quickshell.iconPath("text-x-generic", "application-x-zerosize")
        if (root.dialog.cwd.length === 1 && root.xdgDirs.includes(file.name))
          return Quickshell.iconPath("folder-" + file.name.toLowerCase(), "inode-directory")
        return Quickshell.iconPath("inode-directory", "folder")
      }
    }

    MText {
      id: name

      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: icon.bottom
      anchors.topMargin: Tk.spacing.small
      anchors.leftMargin: Tk.padding.medium
      anchors.rightMargin: Tk.padding.medium

      horizontalAlignment: Text.AlignHCenter
      elide: item.GridView.isCurrentItem ? Text.ElideNone : Text.ElideRight
      wrapMode: item.GridView.isCurrentItem ? Text.WrapAtWordBoundaryOrAnywhere : Text.NoWrap
      text: item.fileName
    }

    Behavior on implicitHeight { Anim {} }
  }
}
