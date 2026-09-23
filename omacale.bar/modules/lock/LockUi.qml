import QtQuick
import QtQuick.Effects
import Quickshell
import "../.."

// Omacale's lock screen — a port of Caelestia's modules/lock/LockSurface.qml.
//
// It is loaded by URL from the clone of Omarchy's lock plugin (see
// assets/lock/LockView.qml and scripts/lock-screen), so everything below is
// drawing only: the session lock, PAM, the blank timers and the `lock` IPC
// all stay in Omarchy's own lock service, which reaches us through `view`.
//
// Caelestia grows a small rounded square holding a lock icon into a 16:9
// card, spinning both as it goes, and reverses it on unlock. The unlock leg
// runs only in the real lock; Omarchy's service drops `locked` itself, so
// this one just plays out and the surface goes with it.
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
  readonly property bool authenticating: view ? view.authenticatingPassword : false
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
  function submit() {
    if (!view || !password.length)
      return
    const entered = password
    view.passwordTextEdited("")
    view.submitPassword(entered)
  }

  // ------------------------------------------------------------ background
  // Omarchy's own lock view draws the current background here, video
  // included, and that is the component to reuse rather than reinvent: it is
  // loaded by URL so this file keeps no import of the shell's internals.
  Item {
    id: background

    anchors.fill: parent
    opacity: 0

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

    // A missing or unreadable BackgroundMedia leaves the surface colour, so
    // the lock still draws; these keep it in step while it is there.
    Binding {
      target: media.item
      property: "path"
      value: root.view ? root.view.backgroundPath : ""
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
    // A blanked display shows nothing, so a video must not keep decoding
    // through it (the reason Omarchy's own view passes this through).
    Binding {
      target: media.item
      property: "playbackEnabled"
      value: root.view ? root.view.loadBackground && !root.view.displaysBlank && !root.view.powerSaverActive : false
      when: media.item !== null && "playbackEnabled" in media.item
      restoreMode: Binding.RestoreNone
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
  Item {
    id: card

    // Caelestia's closed size: the lock icon with padding.large on all sides.
    readonly property int size: lockIcon.implicitHeight + Tk.padding.large * 4
    readonly property int closedRadius: size / 4

    anchors.centerIn: parent
    implicitWidth: size
    implicitHeight: size
    rotation: 180
    scale: 0

    Rectangle {
      id: cardBg

      anchors.fill: parent
      color: Colours.palette.m3surface
      radius: card.closedRadius
      opacity: Colours.transparent ? Colours.trBase : 1

      // Caelestia shadows the card with a MultiEffect; Omacale's Elevation
      // is the same shadow without a layer over an item that resizes.
      Elevation {
        anchors.fill: parent
        radius: parent.radius
        level: 3
        z: -1
        visible: Config.o.appearance.shadow
      }
    }

    MIcon {
      id: lockIcon

      anchors.centerIn: parent
      text: "lock"
      size: Tk.iconSize.extraLarge * 4
      weight: Font.Bold
      rotation: 180
    }

    LockContent {
      id: content

      anchors.centerIn: parent
      width: root.cardWidth - Tk.padding.extraLargeIncreased
      height: root.cardHeight - Tk.padding.extraLargeIncreased

      lock: root
      opacity: 0
      scale: 0
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
      if (!root.inputEnabled || root.authenticating || unlockAnim.running)
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
    initAnim.start()
  }

  ParallelAnimation {
    id: initAnim

    // Keeps the card right if the screen is resized while it is up.
    onFinished: {
      card.implicitWidth = Qt.binding(() => root.cardWidth)
      card.implicitHeight = Qt.binding(() => root.cardHeight)
    }

    Anim {
      target: background
      property: "opacity"
      to: 1
      type: "standardLarge"
    }
    SequentialAnimation {
      ParallelAnimation {
        Anim {
          target: card
          property: "scale"
          to: 1
          type: "fastSpatial"
        }
        Anim {
          target: card
          property: "rotation"
          to: 360
          duration: Tk.durations.fastSpatial
          easing.bezierCurve: Tk.curves.standardAccel
        }
      }
      ParallelAnimation {
        Anim {
          target: lockIcon
          property: "rotation"
          to: 360
          easing.bezierCurve: Tk.curves.standardDecel
        }
        Anim {
          target: lockIcon
          property: "opacity"
          to: 0
          type: "effects"
        }
        Anim {
          target: content
          property: "opacity"
          to: 1
          type: "effects"
        }
        Anim {
          target: content
          property: "scale"
          to: 1
        }
        Anim {
          target: cardBg
          property: "radius"
          to: Tk.rounding.extraLarge * 1.5
        }
        Anim {
          target: card
          property: "implicitWidth"
          to: root.cardWidth
        }
        Anim {
          target: card
          property: "implicitHeight"
          to: root.cardHeight
        }
      }
    }
  }

  // ---------------------------------------------------------- the closing
  // Omarchy's service tears the surface down as soon as PAM succeeds, so this
  // is the send-off, not a gate: nothing here decides when the lock ends.
  ParallelAnimation {
    id: unlockAnim

    Anim {
      target: card
      properties: "implicitWidth,implicitHeight"
      to: card.size
    }
    Anim {
      target: cardBg
      property: "radius"
      to: card.closedRadius
    }
    Anim {
      target: content
      property: "scale"
      to: 0
    }
    Anim {
      target: content
      property: "opacity"
      to: 0
      type: "standardSmall"
    }
    Anim {
      target: lockIcon
      property: "opacity"
      to: 1
      type: "standardLarge"
    }
    Anim {
      target: background
      property: "opacity"
      to: 0
      type: "standardLarge"
    }
    SequentialAnimation {
      PauseAnimation {
        duration: Tk.durations.small
      }
      Anim {
        target: card
        property: "opacity"
        to: 0
        type: "standard"
      }
    }
  }

  Connections {
    target: root.view

    // The service clears `inputEnabled` (its lockRequested) the moment a
    // password is accepted, which is the only unlock signal this side gets.
    function onInputEnabledChanged(): void {
      if (root.view && !root.view.inputEnabled && root.opened && !initAnim.running)
        unlockAnim.start();
    }
  }
}
