pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../core/TaskbarApps.js" as Model
import ".."

// Data for the optional bar section, shared across screens. As in the
// overview, Hyprland owns window state; Omarchy owns application launches.
QtObject {
  id: root
  readonly property var pins: Model.normalize(Config.o.bar.apps.items)
  readonly property var available: AppService.launchable
  readonly property var byId: {
    const out = Object.create(null)
    for (const e of available) out[Model.appId(e.id)] = e
    return out
  }
  function entry(id) { return byId[Model.appId(id)] || null }
  function save(items) { Config.set("bar.apps.items", Model.normalize(items)) }
  function isPinned(app) { return pins.some(i => i.type === "app" && i.app === Model.appId(app)) }
  function pin(app, on) {
    const id = Model.appId(app), key = "app:" + id
    if (!id) return
    const next = Model.remove(pins, key)
    save(on ? next.concat([{ type: "app", app: id }]) : next)
  }
  function setMember(group, app, on) { save(Model.members(pins, group, app, on)) }
  function rename(id, name) {
    if (!name.trim()) return
    save(pins.map(i => i.id === id ? Object.assign({}, i, { name: name.trim() }) : i))
  }
  function newGroup(name) {
    if (!name.trim()) return
    save(pins.concat([{ id: "group:" + Date.now(), type: "group", name: name.trim(), apps: [] }]))
  }
  function newFolder(name, path) {
    const p = Model.folderPath(path, Quickshell.env("HOME"))
    if (!p) return false
    save(pins.concat([{ id: "folder:" + Date.now(), type: "folder", name: name.trim(), path: p }]))
    return true
  }
  function label(item) {
    if (!item) return ""
    const e = item.type === "app" ? entry(item.app) : null
    return e ? e.name : item.name || item.app || ""
  }
  function icon(item) {
    const e = item && item.type === "app" ? entry(item.app) : null
    return e ? IconFiles.source(e.icon, "application-x-executable") : ""
  }

  function claimingEntry(appId) {
    const exact = DesktopEntries.heuristicLookup(appId)
    if (exact && entry(exact.id)) return Model.appId(exact.id)
    // Omarchy's TUI launcher names terminal windows after the command, and
    // terminal wrappers can give them an explicit --app-id instead.
    for (const e of available) {
      const cmd = e.command || []
      if (cmd.indexOf("--app-id=" + appId) >= 0 || cmd.some((v, i) => v === "--app-id" && cmd[i + 1] === appId)) return Model.appId(e.id)
      if (e.runInTerminal && appId.startsWith("org.omarchy.") && String(cmd[0] || "").split("/").pop() === appId.slice(12)) return Model.appId(e.id)
    }
    return ""
  }
  readonly property var windows: {
    // Off means no window subscriptions or work for this feature.
    if (!Config.o.bar.apps.enabled) return []
    void byId
    const out = []
    for (const t of Hyprland.toplevels.values) {
      const w = t.wayland, ws = t.workspace
      if (!w || !w.appId || w.parent || !ws || (ws.id < 1 && ws.name !== "special:minimized")) continue
      const id = claimingEntry(w.appId)
      const address = Model.windowAddress(t.address)
      if (id && address) out.push({ app: id, address: address, workspaceId: ws.id, workspaceName: ws.name, toplevel: t })
    }
    return out
  }
  readonly property var items: Config.o.bar.apps.enabled
    ? Model.build(pins, Object.keys(byId), windows, Config.o.bar.apps.showRunning) : []
  function windowsFor(item) {
    if (!item) return []
    const ids = item.type === "app" ? [item.app] : item.type === "group" ? item.apps : []
    return windows.filter(w => ids.indexOf(w.app) >= 0)
  }
  function active(item) { return windowsFor(item).some(w => w.toplevel === Sys.activeToplevel) }
  function launch(app, host) {
    const e = entry(app)
    if (!e) return
    if (host && host.shell && host.shell.appLibrary) host.shell.appLibrary.launch(e.id, e.name)
    else e.execute() // Older Omarchy without AppLibrary, like the launcher.
  }
  function activate(item, host, newInstance) {
    if (!item) return
    if (item.type === "folder") {
      Qt.openUrlExternally(Model.fileUrl(item.path))
      return
    }
    if (item.type !== "app") return
    const wins = windowsFor(item)
    if (newInstance || !wins.length) { launch(item.app, host); return }
    const active = Sys.activeToplevel
    const workspace = Hyprland.focusedWorkspace
    const w = wins[Model.pickWindow(wins, active ? Model.windowAddress(active.address) : "", workspace ? workspace.id : -1)]
    if (w.workspaceName === "special:minimized" && workspace) Sys.moveWindow(w.address, String(workspace.id))
    Sys.focusWindow(w.address)
  }
}
