import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import "../.."

// The Caelestia bar: logo, workspaces, active window, tray, clock, status
// icons, power — in Caelestia's default order and metrics.
Item {
  id: root

  required property var screen
  required property var host
  required property var scope
  // A column on the left or right edge; a row on the top or bottom one.
  property bool vertical: true

  readonly property int vPadding: Tk.padding.large
  readonly property var cfg: Config.o.bar
  readonly property real gap: Tk.spacing.medium

  // "Along" is the bar's own axis: a height on a column, a width on a row.
  // Nothing below measures a bar item in x or y without going through these.
  readonly property int crossAlign: vertical ? Qt.AlignHCenter : Qt.AlignVCenter
  function along(item) { return vertical ? item.implicitHeight : item.implicitWidth }
  function apos(item) { return vertical ? item.y : item.x }
  function alen(item) { return vertical ? item.height : item.width }
  // A point `a` along the bar, in `item`'s coordinates.
  function pointOn(item, a) { return vertical ? mapToItem(item, 0, a) : mapToItem(item, a, 0) }
  function pointAlong(p) { return vertical ? p.y : p.x }
  // The middle of `item` along the bar, in the bar's coordinates.
  function centreOf(item) {
    return vertical ? item.mapToItem(root, 0, item.height / 2).y : item.mapToItem(root, item.width / 2, 0).x
  }

  // ------------------------------------------------------ space budget
  // The active window title is the bar's flexible space. The tray and the
  // plugins pill share what's left above its minimum, instead of each taking
  // a fixed share. The budget is the column's height less everything that
  // doesn't give way, worked out rather than read back from the layout, so it
  // doesn't move when the tray or plugins collapse. When the tray's full list
  // and the plugins' pinned widgets don't fit, the tray goes compact first;
  // the plugins pill then scrolls, pinned widgets too. On a short screen the
  // clock's calendar icon, then the workspaces' window icons, go before the
  // tray and plugins reach their minimum. The logo, clock, status icons and
  // power never shrink, so they are never pushed off the bottom.
  readonly property real titleMin: cfg.activeWindow.enabled ? Tk.barInner * 3 : Tk.barInner
  readonly property real fixedLen: {
    const rows = [logoRow, workspaces, titleArea, pluginPlace, trayPill, clockPill, statusPill, powerItem]
    const n = rows.filter(r => r.visible).length
    return (logoRow.visible ? along(logoRow) : 0) + workspaces.bareSize
      + (clockPill.visible ? along(clockPill) : 0) - (calIconShown ? calendarLen : 0)
      + (statusPill.visible ? along(statusPill) : 0) + (powerItem.visible ? along(powerItem) : 0)
      + gap * Math.max(0, n - 1)
  }
  readonly property real flexRoom: alen(col) - fixedLen - titleMin
  readonly property real flexMin: (trayPill.visible ? trayPill.collapsedLen : 0) + (pluginPlace.visible ? pluginPill.minLen : 0)
  // Both worked out whether or not they are shown, so hiding one can't
  // bring it straight back.
  readonly property real calendarLen: cfg.clock.enabled && cfg.clock.showIcon ? (vertical ? calIcon.implicitHeight + clockCol.spacing : calIconH.implicitWidth + clockRow.spacing) : 0
  // Set a tick late rather than bound: the clock's size, and so
  // fixedLen, reads the icon's visibility, which reads this.
  property bool calendarFits: true
  readonly property bool calIconShown: cfg.clock.showIcon && calendarFits
  function refitCalendar() { calendarFits = flexRoom - flexMin >= calendarLen + workspaces.iconsSize }
  onFlexRoomChanged: Qt.callLater(refitCalendar)
  onFlexMinChanged: Qt.callLater(refitCalendar)
  onCalendarLenChanged: Qt.callLater(refitCalendar)
  Connections { target: workspaces; function onIconsSizeChanged() { Qt.callLater(root.refitCalendar) } }
  readonly property bool windowIconsFit: flexRoom - flexMin - (calendarFits ? calendarLen : 0) >= workspaces.iconsSize
  readonly property real budget: Math.max(0, flexRoom - (calendarFits ? calendarLen : 0) - (windowIconsFit ? workspaces.iconsSize : 0))
  readonly property bool trayOverBudget: trayPill.visible && trayPill.fullLen + pluginPill.collapsedLen > budget
  readonly property real trayReserve: !trayPill.visible ? 0 : trayPill.compact ? trayPill.collapsedLen : trayPill.fullLen

  // Popout lookup for a position `a` along the bar (Caelestia Bar.checkPopout).
  function popoutAt(a) {
    const p = pointAlong(pointOn(statusCol, a))
    if (cfg.popouts.statusIcons && p >= -statusPill.anchorsPad && p <= alen(statusCol) + statusPill.anchorsPad) {
      for (let i = 0; i < statusCol.children.length; i++) {
        const c = statusCol.children[i]
        if (!c.visible || !c.popout) continue
        if (p >= apos(c) - 3 && p <= apos(c) + alen(c) + 3)
          return { name: c.popout, center: centreOf(c) }
      }
    }
    const t = pointAlong(pointOn(trayCol, a))
    if (cfg.popouts.tray && trayPill.visible && (!trayPill.compact || trayPill.expanded) && t >= 0 && t <= alen(trayCol)) {
      for (let i = 0; i < trayRep.count; i++) {
        const it = trayRep.itemAt(i)
        if (t >= apos(it) - 4 && t <= apos(it) + alen(it) + 4)
          return { name: "traymenu", index: i, item: it.modelData, center: centreOf(it) }
      }
    }
    const w = pointAlong(pointOn(activeWin, a))
    if (cfg.popouts.activeWindow && activeWin.visible && w >= 0 && w <= alen(activeWin) && Sys.activeToplevel)
      return { name: "activewindow", center: centreOf(activeWin) }
    return null
  }

  // ------------------------------------------------------ bar focus
  //
  // No Caelestia original, and none in the stock bar: SUPER+CTRL+0 hands the
  // bar itself the keyboard (ScreenScope.barFocus) and a cursor walks every
  // item top to bottom with Omarchy's panel keys (KeyNav). Enter does what a
  // click does; an item with a popout opens it with the keys, and Escape
  // there comes back here. Drawn as one M3 focus ring that moves between
  // items, so none of them needs a focus state of its own.
  property bool keyMode: false
  property var cursorStop: null
  property int cursorIndex: -1

  // Everything the cursor can land on: { item, act, kind, ... }.
  function navStops() {
    const out = []
    const add = (item, act, extra) => {
      if (item && item.visible && item.width > 0 && item.height > 0)
        out.push(Object.assign({ item: item, act: act }, extra || {}))
    }
    if (cfg.logo) add(logo, () => root.leaveFor("launcher"))
    for (const ws of workspaces.navItems())
      add(ws, () => root.scope.switchWorkspace(ws.wsId), { kind: "workspace", wsId: ws.wsId })
    if (activeWin.visible && Sys.activeToplevel)
      add(activeWin, () => root.scope.openPopoutKeys("activewindow"))
    if (pluginPill.visible && pluginPill.anyShown)
      for (let i = 0; i < pluginRep.count; i++) {
        const slot = pluginRep.itemAt(i)
        if (slot && slot.shown && slot.activeItem)
          out.push({ item: slot, kind: "plugin", act: () => root.openPlugin(slot) })
      }
    if (trayPill.visible)
      for (let i = 0; i < trayRep.count; i++) {
        const it = trayRep.itemAt(i)
        if (it) out.push({ item: it, kind: "tray", tray: it.modelData, act: () => it.modelData.activate() })
      }
    if (clockPill.visible) add(clockPill, () => root.leaveFor("dashboard"))
    for (let i = 0; i < statusCol.children.length; i++) {
      const c = statusCol.children[i]
      if (!c.visible || c instanceof Repeater) continue
      if (c.popout && c.popout !== "update") add(c, () => root.scope.openPopoutKeys(c.popout))
      else {
        const area = [...c.children].find(k => k instanceof MouseArea)
        if (area) add(c, () => { root.scope.barFocus = false; area.clicked(null) })
      }
    }
    if (cfg.power) add(powerItem, () => root.leaveFor("session"))
    return out
  }

  function sameStop(a, b) { return !!a && !!b && a.item === b.item }
  function setStop(s, i) {
    cursorStop = s
    cursorIndex = i
    // The compact tray and the plugin overflow open while the cursor is in them.
    const inTray = !!s && s.kind === "tray"
    if (inTray) { collapseTrayTimer.stop(); if (trayPill.compact) trayPill.expanded = true }
    else if (trayPill.expanded) collapseTrayTimer.restart()
    const inPlugins = !!s && s.kind === "plugin"
    if (inPlugins) { collapsePluginsTimer.stop(); if (pluginPill.overflowCount > 0) pluginPill.expanded = true }
    else if (pluginPill.expanded) collapsePluginsTimer.restart()
  }
  function stepStop(d) {
    const stops = navStops()
    if (!stops.length) return
    let i = stops.findIndex(s => sameStop(s, cursorStop))
    if (i < 0) i = Math.max(-1, Math.min(stops.length, cursorIndex) - (d > 0 ? 1 : 0))
    i = Math.max(0, Math.min(stops.length - 1, i + d))
    setStop(stops[i], i)
  }
  // The cursor starts on the workspace you are on.
  function startCursor() {
    const stops = navStops()
    const i = Math.max(0, stops.findIndex(s => s.kind === "workspace" && s.wsId === workspaces.activeId))
    setStop(stops[i] || null, stops.length ? i : -1)
  }
  function takeKeys() { forceActiveFocus() }
  onKeyModeChanged: {
    if (keyMode) startCursor()
    else setStop(null, -1)
  }

  // A drawer takes over from here: leave bar focus, then open it.
  function leaveFor(name) {
    scope.barFocus = false
    host.toggle(name)
  }
  // A hosted widget opens its own keyboard panel; the bar lets go.
  function openPlugin(slot) {
    scope.barFocus = false
    const it = slot.activeItem
    if (typeof it.toggle === "function") it.toggle()
    else if (typeof it.open === "function") it.open()
  }
  function openTrayMenu(stop) {
    if (!stop || !stop.tray || !stop.tray.hasMenu) return
    scope.trayItem = stop.tray
    scope.openPopoutKeys("traymenu")
  }

  KeyNav {
    id: barKeys
    onMoveRequested: (dx, dy) => root.stepStop(dx + dy > 0 ? 1 : -1)
    onActivateRequested: if (root.cursorStop) root.cursorStop.act()
    onCloseRequested: root.scope.barFocus = false
    onTabRequested: d => root.stepStop(d)
  }
  Keys.onPressed: e => {
    // Menu or Shift+F10: the tray item's own menu.
    if (e.key === Qt.Key_Menu || (e.key === Qt.Key_F10 && (e.modifiers & Qt.ShiftModifier))) {
      if (root.cursorStop && root.cursorStop.kind === "tray") root.openTrayMenu(root.cursorStop)
      e.accepted = true
      return
    }
    // 1..9: that workspace of the group on show.
    if (e.text >= "1" && e.text <= "9" && e.text.length === 1) {
      const n = Number(e.text)
      if (n <= workspaces.shown) root.scope.switchWorkspace(workspaces.groupOffset + n)
      e.accepted = true
      return
    }
    barKeys.handle(e)
  }

  // The cursor: Caelestia's workspace ActiveIndicator motion (its leading
  // edge runs ahead on defaultSpatial and the trailing one follows 1.5x
  // slower), drawn as M3's focus indicator -- an outline with a light tint,
  // the pills' own width, so it sits on the bar's shapes rather than across
  // them. It hugs its item: a short pill on an icon, a tall one on the clock.
  Rectangle {
    id: barCursor

    readonly property Item target: root.cursorStop ? root.cursorStop.item : null
    readonly property real pad: Tk.padding.small / 2 + 2
    property real start: 0
    property real end: 0
    // Where the target is now; re-read when anything above it moves.
    readonly property rect r: {
      void (col.y + col.x + titleArea.height + titleArea.width + trayPill.height + trayPill.width
        + pluginPill.height + pluginPill.width + statusPill.height + statusPill.width + workspaces.height + workspaces.width)
      if (!target) return Qt.rect(0, 0, 0, 0)
      const p = target.mapToItem(root, 0, 0)
      return Qt.rect(p.x, p.y, target.width, target.height)
    }
    function run() {
      if (!target) return
      const h = (root.vertical ? r.height : r.width) + pad * 2
      const mid = root.vertical ? r.y + r.height / 2 : r.x + r.width / 2
      const s = Math.round(mid - h / 2), e = s + Math.round(h)
      if (opacity === 0) { startAnim.stop(); endAnim.stop(); start = s; end = e; return }
      const up = s < start
      const lead = Tk.durations.defaultSpatial, trailing = lead * 1.5
      startAnim.stop(); endAnim.stop()
      startAnim.to = s; endAnim.to = e
      startAnim.duration = up ? lead : trailing
      endAnim.duration = up ? trailing : lead
      startAnim.start(); endAnim.start()
    }
    onRChanged: run()
    NumberAnimation { id: startAnim; target: barCursor; property: "start"; easing.type: Easing.BezierSpline; easing.bezierCurve: Tk.curves.defaultSpatial }
    NumberAnimation { id: endAnim; target: barCursor; property: "end"; easing.type: Easing.BezierSpline; easing.bezierCurve: Tk.curves.defaultSpatial }

    readonly property bool shown: root.keyMode && !!target
    z: 10
    // Along the bar it runs from start to end; across it is the pills' width.
    x: root.vertical ? Math.round((root.width - width) / 2) : start
    y: root.vertical ? start : Math.round((root.height - height) / 2)
    width: root.vertical ? Tk.barInner : Math.max(0, end - start)
    height: root.vertical ? Math.max(0, end - start) : Tk.barInner
    radius: Tk.barInner / 2
    color: Qt.alpha(Colours.m3primary, 0.14)
    border.width: 2
    border.color: Colours.m3primary
    opacity: shown ? 1 : 0
    scale: shown ? 1 : 0.85
    visible: opacity > 0
    Behavior on opacity { Anim { type: "effects" } }
    Behavior on scale { Anim { type: "fastSpatial" } }
    Behavior on color { CAnim {} }
    Behavior on border.color { CAnim {} }
  }

  // The popouts the status group offers, in bar order, as the user sees
  // them: what Omarchy's `togglePanelAt right N` counts (Bar.panelWidgetIdAt).
  // The microphone opens the same popout as the speaker, so it counts once.
  function statusPopouts() {
    const out = []
    for (let i = 0; i < statusCol.children.length; i++) {
      const c = statusCol.children[i]
      if (c.visible && c.popout && out.indexOf(c.popout) < 0)
        out.push(c.popout)
    }
    return out
  }

  // Where a popout opened without the pointer should sit: beside its icon,
  // or centred on the bar when the icon is hidden (a keyboard-layout popout
  // with the icon off still opens).
  function popoutCenterFor(name) {
    if (name === "traymenu" && cursorStop && cursorStop.kind === "tray")
      return centreOf(cursorStop.item)
    if (name === "activewindow" && activeWin.visible)
      return centreOf(activeWin)
    for (let i = 0; i < statusCol.children.length; i++) {
      const c = statusCol.children[i]
      if (c.visible && c.popout === name)
        return centreOf(c)
    }
    return vertical ? height / 2 : width / 2
  }

  // Which collapsible group the pointer is over, from ScreenScope (Caelestia
  // drives its compact tray the same way, in Bar.checkPopout). A hover
  // handler inside the bar is no good: leaving the layer surface altogether
  // never reaches it, and the group would stay open.
  // Open while the pointer is on the group; ScreenScope drives this.
  readonly property bool groupsExpanded: trayPill.expanded || pluginPill.expanded

  function hoverAt(a, onBar) {
    const t = pointAlong(pointOn(trayPill, a))
    if (onBar && trayPill.visible && t >= 0 && t <= alen(trayPill)) {
      collapseTrayTimer.stop()
      if (trayPill.compact) trayPill.expanded = true
    } else if (trayPill.expanded && !collapseTrayTimer.running) collapseTrayTimer.start()

    const p = pointAlong(pointOn(pluginPill, a))
    if (onBar && pluginPill.visible && p >= 0 && p <= alen(pluginPill)) {
      collapsePluginsTimer.stop()
      if (pluginPill.overflowCount > 0) pluginPill.expanded = true
    } else if (pluginPill.expanded && !collapsePluginsTimer.running) collapsePluginsTimer.start()
  }

  // The drawers' MouseArea takes every wheel over the bar, so a capped tray
  // never sees one and is scrolled from here (the plugin pill has its own
  // wheel catcher, see pluginPill).
  function scrollList(flick, a, dy) {
    const p = pointAlong(pointOn(flick, a))
    if (!flick.visible || !flick.interactive || p < 0 || p > alen(flick)) return false
    scrollBy(flick, dy)
    return true
  }
  function scrollBy(flick, dy) {
    const step = ((vertical ? cellRef.implicitHeight : cellRef.implicitWidth) + Tk.spacing.medium / 2) * dy / 120
    if (vertical) flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height, flick.contentY - step))
    else flick.contentX = Math.max(0, Math.min(flick.contentWidth - flick.width, flick.contentX - step))
  }

  function handleWheel(a, dy) {
    const ws = pointAlong(pointOn(workspaces, a))
    if (ws >= 0 && ws <= alen(workspaces)) { workspaces.scroll(dy); return }
    if (trayPill.visible && scrollList(trayFlick, a, dy)) return
    // Omarchy's volume/brightness keys: they resolve the real sink behind a
    // speaker tuning and show Omarchy's OSD.
    const svc = Config.o.services
    if (a < alen(root) / 2) { if (cfg.scroll.volume) Quickshell.execDetached(["omarchy-audio-output-volume", (dy > 0 ? "+" : "-") + svc.volumeStep]) }
    else if (cfg.scroll.brightness) Quickshell.execDetached(["omarchy-brightness-display", dy > 0 ? "+" + svc.brightnessStep + "%" : svc.brightnessStep + "%-"])
  }

  SystemClock { id: clock; precision: root.cfg.clock.showSeconds ? SystemClock.Seconds : SystemClock.Minutes }
  PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource] }

  GridLayout {
    id: col
    anchors.fill: parent
    // Padded at its two ends along the bar.
    anchors.topMargin: root.vertical ? root.vPadding : 0
    anchors.bottomMargin: root.vertical ? root.vPadding : 0
    anchors.leftMargin: root.vertical ? 0 : root.vPadding
    anchors.rightMargin: root.vertical ? 0 : root.vPadding
    columns: root.vertical ? 1 : -1
    rows: root.vertical ? -1 : 1
    flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
    rowSpacing: root.gap
    columnSpacing: root.gap

    // ---------------------------------------------------------- logo
    // Full-width row so the icon is centred with a rounded x: the bar is an
    // even width and the slot odd, so AlignHCenter would put it on a half
    // pixel and blur it.
    Item {
      id: logoRow
      visible: root.cfg.logo
      Layout.fillWidth: root.vertical
      Layout.fillHeight: !root.vertical
      implicitWidth: root.vertical ? 0 : Tk.barInner
      implicitHeight: root.vertical ? logo.height : 0
      LogoIcon {
        id: logo
        x: Math.round((parent.width - width) / 2)
        y: root.vertical ? 0 : Math.round((parent.height - height) / 2)
        width: Math.round(Tk.body.large * 1.2)
        height: width
        value: root.cfg.logoIcon
        size: width
        colour: Colours.m3tertiary
      }
      MouseArea {
        anchors.fill: logo
        anchors.margins: -Tk.px(4)
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: e => root.host.toggle(e.button === Qt.RightButton ? "settings" : "launcher")
      }
    }

    // ---------------------------------------------------- workspaces
    Workspaces {
      id: workspaces
      Layout.alignment: root.crossAlign
      vertical: root.vertical
      screen: root.screen
      iconsFit: root.windowIconsFit
    }

    // ------------------------------------------ active window (centred)
    Item {
      id: titleArea
      Layout.fillWidth: true
      Layout.fillHeight: true
      clip: true

      Item {
        id: activeWin
        visible: root.cfg.activeWindow.enabled
        readonly property var tl: Sys.activeToplevel
        readonly property string title: {
          const t = tl && tl.title ? tl.title : "Desktop"
          if (!root.cfg.activeWindow.compact) return t
          const parts = t.split(/\s+[\-\u2013\u2014]\s+/)
          return parts.length > 1 ? parts[parts.length - 1].trim() : t
        }
        // The room the title has beside the icon, along the bar.
        readonly property real maxLen: root.vertical ? parent.height - winIcon.height - Tk.spacing.small
          : parent.width - winIcon.width - Tk.spacing.small

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        // A column turns the title a quarter and stacks it under the icon; a
        // row leaves it upright beside the icon.
        width: root.vertical ? Math.max(winIcon.implicitWidth, metrics.height)
          : winIcon.implicitWidth + Tk.spacing.small + Math.min(metrics.width, maxLen)
        height: root.vertical ? winIcon.implicitHeight + Tk.spacing.small + Math.min(metrics.width, maxLen)
          : Math.max(winIcon.implicitHeight, metrics.height)
        Behavior on height { enabled: root.vertical; Anim {} }
        Behavior on width { enabled: !root.vertical; Anim {} }

        MIcon {
          id: winIcon
          // Centred across the bar (by x/y: see Workspaces `list`).
          x: root.vertical ? Math.round((parent.width - width) / 2) : 0
          y: root.vertical ? 0 : Math.round((parent.height - height) / 2)
          animate: true
          text: Sys.appIcon(activeWin.tl && activeWin.tl.wayland ? activeWin.tl.wayland.appId : "", "desktop_windows")
          color: Colours.m3primary
        }
        // Caelestia ActiveWindow: two titles cross-fade when the text changes.
        property Item current: title1
        // A step above Caelestia's body.small, which read small beside the
        // status icons. Measured and drawn at the same size.
        readonly property int titleSize: Tk.font(13)
        TextMetrics {
          id: metrics
          text: activeWin.title
          font.family: Tk.sans
          font.pointSize: activeWin.titleSize
          font.letterSpacing: 1.4
          elide: Qt.ElideRight
          elideWidth: Math.max(0, activeWin.maxLen)
          onElidedTextChanged: {
            if (!title1 || !title2) return
            const next = activeWin.current === title1 ? title2 : title1
            next.text = elidedText
            activeWin.current = next
          }
        }
        component Title: MText {
          id: t
          // Under the icon on a column, beside it on a row.
          x: root.vertical ? winIcon.x + Math.round((winIcon.width - width) / 2) : winIcon.x + winIcon.width + Tk.spacing.small
          y: root.vertical ? winIcon.y + winIcon.height + Tk.spacing.small : winIcon.y + Math.round((winIcon.height - height) / 2)
          width: root.vertical ? implicitHeight : implicitWidth
          height: root.vertical ? implicitWidth : implicitHeight
          font.pointSize: activeWin.titleSize
          font.letterSpacing: 1.4
          color: Colours.m3primary
          opacity: activeWin.current === t ? 1 : 0
          Behavior on opacity { Anim { type: "effects" } }
          transform: Rotation { angle: root.vertical ? 90 : 0; origin.x: t.implicitHeight / 2; origin.y: t.implicitHeight / 2 }
        }
        Title { id: title1; Component.onCompleted: text = metrics.elidedText }
        Title { id: title2 }
      }
    }

    // --------------------------------------------------- plugins pill
    // Holds the plugins pill's place in the column; the pill is drawn outside
    // the layout (see pluginPill below). Hiding a parent of a widget makes the
    // widget itself report visible=false, so a pill hidden because every
    // widget had hidden itself could never come back. Hiding this empty
    // placeholder instead also lets the layout drop its spacing.
    Item {
      id: pluginPlace
      Layout.alignment: root.crossAlign
      implicitWidth: root.vertical ? Tk.barInner : pluginPill.implicitWidth
      implicitHeight: root.vertical ? pluginPill.implicitHeight : Tk.barInner
      visible: pluginPill.visible && pluginPill.anyShown
    }

    // ---------------------------------------------------------- tray
    // Caelestia bar/components/Tray.qml: compact collapses the tray behind a
    // chevron that hovering expands (Caelestia's Bar.checkPopout), and
    // hiddenIcons drops items for good. Compact is also switched on by the
    // shared space budget (see "space budget" below) when the tray doesn't fit.
    Rectangle {
      id: trayPill
      Layout.alignment: root.crossAlign
      readonly property var trayItems: SystemTray.items.values.filter(i => i.status !== Status.Passive
        && root.cfg.tray.hiddenIcons.indexOf(i.id) < 0)
      readonly property bool bg: root.cfg.tray.background
      readonly property int padding: bg ? Tk.padding.medium : Tk.padding.extraSmall
      readonly property int spacingN: bg ? Tk.spacing.medium : Tk.spacing.extraSmall
      visible: root.cfg.tray.enabled && trayItems.length > 0

      readonly property bool compact: root.cfg.tray.compact || root.trayOverBudget
      property bool expanded: false
      onCompactChanged: if (!compact) expanded = false

      // The size along the bar. Caelestia's nonAnimHeight, with the expanded
      // list capped to the budget.
      readonly property real chevronLen: root.vertical ? expandTrayIcon.implicitHeight : expandTrayIcon.implicitWidth
      readonly property real listLen: root.vertical ? trayCol.implicitHeight : trayCol.implicitWidth
      readonly property real fullLen: listLen + padding * 2
      readonly property real collapsedLen: Math.max(bg ? Tk.barInner : 0, chevronLen + (bg ? Tk.padding.extraSmall : 0) + padding)
      readonly property real sizeLen: {
        if (!visible) return 0
        if (!compact) return fullLen
        if (!expanded) return collapsedLen
        return Math.max(collapsedLen, Math.min(chevronLen + listLen + spacingN + (bg ? Tk.padding.extraSmall : 0) + padding,
          root.budget - root.along(pluginPill)))
      }
      implicitWidth: root.vertical ? Tk.barInner : sizeLen
      implicitHeight: root.vertical ? sizeLen : Tk.barInner
      radius: Tk.rounding.full
      color: bg ? Colours.m3surfaceContainer : "transparent"
      clip: true
      Behavior on implicitHeight { enabled: root.vertical; Anim {} }
      Behavior on implicitWidth { enabled: !root.vertical; Anim {} }

      // The tray menu keeps it open; closing the menu lets it fold again.
      Connections {
        target: root.scope
        function onPopoutChanged() { if (root.scope.popout === "") collapseTrayTimer.restart() }
      }
      Timer {
        id: collapseTrayTimer
        interval: 400
        onTriggered: if (root.scope.popout !== "traymenu") trayPill.expanded = false
      }

      // Scrolls when an expanded tray is capped by the budget.
      MFlickable {
        id: trayFlick
        x: root.vertical ? 0 : trayPill.padding
        y: root.vertical ? trayPill.padding : 0
        // What is left along the bar once the padding and the chevron have theirs.
        readonly property real room: Math.max(0, (root.vertical ? parent.height : parent.width) - trayPill.padding
          - (trayPill.compact ? trayPill.chevronLen + trayPill.spacingN : trayPill.padding))
        width: root.vertical ? parent.width : room
        height: root.vertical ? room : parent.height
        contentWidth: root.vertical ? width : trayCol.implicitWidth
        contentHeight: root.vertical ? trayCol.implicitHeight : height
        interactive: root.vertical ? contentHeight > height + 0.5 : contentWidth > width + 0.5
        clip: true

        Grid {
          id: trayCol
          // Centred across the bar.
          x: root.vertical ? Math.round((parent.width - width) / 2) : 0
          y: root.vertical ? 0 : Math.round((parent.height - height) / 2)
          columns: root.vertical ? 1 : 1000
          spacing: Tk.spacing.small
          opacity: !trayPill.compact || trayPill.expanded ? 1 : 0
          Behavior on opacity { Anim { type: "effects" } }

          Repeater {
            id: trayRep
            model: trayPill.trayItems
            MouseArea {
              required property var modelData
              implicitWidth: Tk.body.small * 2
              implicitHeight: Tk.body.small * 2
              acceptedButtons: Qt.LeftButton | Qt.RightButton
              cursorShape: Qt.PointingHandCursor
              onClicked: function(e) { if (e.button === Qt.LeftButton) modelData.activate(); else modelData.secondaryActivate() }
              ColouredIcon {
                anchors.fill: parent
                visible: root.cfg.tray.recolour
                colour: Colours.m3secondary
                source: trayImg.source
              }
              Image {
                id: trayImg
                anchors.fill: parent
                visible: !root.cfg.tray.recolour
                source: {
                  let icon = parent.modelData.icon
                  if (icon.indexOf("?path=") >= 0) {
                    const [name, path] = icon.split("?path=")
                    icon = "file://" + path + "/" + name.slice(name.lastIndexOf("/") + 1)
                  }
                  return icon
                }
                sourceSize.width: width * 2
                sourceSize.height: height * 2
                smooth: true
                mipmap: true
              }
              scale: 0
              Component.onCompleted: scale = 1
              Behavior on scale { Anim { easing.bezierCurve: Tk.curves.standardDecel } }
            }
          }
        }
      }

      // Caelestia's expandIcon: one glyph, turned 180° when expanded.
      MIcon {
        id: expandTrayIcon
        visible: trayPill.compact
        // At the far end of the pill, centred across it.
        x: root.vertical ? Math.round((parent.width - width) / 2) : parent.width - width - (trayPill.bg ? Tk.padding.extraSmall : 0)
        y: root.vertical ? parent.height - height - (trayPill.bg ? Tk.padding.extraSmall : 0) : Math.round((parent.height - height) / 2)
        text: root.vertical ? "expand_less" : "chevron_left"
        size: Tk.iconSize.medium
        color: Colours.m3onSurfaceVariant
        rotation: trayPill.expanded ? 180 : 0
        Behavior on rotation { Anim {} }
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: { collapseTrayTimer.stop(); trayPill.expanded = !trayPill.expanded }
        }
      }
    }

    // --------------------------------------------------------- clock
    Rectangle {
      id: clockPill
      visible: root.cfg.clock.enabled
      Layout.alignment: root.crossAlign
      readonly property real pad: root.cfg.clock.background ? Tk.padding.medium : Tk.padding.extraSmall
      implicitWidth: root.vertical ? Tk.barInner : clockRow.implicitWidth + pad * 2
      implicitHeight: root.vertical ? clockCol.implicitHeight + pad * 2 : Tk.barInner
      radius: (root.vertical ? width : height) / 2
      color: root.cfg.clock.background ? Colours.m3surfaceContainer : "transparent"
      readonly property bool h12: Sys.h12
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: e => {
          if (e.button === Qt.RightButton) root.host.toggle("sidebar")
          else root.host.toggle("dashboard")
        }
      }
      // Caelestia bar/components/Clock.qml: body.small x1.1 digits, squeezed
      // or stretched on the width axis so hours and minutes line up.
      // Caelestia KDE's horizontal clock (bar/components/Clock.qml): the icon,
      // the date, then hours:minutes on one line.
      RowLayout {
        id: clockRow
        anchors.centerIn: parent
        visible: !root.vertical
        spacing: Tk.spacing.extraSmall
        MIcon {
          id: calIconH
          visible: root.calIconShown
          Layout.alignment: Qt.AlignVCenter
          text: "calendar_month"
          color: Colours.m3tertiary
        }
        MText {
          visible: root.cfg.clock.showDate
          Layout.alignment: Qt.AlignVCenter
          text: Qt.formatDate(clock.date, "ddd d")
          font.pointSize: Tk.body.small
          color: Colours.m3tertiary
        }
        Rectangle {
          visible: root.cfg.clock.showDate
          Layout.alignment: Qt.AlignVCenter
          implicitWidth: 1
          implicitHeight: Tk.px(16)
          color: Colours.m3outlineVariant
        }
        MText {
          Layout.alignment: Qt.AlignVCenter
          text: Sys.hour(clock.date) + ":" + Qt.formatTime(clock.date, "mm") + (root.cfg.clock.showSeconds ? ":" + Qt.formatTime(clock.date, "ss") : "")
          font.pointSize: Tk.body.small * 1.1
          axes: ({ "ROND": 25 })
          color: Colours.m3tertiary
        }
        MText {
          visible: clockPill.h12
          Layout.alignment: Qt.AlignVCenter
          text: Qt.formatTime(clock.date, "AP").toLowerCase()
          font.pointSize: Tk.body.small * 0.9
          color: Colours.m3tertiary
        }
      }

      ColumnLayout {
        id: clockCol
        anchors.centerIn: parent
        visible: root.vertical
        spacing: Tk.spacing.extraSmall
        readonly property real size: Tk.body.small * 1.1
        function fit(text, metricWidth) {
          return text === "11" ? 1.15 : Math.min(1.05, Math.max(hourMetrics.width, minMetrics.width) / Math.max(1, metricWidth))
        }
        TextMetrics { id: hourMetrics; font.family: Tk.sans; font.pointSize: clockCol.size; text: Sys.hour(clock.date) }
        TextMetrics { id: minMetrics; font.family: Tk.sans; font.pointSize: clockCol.size; text: Qt.formatTime(clock.date, "mm") }
        TextMetrics { id: secMetrics; font.family: Tk.sans; font.pointSize: clockCol.size; text: Qt.formatTime(clock.date, "ss") }
        component Digits: MText {
          property real metricWidth
          readonly property real fitScale: clockCol.fit(text, metricWidth)
          Layout.alignment: Qt.AlignHCenter
          font.pointSize: clockCol.size
          font.letterSpacing: fitScale
          axes: ({ "ROND": 25, "wdth": fitScale * 100 })
          color: Colours.m3tertiary
        }
        MIcon {
          id: calIcon
          visible: root.calIconShown
          Layout.alignment: Qt.AlignHCenter
          text: "calendar_month"
          color: Colours.m3tertiary
        }
        ColumnLayout {
          visible: root.cfg.clock.showDate
          Layout.alignment: Qt.AlignHCenter
          spacing: clockCol.spacing - Tk.px(4)
          MText { Layout.alignment: Qt.AlignHCenter; text: Qt.formatDate(clock.date, "ddd"); font.pointSize: Tk.body.small * 0.9; color: Colours.m3tertiary }
          MText { Layout.alignment: Qt.AlignHCenter; text: Qt.formatDate(clock.date, "d"); font.pointSize: clockCol.size * 1.1; color: Colours.m3tertiary }
          Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: -Tk.padding.extraSmall
            Layout.rightMargin: -Tk.padding.extraSmall
            Layout.topMargin: Tk.px(4)
            Layout.bottomMargin: Tk.padding.extraSmall / 2
            implicitHeight: 1
            color: Colours.m3outlineVariant
          }
        }
        Digits { text: Sys.hour(clock.date); metricWidth: hourMetrics.width }
        Digits { Layout.topMargin: -clockCol.spacing - 4; text: Qt.formatTime(clock.date, "mm"); metricWidth: minMetrics.width }
        Digits { visible: root.cfg.clock.showSeconds; Layout.topMargin: -clockCol.spacing - 4; text: Qt.formatTime(clock.date, "ss"); metricWidth: secMetrics.width }
        MText {
          visible: parent.parent.h12
          Layout.alignment: Qt.AlignHCenter
          Layout.topMargin: -clockCol.spacing - Tk.px(4)
          text: Qt.formatTime(clock.date, "AP").toLowerCase()
          font.pointSize: Tk.body.small * 0.9
          color: Colours.m3tertiary
        }
      }
    }

    // --------------------------------------------------- status icons
    Rectangle {
      id: statusPill
      readonly property int anchorsPad: Tk.padding.medium
      // Not `statusCol.visibleChildren`: while the bar is hidden (fullscreen)
      // every child reads invisible, the pill hides, and its children then
      // stay invisible for good, so the pill never came back.
      readonly property var st: root.cfg.status
      visible: (st.keepAwake && IdleService.enabled) || (st.update && UpdateService.available)
        || RecordService.running || st.notifications
        || (st.lockStatus && (root.host.capsLock || root.host.numLock || lockStatus.visible))
        || st.audio || st.microphone || st.kbLayout || st.network || st.bluetooth || st.battery
      Layout.alignment: root.crossAlign
      implicitWidth: root.vertical ? Tk.barInner : statusCol.implicitWidth + Tk.padding.medium * 2
      implicitHeight: root.vertical ? statusCol.implicitHeight + Tk.padding.medium * 2 : Tk.barInner
      radius: (root.vertical ? width : height) / 2
      color: Colours.m3surfaceContainer
      clip: true
      Behavior on implicitHeight { enabled: root.vertical; Anim {} }
      Behavior on implicitWidth { enabled: !root.vertical; Anim {} }

      // Every icon sits in its own cell, centred across the bar. Filled from
      // the pill's far end, so a new one grows in from the inner side.
      GridLayout {
        id: statusCol
        readonly property real gapPx: Tk.spacing.medium / 2
        x: root.vertical ? Math.round((parent.width - width) / 2) : parent.width - width - Tk.padding.medium
        y: root.vertical ? parent.height - height - Tk.padding.medium : Math.round((parent.height - height) / 2)
        columns: root.vertical ? 1 : -1
        rows: root.vertical ? -1 : 1
        flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rowSpacing: gapPx
        columnSpacing: gapPx

        // Keep awake indicator
        MIcon {
          visible: root.cfg.status.keepAwake && IdleService.enabled
          Layout.alignment: Qt.AlignCenter
          text: "coffee"
          color: Colours.m3secondary
          fill: 1
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.host.toggle("utilities")
          }
        }

        // Pending Omarchy update (stock omarchy.system-update): click runs it.
        MIcon {
          readonly property string popout: "update"
          visible: root.cfg.status.update && UpdateService.available
          Layout.alignment: Qt.AlignCenter
          animate: true
          text: UpdateService.running ? "downloading" : "system_update_alt"
          color: Colours.m3primary
          fill: 1
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: UpdateService.update()
          }
        }

        // Screen recording active indicator
        MIcon {
          visible: RecordService.running
          Layout.alignment: Qt.AlignCenter
          text: "fiber_manual_record"
          color: Colours.m3error
          fill: 1
          SequentialAnimation on opacity {
            running: RecordService.running
            loops: Animation.Infinite
            NumberAnimation { from: 1; to: 0.2; duration: 600 }
            NumberAnimation { from: 0.2; to: 1; duration: 600 }
          }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.host.toggle("utilities")
          }
        }

        // Notifications indicator: always there (when enabled) so the sidebar
        // has a target; filled with unread notifications, outlined when empty.
        MIcon {
          visible: root.cfg.status.notifications
          Layout.alignment: Qt.AlignCenter
          animate: true
          text: NotifService.dnd ? "notifications_off" : NotifService.count > 0 ? "notifications_unread" : "notifications"
          color: NotifService.dnd ? Colours.m3error : Colours.m3secondary
          fill: NotifService.count > 0 || NotifService.dnd ? 1 : 0
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.host.toggle("sidebar")
          }
        }

        // caps/num lock (Caelestia status/LockStatus.qml): each grows in
        // and fades/scales its own icon.
        GridLayout {
          id: lockStatus
          readonly property string popout: "lockstatus"
          readonly property bool caps: root.host.capsLock
          readonly property bool num: root.host.numLock
          property real gap: caps && num ? statusCol.gapPx : 0
          // How much of the bar each icon takes, along it.
          property real capsLen: caps ? (root.vertical ? capsIcon.implicitHeight : capsIcon.implicitWidth) : 0
          property real numLen: num ? (root.vertical ? numIcon.implicitHeight : numIcon.implicitWidth) : 0
          Layout.alignment: Qt.AlignCenter
          visible: root.cfg.status.lockStatus && (capsLen > 0.5 || numLen > 0.5)
          columns: root.vertical ? 1 : -1
          rows: root.vertical ? -1 : 1
          flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
          rowSpacing: Math.round(gap)
          columnSpacing: Math.round(gap)
          Behavior on gap { Anim { type: "slowEffects" } }
          Behavior on capsLen { Anim { type: "slowEffects" } }
          Behavior on numLen { Anim { type: "slowEffects" } }
          Item {
            implicitWidth: root.vertical ? capsIcon.implicitWidth : Math.round(lockStatus.capsLen)
            implicitHeight: root.vertical ? Math.round(lockStatus.capsLen) : capsIcon.implicitHeight
            MIcon {
              id: capsIcon
              anchors.centerIn: parent
              scale: lockStatus.caps ? 1 : 0.5
              opacity: lockStatus.caps ? 1 : 0
              text: "keyboard_capslock_badge"
              color: Colours.m3secondary
              fill: 1
              grade: 25
              Behavior on opacity { Anim { type: "effects" } }
              Behavior on scale { Anim {} }
            }
          }
          Item {
            implicitWidth: root.vertical ? numIcon.implicitWidth : Math.round(lockStatus.numLen)
            implicitHeight: root.vertical ? Math.round(lockStatus.numLen) : numIcon.implicitHeight
            MIcon {
              id: numIcon
              anchors.centerIn: parent
              scale: lockStatus.num ? 1 : 0.5
              opacity: lockStatus.num ? 1 : 0
              text: "looks_one"
              color: Colours.m3secondary
              fill: 1
              grade: 25
              Behavior on opacity { Anim { type: "effects" } }
              Behavior on scale { Anim {} }
            }
          }
        }
        MIcon {
          readonly property string popout: "audio"
          readonly property var sink: Pipewire.defaultAudioSink
          readonly property real vol: sink && sink.audio ? sink.audio.volume : 0
          readonly property bool muted: !sink || !sink.audio || sink.audio.muted
          visible: root.cfg.status.audio
          Layout.alignment: Qt.AlignCenter
          animate: true
          text: muted ? "no_sound" : vol >= 0.5 ? "volume_up" : vol > 0 ? "volume_down" : "volume_mute"
          color: Colours.m3secondary
          size: Tk.iconSize.medium
          fill: 1
        }
        MIcon {
          readonly property string popout: "audio"
          readonly property var src: Pipewire.defaultAudioSource
          readonly property bool muted: !src || !src.audio || src.audio.muted
          // "Only while recording" keeps it out of the way until an app
          // actually opens the microphone.
          visible: root.cfg.status.microphone && (!root.cfg.status.microphoneInUseOnly || AudioService.capturing)
          Layout.alignment: Qt.AlignCenter
          animate: true
          text: muted ? "mic_off" : "mic"
          color: Colours.m3secondary
          size: Tk.iconSize.medium
          fill: 1
        }
        // Caelestia StatusIcons "kbLayout": the active layout's code in mono.
        // KbService is only touched while the icon is on, so it costs nothing
        // when off (its default, as in Caelestia's barconfig).
        MText {
          readonly property string popout: "kblayout"
          visible: root.cfg.status.kbLayout
          Layout.alignment: Qt.AlignCenter
          animate: true
          text: root.cfg.status.kbLayout ? KbService.code : ""
          color: Colours.m3secondary
          font.family: Tk.mono
          font.pointSize: Tk.body.medium
        }
        MIcon {
          readonly property string popout: "network"
          visible: root.cfg.status.network
          Layout.alignment: Qt.AlignCenter
          animate: true
          text: Sys.ethernet ? "cable" : Sys.wifi ? Sys.networkIcon(Sys.strength) : "wifi_off"
          color: Colours.m3secondary
        }
        GridLayout {
          readonly property string popout: "bluetooth"
          // "Only when connected" hides the idle bluetooth glyph.
          visible: root.cfg.status.bluetooth && (!root.cfg.status.bluetoothConnectedOnly
            || Bluetooth.devices.values.some(d => d.connected))
          Layout.alignment: Qt.AlignCenter
          columns: root.vertical ? 1 : -1
          rows: root.vertical ? -1 : 1
          flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
          rowSpacing: statusCol.gapPx
          columnSpacing: statusCol.gapPx
          MIcon {
            Layout.alignment: Qt.AlignCenter
            animate: true
            readonly property var adapter: Bluetooth.defaultAdapter
            text: !adapter || !adapter.enabled ? "bluetooth_disabled"
              : Bluetooth.devices.values.some(d => d.connected) ? "bluetooth_connected" : "bluetooth"
            color: Colours.m3secondary
          }
          Repeater {
            model: Bluetooth.devices.values.filter(d => d.state !== BluetoothDeviceState.Disconnected)
            MIcon {
              required property var modelData
              Layout.alignment: Qt.AlignCenter
              text: Sys.bluetoothIcon(modelData.icon)
              color: Colours.m3secondary
              fill: 1
              SequentialAnimation on opacity {
                running: modelData.state !== BluetoothDeviceState.Connected
                alwaysRunToEnd: true
                loops: Animation.Infinite
                NumberAnimation { from: 1; to: 0; duration: Tk.durations.large; easing.type: Easing.BezierSpline; easing.bezierCurve: Tk.curves.standardAccel }
                NumberAnimation { from: 0; to: 1; duration: Tk.durations.large; easing.type: Easing.BezierSpline; easing.bezierCurve: Tk.curves.standardDecel }
              }
            }
          }
        }
        MIcon {
          readonly property string popout: "battery"
          visible: root.cfg.status.battery
          readonly property var dev: UPower.displayDevice
          readonly property bool laptop: dev && dev.isLaptopBattery
          readonly property bool charging: dev && [UPowerDeviceState.Charging, UPowerDeviceState.FullyCharged, UPowerDeviceState.PendingCharge].indexOf(dev.state) >= 0
          Layout.alignment: Qt.AlignCenter
          animate: true
          text: !laptop ? (PowerProfiles.profile === PowerProfile.PowerSaver ? "energy_savings_leaf"
                         : PowerProfiles.profile === PowerProfile.Performance ? "rocket_launch" : "balance")
                        : Sys.batteryIcon(dev.percentage, charging)
          color: !UPower.onBattery || !dev || dev.percentage > 0.2 ? Colours.m3secondary : Colours.m3error
          fill: 1
        }
      }
    }

    // --------------------------------------------------------- power
    Item {
      id: powerItem
      visible: root.cfg.power
      Layout.alignment: root.crossAlign
      implicitWidth: powerIcon.implicitHeight + Tk.padding.small
      implicitHeight: powerIcon.implicitHeight
      Item {
        anchors.centerIn: parent
        width: powerIcon.implicitHeight + Tk.padding.small
        height: width
        property real radius: width / 2
        StateLayer { onClicked: root.host.toggle("session") }
      }
      MIcon {
        id: powerIcon
        anchors.centerIn: parent
        text: "power_settings_new"
        color: Colours.m3error
        weight: 700
      }
    }
  }

  // Dedicated Caelestia pill for 3rd-party bar widgets (installed in
  // ~/.config/omarchy/plugins/), laid out like the status pill: same padding,
  // same spacing, one status-icon cell per widget (BarWidgetSlot scales each
  // widget's mark to the status icons' size). Sits on pluginPlace.
  //
  // Pinned widgets (Settings › Taskbar › Plugins) always show; the others
  // wait behind a chevron that hovering expands, like the compact tray.
  Rectangle {
    id: pluginPill
    readonly property var pluginsList: root.host.thirdPartyPlugins || []
    readonly property var unpinned: root.cfg.plugins.unpinned
    // The padding at each end of the list, along the bar.
    readonly property real endPad: Tk.padding.medium
    readonly property real listLen: root.vertical ? pluginCol.implicitHeight : pluginCol.implicitWidth
    readonly property bool anyShown: listLen - endPad * 2 > 0.5
    property bool expanded: false
    onOverflowCountChanged: if (overflowCount === 0) expanded = false

    // Counted by hand: Repeater.itemAt is not a binding dependency, so every
    // slot asks for a recount when its size, content or pin changes.
    property int overflowCount: 0
    property real pinnedLen: 0
    function recount() { countTimer.restart() }
    Timer {
      id: countTimer
      interval: 0
      onTriggered: {
        let n = 0, h = 0
        for (let i = 0; i < pluginRep.count; i++) {
          const slot = pluginRep.itemAt(i)
          if (!slot || !slot.shown) continue
          if (slot.pinned) h += Math.round(slot.visualLen) + pluginCol.gapPx
          else n++
        }
        pluginPill.overflowCount = n
        pluginPill.pinnedLen = h
      }
    }
    // The pill's size along the bar with the overflow closed: what the budget plans for.
    readonly property real collapsedLen: overflowCount === 0 && pinnedLen === 0 ? 0
      : endPad * 2 + pinnedLen
        + (overflowCount > 0 ? (root.vertical ? overflowIcon.implicitHeight : overflowIcon.implicitWidth) : -pluginCol.gapPx)

    visible: root.cfg.plugins.enabled !== false && pluginsList.length > 0
    opacity: anyShown ? 1 : 0
    x: col.x + pluginPlace.x
    y: col.y + pluginPlace.y
    // Scrolled down to a single cell, pinned widgets included, when even they
    // don't fit: the pill gives way before the clock and status icons do.
    readonly property real minLen: endPad * 2 + (root.vertical ? cellRef.implicitHeight : cellRef.implicitWidth)
    // Capped by the space budget, leaving the tray its (collapsed) share.
    readonly property real sizeLen: anyShown ? Math.min(Math.max(minLen, root.budget - root.trayReserve), listLen) : 0
    implicitWidth: root.vertical ? Tk.barInner : sizeLen
    implicitHeight: root.vertical ? sizeLen : Tk.barInner
    width: implicitWidth
    height: implicitHeight
    radius: (root.vertical ? width : height) / 2
    color: Colours.m3surfaceContainer
    clip: true

    Behavior on implicitHeight { enabled: root.vertical; Anim {} }
    Behavior on implicitWidth { enabled: !root.vertical; Anim {} }

    Timer {
      id: collapsePluginsTimer
      interval: 400
      onTriggered: pluginPill.expanded = false
    }

    // A status icon's height, so a plugin cell matches the status pill's.
    MIcon { id: cellRef; visible: false; text: "extension" }

    // More widgets than fit scroll rather than being cut off.
    MFlickable {
      id: pluginFlick
      anchors.fill: parent
      contentWidth: root.vertical ? width : pluginCol.implicitWidth
      contentHeight: root.vertical ? pluginCol.implicitHeight : height
      interactive: root.vertical ? contentHeight > height + 0.5 : contentWidth > width + 0.5

      Grid {
        id: pluginCol
        readonly property real gapPx: Tk.spacing.medium / 2
        width: root.vertical ? parent.width : implicitWidth
        height: root.vertical ? implicitHeight : parent.height
        columns: root.vertical ? 1 : 1000
        topPadding: root.vertical ? pluginPill.endPad : 0
        bottomPadding: root.vertical ? pluginPill.endPad : 0
        leftPadding: root.vertical ? 0 : pluginPill.endPad
        rightPadding: root.vertical ? 0 : pluginPill.endPad
        spacing: gapPx

        Repeater {
          id: pluginRep
          model: pluginPill.pluginsList

          BarWidgetSlot {
            required property var modelData
            pinned: pluginPill.unpinned.indexOf(moduleName) < 0
            entry: modelData
            host: root.host
            vertical: root.vertical
            cellLen: root.vertical ? cellRef.implicitHeight : cellRef.implicitWidth
            collapsed: !pinned && !pluginPill.expanded
            onShownChanged: pluginPill.recount()
            onPinnedChanged: pluginPill.recount()
            onVisualLenChanged: pluginPill.recount()
            Component.onCompleted: pluginPill.recount()
            Component.onDestruction: pluginPill.recount()
          }
        }

        // Caelestia's tray chevron, for the widgets that aren't pinned.
        Item {
          width: root.vertical ? parent.width : (pluginPill.overflowCount > 0 ? overflowIcon.implicitWidth : 0)
          height: root.vertical ? (pluginPill.overflowCount > 0 ? overflowIcon.implicitHeight : 0) : parent.height
          MIcon {
            id: overflowIcon
            anchors.centerIn: parent
            visible: pluginPill.overflowCount > 0
            text: root.vertical ? "expand_less" : "chevron_left"
            size: Tk.iconSize.medium
            color: Colours.m3onSurfaceVariant
            rotation: pluginPill.expanded ? 180 : 0
            Behavior on rotation { Anim {} }
          }
          MouseArea {
            anchors.fill: parent
            enabled: pluginPill.overflowCount > 0
            cursorShape: Qt.PointingHandCursor
            onClicked: { collapsePluginsTimer.stop(); pluginPill.expanded = !pluginPill.expanded }
          }
        }
      }
    }

    // Omarchy's WidgetButton takes every wheel, so hosted widgets would eat
    // the scroll of an overfull pill. Wheel only: clicks and hover go through,
    // and while the pill fits the wheel is left to the widget.
    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.NoButton
      onWheel: e => {
        if (!pluginFlick.interactive) { e.accepted = false; return }
        root.scrollBy(pluginFlick, e.angleDelta.y)
      }
    }
  }
}
