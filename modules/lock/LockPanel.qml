import QtQuick
import "../.."

// The lock card and its motion (Caelestia modules/lock/LockSurface.qml's
// `lockContent`, `initAnim` and `unlockAnim`): a small rounded square holding
// a lock icon grows into the 16:9 card, spinning both as it goes, and on
// unlock plays that backwards.
//
// Two places draw it. LockUi plays the opening on the lock surface; the
// unlock overlay (LockUnlockFx) plays the closing, since Omarchy's lock
// service drops the session lock the moment PAM succeeds and the lock
// surface goes with it (see LockFx).
Item {
  id: root

  // LockUi, or the overlay's stand-in for it: what LockContent reads.
  required property var lock
  // The blurred backdrop, faded in with the opening and out with the closing.
  required property Item backdrop
  required property int cardWidth
  required property int cardHeight

  readonly property bool opening: initAnim.running
  readonly property bool closing: unlockAnim.running
  signal openFinished
  signal closeFinished

  // Caelestia's closed size: the lock icon with padding.large on all sides.
  readonly property int size: lockIcon.implicitHeight + Tk.padding.large * 4
  readonly property real closedRadius: size / 4 * Tk.roundScale
  readonly property real openRadius: Tk.rounding.extraLarge * 1.5

  anchors.centerIn: parent
  implicitWidth: size
  implicitHeight: size
  rotation: 180
  scale: 0

  function open() {
    initAnim.start()
  }

  // The state the opening ends in, with no motion: where the overlay starts.
  function showOpen() {
    initAnim.stop()
    unlockAnim.stop()
    backdrop.opacity = 1
    root.opacity = 1
    root.scale = 1
    root.rotation = 360
    lockIcon.rotation = 360
    lockIcon.opacity = 0
    content.opacity = 1
    content.scale = 1
    cardBg.radius = openRadius
    bindSize()
  }

  function close() {
    unlockAnim.start()
  }

  // Keeps the card right if the screen is resized while it is up.
  function bindSize() {
    implicitWidth = Qt.binding(() => root.cardWidth)
    implicitHeight = Qt.binding(() => root.cardHeight)
  }

  Rectangle {
    id: cardBg

    anchors.fill: parent
    color: Colours.palette.m3surface
    radius: root.closedRadius
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

    lock: root.lock
    opacity: 0
    scale: 0
  }

  ParallelAnimation {
    id: initAnim

    onFinished: {
      root.bindSize()
      root.openFinished()
    }

    Anim {
      target: root.backdrop
      property: "opacity"
      to: 1
      type: "standardLarge"
    }
    SequentialAnimation {
      ParallelAnimation {
        Anim {
          target: root
          property: "scale"
          to: 1
          type: "fastSpatial"
        }
        Anim {
          target: root
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
          to: root.openRadius
        }
        Anim {
          target: root
          property: "implicitWidth"
          to: root.cardWidth
        }
        Anim {
          target: root
          property: "implicitHeight"
          to: root.cardHeight
        }
      }
    }
  }

  // The closing is the opening played backwards: every step in reverse
  // order, each ending where its opening twin started, on that twin's curve
  // reversed in time (`back`). One deliberate difference from Caelestia,
  // whose unlockAnim shrinks the card to the square and fades it out without
  // the spin, so the two didn't mirror.
  //
  // The opening's second leg runs `spatial`; a step shorter than that started
  // with it, so its mirror ends with it (`tail`). Its first leg runs
  // `fastSpatial`. The backdrop faded in over the first `standardLarge` of
  // the whole, so it fades out over the last.
  readonly property int legOut: Tk.durations.defaultSpatial
  readonly property int legSpin: Tk.durations.fastSpatial

  function back(c) {
    return [1 - c[2], 1 - c[3], 1 - c[0], 1 - c[1], 1, 1]
  }
  function tail(d) {
    return Math.max(0, legOut - d)
  }

  ParallelAnimation {
    id: unlockAnim

    onFinished: root.closeFinished()

    SequentialAnimation {
      // The opening's second leg, backwards.
      ParallelAnimation {
        Anim {
          target: lockIcon
          property: "rotation"
          to: 180
          duration: root.legOut
          easing.bezierCurve: root.back(Tk.curves.standardDecel)
        }
        SequentialAnimation {
          PauseAnimation {
            duration: root.tail(Tk.durations.defaultEffects)
          }
          Anim {
            target: lockIcon
            property: "opacity"
            to: 1
            duration: Tk.durations.defaultEffects
            easing.bezierCurve: root.back(Tk.curves.defaultEffects)
          }
        }
        SequentialAnimation {
          PauseAnimation {
            duration: root.tail(Tk.durations.defaultEffects)
          }
          Anim {
            target: content
            property: "opacity"
            to: 0
            duration: Tk.durations.defaultEffects
            easing.bezierCurve: root.back(Tk.curves.defaultEffects)
          }
        }
        Anim {
          target: content
          property: "scale"
          to: 0
          duration: root.legOut
          easing.bezierCurve: root.back(Tk.curves.defaultSpatial)
        }
        Anim {
          target: cardBg
          property: "radius"
          to: root.closedRadius
          duration: root.legOut
          easing.bezierCurve: root.back(Tk.curves.defaultSpatial)
        }
        Anim {
          target: root
          properties: "implicitWidth,implicitHeight"
          to: root.size
          duration: root.legOut
          easing.bezierCurve: root.back(Tk.curves.defaultSpatial)
        }
      }
      // The first leg, backwards: the square spins away to nothing.
      ParallelAnimation {
        Anim {
          target: root
          property: "scale"
          to: 0
          duration: root.legSpin
          easing.bezierCurve: root.back(Tk.curves.fastSpatial)
        }
        Anim {
          target: root
          property: "rotation"
          to: 180
          duration: root.legSpin
          easing.bezierCurve: root.back(Tk.curves.standardAccel)
        }
      }
    }
    SequentialAnimation {
      PauseAnimation {
        duration: Math.max(0, root.legOut + root.legSpin - Tk.durations.large)
      }
      Anim {
        target: root.backdrop
        property: "opacity"
        to: 0
        duration: Tk.durations.large
        easing.bezierCurve: root.back(Tk.curves.standard)
      }
    }
  }
}
