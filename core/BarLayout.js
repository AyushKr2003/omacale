.pragma library

// Omacale bar layout (bar.layout, Settings › Taskbar › Layout): which items
// sit in the bar's start, center and end sections, and in what order. No
// Caelestia original -- Caelestia's bar.entries is one list -- the sections
// follow Noctalia's bar. The default reproduces Caelestia's order exactly.
// Plain JS with no Qt, so tests/test-layout.js runs it under node.

var SECTIONS = ["start", "center", "end"]

// Status icons, in Caelestia's order. Neighbours in one section share a pill.
var STATUS = ["keepAwake", "update", "recording", "notifications", "lockStatus",
  "audio", "microphone", "kbLayout", "network", "bluetooth", "battery"]

// key: the existing switch that shows or hides the item ("" = always shown).
var ITEMS = {
  logo:          { section: "start",  label: "Logo",            icon: "change_history",   key: "bar.logo",                  sub: "Opens the launcher" },
  workspaces:    { section: "start",  label: "Workspaces",      icon: "workspaces",       key: "",                          sub: "Always shown" },
  activeWindow:  { section: "center", label: "Window title",    icon: "web_asset",        key: "bar.activeWindow.enabled",  sub: "Takes the free space" },
  plugins:       { section: "end",    label: "Plugin group",    icon: "extension",        key: "bar.plugins.enabled",       sub: "Third-party widgets" },
  tray:          { section: "end",    label: "Tray",            icon: "widgets",          key: "bar.tray.enabled",          sub: "System tray icons" },
  clock:         { section: "end",    label: "Clock",           icon: "schedule",         key: "bar.clock.enabled",         sub: "Opens the dashboard" },
  keepAwake:     { section: "end",    label: "Keep awake",      icon: "coffee",           key: "bar.status.keepAwake",      sub: "Status icon" },
  update:        { section: "end",    label: "Omarchy update",  icon: "system_update_alt", key: "bar.status.update",        sub: "Status icon" },
  recording:     { section: "end",    label: "Recording",       icon: "fiber_manual_record", key: "",                       sub: "Shown while recording" },
  notifications: { section: "end",    label: "Notifications",   icon: "notifications",    key: "bar.status.notifications",  sub: "Status icon" },
  lockStatus:    { section: "end",    label: "Caps / num lock", icon: "keyboard_capslock_badge", key: "bar.status.lockStatus", sub: "Status icon" },
  audio:         { section: "end",    label: "Volume",          icon: "volume_up",        key: "bar.status.audio",          sub: "Status icon" },
  microphone:    { section: "end",    label: "Microphone",      icon: "mic",              key: "bar.status.microphone",     sub: "Status icon" },
  kbLayout:      { section: "end",    label: "Keyboard layout", icon: "keyboard",         key: "bar.status.kbLayout",       sub: "Status icon" },
  network:       { section: "end",    label: "Network",         icon: "wifi",             key: "bar.status.network",        sub: "Status icon" },
  bluetooth:     { section: "end",    label: "Bluetooth",       icon: "bluetooth",        key: "bar.status.bluetooth",      sub: "Status icon" },
  battery:       { section: "end",    label: "Battery",         icon: "battery_5_bar",    key: "bar.status.battery",        sub: "Status icon" },
  power:         { section: "end",    label: "Power",           icon: "power_settings_new", key: "bar.power",               sub: "Opens the session menu" }
}

var ORDER = {
  start: ["logo", "workspaces"],
  center: ["activeWindow"],
  end: ["plugins", "tray", "clock"].concat(STATUS).concat(["power"])
}

function isPlugin(id) { return typeof id === "string" && id.indexOf("plugin:") === 0 }
function pluginOf(id) { return id.slice(7) }

function defaults() {
  return { start: ORDER.start.slice(), center: ORDER.center.slice(), end: ORDER.end.slice() }
}
function clone(l) { return { start: l.start.slice(), center: l.center.slice(), end: l.end.slice() } }
function find(l, id) {
  for (var s = 0; s < SECTIONS.length; s++) {
    var i = l[SECTIONS[s]].indexOf(id)
    if (i >= 0) return { sec: SECTIONS[s], i: i }
  }
  return null
}
// QML hands a list<string> over as an array-like, not always an Array.
function listOf(v) {
  if (!v || typeof v === "string" || typeof v.length !== "number") return []
  var out = []
  for (var i = 0; i < v.length; i++) out.push(v[i])
  return out
}

