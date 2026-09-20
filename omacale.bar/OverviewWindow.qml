import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland

// One window inside the overview grid: its live surface scaled down into the
// workspace tile it lives on, with the app icon over it.
//
// No Caelestia original -- the feature is ported from the omarchy-overview
// plugin (modules/overview/OverviewWindow.qml), redrawn in Omacale's tokens.
// Caelestia's own live preview (the active-window popout, PopoutContent.qml)
// is what the ScreencopyView + rounded mask here follows.
Item {
  id: root

  required property var toplevel            // HyprlandToplevel
  readonly property var d: toplevel && toplevel.lastIpcObject ? toplevel.lastIpcObject : ({})
  property bool showIcon: true
  property bool live: true
  property int radius: Tk.rounding.large
  readonly property real effectiveRadius: Math.min(radius, Math.min(width, height) / 2)
  // Where the tile sits when it is not being dragged; the drag handler puts it
  // back here when the drop goes nowhere.
  property real homeX: 0
  property real homeY: 0
  property bool dragging: false

  signal activated
  signal closeRequested
  signal dragStarted
  signal dropped

  readonly property string appId: String(d.class || "")
  readonly property string title: String(d.title || "")
  readonly property string address: String(d.address || "")
  readonly property var entry: appId ? DesktopEntries.heuristicLookup(appId) : null
  readonly property bool hovered: mouse.containsMouse

  // The preview keeps the window's own aspect, letterboxed inside the tile:
  // the tile is clamped to the workspace, so a window hanging off the edge
  // must not stretch.
  readonly property real ratio: {
    const w = d.size ? d.size[0] : 0, h = d.size ? d.size[1] : 0
    return w > 0 && h > 0 ? w / h : 16 / 9
  }

  // Not a binding: dragging the item writes x/y itself, which would break one
  // for good. Follow `home*` by hand instead, so the tile slides back after a
  // drop that went nowhere and follows the window after one that landed.
  onHomeXChanged: if (!dragging) x = homeX
  onHomeYChanged: if (!dragging) y = homeY
  onDraggingChanged: if (!dragging) { x = homeX; y = homeY }
  Component.onCompleted: { x = homeX; y = homeY }
  Behavior on x { enabled: !root.dragging; Anim { type: "fastSpatial" } }
  Behavior on y { enabled: !root.dragging; Anim { type: "fastSpatial" } }

  Drag.active: dragging
  Drag.source: root
  Drag.hotSpot.x: width / 2
  Drag.hotSpot.y: height / 2

  // Rounded corners by clipping, not by a masked layer: a ShaderEffectSource
  // per window crashed the scene graph once three of them were on screen
  // ("Cannot use same item on different windows at the same time"), and
  // Caelestia clips its own previews the same way (windowinfo/Preview.qml).
  ClippingRectangle {
    anchors.fill: parent
    radius: root.effectiveRadius
    color: Colours.m3surfaceContainerHigh

    ScreencopyView {
      id: preview
      anchors.centerIn: parent
      width: Math.min(parent.width, parent.height * root.ratio)
      height: Math.min(parent.height, parent.width / root.ratio)
      captureSource: root.toplevel ? root.toplevel.wayland : null
      live: root.live
    }

    IconImage {
      anchors.centerIn: parent
      asynchronous: true
      visible: root.showIcon && implicitSize >= 16
      implicitSize: Math.round(Math.min(parent.width, parent.height) * 0.4)
      source: Quickshell.iconPath(root.entry ? root.entry.icon : "", "image-missing")
      opacity: root.hovered ? 1 : 0.85
      Behavior on opacity { Anim { type: "effects" } }
    }
  }

  // Hover veil and outline, as an M3 state layer on a surface this size does.
  Rectangle {
    anchors.fill: parent
    radius: root.effectiveRadius
    color: mouse.pressed ? Qt.alpha(Colours.m3onSurface, 0.12)
         : root.hovered ? Qt.alpha(Colours.m3onSurface, 0.08) : "transparent"
    border.width: root.hovered || root.dragging ? 2 : 1
    border.color: root.hovered || root.dragging ? Colours.m3primary : Colours.m3outlineVariant
    Behavior on color { CAnim {} }
    Behavior on border.color { CAnim {} }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    drag.target: root
    drag.threshold: 8

    onPressed: e => {
      if (e.button === Qt.LeftButton) root.z = 1000
    }
    onPositionChanged: {
      if (drag.active && !root.dragging) {
        root.dragging = true
        root.dragStarted()
      }
    }
    onReleased: {
      root.z = 0
      // Report the drop before clearing the drag: dropping `Drag.active`
      // first makes the workspace under the cursor fire its DropArea exit,
      // which takes the drop target away again.
      if (root.dragging) {
        root.dropped()
        root.dragging = false
      }
    }
    onClicked: e => {
      if (e.button === Qt.MiddleButton) root.closeRequested()
      else root.activated()
    }
  }
}
