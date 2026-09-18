import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// Everything on one monitor, laid out like Caelestia's drawers window: a
// full-screen layer whose background is one SDF blob (frame + drawers, with a
// soft shadow), the bar on the left, and drawers that grow out of the frame.
Scope {
  id: scope

  required property var modelData
  required property var host
  readonly property var screen: modelData
  readonly property var monitor: Hyprland.monitorFor(screen)

  // ---------------------------------------------------------- state
  property bool launcher: false
  property bool dashboard: false
  property bool session: false
  property bool dashShortcut: false
  property string popout: ""
  property real popoutCenter: 0
  property var trayItem: null

  function closeAll() {
    launcher = false; session = false; dashboard = false; dashShortcut = false; popout = ""
  }

  Connections {
    target: scope.host
    function onToggleRequested(name, screenName) {
      if (screenName !== scope.screen.name) return
      if (name === "close") { scope.closeAll(); return }
      if (name === "launcher") scope.launcher = !scope.launcher
      else if (name === "session") scope.session = !scope.session
      else if (name === "dashboard") { scope.dashboard = !scope.dashboard; scope.dashShortcut = scope.dashboard }
    }
  }

  // ------------------------------------------------------ fullscreen
  readonly property bool hasFullscreen: {
    const ws = monitor ? monitor.activeWorkspace : null
    return !!(ws && ws.lastIpcObject && ws.lastIpcObject.hasfullscreen)
  }
  Connections {
    target: Hyprland
    function onRawEvent(e) { if (e.name === "fullscreen" || e.name === "workspace" || e.name === "closewindow") Hyprland.refreshWorkspaces() }
  }
  onHasFullscreenChanged: closeAll()

  // --------------------------------------------- reserved screen edges
  component Reserve: PanelWindow {
    screen: scope.screen
    visible: !scope.host.barHidden
    WlrLayershell.namespace: "omacale-reserve"
    mask: Region {}
    implicitWidth: 1
    implicitHeight: 1
    color: "transparent"
  }
  Reserve { anchors.left: true; exclusiveZone: Tk.barWidth }
  Reserve { anchors.top: true; exclusiveZone: Tk.border }
  Reserve { anchors.right: true; exclusiveZone: Tk.border }
  Reserve { anchors.bottom: true; exclusiveZone: Tk.border }

  PanelWindow {
    id: win

    screen: scope.screen
    visible: !scope.host.barHidden
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omacale"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: scope.launcher || scope.session ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    anchors { top: true; bottom: true; left: true; right: true }

    // Fullscreen collapses the frame into the screen edges.
    property real fs: scope.hasFullscreen ? 1 : 0
    Behavior on fs { Anim {} }

    readonly property real bw: Tk.barWidth * (1 - fs)
    readonly property real bt: Tk.border * (1 - fs)
    // Panel area (Caelestia's Panels item)
    readonly property real ax: bw
    readonly property real ay: bt
    readonly property real aw: width - bw - bt
    readonly property real ah: height - 2 * bt

    // -------------------------------------------------- drawer motion
    property real dOff: scope.dashboard ? 0 : 1
    property real lOff: scope.launcher ? 0 : 1
    property real sOff: scope.session ? 0 : 1
    property real pOff: scope.popout !== "" ? 0 : 1
    Behavior on dOff { Anim {} }
    Behavior on lOff { Anim {} }
    Behavior on sOff { Anim {} }
    Behavior on pOff { Anim {} }

    // Dashboard (top centre)
    readonly property real dw: dash.implicitWidth || 854
    readonly property real dh: dash.implicitHeight
    readonly property real dx: ax + (aw - dw) / 2
    readonly property real dy: ay + (-dh - 5) * dOff
    // Launcher (bottom centre)
    readonly property real lw: launch.implicitWidth
    property real lh: launch.implicitHeight
    readonly property real lx: ax + (aw - lw) / 2
    readonly property real ly: ay + ah - lh + (lh + 5) * lOff
    // Session (right centre)
    readonly property real sw: sess.implicitWidth
    readonly property real sh: sess.implicitHeight
    readonly property real sx: ax + aw - sw + (sw + 5) * sOff
    readonly property real sy: ay + (ah - sh) / 2
    // Popout (left, beside the bar)
    property real pw: pop.implicitWidth + Tk.padding.large * 2
    property real ph: pop.implicitHeight + Tk.padding.large * 2
    Behavior on pw { enabled: win.pOff < 1; Anim {} }
    Behavior on ph { enabled: win.pOff < 1; Anim {} }
    property real py: {
      const off = scope.popoutCenter - bt - ph / 2
      return ay + Math.max(0, Math.min(off, ah - ph))
    }
    Behavior on py { enabled: win.pOff < 1; Anim {} }
    readonly property real px: ax + (-pw - 5) * pOff

    // ------------------------------------------------------ input mask
    readonly property bool dVis: dOff < 1
    readonly property bool lVis: lOff < 1
    readonly property bool sVis: sOff < 1
    readonly property bool pVis: pOff < 1

    mask: Region {
      x: win.fs >= 1 ? 0 : win.ax
      y: win.fs >= 1 ? 0 : win.ay
      width: win.fs >= 1 ? win.width : win.aw
      height: win.fs >= 1 ? win.height : win.ah
      intersection: Intersection.Xor
      Region { intersection: Intersection.Subtract; x: win.dx; y: win.ay; width: win.dVis ? win.dw : 0; height: win.dVis ? Math.max(0, win.dy + win.dh - win.ay) : 0 }
      Region { intersection: Intersection.Subtract; x: win.lx; y: win.ly; width: win.lVis ? win.lw : 0; height: win.lVis ? Math.max(0, win.ay + win.ah - win.ly) : 0 }
      Region { intersection: Intersection.Subtract; x: win.sx; y: win.sy; width: win.sVis ? Math.max(0, win.ax + win.aw - win.sx) : 0; height: win.sVis ? win.sh : 0 }
      Region { intersection: Intersection.Subtract; x: win.ax; y: win.py; width: win.pVis ? Math.max(0, win.px + win.pw - win.ax) : 0; height: win.pVis ? win.ph : 0 }
    }

    HyprlandFocusGrab {
      windows: [win]
      active: scope.launcher || scope.session || (scope.dashboard && scope.dashShortcut) || (scope.popout === "traymenu")
      onCleared: scope.closeAll()
    }

    // ---------------------------------------------------- background
    Item {
      anchors.fill: parent
      layer.enabled: true
      layer.effect: MultiEffect {
        shadowEnabled: true
        blurMax: 15
        shadowColor: Qt.alpha(Colours.m3shadow, 0.7 * (1 - win.fs))
      }

      ShaderEffect {
        anchors.fill: parent
        fragmentShader: Qt.resolvedUrl("shaders/blob.frag.qsb")

        property size res: Qt.size(width, height)
        property real smoothing: Tk.smoothing
        property real holeRadius: Tk.borderRounding * (1 - win.fs)
        property real panelRadius: Tk.rounding.extraLarge
        property rect hole: Qt.rect(win.ax, win.ay, win.aw, win.ah)
        property color color: Colours.m3surface
        property rect r0: win.dVis ? Qt.rect(win.dx, win.dy, win.dw, win.dh) : Qt.rect(0, 0, 0, 0)
        property rect r1: win.lVis ? Qt.rect(win.lx, win.ly, win.lw, win.lh) : Qt.rect(0, 0, 0, 0)
        property rect r2: win.sVis ? Qt.rect(win.sx, win.sy, win.sw, win.sh) : Qt.rect(0, 0, 0, 0)
        // Popout background reaches 20% behind the bar so it never detaches.
        property rect r3: win.pVis ? Qt.rect(win.px - win.pw * 0.2, win.py, win.pw * 1.2, win.ph) : Qt.rect(0, 0, 0, 0)
        property rect r4: Qt.rect(0, 0, 0, 0)
        property rect r5: Qt.rect(0, 0, 0, 0)

        Behavior on color { CAnim {} }
      }
    }

    // ---------------------------------------------------- interactions
    MouseArea {
      id: interactions
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: win.fs > 0 ? Qt.NoButton : Qt.AllButtons
      property point dragStart

      function inPopout(x, y) {
        return x < win.px + win.pw + Tk.borderRounding && y >= win.py - Tk.borderRounding && y <= win.py + win.ph + Tk.borderRounding
      }
      function inTopDash(x, y) {
        const visibleH = win.dh * (1 - win.dOff)
        return y < Math.max(Tk.border, win.bt + visibleH) && x >= win.dx - Tk.borderRounding && x <= win.dx + win.dw + Tk.borderRounding
      }

      onPressed: e => dragStart = Qt.point(e.x, e.y)
      onContainsMouseChanged: {
        if (containsMouse) return
        if (!scope.dashShortcut) scope.dashboard = false
        if (scope.popout !== "traymenu") scope.popout = ""
      }
      onWheel: e => { if (e.x < win.bw) bar.handleWheel(e.y, e.angleDelta.y) }
      onPositionChanged: e => {
        if (win.fs > 0) return
        const x = e.x, y = e.y, dx = x - dragStart.x, dy = y - dragStart.y

        // Session: drag in from the right edge.
        if (pressed && dragStart.x > win.ax + win.aw - Tk.borderRounding && Math.abs(y - (win.sy + win.sh / 2)) < win.sh / 2 + Tk.borderRounding) {
          if (dx < -30) scope.session = true
          else if (dx > 30) scope.session = false
        }
        // Launcher: drag up from the bottom edge.
        if (pressed && dragStart.y > win.ay + win.ah - Tk.borderRounding && x >= win.lx - Tk.borderRounding && x <= win.lx + win.lw + Tk.borderRounding) {
          if (dy < -50) scope.launcher = true
          else if (dy > 50) scope.launcher = false
        }
        // Dashboard: hover the top edge.
        const showDash = inTopDash(x, y)
        if (!scope.dashShortcut) scope.dashboard = showDash
        else if (showDash) scope.dashShortcut = false

        // Popouts: hover bar entries.
        if (x < win.bw) {
          const p = bar.popoutAt(y)
          if (p) {
            if (p.name === "traymenu") {
              if (scope.popout !== "traymenu" || scope.trayItem !== p.item) { scope.trayItem = p.item; scope.popout = "" ; scope.popout = "traymenu" }
            } else scope.popout = p.name
            scope.popoutCenter = p.center
          } else if (scope.popout !== "traymenu") scope.popout = ""
        } else if (scope.popout !== "traymenu" && !inPopout(x, y)) {
          scope.popout = ""
        }
      }

      BarContent {
        id: bar
        x: -Tk.barWidth * win.fs
        width: Tk.barWidth
        height: win.height
        opacity: 1 - win.fs
        screen: scope.screen
        host: scope.host
        scope: scope
      }

      // ---- popout
      Item {
        x: win.ax
        y: win.py
        width: Math.max(0, win.px + win.pw - win.ax)
        height: win.ph
        visible: win.pVis
        clip: true
        Item {
          x: win.px - win.ax
          width: win.pw
          height: win.ph
          opacity: 1 - win.pOff
          PopoutContent {
            id: pop
            x: Tk.padding.large
            y: Tk.padding.large
            width: implicitWidth
            height: implicitHeight
            host: scope.host
            trayItem: scope.trayItem
            property string lastName: ""
            name: scope.popout !== "" ? scope.popout : lastName
            onNameChanged: if (scope.popout !== "") lastName = scope.popout
            onCloseRequested: scope.popout = ""
          }
        }
      }

      // ---- dashboard
      Dashboard {
        id: dash
        x: win.dx
        y: win.dy
        width: win.dw
        height: win.dh
        visible: win.dVis
        opacity: 1 - win.dOff
        host: scope.host
        active: scope.dashboard
      }

      // ---- launcher
      Launcher {
        id: launch
        x: win.lx
        y: win.ly
        width: win.lw
        height: win.lh
        visible: win.lVis
        opacity: 1 - win.lOff
        active: scope.launcher
        maxHeight: win.ah - (scope.dashboard ? win.dh : 0) + Tk.padding.extraLarge
        onDismissed: scope.launcher = false
      }

      // ---- session
      Session {
        id: sess
        x: win.sx
        y: win.sy
        visible: win.sVis
        opacity: 1 - win.sOff
        active: scope.session
        onDismissed: scope.session = false
      }
    }
  }
}
