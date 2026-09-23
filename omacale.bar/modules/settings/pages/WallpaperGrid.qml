import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import "../../.."

// Settings › Wallpaper & style › Wallpapers / Themes. Port of Caelestia's
// nexus wallandstyle/WallpaperSelect.qml and common/WallItem.qml: a grid of
// square thumbnails with a label under each. The lists are the ones Omarchy's
// own pickers show (Wallpapers service); `row.themes` switches to themes.
ColumnLayout {
  id: root
  property var row
  property var settings
  property bool first
  property bool last

  readonly property bool themes: !!(row && row.themes)
  readonly property var items: themes ? Wallpapers.themes : Wallpapers.walls
  readonly property string current: themes ? Wallpapers.currentTheme : Wallpapers.currentWall
  // Caelestia nexus.wallpapersPerRow
  readonly property int perRow: 4

  spacing: Tk.spacing.small
  Component.onCompleted: Wallpapers.reload()

  ButtonRow {
    Layout.alignment: Qt.AlignHCenter
    Layout.bottomMargin: Tk.spacing.medium
    implicitWidth: randomBtn.implicitWidth
    IconTextButton {
      id: randomBtn
      icon: "shuffle"
      text: "Random"
      type: "tonal"
      shapeMorph: true
      fontSize: Tk.body.large
      horizontalPadding: Tk.padding.extraLarge
      verticalPadding: Tk.padding.medium
      disabled: root.items.length < 2
      onClicked: {
        const others = root.items.filter(i => i.key !== root.current)
        root.pick(others[Math.floor(Math.random() * others.length)])
      }
    }
  }

  function pick(item) {
    if (!item) return
    if (themes) Wallpapers.setTheme(item.key)
    else Wallpapers.setWallpaper(item.key)
    settings.back()
  }

  MText {
    Layout.topMargin: Tk.spacing.large
    text: root.themes ? "Omarchy themes" : "Theme backgrounds"
    font.pointSize: Tk.title.small
  }

  GridLayout {
    Layout.fillWidth: true
    visible: root.items.length > 0
    columns: root.perRow
    rowSpacing: Tk.spacing.medium
    columnSpacing: Tk.spacing.large

    Repeater {
      // Pad short lists so a lone item keeps a column's width.
      model: {
        const l = root.items.slice()
        while (l.length < root.perRow) l.push(null)
        return l
      }

      Item {
        id: wi
        required property var modelData
        readonly property bool isCurrent: !!modelData && modelData.key === root.current
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: wl.implicitHeight
        opacity: modelData ? 1 : 0
        enabled: !!modelData

        ColumnLayout {
          id: wl
          anchors.left: parent.left
          anchors.right: parent.right
          spacing: Tk.spacing.small

          ClippingRectangle {
            id: thumb
            Layout.fillWidth: true
            implicitHeight: width
            radius: Tk.rounding.largeIncreased
            color: Colours.m3surfaceContainer
            border.width: wi.isCurrent ? 3 : 0
            border.color: Colours.m3primary

            Rectangle {
              anchors.centerIn: parent
              implicitWidth: ld.implicitWidth + Tk.padding.large * 2
              implicitHeight: implicitWidth
              radius: width / 2
              color: Colours.m3primaryContainer
              opacity: im.status === Image.Ready || !wi.modelData || !wi.modelData.thumb ? 0 : 1
              visible: opacity > 0
              Behavior on opacity { Anim { type: "effects" } }
              LoadingIndicator { id: ld; anchors.centerIn: parent }
            }
            MIcon {
              anchors.centerIn: parent
              visible: !!wi.modelData && !wi.modelData.thumb
              text: root.themes ? "format_paint" : "image"
              size: Tk.iconSize.extraLarge
              color: Colours.m3outline
            }
            Image {
              id: im
              anchors.fill: parent
              source: wi.modelData ? Wallpapers.url(wi.modelData.thumb) : ""
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              retainWhileLoading: true
              sourceSize.width: thumb.width * 2
              sourceSize.height: thumb.height * 2
              opacity: status === Image.Ready ? 1 : 0
              Behavior on opacity { Anim { type: "slowEffects" } }
            }
          }
          MText {
            Layout.fillWidth: true
            Layout.bottomMargin: Tk.padding.small
            text: wi.modelData ? wi.modelData.label : ""
            color: wi.isCurrent ? Colours.m3primary : Colours.m3onSurfaceVariant
            font.pointSize: Tk.label.small
            weight: Font.Medium
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
          }
        }
        StateLayer {
          anchors.bottomMargin: wl.implicitHeight - thumb.height
          radius: Tk.rounding.largeIncreased
          onClicked: root.pick(wi.modelData)
        }
      }
    }
  }

  // Empty state
  Rectangle {
    Layout.fillWidth: true
    visible: root.items.length === 0
    color: Colours.m3surfaceContainer
    radius: Tk.rounding.extraLarge
    implicitHeight: empty.implicitHeight + Tk.padding.extraExtraLarge * 2
    ColumnLayout {
      id: empty
      anchors.centerIn: parent
      spacing: Tk.spacing.extraSmall
      MIcon { Layout.alignment: Qt.AlignHCenter; text: "hide_image"; color: Colours.m3outline; size: Tk.iconSize.extraLarge }
      MText { Layout.alignment: Qt.AlignHCenter; text: root.themes ? "No themes found" : "No backgrounds for this theme"; color: Colours.m3outline; font.pointSize: Tk.title.small }
    }
  }
}
