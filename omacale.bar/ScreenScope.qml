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
  property bool sidebar: false
  property bool utilities: false
  property bool overview: false
  property bool dashShortcut: false
  // Utilities opened by a shortcut/click stay open; opened by hovering the
  // bottom-right corner they close once the cursor leaves (Caelestia Interactions).
  property bool utilShortcut: false
  property bool barHover: false
  property string popout: ""
  property real popoutCenter: 0
  property var trayItem: null

  function closeAll() {
    launcher = false; session = false; dashboard = false; dashShortcut = false; popout = ""; settings = false; sidebar = false; utilities = false; overview = false
  }

  onUtilitiesChanged: utilShortcut = utilities && !interactions.inBottomUtil(interactions.mouseX, interactions.mouseY)

  Connections {
    target: scope.host
    function onToggleRequested(name, screenName, arg) {
      if (screenName !== scope.screen.name) return
      if (name === "close") { scope.closeAll(); return }
      if (name === "launcher" && scope.cfg.launcher.enabled) {
        // With a carousel ("wallpaper" / "theme") it opens onto it, and only
        // closes if that carousel is already showing.
        const mode = arg === "wallpaper" ? "wallpapers" : arg === "theme" ? "themes" : arg === "menu" ? "menu" : ""
        if (mode && !(scope.launcher && launch.mode === mode)) { launch.openMode(arg); scope.launcher = true }
        else scope.launcher = !scope.launcher
      }
      else if (name === "session" && scope.cfg.session.enabled) scope.session = !scope.session
      else if (name === "settings") {
        // With a page id it opens (never toggles) straight onto that page.
        if (arg) { scope.popout = ""; nexus.go(arg); scope.settings = true }
        else scope.settings = !scope.settings
      }
      else if (name === "sidebar" && (!scope.cfg.sidebar || scope.cfg.sidebar.enabled)) {
        if (scope.session) scope.session = false
        scope.sidebar = !scope.sidebar
      }
      else if (name === "utilities" && (!scope.cfg.utilities || scope.cfg.utilities.enabled)) {
        if (scope.session) scope.session = false
        scope.utilities = !scope.utilities
      }
      else if (name === "overview" && scope.cfg.overview.enabled) {
        if (!scope.overview) scope.closeAll()
        scope.overview = !scope.overview
      }
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
  onHasFullscreenChanged: {
    launcher = false
    session = false
    dashboard = false
    dashShortcut = false
    popout = ""
    sidebar = false
    utilities = false
  }

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

  // ----------------------------------------------- notification toasts
  //
  // Deliberately NOT part of the frame window below. That one sits on
  // Hyprland's `top` layer, which a fullscreen window draws over, and it goes
  // away with the bar -- a notification a video can hide is not a
  // notification. The toasts get their own `overlay` surface (where Omarchy's
  // stock toasts live too) and stay up over anything.
  //
  // Which means they can't be a shape in the frame's blob shader the way the
  // other drawers are, so each toast is a card of its own with an elevation
  // shadow, sitting where the frame's top-right inner corner is.
  readonly property real toastInset: Tk.border + Math.max(0, Math.min(Tk.padding.large - Tk.border, Tk.padding.large))

  PanelWindow {
    id: toastWin

    screen: scope.screen
    // Kept up through the outro so the last toast can finish leaving. The
    // first half of the test is deliberately computed outside this window, so
    // a surface that was taken down can always bring itself back.
    visible: NotifService.popupsEnabled
      && ((NotifService.popups.length > 0 && !toastStack.suppressed) || toastStack.implicitHeight > 0)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omacale-notifications"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    // One fixed, full-screen surface, as Omarchy's own popup window uses: a
    // surface that resizes as toasts come and go lets the compositor scale a
    // stale buffer for a frame, which squashes the cards.
    anchors { top: true; bottom: true; left: true; right: true }

    // Only the cards themselves take input; everything else on this surface
    // is click-through, so the overlay never eats a press.
    mask: Region { item: toastStack }

    NotifPopups {
      id: toastStack

      anchors.top: parent.top
      anchors.right: parent.right
      anchors.topMargin: scope.toastInset
      anchors.rightMargin: scope.toastInset

      width: implicitWidth
      height: implicitHeight
      maxHeight: Math.max(0, scope.screen.height - scope.toastInset * 2)
      // The notification centre shows the same notifications in full, so the
      // toasts get out of its way (Caelestia's Notifs.shouldShowPopup).
      suppressed: scope.sidebar
    }
  }

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
    WlrLayershell.layer: win.modal ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.keyboardFocus: scope.launcher || scope.session || scope.settings || scope.overview ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    anchors { top: true; bottom: true; left: true; right: true }

    // Fullscreen collapses the frame into the screen edges.
    property real fs: scope.hasFullscreen ? 1 : 0
    Behavior on fs { Anim {} }

    // Wallpaper luminance for Colours.layer; one sampler serves every screen.
    Loader {
      active: scope.screen === Quickshell.screens[0]
      sourceComponent: WallLuminance {}
    }
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
    property real oOff: scope.overview ? 0 : 1
    property real sbOff: scope.sidebar ? 0 : 1
    property real uOff: (scope.utilities || scope.sidebar) ? 0 : 1
    Behavior on dOff { Anim {} }
    Behavior on lOff { Anim {} }
    Behavior on sOff { Anim {} }
    Behavior on pOff { Anim {} }
    Behavior on nOff { Anim { type: scope.settings ? "slowSpatial" : "emphasized" } }
    Behavior on oOff { Anim { type: scope.overview ? "slowSpatial" : "emphasized" } }
    Behavior on sbOff { Anim {} }
    Behavior on uOff { Anim {} }

    // Visibility flags
    readonly property bool dVis: dOff < 1
    readonly property bool lVis: lOff < 1
    readonly property bool sVis: sOff < 1
    readonly property bool pVis: pOff < 1
    readonly property bool nVis: nOff < 0.999
    readonly property bool oVis: oOff < 0.999
    // Settings and the overview are modal: the whole screen takes input so a
    // press outside them closes, and the other drawers stop carving the mask.
    readonly property bool modal: nVis || oVis
    readonly property bool uVis: uOff < 1
    readonly property bool sbVis: sbOff < 1

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
    // Caelestia's ClipWrapper places the popout from the page's final size
    // (nonAnimHeight), so it moves straight to its spot while the size
    // animates; placing it from the animated `ph` made it drift.
    readonly property real pwTarget: pop.implicitWidth + Tk.padding.large * 2
    readonly property real phTarget: pop.implicitHeight + Tk.padding.large * 2
    property real pw: pwTarget
    property real ph: phTarget
    // Opening from closed: a page's Layout only reports its size on the next
    // polish, after pOff has started moving. Snap until it has settled, so the
    // popout opens in place instead of sliding from the last page's geometry.
    property bool pSettled: true
    Timer { id: pSettle; interval: 60; onTriggered: win.pSettled = true }
    Connections {
      target: scope
      function onPopoutChanged() {
        if (scope.popout !== "" && win.pOff >= 0.999) { win.pSettled = false; pSettle.restart() }
      }
    }
    readonly property bool pAnimate: pOff < 1 && pSettled
    Behavior on pw { enabled: win.pAnimate; Anim {} }
    Behavior on ph { enabled: win.pAnimate; Anim {} }
    property real py: {
      const off = scope.popoutCenter - bt - phTarget / 2
      return ay + Math.max(0, Math.min(off, ah - phTarget))
    }
    Behavior on py { enabled: win.pAnimate; Anim {} }
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
    // Overview (floating, centred) — the same grow as Settings.
    readonly property real ofw: overviewContent.implicitWidth
    readonly property real ofh: overviewContent.implicitHeight
    readonly property real ow: ofw * (1 - 0.55 * oOff)
    readonly property real oh: ofh * (1 - 0.8 * oOff)
    readonly property real ox: ax + (aw - ow) / 2
    readonly property real oy: ay + (ah - oh) / 2
    // Sidebar (top right, above utilities)
    readonly property real sbw: Tk.sizes.sidebarWidth
    readonly property real sbx: ax + aw - sbw + (sbw + 5) * sbOff
    readonly property real sby: ay
    // Anchored to the utilities' top edge, as Caelestia's Sidebar.Wrapper.
    readonly property real sbh: Math.max(0, Math.min(ah, uy - ay))
    // Utilities (bottom right), sliding up out of the bottom edge like
    // Caelestia's Utilities.Wrapper. While the sidebar is open it takes the
    // sidebar's visible width, so the two drawers share one straight side.
    property real sbLerp: scope.sidebar ? 1 : 0
    Behavior on sbLerp {
      Anim {
        duration: Tk.durations.defaultSpatial / 2
        easing.bezierCurve: scope.sidebar ? Tk.curves.standardAccel : Tk.curves.standardDecel
      }
    }
    readonly property real uw: Math.max(0, ax + aw - sbx) * sbLerp + Tk.sizes.utilitiesWidth * (1 - sbLerp)
    readonly property real uh: (util && util.implicitHeight > 0) ? util.implicitHeight : 450
    readonly property real ux: ax + aw - uw
    readonly property real uy: ay + ah - uh + (uh + 5) * uOff
    // Caelestia's PanelBg: the corners they share square up and their fillet
    // is dropped once the sidebar is (nearly) in place.
    readonly property real joinRound: Math.max(0, Math.min(1, sbOff / 0.3))

    // ------------------------------------------------------ input mask

    mask: Region {
      // While settings are open the whole screen takes input (click outside closes).
      x: win.fs >= 1 || win.modal ? 0 : win.ax
      y: win.fs >= 1 || win.modal ? 0 : win.ay
      width: win.fs >= 1 || win.modal ? win.width : win.aw
      height: win.fs >= 1 || win.modal ? win.height : win.ah
      intersection: win.modal ? Intersection.Combine : Intersection.Xor
      Region { intersection: Intersection.Subtract; x: win.dx; y: win.ay; width: win.dVis && !win.modal ? win.dw : 0; height: win.dVis ? Math.max(0, win.dy + win.dh - win.ay) : 0 }
      Region { intersection: Intersection.Subtract; x: win.lx; y: win.ly; width: win.lVis && !win.modal ? win.lw : 0; height: win.lVis ? Math.max(0, win.ay + win.ah - win.ly) : 0 }
      Region { intersection: Intersection.Subtract; x: win.sx; y: win.sy; width: win.sVis && !win.modal ? Math.max(0, win.ax + win.aw - win.sx) : 0; height: win.sVis ? win.sh : 0 }
      Region { intersection: Intersection.Subtract; x: win.ax; y: win.py; width: win.pVis && !win.modal ? Math.max(0, win.px + win.pw - win.ax) : 0; height: win.pVis ? win.ph : 0 }
      Region { intersection: Intersection.Subtract; x: win.ux; y: win.uy; width: win.uVis && !win.modal ? Math.max(0, win.ax + win.aw - win.ux) : 0; height: win.uVis ? Math.max(0, win.ay + win.ah - win.uy) : 0 }
      Region { intersection: Intersection.Subtract; x: win.sbx; y: win.sby; width: win.sbVis && !win.modal ? Math.max(0, win.ax + win.aw - win.sbx) : 0; height: win.sbVis ? win.sbh : 0 }
    }

    // Hyprland hands the keyboard to a window on the workspace you switch to,
    // and to *nothing at all* when that workspace is empty -- an OnDemand
    // layer surface is not offered it back, so the panel that asked for the
    // switch stops receiving keys. Taking the grab again puts the keyboard
    // back on this window; the overview asks for that after every switch.
    property bool regrabbing: false
    function regrab() {
      regrabTimer.restart()
    }
    Timer {
      id: regrabTimer
      interval: 50
      onTriggered: {
        win.regrabbing = true
        grab.active = false
        grab.active = Qt.binding(() => win.grabWanted)
        win.regrabbing = false
        if (scope.overview) overviewContent.forceActiveFocus()
      }
    }
    readonly property bool grabWanted: scope.launcher || scope.session || scope.settings || scope.overview || scope.sidebar || (scope.utilities && scope.utilShortcut) || (scope.dashboard && scope.dashShortcut) || (scope.popout === "traymenu")
    HyprlandFocusGrab {
      id: grab
      windows: [win]
      active: win.grabWanted
      onCleared: {
        if (win.regrabbing) return
        if (scope.overview) {
          regrabTimer.restart()
        } else {
          scope.closeAll()
        }
      }
    }

    // ---------------------------------------------------- scrim
    Rectangle {
      anchors.fill: parent
      color: Colours.m3scrim
      opacity: 0.5 * Math.max(1 - win.nOff, 1 - win.oOff)
      visible: opacity > 0
    }

    // ---------------------------------------------------- background
    Item {
      anchors.fill: parent
      layer.enabled: true
      layer.effect: MultiEffect {
        shadowEnabled: scope.cfg.appearance.shadow
        blurMax: 15
        shadowColor: Qt.alpha(Colours.m3shadow, 0.7 * Math.max(0, 1 - win.fs))
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
        // Sidebar and utilities stretch to keep touching their frame edges
        // while their spatial curve overshoots; the sidebar overlaps the
        // utilities by 2px so the join never shows a seam.
        property rect r5: win.uVis ? Qt.rect(win.ux, win.uy, win.uw, Math.max(win.uh, win.ay + win.ah - win.uy)) : Qt.rect(0, 0, 0, 0)
        property rect r6: win.sbVis ? Qt.rect(win.sbx, win.sby, Math.max(win.sbw, win.ax + win.aw - win.sbx), win.sbh + 2) : Qt.rect(0, 0, 0, 0)
        // The overview floats like Settings, so its attach bitmask is 0 too.
        property rect r7: win.oVis ? Qt.rect(win.ox, win.oy, win.ow, win.oh) : Qt.rect(0, 0, 0, 0)
        // Edges each drawer grows out of, as a bitmask (1 top, 2 right, 4 bottom, 8 left).
        property vector4d attachA: Qt.vector4d(1, 4, 2, 8 + (win.pTouchTop ? 1 : 0) + (win.pTouchBottom ? 4 : 0))
        property vector4d attachB: Qt.vector4d(0, 6, 3, 0)
        property point join: Qt.point(win.joinRound, win.sbOff <= 0.08 ? 1 : 0)

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
      // Caelestia inBottomPanel(utilities, isCorner = true).
      function inBottomUtil(x, y) {
        const visibleH = win.uh * (1 - win.uOff)
        return y > win.height - Math.max(Tk.border, 2, win.bt + visibleH) - Tk.borderRounding && x >= win.ux - Tk.borderRounding && x <= win.ux + win.uw + Tk.borderRounding
      }
      function inTopDash(x, y) {
        const visibleH = win.dh * (1 - win.dOff)
        return y < Math.max(Tk.border, 2, win.bt + visibleH) && x >= win.dx - Tk.borderRounding && x <= win.dx + win.dw + Tk.borderRounding
      }

      onPressed: e => {
        dragStart = Qt.point(e.x, e.y)
        // A click on the scrim (outside the settings panel) closes it.
        if (scope.settings && !(e.x >= win.nx && e.x <= win.nx + win.nw && e.y >= win.ny && e.y <= win.ny + win.nh)) scope.settings = false
        if (scope.overview && !(e.x >= win.ox && e.x <= win.ox + win.ow && e.y >= win.oy && e.y <= win.oy + win.oh)) scope.overview = false
        if (scope.sidebar && e.x < win.sbx) scope.sidebar = false
        if (scope.utilities && !scope.sidebar && (e.x < win.ux || e.y < win.uy)) scope.utilities = false
      }
      onContainsMouseChanged: {
        if (containsMouse) return
        if (!scope.dashShortcut) scope.dashboard = false
        if (!scope.utilShortcut) scope.utilities = false
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
        // Sidebar: drag in from top-right edge, or drag right to close
        if ((!scope.cfg.sidebar || scope.cfg.sidebar.enabled) && pressed && !scope.sidebar && dragStart.x > win.ax + win.aw - Tk.borderRounding && y < win.sy && dx < -30) {
          scope.sidebar = true
        } else if (pressed && scope.sidebar && dragStart.x >= win.sbx && dx > 40) {
          scope.sidebar = false
          if (scope.utilShortcut) scope.utilities = false
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

        // Utilities: hover the bottom-right corner.
        if (!scope.cfg.utilities || scope.cfg.utilities.enabled) {
          const showUtil = inBottomUtil(x, y)
          if (!scope.utilShortcut) scope.utilities = showUtil
          else if (showUtil) scope.utilShortcut = false
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
        screenWidth: win.width
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

      // ---- sidebar
      Sidebar {
        id: sidebarPanel
        x: win.sbx
        y: win.sby
        width: win.sbw
        height: win.sbh
        visible: win.sbVis
        opacity: 1 - win.sbOff
        host: scope.host
        scope: scope
        active: scope.sidebar
      }

      // ---- utilities
      Utilities {
        id: util
        x: win.ux
        y: win.uy
        width: win.uw
        visible: win.uVis
        opacity: 1 - win.uOff
        host: scope.host
        scope: scope
        active: scope.utilities || scope.sidebar
      }

      // ---- overview
      Item {
        x: win.ox
        y: win.oy
        width: win.ow
        height: win.oh
        visible: win.oVis
        // Clipped like Settings: the grid animates to its own size, and a row
        // that has just appeared stays hidden until the panel holds it.
        clip: true
        Overview {
          id: overviewContent
          x: (parent.width - width) / 2
          y: (parent.height - height) / 2
          width: implicitWidth
          height: implicitHeight
          opacity: Math.max(0, 1 - win.oOff * 2.5)
          scale: 0.94 + 0.06 * (1 - win.oOff)
          active: scope.overview
          focus: scope.overview
          screen: scope.screen
          onDismissed: scope.overview = false
          onRefocus: win.regrab()
        }
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
