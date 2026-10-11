// node tests/test-display.js -- unit tests for services/DisplayModel.js, the
// pure half of Settings › Display: hyprmoncfg's IPC envelopes and status,
// hyprctl's monitors, and the arrangement canvas geometry. Fixtures in
// tests/fixtures/display come from a real two-display machine (serial scrubbed).
const fs = require("fs"), vm = require("vm"), path = require("path"), assert = require("assert")
const src = fs.readFileSync(path.join(__dirname, "../services/DisplayModel.js"), "utf8").replace(/^\.pragma.*$/m, "")
const ctx = {}
vm.runInNewContext(src + "\nthis.D = { parseEnvelope, request, fromStatus, fromHypr, logicalSize, fit, rects, scaleLabel, fromEditor, modeGroups, modeFor, recommendedScale, transformOf, rotationOf, flippedOf, signature, secondsLeft, ownsPreview, canDisable, toLayout, refreshLabel, unmirrorAt, brightnessTargets, profileRows, nameTaken, autoMode, diagonalInches, ppi, quickMode, quickEdits, canBlank, safeOutput, nightWanted, clockMinutes, kelvinAt, kelvinPos, wsStrategy, wsStrategyEdit, wsAssigned, wsCycle, wsPlanText }", ctx)
const D = ctx.D
const fx = n => JSON.parse(fs.readFileSync(path.join(__dirname, "fixtures/display", n), "utf8"))
let failed = 0
function test(name, fn) {
  try { fn(); console.log("  PASS", name) } catch (e) { failed++; console.log("  FAIL", name, "\n   ", e.message) }
}
const plain = v => JSON.parse(JSON.stringify(v))

test("a response envelope is read", () => {
  const e = D.parseEnvelope('{"type":"response","protocol_version":1,"id":"3","result":{"ok":true}}')
  assert.strictEqual(e.type, "response"); assert.strictEqual(e.id, "3"); assert.strictEqual(e.result.ok, true)
})
test("an event envelope is read", () => {
  const e = D.parseEnvelope('{"type":"event","protocol_version":1,"event":"status","data":{"x":1}}')
  assert.strictEqual(e.event, "status"); assert.strictEqual(e.data.x, 1)
})
test("another protocol version or junk is ignored", () => {
  assert.strictEqual(D.parseEnvelope('{"type":"response","protocol_version":2,"id":"1","result":{}}'), null)
  assert.strictEqual(D.parseEnvelope("not json"), null)
})
test("a request is one line of JSON", () => {
  const line = D.request("7", "status", {})
  assert.ok(line.endsWith("\n")); assert.deepStrictEqual(plain(JSON.parse(line)), { type: "request", protocol_version: 1, id: "7", method: "status", params: {} })
})
test("monitors from hyprmoncfg's status", () => {
  const m = D.fromStatus(fx("status.json"))
  assert.strictEqual(m.length, 2)
  const e = m.find(x => x.name === "eDP-1")
  assert.strictEqual(e.label, "BOE 0x0910"); assert.strictEqual(e.refresh, 144); assert.strictEqual(e.scale, 1.25)
  assert.strictEqual(e.lw, 1536); assert.strictEqual(e.lh, 864); assert.strictEqual(e.internal, true)
})
test("monitors from hyprctl (no hyprmoncfg)", () => {
  const m = D.fromHypr(fx("hyprctl-monitors.json"))
  assert.strictEqual(m.length, 2)
  const h = m.find(x => x.name === "HDMI-A-1")
  assert.strictEqual(h.lw, 1536); assert.strictEqual(h.refresh, 60); assert.strictEqual(h.enabled, true)
  assert.ok(h.modes.length >= 1)
})
test("a turned display swaps its logical width and height", () => {
  assert.deepStrictEqual(plain(D.logicalSize({ width: 1920, height: 1080, scale: 1, transform: 1 })), { w: 1080, h: 1920 })
  assert.deepStrictEqual(plain(D.logicalSize({ width: 1920, height: 1080, scale: 2, transform: 6 })), { w: 960, h: 540 })
})
test("the arrangement fits the canvas, centred", () => {
  const m = D.fromStatus(fx("status.json"))
  const f = D.fit(m, 600, 300, 20)
  const r = D.rects(m, f)
  const minX = Math.min(...r.map(x => x.x)), maxX = Math.max(...r.map(x => x.x + x.w))
  assert.ok(minX >= 20 - 0.5 && maxX <= 580 + 0.5, "inside the padding")
  assert.ok(Math.abs((minX + maxX) / 2 - 300) < 1, "centred")
  const hdmi = r.find(x => x.name === "HDMI-A-1"), edp = r.find(x => x.name === "eDP-1")
  assert.ok(hdmi.x < edp.x, "HDMI is left of the laptop, as configured")
})
test("scale labels", () => {
  assert.strictEqual(D.scaleLabel(1.25), "125%"); assert.strictEqual(D.scaleLabel(1.33333), "133%"); assert.strictEqual(D.scaleLabel(2), "200%")
})

