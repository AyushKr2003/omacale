pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
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

  // Every enabled bar widget, Omarchy's own included (Settings › Taskbar):
  // `source` "omarchy" or "plugin", `duplicateOf` the Omacale item an Omarchy
  // widget would stand in for (BarLayout.DUPLICATES; null if none).
  // widgetCatalog is every bar widget, enabled or not (Settings › Taskbar's
  // add list).
  readonly property var widgetCatalog: plugins.filter(p =>
    p.kinds.indexOf("bar-widget") >= 0 && BarLayout.NEVER.indexOf(p.id) < 0).map(p =>
    Object.assign({}, p, {
      source: p.firstParty ? "omarchy" : "plugin",
      duplicateOf: p.firstParty && BarLayout.DUPLICATES.hasOwnProperty(p.id) ? BarLayout.DUPLICATES[p.id] : null
    }))
  readonly property var barWidgets: widgetCatalog.filter(p => p.enabled)
  // Whether a status icon is on show: the one rule the bar (StatusRun,
  // BarContent's "at most N" count) and Settings › Taskbar's notes go by.
  function statusOn(id) {
    const st = Config.o.bar.status
    switch (id) {
    case "keepAwake": return st.keepAwake && IdleService.enabled
    case "update": return st.update && UpdateService.available
    case "recording": return RecordService.running
    case "lockStatus": return st.lockStatus && (Sys.capsLock || Sys.numLock)
    case "microphone": return st.microphone && (!st.microphoneInUseOnly || AudioService.capturing)
    case "bluetooth": return st.bluetooth && (!st.bluetoothConnectedOnly || Bluetooth.devices.values.some(d => d.connected))
    default: return !!st[id]
    }
  }

  // Widgets that failed to start in the bar, id -> why (BarWidgetSlot).
  property var widgetErrors: ({})
  function setWidgetError(id, why) {
    if (!id || (widgetErrors[id] || "") === why) return
    const next = Object.assign({}, widgetErrors)
    if (why) next[id] = why
    else delete next[id]
    widgetErrors = next
  }
  // The plugin pill's widgets: the third-party ones.
  readonly property var pillWidgets: barWidgets.filter(p => p.source === "plugin")

  // Where a pill widget sits: "pinned", "overflow" (behind the pill's chevron)
  // or "hidden" (bar.plugins.hidden: not in the bar, the plugin still runs).
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
    Config.set("bar.plugins.enabled", pillWidgets.some(p => hidden.indexOf(p.id) < 0))
  }
  // The pill switch. Turned on with every widget hidden, it brings them back
  // rather than showing an empty pill.
  function setBarShown(on) {
    if (on && pillWidgets.every(p => barMode(p.id) === "hidden")) {
      const ids = pillWidgets.map(p => p.id)
      Config.set("bar.plugins.hidden", Array.from(Config.o.bar.plugins.hidden).filter(i => ids.indexOf(i) < 0))
    }
    Config.set("bar.plugins.enabled", on)
  }

  function savedLayout() {
    const l = Config.o.bar.layout
    return { start: l.start, center: l.center, end: l.end, removed: l.removed, drawer: l.drawer }
  }
  // Settings › Taskbar's bar. Resolved against the enabled bar widgets, so
  // a widget that was disabled drops out of its place.
  function barLayout() {
    // Until `omarchy plugin list` has answered, the widget list is unknown:
    // keep the saved widget places rather than drop them on the next write.
    return BarLayout.resolve(savedLayout(), loaded && !error ? barWidgets.map(p => p.id) : null)
  }
  function setBarLayout(l) {
    Config.set("bar.layout.start", l.start)
    Config.set("bar.layout.center", l.center)
    Config.set("bar.layout.end", l.end)
    Config.set("bar.layout.removed", l.removed || [])
    Config.set("bar.layout.drawer", l.drawer || [])
  }
  // Moving an item in Settings: a pill widget dropped on "Not in the bar"
  // goes back into the pill.
  function placeItem(id, list, index) {
    setBarLayout(BarLayout.place(barLayout(), id, list, index, pillWidgets.map(p => p.id)))
  }
  // Widgets the bar's registry has that were never offered go on the bar
  // (Bar.qml calls this once the registry settles). widgets: [{ id,
  // firstParty }]; omarchyIds: the widgets in Omarchy's own bar layout.
  // The saved places of widgets not loaded yet are kept (resolve with null).
  // After the first adoption, each widget put on the bar is marked New in
  // Settings and announced, since it appeared without being asked for.
  function adoptWidgets(widgets, omarchyIds) {
    const c = Config.o.bar.layout
    const first = !c.adopted
    const before = BarLayout.resolve(savedLayout(), null)
    const r = BarLayout.adoptNew(before, widgets, Array.from(c.seen), first, omarchyIds)
    if (!r.changed) return
    setBarLayout(r.layout)
    Config.set("bar.layout.seen", r.seen)
    Config.set("bar.layout.adopted", true)
    if (first) return
    const placed = r.layout.end.filter(id => before.end.indexOf(id) < 0).map(id => BarLayout.pluginOf(id))
    if (!placed.length) return
    // A new Omarchy widget that is off is turned on, so Omarchy's plugin list
    // agrees with the bar (enable only writes shell.json, nothing reloads).
    for (const id of placed) {
      const w = widgets.find(x => x.id === id)
      if (w && w.enabled === false) Quickshell.execDetached(["omarchy", "plugin", "enable", id])
    }
    Qt.callLater(refresh)
    Config.set("bar.layout.fresh", Array.from(c.fresh).concat(placed))
    const names = placed.map(id => { const w = widgets.find(x => x.id === id); return w && w.name ? w.name : id })
    Toaster.toast(placed.length === 1 ? "New bar widget" : "New bar widgets",
      names.join(", ") + (placed.length === 1 ? " is" : " are") + " on the bar now. Move or remove it in Settings › Taskbar",
      "widgets", Toaster.info, 0, "omacale:new-widgets")
  }
  // Settings › Taskbar's reset: the default layout, and a first adoption
  // again (Bar.qml answers adoptRequested), so Omarchy's widgets come back as
  // on its own bar.
  signal adoptRequested()
  function resetBarLayout() {
    setBarLayout({ start: [], center: [], end: [], removed: [], drawer: [] })
    Config.set("bar.layout.seen", [])
    Config.set("bar.layout.fresh", [])
    Config.set("bar.layout.adopted", false)
    adoptRequested()
  }
  // Pill widgets that waited behind the pill's own chevron
  // (bar.plugins.unpinned, before the chevron for everything) go behind the
  // bar's chevron instead, in the same order. Run with adoption; a no-op once
  // done, as Settings no longer offers the pill's chevron.
  function moveUnpinned() {
    const unpinned = Array.from(Config.o.bar.plugins.unpinned)
    if (!unpinned.length) return
    let l = BarLayout.resolve(savedLayout(), null)
    for (const id of unpinned)
      if (!BarLayout.find(l, "plugin:" + id) && l.drawer.indexOf("plugin:" + id) < 0 && l.removed.indexOf("plugin:" + id) < 0)
        l = BarLayout.place(l, "plugin:" + id, "drawer", l.drawer.length, [])
    setBarLayout(l)
    Config.set("bar.plugins.unpinned", [])
  }
  function clearFresh() { if (Config.o.bar.layout.fresh.length) Config.set("bar.layout.fresh", []) }

  // Add a widget from Settings › Taskbar's add list at the end of the end
  // section. A disabled one is enabled first (Omarchy's `plugin enable`), and
  // placed once that succeeded.
  property string placeAfterEnable: ""
  function addWidget(id) {
    const w = widgetCatalog.find(p => p.id === id)
    if (!w) return
    if (w.enabled) {
      setBarLayout(BarLayout.appendEnd(BarLayout.resolve(savedLayout(), null), "plugin:" + id))
      return
    }
    placeAfterEnable = id
    setEnabled(id, true)
  }
  // The eye on a built-in's row: the item's existing switch.
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
      else if (root.placeAfterEnable !== "") {
        // Seen, so adoption doesn't add it a second time.
        const id = root.placeAfterEnable
        root.setBarLayout(BarLayout.appendEnd(BarLayout.resolve(root.savedLayout(), null), "plugin:" + id))
        if (Config.o.bar.layout.seen.indexOf(id) < 0)
          Config.set("bar.layout.seen", Array.from(Config.o.bar.layout.seen).concat([id]))
      }
      root.placeAfterEnable = ""
      root.busyId = ""
      root.refresh()
    }
  }
}
