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
  overflow:      { section: "end",    label: "Chevron",         icon: "more_horiz",      key: "",                          sub: "Opens the items behind it" },
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

// The Settings page each built-in's gear opens ("" = none: its eye is all).
var PAGES = {
  logo: "barButtons", workspaces: "workspaces", activeWindow: "activeWindow", tray: "tray", clock: "clock",
  keepAwake: "status", update: "status", recording: "", notifications: "status", lockStatus: "status",
  audio: "status", microphone: "status", kbLayout: "status", network: "status", bluetooth: "status",
  battery: "status", plugins: "", power: "barButtons", overflow: ""
}

// A widget's category (its manifest's barWidget.category) as an icon, for its
// row in Settings and the bar's stand-in when it is too long to show.
var CATEGORY_ICONS = {
  "network": "lan", "fun": "mood", "media": "music_note", "system": "memory",
  "productivity": "task_alt", "developer": "code", "development": "code",
  "utilities": "build", "communication": "chat", "weather": "partly_cloudy_day",
  "time": "schedule", "ai": "smart_toy", "status": "monitor_heart", "audio": "volume_up",
  "files": "folder", "info": "info", "appearance": "palette", "compositor": "desktop_windows",
  "window management": "select_window", "layout": "space_bar", "plugin": "extension"
}
function categoryIcon(category) {
  return CATEGORY_ICONS[String(category || "").toLowerCase()] || "extension"
}

var ORDER = {
  start: ["logo", "workspaces"],
  center: ["activeWindow"],
  end: ["overflow", "plugins", "tray", "clock"].concat(STATUS).concat(["power"])
}

// Omarchy's own bar widgets that Omacale already draws itself (the value is
// the Omacale item; "" = covered elsewhere, e.g. Settings › Display). They are
// offered only behind Settings › Taskbar's "Omarchy's versions" switch and are
// never put on the bar by themselves.
var DUPLICATES = {
  "omarchy.audio": "audio", "omarchy.network": "network", "omarchy.bluetooth": "bluetooth",
  "omarchy.clock": "clock", "omarchy.tray": "tray", "omarchy.workspaces": "workspaces",
  "omarchy.menu": "logo", "omarchy.power": "battery", "omarchy.microphone": "microphone",
  "omarchy.keyboard-layout": "kbLayout", "omarchy.system-update": "update",
  "omarchy.active-window": "activeWindow", "omarchy.monitor": ""
}
// Widgets that make no sense on their own in Omacale's bar.
var NEVER = ["omarchy.spacer"]

function isPlugin(id) { return typeof id === "string" && id.indexOf("plugin:") === 0 }
function pluginOf(id) { return id.slice(7) }