// ---- editing (PR 7)
const ed = () => D.fromEditor(fx("editor.json"))
test("the editor draft has every output with its modes and sharp scales", () => {
  const m = ed()
  assert.strictEqual(m.length, 2)
  const h = m.find(x => x.name === "HDMI-A-1")
  assert.strictEqual(h.key, "iiyama north america|pl2530h|000000000")
  assert.strictEqual(h.mode, "1920x1080@60.00Hz"); assert.strictEqual(h.modes.length, 24)
  assert.ok(h.scaleOptions.indexOf(1.25) >= 0); assert.strictEqual(h.physicalWidth, 540)
  assert.strictEqual(h.lw, 1536); assert.strictEqual(h.internal, false)
  assert.strictEqual(m.find(x => x.name === "eDP-1").internal, true)
})
test("an editor document without displays or outputs gives no rows", () => {
  assert.deepStrictEqual(plain(D.fromEditor(null)), []); assert.deepStrictEqual(plain(D.fromEditor({ profile: {} })), [])
})
test("modes group by resolution, biggest first, fastest refresh first", () => {
  const g = D.modeGroups(["1280x720@60.00Hz", "1920x1080@60.00Hz", "1920x1080@74.97Hz", "1920x1080@60.00Hz", "1600x1200@60.00Hz", "junk"])
  assert.deepStrictEqual(plain(g.map(x => x.res)), ["1920x1080", "1600x1200", "1280x720"])
  assert.deepStrictEqual(plain(g[0].rates.map(r => r.mode)), ["1920x1080@74.97Hz", "1920x1080@60.00Hz"])
  assert.strictEqual(g[0].rates[0].hz, 74.97)
})
test("a new resolution keeps the nearest refresh rate", () => {
  const modes = ["1920x1080@60.00Hz", "1920x1080@50.00Hz", "1280x720@59.94Hz", "1280x720@50.00Hz"]
  assert.strictEqual(D.modeFor(modes, "1280x720", 60), "1280x720@59.94Hz")
  assert.strictEqual(D.modeFor(modes, "1280x720", 50), "1280x720@50.00Hz")
  assert.strictEqual(D.modeFor(modes, "800x600", 60), "")
})
test("refresh labels drop needless decimals", () => {
  assert.strictEqual(D.refreshLabel(60), "60 Hz"); assert.strictEqual(D.refreshLabel(59.94), "59.94 Hz"); assert.strictEqual(D.refreshLabel(144.001), "144 Hz")
})
test("the recommended scale follows pixel density, from the sharp scales", () => {
  const opts = [1, 1.2, 1.25, 1.33333, 1.5, 1.6, 2, 2.4, 2.5, 3]
  assert.strictEqual(D.recommendedScale({ width: 1920, physicalWidth: 340, internal: true, scaleOptions: opts }), 1.25)   // 14" 1080p laptop
  assert.strictEqual(D.recommendedScale({ width: 1920, physicalWidth: 540, internal: false, scaleOptions: opts }), 1)     // 25" 1080p
  assert.strictEqual(D.recommendedScale({ width: 3840, physicalWidth: 597, internal: false, scaleOptions: opts }), 1.5)   // 27" 4K
  assert.strictEqual(D.recommendedScale({ width: 3840, physicalWidth: 345, internal: true, scaleOptions: opts }), 2.5)    // 15.6" 4K laptop
  assert.strictEqual(D.recommendedScale({ width: 1920, physicalWidth: 0, scaleOptions: opts }), 1)                        // size unknown
  assert.strictEqual(D.recommendedScale({ width: 1920, physicalWidth: 340, internal: true, scaleOptions: [] }), 1)
})
test("rotation and flip make a Hyprland transform and back", () => {
  assert.strictEqual(D.transformOf(1, false), 1); assert.strictEqual(D.transformOf(0, true), 4); assert.strictEqual(D.transformOf(3, true), 7)
  assert.strictEqual(D.rotationOf(6), 2); assert.strictEqual(D.flippedOf(6), true); assert.strictEqual(D.flippedOf(3), false)
})
test("the signature changes with a layout field, not with the order of keys", () => {
  const p = fx("editor.json").profile
  const q = JSON.parse(JSON.stringify(p))
  assert.strictEqual(D.signature(p), D.signature(q))
  q.outputs[1].mode = "1920x1080@50.00Hz"
  assert.notStrictEqual(D.signature(p), D.signature(q))
  const r = JSON.parse(JSON.stringify(p)); r.outputs[0] = Object.fromEntries(Object.entries(r.outputs[0]).reverse())
  assert.strictEqual(D.signature(p), D.signature(r))
})
test("seconds left until the daemon's deadline", () => {
  const now = Date.parse("2026-10-08T10:00:00Z")
  assert.strictEqual(D.secondsLeft("2026-10-08T10:00:30Z", now), 30)
  assert.strictEqual(D.secondsLeft("2026-10-08T10:00:00.400Z", now), 1)
  assert.strictEqual(D.secondsLeft("2026-10-08T09:59:00Z", now), 0)
  assert.strictEqual(D.secondsLeft("junk", now), 0)
})
test("only Omacale's own preview is confirmed by Omacale", () => {
  assert.strictEqual(D.ownsPreview({ transaction_id: "t1" }, "t1"), true)
  assert.strictEqual(D.ownsPreview({ transaction_id: "t1", reclaimable: true }, "t2"), false)
  assert.strictEqual(D.ownsPreview({ transaction_id: "t1" }, ""), false)
  assert.strictEqual(D.ownsPreview(null, "t1"), false)
})
test("the last enabled display can't be turned off", () => {
  const m = ed()
  assert.strictEqual(D.canDisable(m, "boe|0x0910"), true)
  m[1].enabled = false
  assert.strictEqual(D.canDisable(m, "boe|0x0910"), false)
})
test("a dragged box lands at layout coordinates", () => {
  const m = ed(), f = D.fit(m, 600, 300, 20)
  const r = D.rects(m, f).find(x => x.name === "eDP-1")
  assert.deepStrictEqual(plain(D.toLayout(r.x, r.y, f)), { x: 4122, y: 0 })
  assert.deepStrictEqual(plain(D.toLayout(r.x + 10 * f.k, r.y - 5 * f.k, f)), { x: 4132, y: -5 })
})

