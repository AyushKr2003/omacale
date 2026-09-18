pragma Singleton
import QtQuick

// Caelestia's design tokens (plugin/src/Caelestia/Config/tokens.hpp and
// appearanceconfig.hpp), verbatim. Font sizes are point sizes, as in Caelestia.
QtObject {
  readonly property QtObject rounding: QtObject {
    readonly property int extraSmall: 4
    readonly property int small: 8
    readonly property int medium: 12
    readonly property int large: 16
    readonly property int largeIncreased: 20
    readonly property int extraLarge: 28
    readonly property int extraLargeIncreased: 32
    readonly property int extraExtraLarge: 48
    readonly property int full: 1000
  }
  readonly property QtObject spacing: QtObject {
    readonly property int extraSmall: 4
    readonly property int small: 8
    readonly property int medium: 12
    readonly property int large: 16
    readonly property int largeIncreased: 20
    readonly property int extraLarge: 28
    readonly property int extraLargeIncreased: 32
  }
  readonly property QtObject padding: QtObject {
    readonly property int extraSmall: 4
    readonly property int small: 8
    readonly property int medium: 12
    readonly property int large: 16
    readonly property int largeIncreased: 20
    readonly property int extraLarge: 28
    readonly property int extraLargeIncreased: 32
  }

  // Families (bundled fonts are loaded by Bar.qml).
  readonly property string sans: "Google Sans Flex"
  readonly property string clock: "Rubik"
  readonly property string icon: "Material Symbols Rounded"
  readonly property string mono: "JetBrainsMono Nerd Font"

  // Type scale (pt)
  readonly property QtObject headline: QtObject { readonly property int large: 32; readonly property int medium: 28; readonly property int small: 24 }
  readonly property QtObject title: QtObject { readonly property int large: 22; readonly property int medium: 16; readonly property int small: 14 }
  readonly property QtObject body: QtObject { readonly property int large: 16; readonly property int medium: 14; readonly property int small: 12 }
  readonly property QtObject label: QtObject { readonly property int large: 14; readonly property int medium: 12; readonly property int small: 11 }
  readonly property QtObject iconSize: QtObject {
    readonly property int extraLarge: 36
    readonly property int large: 24
    readonly property int medium: 18
    readonly property int small: 15
  }

  // Frame / bar
  readonly property int border: 10
  readonly property int borderRounding: 25
  readonly property int smoothing: 20
  readonly property int barInner: 40
  readonly property int barWidth: barInner + 2 * Math.max(padding.small, border)

  // Sizes
  readonly property QtObject sizes: QtObject {
    readonly property int audioWidth: 320
    readonly property int networkWidth: 320
    readonly property int batteryWidth: 250
    readonly property int bluetoothWidth: 300
    readonly property int trayMenuWidth: 300
    readonly property int userWidth: 340
    readonly property int logoSize: 30
    readonly property int uptimeSize: 30
    readonly property int dateTimeWidth: 110
    readonly property int mediaWidth: 200
    readonly property int mediaProgressSweep: 180
    readonly property int mediaProgressThickness: 6
    readonly property int resourceProgressThickness: 6
    readonly property int weatherWidth: 275
    readonly property int launcherItemWidth: 600
    readonly property int launcherItemHeight: 57
    readonly property int launcherMaxShown: 7
    readonly property int sessionButton: 80
    readonly property int tabIndicatorHeight: 3
    readonly property int tabIndicatorSpacing: 5
  }

  // Motion
  readonly property QtObject curves: QtObject {
    readonly property var emphasized: [0.05, 0, 2 / 15, 0.06, 1 / 6, 0.4, 5 / 24, 0.82, 0.25, 1, 1, 1]
    readonly property var emphasizedAccel: [0.3, 0, 0.8, 0.15, 1, 1]
    readonly property var emphasizedDecel: [0.05, 0.7, 0.1, 1, 1, 1]
    readonly property var standard: [0.2, 0, 0, 1, 1, 1]
    readonly property var standardAccel: [0.3, 0, 1, 1, 1, 1]
    readonly property var standardDecel: [0, 0, 0, 1, 1, 1]
    readonly property var fastSpatial: [0.42, 1.67, 0.21, 0.9, 1, 1]
    readonly property var defaultSpatial: [0.38, 1.21, 0.22, 1, 1, 1]
    readonly property var slowSpatial: [0.39, 1.29, 0.35, 0.98, 1, 1]
    readonly property var fastEffects: [0.31, 0.94, 0.34, 1, 1, 1]
    readonly property var defaultEffects: [0.34, 0.8, 0.34, 1, 1, 1]
    readonly property var slowEffects: [0.34, 0.88, 0.34, 1, 1, 1]
  }
  readonly property QtObject durations: QtObject {
    readonly property int small: 200
    readonly property int normal: 400
    readonly property int large: 600
    readonly property int extraLarge: 1000
    readonly property int fastSpatial: 350
    readonly property int defaultSpatial: 500
    readonly property int slowSpatial: 650
    readonly property int fastEffects: 150
    readonly property int defaultEffects: 200
    readonly property int slowEffects: 300
  }
}
