// node tests/test-liquid.js -- core/LiquidMath.js (liquid motion's springs and
// shapes), and that its settings exist everywhere they have to: Defaults.js,
// Config.qml's adapter, and the Settings page.
const fs = require("fs"), vm = require("vm"), path = require("path"), assert = require("assert")
const load = (file, names) => {
  const src = fs.readFileSync(path.join(__dirname, "..", file), "utf8").replace(/^\.pragma.*$/m, "")
  const ctx = {}
  vm.runInNewContext(src + "\nthis.__ = { " + names.join(", ") + " }", ctx)
  return ctx.__
}
const M = load("core/LiquidMath.js", ["NUMBERS", "PRESETS", "resolve", "slowed", "step", "overshoot", "bell", "shape", "across", "contentScale", "contentOpacity", "radius", "neck", "thread", "ripples"])
const D = load("core/Defaults.js", ["values", "get"])
const S = load("modules/settings/SettingsModel.js", ["pages", "subpages", "pageById", "whenHolds"])

let failed = 0
function test(name, fn) {
  try { fn(); console.log("  PASS", name) } catch (e) { failed++; console.log("  FAIL", name, "\n   ", e.message) }
}
const near = (a, b, eps, what) => assert.ok(Math.abs(a - b) <= eps, (what || "") + " " + a + " != " + b)
const run = (k, c, x0, target, secs) => {
  let x = x0, v = 0, min = Infinity, max = -Infinity
  for (let t = 0; t < secs; t += 1 / 60) { [x, v] = M.step(x, v, target, k, c, 1 / 60); min = Math.min(min, x); max = Math.max(max, x) }
  return { x, v, min, max }
}
const zero = { stiffness: 170, damping: 18, bulge: 0, neckWidth: 0, narrow: 0, sag: 0, wobble: 0 }