test("a display that mirrors another stays off the arrangement (it would sit under it)", () => {
  const m = ed()
  m[0].mirrorOf = m[1].key; m[0].x = m[1].x; m[0].y = m[1].y
  const r = D.rects(m, D.fit(m, 600, 300, 20))
  assert.deepStrictEqual(plain(r.map(x => x.name)), ["HDMI-A-1"])
})
test("mirroring off puts the display to the right of the one it mirrored", () => {
  const m = ed()
  m[0].mirrorOf = m[1].key; m[0].x = m[1].x; m[0].y = m[1].y
  assert.deepStrictEqual(plain(D.unmirrorAt(m, m[0].key)), { x: 2586 + 1536, y: 0 })
  assert.strictEqual(D.unmirrorAt(m, m[1].key), null)   // not mirroring
})

test("a brightness change goes to its display, or to every display when linked", () => {
  const levels = { "eDP-1": 38, "HDMI-A-1": 60 }
  assert.deepStrictEqual(plain(D.brightnessTargets(levels, "HDMI-A-1", 70.4, false)), { "HDMI-A-1": 70 })
  assert.deepStrictEqual(plain(D.brightnessTargets(levels, "HDMI-A-1", 70.4, true)), { "eDP-1": 70, "HDMI-A-1": 70 })
  assert.deepStrictEqual(plain(D.brightnessTargets(levels, "", 0.2, true)), { "eDP-1": 1, "HDMI-A-1": 1 })   // never fully dark
  assert.deepStrictEqual(plain(D.brightnessTargets({}, "DP-2", 50, true)), { "DP-2": 50 })                   // levels not read yet
})

