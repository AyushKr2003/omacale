// node tests/test-layout.js -- unit tests for core/BarLayout.js.
// BarLayout.js is a QML `.pragma library` file; strip the pragma and run it
// in a vm context so the same file is tested that the shell loads.
const fs = require("fs"), vm = require("vm"), path = require("path"), assert = require("assert")
const src = fs.readFileSync(path.join(__dirname, "../core/BarLayout.js"), "utf8").replace(/^\.pragma.*$/m, "")
const L = {}
vm.runInNewContext(src + "\nthis.L = { SECTIONS, STATUS, ITEMS, defaults, resolve, segments, place, takeOut, putBack, sectionLabel, isPlugin, pluginOf, flexSection, adoptNew, appendEnd, sourceOf, render, foldable, joinable, groups, DUPLICATES, NEVER }", L)
const B = L.L
let failed = 0
function test(name, fn) {
  try { fn(); console.log("  PASS", name) } catch (e) { failed++; console.log("  FAIL", name, "\n   ", e.message) }
}
// Values made inside the vm context have its own Array prototype: compare plain copies.
const plain = v => JSON.parse(JSON.stringify(v))
const eq = (a, b) => assert.deepStrictEqual(plain(a), plain(b))
const DEF_END = ["overflow", "plugins", "tray", "clock", "keepAwake", "update", "recording", "notifications", "lockStatus",
  "audio", "microphone", "kbLayout", "network", "bluetooth", "battery", "power"]

test("defaults are today's order", () => eq(B.defaults(), { start: ["logo", "workspaces"], center: ["activeWindow"], end: DEF_END, removed: [], drawer: [] }))
test("nothing saved resolves to defaults", () => eq(B.resolve(undefined, []), B.defaults()))
test("empty lists resolve to defaults", () => eq(B.resolve({ start: [], center: [], end: [] }, []), B.defaults()))
test("a saved order is kept", () => {
  const saved = { start: ["logo", "workspaces", "network", "bluetooth"], center: ["clock"], end: ["overflow", "activeWindow", "plugins", "tray",
    "keepAwake", "update", "recording", "notifications", "lockStatus", "audio", "microphone", "kbLayout", "battery", "power"], removed: [], drawer: [] }
  eq(B.resolve(saved, []), saved)
})
test("unknown ids and junk are dropped", () => {
  const r = B.resolve({ start: ["logo", "nope", 3, null, "workspaces"], center: "activeWindow", end: DEF_END }, [])
  eq(r, B.defaults())
})
test("duplicates keep the first place", () => {
  const r = B.resolve({ start: ["clock", "logo", "workspaces"], center: ["activeWindow"], end: DEF_END }, [])
  eq(r.start, ["clock", "logo", "workspaces"])
  assert.ok(r.end.indexOf("clock") < 0)
})
test("a missing built-in returns after its default predecessor", () => {
  const end = DEF_END.filter(i => i !== "network")
  const r = B.resolve({ start: ["logo", "workspaces"], center: ["activeWindow"], end }, [])
  eq(r.end, DEF_END)
})
test("a missing built-in with no predecessor present goes first", () => {
  const r = B.resolve({ start: ["workspaces"], center: ["activeWindow"], end: DEF_END }, [])
  eq(r.start, ["logo", "workspaces"])
})
test("plugin entries are kept only for enabled widgets", () => {
  const saved = { start: ["logo", "workspaces", "plugin:a.b"], center: ["activeWindow"], end: DEF_END.concat(["plugin:gone"]) }
  const r = B.resolve(saved, ["a.b", "c.d"])
  eq(r.start, ["logo", "workspaces", "plugin:a.b"])
  eq(r.end, DEF_END)
})
test("segments group adjacent status icons", () => {
  eq(B.segments(["clock", "network", "bluetooth", "power", "battery"]), [
    { kind: "item", id: "clock" },
    { kind: "status", id: "status:network,bluetooth", ids: ["network", "bluetooth"] },
    { kind: "item", id: "power" },
    { kind: "status", id: "status:battery", ids: ["battery"] }])
})
test("segments: a plugin entry splits a run", () => {
  eq(B.segments(["network", "plugin:x.y", "battery"]), [
    { kind: "status", id: "status:network", ids: ["network"] },
    { kind: "plugin", id: "plugin:x.y", pluginId: "x.y" },
    { kind: "status", id: "status:battery", ids: ["battery"] }])
})
test("takeOut puts the widget right after the plugin group", () => {
  const l = B.takeOut(B.defaults(), "x.y")
  eq(l.end.slice(1, 3), ["plugins", "plugin:x.y"])
  eq(B.takeOut(l, "x.y"), l)                               // twice is a no-op
})
test("putBack removes the widget entry", () => eq(B.putBack(B.takeOut(B.defaults(), "x.y"), "x.y"), B.defaults()))
test("section labels follow the bar edge", () => {
  assert.strictEqual(B.sectionLabel("start", true), "Top")
  assert.strictEqual(B.sectionLabel("center", true), "Middle")
  assert.strictEqual(B.sectionLabel("end", false), "Right")
})
test("every catalogue item has a section, label and icon", () => {
  for (const id in B.ITEMS) { const it = B.ITEMS[id]; assert.ok(it.section && it.label && it.icon, id) }
})

