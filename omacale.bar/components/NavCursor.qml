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

  function rectOf(t) {
    const p = t.mapToItem(space, 0, 0)
    return Qt.rect(p.x, p.y, t.width, t.height)
  }
  function stops() {
    const out = []
    const walk = item => {
      if (!item || !item.visible || item.opacity === 0) return
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
    setCursor(null)
  }
  onActiveChanged: if (!active) clear()
  // The drawers' content changed shape (another tab, another page): start
  // over -- unless the cursor is still in it (on the dashboard's tab bar, say).
  onRootsChanged: if (!cursor || !under(cursor, roots)) clear()

  // The first key lands the cursor rather than moving it.
  // Among stops that act on focus (dashboard tabs), the current one: landing
  // anywhere else would switch the tab you opened on.
  function start() {
    const ts = readingOrder(stops())
    if (!ts.length) return false
    let t = ts[0]
    const first = nearest(t, "navOnFocus")
    if (first && first.current === false)
      t = ts.find(s => { const f = nearest(s, "navOnFocus"); return f && f.current === true }) || t
    setCursor(t)
    return true
  }

  function move(dx, dy) {
    if (!cursor) return start()
    if (dx !== 0 && typeof cursor.navAdjust === "function") { cursor.navAdjust(dx); return true }
    const c = rectOf(cursor)
    const cx = c.x + c.width / 2, cy = c.y + c.height / 2
    let best = null, bestScore = Infinity
    for (const t of stops()) {
      if (t === cursor) continue
      const r = rectOf(t)
      const tx = r.x + r.width / 2, ty = r.y + r.height / 2
      // How far it lies in the direction asked, and how far off that line.
      const along = dx !== 0 ? (tx - cx) * dx : (ty - cy) * dy
      if (along <= 2) continue
      const overlap = dx !== 0
        ? Math.min(c.y + c.height, r.y + r.height) - Math.max(c.y, r.y)
        : Math.min(c.x + c.width, r.x + r.width) - Math.max(c.x, r.x)
      const off = overlap > 0 ? 0 : (dx !== 0 ? Math.abs(ty - cy) : Math.abs(tx - cx))
      const score = along + off * 3
      if (score < bestScore) { bestScore = score; best = t }
    }
    if (best) setCursor(best)
    return !!best
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

  // The stop under the cursor was destroyed (a notification dismissed, a list
  // rebuilt): land on whatever now sits nearest to where it was.
  onCursorChanged: if (!cursor && active && lastRect.width > 0) restore.restart()
  property Timer restore: Timer {
    interval: 30
    onTriggered: {
      if (nav.cursor || !nav.active) return
      const cx = nav.lastRect.x + nav.lastRect.width / 2, cy = nav.lastRect.y + nav.lastRect.height / 2
      let best = null, bestD = Infinity
      for (const t of nav.stops()) {
        const r = nav.rectOf(t)
        const d = Math.hypot(r.x + r.width / 2 - cx, r.y + r.height / 2 - cy)
        if (d < bestD) { bestD = d; best = t }
      }
      if (best) nav.setCursor(best)
    }
  }
}
