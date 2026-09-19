import QtQuick
import QtQuick.Layouts
import "Logos.js" as Logos

// Bar logo picker: a grid of simple icons, styled like SeedPicker's swatches
// (the selected one squares off with a ring). Idea from Shibumi-Shell's
// LogoSettingsPage, limited to plain single-colour marks.
ConnectedRect {
  id: root
  property var settings
  property var row
  readonly property string current: Config.o.bar.logoIcon || "omarchy"

  implicitHeight: col.implicitHeight + Tk.padding.largeIncreased * 2
  opacity: Config.o.bar.logo ? 1 : 0.5
  Behavior on opacity { Anim {} }

  ColumnLayout {
    id: col
    anchors.fill: parent
    anchors.margins: Tk.padding.largeIncreased
    spacing: Tk.spacing.large

    RowLayout {
      Layout.fillWidth: true
      spacing: Tk.spacing.medium
      RowLabel {
        Layout.fillWidth: true
        text: "Logo icon"
        subtext: Logos.byId(root.current).label + (Config.o.bar.logo ? "" : " · turn on Logo to show it")
      }
      LogoIcon { value: root.current; size: Tk.iconSize.large; colour: Colours.m3tertiary }
    }

    Flow {
      Layout.fillWidth: true
      spacing: Tk.spacing.small
      Repeater {
        model: Logos.options
        Item {
          id: tile
          required property var modelData
          readonly property bool selected: root.current === modelData.id
          width: 64; height: 70
          Rectangle {
            id: ring
            anchors.horizontalCenter: parent.horizontalCenter
            width: 48; height: 48
            radius: tile.selected ? Tk.rounding.medium : width / 2
            color: tile.selected ? Colours.m3primaryContainer : Colours.m3surfaceContainerHighest
            border.width: tile.selected ? 2 : 0
            border.color: Colours.m3primary
            Behavior on radius { Anim {} }
            Behavior on color { CAnim {} }
            StateLayer { color: tile.selected ? Colours.m3onPrimaryContainer : Colours.m3onSurface; onClicked: Config.set("bar.logoIcon", tile.modelData.id) }
            LogoIcon {
              anchors.centerIn: parent
              value: tile.modelData.id
              size: Tk.iconSize.large
              colour: tile.selected ? Colours.m3onPrimaryContainer : Colours.m3onSurfaceVariant
            }
          }
          MText {
            anchors.top: ring.bottom
            anchors.topMargin: 3
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: tile.modelData.label
            font.pointSize: Tk.label.small
            elide: Text.ElideRight
            color: tile.selected ? Colours.m3primary : Colours.m3onSurfaceVariant
          }
        }
      }
    }
  }
}
