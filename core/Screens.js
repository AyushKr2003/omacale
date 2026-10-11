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