// `removed` holds the built-ins taken off the bar (Settings › Taskbar › Layout's
// "Not in the bar"); they stay off until added back.
// `drawer` holds the items behind the chevron (bar.layout.drawer): drawn
// right after it, folded away until it opens.
function defaults() {
  return { start: ORDER.start.slice(), center: ORDER.center.slice(), end: ORDER.end.slice(), removed: [], drawer: [] }
}
function clone(l) {
  return { start: l.start.slice(), center: l.center.slice(), end: l.end.slice(), removed: (l.removed || []).slice(), drawer: (l.drawer || []).slice() }
}
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
// that is neither on the bar nor removed put back in its default section
// after its nearest default predecessor there (so an item a later version
// adds lands where it belongs). widgetIds null means the widget list isn't
// known yet: every plugin entry is kept rather than lost on the next write.
function resolve(saved, widgetIds) {
  var known = widgetIds !== null && widgetIds !== undefined
  var widgets = listOf(widgetIds)
  var out = { start: [], center: [], end: [], removed: [], drawer: [] }
  var seen = {}
  for (var s = 0; s < SECTIONS.length; s++) {
    var list = listOf(saved ? saved[SECTIONS[s]] : null)
    for (var i = 0; i < list.length; i++) {
      var id = list[i]
      if (typeof id !== "string" || seen[id]) continue
      if (isPlugin(id) ? known && widgets.indexOf(pluginOf(id)) < 0 : !ITEMS.hasOwnProperty(id)) continue
      seen[id] = true
      out[SECTIONS[s]].push(id)
    }
  }
  // Behind the chevron: the same items, never the chevron itself.
  var inDrawer = listOf(saved ? saved.drawer : null)
  for (var d = 0; d < inDrawer.length; d++) {
    var di = inDrawer[d]
    if (typeof di !== "string" || seen[di] || di === "overflow") continue
    if (isPlugin(di) ? known && widgets.indexOf(pluginOf(di)) < 0 : !ITEMS.hasOwnProperty(di)) continue
    seen[di] = true
    out.drawer.push(di)
  }
  // Removed: built-ins and enabled widgets, and only while not on the bar.
  var gone = listOf(saved ? saved.removed : null)
  for (var r = 0; r < gone.length; r++) {
    var g = gone[r]
    if (typeof g !== "string" || seen[g]) continue
    if (isPlugin(g) ? known && widgets.indexOf(pluginOf(g)) < 0 : !ITEMS.hasOwnProperty(g)) continue
    seen[g] = true
    out.removed.push(g)
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
// Items are ids, or { id, drawer } from render(): an item behind the chevron
// is its own segment (drawer: true), never in a run with one that isn't.
function segments(list) {
  var out = []
  for (var i = 0; i < list.length; i++) {
    var id = typeof list[i] === "string" ? list[i] : list[i].id
    var dr = typeof list[i] === "string" ? false : !!list[i].drawer
    var seg
    if (isPlugin(id)) seg = { kind: "plugin", id: id, pluginId: pluginOf(id) }
    else if (STATUS.indexOf(id) >= 0) {
      var last = out.length ? out[out.length - 1] : null
      if (last && last.kind === "status" && !!last.drawer === dr) { last.ids.push(id); last.id = "status:" + last.ids.join(","); continue }
      seg = { kind: "status", id: "status:" + id, ids: [id] }
    } else seg = { kind: "item", id: id }
    if (dr) seg.drawer = true
    out.push(seg)
  }
  return out
}

// Items that can go behind the chevron by the "at most N" limit: the icon-
// sized ones. The clock, title, workspaces, logo and power keep their place.
function foldable(id) {
  return isPlugin(id) || STATUS.indexOf(id) >= 0 || id === "tray" || id === "plugins"
}

// What each section draws: { start, center, end } of { id, drawer }. The
// drawer's items follow the chevron in its section (precede it in the end
// section); with `maxShown` > 0,
// the shown foldable items after the chevron past the first maxShown join
// them (shown(id) says whether an item is on show; they are not saved
// there, so the limit can be changed back). Without the chevron on the bar
// the drawer's items aren't drawn.
function render(layout, maxShown, shown) {
  var out = { start: [], center: [], end: [] }
  for (var s = 0; s < SECTIONS.length; s++) {
    var sec = SECTIONS[s], ids = layout[sec], at = ids.indexOf("overflow")
    if (at < 0) { out[sec] = ids.map(function (id) { return { id: id, drawer: false } }); continue }
    var before = ids.slice(0, at + 1).map(function (id) { return { id: id, drawer: false } })
    var folded = (layout.drawer || []).map(function (id) { return { id: id, drawer: true } })
    var after = [], count = 0, extra = []
    for (var i = at + 1; i < ids.length; i++) {
      var id = ids[i]
      var isShown = !shown || shown(id)
      if (maxShown > 0 && foldable(id) && isShown && ++count > maxShown) extra.push({ id: id, drawer: true })
      else after.push({ id: id, drawer: false })
    }
    // The end section grows from the bar's end, so there the items open on
    // the chevron's far side and the chevron stays under the pointer.
    out[sec] = sec === "end"
      ? before.slice(0, -1).concat(folded).concat(extra).concat(before.slice(-1)).concat(after)
      : before.concat(folded).concat(extra).concat(after)
  }
  return out
}

// Put `id` in `target` (a section, or "removed" to take it off the bar) at
// `index`, counted in the target as it is without the item. A plugin-pill
// widget (third-party: in `pillIds`, or any widget when pillIds is not given)
// placed into "removed" goes back to the pill instead; any other widget is
// taken off the bar like a built-in.
function place(layout, id, target, index, pillIds) {
  var l = clone(layout)
  var lists = SECTIONS.concat(["removed", "drawer"])
  for (var s = 0; s < lists.length; s++) {
    var i = l[lists[s]].indexOf(id)
    if (i >= 0) l[lists[s]].splice(i, 1)
  }
  if (target === "removed" && isPlugin(id) && (!pillIds || listOf(pillIds).indexOf(pluginOf(id)) >= 0)) return l
  if (target === "drawer" && id === "overflow") return clone(layout)
  var list = l[target]
  if (!list) return clone(layout)
  list.splice(Math.max(0, Math.min(list.length, index)), 0, id)
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
  return place(layout, "plugin:" + pluginId, "removed", 0)
}

// Widgets Omarchy offers that have not been offered before, put on the bar:
// what makes a widget a later Omarchy update adds show up by itself.
//   widgets: [{ id, firstParty }] -- the enabled bar widgets
//   seen:    ids already offered once (bar.layout.seen)
//   first:   true before the first adoption ever (bar.layout.adopted false);
//            then only the Omarchy widgets Omarchy's own bar layout has
//            (omarchyIds) are placed, everything else is just marked seen
// A first-party widget that isn't a duplicate goes at the end of the end
// section (before the power button, when that is last); a third-party one needs no place (the plugin pill shows it).
// Returns { layout, seen, changed }.
function adoptNew(layout, widgets, seen, first, omarchyIds) {
  var l = clone(layout), was = listOf(seen), out = was.slice(), changed = !!first
  var list = listOf(widgets), mine = listOf(omarchyIds)
  for (var i = 0; i < list.length; i++) {
    var w = list[i]
    if (!w || typeof w.id !== "string" || out.indexOf(w.id) >= 0) continue
    out.push(w.id)
    changed = true
    if (!w.firstParty || DUPLICATES.hasOwnProperty(w.id) || NEVER.indexOf(w.id) >= 0) continue
    if (first && mine.indexOf(w.id) < 0) continue
    var id = "plugin:" + w.id
    if (find(l, id) || l.removed.indexOf(id) >= 0 || l.drawer.indexOf(id) >= 0) continue
    l = appendEnd(l, id)
  }
  return { layout: l, seen: out, changed: changed }
}

// `id` at the end of the end section -- before the power button when that
// closes the bar, so it stays last.
function appendEnd(layout, id) {
  // The index place() takes is counted without the item itself.
  var e = layout.end.filter(function (x) { return x !== id })
  return place(layout, id, "end", e.length && e[e.length - 1] === "power" && id !== "power" ? e.length - 1 : e.length, [])
}

// Items that share a pill with their neighbours on the bar (each such
// entry's `joinable`, BarContent's Section.runs): Settings groups them the
// same way.
function joinable(id) {
  return isPlugin(id) || STATUS.indexOf(id) >= 0 || id === "tray" || id === "plugins" || id === "power" || id === "overflow"
}
// A section's ids as Settings shows them: runs of neighbouring joinable ids
// as one pill group ({ pill: true }), anything else a group of its own.
function groups(ids) {
  var out = []
  for (var i = 0; i < ids.length; i++) {
    var j = joinable(ids[i]), last = out.length ? out[out.length - 1] : null
    if (j && last && last.pill) last.ids.push(ids[i])
    else out.push({ pill: j, ids: [ids[i]] })
  }
  return out
}

// What a widget is in Settings › Taskbar: "omarchy" (Omarchy's own) or
// "plugin" (third-party); built-ins are "omacale".
function sourceOf(id, firstPartyIds) {
  if (!isPlugin(id)) return "omacale"
  return listOf(firstPartyIds).indexOf(pluginOf(id)) >= 0 ? "omarchy" : "plugin"
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
