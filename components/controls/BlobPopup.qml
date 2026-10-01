import QtQuick
import "../.."

// Caelestia nexus/common/BlobPopup.qml (and dashboard/media/LyricsInfo.qml,
// which is the same thing with its own content): a small blob group of two
// shapes. An icon button's blob, which swells on hover, and a second blob
// that starts as the button and, on open, slides up and out to the left and
// grows to hold `content`, the two melting into each other on the way
// (smoothing rounding.medium, no corner fill).
Item {
  id: root

  property string icon: "more_vert"
  property color color: Colours.m3surfaceContainerHighest
  property bool open: false
  // Inside the popup, around the content.
  property real padding: Tk.padding.large
  // How far above the button the popup's top goes.
  property real topMovement: Tk.padding.medium
  property real popupRadius: Tk.rounding.large
  // Hover/press driven from elsewhere (a row the button sits in).
  property bool pressOverride: false
  property bool hoverOverride: false
  readonly property bool hovered: btn.containsMouse
  // 0 closed .. 1 open, on the effects curve: the content's opacity.
  property real animDriver: open ? 1 : 0
  Behavior on animDriver { Anim { type: "effects" } }
  default property Item content

  implicitWidth: btn.implicitWidth * 0.9
  implicitHeight: btn.implicitHeight * 0.9
  z: open || animDriver > 0 ? 10 : 0

  Behavior on color { CAnim {} }

  // ------------------------------------------------------ the two blobs
  // The button's: grows by extraSmall on hover, and again while open.
  property real btnGrow: (!(btn.pressed || pressOverride) && (btn.containsMouse || hoverOverride) ? Tk.padding.extraSmall : 0)
    + (open ? Tk.padding.extraSmall : 0)
  Behavior on btnGrow { Anim {} }
  property real btnRadius: open ? Tk.rounding.large : Tk.rounding.medium
  Behavior on btnRadius { Anim { type: "effects" } }

  // The popup's, anchored to the button's top-right: open, its right edge
  // comes in to spacing.small from the button's left, and it rises by
  // topMovement (on the fast spatial curve, as Caelestia's transition).
  property real popRight: open ? width - Tk.spacing.small : 0
  property real popTop: open ? topMovement : 0
  property real popW: open ? (content ? content.implicitWidth : 0) + padding * 2 : width
  property real popH: open ? (content ? content.implicitHeight : 0) + padding * 2 : height
  Behavior on popRight { Anim {} }
  Behavior on popW { Anim {} }
  Behavior on popTop { Anim { type: "fastSpatial" } }
  Behavior on popH { Anim { type: "fastSpatial" } }
  readonly property real popX: width - popRight - popW
  readonly property real popY: -popTop

  BlobDeform { id: popDeform; amount: 0.1; cx: root.popX + root.popW / 2; cy: root.popY + root.popH / 2 }

  // One surface over both shapes, with room for the blend to spill.
  BlobSurface {
    readonly property real pad: Tk.rounding.medium * 2
    x: Math.min(-root.btnGrow, root.popX) - pad
    y: Math.min(-root.btnGrow, root.popY) - pad
    width: Math.max(root.width + root.btnGrow, root.popX + root.popW) - x + pad
    height: Math.max(root.height + root.btnGrow, root.popY + root.popH) - y + pad
    framed: false
    cornerFill: false
    smoothing: Tk.rounding.medium
    color: root.color
    rects: [
      [-root.btnGrow - x, -root.btnGrow - y, root.width + root.btnGrow * 2, root.height + root.btnGrow * 2],
      [root.popX - x, root.popY - y, root.popW, root.popH]
    ]
    corners: [root.btnRadius, root.popupRadius]
    deforms: [null, popDeform.vec]
  }

  // The popup's content, clipped to its blob.
  MouseArea {
    x: root.popX
    y: root.popY
    width: root.popW
    height: root.popH
    clip: true
    visible: root.animDriver > 0
    Item {
      anchors.centerIn: parent
      width: root.content ? root.content.implicitWidth : 0
      height: root.content ? root.content.implicitHeight : 0
      opacity: root.animDriver
      children: root.content ? [root.content] : []
    }
  }
  // The content is laid out at its own size, however big the blob is on
  // its way there.
  Binding { target: root.content; property: "width"; value: root.content ? root.content.implicitWidth : 0; when: !!root.content }
  Binding { target: root.content; property: "height"; value: root.content ? root.content.implicitHeight : 0; when: !!root.content }

  MouseArea {
    id: btn
    anchors.centerIn: parent
    implicitWidth: implicitHeight
    implicitHeight: glyph.implicitHeight + Tk.padding.extraSmall * 2
    width: implicitWidth
    height: implicitHeight
    cursorShape: Qt.PointingHandCursor
    hoverEnabled: true
    onClicked: root.open = !root.open

    MIcon {
      id: glyph
      anchors.centerIn: parent
      text: root.icon
      size: Tk.iconSize.medium
      color: Colours.m3onSurfaceVariant
    }
  }
}
