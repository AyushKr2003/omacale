import QtQuick
import Quickshell
import Quickshell.Hyprland

// Workspace overview: this monitor's workspaces as a grid of live window
// previews. Click a workspace to switch, click a window to focus it, drag a
// window onto another workspace to move it.
//
// No Caelestia original -- the feature is ported from the omarchy-overview
// plugin (modules/overview/OverviewWidget.qml), redrawn in Omacale's tokens.
// The data is Hyprland's own (Quickshell's Hyprland IPC), not the plugin's
// `hyprctl` polling service.
Item {
  id: root

  required property var screen
  property bool active: false
  signal dismissed

  readonly property var cfg: Config.o.overview
  readonly property var monitor: Hyprland.monitorFor(screen)
  readonly property var mon: monitor && monitor.lastIpcObject ? monitor.lastIpcObject : null
  readonly property int monId: monitor ? monitor.id : -1

  // ------------------------------------------------------------ geometry
  // A tile stands for the monitor's usable area: Hyprland's reserved edges
  // are Omacale's own frame, and no window is ever drawn under it.
  function res(i) { return mon && mon.reserved ? (mon.reserved[i] || 0) : 0 }
  readonly property real monScale: mon && mon.scale ? mon.scale : 1
  readonly property bool swapped: mon ? (mon.transform % 2 === 1) : false
  readonly property real rawW: mon ? (swapped ? mon.height : mon.width) / monScale : screen.width
  readonly property real rawH: mon ? (swapped ? mon.width : mon.height) / monScale : screen.height
  readonly property real usableW: Math.max(1, rawW - res(0) - res(2))
  readonly property real usableH: Math.max(1, rawH - res(1) - res(3))

  readonly property int rows: Math.max(1, cfg.rows)
  readonly property int cols: Math.max(1, cfg.columns)
  readonly property int perGroup: rows * cols
  readonly property int gap: Tk.spacing.medium

  readonly property int activeId: monitor && monitor.activeWorkspace ? Math.max(1, monitor.activeWorkspace.id) : 1
  readonly property int group: Math.max(0, Math.floor((activeId - 1) / perGroup))

  // The configured scale is a ceiling: the grid always has to fit the screen,
  // however many rows and columns are asked for.
  // The card's inset is the tile gap, so the outer border reads as one more
  // gutter (the bar pads its workspace pill the same way).
  readonly property int pad: Tk.padding.medium
  readonly property real fitW: (screen.width * 0.94 - pad * 2 - (cols - 1) * gap) / cols / usableW
  readonly property real fitH: (screen.height * 0.86 - pad * 2 - (shownRows.length - 1) * gap) / shownRows.length / usableH
  readonly property real tileScale: Math.max(0.02, Math.min(cfg.scale, fitW, fitH))
  readonly property real tileW: Math.round(usableW * tileScale)
  readonly property real tileH: Math.round(usableH * tileScale)

  readonly property real gridW: cols * tileW + (cols - 1) * gap
  readonly property real gridH: shownRows.length * tileH + (shownRows.length - 1) * gap

  // ------------------------------------------------------------ workspaces
  function wsId(r, c) { return group * perGroup + r * cols + c + 1 }
  function rowOf(id) { return Math.floor((id - 1 - group * perGroup) / cols) }
  function colOf(id) { return (id - 1 - group * perGroup) % cols }
  function wsObject(id) {
    const v = Hyprland.workspaces.values
    for (let i = 0; i < v.length; i++) if (v[i].id === id) return v[i]
    return null
  }
  function wsWindows(id) {
    const o = wsObject(id)
    return o && o.toplevels ? o.toplevels.values.length : 0
  }
  function rowHasContent(r) {
    for (let c = 0; c < cols; c++) {
      const id = wsId(r, c)
      if (id === activeId || wsWindows(id) > 0) return true
    }
    return false
  }
  // Rows that are drawn, in order; an empty grid still shows its first row.
  readonly property var shownRows: {
    const out = []
    for (let r = 0; r < rows; r++) if (!cfg.hideEmptyRows || rowHasContent(r)) out.push(r)
    return out.length ? out : [0]
  }
  function cellX(id) { return colOf(id) * (tileW + gap) }
  function cellY(id) {
    const v = shownRows.indexOf(rowOf(id))
    return (v < 0 ? 0 : v) * (tileH + gap)
  }

  // ------------------------------------------------------------ windows
  // Hyprland's stacking order, as the overview plugin sorts it: pinned over
  // floating over tiled, then most recently focused on top.
  readonly property var wins: {
    const out = []
    const vals = Hyprland.toplevels.values
    const lo = group * perGroup + 1, hi = lo + perGroup - 1
    for (let i = 0; i < vals.length; i++) {
      const t = vals[i]
      const d = t.lastIpcObject
      if (!d || !d.size || !d.at) continue
      if ((d.monitor === undefined ? -1 : d.monitor) !== monId) continue
      const id = d.workspace ? d.workspace.id : 0
      if (id < lo || id > hi) continue
      out.push(t)
    }
    return out.sort((a, b) => {
      const x = a.lastIpcObject, y = b.lastIpcObject
      if (!!x.pinned !== !!y.pinned) return x.pinned ? 1 : -1
      if (!!x.floating !== !!y.floating) return x.floating ? 1 : -1
      return (y.focusHistoryID || 0) - (x.focusHistoryID || 0)
    })
  }

  property int dropTarget: -1

  // Hyprland only reports window geometry on demand, and the overview is the
  // one place that needs all of it at once.
  function refresh() {
    Hyprland.refreshToplevels()
    Hyprland.refreshWorkspaces()
    Hyprland.refreshMonitors()
  }
  onActiveChanged: {
    if (active) refresh()
    else dropTarget = -1
  }
  // Only the events that move a window or change what is on a workspace; the
  // raw stream also carries volume, screencast and focus chatter.
  readonly property var watched: ["openwindow", "closewindow", "movewindow", "windowtitle", "workspace",
    "createworkspace", "destroyworkspace", "fullscreen", "changefloatingmode", "pin", "monitoradded", "monitorremoved"]
  Connections {
    target: Hyprland
    enabled: root.active
    function onRawEvent(e) {
      if (e.name.endsWith("v2")) return
      if (root.watched.indexOf(e.name) >= 0) root.refresh()
    }
  }

  // ------------------------------------------------------------ keys
  Keys.onPressed: e => {
    if (e.key === Qt.Key_Escape || e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
      root.dismissed()
      e.accepted = true
      return
    }

    let r = rowOf(activeId), c = colOf(activeId), moved = false, target = -1
    if (e.key === Qt.Key_Left || e.key === Qt.Key_H) { c = (c - 1 + cols) % cols; moved = true }
    else if (e.key === Qt.Key_Right || e.key === Qt.Key_L) { c = (c + 1) % cols; moved = true }
    else if (e.key === Qt.Key_Up || e.key === Qt.Key_K) { r = (r - 1 + rows) % rows; moved = true }
    else if (e.key === Qt.Key_Down || e.key === Qt.Key_J) { r = (r + 1) % rows; moved = true }
    else if (e.key >= Qt.Key_1 && e.key <= Qt.Key_9) {
      const n = e.key - Qt.Key_0
      if (n <= perGroup) target = group * perGroup + n
    } else if (e.key === Qt.Key_0 && perGroup >= 10) target = group * perGroup + 10

    if (moved) target = wsId(r, c)
    if (target > 0) {
      Sys.workspace(target)
      e.accepted = true
    }
  }

  implicitWidth: card.implicitWidth
  implicitHeight: card.implicitHeight

  Rectangle {
    id: card

    anchors.centerIn: parent
    implicitWidth: grid.width + root.pad * 2
    implicitHeight: grid.height + root.pad * 2
    // The frame's own corner and surface, so the overview reads as the bar
    // and its drawers do.
    radius: Tk.borderRounding
    color: Colours.m3surface
    Behavior on implicitWidth { Anim {} }
    Behavior on implicitHeight { Anim {} }

    Elevation {
      anchors.fill: parent
      radius: parent.radius
      level: 3
      z: -1
    }

    Item {
      id: grid

      anchors.centerIn: parent
      width: root.gridW
      height: root.gridH
      Behavior on width { Anim {} }
      Behavior on height { Anim {} }

      // ---- workspaces
      Repeater {
        model: root.perGroup

        Rectangle {
          id: tile

          required property int index
          readonly property int wsId: root.group * root.perGroup + index + 1
          readonly property bool shown: root.shownRows.indexOf(root.rowOf(wsId)) >= 0
          readonly property bool focused: wsId === root.activeId
          readonly property bool dropping: root.dropTarget === wsId

          x: root.cellX(wsId)
          y: root.cellY(wsId)
          width: root.tileW
          height: root.tileH
          visible: shown
          radius: Tk.rounding.medium
          color: dropping ? Qt.alpha(Colours.m3tertiary, 0.18)
               : focused ? Qt.alpha(Colours.m3primary, 0.12)
               : Colours.m3surfaceContainer
          border.width: dropping || focused ? 2 : 0
          border.color: dropping ? Colours.m3tertiary : Colours.m3primary
          Behavior on x { Anim { type: "fastSpatial" } }
          Behavior on y { Anim { type: "fastSpatial" } }
          Behavior on color { CAnim {} }

          MText {
            anchors.centerIn: parent
            text: tile.wsId
            font.family: Tk.clock
            font.pointSize: Math.max(Tk.body.small, Math.round(tile.height / 4))
            weight: Font.DemiBold
            // Workspaces.qml `fg`: lit for the focused workspace, outline for
            // one with nothing on it.
            color: tile.focused ? Colours.m3onSurface : Colours.m3outlineVariant
          }

          StateLayer {
            radius: tile.radius
            color: Colours.m3onSurface
            onClicked: {
              Sys.workspace(tile.wsId)
              root.dismissed()
            }
          }

          DropArea {
            anchors.fill: parent
            onEntered: root.dropTarget = tile.wsId
            onExited: if (root.dropTarget === tile.wsId) root.dropTarget = -1
          }
        }
      }

      // ---- windows
      Repeater {
        model: ScriptModel { values: root.wins }

        OverviewWindow {
          id: win

          required property var modelData
          readonly property var d: modelData.lastIpcObject
          readonly property int wsId: d && d.workspace ? d.workspace.id : 0
          readonly property real relX: Math.max(0, (d.at[0] - (root.mon ? root.mon.x : 0) - root.res(0)) * root.tileScale)
          readonly property real relY: Math.max(0, (d.at[1] - (root.mon ? root.mon.y : 0) - root.res(1)) * root.tileScale)

          toplevel: modelData
          showIcon: root.cfg.showIcons
          live: root.active && root.cfg.previews
          width: Math.max(8, Math.min(d.size[0] * root.tileScale, root.tileW))
          height: Math.max(8, Math.min(d.size[1] * root.tileScale, root.tileH))
          homeX: root.cellX(wsId) + Math.min(relX, root.tileW - width)
          homeY: root.cellY(wsId) + Math.min(relY, root.tileH - height)
          visible: root.shownRows.indexOf(root.rowOf(wsId)) >= 0

          onActivated: {
            Sys.focusWindow(address)
            root.dismissed()
          }
          onCloseRequested: Sys.closeWindow(address)
          onDragStarted: root.dropTarget = -1
          onDropped: {
            const target = root.dropTarget
            root.dropTarget = -1
            if (target > 0 && target !== wsId) Sys.moveWindow(address, target)
          }
        }
      }
    }
  }
}
