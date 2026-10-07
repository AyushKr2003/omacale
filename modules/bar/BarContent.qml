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
import "../../core/BarLayout.js" as BarLayout

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
  readonly property real calendarLen: clockPill.calendarLen
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
  // The plugin pill's length along the bar, for the tray's expanded cap.
  readonly property real pluginLen: along(pluginPill)
  readonly property real trayReserve: !trayPill.visible ? 0 : trayPill.compact ? trayPill.collapsedLen : trayPill.fullLen

  // Popout lookup for a position `a` along the bar (Caelestia Bar.checkPopout).
  function popoutAt(a) {
    return statusPill.popoutAt(a) || trayPill.popoutAt(a) || titleArea.popoutAt(a)
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
    for (const s of logoRow.navStops()) add(s.item, s.act, s)
    for (const s of workspaces.navStops()) add(s.item, s.act, s)
    for (const s of titleArea.navStops()) add(s.item, s.act, s)
    if (pluginPill.visible && pluginPill.anyShown)
      for (let i = 0; i < pluginRep.count; i++) {
        const slot = pluginRep.itemAt(i)
        if (slot && slot.shown && slot.activeItem)
          out.push({ item: slot, kind: "plugin", act: () => root.openPlugin(slot) })
      }
    for (const s of trayPill.navStops()) out.push(s)
    for (const s of clockPill.navStops()) add(s.item, s.act, s)
    for (const s of statusPill.navStops()) add(s.item, s.act, s)
    for (const s of powerItem.navStops()) add(s.item, s.act, s)
    return out
  }

  function sameStop(a, b) { return !!a && !!b && a.item === b.item }
  function setStop(s, i) {
    cursorStop = s
    cursorIndex = i
    // The compact tray and the plugin overflow open while the cursor is in them.
    trayPill.cursorMoved(s)
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
    for (const p of statusPill.statusPopouts())
      if (out.indexOf(p) < 0) out.push(p)
    return out
  }

  // Where a popout opened without the pointer should sit: beside its icon,
  // or centred on the bar when the icon is hidden (a keyboard-layout popout
  // with the icon off still opens).
  function popoutCenterFor(name) {
    for (const e of [trayPill, titleArea, statusPill]) {
      const c = e.popoutCenterFor(name)
      if (c !== undefined) return c
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
    trayPill.hoverAt(a, onBar)

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
    if (workspaces.scrollAt(a, dy)) return
    if (trayPill.scrollAt(a, dy)) return
    // Omarchy's volume/brightness keys: they resolve the real sink behind a
    // speaker tuning and show the OSD (Caelestia's sliders, once the OSD
    // handover is in; Omarchy's own otherwise).
    const svc = Config.o.services
    if (a < alen(root) / 2) { if (cfg.scroll.volume) Quickshell.execDetached(["omarchy-audio-output-volume", (dy > 0 ? "+" : "-") + svc.volumeStep]) }
    else if (cfg.scroll.brightness) Quickshell.execDetached(["omarchy-brightness-display", dy > 0 ? "+" + svc.brightnessStep + "%" : svc.brightnessStep + "%-"])
  }

  // Shared by the clock entry (ClockEntry reads bar.sysClock).
  property alias sysClock: clock
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
    LogoEntry { id: logoRow; bar: root }

    // ---------------------------------------------------- workspaces
    WorkspacesEntry { id: workspaces; bar: root }

    // ------------------------------------------ active window (centred)
    ActiveWindowEntry { id: titleArea; bar: root }

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
    TrayEntry { id: trayPill; bar: root }

    // --------------------------------------------------------- clock
    ClockEntry { id: clockPill; bar: root }

    // --------------------------------------------------- status icons
    StatusRun { id: statusPill; bar: root; ids: BarLayout.STATUS }

    PowerEntry { id: powerItem; bar: root }
  }

  // Dedicated Caelestia pill for 3rd-party bar widgets (installed in
  // ~/.config/omarchy/plugins/), laid out like the status pill: same padding,
  // same spacing, one status-icon cell per widget (BarWidgetSlot scales each
  // widget's mark to the status icons' size). Sits on pluginPlace.
  //
  // Pinned widgets (Settings › Taskbar › Plugins) always show; the others
  // wait behind a chevron that hovering expands, like the compact tray.
  // Hidden ones (bar.plugins.hidden) aren't made at all.
  Rectangle {
    id: pluginPill
    readonly property var pluginsList: (root.host.thirdPartyPlugins || [])
      .filter(e => root.cfg.plugins.hidden.indexOf(root.host.entryId(e)) < 0)
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