test("the shown window title's section takes the free space", () => {
  assert.strictEqual(B.flexSection(B.defaults(), true), "center")
  assert.strictEqual(B.flexSection(B.place(B.defaults(), "activeWindow", "start", 0), true), "start")
  assert.strictEqual(B.flexSection(B.place(B.defaults(), "activeWindow", "end", 0), true), "end")
})
test("a hidden window title takes no space, so the center is centred", () => {
  assert.strictEqual(B.flexSection(B.defaults(), false), "")
})

test("place moves within a section", () => eq(B.place(B.defaults(), "workspaces", "start", 0).start, ["workspaces", "logo"]))
test("place moves into another section at an index", () => {
  const l = B.place(B.defaults(), "clock", "center", 0)
  eq(l.center, ["clock", "activeWindow"]); assert.ok(l.end.indexOf("clock") < 0)
})
test("place clamps the index to the section", () => eq(B.place(B.defaults(), "logo", "end", 99).end.slice(-1), ["logo"]))
test("place into removed takes the item off the bar", () => {
  const l = B.place(B.defaults(), "battery", "removed", 0)
  assert.ok(l.end.indexOf("battery") < 0); eq(l.removed, ["battery"])
})
test("place out of removed adds it back", () => {
  const l = B.place(B.place(B.defaults(), "battery", "removed", 0), "battery", "start", 1)
  eq(l.start, ["logo", "battery", "workspaces"]); eq(l.removed, [])
})
test("a plugin entry placed into removed goes back to its group", () => {
  const l = B.place(B.takeOut(B.defaults(), "x.y"), "plugin:x.y", "removed", 0)
  eq(l, B.defaults())
})
test("place does not mutate its input", () => { const d = B.defaults(); B.place(d, "logo", "end", 0); eq(d, B.defaults()) })
test("removed items stay off the bar when the layout is repaired", () => {
  const r = B.resolve({ start: ["logo", "workspaces"], center: ["activeWindow"], end: DEF_END.filter(i => i !== "battery"), removed: ["battery"] }, [])
  assert.ok(r.end.indexOf("battery") < 0); eq(r.removed, ["battery"])
})
test("removed keeps known built-ins and enabled widgets not also on the bar", () => {
  const r = B.resolve({ start: ["logo", "workspaces"], center: ["activeWindow"], end: DEF_END, removed: ["clock", "nope", "plugin:a.b", "plugin:gone", 5, "battery"] }, ["a.b"])
  eq(r.removed, ["plugin:a.b"]); eq(r.end, DEF_END)
})
test("a removed widget is kept while the widget list is unknown", () => {
  eq(B.resolve({ removed: ["plugin:omarchy.agents"] }, null).removed, ["plugin:omarchy.agents"])
})
test("a widget that isn't in the pill goes into removed", () => {
  const l = B.place(B.place(B.defaults(), "plugin:omarchy.agents", "end", 99, []), "plugin:omarchy.agents", "removed", 0, ["x.y"])
  eq(l.removed, ["plugin:omarchy.agents"]); eq(l.end, DEF_END)
})
test("a pill widget placed into removed goes back to the pill", () => {
  eq(B.place(B.takeOut(B.defaults(), "x.y"), "plugin:x.y", "removed", 0, ["x.y"]), B.defaults())
})

