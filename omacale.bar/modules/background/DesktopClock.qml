import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import "../.."

// Caelestia modules/background/DesktopClock.qml: hours : minutes, a divider,
// then month / day / weekday, on an optional plate with a drop shadow.
//
// One deliberate difference: Caelestia blurs the plate by sampling its own
// wallpaper item. Omarchy draws the wallpaper in another window, so the
// plate's blur is Hyprland's, on this window's layer (Bar.applyDesktopBlur),
// which costs Omacale no textures at all.
Item {
  id: root

  readonly property var cfg: Config.o.background.desktopClock

  property real clockScale: cfg.scale
  readonly property bool invertColors: cfg.invertColors
  readonly property bool useLightSet: Colours.light ? !invertColors : invertColors
  readonly property color safePrimary: useLightSet ? Colours.m3primaryContainer : Colours.m3primary
  readonly property color safeSecondary: useLightSet ? Colours.m3secondaryContainer : Colours.m3secondary
  readonly property color safeTertiary: useLightSet ? Colours.m3tertiaryContainer : Colours.m3tertiary
  readonly property real bigSize: Tk.headline.medium * 3 * clockScale

  implicitWidth: layout.implicitWidth + (Tk.padding.large * 4 * clockScale)
  implicitHeight: layout.implicitHeight + (Tk.padding.extraLargeIncreased * clockScale)

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  component ClockText: MText {
    property real size: Tk.body.large
    font.family: Tk.clock
    font.pointSize: size
    axes: ({})
  }

  Item {
    anchors.fill: parent

    layer.enabled: root.cfg.shadow.enabled && !GameMode.enabled
    layer.effect: MultiEffect {
      shadowEnabled: true
      shadowColor: Colours.m3shadow
      shadowOpacity: root.cfg.shadow.opacity
      shadowBlur: root.cfg.shadow.blur
    }

    Rectangle {
      visible: root.cfg.background.enabled
      anchors.fill: parent
      radius: Tk.rounding.extraLarge * root.clockScale
      opacity: root.cfg.background.opacity
      color: Colours.palette.m3surface
    }

    RowLayout {
      id: layout

      anchors.centerIn: parent
      spacing: Tk.spacing.large * root.clockScale

      RowLayout {
        spacing: Tk.spacing.small

        ClockText {
          text: Sys.hour(clock.date)
          size: root.bigSize
          weight: Font.Bold
          color: root.safePrimary
        }

        ClockText {
          text: ":"
          size: root.bigSize
          color: root.safeTertiary
          opacity: 0.8
          Layout.topMargin: -Tk.padding.large * 1.5 * root.clockScale
        }

        ClockText {
          text: Qt.formatTime(clock.date, "mm")
          size: root.bigSize
          weight: Font.Bold
          color: root.safeSecondary
        }

        ClockText {
          visible: Sys.h12
          Layout.alignment: Qt.AlignTop
          Layout.topMargin: Tk.padding.large * 1.4 * root.clockScale
          text: Qt.formatTime(clock.date, "AP")
          size: Tk.title.medium * root.clockScale
          color: root.safeSecondary
        }
      }

      Rectangle {
        Layout.fillHeight: true
        Layout.preferredWidth: Tk.px(4) * root.clockScale
        Layout.topMargin: Tk.spacing.large * root.clockScale
        Layout.bottomMargin: Tk.spacing.large * root.clockScale
        radius: Tk.rounding.full
        color: root.safePrimary
        opacity: 0.8
      }

      ColumnLayout {
        spacing: 0

        ClockText {
          text: Qt.formatDate(clock.date, "MMMM").toUpperCase()
          size: Tk.title.medium * root.clockScale
          font.letterSpacing: 4
          weight: Font.Bold
          color: root.safeSecondary
        }

        ClockText {
          text: Qt.formatDate(clock.date, "dd")
          size: Tk.headline.medium * root.clockScale
          font.letterSpacing: 2
          weight: Font.Medium
          color: root.safePrimary
        }

        ClockText {
          text: Qt.formatDate(clock.date, "dddd")
          size: Tk.body.large * root.clockScale
          font.letterSpacing: 2
          color: root.safeSecondary
        }
      }
    }
  }

  Behavior on clockScale { Anim {} }
  Behavior on implicitWidth { Anim { type: "standardSmall" } }
}
