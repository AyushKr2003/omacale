// node tests/test-settings.js -- modules/settings/SettingsModel.js: every
// display setting lives once, on the Display sub-pages, and every "nav" row
// leads to a page that exists.
const fs = require("fs"), vm = require("vm"), path = require("path"), assert = require("assert")
const src = fs.readFileSync(path.join(__dirname, "../modules/settings/SettingsModel.js"), "utf8").replace(/^\.pragma.*$/m, "")
const ctx = {}
vm.runInNewContext(src + "\nthis.M = { pages, subpages, pageById, searchRows }", ctx)
const M = ctx.M
let failed = 0
function test(name, fn) {
  try { fn(); console.log("  PASS", name) } catch (e) { failed++; console.log("  FAIL", name, "\n   ", e.message) }
}
const all = []
for (const p of M.pages) for (const r of p.rows) all.push({ page: p.id, r })
for (const id in M.subpages) for (const r of M.subpages[id].rows) all.push({ page: id, r })
const where = key => all.filter(x => x.r.key === key).map(x => x.page)

test("every display setting is on one Display sub-page, once", () => {
  const expect = {
    "display.cursorSize": "displayText", "display.zeroScaling": "displayText",
    "display.linkBrightness": "displayBrightness", "services.brightnessStep": "displayBrightness", "bar.scroll.brightness": "displayBrightness",
    "display.nightSchedule": "displayNight", "display.nightFrom": "displayNight", "display.nightTo": "displayNight",
    "display.quickOnConnect": "displayProfiles", "notifs.screen": "displayShell", "osd.screen": "displayShell"
  }
  for (const k in expect) assert.deepStrictEqual(where(k), [expect[k]], k + " is on " + where(k).join(", "))
})
test("the per-screen bar and desktop pickers are only on Shell on each screen", () => {
  const screens = all.filter(x => x.r.comp === "screens").map(x => x.page + ":" + x.r.mode)
  assert.deepStrictEqual(screens.sort(), ["displayShell:bar", "displayShell:desktop"])
})
test("every nav row leads to a page that exists", () => {
  for (const x of all) if (x.r.type === "nav") assert.ok(M.pageById(x.r.page), x.page + " -> " + x.r.page)
})
test("search finds the moved rows on their new pages", () => {
  assert.deepStrictEqual([...M.searchRows("brightness step").map(r => r.where)], ["Brightness"])
  assert.deepStrictEqual([...M.searchRows("cursor size").map(r => r.where)], ["Text and cursor"])
})
test("custom times are every half hour", () => {
  const o = M.pageById("displayNight").rows.find(r => r.key === "display.nightFrom").options
  assert.strictEqual(o.length, 48); assert.strictEqual(o[0].value, "00:00"); assert.strictEqual(o[47].value, "23:30")
})
console.log(failed ? `${failed} failed` : "all passed")
process.exit(failed ? 1 : 0)