// ---- adoption: widgets Omarchy offers show up by themselves
const W = (id, fp) => ({ id, firstParty: fp })
const OMARCHY = [W("omarchy.agents", true), W("omarchy.weather", true), W("omarchy.audio", true),
  W("omarchy.spacer", true), W("omarchy.tailscale", true), W("omaplug", false)]
test("first adoption places only Omarchy-only widgets from Omarchy's own bar", () => {
  const r = B.adoptNew(B.defaults(), OMARCHY, [], true, ["omarchy.agents", "omarchy.audio", "omarchy.spacer", "omaplug"])
  eq(r.layout.end, DEF_END.slice(0, -1).concat(["plugin:omarchy.agents", "power"]))
  eq(r.seen, OMARCHY.map(w => w.id)); assert.ok(r.changed)
})
test("a new Omarchy widget goes at the end of the end section, before power", () => {
  const r = B.adoptNew(B.defaults(), [W("omarchy.agents", true), W("omarchy.new", true)], ["omarchy.agents"], false, [])
  eq(r.layout.end.slice(-2), ["plugin:omarchy.new", "power"]); eq(r.seen, ["omarchy.agents", "omarchy.new"])
  const moved = B.place(B.defaults(), "power", "start", 0)
  eq(B.adoptNew(moved, [W("omarchy.new", true)], [], false, []).layout.end.slice(-1), ["plugin:omarchy.new"])
})
test("duplicates, never-widgets and third-party widgets are only marked seen", () => {
  const r = B.adoptNew(B.defaults(), [W("omarchy.audio", true), W("omarchy.spacer", true), W("omaplug", false)], [], false, [])
  eq(r.layout, B.defaults()); eq(r.seen, ["omarchy.audio", "omarchy.spacer", "omaplug"]); assert.ok(r.changed)
})
test("nothing new is no change", () => {
  const r = B.adoptNew(B.defaults(), [W("omarchy.agents", true)], ["omarchy.agents"], false, [])
  assert.ok(!r.changed); eq(r.layout, B.defaults())
})
test("a widget already placed or removed is not placed again", () => {
  const l = B.place(B.defaults(), "plugin:omarchy.agents", "removed", 0, [])
  eq(B.adoptNew(l, [W("omarchy.agents", true)], [], false, []).layout, l)
  const m = B.place(B.defaults(), "plugin:omarchy.weather", "start", 0, [])
  eq(B.adoptNew(m, [W("omarchy.weather", true)], [], false, []).layout, m)
})
test("adoption does not mutate its input", () => {
  const d = B.defaults(), seen = []
  B.adoptNew(d, [W("omarchy.agents", true)], seen, false, []); eq(d, B.defaults()); eq(seen, [])
})
test("every duplicate points at a built-in or nothing", () => {
  for (const id in B.DUPLICATES) assert.ok(B.DUPLICATES[id] === "" || B.ITEMS[B.DUPLICATES[id]], id)
})
test("appendEnd keeps power last, and moves an item already on the bar", () => {
  eq(B.appendEnd(B.defaults(), "plugin:x.y").end.slice(-2), ["plugin:x.y", "power"])
  eq(B.appendEnd(B.defaults(), "clock").end.slice(-2), ["clock", "power"])
  const noPower = B.place(B.defaults(), "power", "removed", 0)
  eq(B.appendEnd(noPower, "plugin:x.y").end.slice(-1), ["plugin:x.y"])
})
test("sourceOf tells built-ins, Omarchy widgets and plugins apart", () => {
  assert.strictEqual(B.sourceOf("clock", []), "omacale")
  assert.strictEqual(B.sourceOf("plugin:omarchy.agents", ["omarchy.agents"]), "omarchy")
  assert.strictEqual(B.sourceOf("plugin:omaplug", ["omarchy.agents"]), "plugin")
})
test("removing the window title leaves no flexible section", () => {
  assert.strictEqual(B.flexSection(B.place(B.defaults(), "activeWindow", "removed", 0), true), "")
})

