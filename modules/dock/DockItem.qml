import QtQuick
import Quickshell.Widgets
import "../.."

// One app in the dock: its icon on a rounded cell, and a dot per open window
// (up to three) on the side facing the dock's edge, the active app's in
// m3primary. No Caelestia original (Caelestia has no dock); the cell is drawn
// like the launcher's rows (StateLayer on a rounded surface).
Item {
  id: root

  // The app (DockService.items entry); set by the dock, which keeps this
  // icon alive across rebuilds of its list.
  property var modelData: ({ windows: [], active: false, icon: "", name: "" })
  property real cell: Tk.px(48)
  property string edge: "bottom"
  property bool menuShown: false
  // The dock's magnification of this icon; it grows away from the edge.
  property real mag: 1

  signal menuRequested
  // A drag along the dock: how far from where it was pressed.
  signal dragMoved(real offset)
  signal dragEnded(real offset)
  readonly property bool vert: edge === "left" || edge === "right"

  transform: Scale {
    origin.x: root.edge === "left" ? 0 : root.edge === "right" ? root.width : root.width / 2
    origin.y: root.edge === "top" ? 0 : root.edge === "bottom" ? root.height : root.height / 2
    xScale: root.mag
    yScale: root.mag
  }

  readonly property int dots: Math.min(3, modelData.windows.length)

  implicitWidth: cell
  implicitHeight: cell

  Rectangle {
    id: bg
    anchors.fill: parent
    radius: Tk.rounding.large
    // Only the app whose menu is open gets a tile; the active one is told by
    // its dot, so every icon sits on the plate the same way.
    color: root.menuShown ? Colours.m3surfaceContainerHighest : "transparent"
    Behavior on color { CAnim {} }

    StateLayer {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
      cursorShape: dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
      // Pressed and moved past a few px along the dock: a drag, not a click.
      property real startAlong: 0
      property bool dragging: false
      property real lastD: 0
      // The frame's own MouseArea mustn't take the drag over.
      preventStealing: true
      function along(e) { return root.vert ? mapToItem(null, e.x, e.y).y : mapToItem(null, e.x, e.y).x }
      onPressed: e => { startAlong = along(e); dragging = false; lastD = 0 }
      onPositionChanged: e => {
        if (!pressed || !(pressedButtons & Qt.LeftButton)) return
        const d = along(e) - startAlong
        if (!dragging && Math.abs(d) > 8) dragging = true
        if (dragging) { lastD = d; root.dragMoved(d) }
      }
      onReleased: e => { if (dragging) root.dragEnded(along(e) - startAlong) }
      // A grab taken mid-drag still drops where it was.
      onCanceled: { if (dragging) { dragging = false; root.dragEnded(lastD) } }
      onClicked: e => {
        if (dragging) { dragging = false; return }
        if (e && e.button === Qt.RightButton) root.menuRequested()
        else if (e && e.button === Qt.MiddleButton) DockService.launch(root.modelData)
        else DockService.activate(root.modelData)
      }
    }
  }

  // The cell's edge side holds the window dots (dotRoom), so the icon is
  // centred in what is left and the two never touch.
  readonly property real dotRoom: Tk.px(9)
  readonly property real iconSize: Math.round(Math.min(root.cell * 0.78, root.cell - dotRoom * 2 + Tk.px(6)))
  IconImage {
    implicitSize: root.iconSize
    readonly property real away: (root.dotRoom - (root.cell - root.iconSize) / 2) > 0 ? root.dotRoom - (root.cell - root.iconSize) / 2 : 0
    x: Math.round((root.width - width) / 2 + (root.edge === "left" ? away : root.edge === "right" ? -away : 0))
    y: Math.round((root.height - height) / 2 + (root.edge === "top" ? away : root.edge === "bottom" ? -away : 0))
    asynchronous: true
    source: root.modelData.icon
  }

  // The window dots, on the edge side of the cell.
  Grid {
    readonly property bool vert: root.edge === "left" || root.edge === "right"
    columns: vert ? 1 : 3
    spacing: Tk.px(3)
    x: root.edge === "left" ? Tk.px(2) : root.edge === "right" ? root.width - width - Tk.px(2) : Math.round((root.width - width) / 2)
    y: root.edge === "top" ? Tk.px(2) : root.edge === "bottom" ? root.height - height - Tk.px(2) : Math.round((root.height - height) / 2)
    Repeater {
      model: root.dots
      Rectangle {
        width: root.modelData.active && index === 0 ? Tk.px(10) * (parent.vert ? 0.5 : 1) : Tk.px(5)
        height: root.modelData.active && index === 0 ? Tk.px(10) * (parent.vert ? 1 : 0.5) : Tk.px(5)
        radius: Tk.rounding.full
        color: root.modelData.active ? Colours.m3primary : Colours.m3onSurfaceVariant
        Behavior on width { Anim { type: "fastSpatial" } }
        Behavior on height { Anim { type: "fastSpatial" } }
      }
    }
  }
}
