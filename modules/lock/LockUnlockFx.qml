import QtQuick
import Quickshell
import Quickshell.Wayland
import "../.."

// The lock card's closing, played after Omarchy's lock service has already
// dropped the session lock (see LockFx for why it can't play on the lock
// surface itself).
//
// Hyprland draws nothing but the lock surface while the session is locked
// (Renderer.cpp skips every other layer), so this surface sits behind it
// unseen -- and, unseen, gets no frame callbacks. Qt Wayland stops drawing a
// window whose callbacks stop (100ms, then `mFrameCallbackTimedOut` marks it
// unexposed), so whatever it committed first is all it will show until the
// lock goes. Hence two rules:
//
// - It is created only once LockUi's card is open (`ready`), already in the
//   open state, so that one frame -- the first a new surface draws, which
//   needs no callback -- is the lock's own last frame, and the desktop never
//   shows between the lock surface going and this one taking over.
// - The closing starts on the first frame drawn after the unlock, not at the
//   unlock: until Hyprland sends the callback that wakes Qt, the animation
//   would run unseen and the first frame shown would already be partway in.
//
// It takes no input, and gives up after a few seconds whatever happens, so
// it can never be left over the desktop.
PanelWindow {
  id: root

  required property var shellScreen
  readonly property string name: shellScreen ? shellScreen.name : ""
  readonly property var fx: LockFx.screens[name] || null
  readonly property bool ready: !!fx && fx.ready
  readonly property bool playing: !!fx && fx.playing

  screen: shellScreen
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "omacale-unlock"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  anchors { top: true; bottom: true; left: true; right: true }
  mask: Region {}

  // What LockContent reads from LockUi, frozen as the lock looked when it
  // let go: the password was just cleared on submit.
  QtObject {
    id: stand

    readonly property bool onScreen: true
    readonly property int height: root.height
    readonly property string password: ""
    readonly property bool authenticating: false
    readonly property bool inputEnabled: false
    readonly property bool fingerprint: false
    readonly property int failedAttempts: 0
    readonly property string failureMessage: ""
    function wake() {}
    function submit() {}
  }

  Item {
    id: scene

    anchors.fill: parent

    Item {
      id: backdrop

      anchors.fill: parent
      opacity: 0

      Rectangle {
        anchors.fill: parent
        color: Colours.palette.m3surface
        visible: !frame.visible
      }

      // LockUi's grab of its own blurred backdrop.
      Image {
        id: frame

        anchors.fill: parent
        visible: status === Image.Ready
        source: root.fx && root.fx.frame ? root.fx.frame.url : ""
        // In the first frame, which is the only one drawn behind the lock.
        asynchronous: false
        cache: false
      }
    }

    LockPanel {
      id: panel

      lock: stand
      backdrop: backdrop
      cardWidth: Math.round(root.height * Tk.sizes.lockHeightMult * Tk.sizes.lockRatio)
      cardHeight: Math.round(root.height * Tk.sizes.lockHeightMult)
      onCloseFinished: LockFx.finished(root.name)
    }
  }

  // The window this surface draws into, for its frameSwapped.
  readonly property var qwin: scene.Window.window

  property bool waitingFrame: false

  Component.onCompleted: {
    panel.showOpen()
    if (playing)
      begin()
  }
  onPlayingChanged: if (playing) begin()

  function begin() {
    if (waitingFrame || panel.closing)
      return
    waitingFrame = true
    giveUp.restart()
    noFrame.restart()
    // Behind the lock Qt is unexposed and draws on Hyprland's next callback;
    // over the desktop (the IPC test) nothing else would ask for a frame.
    if (qwin)
      qwin.requestUpdate()
  }

  function startClosing() {
    if (!waitingFrame)
      return
    waitingFrame = false
    noFrame.stop()
    panel.close()
  }

  Connections {
    target: root.qwin
    function onFrameSwapped(): void {
      root.startClosing()
    }
  }

  // A frame that never comes (no window yet, a compositor that never calls
  // back) still gets its closing, late rather than never.
  Timer {
    id: noFrame

    interval: 250
    onTriggered: root.startClosing()
  }

  Timer {
    id: giveUp

    interval: Math.max(3000, Tk.durations.extraLarge * 3)
    onTriggered: LockFx.finished(root.name)
  }
}
