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
// icons, power, in Caelestia's metrics. Where each sits is bar.layout
// (core/BarLayout.js): a start, center and end section, Noctalia-style, whose
// default is Caelestia's order. Every item is an entry (modules/bar/entries/)
// with the same small interface; this file lays the sections out and walks
// the entries in bar order for focus, popouts, hover, the wheel and the
// space budget.
Item {
  id: root

  required property var screen
  required property var host
  required property var scope
  // A column on the left or right edge; a row on the top or bottom one.
  property bool vertical: true
  // Which edge this screen's bar is on (ScreenScope.barPos).
  property string edge: "left"

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

  // ------------------------------------------------------------ layout
  // null until the shell has registered its widgets and Omarchy's bar
  // config has arrived: "not known yet" keeps every placed widget (resolve),
  // where an empty list would drop them and build them again a moment later.
  readonly property var widgetIds: host.widgetIds && host.widgetIds.length ? host.widgetIds : null
  readonly property var layout: BarLayout.resolve({ start: cfg.layout.start, center: cfg.layout.center, end: cfg.layout.end, removed: cfg.layout.removed, drawer: cfg.layout.drawer }, widgetIds)
  // What each section draws, the chevron's items included (BarLayout.render):
  // the drawer, plus the icons past bar.layout.maxShown.
  readonly property var rendered: BarLayout.render(layout, cfg.layout.maxShown, id => root.onShow(id))
  // Whether an item is on show, for the "at most N" limit. Status icons follow
  // statusOn, the one rule StatusRun draws them by.
  function onShow(id) {
    if (BarLayout.isPlugin(id)) return !!widgetIds && widgetIds.indexOf(BarLayout.pluginOf(id)) >= 0
    if (BarLayout.STATUS.indexOf(id) >= 0) return statusOn(id)
    // From the data, never from the entries: they are rebuilt from what
    // this decides, and asking one that is being torn down fails.
    if (id === "tray") return cfg.tray.enabled && SystemTray.items.values.some(i => i.status !== Status.Passive
      && cfg.tray.hiddenIcons.indexOf(i.id) < 0)
    if (id === "plugins") return cfg.plugins.enabled !== false && (host.thirdPartyPlugins || []).some(e =>
      cfg.plugins.hidden.indexOf(host.entryId(e)) < 0 && placedWidgets.indexOf(host.entryId(e)) < 0)
    return true
  }
  // Set by the lock icon while it is still folding away (StatusRun).
  property bool lockFolding: false
  function statusOn(id) {
    // The lock icon stays while it is still folding away.
    return PluginService.statusOn(id) || (id === "lockStatus" && cfg.status.lockStatus && lockFolding)
  }
  // The chevron's items are drawn while it is open (OverflowEntry).
  property bool drawerOpen: false
  // The section models, replaced only when they really change, so a settings
  // write that leaves the layout alone doesn't recreate every entry.
  property var segs: ({ start: [], center: [], end: [] })
  // Widgets with a place of their own in the layout; the plugin pill leaves
  // them out. Kept, like segs, until its contents change: a new array would
  // rebuild the pill's hosted widgets.
  property var placedWidgets: []
  function updateSegs() {
    const r = rendered
    const next = { start: BarLayout.segments(r.start), center: BarLayout.segments(r.center), end: BarLayout.segments(r.end) }
    if (JSON.stringify(next) !== JSON.stringify(segs)) segs = next
    // The drawer's widgets too: kept out of the pill even with the chevron off the bar.
    const placed = BarLayout.SECTIONS.concat(["drawer"]).reduce((out, s) =>
      out.concat(layout[s].filter(id => BarLayout.isPlugin(id)).map(id => BarLayout.pluginOf(id))), [])
    if (JSON.stringify(placed) !== JSON.stringify(placedWidgets)) placedWidgets = placed
  }
  // A Settings edit writes each list in turn; settle on the result once.
  onRenderedChanged: Qt.callLater(updateSegs)
  Component.onCompleted: updateSegs()
  // The section whose free space the window title takes ("" while it is off).
  readonly property string titleIn: BarLayout.flexSection(layout, cfg.activeWindow.enabled)

  // Entries register as they are created. The items there is only one of are
  // also looked up by id; layoutGen re-runs whatever depends on the set.
  property var entryMap: ({})
  property int layoutGen: 0
  function registerEntry(e) {
    if (e.entryId.indexOf(":") < 0) entryMap[e.entryId] = e
    layoutGen++
  }
  function unregisterEntry(e) {
    for (const k in entryMap) if (entryMap[k] === e) delete entryMap[k]
    layoutGen++
  }
  function entryFor(id) { void layoutGen; return entryMap[id] || null }
  // The chevron's items on the bar right now (open), in bar order.
  function drawerItems() {
    const out = []
    for (const box of [startBox, centerBox, endBox])
      for (let i = 0; i < box.rep.count; i++) {
        const l = box.rep.itemAt(i)
        if (l && l.item && l.drawer && l.visible) out.push(l.item)
      }
    return out
  }
  readonly property var wsE: entryFor("workspaces")
  readonly property var titleE: entryFor("activeWindow")
  readonly property var trayE: entryFor("tray")
  readonly property var pluginsE: entryFor("plugins")
  readonly property var clockE: entryFor("clock")
  // Every entry, in bar order: start, center, end, each in its own order.
  function entries() {
    void layoutGen
    const out = []
    for (const box of [startBox, centerBox, endBox])
      for (let i = 0; i < box.rep.count; i++) {
        const l = box.rep.itemAt(i)
        // Folded behind a closed chevron: not on the bar for anything.
        if (l && l.item && !l.folded) out.push(l.item)
      }
    return out
  }
  // The first defined answer of `fn` over the entries, in bar order.
  function ask(fn, ...args) {
    for (const e of entries()) {
      if (typeof e[fn] !== "function") continue
      const r = e[fn](...args)
      if (r !== undefined && r !== null) return r
    }
    return null
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
    let len = 0, n = 0
    for (const e of entries()) {
      if (!e.shown) continue
      n++
      if (e === wsE) len += e.bareSize
      else if (e === clockE) len += along(e) - (calIconShown ? calendarLen : 0)
      else if (e !== titleE && e !== trayE && e !== pluginsE) len += along(e)
    }
    // Gaps between the entries of a section, and between the sections.
    const boxes = [startBox, centerBox, endBox].filter(b => b.visible).length
    return len + gap * Math.max(0, n - boxes) + gap * Math.max(0, boxes - 1)
  }
  readonly property real flexRoom: alen(col) - fixedLen - titleMin
  readonly property real flexMin: (trayE && trayE.visible ? trayE.collapsedLen : 0) + (pluginsE && pluginsE.visible ? pluginsE.pill.minLen : 0)
  // Both worked out whether or not they are shown, so hiding one can't
  // bring it straight back.
  readonly property real calendarLen: clockE ? clockE.calendarLen : 0
  // Set a tick late rather than bound: the clock's size, and so
  // fixedLen, reads the icon's visibility, which reads this.
  property bool calendarFits: true
  readonly property bool calIconShown: cfg.clock.showIcon && calendarFits
  readonly property real wsIconsSize: wsE ? wsE.iconsSize : 0
  function refitCalendar() { calendarFits = flexRoom - flexMin >= calendarLen + wsIconsSize }
  onFlexRoomChanged: Qt.callLater(refitCalendar)
  onFlexMinChanged: Qt.callLater(refitCalendar)
  onCalendarLenChanged: Qt.callLater(refitCalendar)
  onWsIconsSizeChanged: Qt.callLater(refitCalendar)
  readonly property bool windowIconsFit: flexRoom - flexMin - (calendarFits ? calendarLen : 0) >= wsIconsSize
  readonly property real budget: Math.max(0, flexRoom - (calendarFits ? calendarLen : 0) - (windowIconsFit ? wsIconsSize : 0))
  readonly property bool trayOverBudget: !!trayE && trayE.visible && trayE.fullLen + (pluginsE ? pluginsE.pill.collapsedLen : 0) > budget
  // The plugin pill's length along the bar, for the tray's expanded cap.
  readonly property real pluginLen: pluginsE ? along(pluginsE.pill) : 0
  property alias overlay: overlay
  // A status icon's length along the bar: one cell, for the plugin pills.
  readonly property real cellLen: vertical ? cellRef.implicitHeight : cellRef.implicitWidth
  MIcon { id: cellRef; visible: false; text: "extension" }
  readonly property real trayReserve: !trayE || !trayE.visible ? 0 : trayE.compact ? trayE.collapsedLen : trayE.fullLen

  // Popout lookup for a position `a` along the bar (Caelestia Bar.checkPopout).
  function popoutAt(a) {
    return ask("popoutAt", a)
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
    for (const e of entries()) {
      if (typeof e.navStops !== "function" || !e.shown) continue
      // Tray items and hosted widgets are cells of their pill, listed as they
      // are; everything else only while it has a size on the bar.
      for (const s of e.navStops()) {
        if (s.kind === "tray" || s.kind === "plugin") out.push(s)
        else add(s.item, s.act, s)
      }
    }
    return out
  }

  function sameStop(a, b) { return !!a && !!b && a.item === b.item }
  function setStop(s, i) {
    cursorStop = s
    cursorIndex = i
    // The compact tray and the plugin overflow open while the cursor is in them.
    for (const e of entries())
      if (typeof e.cursorMoved === "function") e.cursorMoved(s)
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
    const i = Math.max(0, stops.findIndex(s => s.kind === "workspace" && wsE && s.wsId === wsE.activeId))
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
      if (root.wsE && n <= root.wsE.shown) root.scope.switchWorkspace(root.wsE.groupOffset + n)
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
      void (root.layoutGen + col.y + col.x + startBox.x + startBox.y + startBox.width + startBox.height
        + centerBox.x + centerBox.y + centerBox.width + centerBox.height + endBox.x + endBox.y + endBox.width + endBox.height
        + (root.pluginsE ? root.pluginsE.pill.width + root.pluginsE.pill.height : 0)
        + (root.trayE ? root.trayE.width + root.trayE.height : 0))
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
    for (const e of entries())
      if (typeof e.statusPopouts === "function")
        for (const p of e.statusPopouts())
          if (out.indexOf(p) < 0) out.push(p)
    return out
  }

  // Where a popout opened without the pointer should sit: beside its icon,
  // or centred on the bar when the icon is hidden (a keyboard-layout popout
  // with the icon off still opens).
  function popoutCenterFor(name) {
    const c = ask("popoutCenterFor", name)
    return c !== null ? c : vertical ? height / 2 : width / 2
  }

  // Which collapsible group the pointer is over, from ScreenScope (Caelestia
  // drives its compact tray the same way, in Bar.checkPopout). A hover
  // handler inside the bar is no good: leaving the layer surface altogether
  // never reaches it, and the group would stay open.
  // Open while the pointer is on the group; ScreenScope drives this.
  readonly property bool groupsExpanded: (!!trayE && trayE.expanded) || (!!pluginsE && pluginsE.expanded) || drawerOpen

  function hoverAt(a, onBar) {
    for (const e of entries())
      if (typeof e.hoverAt === "function") e.hoverAt(a, onBar)
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
    const step = (cellLen + Tk.spacing.medium / 2) * dy / 120
    if (vertical) flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height, flick.contentY - step))
    else flick.contentX = Math.max(0, Math.min(flick.contentWidth - flick.width, flick.contentX - step))
  }

  function handleWheel(a, dy) {
    for (const e of entries())
      if (typeof e.scrollAt === "function" && e.scrollAt(a, dy)) return
    // Omarchy's volume/brightness keys: they resolve the real sink behind a
    // speaker tuning and show the OSD (Caelestia's sliders, once the OSD
    // handover is in; Omarchy's own otherwise).
    const svc = Config.o.services
    if (a < alen(root) / 2) { if (cfg.scroll.volume) Quickshell.execDetached(["omarchy-audio-output-volume", (dy > 0 ? "+" : "-") + svc.volumeStep]) }
    // The screen this bar is on, not the focused one; DisplayService brings
    // the others along when the displays share one brightness.
    else if (cfg.scroll.brightness) DisplayService.stepBrightness(screen.name, dy > 0 ? "+" + svc.brightnessStep + "%" : svc.brightnessStep + "%-")
  }

  // Shared by the clock entry (ClockEntry reads bar.sysClock).
  property alias sysClock: clock
  SystemClock { id: clock; precision: root.cfg.clock.showSeconds ? SystemClock.Seconds : SystemClock.Minutes }
  PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource] }

  // ------------------------------------------------------- sections
  // Start sits at the start of the bar, end at its end. The window title
  // (always somewhere: it holds the free space even with its text off) makes
  // its section take the free space; any other center section is centred on
  // the bar and shifted, never shrunk, so it doesn't overlap start or end.
  // With the title in the center (the default) this is the old single column.
  function natural(box) { return box.visible ? (vertical ? box.implicitHeight : box.implicitWidth) : 0 }
  readonly property real sNat: natural(startBox)
  readonly property real cNat: natural(centerBox)
  readonly property real eNat: natural(endBox)
  readonly property real lenAll: alen(col)
  // Where what follows start may begin, and where what precedes end must stop.
  readonly property real afterStart: startBox.visible ? sNat + gap : 0
  readonly property real beforeEnd: endBox.visible ? lenAll - eNat - gap : lenAll
  readonly property real centerPos: {
    if (titleIn === "center") return afterStart
    const lo = afterStart + (titleIn === "start" ? titleMin + gap : 0)
    const hi = beforeEnd - cNat - (titleIn === "end" ? titleMin + gap : 0)
    return Math.round(Math.max(lo, Math.min(hi, (lenAll - cNat) / 2)))
  }
  readonly property real centerLen: titleIn === "center" ? Math.max(0, beforeEnd - afterStart) : cNat
  readonly property real startLen: titleIn !== "start" ? sNat
    : Math.max(sNat, (centerBox.visible ? centerPos - gap : beforeEnd))
  readonly property real endLen: titleIn !== "end" ? eNat
    : Math.max(eNat, lenAll - (centerBox.visible ? centerPos + cNat + gap : afterStart))

  // One section: its entries in order, one Loader each. A Loader is what the
  // layout sees, so it takes its entry's own Layout settings.
  component Section: GridLayout {
    id: box
    property var segList: []
    // The Repeater's model, kept in step with segList row by row: an entry
    // that stays where it is keeps its delegate (and a hosted widget its
    // state) when others change, and one that folds behind the chevron or
    // comes back only has its `drawer` flag changed; only what moved is made
    // again, never the whole section.
    ListModel { id: segModel }
    function rowOf(seg) {
      return { segId: seg.id, kind: seg.kind, idsStr: seg.ids ? seg.ids.join(",") : "", pluginId: seg.pluginId || "", drawer: !!seg.drawer }
    }
    function sync() {
      const next = segList || []
      for (let i = 0; i < next.length; i++) {
        let j = -1
        for (let k = i; k < segModel.count; k++) if (segModel.get(k).segId === next[i].id) { j = k; break }
        // Out of place: made again where it belongs. A ListModel move()
        // reorders the Repeater's items but not the GridLayout they sit in,
        // which kept drawing them in the old order.
        if (j > i) segModel.remove(j)
        if (j !== i) segModel.insert(i, rowOf(next[i]))
        else if (segModel.get(i).drawer !== !!next[i].drawer) segModel.setProperty(i, "drawer", !!next[i].drawer)
      }
      while (segModel.count > next.length) segModel.remove(segModel.count - 1)
    }
    onSegListChanged: sync()
    Component.onCompleted: sync()
    property string sec
    property alias rep: srep
    readonly property bool any: {
      void root.layoutGen
      for (let i = 0; i < srep.count; i++) {
        const l = srep.itemAt(i)
        if (l && l.item && l.item.shown) return true
      }
      return false
    }
    visible: any
    columns: root.vertical ? 1 : -1
    rows: root.vertical ? -1 : 1
    flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
    // The gaps are each Loader's leading margin instead (`lead`), so one that
    // folds behind the chevron takes its gap with it, gradually.
    rowSpacing: 0
    columnSpacing: 0
    // The first entry on show: it has no gap before it.
    readonly property Item firstShown: {
      void root.layoutGen
      for (let i = 0; i < srep.count; i++) {
        const l = srep.itemAt(i)
        if (l && l.item && l.item.shown && l.foldProg > 0.001) return l
      }
      return null
    }
    // Neighbouring pills (status icons, widgets) share one pill: runs of
    // shown entries that are `joinable`, as [{ a, b }] (first and last
    // Loader). Each joined entry drops its own background and its padding on
    // the joined side, and `backdrops` draws the run's pill behind them.
    readonly property var runs: {
      void root.layoutGen
      const out = []
      let cur = null
      for (let i = 0; i < srep.count; i++) {
        const l = srep.itemAt(i)
        const it = l ? l.item : null
        if (!it || !it.shown || l.foldProg <= 0.001) continue      // hidden: takes no room, joins nothing
        if (it.joinable === true) {
          if (cur) { cur.b = l; cur.n++ } else { cur = { a: l, b: l, n: 1 } }
        } else { if (cur) out.push(cur); cur = null }
      }
      if (cur) out.push(cur)
      return out.filter(r => r.n > 1)
    }
    function joinOf(loader) {
      for (const r of runs) {
        if (r.a === loader) return { before: false, after: true }
        if (r.b === loader) return { before: true, after: false }
        // Inside a run: between its first and last, along the bar.
        const p = root.apos(loader), pa = root.apos(r.a), pb = root.apos(r.b)
        if (p > pa && p < pb) return { before: true, after: true }
      }
      return { before: false, after: false }
    }
    Repeater {
      id: srep
      model: segModel
      Loader {
        id: ld
        required property string segId
        required property string kind
        required property string idsStr
        required property string pluginId
        required property bool drawer
        required property int index
        readonly property var join: { void box.runs; return box.joinOf(ld) }
        Binding { target: ld.item; property: "joinBefore"; value: ld.join.before; when: !!ld.item && ld.item.joinable === true }
        Binding { target: ld.item; property: "joinAfter"; value: ld.join.after; when: !!ld.item && ld.item.joinable === true }
        // Behind the chevron, and it is closed.
        readonly property bool folded: drawer && !root.drawerOpen
        // How far it is unfolded, 0..1. The chevron's items come out one after
        // another from the chevron's side (and go back the other way round):
        // its length, its gap, its opacity and a short slide follow this.
        readonly property int drawerCount: box.segList.filter(s => s.drawer).length
        readonly property int drawerOrder: {
          if (!drawer) return 0
          const n = box.segList.slice(0, index).filter(s => s.drawer).length
          // Counted from the chevron: in the end section it is after them.
          return box.sec === "end" ? drawerCount - 1 - n : n
        }
        property real foldProg: folded ? 0 : 1
        Behavior on foldProg {
          SequentialAnimation {
            PauseAnimation { duration: (ld.folded ? ld.drawerCount - 1 - ld.drawerOrder : ld.drawerOrder) * 35 }
            Anim { type: "spatial" }
          }
        }
        // A gap before every entry but the first on show.
        readonly property real lead: box.firstShown === ld ? 0 : root.gap * foldProg
        Layout.topMargin: root.vertical ? lead : 0
        Layout.leftMargin: root.vertical ? 0 : lead
        Layout.preferredHeight: drawer && root.vertical && item ? item.implicitHeight * foldProg : -1
        Layout.preferredWidth: drawer && !root.vertical && item ? item.implicitWidth * foldProg : -1
        clip: drawer && foldProg < 1
        opacity: drawer ? foldProg : 1
        // Toward the chevron while folding: before it in the end section.
        transform: Translate {
          readonly property real d: ld.drawer ? (1 - ld.foldProg) * root.cellLen * (box.sec === "end" ? 1 : -1) : 0
          x: root.vertical ? 0 : d
          y: root.vertical ? d : 0
        }
        Layout.fillWidth: !!item && item.Layout.fillWidth
        Layout.fillHeight: !!item && item.Layout.fillHeight
        Layout.alignment: item ? item.Layout.alignment : 0
        visible: !!item && item.shown && foldProg > 0.001
        sourceComponent: root.entryComponent({ kind: kind, id: segId })
        onLoaded: {
          if (kind === "status") item.ids = idsStr.split(",")
          else if (kind === "plugin") item.pluginId = pluginId
        }
      }
    }
  }
  function entryComponent(seg) {
    if (seg.kind === "status") return cStatus
    if (seg.kind === "plugin") return cSinglePlugin
    return ({ logo: cLogo, workspaces: cWorkspaces, activeWindow: cActiveWindow, plugins: cPlugins,
      tray: cTray, clock: cClock, power: cPower, overflow: cOverflow })[seg.id] || null
  }
  Component { id: cLogo; LogoEntry { bar: root } }
  Component { id: cWorkspaces; WorkspacesEntry { bar: root } }
  Component { id: cActiveWindow; ActiveWindowEntry { bar: root } }
  Component { id: cPlugins; PluginsEntry { bar: root } }
  Component { id: cTray; TrayEntry { bar: root } }
  Component { id: cClock; ClockEntry { bar: root } }
  Component { id: cStatus; StatusRun { bar: root } }
  Component { id: cPower; PowerEntry { bar: root } }
  Component { id: cSinglePlugin; SinglePluginEntry { bar: root } }
  Component { id: cOverflow; OverflowEntry { bar: root } }

  Item {
    id: col
    anchors.fill: parent

    // The shared pills behind joined entries (Section.runs), one per run,
    // from its first entry's start to its last entry's end.
    Repeater {
      model: [startBox, centerBox, endBox].reduce((out, b) => out.concat(b.runs.map(r => ({ box: b, a: r.a, b: r.b }))), [])
      Rectangle {
        required property var modelData
        readonly property Item box: modelData.box
        readonly property Item first: modelData.a
        readonly property Item last: modelData.b
        // Across the bar it is centred on the section, whatever each entry's
        // own breadth; along it, from the first entry to the end of the last.
        x: box.x + (root.vertical ? Math.round((box.width - width) / 2) : first.x)
        y: box.y + (root.vertical ? first.y : Math.round((box.height - height) / 2))
        width: root.vertical ? Tk.barInner : last.x + last.width - first.x
        height: root.vertical ? last.y + last.height - first.y : Tk.barInner
        radius: (root.vertical ? width : height) / 2
        color: Colours.m3surfaceContainer
        visible: box.visible
      }
    }
    // Padded at its two ends along the bar.
    anchors.topMargin: root.vertical ? root.vPadding : 0
    anchors.bottomMargin: root.vertical ? root.vPadding : 0
    anchors.leftMargin: root.vertical ? 0 : root.vPadding
    anchors.rightMargin: root.vertical ? 0 : root.vPadding

    Section {
      id: startBox
      segList: root.segs.start
      sec: "start"
      x: 0; y: 0
      width: root.vertical ? col.width : root.startLen
      height: root.vertical ? root.startLen : col.height
    }
    Section {
      id: centerBox
      segList: root.segs.center
      sec: "center"
      x: root.vertical ? 0 : root.centerPos
      y: root.vertical ? root.centerPos : 0
      width: root.vertical ? col.width : root.centerLen
      height: root.vertical ? root.centerLen : col.height
    }
    Section {
      id: endBox
      segList: root.segs.end
      sec: "end"
      x: root.vertical ? 0 : col.width - root.endLen
      y: root.vertical ? col.height - root.endLen : 0
      width: root.vertical ? col.width : root.endLen
      height: root.vertical ? root.endLen : col.height
    }
  }

  // Drawn above the layout: pills that must not live inside a placeholder
  // that can hide (PluginsEntry), placed from their placeholder's position.
  Item { id: overlay; anchors.fill: parent }
}
