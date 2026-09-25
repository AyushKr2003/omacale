pragma Singleton
import QtQuick
import qs.Commons
import ".."

// Caelestia's design tokens (plugin/src/Caelestia/Config/tokens.hpp and
// appearanceconfig.hpp), verbatim. Font sizes are point sizes, as in Caelestia.
// Every size goes through a scale (see "Scale" below); at 1x they are exact.
QtObject {
  id: tk

  // Scale. Caelestia's appearance.{font,padding,spacing,rounding}.scale
  // (appearanceconfig.cpp: token * scale, cast to int), under a master that
  // Omacale adds: Omarchy's own shell.toml scale by default ([font] base-size
  // / 12, and [spacing] scale for gaps), or the user's. Unlike Caelestia the
  // master also scales `sizes` and the bar, so a smaller UI gets narrower
  // drawers. Frame settings (border, rounding, smoothing) are user px and
  // don't scale.
  readonly property QtObject scaleCfg: Config.o.appearance.scale
  readonly property bool followOmarchy: scaleCfg.source !== "custom"
  // Reach-ins into Omarchy's Commons/Style.qml; 1.0 if they ever go away.
  readonly property real omarchyFont: ("fontScale" in Style) && isFinite(Style.fontScale) ? Style.fontScale : 1
  readonly property real omarchySpacing: ("spacingScale" in Style) && isFinite(Style.spacingScale) ? Style.spacingScale : 1
  readonly property real uiScale: clamp(followOmarchy ? omarchyFont : scaleCfg.ui, 0.5, 2)
  readonly property real fontScale: uiScale * clamp(scaleCfg.font, 0.25, 4)
  readonly property real padScale: uiScale * clamp(scaleCfg.padding, 0, 4) * (followOmarchy ? clamp(omarchySpacing, 0, 4) : 1)
  readonly property real spaceScale: uiScale * clamp(scaleCfg.spacing, 0, 4) * (followOmarchy ? clamp(omarchySpacing, 0, 4) : 1)
  readonly property real roundScale: uiScale * clamp(scaleCfg.rounding, 0, 4)

  function clamp(v, lo, hi) { return isFinite(v) ? Math.max(lo, Math.min(hi, v)) : 1 }
  // A size with no Caelestia token, at the UI scale.
  function px(n) { return Math.round(n * uiScale) }
  function font(n) { return Math.max(1, Math.round(n * fontScale)) }
  readonly property QtObject rounding: QtObject {
    readonly property int extraSmall: Math.round(4 * tk.roundScale)
    readonly property int small: Math.round(8 * tk.roundScale)
    readonly property int medium: Math.round(12 * tk.roundScale)
    readonly property int large: Math.round(16 * tk.roundScale)
    readonly property int largeIncreased: Math.round(20 * tk.roundScale)
    readonly property int extraLarge: Math.round(28 * tk.roundScale)
    readonly property int extraLargeIncreased: Math.round(32 * tk.roundScale)
    readonly property int extraExtraLarge: Math.round(48 * tk.roundScale)
    readonly property int full: 1000
  }
  readonly property QtObject spacing: QtObject {
    readonly property int extraSmall: Math.round(4 * tk.spaceScale)
    readonly property int small: Math.round(8 * tk.spaceScale)
    readonly property int medium: Math.round(12 * tk.spaceScale)
    readonly property int large: Math.round(16 * tk.spaceScale)
    readonly property int largeIncreased: Math.round(20 * tk.spaceScale)
    readonly property int extraLarge: Math.round(28 * tk.spaceScale)
    readonly property int extraLargeIncreased: Math.round(32 * tk.spaceScale)
  }
  readonly property QtObject padding: QtObject {
    readonly property int extraSmall: Math.round(4 * tk.padScale)
    readonly property int small: Math.round(8 * tk.padScale)
    readonly property int medium: Math.round(12 * tk.padScale)
    readonly property int large: Math.round(16 * tk.padScale)
    readonly property int largeIncreased: Math.round(20 * tk.padScale)
    readonly property int extraLarge: Math.round(28 * tk.padScale)
    readonly property int extraLargeIncreased: Math.round(32 * tk.padScale)
    readonly property int extraExtraLarge: Math.round(48 * tk.padScale)
  }

  // Families (bundled fonts are loaded by Bar.qml).
  readonly property string sans: "Google Sans Flex"
  readonly property string clock: "Rubik"
  readonly property string icon: "Material Symbols Rounded"
  readonly property string mono: "JetBrainsMono Nerd Font"

  // Type scale (pt)
  readonly property QtObject headline: QtObject { readonly property int large: tk.font(32); readonly property int medium: tk.font(28); readonly property int small: tk.font(24) }
  readonly property QtObject title: QtObject { readonly property int large: tk.font(22); readonly property int medium: tk.font(16); readonly property int small: tk.font(14) }
  readonly property QtObject body: QtObject { readonly property int large: tk.font(16); readonly property int medium: tk.font(14); readonly property int small: tk.font(12) }
  readonly property QtObject label: QtObject { readonly property int large: tk.font(14); readonly property int medium: tk.font(12); readonly property int small: tk.font(11) }
  readonly property QtObject iconSize: QtObject {
    readonly property int extraLarge: tk.font(36)
    readonly property int large: tk.font(24)
    readonly property int medium: tk.font(18)
    readonly property int small: tk.font(15)
  }

  // Frame / bar (user-configurable)
  readonly property int border: Config.o.border.thickness
  readonly property int borderRounding: Config.o.border.rounding
  readonly property int smoothing: Config.o.border.smoothing
  readonly property int barInner: px(40)
  readonly property int barWidth: barInner + 2 * Math.max(padding.small, border)

  // Sizes
  readonly property QtObject sizes: QtObject {
    readonly property int audioWidth: tk.px(320)
    readonly property int networkWidth: tk.px(320)
    readonly property int batteryWidth: tk.px(250)
    readonly property int bluetoothWidth: tk.px(300)
    readonly property int trayMenuWidth: tk.px(300)
    readonly property int kbLayoutWidth: tk.px(320)
    readonly property int windowPreviewSize: tk.px(400)
    // Caelestia WInfoTokens (tokens.hpp): the detached window info panel.
    readonly property real winfoHeightMult: 0.7
    readonly property int winfoDetailsWidth: tk.px(500)
    readonly property int userWidth: tk.px(340)
    readonly property int logoSize: tk.px(30)
    readonly property int uptimeSize: tk.px(30)
    readonly property int dateTimeWidth: tk.px(110)
    readonly property int mediaWidth: tk.px(200)
    readonly property int mediaProgressSweep: 180
    readonly property int mediaProgressThickness: tk.px(6)
    readonly property int resourceProgressThickness: tk.px(6)
    readonly property int weatherWidth: tk.px(275)
    readonly property int launcherItemWidth: tk.px(600)
    readonly property int launcherItemHeight: tk.px(57)
    readonly property int launcherMaxShown: 7
    readonly property int launcherWallpaperWidth: tk.px(280)
    readonly property int launcherWallpaperHeight: tk.px(200)
    readonly property int sessionButton: tk.px(80)
    readonly property int sidebarWidth: tk.px((Config.o.sidebar && Config.o.sidebar.width) ? Config.o.sidebar.width : 430)
    readonly property int utilitiesWidth: tk.px((Config.o.utilities && Config.o.utilities.width) ? Config.o.utilities.width : 430)
    readonly property int tabIndicatorHeight: tk.px(3)
    readonly property int tabIndicatorSpacing: tk.px(5)
    readonly property int notifImage: tk.px(42)
    readonly property int notifBadge: tk.px(20)
    readonly property int notifsWidth: tk.px((Config.o.notifs && Config.o.notifs.popups) ? Config.o.notifs.popups.width : 430)
    // Lock screen (Caelestia LockTokens in tokens.hpp). The card is a 16:9
    // rect 70% of the screen height; the rest are the heights and widths its
    // cards drop detail at, so a 1080p screen shows less than a 1440p one.
    // Grows with the UI scale (the content inside it does), up to 90% of
    // the screen, or a scaled-up lock overflows its card.
    readonly property real lockHeightMult: Math.min(0.9, 0.7 * tk.uiScale)
    readonly property real lockRatio: 16 / 9
    readonly property int lockCenterWidth: tk.px(600)
    readonly property int lockWeatherDetailsHeight: tk.px(550)
    readonly property int lockForecastHeight: tk.px(975)
    readonly property int lockForecastItemWidth: tk.px(51)
    readonly property int lockLargeLogoWidth: tk.px(320)
    readonly property int lockLargeFontWidth: tk.px(400)
    readonly property int lockFetch4LinesHeight: tk.px(600)
    readonly property int lockFetch3LinesHeight: tk.px(500)
    readonly property int lockColourRowHeight: tk.px(570)
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
  readonly property real animScale: Math.max(0.05, Config.o.appearance.animScale)
  readonly property QtObject durations: QtObject {
    readonly property int small: 200 * tk.animScale
    readonly property int normal: 400 * tk.animScale
    readonly property int large: 600 * tk.animScale
    readonly property int extraLarge: 1000 * tk.animScale
    readonly property int fastSpatial: 350 * tk.animScale
    readonly property int defaultSpatial: 500 * tk.animScale
    readonly property int slowSpatial: 650 * tk.animScale
    readonly property int fastEffects: 150 * tk.animScale
    readonly property int defaultEffects: 200 * tk.animScale
    readonly property int slowEffects: 300 * tk.animScale
  }
}
