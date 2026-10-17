.pragma library

// The session drawer's items and how Settings › Session › Buttons arranges
// them (session.order, session.hidden, session.extraStyle). Shared by
// Session.qml and the SessionButtons card; `node tests/test-session.js`.

// Caelestia's order (modules/session/Content.qml), then Omarchy's Lock and
// Screensaver, which have no Caelestia original.
var IDS = ["logout", "shutdown", "gif", "hibernate", "reboot", "lock", "screensaver"]
var EXTRA = ["lock", "screensaver"]

// The saved order, repaired: unknown ids and duplicates dropped, and an item
// it doesn't name (one added in a later version) put back after the item
// that comes before it by default.
function order(saved) {
  var out = []
  var list = saved ? Array.prototype.slice.call(saved) : []
  for (var i = 0; i < list.length; i++)
    if (IDS.indexOf(list[i]) >= 0 && out.indexOf(list[i]) < 0) out.push(list[i])
  for (var j = 0; j < IDS.length; j++) {
    if (out.indexOf(IDS[j]) >= 0) continue
    var at = j === 0 ? 0 : out.indexOf(IDS[j - 1]) + 1
    out.splice(at, 0, IDS[j])
  }
  return out
}

// Whether an item is in the drawer. The animation is session.gif; Lock and
// Screensaver also need session.extraButtons (the setting from before
// buttons could be hidden one by one).
function shown(id, cfg) {
  if (id === "gif") return !!cfg.gif
  if (EXTRA.indexOf(id) >= 0 && !cfg.extraButtons) return false
  return Array.prototype.indexOf.call(cfg.hidden || [], id) < 0
}

// Whether an item is drawn half-size (Lock and Screensaver in the compact style).
function small(id, cfg) { return cfg.extraStyle !== "full" && EXTRA.indexOf(id) >= 0 }

// The drawer's rows, top to bottom: each a list of ids. Neighbouring small
// buttons share a row, two to a row; everything else has a row of its own.
function rows(cfg) {
  var ids = order(cfg.order).filter(function(id) { return shown(id, cfg) })
  var out = []
  for (var i = 0; i < ids.length; i++) {
    var last = out.length ? out[out.length - 1] : null
    if (small(ids[i], cfg) && last && last.length === 1 && small(last[0], cfg)) last.push(ids[i])
    else out.push([ids[i]])
  }
  return out
}

// `order` with `id` moved one place up (-1) or down (+1).
function moved(saved, id, by) {
  var o = order(saved)
  var i = o.indexOf(id), j = i + by
  if (i < 0 || j < 0 || j >= o.length) return o
  o[i] = o[j]; o[j] = id
  return o
}