// The saved layout, repaired: unknown ids, junk and duplicates dropped,
// widgets that are no longer enabled bar widgets dropped, and every built-in
// that is missing put back in its default section after its nearest default
// predecessor there (so an item a later version adds lands where it belongs).
function resolve(saved, widgetIds) {
  var widgets = listOf(widgetIds)
  var out = { start: [], center: [], end: [] }
  var seen = {}
  for (var s = 0; s < SECTIONS.length; s++) {
    var list = listOf(saved ? saved[SECTIONS[s]] : null)
    for (var i = 0; i < list.length; i++) {
      var id = list[i]
      if (typeof id !== "string" || seen[id]) continue
      if (isPlugin(id) ? widgets.indexOf(pluginOf(id)) < 0 : !ITEMS.hasOwnProperty(id)) continue
      seen[id] = true
      out[SECTIONS[s]].push(id)
    }
  }
  for (var t = 0; t < SECTIONS.length; t++) {
    var sec = SECTIONS[t], order = ORDER[sec]
    for (var j = 0; j < order.length; j++) {
      if (seen[order[j]]) continue
      seen[order[j]] = true
      var at = 0
      for (var k = j - 1; k >= 0; k--) {
        var p = out[sec].indexOf(order[k])
        if (p >= 0) { at = p + 1; break }
      }
      out[sec].splice(at, 0, order[j])
    }
  }
  return out
}

// A section's ids as what the bar draws: one entry per item, except that
// neighbouring status icons share one pill (a "status" segment).
function segments(list) {
  var out = []
  for (var i = 0; i < list.length; i++) {
    var id = list[i]
    if (isPlugin(id)) out.push({ kind: "plugin", id: id, pluginId: pluginOf(id) })
    else if (STATUS.indexOf(id) >= 0) {
      var last = out.length ? out[out.length - 1] : null
      if (last && last.kind === "status") { last.ids.push(id); last.id = "status:" + last.ids.join(",") }
      else out.push({ kind: "status", id: "status:" + id, ids: [id] })
    } else out.push({ kind: "item", id: id })
  }
  return out
}

// One step towards the start (dir -1) or the end (dir 1). At a section's
// edge the item crosses into the neighbouring section, at its near end.
function canMove(layout, id, dir) {
  var f = find(layout, id)
  if (!f) return false
  var j = f.i + dir
  if (j >= 0 && j < layout[f.sec].length) return true
  var ns = SECTIONS.indexOf(f.sec) + dir
  return ns >= 0 && ns < SECTIONS.length
}
function move(layout, id, dir) {
  var l = clone(layout)
  if (!canMove(l, id, dir)) return l
  var f = find(l, id), list = l[f.sec]
  var inside = dir < 0 ? f.i > 0 : f.i < list.length - 1
  list.splice(f.i, 1)
  if (inside) { list.splice(f.i + dir, 0, id); return l }
  var ns = SECTIONS[SECTIONS.indexOf(f.sec) + dir]
  if (dir < 0) l[ns].push(id)
  else l[ns].unshift(id)
  return l
}

// A widget out of the plugin group, placed right after the group.
function takeOut(layout, pluginId) {
  var l = clone(layout), id = "plugin:" + pluginId
  if (find(l, id)) return l
  var g = find(l, "plugins")
  if (g) l[g.sec].splice(g.i + 1, 0, id)
  else l.end.push(id)
  return l
}
function putBack(layout, pluginId) {
  var l = clone(layout), f = find(l, "plugin:" + pluginId)
  if (f) l[f.sec].splice(f.i, 1)
  return l
}

// The section whose free space the window title takes: where it is, while it
// is shown. With it switched off nothing takes the free space, so the center
// section is centred on the bar.
function flexSection(layout, titleShown) {
  if (!titleShown) return ""
  for (var s = 0; s < SECTIONS.length; s++)
    if (layout[SECTIONS[s]].indexOf("activeWindow") >= 0) return SECTIONS[s]
  return ""
}

function sectionLabel(section, vertical) {
  var names = vertical ? { start: "Top", center: "Middle", end: "Bottom" } : { start: "Left", center: "Center", end: "Right" }
  return names[section] || section
}
