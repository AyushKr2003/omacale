import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import "../.."

// The fetch card (Caelestia lock/Fetch.qml): a fake shell prompt over a
// neofetch-style block, with the distro logo beside it and a row of palette
// swatches under it. Lines drop out as the card gets shorter, in Caelestia's
// order, so a laptop keeps its battery line and a 1080p screen loses "OS".
//
// Caelestia's swatch row is the terminal palette; Omacale has no terminal
// colours of its own, so it shows the scheme's accents instead.
Rectangle {
  id: root

  required property real rootHeight

  readonly property int cBoxSize: Tk.body.medium * 2
  readonly property bool bigFont: width > Tk.sizes.lockLargeFontWidth
  readonly property bool sideLogo: width > Tk.sizes.lockLargeLogoWidth
  readonly property bool showSwatches: rootHeight > Tk.sizes.lockColourRowHeight

  readonly property var dev: UPower.displayDevice
  readonly property bool battery: dev && dev.isLaptopBattery

  implicitHeight: layout.implicitHeight + Tk.padding.extraLarge * 2
  radius: Tk.rounding.medium
  color: Colours.m3surfaceContainer

  ColumnLayout {
    id: layout

    anchors.fill: parent
    anchors.margins: Tk.padding.extraLarge

    spacing: Tk.spacing.small

    RowLayout {
      Layout.fillWidth: true
      Layout.fillHeight: false
      spacing: Tk.spacing.medium

      Rectangle {
        implicitWidth: prompt.implicitWidth + Tk.padding.medium * 2
        implicitHeight: prompt.implicitHeight + Tk.padding.small * 2

        color: Colours.m3primary
        radius: Tk.rounding.medium

        MText {
          id: prompt

          anchors.centerIn: parent
          text: ">"
          color: Colours.m3onPrimary
          font.family: Tk.mono
          font.pointSize: root.bigFont ? Tk.body.medium : Tk.body.small
        }
      }

      MText {
        Layout.fillWidth: true
        text: "omacalefetch.sh"
        font.family: Tk.mono
        font.pointSize: root.bigFont ? Tk.body.medium : Tk.body.small
        elide: Text.ElideRight
      }

      LogoIcon {
        Layout.alignment: Qt.AlignVCenter
        visible: !root.sideLogo
        size: prompt.implicitHeight * 1.6
        value: Config.o.bar.logoIcon
        colour: Config.o.lock.recolourLogo ? Colours.m3primary : Colours.m3onSurface
      }
    }

    RowLayout {
      Layout.fillWidth: true
      Layout.fillHeight: true
      spacing: Tk.spacing.extraLarge

      LogoIcon {
        Layout.alignment: Qt.AlignVCenter
        visible: root.sideLogo
        size: Math.max(Tk.px(48), lines.implicitHeight)
        value: Config.o.bar.logoIcon
        colour: Config.o.lock.recolourLogo ? Colours.m3primary : Colours.m3onSurface
      }

      ColumnLayout {
        id: lines

        Layout.fillWidth: true
        Layout.topMargin: Tk.padding.medium
        Layout.bottomMargin: root.sideLogo || root.showSwatches ? Tk.padding.medium : 0
        spacing: Tk.spacing.medium

        Repeater {
          model: {
            const items = []
            const h = root.rootHeight

            if (!root.battery && h > Tk.sizes.lockFetch4LinesHeight)
              items.push(`OS  : ${Sys.osName}`)
            if (h > (root.battery ? Tk.sizes.lockFetch4LinesHeight : Tk.sizes.lockFetch3LinesHeight))
              items.push(`WM  : ${Sys.wm}`)
            if (!root.battery || h > Tk.sizes.lockFetch3LinesHeight)
              items.push(`USER: ${Sys.user}`)
            items.push(`UP  : ${Sys.uptime}`)
            if (root.battery) {
              const charging = [UPowerDeviceState.Charging, UPowerDeviceState.FullyCharged, UPowerDeviceState.PendingCharge].indexOf(root.dev.state) >= 0
              const pct = Math.round(root.dev.percentage * 100)
              items.push(charging ? `BATT: (+) ${pct}%` : `BATT: ${pct}%`)
            }

            return items
          }

          MText {
            required property string modelData

            Layout.fillWidth: true
            text: modelData
            font.family: Tk.mono
            font.pointSize: root.bigFont ? Tk.body.medium : Tk.body.small
            elide: Text.ElideRight
          }
        }
      }
    }

    Loader {
      Layout.topMargin: root.sideLogo ? Tk.spacing.small : 0
      Layout.alignment: Qt.AlignHCenter
      active: root.showSwatches
      visible: active
      asynchronous: true

      sourceComponent: RowLayout {
        id: swatches

        readonly property var colours: [Colours.m3primary, Colours.m3secondary, Colours.m3tertiary, Colours.m3error, Colours.m3primaryContainer, Colours.m3secondaryContainer, Colours.m3tertiaryContainer, Colours.m3errorContainer]

        spacing: Tk.spacing.largeIncreased

        Repeater {
          model: Math.max(0, Math.min(Math.floor((lines.width + swatches.spacing) / (root.cBoxSize + swatches.spacing)), 8))

          Rectangle {
            required property int index

            implicitWidth: implicitHeight
            implicitHeight: root.cBoxSize
            color: swatches.colours[index]
            radius: Tk.rounding.medium

            Behavior on color {
              CAnim {}
            }
          }
        }
      }
    }
  }
}
