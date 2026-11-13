// node tests/test-session.js -- modules/session/SessionItems.js: the session
// drawer's order, hidden items and the compact Lock/Screensaver pair.
const fs = require("fs"), vm = require("vm"), path = require("path"), assert = require("assert")
const src = fs.readFileSync(path.join(__dirname, "../modules/session/SessionItems.js"), "utf8").replace(/^\.pragma.*$/m, "")
const ctx = {}
vm.runInNewContext(src + "\nthis.M = { IDS, order, shown, rows, moved, sleepKind, icon, command }", ctx)
const M = ctx.M
let failed = 0
function test(name, fn) {
  try { fn(); console.log("  PASS", name) } catch (e) { failed++; console.log("  FAIL", name, "\n   ", e.message) }
}
const cfg = o => Object.assign({ gif: true, extraButtons: true, extraStyle: "compact", order: M.IDS, hidden: [] }, o)
const j = x => JSON.parse(JSON.stringify(x))

test("the default is Caelestia's four, the animation, then the compact pair", () => {
  assert.deepStrictEqual(j(M.rows(cfg())), [["logout"], ["shutdown"], ["gif"], ["hibernate"], ["reboot"], ["lock", "screensaver"]])
})
test("full size puts Lock and Screensaver on rows of their own", () => {
  assert.deepStrictEqual(j(M.rows(cfg({ extraStyle: "full" }))).slice(-2), [["lock"], ["screensaver"]])
})
test("the compact pair only shares a row when they are neighbours", () => {
  const order = ["lock", "logout", "shutdown", "gif", "hibernate", "reboot", "screensaver"]
  assert.deepStrictEqual(j(M.rows(cfg({ order }))), [["lock"], ["logout"], ["shutdown"], ["gif"], ["hibernate"], ["reboot"], ["screensaver"]])
})
test("hidden items, the animation switch and extraButtons leave items out", () => {
  assert.deepStrictEqual(j(M.rows(cfg({ hidden: ["reboot", "screensaver"], gif: false }))), [["logout"], ["shutdown"], ["hibernate"], ["lock"]])
  assert.deepStrictEqual(j(M.rows(cfg({ extraButtons: false }))).flat().indexOf("lock"), -1)
})
test("a saved order is repaired: unknown and duplicate ids dropped, missing ones put back", () => {
  assert.deepStrictEqual(j(M.order(["reboot", "bogus", "reboot", "logout"])), ["reboot", "lock", "screensaver", "logout", "shutdown", "gif", "hibernate"])
  assert.deepStrictEqual(j(M.order([])), j(M.IDS))
})
test("moving swaps with the neighbour and stops at the ends", () => {
  assert.deepStrictEqual(j(M.moved(M.IDS, "shutdown", -1)).slice(0, 2), ["shutdown", "logout"])
  assert.deepStrictEqual(j(M.moved(M.IDS, "logout", -1)), j(M.IDS))
  assert.deepStrictEqual(j(M.moved(M.IDS, "screensaver", 1)), j(M.IDS))
})
const sess = o => Object.assign({ sleepAction: "hibernate", icons: {}, commands: {} }, o)
test("the third button: the chosen sleep, else the other, else none; a custom command wins", () => {
  assert.strictEqual(M.sleepKind(sess(), true, true), "hibernate")
  assert.strictEqual(M.sleepKind(sess(), false, true), "suspend")
  assert.strictEqual(M.sleepKind(sess({ sleepAction: "suspend" }), true, true), "suspend")
  assert.strictEqual(M.sleepKind(sess({ sleepAction: "suspend" }), true, false), "hibernate")
  assert.strictEqual(M.sleepKind(sess(), false, false), "")
  assert.strictEqual(M.sleepKind(sess({ commands: { hibernate: "zzz" } }), false, false), "custom")
})
test("icons and commands fall back to Omarchy's own, the user's settings first", () => {
  assert.strictEqual(M.command("shutdown", sess(), ""), "omarchy system shutdown")
  assert.strictEqual(M.command("reboot", sess({ commands: { reboot: "my-reboot" } }), ""), "my-reboot")
  assert.strictEqual(M.command("hibernate", sess(), "suspend"), "systemctl suspend")
  assert.strictEqual(M.command("hibernate", sess({ commands: { hibernate: "zzz" } }), "custom"), "zzz")
  assert.strictEqual(M.icon("hibernate", sess(), "suspend"), "bedtime")
  assert.strictEqual(M.icon("logout", sess({ icons: { logout: "door_open" } }), ""), "door_open")
})
console.log(failed ? `${failed} failed` : "all passed")
process.exit(failed ? 1 : 0)
