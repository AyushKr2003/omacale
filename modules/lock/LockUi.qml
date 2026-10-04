import QtQuick
import QtQuick.Effects
import QtQuick.Window
import Quickshell
import Quickshell.Wayland
import "../.."

// Omacale's lock screen — a port of Caelestia's modules/lock/LockSurface.qml.
//
// It is loaded by URL from the clone of Omarchy's lock plugin (see
// assets/lock/LockView.qml and scripts/lock-screen), so everything below is
// drawing only: the session lock, PAM, the blank timers and the `lock` IPC
// all stay in Omarchy's own lock service, which reaches us through `view`.
//
// Caelestia grows a small rounded square holding a lock icon into a 16:9
// card, spinning both as it goes (LockPanel), and closes it back on unlock.
// Omarchy's service drops the session lock the moment PAM succeeds, so the
// card on screen is a mirror of this one drawn above the lock by Omacale's
// unlock overlay, which plays the closing (LockFx).
Item {
  id: root

  // The wrapper in the lock plugin (its property contract is Omarchy's
  // LockView.qml). Null for a moment while the Loader sets it.
  property var view: null

  // Whether this lock surface is really on screen.
  //
  // Omarchy's lock service builds a LockView inside its preview PanelWindow
  // as a plain child (Service.qml's `previewWindow`), and a window's
  // `visible: false` does not stop its QML tree being created -- so the whole
  // lock UI, ours included, exists from the moment the shell starts. Anything
  // in here that polls has to gate on this instead of on being constructed,
  // or it runs for the entire session behind a window nobody can see.
  //
  // `loadBackground` is exactly that bit on both surfaces Omarchy makes:
  // `root.locked` on the session lock, `previewVisible` on the preview.
  readonly property bool onScreen: view ? view.loadBackground : false

  readonly property string password: view ? view.passwordText : ""
  // Omarchy's flag, held from Enter until the password is refused: on
  // success Omarchy clears it a moment before it drops the lock, and the
  // field must still say "Loading..." as the card closes, as Caelestia's does.
  readonly property bool authenticating: (view ? view.authenticatingPassword : false) || passwordSent
  readonly property bool inputEnabled: view ? view.inputEnabled : false
  readonly property bool fingerprint: view ? view.fingerprintConfigured : false
  readonly property int failedAttempts: view ? view.failedAttempts : 0
  readonly property string failureMessage: view ? view.failureMessage : ""

  // A lock that comes back from a blanked screen, or a second monitor's
  // surface taking focus, must still type into the field.
  onInputEnabledChanged: if (inputEnabled)
    Qt.callLater(() => keys.forceActiveFocus())

  // Both preview (`omarchy-shell lock preview`) and the real surface measure
  // from the window, which is the screen either way.
  readonly property int cardWidth: Math.round(height * Tk.sizes.lockHeightMult * Tk.sizes.lockRatio)
  readonly property int cardHeight: Math.round(height * Tk.sizes.lockHeightMult)

  function wake() {
    if (view)
      view.wakeRequested()
  }
  function type(text) {
    if (!view)
      return
    if (failureMessage)
      view.clearFailureRequested()
    view.passwordTextEdited(password + text)
  }
  function erase(all) {
    if (view)
      view.passwordTextEdited(all ? "" : password.slice(0, -1))
  }
  // Emitted as Enter is handled, before anything changes: the field drops
  // its placeholder crossfade, as Caelestia's PasswordInput does on Enter.
  signal submitted

  // A password is in flight. Every refusal counts an attempt (Omarchy's
  // handlePasswordFailure); the reset to 0 is the unlock's, not a refusal.
  property bool passwordSent: false
  onFailedAttemptsChanged: if (failedAttempts > 0)
    passwordSent = false

  // Caelestia's order (Pam.qml): authentication starts, and only then is
  // the buffer cleared, so the field goes from the dots straight to
  // "Loading..." without the idle placeholder showing between them.
  function submit() {
    if (!view || !password.length)
      return
    const entered = password
    submitted()
    passwordSent = true
    view.submitPassword(entered)
    view.passwordTextEdited("")
  }

  // ------------------------------------------------------------ background
  // Mirrors Omarchy's own LockView: the shell draws stills only, so a video
  // background is its cached poster (`videoPosterPath`) with OWE's live lock
  // feed over it. Both components are Omarchy's and loaded by URL, so this
  // file keeps no import of the shell's internals.
  //
  // Same test as Omarchy's Util.isVideoPath, restated so the lock UI doesn't
  // import qs.Commons.
  readonly property alias card: card
  readonly property bool video: /\.(mp4|m4v|mov|webm|mkv|avi)$/i.test(view ? String(view.backgroundPath || "") : "")
  // Omarchy's `feedActive`: a blanked display shows nothing, so a video must
  // not keep decoding through it.
  // The ShellScreen this surface is on, for the screen capture. The wrapper
  // doesn't pass Omarchy's `lockSurface.screen` down, so it is found by the
  // name of the screen the window sits on.
  readonly property var shellScreen: {
    const screens = Quickshell.screens
    for (let i = 0; i < screens.length; i++)
      if (screens[i].name === Screen.name)
        return screens[i]
    return null
  }
  readonly property bool captured: capture.item !== null && capture.item.hasContent

  readonly property bool feedActive: video && !!view && view.loadBackground && !view.displaysBlank && !view.powerSaverActive

  Item {
    id: background

    anchors.fill: parent
    opacity: 0

    // The still (or poster) only. Omarchy doesn't blur the feed either: it
    // "cannot be sampled by MultiEffect on every renderer".
    Item {
      anchors.fill: parent

      layer.enabled: Config.o.lock.blur
      layer.effect: MultiEffect {
        autoPaddingEnabled: false
        blurEnabled: true
        blur: 1
        blurMax: 64
        blurMultiplier: 1
      }

      Rectangle {
        anchors.fill: parent
        color: Colours.palette.m3surface
      }

      Loader {
        id: media

        anchors.fill: parent
        source: Quickshell.env("OMARCHY_PATH") + "/shell/Ui/BackgroundMedia.qml"
      }

      // Omarchy 4.0.x has no BackgroundMedia; its own view drew the still
      // with a plain Image (v4.0.4 plugins/lock/LockView.qml), and so does
      // this. A video there has no poster, so it keeps the surface colour.
      Image {
        anchors.fill: parent
        visible: media.status === Loader.Error
        source: visible && !root.video && root.view && root.view.loadBackground && root.view.backgroundPath
          ? "file://" + String(root.view.backgroundPath).split("/").map(encodeURIComponent).join("/") + "?v=" + root.view.backgroundVersion
          : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        sourceSize.width: width
        sourceSize.height: height
      }
    }

    // A missing or unreadable BackgroundMedia leaves the surface colour, so
    // the lock still draws; these keep it in step while it is there.
    Binding {
      target: media.item
      property: "path"
      value: root.view && root.view.loadBackground ? (root.video ? root.view.videoPosterPath : root.view.backgroundPath) : ""
      when: media.item !== null
      restoreMode: Binding.RestoreNone
    }
    Binding {
      target: media.item
      property: "version"
      value: root.view ? root.view.backgroundVersion : 0
      when: media.item !== null
      restoreMode: Binding.RestoreNone
    }

    // The wrapper names the feed (it lives in the lock clone), so a wrapper
    // too old to know it, or a system without Owe.LockFeed, just keeps the
    // poster: a Loader error stays inside the Loader.
    Loader {
      id: feed

      anchors.fill: parent
      active: root.feedActive && !!root.view.feedSurfaceUrl && !root.captured
      source: active ? root.view.feedSurfaceUrl : ""
      visible: status === Loader.Ready
    }

    // Omarchy's darkening over video, for legibility.
    Rectangle {
      anchors.fill: parent
      visible: root.video && !root.captured
      color: "#22000000"
    }

    // Caelestia's default background (LockSurface.qml `screencopyBackground`):
    // one frame of what this screen showed, taken as the surface appears --
    // Hyprland refuses captures once the lock is confirmed, and the live
    // flag would only ever see the lock itself. Built only while on screen,
    // since the preview's LockUi exists all session. Until (or unless) the
    // frame lands -- a display that is off, a capture refused -- the
    // wallpaper above shows instead. Always blurred, whatever `lock.blur`
    // says: a sharp copy of the desktop would show it to anyone at the
    // machine.
    Item {
      anchors.fill: parent
      visible: root.captured

      layer.enabled: true
      layer.effect: MultiEffect {
        autoPaddingEnabled: false
        blurEnabled: true
        blur: 1
        blurMax: 64
        blurMultiplier: 1
      }

      Loader {
        id: capture

        anchors.fill: parent
        active: root.onScreen && !Config.o.lock.useWallpaper && !!root.shellScreen

        sourceComponent: ScreencopyView {
          captureSource: root.shellScreen
          live: false
        }
      }
    }
  }

  // Any input wakes the displays Omarchy blanked a few seconds into the lock.
  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: {
      root.wake()
      keys.forceActiveFocus()
    }
    onPositionChanged: root.wake()
  }

  // ------------------------------------------------------------- the card
  // Hidden while the unlock overlay draws its mirror of it above the lock;
  // it still plays its motion, which the mirror follows.
  readonly property bool covered: {
    const e = LockFx.screens[screenName]
    return !!e && e.ui === root && e.covering
  }

  Item {
    anchors.fill: parent
    visible: !root.covered

    LockPanel {
      id: card

      lock: root
      backdrop: background
      cardWidth: root.cardWidth
      cardHeight: root.cardHeight
      onOpenFinished: root.handOver()
    }
  }

  // Keyboard goes to one focus item, as Caelestia's PasswordInput does, so
  // typing anywhere on the lock reaches the password field.
  Item {
    id: keys

    // The surface hands focus to whoever asks first, and this UI is loaded
    // into it a frame late, so it takes focus itself rather than waiting --
    // and takes it back if anything else grabs it, as Caelestia's field does.
    focus: true
    Component.onCompleted: Qt.callLater(forceActiveFocus)
    onActiveFocusChanged: if (!activeFocus)
      forceActiveFocus()

    Keys.onPressed: event => {
      root.wake()
      if (!root.inputEnabled || root.authenticating)
        return

      if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return)
        root.submit()
      else if (event.key === Qt.Key_Escape)
        root.erase(true)
      else if (event.key === Qt.Key_Backspace)
        root.erase(event.modifiers & Qt.ControlModifier)
      else if (event.key === Qt.Key_U && (event.modifiers & Qt.ControlModifier))
        root.erase(true)
      else if (/^[^\x00-\x1F\x7F-\x9F]+$/.test(event.text))
        root.type(event.text)

      event.accepted = true
    }
  }

  // ---------------------------------------------------------- the opening
  // Caelestia's lock surface has its size from the first frame; ours is
  // loaded into one, so the card would animate out to a `to` of zero if it
  // started before the window was sized.
  property bool opened: false
  onHeightChanged: open()
  Component.onCompleted: open()
  function open() {
    if (opened || width <= 0 || height <= 0)
      return
    opened = true
    card.open()
  }

  // ---------------------------------------------------------- the closing
  // Omarchy's service tears this surface down in the same call that accepts
  // the password, so the card is drawn by Omacale's own overlay above the
  // lock, which plays the closing (LockFx, LockUnlockFx). Only the real lock
  // arms it: the preview's view never takes input, and an overlay over the
  // preview would cover it.
  readonly property string screenName: shellScreen ? shellScreen.name : ""
  readonly property bool armed: onScreen && inputEnabled && !!screenName
  property bool handedOver: false

  // The service clears `inputEnabled` (its lockRequested) the moment a
  // password is accepted, which is the only unlock signal this side gets.
  onArmedChanged: {
    if (armed) {
      passwordSent = false
      LockFx.arm(screenName, root)
    } else {
      if (onScreen && !inputEnabled)
        LockFx.unlock(screenName)
      else
        LockFx.disarm(screenName)
      handedOver = false
    }
  }
  Component.onDestruction: if (armed) LockFx.disarm(screenName)

  // Once the card is open, the overlay takes a grab of this backdrop, to fade
  // out once the lock has gone. A capture that lands later grabs again. The
  // video feed is another client's surface and isn't in the grab; its
  // poster is.
  function handOver() {
    if (!armed)
      return
    background.grabToImage(result => {
      if (!root.armed)
        return
      root.handedOver = true
      LockFx.ready(root.screenName, result)
    })
  }
  onCapturedChanged: if (captured && handedOver) handOver()
}
