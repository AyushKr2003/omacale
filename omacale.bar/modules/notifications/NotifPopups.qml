import QtQuick
import Quickshell
import "../.."

// The toast stack (Caelestia modules/notifications/Content.qml + Wrapper.qml).
//
// Caelestia draws this as one more drawer in the blob frame. Omacale can't:
// the frame lives on Hyprland's *top* layer, which a fullscreen window covers,
// and a notification that a video can hide is not a notification. The stack
// gets its own overlay-layer window in ScreenScope instead, so each toast is
// a card in its own right rather than content inset into the frame.
Item {
  id: root

  // Toasts stay out of the way of the notification centre, which shows the
  // same notifications in full (Caelestia's Notifs.shouldShowPopup).
  property bool suppressed: false
  readonly property int count: list.count

  implicitWidth: Tk.sizes.notifsWidth
  implicitHeight: {
    const n = list.count
    if (n === 0) return 0
    let height = (n - 1) * Tk.spacing.medium
    for (let i = 0; i < n; i++) height += (list.itemAtIndex(i)?.nonAnimHeight ?? 0)
    return Math.min(root.maxHeight, height)
  }
  Behavior on implicitHeight { Anim {} }

  // How tall the column may grow before it starts scrolling under the
  // "+n" indicators. Set by the window; the screen height by default.
  property real maxHeight: 0

  ListView {
    id: list

    anchors.fill: parent
    clip: true
    interactive: false
    orientation: Qt.Vertical
    spacing: 0
    cacheBuffer: root.maxHeight

    model: ScriptModel {
      values: root.suppressed ? [] : NotifService.popups
    }

    delegate: NotifWrapper {}

    move: Transition { Anim { property: "y" } }
    displaced: Transition { Anim { property: "y" } }

    ExtraIndicator {
      anchors.top: parent.top
      extra: {
        const n = list.count
        if (n === 0) return 0
        const scrollY = list.contentY
        let height = 0
        for (let i = 0; i < n; i++) {
          height += (list.itemAtIndex(i)?.nonAnimHeight ?? 0) + Tk.spacing.medium
          if (height - Tk.spacing.medium >= scrollY) return i
        }
        return n
      }
    }

    ExtraIndicator {
      anchors.bottom: parent.bottom
      extra: {
        const n = list.count
        if (n === 0) return 0
        const scrollY = list.contentHeight - (list.contentY + list.height)
        let height = 0
        for (let i = n - 1; i >= 0; i--) {
          height += (list.itemAtIndex(i)?.nonAnimHeight ?? 0) + Tk.spacing.medium
          if (height - Tk.spacing.medium >= scrollY) return n - i - 1
        }
        return 0
      }
    }
  }

  // Caelestia's NotifWrapper: carries the gap above the toast (so the first
  // one sits flush), and throws the card off screen as it is removed.
  component NotifWrapper: Item {
    id: wrapper

    required property var modelData
    required property int index
    readonly property real nonAnimHeight: notif.nonAnimHeight
    property int idx

    onIndexChanged: if (index !== -1) idx = index

    implicitWidth: root.width
    implicitHeight: notif.implicitHeight + (idx === 0 ? 0 : Tk.spacing.medium)

    ListView.onRemove: removeAnim.start()

    SequentialAnimation {
      id: removeAnim

      PropertyAction { target: wrapper; property: "ListView.delayRemove"; value: true }
      PropertyAction { target: wrapper; property: "enabled"; value: false }
      PropertyAction { target: wrapper; property: "implicitHeight"; value: 0 }
      PropertyAction { target: wrapper; property: "z"; value: 1 }
      Anim {
        target: notif
        property: "x"
        to: (notif.x >= 0 ? root.width : -root.width) * 2
        type: "emphasized"
      }
      PropertyAction { target: wrapper; property: "ListView.delayRemove"; value: false }
    }

    Item {
      anchors.top: parent.top
      anchors.topMargin: wrapper.idx === 0 ? 0 : Tk.spacing.medium
      implicitWidth: notif.implicitWidth
      implicitHeight: notif.implicitHeight

      // Outside the clipper, and following the card rather than the slot, so
      // a toast being thrown away takes its shadow with it. Caelestia's
      // toasts get their depth from the frame blob they sit on; ours float
      // over the wallpaper and need their own.
      Elevation {
        x: notif.x
        y: notif.y
        width: notif.width
        height: notif.height
        radius: notif.radius
        level: 2
        z: -1
      }

      // Clipped to the toast's own slot, so a card being dragged away slides
      // out of view instead of over its neighbours (Caelestia's
      // ClippingRectangle), and an expanding body never spills past it.
      Item {
        anchors.fill: parent
        clip: true

        NotifToast {
          id: notif

          modelData: wrapper.modelData
          implicitWidth: root.width

          onDismissed: NotifService.dismissPopup(wrapper.modelData)
          onClicked: NotifService.invokePopup(wrapper.modelData)
        }
      }
    }
  }

  // Caelestia components/widgets/ExtraIndicator: "+n" for the toasts that
  // scrolled off the top or bottom of a stack taller than the screen.
  component ExtraIndicator: Rectangle {
    id: indicator

    required property int extra

    anchors.right: parent.right
    anchors.margins: Tk.padding.medium

    color: Colours.m3tertiary
    radius: Tk.rounding.medium
    implicitWidth: count.implicitWidth + Tk.padding.medium * 2
    implicitHeight: count.implicitHeight + Tk.padding.small
    z: 2

    opacity: extra > 0 ? 1 : 0
    scale: extra > 0 ? 1 : 0.5
    visible: opacity > 0

    Elevation {
      anchors.fill: parent
      radius: parent.radius
      opacity: parent.opacity
      z: -1
      level: 2
    }

    MText {
      id: count
      anchors.centerIn: parent
      animate: indicator.opacity > 0
      text: `+${indicator.extra}`
      color: Colours.m3onTertiary
    }

    Behavior on opacity { Anim { type: "fastEffects" } }
    Behavior on scale { Anim { type: "fastSpatial" } }
  }
}
