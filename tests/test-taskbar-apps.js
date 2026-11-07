// node tests/test-taskbar-apps.js -- saved app sections and window selection.
const fs = require("fs"), vm = require("vm"), path = require("path"), assert = require("assert")
function load(file) {
  const ctx = {}
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, "..", file), "utf8").replace(/^\.pragma.*$/m, ""), ctx)
  return ctx
}
const M = load("core/TaskbarApps.js"), D = load("core/Defaults.js"), L = load("core/BarLayout.js")
const plain = v => JSON.parse(JSON.stringify(v))
const eq = (a, b) => assert.deepStrictEqual(plain(a), b)
const app = id => ({ id: "app:" + id, type: "app", app: id })
const group = { id: "group:work", type: "group", name: "Work", apps: ["editor", "browser"] }
const folder = { id: "folder:docs", type: "folder", name: "Documents", path: "/tmp/Documents" }
let failed = 0
function test(name, fn) {
  try { fn(); console.log("  PASS", name) } catch (e) { failed++; console.log("  FAIL", name, "\n   ", e.message) }
}

test("disabled by default, with no saved items", () => {
  eq(D.values.bar.apps, { enabled: false, showRunning: true, useAvailableSpace: true, showSettings: false, maxShown: 8, items: [] })
  assert.strictEqual(L.ITEMS.apps.key, "bar.apps.enabled")
  assert.strictEqual(L.PAGES.apps, "taskbarApps")
})
test("old layouts acquire one optional slot without disturbing their order", () => {
  const old = { start: ["workspaces", "logo"], center: ["clock"], end: ["network", "activeWindow"] }
  const next = L.resolve(old, [])
  eq(next.start, ["workspaces", "apps", "logo"])
  assert.ok(next.end.indexOf("network") < next.end.indexOf("activeWindow"))
  eq(L.resolve(next, []), plain(next))
  eq(L.resolve(L.place(next, "apps", "removed", 0), []).removed, ["apps"])
})
test("malformed settings do not break the section", () => {
  for (const value of [null, {}, 1, "bad", [null, 7, {}, [], { type: "command", cmd: "touch /tmp/no" }]]) eq(M.normalize(value), [])
})
test("normalizes ids and removes duplicates, retaining order", () => {
  eq(M.normalize([{ type: "app", app: " editor.desktop " }, app("editor"), folder, group]), [app("editor"), folder, group])
})
test("bad groups and relative directories are dropped", () => {
  eq(M.normalize([{ type: "group", id: "app:editor", name: "Work" }, { type: "group", id: "group:x", name: " " }, { type: "folder", id: "folder:x", path: "relative" }]), [])
})
test("prototype-looking app ids are ordinary data", () => {
  eq(M.build([app("__proto__"), app("constructor")], ["__proto__", "constructor"], [], false), [app("__proto__"), app("constructor")])
})
test("groups deduplicate members and retain unavailable ids", () => {
  eq(M.normalize([Object.assign({}, group, { apps: ["editor.desktop", "editor", null, "missing"] })])[0].apps, ["editor", "missing"])
})
test("pin order survives JSON serialization", () => {
  const saved = [folder, group, app("browser")]
  eq(M.normalize(JSON.parse(JSON.stringify(saved))), saved)
})
test("running members stay in their group; standalone pins stay first", () => {
  eq(M.build([folder, group, app("music")], ["editor", "browser", "music", "chat"], [{ app: "editor" }, { app: "chat" }, { app: "chat" }, { app: "music" }], true), [folder, group, app("music"), app("chat")])
})
test("pinned-only mode excludes unpinned running apps", () => {
  eq(M.build([app("editor")], ["editor", "chat"], [{ app: "chat" }], false), [app("editor")])
})
test("uninstalled pins hide without being erased from saved settings", () => {
  const pins = [app("missing"), group]
  eq(M.build(pins, ["editor"], [], true), [group])
  eq(pins, [app("missing"), group])
  eq(M.build(pins, ["missing", "editor"], [], true), pins)
})
test("hidden apps are omitted when not in the installed/allowed set", () => {
  eq(M.build([app("hidden")], [], [{ app: "hidden" }], true), [])
})
test("empty groups stay available to configure", () => {
  const empty = Object.assign({}, group, { apps: [] })
  eq(M.build([empty], [], [], false), [empty])
})
test("membership changes do not mutate or reorder other pins", () => {
  const pins = [folder, group, app("music")]
  eq(M.members(pins, group.id, "chat.desktop", true)[1].apps, ["editor", "browser", "chat"])
  eq(M.members(pins, group.id, "editor", false)[1].apps, ["browser"])
  eq(pins, [folder, group, app("music")])
  eq(M.members(pins, "removed-group", "chat", true), pins)
})
test("reorder clamps at either end and preserves membership", () => {
  const pins = [folder, group, app("music")]
  eq(M.move(pins, folder.id, -1), pins)
  eq(M.move(pins, folder.id, 99), [group, app("music"), folder])
  eq(M.move(pins, "missing", 1), pins)
  eq(M.remove(pins, group.id), [folder, app("music")])
  eq(pins, [folder, group, app("music")])
})
test("drag places pins by stable ids without losing hidden pins or group edits", () => {
  const pins = [app("hidden"), folder, group, app("music")]
  eq(M.place(pins, app("music"), folder.id), [app("hidden"), app("music"), folder, group])
  eq(M.place(pins, app("chat"), folder.id), [app("hidden"), app("chat"), folder, group, app("music")])
  eq(M.place(pins, app("music"), ""), pins)
  eq(M.place(pins, group, group.id), pins)
  eq(M.place(pins, Object.assign({}, group, {name:"stale",apps:[]}), ""), [app("hidden"), folder, app("music"), group])
  eq(M.place(pins, {id:"folder:gone",type:"folder",path:"/tmp",name:"Gone"}, ""), pins)
  eq(pins, [app("hidden"), folder, group, app("music")])
})
test("directory shortcuts expand home but reject relative paths and controls", () => {
  assert.strictEqual(M.folderPath("~/My Documents", "/home/test"), "/home/test/My Documents")
  assert.strictEqual(M.folderPath("~", "/home/test"), "/home/test")
  for (const p of ["relative", "https://site.invalid", "~/x", "/tmp/a\nb", "/tmp/a\u0000b"])
    assert.strictEqual(M.folderPath(p, ""), "", p)
})
test("folder URLs preserve spaces, fragments, queries and literal shell syntax", () => {
  const dir = '/tmp/a b/#?%/$(touch nope);"é"'
  const url = M.fileUrl(dir)
  assert.strictEqual(url, 'file:///tmp/a%20b/%23%3F%25/%24(touch%20nope)%3B%22%C3%A9%22')
  assert.strictEqual(decodeURIComponent(url.slice(7)), dir)
})
test("web-app classes retain paths across supported browser prefixes", () => {
  assert.strictEqual(M.webappClass("brave-youtube.com__-Default"), M.webappClass("chrome-youtube.com__-Default"))
  assert.notStrictEqual(M.webappClass("brave-site.test__one-Default"), M.webappClass("chrome-site.test__two-Default"))
  assert.strictEqual(M.webappClass("chrome-SITE.test__Foo-Default"), M.webappClass("brave-site.test__Foo-Default"))
  assert.notStrictEqual(M.webappClass("brave-site.test__Foo-Default"), M.webappClass("chrome-site.test__foo-Default"))
  assert.strictEqual(M.webappClass("brave-browser"), "")
})
test("native bare window addresses become canonical Lua selectors", () => {
  assert.strictEqual(M.windowAddress("56436d702310"), "0x56436d702310")
  assert.strictEqual(M.windowAddress("0xABC"), "0xabc")
  for (const value of ["", "address:123", "12;foo", null]) assert.strictEqual(M.windowAddress(value), "")
})
test("click cycles the app's windows and prefers the current workspace", () => {
  const wins = [{ address: "a", workspaceId: 1 }, { address: "b", workspaceId: 2 }, { address: "c", workspaceId: 2 }]
  assert.strictEqual(M.pickWindow(wins, "a", 1), 1)
  assert.strictEqual(M.pickWindow(wins, "c", 2), 0)
  assert.strictEqual(M.pickWindow(wins, "other", 2), 1)
  assert.strictEqual(M.pickWindow(wins, "other", 3), 0)
  assert.strictEqual(M.pickWindow([], "", 1), -1)
})
console.log(failed ? `${failed} failed` : "all passed")
process.exit(failed ? 1 : 0)
