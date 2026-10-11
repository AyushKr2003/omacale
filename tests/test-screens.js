// node tests/test-screens.js -- unit tests for core/Screens.js: which screens
// get the bar, desktop widgets, toasts and OSD, and each bar's edge.
const fs = require("fs"), vm = require("vm"), path = require("path"), assert = require("assert")
const src = fs.readFileSync(path.join(__dirname, "../core/Screens.js"), "utf8").replace(/^\.pragma.*$/m, "")
const ctx = {}
vm.runInNewContext(src + "\nthis.S = { edgeFor, barOn, shownOn, targetFor, barScreen, positionsFrom, positionsWith }", ctx)
const S = ctx.S
let failed = 0
function test(name, fn) {
  try { fn(); console.log("  PASS", name) } catch (e) { failed++; console.log("  FAIL", name, "\n   ", e.message) }
}
const both = ["eDP-1", "HDMI-A-1"]

test("a screen's own edge wins", () => assert.strictEqual(S.edgeFor("HDMI-A-1", { "HDMI-A-1": "top" }, "left"), "top"))
test("otherwise the bar's setting", () => assert.strictEqual(S.edgeFor("eDP-1", { "HDMI-A-1": "top" }, "left"), "left"))
test("a junk edge falls back", () => assert.strictEqual(S.edgeFor("eDP-1", { "eDP-1": "middle" }, "left"), "left"))
test("an excluded screen has no bar", () => assert.strictEqual(S.barOn("HDMI-A-1", ["HDMI-A-1"], both), false))
test("other screens keep theirs", () => assert.strictEqual(S.barOn("eDP-1", ["HDMI-A-1"], both), true))
test("excluding every screen keeps the first one's bar", () => {
  assert.strictEqual(S.barOn("eDP-1", both, both), true)
  assert.strictEqual(S.barOn("HDMI-A-1", both, both), false)
})
test("an unplugged excluded screen doesn't count", () => assert.strictEqual(S.barOn("eDP-1", ["eDP-1", "DP-9"], ["eDP-1"]), true))
test("desktop widgets follow their own exclusions", () => {
  assert.strictEqual(S.shownOn("eDP-1", ["eDP-1"]), false)
  assert.strictEqual(S.shownOn("HDMI-A-1", ["eDP-1"]), true)
})
test("toasts/OSD target: all, focused or one screen", () => {
  assert.strictEqual(S.targetFor("eDP-1", "all", "HDMI-A-1", both), true)
  assert.strictEqual(S.targetFor("eDP-1", "focused", "HDMI-A-1", both), false)
  assert.strictEqual(S.targetFor("HDMI-A-1", "focused", "HDMI-A-1", both), true)
  assert.strictEqual(S.targetFor("eDP-1", "eDP-1", "HDMI-A-1", both), true)
  assert.strictEqual(S.targetFor("HDMI-A-1", "eDP-1", "HDMI-A-1", both), false)
})
test("a named screen that is unplugged falls back to the focused one", () => {
  assert.strictEqual(S.targetFor("HDMI-A-1", "DP-9", "HDMI-A-1", both), true)
  assert.strictEqual(S.targetFor("eDP-1", "DP-9", "HDMI-A-1", both), false)
})
test("bar hotkeys go to the focused screen, or the first one with a bar", () => {
  assert.strictEqual(S.barScreen("HDMI-A-1", [], both), "HDMI-A-1")
  assert.strictEqual(S.barScreen("HDMI-A-1", ["HDMI-A-1"], both), "eDP-1")
})

test("positions are stored as screen=edge strings", () => {
  const m = S.positionsFrom(["HDMI-A-1=top", "junk", "eDP-1=left"])
  assert.strictEqual(m["HDMI-A-1"], "top"); assert.strictEqual(m["eDP-1"], "left"); assert.strictEqual(Object.keys(m).length, 2)
})
test("setting a screen's edge replaces its entry; follow-the-bar removes it", () => {
  assert.deepStrictEqual(Array.from(S.positionsWith(["HDMI-A-1=top", "eDP-1=left"], "HDMI-A-1", "bottom")), ["eDP-1=left", "HDMI-A-1=bottom"])
  assert.deepStrictEqual(Array.from(S.positionsWith(["HDMI-A-1=top"], "HDMI-A-1", "")), [])
})

console.log(failed ? `${failed} failed` : "all passed")
process.exit(failed ? 1 : 0)
