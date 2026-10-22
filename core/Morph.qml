pragma Singleton
import QtQuick
import ".."

// Morph motion (Settings › Motion › Style), Omacale's own: panels come and
// go, and switch, the way Serpantinum's do. The container is Serpantinum's
// master window (shell/serpantinum/src/quickshell/Main.qml animContainer:
// morphDuration 300 OutCubic, exitDuration 180; switchWidget/executeSwitch:
// one panel reshapes from the old page to the new one while the old content
// is dropped at once); the content is its pages' introMain
// (volume/VolumePopup.qml introAnim/exitAnim: 800ms OutExpo in, 180ms
// InQuart out; scale 0.95 + 0.05p, opacity p, a 20px rise).
// The one reader of Config.o.morph. Off (the default), and whenever liquid
// motion is on, everything moves on Caelestia's curves.
QtObject {
  readonly property bool enabled: Config.o.morph.enabled && !Config.o.liquid.enabled

  readonly property int slideIn: 300 * Tk.animScale
  readonly property int slideOut: 180 * Tk.animScale
  // easeOutCubic / easeInCubic as bezier splines, for Anim.
  readonly property var curveIn: [0.33, 1, 0.68, 1, 1, 1]
  readonly property var curveOut: [0.32, 0, 0.67, 0, 1, 1]
  readonly property int introIn: 800 * Tk.animScale
  readonly property int introOut: 180 * Tk.animScale
  readonly property real scaleFrom: 0.95
  readonly property real rise: Tk.px(20)

  // The Anim type for a drawer's *OffC Behavior (0 open, 1 away), or its
  // Caelestia one while off.
  function type(behavior, fallback) {
    return enabled ? (behavior.targetValue < 0.5 ? "morphIn" : "morphOut") : fallback
  }
}
