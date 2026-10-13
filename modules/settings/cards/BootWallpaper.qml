import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import "../../.."

// Settings › Boot menu › Picture: an image behind Limine's menu, picked with
// Omacale's own FileDialog (Settings.fileRequested), as Session › Picture.
// Under it, the current theme's backgrounds (the Wallpapers service, what
// Omarchy's own picker lists) as thumbnails to pick with one click.
// Only the path is kept here; Apply copies the file onto the boot partition
// (Limine can't read anything else).
ConnectedRect {
  id: root
  property var row
  property var settings
  property bool first
  property bool last

  readonly property string path: Config.o.boot.wallpaper
  // Limine reads PNG, JPEG, BMP and QOI; a theme's videos and WebPs can't go.
  readonly property var walls: Wallpapers.walls.filter(w => /\.(png|jpe?g|bmp)$/i.test(w.key))
  implicitHeight: body.implicitHeight + Tk.padding.medium * 2
  Component.onCompleted: Wallpapers.reload()

  function pick(p) {
    Config.set("boot.wallpaper", p)
    // Over a picture an opaque text background would hide it: start
    // half see-through, as Limine's own default with a wallpaper.
    if (Config.o.boot.backgroundAlpha === 0) Config.set("boot.backgroundAlpha", 50)
  }

  ColumnLayout {
    id: body
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: Tk.padding.largeIncreased
    anchors.rightMargin: Tk.padding.medium
    spacing: Tk.spacing.medium

    RowLayout {
      id: rl
      Layout.fillWidth: true
      spacing: Tk.spacing.medium
      Rectangle {
        Layout.preferredWidth: Tk.iconSize.large * 2
        Layout.preferredHeight: Math.round(Layout.preferredWidth * 9 / 16)
        radius: Tk.rounding.extraSmall
        color: Colours.m3surfaceContainerHighest
        clip: true
        Image {
          anchors.fill: parent
          visible: root.path !== ""
          source: root.path ? "file://" + root.path : ""
          fillMode: Image.PreserveAspectCrop
          sourceSize.width: 256
          asynchronous: true
        }
        MIcon { anchors.centerIn: parent; visible: root.path === ""; text: "hide_image"; color: Colours.m3onSurfaceVariant }
      }
      RowLabel {
        Layout.fillWidth: true
        text: "Picture"
        subtext: root.path ? root.path.slice(root.path.lastIndexOf("/") + 1) + " · copied to the boot partition when you apply"
          : "None: the background colour fills the screen. PNG, JPEG or BMP, up to 16 MB"
      }
      IconButton {
        visible: root.path !== ""
        type: "text"
        icon: "close"
        onClicked: Config.set("boot.wallpaper", "")
      }
      IconButton {
        type: "tonal"
        icon: "folder_open"
        onClicked: root.settings.fileRequested("Select a boot menu picture", ["png", "jpg", "jpeg", "bmp"], p => root.pick(p))
      }
    }

    MText {
      visible: root.walls.length > 0
      text: "Your theme's wallpapers"
      font.pointSize: Tk.label.large
      color: Colours.m3onSurfaceVariant
    }
    Flow {
      Layout.fillWidth: true
      Layout.rightMargin: Tk.padding.medium
      Layout.bottomMargin: Tk.padding.small
      visible: root.walls.length > 0
      spacing: Tk.spacing.small
      Repeater {
        model: root.walls
        ClippingRectangle {
          id: wt
          required property var modelData
          readonly property bool isCurrent: modelData.key === root.path
          width: Tk.px(128)
          height: Math.round(width * 9 / 16)
          radius: Tk.rounding.small
          color: Colours.m3surfaceContainerHighest
          Image {
            anchors.fill: parent
            source: Wallpapers.url(wt.modelData.thumb || wt.modelData.key)
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: wt.width * 2
            asynchronous: true
          }
          Rectangle {
            anchors.fill: parent
            radius: wt.radius
            color: "transparent"
            border.width: wt.isCurrent ? 3 : 0
            border.color: Colours.m3primary
          }
          MIcon {
            visible: wt.isCurrent
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Tk.padding.small
            text: "check_circle"
            fill: 1
            color: Colours.m3primary
          }
          StateLayer {
            onClicked: root.pick(wt.modelData.key)
          }
        }
      }
    }
  }
}
