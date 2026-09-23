import QtQuick
import "../.."

// Caelestia modules/background/Visualiser.qml: the bars slide up and fade in
// while shown, and hold cava only while they are.
//
// Caelestia's optional blur masks its own wallpaper item with the bars. Here
// it is Hyprland's blur on this window's layer (Bar.applyDesktopBlur), so it
// costs no textures. When no app has a playback stream open, cava isn't run
// at all and the bars settle to nothing.
Item {
  id: root

  property bool shown: false
  property real screenHeight: 0
  property real barZone: 0

  readonly property var cfg: Config.o.background.visualiser
  readonly property bool wantCava: shown && AudioService.hasPlayback
  onWantCavaChanged: Sys.visualiserWanted += wantCava ? 1 : -1
  Component.onDestruction: if (wantCava) Sys.visualiserWanted -= 1

  property real offset: shown ? 0 : screenHeight * 0.2
  opacity: shown ? 1 : 0

  // Silence, or cava not running: the same number of bars, all at rest.
  readonly property var zeros: {
    const z = []
    for (let i = 0; i < Sys.visBars; i++) z.push(0)
    return z
  }

  VisualiserBars {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Tk.border - root.offset
    anchors.rightMargin: Tk.border
    anchors.leftMargin: root.barZone + Tk.spacing.small * root.cfg.spacing
    // The full inner height of Caelestia's bars item; the window is only its
    // bottom 40%, which is all the bars ever reach.
    height: root.screenHeight - Tk.border * 2

    visible: root.opacity > 0
    values: Sys.visValues.length ? Sys.visValues : root.zeros
    primaryColor: Qt.alpha(Colours.m3primary, 0.7)
    secondaryColor: Qt.alpha(Colours.m3inversePrimary, 0.7)
    rounding: Tk.rounding.medium * root.cfg.rounding
    spacing: Tk.spacing.extraSmall * root.cfg.spacing
    animationDuration: Tk.durations.normal

    Behavior on anchors.leftMargin { Anim {} }
  }

  Behavior on offset { Anim {} }
  Behavior on opacity { Anim { type: "effects" } }
}
