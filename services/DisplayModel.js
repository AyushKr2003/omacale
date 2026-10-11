.pragma library

// The pure half of Settings › Display: hyprmoncfg's IPC (protocol v1,
// newline-delimited JSON over $XDG_RUNTIME_DIR/hyprmoncfgd.sock, as its own
// Omarchy plugin speaks it), its status document, hyprctl's monitors for when
// hyprmoncfg isn't there, and the arrangement canvas. Plain JS, so
// tests/test-display.js runs it under node.

var PROTOCOL = 1

function parseEnvelope(line) {
  var e
  try { e = JSON.parse(line) } catch (err) { return null }
  if (!e || e.protocol_version !== PROTOCOL) return null
  return e
}

function request(id, method, params) {
  return JSON.stringify({ type: "request", protocol_version: PROTOCOL, id: String(id), method: method, params: params || {} }) + "\n"
}

// Logical size: the mode over the scale, turned for a 90/270 degree transform
// (transforms 1, 3, 5, 7).
function logicalSize(m) {
  var s = m.scale > 0 ? m.scale : 1
  var w = Math.round(m.width / s), h = Math.round(m.height / s)
  return (m.transform % 2 === 1) ? { w: h, h: w } : { w: w, h: h }
}

function row(o) {
  var sz = logicalSize(o)
  return {
    key: o.key || o.name, name: o.name, label: o.label || o.name, make: o.make || "", model: o.model || "",
    width: o.width, height: o.height, refresh: Math.round((o.refresh || 0) * 100) / 100,
    x: o.x || 0, y: o.y || 0, scale: o.scale || 1, transform: o.transform || 0,
    lw: sz.w, lh: sz.h, internal: !!o.internal, focused: !!o.focused, enabled: o.enabled !== false,
    mirrorOf: o.mirrorOf || "", modes: o.modes || []
  }
}

// hyprmoncfg status --json / the "status" event's monitors.
function fromStatus(status) {
  var list = (status && status.monitors) || []
  return list.map(function (m) {
    return row({ key: m.key, name: m.name, label: m.description, make: m.make, model: m.model, width: m.width, height: m.height,
      refresh: m.refresh_rate, x: m.x, y: m.y, scale: m.scale, transform: m.transform, internal: m.internal,
      focused: m.focused, enabled: m.enabled, mirrorOf: m.mirror_of })
  })
}

// hyprctl monitors all -j, when hyprmoncfg isn't managing the displays.
function fromHypr(list) {
  return (list || []).map(function (m) {
    return row({ name: m.name, label: m.description, make: m.make, model: m.model, width: m.width, height: m.height,
      refresh: m.refreshRate, x: m.x, y: m.y, scale: m.scale, transform: m.transform,
      internal: /^(eDP|LVDS|DSI)/.test(m.name), focused: m.focused, enabled: !m.disabled,
      mirrorOf: m.mirrorOf && m.mirrorOf !== "none" ? m.mirrorOf : "", modes: m.availableModes })
  })
}

// Scale and offset that fit every enabled display's logical rect into a
// w x h canvas with `pad` around, centred.
// A display that mirrors another takes that one's place, so the canvas
// leaves it out (its box would sit exactly under the other's).
function placed(m) { return m.enabled && !m.mirrorOf }

function fit(monitors, w, h, pad) {
  var on = monitors.filter(placed)
  if (!on.length) return { k: 1, ox: 0, oy: 0 }
  var x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity
  on.forEach(function (m) { x0 = Math.min(x0, m.x); y0 = Math.min(y0, m.y); x1 = Math.max(x1, m.x + m.lw); y1 = Math.max(y1, m.y + m.lh) })
  var bw = Math.max(1, x1 - x0), bh = Math.max(1, y1 - y0)
  var k = Math.min((w - pad * 2) / bw, (h - pad * 2) / bh)
  return { k: k, ox: (w - bw * k) / 2 - x0 * k, oy: (h - bh * k) / 2 - y0 * k }
}

function rects(monitors, f) {
  return monitors.filter(placed).map(function (m) {
    return { key: m.key, name: m.name, x: m.x * f.k + f.ox, y: m.y * f.k + f.oy, w: m.lw * f.k, h: m.lh * f.k }
  })
}

function scaleLabel(s) { return Math.round(s * 100) + "%" }