test("presets resolve to their numbers, custom to the stored ones", () => {
  assert.strictEqual(M.resolve("balanced", null).stiffness, 170)
  assert.strictEqual(M.resolve("bouncy", { stiffness: 1 }).stiffness, M.PRESETS.bouncy.stiffness)
  assert.strictEqual(M.resolve("custom", { stiffness: 300, damping: 9 }).stiffness, 300)
  // Anything missing or broken falls back to the balanced preset's.
  assert.strictEqual(M.resolve("custom", { stiffness: "x" }).stiffness, 170)
  assert.strictEqual(M.resolve("custom", {}).wobble, 260)
  for (const p in M.PRESETS) for (const k of M.NUMBERS) assert.ok(isFinite(M.PRESETS[p][k]), p + "." + k)
})
test("the spring settles on its target, and the balanced preset overshoots about 5%", () => {
  const r = run(170, 18, 1, 0, 3)
  near(r.x, 0, 1e-3, "settled"); near(r.v, 0, 1e-2, "still")
  near(-r.min, M.overshoot(170, 18), 0.01, "overshoot")
  near(M.overshoot(170, 18), 0.049, 0.005)
  assert.strictEqual(M.overshoot(100, 40), 0, "overdamped: none")
})
test("a stiff spring stays stable at a long frame", () => {
  let x = 1, v = 0
  for (let i = 0; i < 40; i++) [x, v] = M.step(x, v, 0, 600 / 0.0625, 60 / 0.25, 0.05)
  assert.ok(isFinite(x) && Math.abs(x) < 1e-3, String(x))
})
test("slowing a spring keeps its damping ratio and lengthens its period", () => {
  const [k, c] = M.slowed(170, 18, 2)
  near(c / (2 * Math.sqrt(k)), 18 / (2 * Math.sqrt(170)), 1e-9, "ratio")
  near(Math.sqrt(170) / Math.sqrt(k), 2, 1e-9, "period")
})
test("the bell is 0 shut, 1 halfway, 0 open", () => {
  assert.strictEqual(M.bell(0), 0); assert.strictEqual(M.bell(0.5), 1); assert.strictEqual(M.bell(1), 0)
  assert.strictEqual(M.bell(1.2), 0); assert.strictEqual(M.bell(-0.1), 0)
})
test("with nothing to add, a sliding drawer's rect is its own", () => {
  const r = [100, -40, 800, 400]
  for (const e of ["top", "bottom", "left", "right", "none"])
    for (const p of [0, 0.3, 0.5, 1]) assert.deepStrictEqual(Array.from(M.shape(r, e, p, zero, 0, 0, false, 0)), r, e + " " + p)
})
test("narrowing, bulging and sag keep the edge the drawer hangs from", () => {
  const o = Object.assign({}, zero, { narrow: 0.1, bulge: 0.6 })
  const r = [100, 50, 800, 400]
  const top = M.shape(r, "top", 0.5, o, 6, 0, false, 0)
  assert.strictEqual(top[1], 50, "top edge"); near(top[2], 720, 1e-9, "narrowed"); near(top[0] + top[2] / 2, 500, 1e-9, "centred"); near(top[3], 406, 1e-9, "sagged")
  const bot = M.shape(r, "bottom", 1.1, o, 6, 0, false, 0)
  near(bot[1] + bot[3], 450, 1e-9, "bottom edge"); near(bot[2], 800 * 1.06, 1e-9, "bulged on the overshoot")
  const right = M.shape(r, "right", 0.5, o, 6, 0, false, 0)
  near(right[0] + right[2], 900, 1e-9, "right edge"); near(right[3], 360, 1e-9, "narrowed across"); near(right[2], 806, 1e-9, "sagged along")
  const left = M.shape(r, "left", 0.5, o, 6, 0, false, 0)
  assert.strictEqual(left[0], 100, "left edge")
})
test("an overshoot lengthens it from the free end instead of moving it off its edge", () => {
  const r = [100, 50, 800, 400]
  const top = M.shape(r, "top", 1.2, zero, 0, 0, false, 0)
  assert.strictEqual(top[1], 50); near(top[3], 480, 1e-9)
  const left = M.shape(r, "left", 1.2, zero, 0, 0, false, 0)
  assert.strictEqual(left[0], 100); near(left[2], 960, 1e-9)
  const drop = M.shape(r, "bottom", 1.1, zero, 0, 0, true, 0)
  near(drop[1] + drop[3], 450, 1e-9); near(drop[3], 440, 1e-9)
})
test("a drop grows out of its edge into its open rect", () => {
  const r = [100, 50, 800, 400]
  const shut = M.shape(r, "top", 0, zero, 0, 0, true, 10)
  near(shut[3], 0, 1e-9, "nothing shut"); near(shut[2], 800 * 0.3, 1e-9, "narrow")
  const open = M.shape(r, "top", 1, zero, 0, 0, true, 10)
  assert.deepStrictEqual(Array.from(open), [100, 40, 800, 410], "open, reaching into the frame")
  const b = M.shape(r, "bottom", 1, zero, 0, 0, true, 10)
  near(b[1] + b[3], 460, 1e-9, "bottom edge in the frame")
  assert.deepStrictEqual(Array.from(M.contentScale("top", 1, zero, 0, true)), [1, 1])
  assert.deepStrictEqual(Array.from(M.contentScale("top", 0.5, zero, 0, false)), [1, 1])
  assert.deepStrictEqual(Array.from(M.contentScale("left", 0.5, zero, 0, true)), [0.5, 0.3 + 0.7 * 0.8])
})
test("the content never comes out of its shape", () => {
  const o = Object.assign({}, zero, { narrow: 0.1, bulge: 0.6 })
  const r = [0, 0, 800, 400]
  for (const p of [0.1, 0.5, 0.9, 1, 1.05]) {
    const sc = M.contentScale("top", p, o, 0, false)
    assert.ok(800 * sc[0] <= M.shape(r, "top", p, o, 0, 0, false, 0)[2] + 1e-9, "p " + p)
  }
  assert.strictEqual(M.contentOpacity(0.2, false), 0); assert.strictEqual(M.contentOpacity(1, true), 1)
})
test("a drawer is round as a drop at first and squares up as it grows", () => {
  const r = [0, 0, 800, 400]
  assert.strictEqual(M.radius([0, 0, 200, 100], 28, 0), 50)
  assert.strictEqual(M.radius(r, 28, 0), 112, "a big one stops at four of its radius")
  assert.strictEqual(M.radius(r, 28, 1), 28)
})
test("the neck and the thread are bells; the ripples spread and fade", () => {
  assert.strictEqual(M.neck(20, 0.5), 20); assert.strictEqual(M.neck(20, 1), 0); assert.strictEqual(M.neck(-5, 0.5), 0)
  assert.strictEqual(M.thread(52, 0.5), 52)
  const born = M.ripples(0, 1, 1), spent = M.ripples(1, 0, 1)
  assert.strictEqual(born[1], 0, "no height at birth"); assert.strictEqual(spent[1], 0, "none once spent")
  assert.ok(spent[0] > born[0], "spreads"); assert.strictEqual(born[2], 10); assert.strictEqual(spent[2], 0)
})

