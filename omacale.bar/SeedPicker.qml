import QtQuick
import QtQuick.Layouts
import qs.Commons

// Seed colour: the Omarchy theme accent (default), any colour of the current
// theme, or a hex value. Below it, the generated M3 palette.
ConnectedRect {
  id: root
  property var settings
  property var row
  first: true
  readonly property string seed: Config.o.appearance.seed
  implicitHeight: col.implicitHeight + Tk.padding.largeIncreased * 2

  ColumnLayout {
    id: col
    anchors.fill: parent
    anchors.margins: Tk.padding.largeIncreased
    spacing: Tk.spacing.large

    RowLayout {
      Layout.fillWidth: true
      RowLabel {
        Layout.fillWidth: true
        text: "Seed colour"
        subtext: root.seed === "" ? "Following the Omarchy theme accent" : "Custom " + root.seed.toUpperCase()
      }
      Rectangle {
        width: 132; height: 36; radius: height / 2
        color: Colours.m3surfaceContainerHighest
        border.width: hex.activeFocus ? 2 : 0
        border.color: Colours.m3primary
        Row {
          anchors.fill: parent
          anchors.leftMargin: Tk.padding.medium
          spacing: Tk.spacing.small
          MIcon { anchors.verticalCenter: parent.verticalCenter; text: "tag"; size: Tk.iconSize.small; color: Colours.m3onSurfaceVariant }
          MTextField {
            id: hex
            anchors.verticalCenter: parent.verticalCenter
            width: 80
            text: root.seed.replace("#", "")
            maximumLength: 6
            font.family: Tk.mono; font.pointSize: Tk.body.small
            validator: RegularExpressionValidator { regularExpression: /[0-9a-fA-F]{0,6}/ }
            onEditingFinished: Config.set("appearance.seed", text.length === 6 ? "#" + text.toLowerCase() : "")
            MText { visible: !hex.text; text: "auto"; color: Colours.m3outline; anchors.verticalCenter: parent.verticalCenter }
          }
        }
      }
    }

    Flow {
      Layout.fillWidth: true
      spacing: Tk.spacing.medium
      Swatch { colour: Color.accent; value: ""; label: "Theme"; icon: "auto_awesome" }
      Repeater {
        model: Colours.themeSwatches
        Swatch { required property var modelData; colour: modelData.color; value: modelData.color.toLowerCase(); label: modelData.name }
      }
    }

    // Generated palette
    RowLayout {
      Layout.fillWidth: true
      spacing: 2
      Repeater {
        model: [
          { c: Colours.m3primary, on: Colours.m3onPrimary, n: "Primary" },
          { c: Colours.m3primaryContainer, on: Colours.m3onPrimaryContainer, n: "Container" },
          { c: Colours.m3secondary, on: Colours.m3onSecondary, n: "Secondary" },
          { c: Colours.m3tertiary, on: Colours.m3onTertiary, n: "Tertiary" },
          { c: Colours.m3surfaceContainerHighest, on: Colours.m3onSurface, n: "Surface" },
          { c: Colours.m3error, on: Colours.m3onError, n: "Error" }
        ]
        Rectangle {
          required property var modelData
          required property int index
          Layout.fillWidth: true
          implicitHeight: 44
          color: modelData.c
          topLeftRadius: index === 0 ? height / 2 : Tk.rounding.extraSmall
          bottomLeftRadius: topLeftRadius
          topRightRadius: index === 5 ? height / 2 : Tk.rounding.extraSmall
          bottomRightRadius: topRightRadius
          Behavior on color { CAnim {} }
          MText { anchors.centerIn: parent; text: parent.modelData.n; color: parent.modelData.on; font.pointSize: Tk.label.small; weight: Font.Medium }
        }
      }
    }
  }

  component Swatch: Item {
    id: sw
    property color colour
    property string value
    property string label
    property string icon: ""
    readonly property bool selected: root.seed.toLowerCase() === value
    width: 56; height: 62
    Rectangle {
      id: ring
      anchors.horizontalCenter: parent.horizontalCenter
      width: 44; height: 44
      radius: sw.selected ? Tk.rounding.medium : width / 2
      color: "transparent"
      border.width: sw.selected ? 2 : 0
      border.color: Colours.m3primary
      Behavior on radius { Anim {} }
      Rectangle {
        anchors.centerIn: parent
        width: sw.selected ? 32 : 40; height: width
        radius: sw.selected ? Tk.rounding.small : width / 2
        color: sw.colour
        Behavior on width { Anim {} }
        Behavior on radius { Anim {} }
        MIcon {
          anchors.centerIn: parent
          visible: sw.selected || sw.icon !== ""
          text: sw.selected ? "check" : sw.icon
          size: Tk.iconSize.small
          weight: 700
          color: Qt.color(sw.colour).hslLightness > 0.55 ? "#1a1a1a" : "#ffffff"
        }
      }
      MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Config.set("appearance.seed", sw.value) }
    }
    MText {
      anchors.top: ring.bottom
      anchors.topMargin: 2
      anchors.horizontalCenter: parent.horizontalCenter
      text: sw.label
      font.pointSize: Tk.label.small
      color: sw.selected ? Colours.m3primary : Colours.m3onSurfaceVariant
    }
  }
}