// ---------------------------------------------------------------- editing
// hyprmoncfg's editor_state: `profile.outputs` is the layout being edited
// (the daemon snaps and reflows it in edit_profile, so nothing here does
// geometry rules), `displays` the per-display facts (modes, sharp scales,
// physical size). Rows look like fromStatus's, plus what the editor needs.
function fromEditor(doc) {
  var outs = (doc && doc.profile && doc.profile.outputs) || []
  var meta = {}
  ;((doc && doc.displays) || []).forEach(function (d) { meta[d.key] = d })
  return outs.map(function (o) {
    var d = meta[o.key] || {}
    var r = row({ key: o.key, name: o.name, label: o.description, make: o.make, model: o.model, width: o.width, height: o.height,
      refresh: o.refresh, x: o.x, y: o.y, scale: o.scale, transform: o.transform, internal: d.internal,
      focused: d.focused, enabled: o.enabled, mirrorOf: o.mirror_of, modes: d.available_modes || [] })
    r.mode = o.mode || ""
    r.vrr = o.vrr || 0
    r.bitdepth = o.bitdepth || 8
    r.cm = o.cm || ""
    r.scaleOptions = (d.scale_options || []).map(Number)
    r.physicalWidth = d.physical_width || 0
    return r
  })
}

function parseMode(mode) {
  var m = /^(\d+)x(\d+)@([\d.]+)Hz$/.exec(String(mode || ""))
  return m ? { w: Number(m[1]), h: Number(m[2]), hz: Number(m[3]), res: m[1] + "x" + m[2], mode: mode } : null
}

// Resolutions, most pixels first, each with its refresh rates, fastest first.
function modeGroups(modes) {
  var by = {}, out = []
  ;(modes || []).forEach(function (s) {
    var p = parseMode(s)
    if (!p) return
    if (!by[p.res]) { by[p.res] = { res: p.res, w: p.w, h: p.h, rates: [] }; out.push(by[p.res]) }
    if (!by[p.res].rates.some(function (r) { return r.mode === s })) by[p.res].rates.push({ mode: s, hz: p.hz })
  })
  out.forEach(function (g) { g.rates.sort(function (a, b) { return b.hz - a.hz }) })
  return out.sort(function (a, b) { return b.w * b.h - a.w * a.h || b.w - a.w })
}

// The mode at `res` whose refresh is nearest `hz` ("" if `res` has none).
function modeFor(modes, res, hz) {
  var g = modeGroups(modes).find(function (x) { return x.res === res })
  if (!g) return ""
  var best = g.rates[0]
  g.rates.forEach(function (r) { if (Math.abs(r.hz - hz) < Math.abs(best.hz - hz)) best = r })
  return best.mode
}

function refreshLabel(hz) { return (Math.round(hz * 100) / 100).toString().replace(/\.0+$/, "") + " Hz" }

// hyprmoncfg has no "auto" scale, only the scales that come out sharp on the
// display. Recommend the sharp one nearest the display's density over a
// comfortable one (a laptop sits closer, so it gets a little more), never
// under 1. Without a physical size, 1.
function recommendedScale(d) {
  var opts = (d.scaleOptions || []).filter(function (v) { return v >= 1 })
  if (!d.physicalWidth || !opts.length) return 1
  var ppi = d.width / (d.physicalWidth / 25.4)
  var want = Math.max(1, ppi / (d.internal ? 115 : 110))
  var best = opts[0]
  opts.forEach(function (v) { if (Math.abs(v - want) < Math.abs(best - want)) best = v })
  return best
}

// Hyprland transforms: 0-3 turn by 90 degrees, 4-7 are the same flipped.
function transformOf(rotation, flipped) { return (rotation % 4) + (flipped ? 4 : 0) }
function rotationOf(t) { return (t || 0) % 4 }
function flippedOf(t) { return (t || 0) >= 4 }

// A profile's layout as a string that ignores key order (dirty checks).
function signature(profile) {
  var keys = ["key", "enabled", "mode", "x", "y", "scale", "transform", "mirror_of", "vrr", "bitdepth", "cm"]
  // Workspaces too (Settings › Display › Workspaces), keys sorted at every level.
  function sorted(v) {
    if (Array.isArray(v)) return v.map(sorted)
    if (v && typeof v === "object") { var o = {}; Object.keys(v).sort().forEach(function (k) { o[k] = sorted(v[k]) }); return o }
    return v
  }
  return JSON.stringify([((profile && profile.outputs) || []).map(function (o) {
    return keys.map(function (k) { return o[k] === undefined ? null : o[k] })
  }), sorted((profile && profile.workspaces) || null)])
}

function secondsLeft(deadline, now) {
  var at = Date.parse(deadline)
  return isFinite(at) ? Math.max(0, Math.ceil((at - now) / 1000)) : 0
}

// A preview is Omacale's to confirm only if Omacale started it (its id is in
// the runtime file); hyprmoncfg's own panel confirms its own and the
// "reclaimable" ones, so both never ask about the same preview.
function ownsPreview(pending, id) {
  return !!(pending && id && String(pending.transaction_id || "") === id)
}

function canDisable(rows, key) {
  return rows.some(function (m) { return m.enabled && m.key !== key })
}

// Canvas point (a box's top-left) back to layout coordinates.
function toLayout(x, y, f) {
  return { x: Math.round((x - f.ox) / f.k), y: Math.round((y - f.oy) / f.k) }
}