// ---- profiles and details (PR 8)
const st = {
  daemon: { running: true },
  profiles: [
    { name: "last", output_count: 2, connected_enabled_outputs: 2, exact_display_match: true, active: false, recommended: true },
    { name: "llll", output_count: 1, connected_enabled_outputs: 1, exact_display_match: false, active: false, recommended: false },
    { name: "sss", output_count: 2, connected_enabled_outputs: 2, exact_display_match: true, active: true, recommended: false }
  ]
}
test("profiles: the active one first, then recommended, then by name", () => {
  const r = D.profileRows(st)
  assert.deepStrictEqual(plain(r.map(x => x.name)), ["sss", "last", "llll"])
  assert.deepStrictEqual(plain(r[0]), { name: "sss", active: true, recommended: false, fits: true, shown: 2, total: 2 })
  assert.strictEqual(r[2].fits, false)
  assert.deepStrictEqual(plain(D.profileRows(null)), [])
})
test("a profile name is taken regardless of case and spaces around it", () => {
  assert.strictEqual(D.nameTaken(st, " SSS "), true); assert.strictEqual(D.nameTaken(st, "work"), false); assert.strictEqual(D.nameTaken(st, ""), false)
})
test("automatic switching is on unless a profile is pinned", () => {
  assert.deepStrictEqual(plain(D.autoMode(st)), { auto: true, pinned: "" })
  assert.deepStrictEqual(plain(D.autoMode({ daemon: { profile_override: "llll" } })), { auto: false, pinned: "llll" })
  assert.deepStrictEqual(plain(D.autoMode(null)), { auto: true, pinned: "" })
})
test("physical size as a diagonal in inches, and pixel density", () => {
  assert.strictEqual(D.diagonalInches(340, 190), 15.3)
  assert.strictEqual(D.diagonalInches(540, 300), 24.3)
  assert.strictEqual(D.diagonalInches(0, 0), 0)
  assert.strictEqual(D.ppi(1920, 340), 143); assert.strictEqual(D.ppi(1920, 0), 0)
})

// ---- quick display menu (PR 9)
const two = () => {
  const m = ed()                         // eDP-1 (internal) right of HDMI-A-1, both on
  return m
}
const byKey = (edits, key) => edits.find(e => e.output_key === key)
test("the current mode is read from the layout", () => {
  const m = two()
  assert.strictEqual(D.quickMode(m), "extend")
  m[0].mirrorOf = m[1].key; assert.strictEqual(D.quickMode(m), "mirror")
  const a = two(); a[1].enabled = false; assert.strictEqual(D.quickMode(a), "laptop")
  const b = two(); b[0].enabled = false; assert.strictEqual(D.quickMode(b), "external")
  assert.strictEqual(D.quickMode([two()[0]]), "")          // a laptop alone: nothing to choose
})
test("extend turns everything on, unmirrored, side by side with the laptop last", () => {
  const m = two(); m[0].mirrorOf = m[1].key; m[0].x = m[1].x; m[0].y = m[1].y
  const e = D.quickEdits(m, "extend")
  assert.deepStrictEqual(plain(byKey(e, m[1].key)), { output_key: m[1].key, enabled: true, mirror_of: "", x: 2586, y: 0 })
  assert.deepStrictEqual(plain(byKey(e, m[0].key)), { output_key: m[0].key, enabled: true, mirror_of: "", x: 2586 + 1536, y: 0 })
})
test("mirror shows the first external display on the laptop", () => {
  const e = D.quickEdits(two(), "mirror")
  const m = two()
  assert.deepStrictEqual(plain(byKey(e, m[0].key)), { output_key: m[0].key, enabled: true, mirror_of: m[1].key })
  assert.deepStrictEqual(plain(byKey(e, m[1].key)), { output_key: m[1].key, enabled: true, mirror_of: "" })
})
test("only the laptop / only the external turn the others off, never all", () => {
  const m = two()
  const l = D.quickEdits(m, "laptop"), x = D.quickEdits(m, "external")
  assert.strictEqual(byKey(l, m[1].key).enabled, false); assert.strictEqual(byKey(l, m[0].key).enabled, true)
  assert.strictEqual(byKey(x, m[0].key).enabled, false); assert.strictEqual(byKey(x, m[1].key).enabled, true)
  // the turned-on one goes first, so no edit ever leaves zero displays on
  assert.strictEqual(l[0].enabled, true); assert.strictEqual(x[0].enabled, true)
  assert.deepStrictEqual(plain(D.quickEdits([m[0]], "external")), [])
})

