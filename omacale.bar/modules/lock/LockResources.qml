import QtQuick
import QtQuick.Layouts
import "../.."

// CPU, memory and disk across the top right of the lock (Caelestia
// lock/Resources.qml): three Material shapes filled to their usage behind a
// wavy surface, with the CPU temperature riding on the corner of the first.
Rectangle {
  id: root

  // Caelestia scales the type off how far the card is from its width on a
  // 1080p screen, so the numbers stay readable on a small panel and grow on
  // a large one.
  readonly property real fontScale: {
    if (width <= 0)
      return 1 // The card has no width on its first frame, and Qt refuses a zero point size
    const diff = width / 391 - 1
    return Math.max(0.3, 1 + Math.pow(Math.abs(diff), 0.8) * Math.sign(diff))
  }

  // Sys only polls while something is showing the numbers.
  Component.onCompleted: Sys.resourcesWanted += 1
  Component.onDestruction: Sys.resourcesWanted -= 1

  implicitHeight: layout.implicitHeight + Tk.padding.large * 2
  radius: Tk.rounding.extraLarge
  color: Colours.m3surfaceContainer

  RowLayout {
    id: layout

    anchors.fill: parent
    anchors.margins: Tk.padding.large
    spacing: Tk.spacing.large

    Resource {
      id: cpu

      icon: "memory"
      value: Sys.cpu
      colour: Colours.m3primary
      shapeColour: Colours.m3primaryContainer
      fillColour: Qt.alpha(Colours.m3secondary, 0.3)
      shape: "pentagon"

      MShape {
        readonly property bool hot: Sys.cpuTemp > 90

        x: cpu.width * 0.78 - implicitSize / 2 + Tk.padding.medium
        y: cpu.width * 0.22 - implicitSize / 2

        shape: hot ? "softBurst" : "circle"
        color: hot ? Colours.m3errorContainer : Colours.m3secondaryContainer
        visible: Sys.cpuTemp > 0
        implicitSize: {
          const size = Math.round(tempLabel.implicitHeight * 2)
          return size % 2 === 0 ? size : size + 1 // Even, so the centre lands on a pixel
        }

        MText {
          id: tempLabel

          anchors.centerIn: parent
          text: `${Math.round(Sys.cpuTemp)}°`
          color: parent.hot ? Colours.m3onErrorContainer : Colours.m3secondary
          font.pointSize: Tk.title.medium * Math.max(0.6, cpu.width / 112)
          weight: Font.Medium
          axes: ({ "ROND": 25, "wdth": 50 })
        }
      }
    }

    Resource {
      icon: "memory_alt"
      value: Sys.mem
      colour: Colours.m3tertiary
      shapeColour: Colours.m3onTertiary
      fillColour: Qt.alpha(Colours.m3tertiary, 0.3)
      shape: "slanted"
    }

    Resource {
      icon: "hard_disk"
      value: Sys.disk
      colour: Colours.m3secondary
      shapeColour: Colours.m3secondaryContainer
      fillColour: Qt.alpha(Colours.m3secondary, 0.4)
      shape: "gem"
    }
  }

  component Resource: Item {
    id: res

    required property string icon
    required property color colour
    required property color shapeColour
    property color fillColour
    property real value: 0
    property alias shape: shape.shape

    // Plain, not readonly: a Behavior on a readonly property is a load error.
    property real fillValue: Math.max(0, Math.min(1, value))

    Layout.fillWidth: true
    implicitHeight: width

    Behavior on fillValue {
      Anim {}
    }

    MShape {
      id: shape

      implicitSize: res.width
      color: res.shapeColour
    }

    // The fill is a wavy-topped rect clipped to the shape, as Caelestia fills
    // its resource shapes.
    Item {
      anchors.fill: shape
      layer.enabled: true
      layer.effect: ShaderMaskEffect {
        maskItem: shape
      }

      Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: shape.implicitSize * res.fillValue

        Rectangle {
          anchors.fill: parent
          anchors.topMargin: wave.height / 2
          color: res.fillColour
        }

        WavyLine {
          id: wave

          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          lineWidth: Math.max(3, shape.implicitSize / 22)
          frequency: 3
          color: res.fillColour
          running: res.fillValue > 0
        }
      }
    }

    ColumnLayout {
      anchors.centerIn: parent
      spacing: -Tk.spacing.extraSmall

      MIcon {
        Layout.alignment: Qt.AlignHCenter
        text: res.icon
        color: Colours.m3secondary
        size: Tk.iconSize.medium * root.fontScale
      }

      MText {
        Layout.alignment: Qt.AlignHCenter
        text: `${(res.value * 100).toFixed(1)}%`
        color: res.colour
        font.pointSize: Tk.headline.large * root.fontScale
        axes: ({ "ROND": 25, "wdth": 50 })
      }
    }
  }
}