// Turning mirroring off alone leaves the display on top of the one it
// mirrored, which hyprmoncfg rejects ("layout overlaps"); put it to that
// one's right in the same edit. null when the display mirrors nothing.
// mirrorOf is a key from the editor and a name from status/hyprctl.
function unmirrorAt(rows, key) {
  var m = rows.find(function (r) { return r.key === key })
  if (!m || !m.mirrorOf) return null
  var t = rows.find(function (r) { return r.key === m.mirrorOf || r.name === m.mirrorOf })
  return t ? { x: t.x + t.lw, y: t.y } : null
}

// Settings › Display › "Same brightness on every display": a change made on
// one display goes to every display that reports a brightness. 1 at least,
// so a slider dragged to the end never turns a backlight off.
function brightnessTargets(levels, name, value, linked) {
  var v = Math.max(1, Math.min(100, Math.round(value)))
  var names = linked ? Object.keys(levels || {}) : []
  if (name && names.indexOf(name) < 0) names.push(name)
  var out = {}
  names.forEach(function (n) { out[n] = v })
  return out
}

// --------------------------------------------------------------- profiles
// hyprmoncfg's status `profiles`: the one in use first, then the one it
// recommends for the displays connected now, then by name. `shown` of
// `total` is how many of the profile's displays are connected and on.
function profileRows(status) {
  var list = (status && status.profiles) || []
  return list.map(function (p) {
    return { name: String(p.name || ""), active: !!p.active, recommended: !!p.recommended, fits: !!p.exact_display_match,
      shown: p.connected_enabled_outputs || 0, total: p.output_count || 0 }
  }).sort(function (a, b) {
    return (b.active - a.active) || (b.recommended - a.recommended) || a.name.localeCompare(b.name)
  })
}

function nameTaken(status, name) {
  var n = String(name || "").trim().toLowerCase()
  return !!n && ((status && status.profiles) || []).some(function (p) { return String(p.name || "").toLowerCase() === n })
}

// Automatic switching is off while a profile is pinned (daemon.profile_override).
function autoMode(status) {
  var pinned = String((status && status.daemon && status.daemon.profile_override) || "")
  return { auto: pinned === "", pinned: pinned }
}

// ---------------------------------------------------------------- details
function diagonalInches(wmm, hmm) {
  return wmm > 0 && hmm > 0 ? Math.round(Math.sqrt(wmm * wmm + hmm * hmm) / 25.4 * 10) / 10 : 0
}
function ppi(width, wmm) { return wmm > 0 ? Math.round(width / (wmm / 25.4)) : 0 }

// ------------------------------------------------------- quick display menu
// Extend / Mirror / Only laptop / Only external, as on other desktops'
// display-switch key. Needs a built-in display and at least one other.
function quickParts(rows) {
  var inner = rows.filter(function (r) { return r.internal })[0] || null
  var outer = rows.filter(function (r) { return !r.internal }).sort(function (a, b) { return a.x - b.x })
  return { inner: inner, outer: outer }
}

function quickMode(rows) {
  var p = quickParts(rows || [])
  if (!p.inner || !p.outer.length) return ""
  if (!p.inner.enabled) return "external"
  if (p.inner.mirrorOf) return "mirror"
  if (!p.outer.some(function (r) { return r.enabled })) return "laptop"
  return "extend"
}

// The edit_profile edits that switch to `mode`, in an order where every step
// is a valid layout for hyprmoncfg: whatever stays on is turned on (and
// un-mirrored beside its source, which would otherwise overlap it) before
// anything is turned off.
function quickEdits(rows, mode) {
  var p = quickParts(rows || [])
  if (!p.inner || !p.outer.length) return []
  var first = p.outer[0]
  function on(r) {
    var e = { output_key: r.key, enabled: true, mirror_of: "" }
    var at = unmirrorAt(rows, r.key)
    if (at) { e.x = at.x; e.y = at.y }
    return e
  }
  function off(r) { return { output_key: r.key, enabled: false, mirror_of: "" } }
  if (mode === "extend") {
    // Externals left to right from the first one's place, the laptop last.
    var x = first.x, y = first.y, out = []
    p.outer.concat([p.inner]).forEach(function (r) {
      out.push({ output_key: r.key, enabled: true, mirror_of: "", x: x, y: y })
      x += r.lw
    })
    return out
  }
  if (mode === "mirror")
    return [{ output_key: first.key, enabled: true, mirror_of: "" },
            { output_key: p.inner.key, enabled: true, mirror_of: first.key }]
  if (mode === "laptop") return [on(p.inner)].concat(p.outer.map(off))
  if (mode === "external") return p.outer.map(on).concat([off(p.inner)])
  return []
}