const configSrc = fs.readFileSync(path.join(__dirname, "../core/Config.qml"), "utf8")
const block = configSrc.slice(configSrc.indexOf("property JsonObject liquid"))
const leaves = (o, prefix) => Object.keys(o).flatMap(k => typeof o[k] === "object" && !Array.isArray(o[k]) ? leaves(o[k], prefix + k + ".") : [prefix + k])
const all = []
for (const p of S.pages) for (const r of p.rows) all.push({ page: p.id, r })
for (const id in S.subpages) for (const r of S.subpages[id].rows) all.push({ page: id, r })

test("every liquid default is in Config.qml with the same default", () => {
  for (const key of leaves(D.values.liquid, "")) {
    const name = key.split(".").pop(), v = D.get(D.values.liquid, key)
    const m = block.match(new RegExp("property (?:bool|real|int|string) " + name + ": ([^\\n]+)"))
    assert.ok(m, key + " missing from Config.qml")
    assert.strictEqual(JSON.parse(m[1].trim()), v, key)
  }
})
test("every liquid setting is on the Motion page, and every key there exists", () => {
  const page = S.pageById("liquid")
  assert.ok(page, "page")
  const keys = page.rows.filter(r => r.key).map(r => r.key)
  // liquid.enabled is the Style row's (motionStyle), with morph.enabled.
  for (const key of leaves(D.values.liquid, "liquid.")) if (key !== "liquid.preset" && key !== "liquid.enabled") assert.ok(keys.includes(key), key + " has no row")
  for (const k of keys) assert.notStrictEqual(D.get(D.values, k), undefined, k)
  assert.ok(page.rows.some(r => r.comp === "liquidPreset"), "the preset row")
  assert.ok(page.rows.some(r => r.comp === "motionStyle"), "the style row")
  assert.ok(all.some(x => x.r.type === "nav" && x.r.page === "liquid" && x.page === "frame"), "Frame & motion links to it")
})
test("liquid motion is off by default, and the rest of the page waits for it", () => {
  assert.strictEqual(D.values.liquid.enabled, false)
  const page = S.pageById("liquid")
  for (const r of page.rows) if (r.key && r.key !== "liquid.enabled") {
    const off = S.whenHolds(r.when, k => k === "liquid.enabled" ? false : D.get(D.values, k))
    assert.strictEqual(off, false, r.key + " is live with liquid motion off")
  }
})
test("morph motion is off by default", () => {
  assert.strictEqual(D.values.morph.enabled, false)
})
test("a list of when conditions must all hold", () => {
  const get = k => ({ a: 1, b: 2 })[k]
  assert.strictEqual(S.whenHolds(undefined, get), true)
  assert.strictEqual(S.whenHolds({ key: "a", value: 1 }, get), true)
  assert.strictEqual(S.whenHolds([{ key: "a", value: 1 }, { key: "b", value: 2 }], get), true)
  assert.strictEqual(S.whenHolds([{ key: "a", value: 1 }, { key: "b", value: 3 }], get), false)
})
console.log(failed ? `${failed} failed` : "all passed")
process.exit(failed ? 1 : 0)
