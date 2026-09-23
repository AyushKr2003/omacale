import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../.."

// Caelestia modules/background/Background.qml, minus the wallpaper (Omarchy's
// background plugin draws that): the desktop clock and the audio visualiser,
// drawn on Hyprland's `bottom` layer, above the wallpaper and below windows.
//
// Caelestia puts both in one full-screen window, which costs a few full-screen
// buffers for its whole life. Here each is a window of its own, sized to what
// it draws: the clock is a card, and the visualiser is the bottom 40% of the
// screen while it shows and a 1px strip while it is auto-hidden. With both off
// (the default, as in Caelestia) nothing is created at all.
//
// Surfaces on one layer stack in the order they were created, and the clock
// belongs over the bars (Caelestia's behindClock). So the visualiser's surface
// is parked rather than destroyed when it hides, the clock is only created
// once the visualiser's window exists, and a visualiser switched on later has
// the clock re-created above it.
Scope {
  id: root

  required property var screen
  // The bar's exclusive zone, which the visualiser starts beside.
  property real barZone: 0
  readonly property var cfg: Config.o.background
  readonly property var monitor: Hyprland.monitorFor(screen)

  // ------------------------------------------------------------ clock
  // Room around the card for the drop shadow to spread into.
  readonly property int shadowPad: Tk.padding.extraLargeIncreased
  // Caelestia's clockLoader margins, measured from the screen edges.
  readonly property int clockMargin: Tk.padding.extraLargeIncreased
  readonly property int clockLeftMargin: Tk.padding.extraLargeIncreased + Tk.barInner + Math.max(Tk.padding.small, Tk.border)

  property bool restacking: false
  function restackClock() {
    if (!clockLoader.item) return
    restacking = true
    Qt.callLater(() => restacking = false)
  }

  LazyLoader {
    id: clockLoader
    active: root.cfg.desktopClock.enabled && !root.restacking && (!root.cfg.visualiser.enabled || visLoader.item !== null)

    PanelWindow {
      id: clockWin

      readonly property string pos: root.cfg.desktopClock.position
      readonly property bool atTop: pos.indexOf("top") === 0
      readonly property bool atBottom: pos.indexOf("bottom") === 0
      readonly property bool atLeft: pos.endsWith("left")
      readonly property bool atRight: pos.endsWith("right")

      screen: root.screen
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.namespace: "omacale-clock"
      WlrLayershell.layer: WlrLayer.Bottom
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      mask: Region {}

      // An axis left unanchored centres the window on it, which is
      // Caelestia's *-center / middle-* placement.
      anchors { top: clockWin.atTop; bottom: clockWin.atBottom; left: clockWin.atLeft; right: clockWin.atRight }
      margins {
        top: root.clockMargin - root.shadowPad
        bottom: root.clockMargin - root.shadowPad
        left: root.clockLeftMargin - root.shadowPad
        right: root.clockMargin - root.shadowPad
      }

      implicitWidth: Math.ceil(clockItem.implicitWidth) + root.shadowPad * 2
      implicitHeight: Math.ceil(clockItem.implicitHeight) + root.shadowPad * 2

      DesktopClock {
        id: clockItem
        anchors.fill: parent
        anchors.margins: root.shadowPad
      }
    }
  }

  // ------------------------------------------------------- visualiser
  // Caelestia Visualiser.shouldBeActive: with auto-hide, only while every
  // window on the monitor's workspace floats (an empty one included).
  readonly property bool visWanted: {
    if (!cfg.visualiser.enabled) return false
    if (!cfg.visualiser.autoHide) return true
    const ws = monitor ? monitor.activeWorkspace : null
    const tl = ws && ws.toplevels ? ws.toplevels.values : []
    return tl.every(t => t.lastIpcObject && t.lastIpcObject.floating)
  }
  // Kept full size through the slide-out, then parked.
  onVisWantedChanged: if (!visWanted) visLinger.restart()
  Timer { id: visLinger; interval: Tk.durations.defaultSpatial }
  readonly property bool visParked: !visWanted && !visLinger.running

  // `floating` lives in lastIpcObject, which Quickshell only refreshes on request.
  readonly property bool tracksFloating: cfg.visualiser.enabled && cfg.visualiser.autoHide
  onTracksFloatingChanged: if (tracksFloating) Hyprland.refreshToplevels()
  Component.onCompleted: if (tracksFloating) Hyprland.refreshToplevels()
  Connections {
    target: Hyprland
    enabled: root.tracksFloating
    function onRawEvent(e) {
      if (["changefloatingmode", "openwindow", "closewindow", "movewindow"].indexOf(e.name) >= 0) Hyprland.refreshToplevels()
    }
  }

  LazyLoader {
    id: visLoader
    active: root.cfg.visualiser.enabled

    PanelWindow {
      id: visWin

      screen: root.screen
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.namespace: "omacale-visualiser"
      WlrLayershell.layer: WlrLayer.Bottom
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      mask: Region {}

      // Caelestia's bars fill the screen inside the border and rise at most
      // 40% of that, so only the bottom of the screen is ever drawn on.
      anchors { bottom: true; left: true; right: true }
      implicitHeight: root.visParked ? 1 : Math.ceil((root.screen.height - Tk.border * 2) * 0.4 + Tk.border)

      // Created hidden, so it slides in like Caelestia's does.
      property bool entered: false
      Component.onCompleted: {
        entered = true
        root.restackClock()
      }

      Visualiser {
        visible: !root.visParked
        anchors.fill: parent
        screenHeight: root.screen.height
        barZone: root.barZone
        shown: visWin.entered && root.visWanted
      }
    }
  }
}
