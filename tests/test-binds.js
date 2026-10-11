// node tests/test-binds.js -- unit tests for modules/settings/cards/BindParse.js,
// the keybinds.lua line parser Settings › Keybinds uses (also for Omarchy's
// own bindings/*.lua lines, to restore a key a trial rebind replaced).
const fs = require("fs"), vm = require("vm"), path = require("path"), assert = require("assert")
const src = fs.readFileSync(path.join(__dirname, "../modules/settings/cards/BindParse.js"), "utf8").replace(/^\.pragma.*$/m, "")
const ctx = {}
vm.runInNewContext(src + "\nthis.P = { parseBind, stockLine }", ctx)
const P = ctx.P
let failed = 0
function test(name, fn) {
  try { fn(); console.log("  PASS", name) } catch (e) { failed++; console.log("  FAIL", name, "\n   ", e.message) }
}
const plain = v => JSON.parse(JSON.stringify(v))

test("a plain bind", () => {
  const b = P.parseBind('o.bind("SUPER + A", "Omacale launcher", "omarchy-shell omacale launcher")')
  assert.deepStrictEqual(plain(b), { optional: false, rebind: false, keys: "SUPER + A", desc: "Omacale launcher", cmd: "omarchy-shell omacale launcher", opts: "", note: "",
    line: 'o.bind("SUPER + A", "Omacale launcher", "omarchy-shell omacale launcher")' })
})
test("a commented rebind with a note", () => {
  const b = P.parseBind('-- o.rebind("SUPER + ESCAPE", "Omacale session menu", "omarchy-shell omacale session")      -- was: System menu')
  assert.strictEqual(b.optional, true); assert.strictEqual(b.rebind, true)
  assert.strictEqual(b.note, "was: System menu")
  assert.strictEqual(b.line, 'o.rebind("SUPER + ESCAPE", "Omacale session menu", "omarchy-shell omacale session")')
})
test("options are kept in the line", () => {
  const b = P.parseBind('-- o.rebind("XF86PowerOff", "Omacale power menu", "omarchy-shell omacale session || omarchy-menu toggle system", { locked = true })  -- was: Power menu')
  assert.strictEqual(b.cmd, "omarchy-shell omacale session || omarchy-menu toggle system")
  assert.strictEqual(b.opts, "{ locked = true }")
  assert.strictEqual(b.line, 'o.rebind("XF86PowerOff", "Omacale power menu", "omarchy-shell omacale session || omarchy-menu toggle system", { locked = true })')
  assert.strictEqual(b.note, "was: Power menu")
})
test("anything else is not a bind", () => {
  assert.strictEqual(P.parseBind("-- just a comment"), null)
  assert.strictEqual(P.parseBind("function o.rebind(keys, description, dispatcher, options)"), null)
})
test("stockLine finds Omarchy's line for a key", () => {
  const omarchy = 'o.bind("SUPER + SPACE", "Omarchy menu", "omarchy-menu")\no.bind("XF86PowerOff", "Power menu", "omarchy-menu toggle system", { locked = true })\n'
  assert.strictEqual(P.stockLine(omarchy, "XF86PowerOff"), 'o.bind("XF86PowerOff", "Power menu", "omarchy-menu toggle system", { locked = true })')
  assert.strictEqual(P.stockLine(omarchy, "SUPER + Q"), "")
})

console.log(failed ? `${failed} failed` : "all passed")
process.exit(failed ? 1 : 0)