// ---- turn a screen off for now (PR 10)
test("a screen can be turned off while another stays lit", () => {
  const m = ed()
  assert.strictEqual(D.canBlank(m, [], "eDP-1"), true)
  assert.strictEqual(D.canBlank(m, ["HDMI-A-1"], "eDP-1"), false)   // it would be the last one lit
  assert.strictEqual(D.canBlank(m, ["eDP-1"], "eDP-1"), false)      // already off
  const d = ed(); d[1].enabled = false
  assert.strictEqual(D.canBlank(d, [], "eDP-1"), false)              // the other is disabled
  assert.strictEqual(D.canBlank(d, [], "HDMI-A-1"), false)           // a disabled one isn't lit
})
test("only plain connector names reach a Hyprland command", () => {
  assert.strictEqual(D.safeOutput("eDP-1"), true); assert.strictEqual(D.safeOutput("HDMI-A-1"), true)
  assert.strictEqual(D.safeOutput('x" }) os.execute("rm'), false); assert.strictEqual(D.safeOutput(""), false)
})

// ---- night light (PR 11)
test("clock minutes from HH:MM or a local ISO time", () => {
  assert.strictEqual(D.clockMinutes("20:30"), 1230); assert.strictEqual(D.clockMinutes("2026-10-08T07:12"), 432)
  assert.strictEqual(D.clockMinutes("junk"), -1); assert.strictEqual(D.clockMinutes(""), -1)
})
test("a custom schedule, including one over midnight", () => {
  assert.strictEqual(D.nightWanted(21 * 60, "custom", "20:00", "07:00", "", ""), true)
  assert.strictEqual(D.nightWanted(3 * 60, "custom", "20:00", "07:00", "", ""), true)
  assert.strictEqual(D.nightWanted(12 * 60, "custom", "20:00", "07:00", "", ""), false)
  assert.strictEqual(D.nightWanted(7 * 60, "custom", "20:00", "07:00", "", ""), false)     // ends at 07:00
  assert.strictEqual(D.nightWanted(14 * 60, "custom", "13:00", "15:00", "", ""), true)     // same-day window
  assert.strictEqual(D.nightWanted(14 * 60, "custom", "13:00", "13:00", "", ""), null)     // empty window: no opinion
})
test("sunset to sunrise follows the weather's times, or has no opinion without them", () => {
  assert.strictEqual(D.nightWanted(19 * 60 + 30, "sun", "", "", "2026-10-08T19:05", "2026-10-08T07:40"), true)
  assert.strictEqual(D.nightWanted(10 * 60, "sun", "", "", "2026-10-08T19:05", "2026-10-08T07:40"), false)
  assert.strictEqual(D.nightWanted(10 * 60, "sun", "", "", "", ""), null)
  assert.strictEqual(D.nightWanted(10 * 60, "off", "20:00", "07:00", "", ""), null)
})
test("temperature slider: 2500 K warm end to 6000 K, in 100 K steps", () => {
  assert.strictEqual(D.kelvinAt(0), 2500); assert.strictEqual(D.kelvinAt(1), 6000); assert.strictEqual(D.kelvinAt(0.43), 4000)
  assert.strictEqual(D.kelvinPos(4000), 1500 / 3500); assert.strictEqual(D.kelvinPos(9000), 1)
})

