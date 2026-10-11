// node tests/test-theme-mode.js -- unit tests for core/ThemeMode.js, Omarchy's
// light/dark rule (omarchy-theme-color resolve_theme_mode) as Omacale reads it.
const fs = require("fs"), vm = require("vm"), path = require("path"), assert = require("assert")
const src = fs.readFileSync(path.join(__dirname, "../core/ThemeMode.js"), "utf8").replace(/^\.pragma.*$/m, "")
const ctx = {}
vm.runInNewContext(src + "\nthis.M = { parse, resolveMode }", ctx)
const M = ctx.M
let failed = 0
function test(name, fn) {
  try { fn(); console.log("  PASS", name) } catch (e) { failed++; console.log("  FAIL", name, "\n   ", e.message) }
}

test("the mode key wins", () => assert.strictEqual(M.resolveMode('mode = "light"\nbackground = "#000000"', false), "light"))
test("mode beats a light.mode file", () => assert.strictEqual(M.resolveMode('mode = "dark"\nbackground = "#ffffff"', true), "dark"))
test("the legacy theme_type key", () => assert.strictEqual(M.resolveMode("theme_type = 'light'\nbackground = '#000000'", false), "light"))
test("a light.mode file", () => assert.strictEqual(M.resolveMode('background = "#101010"', true), "light"))
test("a bright background is light", () => assert.strictEqual(M.resolveMode('background = "#eff1f5"', false), "light"))
test("r+g+b of exactly 382 is dark", () => assert.strictEqual(M.resolveMode('background = "#7f7f80"', false), "dark"))
test("no usable background is dark", () => {
  assert.strictEqual(M.resolveMode('background = "teal"', false), "dark")
  assert.strictEqual(M.resolveMode("", false), "dark")
})
test("comments and spacing are ignored", () => {
  const p = M.parse('# a theme\n  accent="#ff0000"  # red\nmode = light\n')
  assert.strictEqual(p.accent, "#ff0000"); assert.strictEqual(p.mode, "light")
})

console.log(failed ? `${failed} failed` : "all passed")
process.exit(failed ? 1 : 0)