// ------------------------------------------------- turn a screen off for now
// A lit screen is on and not blanked; one may go dark while another stays lit.
function canBlank(rows, blanked, name) {
  var lit = (rows || []).filter(function (r) { return r.enabled && (blanked || []).indexOf(r.name) < 0 })
  return lit.some(function (r) { return r.name === name }) && lit.length >= 2
}

// Names go into Hyprland Lua (dispatch/eval); Omarchy refuses anything but a
// plain connector name too (omarchy-hyprland-monitor-clamshell).
function safeOutput(name) { return /^[A-Za-z0-9._-]+$/.test(String(name || "")) }

// ------------------------------------------------------------- night light
// Minutes since midnight from "HH:MM" or a local ISO time ("…T19:05", as
// the weather fetch gives sunrise/sunset with timezone=auto); -1 if neither.
function clockMinutes(t) {
  var m = /(?:^|T)(\d{1,2}):(\d{2})/.exec(String(t || ""))
  return m ? Number(m[1]) * 60 + Number(m[2]) : -1
}

// Whether the schedule wants the night light on at `now` (minutes since
// midnight): true / false, or null when it has no say (schedule off, times
// unknown, or an empty window). from..to may run over midnight.
function nightWanted(now, schedule, from, to, sunset, sunrise) {
  var a, b
  if (schedule === "custom") { a = clockMinutes(from); b = clockMinutes(to) }
  else if (schedule === "sun") { a = clockMinutes(sunset); b = clockMinutes(sunrise) }
  else return null
  if (a < 0 || b < 0 || a === b) return null
  return a < b ? (now >= a && now < b) : (now >= a || now < b)
}

// The temperature slider: 2500 K (warmest) to 6000 K, 100 K steps.
function kelvinAt(pos) { return Math.round((2500 + Math.max(0, Math.min(1, pos)) * 3500) / 100) * 100 }
function kelvinPos(k) { return Math.max(0, Math.min(1, (k - 2500) / 3500)) }

// --------------------------------------------------- workspaces per screen
// A profile's `workspaces` (hyprmoncfg): `enabled`, `strategy` (manual /
// sequential / interleave), `max_workspaces`, `group_size`, and `rules`.
// Only rules for plain workspace numbers are Omacale's to edit; the others
// (`f[1]s[false]`, `w[tv1]s[false]`, …) are passed through untouched.
function wsClone(w) { return JSON.parse(JSON.stringify(w || {})) }
function wsNumbered(r) { return /^\d+$/.test(String(r.workspace)) }

function wsStrategy(w) {
  if (!w || !w.enabled) return "off"
  return w.strategy || "manual"
}

// As hyprmoncfg's own panel (Model.js workspaceStrategyChanges /
// manualWorkspaceRulesFromPlan): off only disables; switching to manual with
// no numbered rules of its own starts from the current plan.
function wsStrategyEdit(w, choice, plan) {
  var n = wsClone(w)
  if (choice === "off") { n.enabled = false; return n }
  n.enabled = true
  n.strategy = choice
  n.rules = n.rules || []
  if (choice === "manual" && !n.rules.some(wsNumbered)) {
    ;(plan || []).forEach(function (row) {
      (row.workspaces || []).forEach(function (ws) {
        n.rules.push({ workspace: String(ws), output_key: row.output_key, output_name: row.output_name })
      })
    })
  }
  return n
}

function wsAssigned(w) {
  var out = {}
  ;((w && w.rules) || []).forEach(function (r) { if (wsNumbered(r) && r.output_key) out[String(r.workspace)] = r.output_key })
  return out
}

// One click on workspace `ws`: the next screen in `outputs` ({key, name}),
// then none, then the first again. A rule left with nothing but its number
// is dropped; one with other settings (default, persistent) is kept.
function wsCycle(w, ws, outputs) {
  var n = wsClone(w)
  n.rules = n.rules || []
  var i = n.rules.findIndex(function (r) { return String(r.workspace) === String(ws) })
  var rule = i >= 0 ? n.rules[i] : { workspace: String(ws), output_key: "" }
  var at = outputs.findIndex(function (o) { return o.key === rule.output_key })
  var next = rule.output_key ? outputs[at + 1] : outputs[0]   // past the last one: none
  if (next) { rule.output_key = next.key; rule.output_name = next.name }
  else { rule.output_key = ""; delete rule.output_name }
  var bare = !rule.output_key && Object.keys(rule).every(function (k) { return k === "workspace" || k === "output_key" })
  if (i >= 0 && bare) n.rules.splice(i, 1)
  else if (i >= 0) n.rules[i] = rule
  else if (!bare) n.rules.push(rule)
  return n
}

function wsPlanText(plan) {
  return (plan || []).map(function (r) { return r.output_name + ": " + ((r.workspaces || []).length ? r.workspaces.join(" ") : "–") }).join(" · ")
}
