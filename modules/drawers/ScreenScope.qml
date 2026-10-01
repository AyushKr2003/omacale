import QtQuick
import QtQuick.Dialogs
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../.."

// Everything on one monitor, laid out like Caelestia's drawers window: a
// full-screen layer whose background is one SDF blob (frame + drawers, with a
// soft shadow), the bar on one of its edges (the left, in Caelestia), and
// drawers that grow out of the frame.
Scope {
  id: scope

  required property var modelData
  required property var host
  readonly property var screen: modelData
  readonly property var monitor: Hyprland.monitorFor(screen)
  readonly property var cfg: Config.o

  // The edge the bar is on (Bar.position). Caelestia itself only draws it on
  // the left; the other edges follow Caelestia KDE's drawers: the panel area is
  // inset by the bar on its edge, and a right-hand bar mirrors the drawers that
  // live on the right (session, sidebar, utilities, toasts) over to the left,
  // out of the popouts' way.
  readonly property string barPos: host.position
  readonly property bool barVert: barPos === "left" || barPos === "right"
  readonly property bool mirror: barPos === "right"
  // A bottom bar puts utilities on top and the notification sidebar under it
  // (the other way round from every other edge), so the bar's popouts and the
  // utilities' hover corner don't share the bottom-right of the screen.
  readonly property bool flipV: barPos === "bottom"

  // ---------------------------------------------------------- state
  property bool launcher: false
  property bool dashboard: false
  property bool session: false
  property bool settings: false
  property bool sidebar: false
  // Caelestia's NotifDock clears every popup as it opens, and Notifs shows
  // none while it stays open: the toasts are dismissed, not just hidden.
  onSidebarChanged: if (sidebar && NotifService.popups.length) NotifService.dismissAllPopups()
  Connections {
    target: NotifService
    function onPopupsChanged() { if (scope.sidebar && NotifService.popups.length) Qt.callLater(NotifService.dismissAllPopups) }
  }
  property bool utilities: false
  property bool overview: false
  property bool dashShortcut: false
  // Utilities opened by a shortcut/click stay open; opened by hovering the
  // bottom-right corner they close once the cursor leaves (Caelestia Interactions).
  property bool utilShortcut: false
  property bool barHover: false
  // `omarchy toggle bar` (SUPER+SHIFT+SPACE) takes the bar column away and
  // nothing else: the frame, the reserved edges and every drawer stay, as in
  // Caelestia's non-persistent bar at rest. What points at the bar (its
  // popouts, its focus mode, the hover reveal, the wheel) is off meanwhile.
  readonly property bool barOff: host.barHidden
  onBarOffChanged: if (barOff) {
    barFocus = false
    popout = ""
    barHover = false
  }
  property string popout: ""
  property real popoutCenter: 0
  property var trayItem: null
  // Popouts the pointer leaving doesn't close. The tray menu is still swapped
  // by hovering another bar icon; the two that take the keyboard (Caelestia's
  // wirelesspassword and the detached winfo) are "held": only Escape, their own
  // buttons or a click outside (the focus grab clearing) put them away, so
  // crossing the bar doesn't throw away a half-typed password.
  //
  // A popout opened from the keyboard (an Omarchy panel hotkey, IPC) is held
  // too: hovering the bar doesn't swap it, and it has the keys. One opened by
  // the pointer stays exactly Caelestia's.
  property bool popoutKeys: false
  // SUPER+CTRL+0: the bar itself has the keyboard (BarContent's cursor).
  property bool barFocus: false
  onBarFocusChanged: {
    if (barFocus) {
      if (!cfg.bar.persistent) barHover = true
      win.primeFocus()
    } else if (!cfg.bar.persistent && popout === "") barHover = false
  }
  // The bar focus mode switching workspace: Hyprland takes the keyboard (and
  // clears the grab), so take both back rather than treat it as a click away.
  function switchWorkspace(id) {
    Sys.workspace(id)
    wsSettle.restart()
    win.regrab()
  }
  Timer { id: wsSettle; interval: 600 }
  // ---------------------------------------------------- drawer keys
  //
  // No Caelestia original (its drawers are pointer-only). The dashboard
  // opened by its shortcut, the sidebar, and utilities opened by theirs take
  // the keyboard, and one spatial cursor (NavCursor) walks whatever of them
  // is open -- the sidebar and utilities share a panel, so j/k run from one
  // into the other. Settings keeps its own focus and hands its keys over
  // through keyHook. Omarchy's panel keys (KeyNav), plus Tab / 1..4 for
  // dashboard tabs and Shift+X to clear the notifications.
  readonly property bool drawerKeys: !popoutHeld && !barFocus && !launcher && !session && !overview && !settings
    && (sidebar || (dashboard && dashShortcut) || (utilities && utilShortcut))
  onDrawerKeysChanged: if (drawerKeys) win.primeFocus()

  NavCursor {
    id: drawerNav
    space: win.contentItem
    active: scope.drawerKeys || scope.settings
    roots: scope.settings ? (scope.nexus && scope.nexus.navRoots ? scope.nexus.navRoots : [])
      : [].concat(scope.dashboard && scope.dash ? scope.dash.navRoots : [],
                  scope.sidebar && scope.sidebarPanel ? scope.sidebarPanel.navRoots : [],
                  (scope.utilities || scope.sidebar) && scope.util ? scope.util.navRoots : [])
  }
  KeyNav {
    id: drawerKeyNav
    onMoveRequested: (dx, dy) => drawerNav.move(dx, dy)
    onActivateRequested: drawerNav.activate()
    onCloseRequested: {
      scope.dashboard = false; scope.dashShortcut = false
      scope.sidebar = false; scope.utilities = false
    }
    onTabRequested: d => drawerNav.next(d)
    onDeleteRequested: drawerNav.remove()
    onTextKey: t => {
      const h = drawerNav.nearest(drawerNav.cursor, "navText") || drawerNav.roots.find(r => typeof r.navText === "function")
      if (h) h.navText(t)
    }
  }
  function drawerKey(e) {
    if (e.text === "X") {
      if (sidebar && sidebarPanel) sidebarPanel.navClearAll()
      e.accepted = true
      return
    }
    if (dashboard && dash && !settings) {
      const onTabs = drawerNav.cursor && dash.inTabBar(drawerNav.cursor)
      if (e.key === Qt.Key_Tab || e.key === Qt.Key_Backtab) {
        dash.navTab((e.modifiers & Qt.ShiftModifier) || e.key === Qt.Key_Backtab ? -1 : 1)
        if (onTabs) drawerNav.setCursor(dash.navTabStop())
        e.accepted = true
        return
      }
      if (e.text.length === 1 && e.text >= "1" && e.text <= "9") {
        dash.navTabAt(Number(e.text))
        if (onTabs) drawerNav.setCursor(dash.navTabStop())
        e.accepted = true
        return
      }
    }
    drawerKeyNav.handle(e)
  }

  // After another surface of ours unmaps (the toasts), whatever holds the
  // keyboard takes it again: a primed one re-primes, the rest re-grab.
  function retakeKeys() {
    if (popoutKeys || barFocus || drawerKeys) win.primeFocus()
    else if (win.grabWanted) win.regrab()
  }

  function toggleBarFocus() {
    if (barOff) return
    if (barFocus) { barFocus = false; return }
    closeAll()
    barFocus = true
  }
  readonly property bool popoutHeld: popout === "wirelesspassword" || popout === "winfo" || popoutKeys
  readonly property bool popoutSticky: popout === "traymenu" || popoutHeld
  // The network the password popout is asking for.
  property string passwordSsid: ""

  // The drawers, while they exist. As in Caelestia's drawer Wrappers
  // (`Loader { active: shouldBeActive || visible }`), each one is only built
  // while it is open or animating out, and destroyed once it has gone: kept
  // around they cost ~150 MB (their items, and a font engine per text style).
  readonly property var dash: dashLoader.item
  readonly property var launch: launchLoader.item
  readonly property var sess: sessLoader.item
  readonly property var sidebarPanel: sidebarLoader.item
  readonly property var util: utilLoader.item
  readonly property var overviewContent: overviewLoader.item
  readonly property var nexus: nexusLoader.item
  // What a rebuilt drawer should come back to: the dashboard's tab and the
  // settings page (with its back stack) the user left them on.
  property int dashTab: 0
  property string nexusPage: "style"
  property var nexusStack: []
  // ScreenScope under a name no drawer shadows: Sidebar and Utilities have a
  // `scope` property of their own, which a binding inside their (inline,
  // on-demand) component would resolve `scope` to.
  readonly property var screenScope: scope

  onPopoutChanged: if (popout === "") {
    if (popoutKeys && !cfg.bar.persistent && !barFocus) barHover = false
    popoutKeys = false
    // A popout opened from the bar focus mode gives the keys back to it.
    if (barFocus) Qt.callLater(() => bar.takeKeys())
  }

  // Open a bar popout with the keyboard (Bar.summonBarWidget, IPC popout).
  // Opens, never toggles: the host asks isBarWidgetOpen first.
  function openPopoutKeys(name) {
    if (barOff) return
    if (session) session = false
    popoutCenter = bar.popoutCenterFor(name)
    popoutKeys = true
    popout = name
    if (!cfg.bar.persistent) barHover = true
    win.primeFocus()
  }
  // The status group's popouts that have an icon on the bar, in bar order.
  function statusPopouts() { return bar.statusPopouts() }
  // Tab in a keyboard popout: the next status popout down the bar, wrapping
  // (from one that isn't a status popout, the first or last).
  function tabPopout(d) {
    const list = statusPopouts()
    if (!list.length) return
    const i = list.indexOf(popout)
    const next = i < 0 ? (d > 0 ? 0 : list.length - 1) : (i + d + list.length) % list.length
    if (list[next] !== popout) openPopoutKeys(list[next])
  }

  Component.onCompleted: host.registerScope(scope)
  Component.onDestruction: host.unregisterScope(scope)

  function closeAll() {
    barFocus = false
    launcher = false; session = false; dashboard = false; dashShortcut = false; popout = ""; settings = false; sidebar = false; utilities = false; overview = false
  }

  onUtilitiesChanged: utilShortcut = utilities && !interactions.inBottomUtil(interactions.mouseX, interactions.mouseY)

  Connections {
    target: scope.host
    function onToggleRequested(name, screenName, arg) {
      if (screenName !== scope.screen.name) return
      if (name === "close") { scope.closeAll(); return }
      // Caelestia only reaches the window info panel from the active-window
      // popout; the IPC opens it straight away, centred on the bar.
      if (name === "windowInfo") {
        if (scope.popout === "winfo") scope.popout = ""
        else { scope.popoutCenter = scope.barVert ? scope.screen.height / 2 : scope.screen.width / 2; scope.popout = "winfo" }
        return
      }
      if (name === "launcher" && scope.cfg.launcher.enabled) {
        // With a mode ("wallpaper" / "theme" / "menu" / "clipboard") it opens
        // onto it, and only closes if that mode is already showing.
        const mode = arg === "wallpaper" ? "wallpapers" : arg === "theme" ? "themes" : arg === "menu" ? "menu" : arg === "clipboard" ? "clipboard" : ""
        if (mode && !(scope.launcher && launch && launch.mode === mode)) { scope.launcher = true; launch.openMode(arg) }
        else scope.launcher = !scope.launcher
      }
      else if (name === "session" && scope.cfg.session.enabled) scope.session = !scope.session
      else if (name === "settings") {
        // With a page id it opens (never toggles) straight onto that page.
        if (arg) {
          // From a popout's settings button: that popout's blob becomes
          // Settings, travelling to the middle as it grows (Caelestia
          // bar/popouts/Wrapper.qml detach("any")).
          if (!scope.settings) win.handOffPopout()
          scope.popout = ""; scope.settings = true; nexus.go(arg)
        }
        else scope.settings = !scope.settings
      }
      // The session menu stays: it moves over to sit against the sidebar.
      else if (name === "sidebar" && (!scope.cfg.sidebar || scope.cfg.sidebar.enabled)) scope.sidebar = !scope.sidebar
      else if (name === "utilities" && (!scope.cfg.utilities || scope.cfg.utilities.enabled)) {
        if (scope.session) scope.session = false
        scope.utilities = !scope.utilities
      }
      else if (name === "overview" && scope.cfg.overview.enabled) {
        if (!scope.overview) scope.closeAll()
        scope.overview = !scope.overview
      }
      else if (name === "dashboard" && scope.cfg.dashboard.enabled) {
        if (arg && scope.dashboard && dash) { dash.selectTab(arg); return }
        scope.dashboard = !scope.dashboard
        scope.dashShortcut = scope.dashboard
        if (arg && dash) dash.selectTab(arg)
      }
    }
  }

  // ------------------------------------------------------ fullscreen
  // Real fullscreen only (`fullscreen` 2), Caelestia's test in
  // ContentWindow.qml. Not the workspace's `hasfullscreen`, which is also true
  // for a maximized window (SUPER+ALT+F, "Full width"): that one leaves our
  // top-layer surface and the reserved edges alone, so the frame stays.
  readonly property bool hasFullscreen: {
    const ws = monitor ? monitor.activeWorkspace : null
    return !!(ws && ws.toplevels.values.some(t => t.lastIpcObject && t.lastIpcObject.fullscreen > 1))
  }
  Connections {
    target: Hyprland
    function onRawEvent(e) {
      if (e.name === "fullscreen" || e.name === "workspace" || e.name === "closewindow") {
        Hyprland.refreshWorkspaces()
        Hyprland.refreshToplevels()
      }
    }
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
    WlrLayershell.namespace: "omacale-reserve"
    mask: Region {}
    implicitWidth: 1
    implicitHeight: 1
    color: "transparent"
  }
  // What an edge reserves: the frame's border, or the bar's breadth on its own.
  function zoneFor(edge) {
    return edge === barPos && cfg.bar.persistent && !barOff ? Tk.barWidth : Tk.border
  }
  Reserve { anchors.left: true; exclusiveZone: scope.zoneFor("left") }
  Reserve { anchors.top: true; exclusiveZone: scope.zoneFor("top") }
  Reserve { anchors.right: true; exclusiveZone: scope.zoneFor("right") }
  Reserve { anchors.bottom: true; exclusiveZone: scope.zoneFor("bottom") }

  // Desktop clock and visualiser, under the windows (Caelestia's background).
  Background {
    screen: scope.screen
    barPos: scope.barPos
    barZone: scope.zoneFor(scope.barPos)
  }

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
  // Toasts sit in the top-right corner, the top-left one when the bar is on the
  // right (Caelestia KDE's auto position), and below a bar on the top edge.
  readonly property real toastTop: toastInset + (barPos === "top" ? Math.max(0, win.bw - Tk.border) : 0)

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

    // Taking this surface down makes Hyprland hand the keyboard to a window,
    // even from a panel that holds it: opening the sidebar over a toast (the
    // toasts get out of its way) or the last toast timing out under an open
    // drawer left h/j/k/l going to the window behind. Take the keys back.
    onVisibleChanged: if (!visible) scope.retakeKeys()

    NotifPopups {
      id: toastStack

      // In the corner by x/y: an anchor that a binding clears doesn't reliably
      // let go, and the bar can move to the other side while the shell runs.
      x: scope.mirror ? scope.toastInset : parent.width - width - scope.toastInset
      y: scope.toastTop

      width: implicitWidth
      height: implicitHeight
      // Caelestia notifications/Content.qml: the stack stops short of the
      // session menu and of utilities (when they share its corner's side).
      maxHeight: {
        let h = scope.screen.height - scope.toastTop - scope.toastInset
        if (scope.session) h = Math.min(h, win.sy - Math.max(0, Tk.padding.large - Tk.border) - scope.toastTop)
        if (scope.utilities && !scope.flipV)
          h = Math.min(h, scope.screen.height - win.uh - Tk.border * 2 - Tk.padding.large * 2 - Tk.spacing.extraLarge)
        return Math.max(0, h)
      }
      // The notification centre shows the same notifications in full, so the
      // toasts get out of its way (Caelestia's Notifs.shouldShowPopup).
      suppressed: scope.sidebar
    }
  }

  // Caelestia's facePicker: choose an image and copy it to ~/.face, which the
  // dashboard and the lock screen read. The portal's native dialog; made on
  // demand and dropped once it closes.
  Loader {
    id: facePicker
    active: false
    sourceComponent: FileDialog {
      title: "Choose a profile picture"
      nameFilters: ["Images (*.png *.jpg *.jpeg *.webp *.bmp *.gif)"]
      currentFolder: "file://" + Quickshell.env("HOME") + "/Pictures"
      Component.onCompleted: open()
      onAccepted: {
        const path = decodeURIComponent(String(selectedFile).replace(/^file:\/\//, ""))
        Quickshell.execDetached(["cp", "-f", "--", path, Quickshell.env("HOME") + "/.face"])
        facePicker.active = false
      }
      onRejected: facePicker.active = false
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
      minimumSize.width: Tk.px(800)
      minimumSize.height: Tk.px(500)
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
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omacale"
    WlrLayershell.layer: win.modal ? WlrLayer.Overlay : WlrLayer.Top
    // A keyboard-opened popout primes Exclusive first, as Omarchy's
    // KeyboardPanel does: this window is always mapped, and Hyprland doesn't
    // offer an already-mapped surface the keyboard when it merely changes
    // from None to OnDemand. OnDemand afterwards gives pointer hit-testing
    // back to other surfaces (and outputs).
    WlrLayershell.keyboardFocus: (scope.popoutKeys || scope.barFocus || scope.drawerKeys) && !win.focusPrimed ? WlrKeyboardFocus.Exclusive
      : scope.launcher || scope.session || scope.settings || scope.overview || scope.popoutHeld || scope.barFocus || scope.drawerKeys ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
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
    readonly property bool barShown: !scope.barOff && (scope.cfg.bar.persistent || scope.barHover)
    property real barProg: barShown ? 1 : 0
    // Caelestia BarWrapper: out on the default spatial curve, back in on
    // emphasized.
    Behavior on barProg { Anim { type: win.barShown ? "spatial" : "emphasized" } }

    // The frame's breadth on the bar's edge (bw) and on the others (bt).
    readonly property real bw: (Tk.border + (Tk.barWidth - Tk.border) * barProg) * (1 - fs)
    readonly property real bt: Tk.border * (1 - fs)
    // Panel area (Caelestia's Panels item)
    readonly property real ax: scope.barPos === "left" ? bw : bt
    readonly property real ay: scope.barPos === "top" ? bw : bt
    readonly property real aw: width - ax - (scope.barPos === "right" ? bw : bt)
    readonly property real ah: height - ay - (scope.barPos === "bottom" ? bw : bt)

    // Drawers on the right of the screen (the left, with a right-hand bar):
    // where one of width w sits, off = 0 open to 1 away, and the part of the
    // area it shows, which is what the input mask keeps. `off` is not
    // clamped: the spatial curve overshoots, and the drawer comes a few px
    // off its wall and back, as Caelestia's do (the blob's corner fill keeps
    // it joined to the frame meanwhile).
    function sideX(w, off) {
      return scope.mirror ? ax - (w + 5) * off : ax + aw - w + (w + 5) * off
    }
    function sideMaskX(x) { return scope.mirror ? ax : x }
    function sideMaskW(x, w) { return scope.mirror ? Math.max(0, x + w - ax) : Math.max(0, ax + aw - x) }

    // -------------------------------------------------- drawer motion
    property real dOff: scope.dashboard ? 0 : 1
    property real lOff: scope.launcher ? 0 : 1
    property real sOff: scope.session ? 0 : 1
    // A detached popout flies back to the bar before it slides away.
    property real pOff: scope.popout !== "" || pDet > 0.001 ? 0 : 1
    property real nOff: scope.settings ? 0 : 1
    property real oOff: scope.overview ? 0 : 1
    property real sbOff: scope.sidebar ? 0 : 1
    // The clipboard preview, out while the launcher shows clipboard rows.
    property real cpOff: scope.launcher && launch && launch.previewWanted ? 0 : 1
    // Utilities give way to the session menu, unless the sidebar holds them
    // (Caelestia utilities/Wrapper.qml shouldBeActive).
    property real uOff: (scope.sidebar || (scope.utilities && !scope.session)) ? 0 : 1
    Behavior on dOff { Anim {} }
    Behavior on lOff { Anim {} }
    Behavior on sOff { Anim {} }
    Behavior on pOff { Anim {} }
    Behavior on nOff { Anim { type: scope.settings ? "slowSpatial" : "emphasized" } }
    Behavior on oOff { Anim { type: scope.overview ? "slowSpatial" : "emphasized" } }
    Behavior on sbOff { Anim {} }
    Behavior on cpOff { Anim {} }
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
    readonly property real dw: (dash && dash.implicitWidth) || Tk.px(854)
    readonly property real dh: dash ? dash.implicitHeight : 0
    readonly property real dx: ax + Math.round((aw - dw) / 2)
    readonly property real dy: ay + (-dh - 5) * dOff
    // Launcher (bottom centre)
    readonly property real lw: launch ? launch.implicitWidth : 0
    property real lh: launch ? launch.implicitHeight : 0
    readonly property real lx: ax + Math.round((aw - lw) / 2)
    readonly property real ly: ay + ah - lh + (lh + 5) * lOff
    // Clipboard preview (bottom, right of the launcher), Caelestia PR #1298's
    // ClipboardPreview: its own panel a gap from the launcher, sized to what
    // it shows (ClipboardPreview.fit): an image to its aspect ratio, up to the
    // room right of the launcher; text 400px wide and as tall as the text.
    // Neither is ever taller than the launcher itself. The last row stays on it while it slides away.
    readonly property bool cpVis: cpOff < 1
    property var cpRow: null
    readonly property real cpPadH: Tk.padding.large * 2
    readonly property real cpPadV: Tk.padding.large + Math.max(0, Tk.padding.large - Tk.border)
    // The PR's gap is spacing.large + 4. Here it is two frame fillets wide,
    // so each panel's arc into the frame is full-size and the two meet flat
    // on it as one round U (blob.frag narrows them if it is ever less).
    readonly property real cpGap: Tk.smoothing * 2
    readonly property real cpMaxW: Math.max(Tk.px(200), Math.min(Tk.px(640), ax + aw - (lx + lw + cpGap) - Tk.padding.large) - cpPadH)
    readonly property real cpMaxH: Math.max(Tk.px(80), lh - cpPadV)
    readonly property size cpFit: cpLoader.item ? cpLoader.item.fit : Qt.size(0, 0)
    readonly property real cpTextW: Tk.px(400) - cpPadH
    property real cpw: cpFit.width > 0 ? cpFit.width + cpPadH : Tk.px(400)
    property real cph: cpFit.height > 0 ? cpFit.height + cpPadV : lh
    Behavior on cpw { enabled: win.cpOff < 1; Anim {} }
    Behavior on cph { enabled: win.cpOff < 1; Anim {} }
    readonly property real cpx: lx + lw + cpGap
    readonly property real cpy: ay + ah - cph + (cph + 5) * cpOff
    // Session (right centre). With the sidebar out it sits against the
    // sidebar instead of the frame, and slides out from behind it, clipped at
    // its edge (Caelestia Panels.qml sessionWrapper, session/Wrapper.qml
    // sidebarOffset).
    readonly property real sw: sess ? sess.implicitWidth : 0
    readonly property real sh: sess ? sess.implicitHeight : 0
    readonly property real sShift: sbVis ? sbw * (1 - sbOff) : 0
    readonly property real sHide: sw + 5 + (sbVis ? 14 : 0)
    readonly property real sx: scope.mirror ? ax + sShift - sHide * sOff : ax + aw - sShift - sw + sHide * sOff
    readonly property real sy: ay + Math.round((ah - sh) / 2)
    // The session's clip: the panel area short of the sidebar.
    readonly property real sClipX: scope.mirror ? ax + sShift : ax
    readonly property real sClipW: Math.max(0, aw - sShift)
    readonly property real sMaskX: Math.max(sx, sClipX)
    readonly property real sMaskW: Math.max(0, Math.min(sx + sw, sClipX + sClipW) - sMaskX)
    // Popout (against the bar's edge, beside its icon)
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
        if (scope.popout !== "") win.pHandoff = false
        if (scope.popout !== "" && win.pOff >= 0.999) { win.pSettled = false; pSettle.restart() }
      }
    }
    readonly property bool pAnimate: pOff < 1 && pSettled
    property real pFade: scope.popout !== "" ? 1 : 0
    Behavior on pFade { Anim { type: "effects" } }
    Behavior on pw { enabled: win.pAnimate; Anim {} }
    Behavior on ph { enabled: win.pAnimate; Anim {} }
    // Along the bar: centred on its icon, kept inside the panel area.
    property real pa: {
      const size = scope.barVert ? phTarget : pwTarget
      const lo = scope.barVert ? ay : ax
      const span = scope.barVert ? ah : aw
      return Math.max(lo, Math.min(scope.popoutCenter - size / 2, lo + span - size))
    }
    Behavior on pa { enabled: win.pAnimate; Anim {} }
    // Across the bar: out of its edge, sliding in from behind it. A popout
    // pressed against an end of the panel area squares its corner there by
    // itself (the blob's corner fill), as Caelestia's does.
    readonly property real pax: scope.barVert ? (scope.barPos === "left" ? ax + (-pw - 5) * pOff : ax + aw - pw + (pw + 5) * pOff) : pa
    readonly property real pay: scope.barVert ? pa : (scope.barPos === "top" ? ay + (-ph - 5) * pOff : ay + ah - ph + (ph + 5) * pOff)
    // Detached (the window info panel): the popout leaves the bar and floats
    // in the middle of the panel area over a scrim, and on closing flies back
    // to the bar before it slides in (Caelestia bar/popouts/Wrapper.qml
    // detach(), ClipWrapper.qml).
    readonly property bool pDetachWanted: scope.popout === "winfo"
    property real pDet: pDetachWanted ? 1 : 0
    Behavior on pDet { Anim {} }
    readonly property real px: pax + (ax + Math.round((aw - pw) / 2) - pax) * pDet
    readonly property real py: pay + (ay + Math.round((ah - ph) / 2) - pay) * pDet
    // What of it the panel area shows.
    readonly property real pcx: Math.max(ax, px)
    readonly property real pcy: Math.max(ay, py)
    readonly property real pcw: Math.max(0, Math.min(ax + aw, px + pw) - pcx)
    readonly property real pch: Math.max(0, Math.min(ay + ah, py + ph) - pcy)
    // The shader rect reaches 20% behind the bar so the popout never comes
    // off it, even squashed by its deformation (Caelestia's extraWidth, gone
    // once detached).
    readonly property real pExtra: 0.2 * (1 - pDet)
    readonly property real prx: px - (scope.barPos === "left" ? pw * pExtra : 0)
    readonly property real pry: py - (scope.barPos === "top" ? ph * pExtra : 0)
    readonly property real prw: scope.barVert ? pw * (1 + pExtra) : pw
    readonly property real prh: scope.barVert ? ph : ph * (1 + pExtra)
    // Settings (floating, centred) — grows out of a small pill.
    readonly property real nfw: nexus ? nexus.implicitWidth : 0
    readonly property real nfh: nexus ? nexus.implicitHeight : 0
    // Opened from a popout, it starts as that popout's rect and grows into
    // place from there, and on closing goes back to the bar and into it;
    // otherwise it grows out of a small pill in the middle.
    property var nOrigin: null
    // The popout whose blob has become Settings: drawn no more, its slide
    // away left to finish unseen.
    property bool pHandoff: false
    function handOffPopout() {
      if (!pVis || pOff > 0.5 || scope.popout === "" || pDetachWanted) return
      nOrigin = [prx, pry, prw, prh]
      pHandoff = true
    }
    // The popout's rect slid all the way behind the bar.
    readonly property var nOriginAway: !nOrigin ? null
      : scope.barPos === "left" ? [nOrigin[0] - pw - 5, nOrigin[1], nOrigin[2], nOrigin[3]]
      : scope.barPos === "right" ? [nOrigin[0] + pw + 5, nOrigin[1], nOrigin[2], nOrigin[3]]
      : scope.barPos === "top" ? [nOrigin[0], nOrigin[1] - ph - 5, nOrigin[2], nOrigin[3]]
      : [nOrigin[0], nOrigin[1] + ph + 5, nOrigin[2], nOrigin[3]]
    readonly property var nFrom: nOrigin ? (scope.settings ? nOrigin : nOriginAway) : null
    function nLerp(a, b) { return a + (b - a) * (1 - nOff) }
    readonly property real nw: nFrom ? nLerp(nFrom[2], nfw) : nfw * (1 - 0.55 * nOff)
    readonly property real nh: nFrom ? nLerp(nFrom[3], nfh) : nfh * (1 - 0.8 * nOff)
    readonly property real nx: nFrom ? nLerp(nFrom[0], ax + Math.round((aw - nfw) / 2)) : ax + Math.round((aw - nw) / 2)
    readonly property real ny: nFrom ? nLerp(nFrom[1], ay + Math.round((ah - nfh) / 2)) : ay + Math.round((ah - nh) / 2)
    onNVisChanged: if (!nVis && !scope.settings) nOrigin = null
    onPOffChanged: if (pOff >= 1) pHandoff = false
    // Overview — the same grow as Settings. In the middle it floats; at the
    // top or bottom (Settings › Panels › Overview › Position) it grows out of
    // that frame edge instead, as the dashboard and launcher do.
    readonly property string oPos: scope.cfg.overview.position
    // Detached, a top/bottom overview floats like the middle one, a gap off
    // its frame edge, instead of growing out of it.
    readonly property bool oAttached: oPos !== "middle" && !scope.cfg.overview.detached
    readonly property real oGap: oAttached ? 0 : scope.cfg.overview.gap
    readonly property real ofw: overviewContent ? overviewContent.implicitWidth : 0
    readonly property real ofh: overviewContent ? overviewContent.implicitHeight : 0
    readonly property real ow: ofw * (1 - 0.55 * oOff)
    readonly property real oh: ofh * (1 - 0.8 * oOff)
    readonly property real ox: ax + Math.round((aw - ow) / 2)
    readonly property real oy: oPos === "top" ? ay + oGap : oPos === "bottom" ? ay + ah - oh - oGap : ay + Math.round((ah - oh) / 2)
    // Sidebar (top right, above utilities)
    readonly property real sbw: Tk.sizes.sidebarWidth
    readonly property real sbx: sideX(sbw, sbOff)
    readonly property real sby: scope.flipV ? Math.min(ay + ah, uy + uh) : ay
    // Anchored to the utilities' top edge, as Caelestia's Sidebar.Wrapper.
    readonly property real sbh: scope.flipV ? Math.max(0, ay + ah - sby) : Math.max(0, Math.min(ah, uy - ay))
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
    // The sidebar's width including its overshoot, widened by half its
    // horizontal stretch while it deforms (ContentWindow.qml
    // utilities.horizontalStretch).
    readonly property real uHStretch: (sbDeform.m00 - 1) / 2 + 1
    readonly property real uw: sbw * (1 - sbOff) * uHStretch * sbLerp + Tk.sizes.utilitiesWidth * (1 - sbLerp)
    readonly property real uh: (util && util.implicitHeight > 0) ? util.implicitHeight : Tk.px(450)
    readonly property real ux: scope.mirror ? ax : ax + aw - uw
    readonly property real uy: scope.flipV ? ay - (uh + 5) * uOff : ay + ah - uh + (uh + 5) * uOff
    // The part of it the panel area shows.
    readonly property real uMaskY: scope.flipV ? Math.max(ay, uy) : uy
    readonly property real uMaskH: scope.flipV ? Math.max(0, uy + uh - uMaskY) : Math.max(0, ay + ah - uy)
    // The sidebar's shader rect: 2px over the utilities so the join never
    // shows a seam, and taller by its vertical squash so a deformed sidebar
    // still reaches them (ContentWindow.qml sidebarBg implicitHeight).
    readonly property real sbRectH: sbh / Math.max(0.5, sbDeform.m11) + 2
    readonly property real sbRectY: scope.flipV ? sby + sbh - sbRectH : sby
    // Caelestia's PanelBg: the corners they share square up over the last
    // 30% of the sidebar's slide, and their fillet is dropped once it is
    // within 8% of in place.
    readonly property real joinRound: Math.max(0, Math.min(1, sbOff / 0.3))
    readonly property bool joinExcluded: sbOff <= 0.08

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
      Region { intersection: Intersection.Subtract; x: win.cpx; y: win.cpy; width: win.cpVis && !win.modal ? win.cpw : 0; height: win.cpVis ? Math.max(0, win.ay + win.ah - win.cpy) : 0 }
      Region { intersection: Intersection.Subtract; x: win.sMaskX; y: win.sy; width: win.sVis && !win.modal ? win.sMaskW : 0; height: win.sVis ? win.sh : 0 }
      Region { intersection: Intersection.Subtract; x: win.pcx; y: win.pcy; width: win.pVis && !win.modal ? win.pcw : 0; height: win.pVis ? win.pch : 0 }
      Region { intersection: Intersection.Subtract; x: win.ux; y: win.uMaskY; width: win.uVis && !win.modal ? Math.max(0, win.uw) : 0; height: win.uVis ? win.uMaskH : 0 }
      Region { intersection: Intersection.Subtract; x: win.sideMaskX(win.sbx); y: win.sby; width: win.sbVis && !win.modal ? win.sideMaskW(win.sbx, win.sbw) : 0; height: win.sbVis ? win.sbh : 0 }
    }

    // Hyprland hands the keyboard to a window on the workspace you switch to,
    // and to *nothing at all* when that workspace is empty -- an OnDemand
    // layer surface is not offered it back, so the panel that asked for the
    // switch stops receiving keys. Taking the grab again puts the keyboard
    // back on this window; the overview asks for that after every switch.
    property bool focusPrimed: true
    function primeFocus() {
      focusPrimed = false
      primeTimer.restart()
      primeSettle.restart()
    }
    // The prime's switch from Exclusive to OnDemand clears the focus grab,
    // which would close the popout it was opening; for a moment after a
    // keyboard open, a cleared grab is taken again instead.
    Timer {
      id: primeSettle
      interval: 400
    }
    Timer {
      id: primeTimer
      interval: 120
      onTriggered: {
        win.focusPrimed = true
        Qt.callLater(() => scope.popout !== "" ? pop.forceActiveFocus() : scope.barFocus ? bar.takeKeys()
          : scope.drawerKeys ? drawerKeyItem.forceActiveFocus() : null)
      }
    }

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
        if (scope.overview && overviewContent) overviewContent.forceActiveFocus()
        else if (scope.barFocus && scope.popout === "") bar.takeKeys()
      }
    }
    readonly property bool grabWanted: scope.barFocus || scope.launcher || scope.session || scope.settings || scope.overview || scope.sidebar || (scope.utilities && scope.utilShortcut) || (scope.dashboard && scope.dashShortcut) || scope.popoutSticky
    HyprlandFocusGrab {
      id: grab
      windows: [win]
      active: win.grabWanted
      onCleared: {
        if (win.regrabbing) return
        if (scope.overview || primeSettle.running || wsSettle.running) {
          regrabTimer.restart()
        } else {
          scope.closeAll()
        }
      }
    }

    // Holds the keyboard for the dashboard / sidebar / utilities cursor.
    Item {
      id: drawerKeyItem
      Keys.onPressed: e => scope.drawerKey(e)
    }

    // ---------------------------------------------------- scrim
    Rectangle {
      anchors.fill: parent
      color: Colours.m3scrim
      opacity: 0.5 * Math.max(1 - win.nOff, 1 - win.oOff, Math.min(1, win.pDet))
      visible: opacity > 0
    }

    // ------------------------------------------------------- jelly
    // Caelestia's BlobRect deformation (ContentWindow.qml PanelBg
    // deformAmount): each drawer stretches along its motion and wobbles once
    // as it settles; the same matrix is applied to its content below.
    BlobDeform { id: dashDeform; amount: 0.1; cx: win.dx + win.dw / 2; cy: win.dy + win.dh / 2 }
    BlobDeform { id: launchDeform; amount: 0.1; cx: win.lx + win.lw / 2; cy: win.ly + win.lh / 2 }
    BlobDeform { id: cpDeform; amount: 0.1; cx: win.cpx + win.cpw / 2; cy: win.cpy + win.cph / 2 }
    BlobDeform { id: sessDeform; amount: 0.2; cx: win.sx + win.sw / 2; cy: win.sy + win.sh / 2 }
    BlobDeform {
      id: popDeform
      amount: win.pDetachWanted ? 0.05 : scope.popout !== "" ? 0.15 : 0.1
      cx: win.prx + win.prw / 2
      cy: win.pry + win.prh / 2
    }
    BlobDeform { id: nDeform; amount: 0.05; cx: win.nx + win.nw / 2; cy: win.ny + win.nh / 2 }
    BlobDeform { id: sbDeform; amount: 0.03; cx: win.sbx + win.sbw / 2; cy: win.sbRectY + win.sbRectH / 2 }
    BlobDeform { id: utilDeform; amount: win.sbVis ? 0.1 : 0.15; cx: win.ux + win.uw / 2; cy: win.uy + win.uh / 2 }

    // ---------------------------------------------------- background
    Item {
      anchors.fill: parent
      // Caelestia draws the blob opaque and fades the whole layer (and so
      // its shadow) by the surface's alpha.
      opacity: Colours.m3surface.a
      // Only when there is a shadow to draw. The layer is a screen-sized
      // texture that the frame shader renders into and MultiEffect then
      // blurs; with shadows off that whole round trip produced the same
      // pixels the shader can write straight to the window.
      layer.enabled: scope.cfg.appearance.shadow
      layer.effect: MultiEffect {
        shadowEnabled: true
        blurMax: 15
        shadowColor: Qt.alpha(Colours.m3shadow, 0.7 * Math.max(0, 1 - win.fs))
      }

      BlobSurface {
        anchors.fill: parent
        hole: Qt.rect(win.ax, win.ay, win.aw, win.ah)
        frameRadius: Tk.borderRounding * (1 - win.fs)
        color: Qt.alpha(Colours.m3surface, 1)
        Behavior on color { CAnim {} }

        // r0 dashboard, r1 launcher, r2 session, r3 popout, r4 settings,
        // r5 utilities, r6 sidebar, r7 overview, r8 clipboard preview.
        rects: [
          win.dVis ? [win.dx, win.dy, win.dw, win.dh] : null,
          win.lVis ? [win.lx, win.ly, win.lw, win.lh] : null,
          win.sVis ? [win.sx, win.sy, win.sw, win.sh] : null,
          win.pVis && !win.pHandoff ? [win.prx, win.pry, win.prw, win.prh] : null,
          win.nVis ? [win.nx, win.ny, win.nw, win.nh] : null,
          win.uVis ? [win.ux, win.uy, win.uw, win.uh] : null,
          win.sbVis ? [win.sbx, win.sbRectY, win.sbw, win.sbRectH] : null,
          win.oVis ? [win.ox, win.oy, win.ow, win.oh] : null,
          win.cpVis ? [win.cpx, win.cpy, win.cpw, win.cph] : null
        ]
        deforms: [dashDeform.vec, launchDeform.vec, sessDeform.vec, popDeform.vec, nDeform.vec,
                  utilDeform.vec, sbDeform.vec, null, cpDeform.vec]
        // The corner the sidebar and utilities share flattens as the sidebar
        // comes in (its left side; the right, with a right-hand bar; the
        // utilities' bottom and the sidebar's top, with a bottom bar).
        readonly property real jr: win.joinRound * Tk.rounding.extraLarge
        corners: [-1, -1, -1, -1, -1,
          scope.flipV ? [-1, -1, jr, -1] : scope.mirror ? [jr, -1, -1, -1] : [-1, -1, -1, jr],
          scope.flipV ? [-1, -1, -1, jr] : scope.mirror ? [-1, jr, -1, -1] : [-1, -1, jr, -1]]
        // The clipboard preview is its own panel beside the launcher, as
        // Caelestia PR #1298 draws it, not a bulge of it.
        excluded: win.joinExcluded ? [[1, 8], [5, 6]] : [[1, 8]]
      }
    }

    // ---------------------------------------------------- interactions
    MouseArea {
      id: interactions
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: win.fs > 0 ? Qt.NoButton : Qt.AllButtons
      property point dragStart

      // How far a point is from the bar's screen edge, and where it is along
      // the bar: the two axes the bar's hit tests work in.
      function barDepth(x, y) {
        return scope.barPos === "left" ? x : scope.barPos === "right" ? win.width - x : scope.barPos === "top" ? y : win.height - y
      }
      function barAlong(x, y) { return scope.barVert ? y : x }
      // A popout, and the bar between it and its edge.
      function inPopout(x, y) {
        const r = Tk.borderRounding
        const inX = x >= win.px - r && x <= win.px + win.pw + r
        const inY = y >= win.py - r && y <= win.py + win.ph + r
        if (scope.barPos === "left") return x < win.px + win.pw + r && inY
        if (scope.barPos === "right") return x > win.px - r && inY
        if (scope.barPos === "top") return y < win.py + win.ph + r && inX
        return y > win.py - r && inX
      }
      // Caelestia inBottomPanel(utilities, isCorner = true), measured from the
      // panel area's bottom edge.
      // The utilities' hover corner: the bottom of the panel area, or its top
      // when a bottom bar has put them there.
      function inBottomUtil(x, y) {
        const visibleH = win.uh * (1 - win.uOff)
        const inX = x >= win.ux - Tk.borderRounding && x <= win.ux + win.uw + Tk.borderRounding
        if (scope.flipV) return y < win.ay + visibleH + Tk.borderRounding && inX
        return y > win.ay + win.ah - visibleH - Tk.borderRounding && inX
      }
      // The dashboard hovers from the panel area's top edge (below a bar on the
      // top edge, whose own strip belongs to its popouts).
      function inTopDash(x, y) {
        const visibleH = win.dh * (1 - win.dOff)
        const top = scope.barPos === "top" ? win.ay : 0
        return y >= top && y < Math.max(win.ay + visibleH, top + 2) && x >= win.dx - Tk.borderRounding && x <= win.dx + win.dw + Tk.borderRounding
      }
      // The right-hand drawers' side: is a press or drag at x on it.
      function nearSideEdge(x) {
        return scope.mirror ? x < win.ax + Tk.borderRounding : x > win.ax + win.aw - Tk.borderRounding
      }
      // A drag's distance toward the middle of the screen from the right-hand
      // drawers' edge (away from it, with a right-hand bar).
      function sideInward(dx) { return scope.mirror ? dx : -dx }

      onPressed: e => {
        dragStart = Qt.point(e.x, e.y)
        // A click on the scrim (outside the settings panel) closes it.
        if (scope.settings && !(e.x >= win.nx && e.x <= win.nx + win.nw && e.y >= win.ny && e.y <= win.ny + win.nh)) scope.settings = false
        if (scope.overview && !(e.x >= win.ox && e.x <= win.ox + win.ow && e.y >= win.oy && e.y <= win.oy + win.oh)) scope.overview = false
        if (scope.sidebar && (scope.mirror ? e.x > win.sbx + win.sbw : e.x < win.sbx)) scope.sidebar = false
        if (scope.utilities && !scope.sidebar && ((scope.mirror ? e.x > win.ux + win.uw : e.x < win.ux) || (scope.flipV ? e.y > win.uy + win.uh : e.y < win.uy))) scope.utilities = false
      }
      onContainsMouseChanged: {
        if (containsMouse) return
        bar.hoverAt(-1, false)
        if (!scope.dashShortcut) scope.dashboard = false
        if (!scope.utilShortcut) scope.utilities = false
        if (!scope.popoutSticky) scope.popout = ""
        scope.barHover = false
      }
      onWheel: e => { if (!scope.barOff && barDepth(e.x, e.y) < win.bw) bar.handleWheel(barAlong(e.x, e.y), e.angleDelta.y) }
      onPositionChanged: e => {
        if (win.fs > 0 || scope.settings) return
        const x = e.x, y = e.y, dx = x - dragStart.x, dy = y - dragStart.y

        // Auto-hiding bar: reveal at the bar's edge, hide once well away.
        if (!scope.cfg.bar.persistent && !scope.barOff) {
          const depth = barDepth(x, y)
          if (scope.cfg.bar.showOnHover && depth <= Math.max(Tk.border, 2)) scope.barHover = true
          else if (depth > Tk.barWidth + Tk.borderRounding && !(scope.popout !== "" && inPopout(x, y))) scope.barHover = false
          const drag = scope.barPos === "left" ? dx : scope.barPos === "right" ? -dx : scope.barPos === "top" ? dy : -dy
          if (pressed && barDepth(dragStart.x, dragStart.y) <= Math.max(Tk.border, 2) && drag > 20) scope.barHover = true
        }

        // Session: drag in from the right-hand edge.
        if (scope.cfg.session.enabled && pressed && nearSideEdge(dragStart.x) && Math.abs(y - (win.sy + win.sh / 2)) < win.sh / 2 + Tk.borderRounding) {
          if (sideInward(dx) > scope.cfg.session.dragThreshold) scope.session = true
          else if (sideInward(dx) < -scope.cfg.session.dragThreshold) scope.session = false
        }
        // Sidebar: drag in from the top of that edge, or drag back out to close
        if ((!scope.cfg.sidebar || scope.cfg.sidebar.enabled) && pressed && !scope.sidebar && nearSideEdge(dragStart.x) && (scope.flipV ? y > win.sy + win.sh : y < win.sy) && sideInward(dx) > 30) {
          scope.sidebar = true
        } else if (pressed && scope.sidebar && (scope.mirror ? dragStart.x <= win.sbx + win.sbw : dragStart.x >= win.sbx) && sideInward(dx) < -40) {
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
          // Caelestia hands a shortcut-opened dashboard to the pointer once it
          // hovers it -- which also takes the keyboard away. Not mid-way
          // through keyboard navigation: the keys would land in the window
          // behind (a held key kept repeating there).
          else if (showDash && !drawerNav.cursor) scope.dashShortcut = false
        }

        // Utilities: hover the bottom-right corner.
        if (!scope.cfg.utilities || scope.cfg.utilities.enabled) {
          const showUtil = inBottomUtil(x, y)
          if (!scope.utilShortcut) scope.utilities = showUtil
          else if (showUtil && !drawerNav.cursor) scope.utilShortcut = false
        }

        updatePointer(x, y)
      }

      // Bar popouts and the collapsible groups (compact tray, plugin
      // overflow), for a pointer at window coordinates x, y.
      function updatePointer(x, y) {
        const onBar = barDepth(x, y) < win.bw && win.barProg > 0.5
        bar.hoverAt(barAlong(x, y), onBar)

        if (scope.popoutHeld) return
        if (onBar) {
          const p = bar.popoutAt(barAlong(x, y))
          if (p) {
            if (p.name === "traymenu") {
              if (scope.popout !== "traymenu" || scope.trayItem !== p.item) { scope.trayItem = p.item; scope.popout = ""; scope.popout = "traymenu" }
            } else scope.popout = p.name
            scope.popoutCenter = p.center
          } else if (scope.popout !== "traymenu") scope.popout = ""
        } else if (!inPopout(x, y)) {
          // Off the bar and out of the popout: the tray menu goes too, so a
          // compact tray doesn't stay open behind it.
          scope.popout = ""
        }
      }

      // The pointer leaving the bar is invisible here: the window's input
      // mask means no event arrives, and Qt keeps hover state (containsMouse
      // never goes false). While a group is open -- and only then -- ask
      // Hyprland where the cursor is; Quickshell has no cursor API.
      Timer {
        id: pointerPoll
        interval: 350
        repeat: true
        running: bar.groupsExpanded
        onTriggered: if (!cursorProc.running) cursorProc.running = true
      }
      Process {
        id: cursorProc
        command: ["hyprctl", "cursorpos"]
        stdout: StdioCollector {
          onStreamFinished: {
            const p = String(text).split(",")
            if (p.length < 2 || !scope.screen) return
            const gx = Number(p[0]), gy = Number(p[1])
            if (!isFinite(gx) || !isFinite(gy)) return
            interactions.updatePointer(gx - scope.screen.x, gy - scope.screen.y)
          }
        }
      }

      BarContent {
        id: bar
        // Slides in from its edge as the frame's breadth on it grows.
        x: scope.barPos === "left" ? win.bw - Tk.barWidth : scope.barPos === "right" ? win.width - win.bw : 0
        y: scope.barPos === "top" ? win.bw - Tk.barWidth : scope.barPos === "bottom" ? win.height - win.bw : 0
        width: scope.barVert ? Tk.barWidth : win.width
        height: scope.barVert ? win.height : Tk.barWidth
        vertical: scope.barVert
        // Slid, never faded, with the frame's breadth; gone as soon as it
        // starts to hide (Caelestia's content Loader is active only while
        // the bar should be visible).
        opacity: 1 - win.fs
        visible: opacity > 0 && win.barShown && win.bw > Tk.border
        screen: scope.screen
        host: scope.host
        scope: scope
        keyMode: scope.barFocus
      }

      // ---- tooltip bubble for widgets
      Rectangle {
        id: tooltipBubble
        visible: scope.host.tooltipShown && scope.host.tooltipText !== "" && scope.host.tooltipTarget !== null
        // The target's centre, mapped: hosted widgets are scaled and may be
        // turned, so its (0,0) plus half its height is not its middle.
        readonly property point targetPt: {
          var t = scope.host.tooltipTarget
          if (!t) return Qt.point(0, 0)
          try {
            return t.mapToItem(win.contentItem, t.width / 2, t.height / 2)
          } catch (e) {
            return Qt.point(0, 0)
          }
        }
        // Beside the widget, away from the bar's edge.
        x: scope.barVert
          ? (scope.barPos === "left" ? Tk.barWidth + Tk.spacing.small : win.width - Tk.barWidth - Tk.spacing.small - width)
          : Math.max(Tk.padding.medium, Math.min(targetPt.x - width / 2, win.width - width - Tk.padding.medium))
        y: scope.barVert
          ? Math.max(Tk.padding.medium, Math.min(targetPt.y - height / 2, win.height - height - Tk.padding.medium))
          : (scope.barPos === "top" ? Tk.barWidth + Tk.spacing.small : win.height - Tk.barWidth - Tk.spacing.small - height)
        z: 999
        implicitWidth: tipText.implicitWidth + Tk.padding.medium * 2
        implicitHeight: tipText.implicitHeight + Tk.padding.small * 2
        radius: Tk.rounding.small
        color: Colours.m3surfaceContainerHigh
        border.color: Colours.m3outlineVariant
        border.width: 1
        opacity: visible ? 1 : 0
        Behavior on opacity { Anim { type: "effects" } }
        MText {
          id: tipText
          anchors.centerIn: parent
          text: scope.host.tooltipText
          font.pointSize: Tk.body.small
          color: Colours.m3onSurface
        }
      }

      // ---- popout
      Item {
        x: win.pcx
        y: win.pcy
        width: win.pcw
        height: win.pch
        visible: win.pVis
        clip: true
        Item {
          x: win.px - win.pcx
          y: win.py - win.pcy
          width: win.pw
          height: win.ph
          // Caelestia's popout Wrapper fades its content in and out (200ms)
          // while the popout slides.
          opacity: win.pHandoff ? 0 : (1 - win.pOff) * win.pFade
          transform: Matrix4x4 { matrix: popDeform.matrixAt(win.prx + win.prw / 2 - win.px, win.pry + win.prh / 2 - win.py) }
          PopoutContent {
            id: pop
            // Centred in the animating popout, as Caelestia's pages are, so
            // a page switch grows and shrinks around the content.
            x: Math.round((win.pw - width) / 2)
            y: Math.round((win.ph - height) / 2)
            width: implicitWidth
            height: implicitHeight
            host: scope.host
            trayItem: scope.trayItem
            screen: scope.screen
            open: scope.popout !== ""
            property string lastName: ""
            name: scope.popout !== "" ? scope.popout : lastName
            onNameChanged: if (scope.popout !== "") lastName = scope.popout
            passwordSsid: scope.passwordSsid
            onCloseRequested: scope.popout = ""
            keyMode: scope.popoutKeys
            onTabRequested: d => scope.tabPopout(d)
            onSwitchRequested: (name, arg) => {
              if (name === "wirelesspassword") scope.passwordSsid = arg
              scope.popout = name
            }
          }
        }
      }

      // ---- dashboard
      Loader {
        id: dashLoader
        active: scope.dashboard || win.dVis
        sourceComponent: Dashboard {
          x: win.dx
          y: win.dy
          width: win.dw
          height: win.dh
          visible: win.dVis
          opacity: 1 - win.dOff
          transform: Matrix4x4 { matrix: dashDeform.matrixAt(win.dw / 2, win.dh / 2) }
          host: scope.host
          active: scope.dashboard
          tab: scope.dashTab
          onTabChanged: scope.dashTab = tab
          onFaceRequested: { scope.dashboard = false; facePicker.active = true }
        }
      }

      // ---- launcher
      Loader {
        id: launchLoader
        active: scope.launcher || win.lVis
        // A Loader is a focus scope: without `focus` on it, nothing inside can
        // hold the keyboard, and a drawer created on open has no earlier focus
        // to fall back on.
        focus: scope.launcher
        sourceComponent: Launcher {
          x: win.lx
          y: win.ly
          width: win.lw
          height: win.lh
          visible: win.lVis
          opacity: 1 - win.lOff
          transform: Matrix4x4 { matrix: launchDeform.matrixAt(win.lw / 2, win.lh / 2) }
          active: scope.launcher
          screenWidth: win.width
          sideMargin: scope.sidebar || scope.utilities ? (scope.sidebar ? win.sbw : Tk.sizes.utilitiesWidth) : 0
          maxHeight: win.ah - (scope.dashboard ? win.dh : 0) + Tk.padding.extraLarge
          onDismissed: scope.launcher = false
          onOpenSettings: { scope.launcher = false; scope.settings = true }
          onClipRowChanged: if (clipRow) win.cpRow = clipRow
        }
      }

      // ---- clipboard preview (beside the launcher)
      Loader {
        id: cpLoader
        active: win.cpVis
        sourceComponent: ClipboardPreview {
          x: win.cpx + Tk.padding.large
          y: win.cpy + Tk.padding.large
          width: win.cpw - win.cpPadH
          height: win.cph - win.cpPadV
          opacity: 1 - win.cpOff
          transform: Matrix4x4 { matrix: cpDeform.matrixAt(win.cpw / 2 - Tk.padding.large, win.cph / 2 - Tk.padding.large) }
          row: win.cpRow
          maxW: win.cpMaxW
          maxH: win.cpMaxH
          textW: win.cpTextW
        }
      }

      // ---- session
      // Clipped at the sidebar's edge while the sidebar is out, so the menu
      // slides out from behind it (Caelestia Panels.qml sessionWrapper clip).
      Item {
        x: win.sClipX
        y: 0
        width: win.sClipW
        height: win.height
        clip: win.sbVis
        Loader {
          id: sessLoader
          active: scope.session || win.sVis
          focus: scope.session
          sourceComponent: Session {
            mirror: scope.mirror
            x: win.sx - win.sClipX
            y: win.sy
            visible: win.sVis
            opacity: 1 - win.sOff
            transform: Matrix4x4 { matrix: sessDeform.matrixAt(win.sw / 2, win.sh / 2) }
            active: scope.session
            onDismissed: scope.session = false
          }
        }
      }

      // ---- sidebar
      Loader {
        id: sidebarLoader
        active: scope.sidebar || win.sbVis
        sourceComponent: Sidebar {
          x: win.sbx
          y: win.sby
          width: win.sbw
          height: win.sbh
          visible: win.sbVis
          opacity: 1 - win.sbOff
          transform: Matrix4x4 { matrix: sbDeform.matrixAt(win.sbw / 2, win.sbRectY + win.sbRectH / 2 - win.sby) }
          host: screenScope.host
          scope: screenScope
          active: screenScope.sidebar
        }
      }

      // ---- utilities
      Loader {
        id: utilLoader
        active: scope.utilities || scope.sidebar || win.uVis
        sourceComponent: Utilities {
          x: win.ux
          y: win.uy
          width: win.uw
          visible: win.uVis
          opacity: 1 - win.uOff
          transform: Matrix4x4 { matrix: utilDeform.matrixAt(win.uw / 2, win.uh / 2) }
          hStretch: utilDeform.m00
          host: screenScope.host
          scope: screenScope
          active: screenScope.utilities || screenScope.sidebar
        }
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
        Loader {
          id: overviewLoader
          focus: scope.overview
          // Unsized, so the drawer keeps its own size; placed here instead,
          // against the frame edge it grows out of.
          anchors.horizontalCenter: parent.horizontalCenter
          y: win.oPos === "top" ? 0 : win.oPos === "bottom" ? parent.height - height : (parent.height - height) / 2
          active: scope.overview || win.oVis
          sourceComponent: Overview {
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
      }

      // ---- settings
      Item {
        x: win.nx
        y: win.ny
        width: win.nw
        height: win.nh
        visible: win.nVis
        clip: true
        Loader {
          id: nexusLoader
          focus: scope.settings
          // Unsized, so the drawer keeps its own size; centred here instead.
          anchors.centerIn: parent
          active: scope.settings || win.nVis
          sourceComponent: Settings {
            width: implicitWidth
            height: implicitHeight
            opacity: Math.max(0, 1 - win.nOff * 2.5)
            scale: 0.94 + 0.06 * (1 - win.nOff)
            transform: Matrix4x4 { matrix: nDeform.matrixAt(width / 2, height / 2) }
            active: scope.settings
            screenWidth: scope.screen.width
            screenHeight: scope.screen.height
            version: scope.host.version
            onCloseRequested: scope.settings = false
            onPopOutRequested: { scope.settings = false; scope.settingsWindow = true }
            keyHook: e => screenScope.drawerKey(e)
            pageId: scope.nexusPage
            stack: scope.nexusStack
            onPageIdChanged: scope.nexusPage = pageId
            onStackChanged: scope.nexusStack = stack
          }
        }
      }
    }
  }
}
