import QtQuick
import "../.."

// The lock card and its motion (Caelestia modules/lock/LockSurface.qml's
// `lockContent`, `initAnim` and `unlockAnim`): a small rounded square holding
// a lock icon grows into the 16:9 card, spinning both as it goes, and on
// unlock the card closes back into the square and fades away.
//
// Two places draw it. LockUi plays the opening on the lock surface; the
// unlock overlay (LockUnlockFx), drawn above the lock, shows a second card
// that follows this one frame for frame (`follow`) and plays the closing,
// since Omarchy's lock service drops the session lock the moment PAM
// succeeds and the lock surface goes with it (see LockFx).
Item {
  id: root

  // LockUi, or the overlay's stand-in for it: what LockContent reads.
  required property var lock
  // The blurred backdrop, faded in with the opening and out with the closing.
  required property Item backdrop
  required property int cardWidth
  required property int cardHeight

  // Another LockPanel to mirror: every animated value follows it until the
  // closing starts here.
  property Item follow: null
  property bool released: false
  readonly property bool following: !!follow && !released

  readonly property bool opening: initAnim.running
  readonly property bool closing: unlockAnim.running

  // What a follower reads.
  property alias bgRadius: cardBg.radius
  property alias iconRotation: lockIcon.rotation
  property alias iconOpacity: lockIcon.opacity
  property alias contentOpacity: content.opacity
  property alias contentScale: content.scale
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
    released = true
    unlockAnim.start()
  }

  component Follow: Binding {
    when: root.following
    restoreMode: Binding.RestoreNone
  }
  Follow { target: root; property: "scale"; value: root.follow ? root.follow.scale : 0 }
  Follow { target: root; property: "rotation"; value: root.follow ? root.follow.rotation : 0 }
  Follow { target: root; property: "opacity"; value: root.follow ? root.follow.opacity : 0 }
  Follow { target: root; property: "implicitWidth"; value: root.follow ? root.follow.implicitWidth : 0 }
  Follow { target: root; property: "implicitHeight"; value: root.follow ? root.follow.implicitHeight : 0 }
  Follow { target: cardBg; property: "radius"; value: root.follow ? root.follow.bgRadius : 0 }
  Follow { target: lockIcon; property: "rotation"; value: root.follow ? root.follow.iconRotation : 0 }
  Follow { target: lockIcon; property: "opacity"; value: root.follow ? root.follow.iconOpacity : 0 }
  Follow { target: content; property: "opacity"; value: root.follow ? root.follow.contentOpacity : 0 }
  Follow { target: content; property: "scale"; value: root.follow ? root.follow.contentScale : 0 }

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

  // Caelestia's unlockAnim, as is: the content shrinks away and fades, the
  // card closes back to the lock-icon square (no spin) as the icon fades
  // back in, the backdrop fades out, and the square fades out last.
  ParallelAnimation {
    id: unlockAnim

    onFinished: root.closeFinished()

    Anim {
      target: root
      properties: "implicitWidth,implicitHeight"
      to: root.size
    }
    Anim {
      target: cardBg
      property: "radius"
      to: root.closedRadius
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
      target: root.backdrop
      property: "opacity"
      to: 0
      type: "standardLarge"
    }
    SequentialAnimation {
      PauseAnimation {
        duration: Tk.durations.small
      }
      Anim {
        type: "standard"
        target: root
        property: "opacity"
        to: 0
      }
    }
  }
}
