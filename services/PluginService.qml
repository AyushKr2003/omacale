pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."
import "../core/BarLayout.js" as BarLayout

// Settings › Plugins: every Omarchy shell plugin, built-in and third-party.
// Omarchy is the engine: `omarchy plugin list --json` says what is enabled
// and what may be disabled, `omarchy-plugin-catalog` (the manifest walk its
// own enable/clone use) supplies names, descriptions and kinds, and every
// change goes through `omarchy plugin enable|disable|add|update|remove`.
// Caelestia has no plugin page; the layout follows Shibumi's catalog.
QtObject {
  id: root

  property var plugins: []
  property bool loaded: false
  property bool loading: false
  property string busyId: ""        // plugin being enabled/disabled
  property string error: ""

  // Clones Omacale's own handovers made (scripts/lock-screen,
  // scripts/notif-popups, scripts/osd-handover). They are torn down by those
  // scripts, never here.
  readonly property var managedClones: ["omarchy.lock", "omarchy.notifications", "omarchy.osd"]

  function refresh() {
    if (loading)
      return
    loading = true
    listProc.running = true
  }

  function byId(id) {
    for (let i = 0; i < plugins.length; i++)
      if (plugins[i].id === id)
        return plugins[i]
    return null
  }

  // Bar widgets (Settings › Taskbar › Plugins): enabled third-party plugins
  // with a widget for the plugin pill.
  readonly property var barWidgets: plugins.filter(p =>
    !p.firstParty && p.enabled && p.kinds.indexOf("bar-widget") >= 0)

  // Where a widget sits: "pinned", "overflow" (behind the pill's chevron) or
  // "hidden" (bar.plugins.hidden: not in the bar, the plugin still runs).
  function barMode(id) {
    const c = Config.o.bar.plugins
    return c.hidden.indexOf(id) >= 0 ? "hidden" : c.unpinned.indexOf(id) >= 0 ? "overflow" : "pinned"
  }
  // Hiding leaves the pin alone, so a widget shown again goes back where it was.
  function setBarMode(id, mode) {
    const c = Config.o.bar.plugins
    const hidden = Array.from(c.hidden).filter(i => i !== id)
    if (mode === "hidden") hidden.push(id)
    else {
      const unpinned = Array.from(c.unpinned).filter(i => i !== id)
      if (mode === "overflow") unpinned.push(id)
      Config.set("bar.plugins.unpinned", unpinned)
    }
    Config.set("bar.plugins.hidden", hidden)
    // The pill is shown while any widget is in it: hiding the last one
    // switches it off, bringing one back switches it on.
    Config.set("bar.plugins.enabled", barWidgets.some(p => hidden.indexOf(p.id) < 0))
  }
  // The pill switch. Turned on with every widget hidden, it brings them back
  // rather than showing an empty pill.
  function setBarShown(on) {
    if (on && barWidgets.every(p => barMode(p.id) === "hidden")) {
      const ids = barWidgets.map(p => p.id)
      Config.set("bar.plugins.hidden", Array.from(Config.o.bar.plugins.hidden).filter(i => ids.indexOf(i) < 0))
    }
    Config.set("bar.plugins.enabled", on)
  }

  // Settings › Taskbar › Layout. Resolved against the enabled bar widgets, so
  // a widget that was disabled drops out of its place.
  function barLayout() {
    const l = Config.o.bar.layout
    // Until `omarchy plugin list` has answered, the widget list is unknown:
    // keep the saved widget places rather than drop them on the next write.
    return BarLayout.resolve({ start: l.start, center: l.center, end: l.end, removed: l.removed },
      loaded && !error ? barWidgets.map(p => p.id) : null)
  }
  function setBarLayout(l) {
    Config.set("bar.layout.start", l.start)
    Config.set("bar.layout.center", l.center)
    Config.set("bar.layout.end", l.end)
    Config.set("bar.layout.removed", l.removed || [])
  }
  // Settings › Taskbar › Layout's eye: the item's existing switch.
  function itemShown(id) {
    const it = BarLayout.ITEMS[id]
    return !it || !it.key ? true : !!Config.get(it.key)
  }
  function setItemShown(id, on) {
    const it = BarLayout.ITEMS[id]
    if (!it || !it.key) return
    if (it.key === "bar.plugins.enabled") setBarShown(on)
    else Config.set(it.key, on)
  }
  // A widget out of the plugin pill, on the bar on its own, and back.
  function takeOutWidget(id) { setBarLayout(BarLayout.takeOut(barLayout(), id)) }
  function putBackWidget(id) { setBarLayout(BarLayout.putBack(barLayout(), id)) }

  function setEnabled(id, on) {
    const p = byId(id)
    if (!p || busyId !== "" || !p.toggleable)
      return
    busyId = id
    error = ""
    toggleProc.command = ["omarchy", "plugin", on ? "enable" : "disable", id]
    toggleProc.running = true
  }

  // add / update / remove write into ~/.config/omarchy/plugins, and the shell
  // answers any write there by reloading every plugin -- Omacale included,
  // so the Settings window this was started from is gone before it finishes.
  // Run them detached and bring Settings back on this page afterwards.
  function runAndReturn(args) {
    const cmd = args.map(a => "'" + String(a).replace(/'/g, "'\\''") + "'").join(" ")
    Quickshell.execDetached(["bash", "-c",
      cmd + " >/dev/null 2>&1; sleep 2; omarchy-shell omacale settingsPage plugins"])
  }
  function remove(id) {
    const p = byId(id)
    if (p && p.removable)
      runAndReturn(["omarchy", "plugin", "remove", id, "--yes"])
  }
  function update(id) {
    runAndReturn(id ? ["omarchy", "plugin", "update", id, "--yes"] : ["omarchy", "plugin", "update", "--yes"])
  }
  function add(url, enable) {
    const u = String(url || "").trim()
    if (!u)
      return
    runAndReturn(["omarchy", "plugin", "add", u].concat(enable ? ["--enable"] : []).concat(["--yes"]))
  }

  function merge(listText, catalogText) {
    let list = [], catalog = []
    try { list = JSON.parse(listText) } catch (e) { list = [] }
    try { catalog = JSON.parse(catalogText) } catch (e) { catalog = [] }
    const meta = {}
    for (const c of catalog)
      if (c && c.id)
        meta[c.id] = c
    const out = []
    for (const p of list) {
      if (!p || !p.id)
        continue
      const m = meta[p.id] || {}
      const kinds = Array.isArray(p.kinds) ? p.kinds : (m.kinds || [])
      const isBar = kinds.indexOf("bar") >= 0
      const managed = managedClones.indexOf(p.clonedFrom) >= 0
      out.push({
        id: p.id,
        name: p.name || (m.barWidget && m.barWidget.displayName) || p.id,
        description: m.description || (m.barWidget && m.barWidget.description) || "",
        category: m.barWidget && m.barWidget.category ? m.barWidget.category : "",
        kinds: kinds,
        enabled: !!p.enabled,
        active: !!p.active,
        firstParty: !!p.firstParty,
        clonedFrom: p.clonedFrom || "",
        managed: managed,
        isBar: isBar,
        sourceDir: m.sourceDir || "",
        manifestPath: m.manifestPath || "",
        // A bar is picked, not enabled; the active one can't go; Omacale's
        // own clones belong to its handover scripts.
        toggleable: !!p.canDisable && !isBar && !managed,
        removable: !p.firstParty && !p.active && !managed
      })
    }
    out.sort((a, b) => a.name.localeCompare(b.name))
    plugins = out
    loaded = true
  }

  property Process listProc: Process {
    command: ["bash", "-c", "omarchy plugin list --json; printf '\\n@@CATALOG@@\\n'; omarchy-plugin-catalog"]
    stdout: StdioCollector {
      onStreamFinished: {
        const parts = String(text).split("\n@@CATALOG@@\n")
        root.merge(parts[0] || "[]", parts[1] || "[]")
      }
    }
    onExited: (code) => {
      root.loading = false
      if (code !== 0)
        root.error = "Couldn't read the plugin list (omarchy plugin list)"
    }
  }

  property Process toggleProc: Process {
    stderr: StdioCollector {
      id: toggleErr
    }
    onExited: (code) => {
      if (code !== 0)
        root.error = String(toggleErr.text).trim().split("\n").pop() || "omarchy plugin failed"
      root.busyId = ""
      root.refresh()
    }
  }
}
