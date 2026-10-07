// node tests/test-layout.js -- unit tests for core/BarLayout.js.
// BarLayout.js is a QML `.pragma library` file; strip the pragma and run it
// in a vm context so the same file is tested that the shell loads.
const fs = require("fs"), vm = require("vm"), path = require("path"), assert = require("assert")
const src = fs.readFileSync(path.join(__dirname, "../core/BarLayout.js"), "utf8").replace(/^\.pragma.*$/m, "")
const L = {}
vm.runInNewContext(src + "\nthis.L = { SECTIONS, STATUS, ITEMS, defaults, resolve, segments, move, canMove, takeOut, putBack, sectionLabel, isPlugin, pluginOf, flexSection }", L)
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

test("defaults are today's order", () => eq(B.defaults(), { start: ["logo", "workspaces"], center: ["activeWindow"], end: DEF_END }))
test("nothing saved resolves to defaults", () => eq(B.resolve(undefined, []), B.defaults()))
test("empty lists resolve to defaults", () => eq(B.resolve({ start: [], center: [], end: [] }, []), B.defaults()))
test("a saved order is kept", () => {
  const saved = { start: ["logo", "workspaces", "network", "bluetooth"], center: ["clock"], end: ["activeWindow", "plugins", "tray",
    "keepAwake", "update", "recording", "notifications", "lockStatus", "audio", "microphone", "kbLayout", "battery", "power"] }
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
test("move within a section", () => eq(B.move(B.defaults(), "workspaces", -1).start, ["workspaces", "logo"]))
test("move up across into the previous section's end", () => {
  const l = B.move(B.defaults(), "activeWindow", -1)
  eq(l.start, ["logo", "workspaces", "activeWindow"]); eq(l.center, [])
})
test("move down across into the next section's start", () => {
  const l = B.move(B.defaults(), "activeWindow", 1)
  eq(l.center, []); eq(l.end[0], "activeWindow")
})
test("move into an empty section", () => {
  let l = B.move(B.defaults(), "activeWindow", 1)        // center now empty
  l = B.move(l, "workspaces", 1)                           // last of start -> start of center
  eq(l.center, ["workspaces"])
})
test("no move past the very ends", () => {
  eq(B.move(B.defaults(), "logo", -1), B.defaults())
  eq(B.move(B.defaults(), "power", 1), B.defaults())
  assert.strictEqual(B.canMove(B.defaults(), "logo", -1), false)
  assert.strictEqual(B.canMove(B.defaults(), "power", 1), false)
  assert.strictEqual(B.canMove(B.defaults(), "logo", 1), true)
})
test("move does not mutate its input", () => {
  const d = B.defaults(); B.move(d, "workspaces", -1); eq(d, B.defaults())
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
  assert.strictEqual(B.flexSection(B.move(B.defaults(), "activeWindow", -1), true), "start")
  assert.strictEqual(B.flexSection(B.move(B.defaults(), "activeWindow", 1), true), "end")
})
test("a hidden window title takes no space, so the center is centred", () => {
  assert.strictEqual(B.flexSection(B.defaults(), false), "")
})

console.log(failed ? `${failed} failed` : "all passed")
process.exit(failed ? 1 : 0)