// ---- workspaces per screen (PR 12)
const E = "boe|0x0910", H = "iiyama|pl2530h|0"
const outs = [{ key: E, name: "eDP-1" }, { key: H, name: "HDMI-A-1" }]
const ws = () => ({ enabled: true, strategy: "manual", max_workspaces: 9, group_size: 3, rules: [
  { workspace: "1", output_key: "" },
  { workspace: "4", output_key: E, output_name: "eDP-1", default: true, persistent: true },
  { workspace: "5", output_key: E, output_name: "eDP-1" },
  { workspace: "f[1]s[false]", output_key: "" }
] })
test("the strategy, with disabled meaning off", () => {
  assert.strictEqual(D.wsStrategy(ws()), "manual")
  assert.strictEqual(D.wsStrategy(Object.assign(ws(), { enabled: false })), "off")
  assert.strictEqual(D.wsStrategy({ enabled: true }), "manual")
  assert.strictEqual(D.wsStrategy(null), "off")
})
test("changing the strategy keeps everything else", () => {
  const off = D.wsStrategyEdit(ws(), "off", [])
  assert.strictEqual(off.enabled, false); assert.strictEqual(off.rules.length, 4)
  const seq = D.wsStrategyEdit(Object.assign(ws(), { enabled: false }), "sequential", [])
  assert.strictEqual(seq.enabled, true); assert.strictEqual(seq.strategy, "sequential"); assert.strictEqual(seq.group_size, 3)
})
test("manual from another strategy starts from the plan when it has no rules of its own", () => {
  const plan = [{ output_key: E, output_name: "eDP-1", workspaces: ["1", "2"] }, { output_key: H, output_name: "HDMI-A-1", workspaces: ["3"] }]
  const m = D.wsStrategyEdit({ enabled: true, strategy: "sequential", rules: [{ workspace: "w[tv1]", output_key: "" }] }, "manual", plan)
  assert.deepStrictEqual(plain(D.wsAssigned(m)), { "1": E, "2": E, "3": H })
  assert.ok(m.rules.some(r => r.workspace === "w[tv1]"), "special rules stay")
})
test("which screen each numbered workspace is on", () => {
  assert.deepStrictEqual(plain(D.wsAssigned(ws())), { "4": E, "5": E })
})
test("a click moves a workspace to the next screen, then to none, keeping its other settings and the special rules", () => {
  let w = D.wsCycle(ws(), "4", outs)                       // eDP-1 -> HDMI-A-1
  let r4 = w.rules.find(r => r.workspace === "4")
  assert.strictEqual(r4.output_key, H); assert.strictEqual(r4.output_name, "HDMI-A-1"); assert.strictEqual(r4.default, true)
  w = D.wsCycle(w, "4", outs)                              // HDMI-A-1 -> none (kept: it has default/persistent)
  r4 = w.rules.find(r => r.workspace === "4")
  assert.strictEqual(r4.output_key, ""); assert.strictEqual(r4.output_name, undefined)
  w = D.wsCycle(w, "4", outs)                              // none -> eDP-1
  assert.strictEqual(w.rules.find(r => r.workspace === "4").output_key, E)
  w = D.wsCycle(ws(), "7", outs)                           // a new one gets a rule
  assert.strictEqual(w.rules.find(r => r.workspace === "7").output_key, E)
  w = D.wsCycle(D.wsCycle(w, "7", outs), "7", outs)        // ...and loses it again at none (nothing else on it)
  assert.strictEqual(w.rules.find(r => r.workspace === "7"), undefined)
  assert.ok(w.rules.some(r => r.workspace === "f[1]s[false]"))
  assert.strictEqual(ws().rules.find(r => r.workspace === "4").output_key, E, "the input isn't changed")
})
test("the plan as text", () => {
  assert.strictEqual(D.wsPlanText([{ output_name: "eDP-1", workspaces: ["4", "5"] }, { output_name: "HDMI-A-1", workspaces: [] }]), "eDP-1: 4 5 · HDMI-A-1: –")
})

test("a workspace change counts as a change too (any key order)", () => {
  const p = fx("editor.json").profile
  p.workspaces = { enabled: true, strategy: "manual", rules: [{ workspace: "6", output_key: "a" }] }
  const q = JSON.parse(JSON.stringify(p)); q.workspaces.rules[0].output_key = "b"
  assert.notStrictEqual(D.signature(p), D.signature(q))
  const r = JSON.parse(JSON.stringify(p)); r.workspaces = { rules: p.workspaces.rules, strategy: "manual", enabled: true }
  assert.strictEqual(D.signature(p), D.signature(r))
})

console.log(failed ? `${failed} failed` : "all passed")
process.exit(failed ? 1 : 0)
