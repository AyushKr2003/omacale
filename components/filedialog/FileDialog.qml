pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import "../.."

// Caelestia components/filedialog/FileDialog.qml: the shell's own file
// picker, a QML window over Qt's FolderListModel, in place of QtQuick.Dialogs.
//
// Never the native dialog: Omarchy exports QT_QPA_PLATFORMTHEME=gtk3, so Qt
// builds GTK3's file chooser *inside the shell process*, and any fatal in
// GTK, GVfs or GLib (issue #5: a GLib abort in GtkPlacesView's synchronous
// GVfs call) takes the bar, notifications, OSD and lock IPC down with it.
// Nothing here goes near GTK or GIO: the listing is QDir plus inotify, the
// thumbnails are QImageReader.
//
// The window is fixed-size, which Hyprland takes as a dialog and floats
// (min == max size), so it never lands tiled in the user's layout and needs
// no window rule.
LazyLoader {
  id: loader

  property var cwd: ["Home"]
  property string filterLabel: "All files"
  property var filters: ["*"]
  property string title: "Select a file"
  // Caelestia's Images.validImageExtensions, as far as Qt's image plugins read
  // them: shown as thumbnails, and the filter for picking an image.
  readonly property var imageSuffixes: ["png", "jpg", "jpeg", "webp", "bmp", "gif", "svg", "tif", "tiff", "avif", "jxl"]

  signal accepted(string path)
  signal rejected()

  function open() {
    activeAsync = true
  }

  function close() {
    rejected()
  }

  onAccepted: activeAsync = false
  onRejected: activeAsync = false

  FloatingWindow {
    id: root

    // Always reassigned, never pushed: a var array doesn't notify in place.
    property var cwd: loader.cwd.slice()
    readonly property string filterLabel: loader.filterLabel
    readonly property var filters: loader.filters
    readonly property var imageSuffixes: loader.imageSuffixes

    // Caelestia filedialog/Sizes.qml.
    readonly property int itemWidth: Tk.px(103)
    readonly property int sidebarWidth: Tk.px(230)

    readonly property bool selectionValid: {
      const file = folderContents.currentItem ? folderContents.currentItem.file : null
      if (!file || file.isDir) return false
      return filters.includes("*") || filters.some(f => f.toLowerCase() === file.suffix.toLowerCase())
    }

    // Caelestia's Paths.home with cwd[0] "Home"; anything else is absolute.
    readonly property string path: {
      const home = Quickshell.env("HOME")
      return cwd[0] === "Home" ? [home].concat(cwd.slice(1)).join("/") : cwd.join("/")
    }

    function accepted(path) {
      loader.accepted(path)
    }

    function rejected() {
      loader.rejected()
    }

    readonly property int fixedW: Math.min(Tk.px(1000), Math.round((screen ? screen.width : 1920) * 0.9))
    readonly property int fixedH: Math.min(Tk.px(600), Math.round((screen ? screen.height : 1080) * 0.9))

    implicitWidth: fixedW
    implicitHeight: fixedH
    minimumSize.width: fixedW
    minimumSize.height: fixedH
    maximumSize.width: fixedW
    maximumSize.height: fixedH
    color: Colours.m3surface
    surfaceFormat.opaque: false
    title: loader.title

    onVisibleChanged: if (!visible) rejected()

    RowLayout {
      anchors.fill: parent
      spacing: 0

      FileDialogSidebar {
        Layout.fillHeight: true
        dialog: root
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 0

        FileDialogHeader {
          Layout.fillWidth: true
          dialog: root
        }

        FolderContents {
          id: folderContents
          Layout.fillWidth: true
          Layout.fillHeight: true
          dialog: root
        }

        FileDialogButtons {
          Layout.fillWidth: true
          dialog: root
          folder: folderContents
        }
      }
    }

    Behavior on color { CAnim {} }
  }
}
