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

// What the third button does: a command of the user's own, else the chosen
// sleep, else the other one, else nothing ("" folds the button away).
// canHibernate / canSuspend are Omarchy's guards on its menu entries.
function sleepKind(cfg, canHibernate, canSuspend) {
  if (cfg.commands.hibernate) return "custom"
  var wantHibernate = cfg.sleepAction !== "suspend"
  if (wantHibernate && canHibernate) return "hibernate"
  if (canSuspend) return "suspend"
  if (canHibernate) return "hibernate"
  return ""
}

// A button's icon and command: Caelestia's session.icons / session.commands,
// empty meaning Omarchy's own (its System menu, omarchy-menu.jsonc
// "system.*"). Shared by the session drawer and the lock's session controls.
function icon(id, cfg, sleep) {
  var fallback = id === "logout" ? "logout"
    : id === "shutdown" ? "power_settings_new"
    : id === "hibernate" ? (sleep === "suspend" ? "bedtime" : "downloading")
    : id === "reboot" ? "cached"
    : id === "lock" ? "lock"
    : "slideshow"
  return cfg.icons[id] || fallback
}

function command(id, cfg, sleep) {
  if (id === "hibernate")
    return sleep === "custom" ? cfg.commands.hibernate
      : sleep === "suspend" ? "systemctl suspend" : "systemctl hibernate"
  var fallback = id === "logout" ? "omarchy system logout"
    : id === "shutdown" ? "omarchy system shutdown"
    : id === "reboot" ? "omarchy system reboot"
    : id === "lock" ? "omarchy-system-lock"
    : "omarchy-launch-screensaver force"
  return cfg.commands[id] || fallback
}