test("plugin entries are all kept while the widget list is unknown", () => {
  const saved = { start: ["logo", "workspaces", "plugin:a.b"], center: ["activeWindow"], end: DEF_END, removed: [] }
  eq(B.resolve(saved, null).start, ["logo", "workspaces", "plugin:a.b"])
})

// ---- behind the chevron
test("the drawer keeps its items off the sections and drops the chevron", () => {
  const r = B.resolve({ end: DEF_END.filter(i => i !== "network"), drawer: ["network", "overflow", "nope", "network", "plugin:a.b"] }, ["a.b"])
  eq(r.drawer, ["network", "plugin:a.b"]); assert.ok(r.end.indexOf("network") < 0); assert.ok(r.end.indexOf("overflow") >= 0)
})
test("an item on the bar is not also in the drawer", () => {
  eq(B.resolve({ end: DEF_END, drawer: ["network"] }, []).drawer, [])
})
test("place moves items into and out of the drawer, never the chevron", () => {
  const l = B.place(B.defaults(), "battery", "drawer", 0)
  eq(l.drawer, ["battery"]); assert.ok(l.end.indexOf("battery") < 0)
  eq(B.place(l, "battery", "end", 3).drawer, [])
  eq(B.place(B.defaults(), "overflow", "drawer", 0), B.defaults())
})
const ids = sec => sec.map(x => x.id + (x.drawer ? "*" : ""))
test("render puts the drawer next to the chevron, before it in the end section", () => {
  const l = B.place(B.place(B.defaults(), "battery", "drawer", 0), "keepAwake", "drawer", 1)
  const r = B.render(l, 0, null)
  eq(ids(r.end).slice(0, 4), ["battery*", "keepAwake*", "overflow", "plugins"])
  eq(ids(r.start), ["logo", "workspaces"])
  const st = B.render(B.place(l, "overflow", "start", 0), 0, null)
  eq(ids(st.start).slice(0, 3), ["overflow", "battery*", "keepAwake*"])
})
test("render folds shown icons past the limit, keeping the clock and power", () => {
  const r = B.render(B.defaults(), 3, id => id !== "recording")
  const folded = r.end.filter(x => x.drawer).map(x => x.id)
  eq(folded, ["update", "notifications", "lockStatus", "audio", "microphone", "kbLayout", "network", "bluetooth", "battery"])
  eq(r.end.filter(x => !x.drawer)[0].id, "overflow"); assert.ok(r.end.find(x => x.id === "clock" && !x.drawer)); assert.ok(r.end.find(x => x.id === "power" && !x.drawer))
})
test("without the chevron on the bar the drawer isn't drawn", () => {
  const l = B.place(B.place(B.defaults(), "battery", "drawer", 0), "overflow", "removed", 0)
  assert.ok(!B.render(l, 0, null).end.some(x => x.id === "battery"))
})
test("segments: a drawer item never shares a run with one on the bar", () => {
  eq(B.segments([{ id: "network", drawer: true }, { id: "bluetooth", drawer: true }, { id: "battery", drawer: false }]), [
    { kind: "status", id: "status:network,bluetooth", ids: ["network", "bluetooth"], drawer: true },
    { kind: "status", id: "status:battery", ids: ["battery"] }])
})
test("adoption leaves a widget in the drawer there", () => {
  const l = B.place(B.defaults(), "plugin:omarchy.agents", "drawer", 0, [])
  eq(B.adoptNew(l, [W("omarchy.agents", true)], [], false, []).layout, l)
})

test("groups: neighbouring joinable items form one pill group", () => {
  eq(B.groups(["clock", "overflow", "network", "plugin:a.b", "power", "workspaces", "tray"]), [
    { pill: false, ids: ["clock"] },
    { pill: true, ids: ["overflow", "network", "plugin:a.b", "power"] },
    { pill: false, ids: ["workspaces"] },
    { pill: true, ids: ["tray"] }])
  eq(B.groups([]), [])
})

console.log(failed ? `${failed} failed` : "all passed")
process.exit(failed ? 1 : 0)
