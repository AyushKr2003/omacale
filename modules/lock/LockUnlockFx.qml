import QtQuick
import Quickshell
import Quickshell.Wayland
import "../.."

// The lock card as the user sees it, drawn above the session lock, and its
// closing once Omarchy's lock service has dropped the lock (see LockFx for
// why the closing can't play on the lock surface itself).
//
// Hyprland draws a layer with the `above_lock` rule over the lock surface,
// and sends it frame callbacks as it does (Renderer.cpp renderLockscreen,
// SurfacePassElement's presentFeedback), so unlike a layer behind the lock
// this one is live the whole time. Its card follows the lock's own card frame
// for frame (LockPanel `follow`) and reads the lock's state (`stand`), so it
// looks exactly like it; the lock hides its own card once this one is known
// to be drawn (LockFx.cover). When the lock goes, nothing changes on screen:
// the card is already here, and the closing starts on the next frame.
//
// With `above_lock = 2` the card also takes the pointer (only the card: the
// input region is the card's rect), so its buttons are the ones that react.
// The keyboard stays with the lock surface whatever is above it.
//
// It never takes the keyboard, and once the closing starts it gives up after
// a few seconds whatever happens, so it can never be left over the desktop.
PanelWindow {
  id: root

  required property var shellScreen
  readonly property string name: shellScreen ? shellScreen.name : ""
  readonly property var fx: LockFx.screens[name] || null
  readonly property var ui: fx ? fx.ui : null
  readonly property bool playing: !!fx && fx.playing
  // Mirroring the lock, until the closing starts.
  readonly property bool following: !!ui && !playing
  // `omacale unlockFx`: no lock to mirror, just the card and its closing.
  property bool test: false

  screen: shellScreen
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "omacale-unlock"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  anchors { top: true; bottom: true; left: true; right: true }
  mask: Region {
    x: panel.x
    y: panel.y
    width: root.following && root.fx.covering ? panel.width : 0
    height: root.following && root.fx.covering ? panel.height : 0
  }

  // What LockContent reads from LockUi: bound to the lock while it is up,
  // and left as it last was when the lock lets go -- the password cleared
  // and, after a password unlock, the field on "Loading...", as Caelestia's
  // is while its unlockAnim plays. LockUi reports the lock let go before
  // Omarchy resets the rest (`finishUnlock`), so nothing here moves after.
  QtObject {
    id: stand

    signal submitted

    property bool onScreen: true
    property int height: root.height
    property string password: ""
    property bool authenticating: true
    property bool inputEnabled: false
    property bool fingerprint: false
    property int failedAttempts: 0
    property string failureMessage: ""
    function wake() {
      if (root.following)
        root.ui.wake()
    }
    function submit() {
      if (root.following)
        root.ui.submit()
    }
  }

  component Mirror: Binding {
    target: stand
    when: root.following
    restoreMode: Binding.RestoreNone
  }
  Mirror { property: "onScreen"; value: root.ui ? root.ui.onScreen : false }
  Mirror { property: "height"; value: root.ui ? root.ui.height : 0 }
  Mirror { property: "password"; value: root.ui ? root.ui.password : "" }
  Mirror { property: "authenticating"; value: root.ui ? root.ui.authenticating : false }
  Mirror { property: "inputEnabled"; value: root.ui ? root.ui.inputEnabled : false }
  Mirror { property: "fingerprint"; value: root.ui ? root.ui.fingerprint : false }
  Mirror { property: "failedAttempts"; value: root.ui ? root.ui.failedAttempts : 0 }
  Mirror { property: "failureMessage"; value: root.ui ? root.ui.failureMessage : "" }

  Connections {
    target: root.following ? root.ui : null
    ignoreUnknownSignals: true
    function onSubmitted() {
      stand.submitted()
    }
  }

  Item {
    id: scene

    anchors.fill: parent

    Item {
      id: backdrop

      anchors.fill: parent
      // The lock's own backdrop is right under this one while it is up, so
      // this shows only once it holds the same picture (the grab LockUi
      // takes when its card has opened). A video stays the lock's: the live
      // feed is another client's surface, and the grab has only its poster.
      opacity: root.test || (frame.visible && !!root.ui && !root.ui.video) ? 1 : 0

      Rectangle {
        anchors.fill: parent
        color: Colours.palette.m3surface
        visible: root.test && !frame.visible
      }

      // LockUi's grab of its own blurred backdrop.
      Image {
        id: frame

        anchors.fill: parent
        visible: status === Image.Ready
        source: root.fx && root.fx.frame ? root.fx.frame.url : ""
        cache: false
      }
    }

    // Any pointer on the card wakes blanked displays, as the lock's own
    // MouseArea does everywhere else.
    MouseArea {
      anchors.fill: panel
      hoverEnabled: true
      onPositionChanged: stand.wake()
      onClicked: stand.wake()
    }

    LockPanel {
      id: panel

      lock: stand
      backdrop: backdrop
      follow: root.ui ? root.ui.card : null
      cardWidth: Math.round(root.height * Tk.sizes.lockHeightMult * Tk.sizes.lockRatio)
      cardHeight: Math.round(root.height * Tk.sizes.lockHeightMult)
      onCloseFinished: LockFx.finished(root.name)
    }
  }

  // The window this surface draws into, for its frameSwapped.
  readonly property var qwin: scene.Window.window

  Component.onCompleted: {
    if (!ui) {
      test = true
      panel.showOpen()
    }
    if (playing)
      begin()
  }
  onPlayingChanged: if (playing) begin()

  function begin() {
    if (panel.closing)
      return
    // A video backdrop was the lock's until now; the grab of its poster
    // takes over for the fade.
    backdrop.opacity = test || frame.visible ? 1 : 0
    panel.close()
    giveUp.restart()
  }

  // Is Hyprland drawing this above the lock? Only a surface it draws gets
  // frame callbacks, and Qt only swaps a frame on one (without it, it stops
  // after 100ms and marks the window unexposed). So: ask for a frame now and
  // then, and see whether one is swapped. A layer without the rule, or a
  // display that is off, answers no, and the lock shows its own card.
  property bool pingPending: false
  property real pingAt: 0

  Timer {
    interval: 400
    repeat: true
    running: root.following
    triggeredOnStart: true
    onTriggered: {
      if (root.pingPending && Date.now() - root.pingAt > 250) {
        root.pingPending = false
        LockFx.cover(root.name, false)
      }
      if (!root.pingPending && root.qwin) {
        root.pingPending = true
        root.pingAt = Date.now()
        root.qwin.requestUpdate()
      }
    }
  }

  Connections {
    target: root.qwin
    function onFrameSwapped(): void {
      if (!root.pingPending)
        return
      root.pingPending = false
      LockFx.cover(root.name, true)
    }
  }

  Timer {
    id: giveUp

    interval: Math.max(3000, Tk.durations.extraLarge * 3)
    onTriggered: LockFx.finished(root.name)
  }
}
