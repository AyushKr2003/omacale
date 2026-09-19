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
  readonly property var cfg: Config.o

  // ---------------------------------------------------------- state
  property bool launcher: false
  property bool dashboard: false
  property bool session: false
  property bool settings: false
  property bool dashShortcut: false
  property bool barHover: false
  property string popout: ""
  property real popoutCenter: 0
  property var trayItem: null

  function closeAll() {
    launcher = false; session = false; dashboard = false; dashShortcut = false; popout = ""; settings = false
  }

  Connections {
    target: scope.host
    function onToggleRequested(name, screenName, arg) {
      if (screenName !== scope.screen.name) return
      if (name === "close") { scope.closeAll(); return }
      if (name === "launcher" && scope.cfg.launcher.enabled) scope.launcher = !scope.launcher
      else if (name === "session" && scope.cfg.session.enabled) scope.session = !scope.session
      else if (name === "settings") scope.settings = !scope.settings
      else if (name === "dashboard" && scope.cfg.dashboard.enabled) {
        if (arg && scope.dashboard) { dash.selectTab(arg); return }
        scope.dashboard = !scope.dashboard
        scope.dashShortcut = scope.dashboard
        if (arg) dash.selectTab(arg)
      }
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
  Reserve { anchors.left: true; exclusiveZone: scope.cfg.bar.persistent ? Tk.barWidth : Tk.border }
  Reserve { anchors.top: true; exclusiveZone: Tk.border }
  Reserve { anchors.right: true; exclusiveZone: Tk.border }
  Reserve { anchors.bottom: true; exclusiveZone: Tk.border }

  // Settings popped out into a real window.
  property bool settingsWindow: false
  LazyLoader {
    active: scope.settingsWindow
    FloatingWindow {
      visible: true
      title: "Omacale Settings"
      color: Colours.m3surface
      implicitWidth: winSettings.implicitWidth
      implicitHeight: winSettings.implicitHeight
      minimumSize.width: 800
      minimumSize.height: 500
      onVisibleChanged: if (!visible) scope.settingsWindow = false
      Settings {
        id: winSettings
        anchors.fill: parent
        isWindow: true
        screenWidth: scope.screen.width
        screenHeight: scope.screen.height
        version: scope.host.version
        onCloseRequested: scope.settingsWindow = false
      }
    }
  }

  PanelWindow {
    id: win

    screen: scope.screen
    visible: !scope.host.barHidden
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omacale"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: scope.launcher || scope.session || scope.settings ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    anchors { top: true; bottom: true; left: true; right: true }

    // Fullscreen collapses the frame into the screen edges.
    property real fs: scope.hasFullscreen ? 1 : 0
    Behavior on fs { Anim {} }
    // Auto-hiding bar (Caelestia's non-persistent bar).
    property real barProg: scope.cfg.bar.persistent || scope.barHover ? 1 : 0
    Behavior on barProg { Anim {} }

    readonly property real bw: (Tk.border + (Tk.barWidth - Tk.border) * barProg) * (1 - fs)
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
    property real nOff: scope.settings ? 0 : 1
    Behavior on dOff { Anim {} }
    Behavior on lOff { Anim {} }
    Behavior on sOff { Anim {} }
    Behavior on pOff { Anim {} }
    Behavior on nOff { Anim { type: scope.settings ? "slowSpatial" : "emphasized" } }

    // Dashboard (top centre)
    readonly property real dw: dash.implicitWidth || 854
    readonly property real dh: dash.implicitHeight
    readonly property real dx: ax + (aw - dw) / 2
    readonly property real dy: ay + (-dh - 5) * Math.max(0, dOff)
    // Launcher (bottom centre)
    readonly property real lw: launch.implicitWidth
    property real lh: launch.implicitHeight
    readonly property real lx: ax + (aw - lw) / 2
    readonly property real ly: ay + ah - lh + (lh + 5) * Math.max(0, lOff)
    // Session (right centre)
    readonly property real sw: sess.implicitWidth
    readonly property real sh: sess.implicitHeight
    readonly property real sx: ax + aw - sw + (sw + 5) * Math.max(0, sOff)
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
    // A popout pressed against the top or bottom of the panel area grows out of
    // that frame edge too: it reaches into the frame so its corner there is
    // square and the frame flares into it, as the dashboard and launcher do.
    readonly property bool pTouchTop: py <= ay + 0.5
    readonly property bool pTouchBottom: py + ph >= ay + ah - 0.5
    readonly property real px: ax + (-pw - 5) * Math.max(0, pOff)
    // Settings (floating, centred) — grows out of a small pill.
    readonly property real nfw: nexus.implicitWidth
    readonly property real nfh: nexus.implicitHeight
    readonly property real nw: nfw * (1 - 0.55 * nOff)
    readonly property real nh: nfh * (1 - 0.8 * nOff)
    readonly property real nx: ax + (aw - nw) / 2
    readonly property real ny: ay + (ah - nh) / 2

    // ------------------------------------------------------ input mask
    readonly property bool dVis: dOff < 1
    readonly property bool lVis: lOff < 1
    readonly property bool sVis: sOff < 1
    readonly property bool pVis: pOff < 1
    readonly property bool nVis: nOff < 0.999

    mask: Region {
      // While settings are open the whole screen takes input (click outside closes).
      x: win.fs >= 1 || win.nVis ? 0 : win.ax
      y: win.fs >= 1 || win.nVis ? 0 : win.ay
      width: win.fs >= 1 || win.nVis ? win.width : win.aw
      height: win.fs >= 1 || win.nVis ? win.height : win.ah
      intersection: win.nVis ? Intersection.Combine : Intersection.Xor
      Region { intersection: Intersection.Subtract; x: win.dx; y: win.ay; width: win.dVis && !win.nVis ? win.dw : 0; height: win.dVis ? Math.max(0, win.dy + win.dh - win.ay) : 0 }
      Region { intersection: Intersection.Subtract; x: win.lx; y: win.ly; width: win.lVis && !win.nVis ? win.lw : 0; height: win.lVis ? Math.max(0, win.ay + win.ah - win.ly) : 0 }
      Region { intersection: Intersection.Subtract; x: win.sx; y: win.sy; width: win.sVis && !win.nVis ? Math.max(0, win.ax + win.aw - win.sx) : 0; height: win.sVis ? win.sh : 0 }
      Region { intersection: Intersection.Subtract; x: win.ax; y: win.py; width: win.pVis && !win.nVis ? Math.max(0, win.px + win.pw - win.ax) : 0; height: win.pVis ? win.ph : 0 }
    }

    HyprlandFocusGrab {
      windows: [win]
      active: scope.launcher || scope.session || scope.settings || (scope.dashboard && scope.dashShortcut) || (scope.popout === "traymenu")
      onCleared: scope.closeAll()
    }

    // ---------------------------------------------------- scrim
    Rectangle {
      anchors.fill: parent
      color: Colours.m3scrim
      opacity: 0.5 * (1 - win.nOff)
      visible: opacity > 0
    }

    // ---------------------------------------------------- background
    Item {
      anchors.fill: parent
      layer.enabled: true
      layer.effect: MultiEffect {
        shadowEnabled: scope.cfg.appearance.shadow
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
        property rect r3: win.pVis ? Qt.rect(win.px - win.pw * 0.2, win.py - (win.pTouchTop ? win.bt : 0), win.pw * 1.2, win.ph + (win.pTouchTop ? win.bt : 0) + (win.pTouchBottom ? win.bt : 0)) : Qt.rect(0, 0, 0, 0)
        property rect r4: win.nVis ? Qt.rect(win.nx, win.ny, win.nw, win.nh) : Qt.rect(0, 0, 0, 0)
        property rect r5: Qt.rect(0, 0, 0, 0)
        // Edges each drawer grows out of, as a bitmask (1 top, 2 right, 4 bottom, 8 left).
        property vector4d attachA: Qt.vector4d(1, 4, 2, 8 + (win.pTouchTop ? 1 : 0) + (win.pTouchBottom ? 4 : 0))
        property vector4d attachB: Qt.vector4d(0, 0, 0, 0)

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
        return y < Math.max(Tk.border, 2, win.bt + visibleH) && x >= win.dx - Tk.borderRounding && x <= win.dx + win.dw + Tk.borderRounding
      }

      onPressed: e => {
        dragStart = Qt.point(e.x, e.y)
        // A click on the scrim (outside the settings panel) closes it.
        if (scope.settings && !(e.x >= win.nx && e.x <= win.nx + win.nw && e.y >= win.ny && e.y <= win.ny + win.nh)) scope.settings = false
      }
      onContainsMouseChanged: {
        if (containsMouse) return
        if (!scope.dashShortcut) scope.dashboard = false
        if (scope.popout !== "traymenu") scope.popout = ""
        scope.barHover = false
      }
      onWheel: e => { if (e.x < win.bw) bar.handleWheel(e.y, e.angleDelta.y) }
      onPositionChanged: e => {
        if (win.fs > 0 || scope.settings) return
        const x = e.x, y = e.y, dx = x - dragStart.x, dy = y - dragStart.y

        // Auto-hiding bar: reveal at the left edge, hide once well away.
        if (!scope.cfg.bar.persistent) {
          if (scope.cfg.bar.showOnHover && x <= Math.max(Tk.border, 2)) scope.barHover = true
          else if (x > Tk.barWidth + Tk.borderRounding && !(scope.popout !== "" && inPopout(x, y))) scope.barHover = false
          if (pressed && dragStart.x <= Math.max(Tk.border, 2) && dx > 20) scope.barHover = true
        }

        // Session: drag in from the right edge.
        if (scope.cfg.session.enabled && pressed && dragStart.x > win.ax + win.aw - Tk.borderRounding && Math.abs(y - (win.sy + win.sh / 2)) < win.sh / 2 + Tk.borderRounding) {
          if (dx < -scope.cfg.session.dragThreshold) scope.session = true
          else if (dx > scope.cfg.session.dragThreshold) scope.session = false
        }
        // Launcher: drag up from the bottom edge.
        if (scope.cfg.launcher.enabled && pressed && dragStart.y > win.ay + win.ah - Tk.borderRounding && x >= win.lx - Tk.borderRounding && x <= win.lx + win.lw + Tk.borderRounding) {
          if (dy < -scope.cfg.launcher.dragThreshold) scope.launcher = true
          else if (dy > scope.cfg.launcher.dragThreshold) scope.launcher = false
        }
        // Dashboard: hover the top edge.
        if (scope.cfg.dashboard.enabled) {
          const showDash = scope.cfg.dashboard.showOnHover && inTopDash(x, y)
          if (!scope.dashShortcut) scope.dashboard = showDash
          else if (showDash) scope.dashShortcut = false
        }

        // Popouts: hover bar entries.
        if (x < win.bw && win.barProg > 0.5) {
          const p = bar.popoutAt(y)
          if (p) {
            if (p.name === "traymenu") {
              if (scope.popout !== "traymenu" || scope.trayItem !== p.item) { scope.trayItem = p.item; scope.popout = ""; scope.popout = "traymenu" }
            } else scope.popout = p.name
            scope.popoutCenter = p.center
          } else if (scope.popout !== "traymenu") scope.popout = ""
        } else if (scope.popout !== "traymenu" && !inPopout(x, y)) {
          scope.popout = ""
        }
      }

      BarContent {
        id: bar
        x: win.bw - Tk.barWidth
        width: Tk.barWidth
        height: win.height
        opacity: Math.min(1 - win.fs, win.barProg)
        visible: opacity > 0
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
        onOpenSettings: { scope.launcher = false; scope.settings = true }
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

      // ---- settings
      Item {
        x: win.nx
        y: win.ny
        width: win.nw
        height: win.nh
        visible: win.nVis
        clip: true
        Settings {
          id: nexus
          x: (parent.width - width) / 2
          y: (parent.height - height) / 2
          width: implicitWidth
          height: implicitHeight
          opacity: Math.max(0, 1 - win.nOff * 2.5)
          scale: 0.94 + 0.06 * (1 - win.nOff)
          active: scope.settings
          screenWidth: scope.screen.width
          screenHeight: scope.screen.height
          version: scope.host.version
          onCloseRequested: scope.settings = false
          onPopOutRequested: { scope.settings = false; scope.settingsWindow = true }
        }
      }
    }
  }
}
