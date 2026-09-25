import QtQuick
import ".."

// The keyboard cursor for the drawers (dashboard, sidebar, utilities,
// settings). No Caelestia original: its drawers are pointer-only. Same model
// as the popouts' cursor (PopoutContent): the stops are every item with
// `navTarget` (StateLayer, MSwitch, MSlider, notification rows) under
// `roots`, found afresh on each key, so rows rebuilt under the cursor lose
// nothing. It differs in moving *spatially* -- h/l go sideways across the
// dashboard's cards and the quick-toggle grid, j/k go up and down -- and in
// scrolling the stop into view when it sits in a vertical Flickable.
//
// Drawers name their roots (`navRoots`) rather than being walked whole: the
// dashboard's other tabs sit beside the current one in a clipped strip and
// would otherwise count as on screen.
QtObject {
  id: nav

  property var roots: []
  // Common ancestor all geometry is measured in.
  property Item space: null
  // The cursor is drawn only while this is on (the drawer has the keys).
  property bool active: false

  property Item cursor: null
  property rect lastRect: Qt.rect(0, 0, 0, 0)
  // What the cursor was on, to find it again when its row is rebuilt: the
  // stop's `navKey` (or its nearest ancestor's), and the list it sat in.
  property string lastKey: ""
  property Item lastScope: null
  // The stops after and before it in that list, nearest first, so that a
  // dismissed notification hands the cursor to the next one.
  property var lastAfter: []
  property var lastBefore: []

  // Measured where it will settle: a sliding strip (the dashboard's pages)
  // says how far it still has to go with `navShiftX`, so a key pressed
  // mid-slide doesn't aim at where the page happens to be.
  function rectOf(t) {
    const p = t.mapToItem(space, 0, 0)
    let x = p.x
    for (let a = t.parent; a; a = a.parent) if (typeof a.navShiftX === "number") x += a.navShiftX
    return Qt.rect(x, p.y, t.width, t.height)
  }
  function stops() {
    const out = []
    // Disabled covers a notification group on its way out, whose rows would
    // otherwise still draw the cursor while they shrink away.
    const walk = item => {
      if (!item || !item.visible || !item.enabled || item.opacity === 0) return
      if (item.navTarget === true && item.width > 0 && item.height > 0) out.push(item)
      for (let i = 0; i < item.children.length; i++) walk(item.children[i])
    }
    for (const r of roots) walk(r)
    return out
  }
  function readingOrder(ts) {
    return ts.map(t => ({ t: t, r: rectOf(t) }))
      .sort((a, b) => Math.abs(a.r.y - b.r.y) > 4 ? a.r.y - b.r.y : a.r.x - b.r.x)
      .map(e => e.t)
  }

  function setCursor(t) {
    if (cursor && cursor !== t && cursor.focused !== undefined) cursor.focused = false
    cursor = t
    if (!t) return
    if (t.focused !== undefined) t.focused = active
    lastRect = rectOf(t)
    lastKey = keyOf(t)
    lastScope = scroller(t)
    const order = readingOrder(stops().filter(s => !lastScope || under(s, [lastScope])))
      .map(s => ({ t: s, key: keyOf(s) }))
    const i = order.findIndex(e => e.t === t)
    lastAfter = i < 0 ? [] : order.slice(i + 1)
    lastBefore = i < 0 ? [] : order.slice(0, i).reverse()
    reveal(t)
    // A stop that acts on focus alone (a dashboard tab opens its page).
    const onFocus = nearest(t, "navOnFocus")
    if (onFocus) onFocus.navOnFocus()
  }
  function under(item, rs) {
    for (let p = item; p; p = p.parent) if (rs.indexOf(p) >= 0) return true
    return false
  }
  function clear() {
    lastRect = Qt.rect(0, 0, 0, 0)
    lastKey = ""
    lastScope = null
    lastAfter = []
    lastBefore = []
    setCursor(null)
  }
  onActiveChanged: if (!active) clear()
  // The drawers' content changed shape (another tab, another page): start
  // over -- unless the cursor is still in it (on the dashboard's tab bar, say).
  onRootsChanged: if (!cursor || !under(cursor, roots)) clear()

  function keyOf(t) {
    for (let p = t; p; p = p.parent)
      if (typeof p.navKey === "string" && p.navKey !== "") return p.navKey
    return ""
  }
  // The vertical list a stop scrolls in, if any.
  function scroller(t) {
    for (let p = t ? t.parent : null; p; p = p.parent)
      if (p.contentY !== undefined && p.contentItem && p.flickableDirection !== Flickable.HorizontalFlick) return p
    return null
  }
  // A row of stops (`navRow`, the dashboard's tabs) is its own lane: h/l
  // stay in it and never enter it, and j/k land on its `navEnter()` stop.
  function rowOf(t) {
    for (let p = t; p; p = p.parent) if (p.navRow === true) return p
    return null
  }
  // A stop on a tab that isn't open would switch tabs just by being landed on.
  function idle(t) {
    const f = nearest(t, "navOnFocus")
    return !f || f.current !== false
  }
  // Not scrolled out of any list the cursor isn't in.
  function onScreen(e) {
    for (let s = scroller(e.t); s; s = scroller(s)) {
      if (under(cursor, [s])) continue
      const v = rectOf(s)
      if (e.r.y + e.r.height <= v.y || e.r.y >= v.y + v.height) return false
    }
    return true
  }

  // The first key lands the cursor rather than moving it.
  // Among stops that act on focus (dashboard tabs), the current one: landing
  // anywhere else would switch the tab you opened on.
  function start() {
    const ts = readingOrder(stops())
    if (!ts.length) return false
    setCursor(ts.find(idle) || ts[0])
    return true
  }

  // The best stop in the direction asked. Stops in line with the cursor (its
  // beam) come first, nearest wins, and among a row at the same distance the
  // one most in line. Off the beam it costs three times the drift; sideways
  // it has to be within 45 degrees, so h/l never drop to the bottom of the
  // panel.
  function pick(c, dx, dy, list) {
    const cx = c.x + c.width / 2, cy = c.y + c.height / 2
    let best = null, bestScore = Infinity, bestOff = Infinity, bestBeam = false
    for (const e of list) {
      const r = e.r
      const tx = r.x + r.width / 2, ty = r.y + r.height / 2
      const along = dx !== 0 ? (tx - cx) * dx : (ty - cy) * dy
      if (along <= 2) continue
      const overlap = dx !== 0
        ? Math.min(c.y + c.height, r.y + r.height) - Math.max(c.y, r.y)
        : Math.min(c.x + c.width, r.x + r.width) - Math.max(c.x, r.x)
      const beam = overlap > 0
      const off = dx !== 0 ? Math.abs(ty - cy) : Math.abs(tx - cx)
      if (!beam && dx !== 0 && off > along) continue
      if (bestBeam && !beam) continue
      const score = beam ? along : along + off * 3
      if ((beam && !bestBeam) || score < bestScore - 4 || (score <= bestScore + 4 && off < bestOff)) {
        best = e.t; bestScore = score; bestOff = off; bestBeam = beam
      }
    }
    return best
  }

  function move(dx, dy) {
    if (!cursor) return start()
    if (dx !== 0 && typeof cursor.navAdjust === "function") { cursor.navAdjust(dx); return true }
    const c = rectOf(cursor)
    const row = rowOf(cursor)
    let cands = stops().filter(t => t !== cursor)
    // Sideways stays in the cursor's lane, and skips the stop it sits in or
    // holds (a notification and its action buttons): their centres are
    // beside each other, so l from Close went back up to the notification.
    if (dx !== 0) cands = cands.filter(t => rowOf(t) === row && !under(cursor, [t]) && !under(t, [cursor]))
    cands = cands.map(t => ({ t: t, r: rectOf(t) }))
    let best = null
    // Through the list the cursor is in before out of it: j/k run down the
    // notifications, rather than to the clear-all button floating over them.
    for (let s = scroller(cursor); s && !best; s = scroller(s))
      best = pick(c, dx, dy, cands.filter(e => under(e.t, [s])))
    if (!best) best = pick(c, dx, dy, cands.filter(onScreen)) || pick(c, dx, dy, cands)
    if (!best) return false
    const into = rowOf(best)
    if (dy !== 0 && into && into !== row && typeof into.navEnter === "function")
      best = into.navEnter() || best
    setCursor(best)
    return true
  }
  // Tab: the next or previous stop in reading order, wrapping.
  function next(d) {
    const ts = readingOrder(stops())
    if (!ts.length) return
    const i = cursor ? ts.indexOf(cursor) : -1
    setCursor(ts[i < 0 ? (d > 0 ? 0 : ts.length - 1) : (i + d + ts.length) % ts.length])
  }
  function activate() {
    if (!cursor) { start(); return }
    cursor.navActivate()
  }
  function nearest(item, name) {
    for (let p = item; p; p = p.parent)
      if (typeof p[name] === "function") return p
    return null
  }
  function remove() {
    const row = nearest(cursor, "navDelete")
    if (row) row.navDelete()
  }

  // Scroll a stop inside a vertical Flickable into view.
  function reveal(t) {
    for (let p = t.parent; p; p = p.parent) {
      if (p.contentY === undefined || p.contentHeight === undefined || !p.contentItem) continue
      if (p.flickableDirection === Flickable.HorizontalFlick) continue
      if (p.contentHeight <= p.height + 0.5) continue
      const y = t.mapToItem(p.contentItem, 0, 0).y
      const pad = Tk.padding.medium
      let to = p.contentY
      if (y - pad < to) to = y - pad
      else if (y + t.height + pad > to + p.height) to = y + t.height + pad - p.height
      p.contentY = Math.max(0, Math.min(p.contentHeight - p.height, to))
      return
    }
  }

  // The stop under the cursor was destroyed (a notification dismissed, a
  // list rebuilt because one arrived): find it again by its key; else the
  // next stop that was after it in its list (or, at the end, the one before),
  // matched the same way since those rows are rebuilt too; else whatever now
  // sits nearest to where it was in that list -- so a dismissal doesn't send
  // the cursor to the clear-all button or down into utilities. A list
  // rebuilt a frame late gets a few tries before the cursor looks outside it.
  onCursorChanged: if (!cursor && active && lastRect.width > 0) { restore.tries = 0; restore.restart() }
  property Timer restore: Timer {
    property int tries: 0
    interval: 30
    onTriggered: {
      if (nav.cursor || !nav.active) return
      const all = nav.stops().filter(nav.idle)
      const byKey = nav.lastKey !== "" ? all.filter(t => nav.keyOf(t) === nav.lastKey) : []
      const find = e => all.find(t => t === e.t || (e.key !== "" && nav.keyOf(t) === e.key))
      if (!byKey.length) {
        for (const e of nav.lastAfter.concat(nav.lastBefore)) {
          const t = find(e)
          if (t) { nav.setCursor(t); return }
        }
      }
      const inScope = nav.lastScope ? all.filter(t => nav.under(t, [nav.lastScope])) : []
      const pool = byKey.length ? byKey : inScope.length ? inScope : nav.lastScope && ++tries < 8 ? null : all
      if (!pool) { restart(); return }
      const cx = nav.lastRect.x + nav.lastRect.width / 2, cy = nav.lastRect.y + nav.lastRect.height / 2
      let best = null, bestD = Infinity
      for (const t of pool) {
        const r = nav.rectOf(t)
        const d = Math.hypot(r.x + r.width / 2 - cx, r.y + r.height / 2 - cy)
        if (d < bestD) { bestD = d; best = t }
      }
      if (best) nav.setCursor(best)
    }
  }
}
