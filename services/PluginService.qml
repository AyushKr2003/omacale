pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

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
  // scripts/notif-popups). They are torn down by those scripts, never here.
  readonly property var managedClones: ["omarchy.lock", "omarchy.notifications"]

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
