.pragma library

// Which screens get what (Settings › Taskbar › Screens, Panels › Desktop,
// Notifications and OSD): Caelestia's bar.excludedScreens and per-monitor
// bar edges, keyed by connector name as Caelestia does. Plain JS, so
// tests/test-screens.js runs it under node.

var EDGES = ["left", "right", "top", "bottom"]

function listOf(v) {
  if (!v || typeof v === "string" || typeof v.length !== "number") return []
  var out = []
  for (var i = 0; i < v.length; i++) out.push(String(v[i]))
  return out
}

// A screen's bar edge: its own (bar.screenPositions), else the bar's.
function edgeFor(name, positions, fallback) {
  var e = positions && positions[name]
  return EDGES.indexOf(e) >= 0 ? e : fallback
}

// Whether a screen has a bar. Excluding every connected screen would leave
// no bar at all, so the first connected screen keeps its own then.
function barOn(name, excluded, connected) {
  var ex = listOf(excluded), all = listOf(connected)
  if (ex.indexOf(name) < 0) return true
  var none = all.every(function (n) { return ex.indexOf(n) >= 0 })
  return none && all[0] === name
}

// Desktop widgets: on every screen not excluded.
function shownOn(name, excluded) { return listOf(excluded).indexOf(name) < 0 }

// Toasts and the OSD: "all", "focused", or one screen's name (the focused
// screen while that one isn't plugged in).
function targetFor(name, setting, focused, connected) {
  if (!setting || setting === "all") return true
  if (setting === "focused") return name === focused
  if (listOf(connected).indexOf(setting) < 0) return name === focused
  return name === setting
}

// Where a bar hotkey opens: the focused screen, else the first with a bar.
function barScreen(focused, excluded, connected) {
  if (barOn(focused, excluded, connected)) return focused
  var all = listOf(connected)
  for (var i = 0; i < all.length; i++) if (barOn(all[i], excluded, connected)) return all[i]
  return focused
}

// bar.screenPositions is stored as "screen=edge" strings (a settings list),
// read as a map here.
function positionsFrom(list) {
  var out = {}, l = listOf(list)
  for (var i = 0; i < l.length; i++) {
    var eq = l[i].lastIndexOf("=")
    if (eq > 0 && EDGES.indexOf(l[i].slice(eq + 1)) >= 0) out[l[i].slice(0, eq)] = l[i].slice(eq + 1)
  }
  return out
}
// The list with one screen's edge set; "" goes back to following the bar.
function positionsWith(list, name, edge) {
  var out = listOf(list).filter(function (e) { return e.slice(0, e.lastIndexOf("=")) !== name })
  if (EDGES.indexOf(edge) >= 0) out.push(name + "=" + edge)
  return out
}

// The edges of a screen ({ x, y, width, height }, layout coordinates) that
// another screen sits against, along more than a corner: the pointer slides
// over them into the next screen instead of stopping there.
function sharedEdges(me, screens) {
  var out = []
  var l = me.x, r = me.x + me.width, t = me.y, b = me.y + me.height
  for (var i = 0; i < (screens ? screens.length : 0); i++) {
    var o = screens[i]
    if (!o || (o.x === me.x && o.y === me.y && o.width === me.width && o.height === me.height)) continue
    var ol = o.x, or_ = o.x + o.width, ot = o.y, ob = o.y + o.height
    var alongV = Math.min(b, ob) > Math.max(t, ot), alongH = Math.min(r, or_) > Math.max(l, ol)
    if (alongV && or_ === l && out.indexOf("left") < 0) out.push("left")
    if (alongV && ol === r && out.indexOf("right") < 0) out.push("right")
    if (alongH && ob === t && out.indexOf("top") < 0) out.push("top")
    if (alongH && ot === b && out.indexOf("bottom") < 0) out.push("bottom")
  }
  return out
}

// The dock's edge (dock.position). Never the bar's; a chosen edge is kept.
// "auto" is the bottom, as docks are, else the top, else the side away from
// the bar -- skipping edges shared with another screen (the pointer can't
// rest there to bring the dock out), unless every one of them is.
function dockEdgeFor(setting, barPos, shared) {
  if (EDGES.indexOf(setting) >= 0 && setting !== barPos) return setting
  var opposite = { left: "right", right: "left", top: "bottom", bottom: "top" }
  var order = ["bottom", "top", opposite[barPos] || "right"]
  var free = order.filter(function (e) { return e !== barPos })
  var sh = listOf(shared)
  for (var i = 0; i < free.length; i++) if (sh.indexOf(free[i]) < 0) return free[i]
  return free[0]
}
