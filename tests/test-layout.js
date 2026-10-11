// node tests/test-layout.js -- unit tests for core/BarLayout.js.
// BarLayout.js is a QML `.pragma library` file; strip the pragma and run it
// in a vm context so the same file is tested that the shell loads.
const fs = require("fs"), vm = require("vm"), path = require("path"), assert = require("assert")
const src = fs.readFileSync(path.join(__dirname, "../core/BarLayout.js"), "utf8").replace(/^\.pragma.*$/m, "")
const L = {}
vm.runInNewContext(src + "\nthis.L = { SECTIONS, STATUS, ITEMS, defaults, resolve, segments, place, takeOut, putBack, sectionLabel, isPlugin, pluginOf, flexSection }", L)
const B = L.L
let failed = 0
function test(name, fn) {
  try { fn(); console.log("  PASS", name) } catch (e) { failed++; console.log("  FAIL", name, "\n   ", e.message) }
}
// Values made inside the vm context have its own Array prototype: compare plain copies.
const plain = v => JSON.parse(JSON.stringify(v))
const eq = (a, b) => assert.deepStrictEqual(plain(a), plain(b))
const DEF_END = ["plugins", "tray", "clock", "keepAwake", "update", "recording", "notifications", "lockStatus",
  "audio", "microphone", "kbLayout", "network", "bluetooth", "battery", "power"]

test("defaults are today's order", () => eq(B.defaults(), { start: ["logo", "workspaces"], center: ["activeWindow"], end: DEF_END, removed: [] }))
test("nothing saved resolves to defaults", () => eq(B.resolve(undefined, []), B.defaults()))
test("empty lists resolve to defaults", () => eq(B.resolve({ start: [], center: [], end: [] }, []), B.defaults()))
test("a saved order is kept", () => {
  const saved = { start: ["logo", "workspaces", "network", "bluetooth"], center: ["clock"], end: ["activeWindow", "plugins", "tray",
    "keepAwake", "update", "recording", "notifications", "lockStatus", "audio", "microphone", "kbLayout", "battery", "power"], removed: [] }
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
  eq(l.end.slice(0, 2), ["plugins", "plugin:x.y"])
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
test("removed keeps only known built-ins not also on the bar", () => {
  const r = B.resolve({ start: ["logo", "workspaces"], center: ["activeWindow"], end: DEF_END, removed: ["clock", "nope", "plugin:a.b", 5, "battery"] }, ["a.b"])
  eq(r.removed, []); eq(r.end, DEF_END)
})
test("removing the window title leaves no flexible section", () => {
  assert.strictEqual(B.flexSection(B.place(B.defaults(), "activeWindow", "removed", 0), true), "")
})

test("plugin entries are all kept while the widget list is unknown", () => {
  const saved = { start: ["logo", "workspaces", "plugin:a.b"], center: ["activeWindow"], end: DEF_END, removed: [] }
  eq(B.resolve(saved, null).start, ["logo", "workspaces", "plugin:a.b"])
})

console.log(failed ? `${failed} failed` : "all passed")
process.exit(failed ? 1 : 0)
