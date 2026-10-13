pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import ".."

// What the dock shows: the pinned apps (Config dock.pinned, desktop ids, in
// order), then the apps with open windows that aren't pinned, each with its
// windows. No Caelestia original (Caelestia has no dock).
//
// A window belongs to the desktop entry whose id, StartupWMClass or name is
// its class (or initial class); a web app to the entry that opens its site;
// else Quickshell's heuristic lookup. A window no entry claims is an app of
// its own, keyed by class, drawn with WindowIcons' icon.
QtObject {
  id: root

  readonly property var cfg: Config.o.dock

  // ------------------------------------------------------- the index
  property var byKey: ({})   // normalised id / StartupWMClass / name -> entry
  property var webapps: []   // { host, entry }

  function rebuild() {
    const keys = {}, web = []
    for (const e of DesktopEntries.applications.values || []) {
      if (!e) continue
      for (const k of [e.id, e.startupClass, e.name])
        if (k && keys[WindowIcons.norm(k)] === undefined) keys[WindowIcons.norm(k)] = e
      const url = WindowIcons.commandOf(e).match(/(?:omarchy-launch-webapp|--app=)\s*"?(https?:\/\/[^\s"]+)/)
      if (url) {
        const host = url[1].replace(/^https?:\/\//, "").split(/[\/?#]/)[0].toLowerCase()
        if (host) web.push({ host: host, entry: e })
      }
    }
    byKey = keys
    webapps = web
  }
  property Connections entriesWatch: Connections {
    target: DesktopEntries.applications
    function onValuesChanged() { root.rebuild() }
  }
  Component.onCompleted: { rebuild(); seed() }

  function entryById(id) {
    if (!id) return null
    return byKey[WindowIcons.norm(id)] || DesktopEntries.byId(id) || null
  }

  // The desktop entry a window's IPC object belongs to, or null.
  function entryFor(d) {
    const cls = String(d.class || ""), initial = String(d.initialClass || "")
    for (const c of [cls, initial]) {
      const e = byKey[WindowIcons.norm(c)]
      if (e) return e
    }
    for (const c of [cls, initial]) {
      const host = WindowIcons.webappHost(c)
      if (!host) continue
      for (const w of webapps)
        if (w.host === host || host.endsWith("." + w.host) || w.host.endsWith("." + host)) return w.entry
    }
    // Terminals and browsers are matched exactly or not at all: a TUI or a
    // web app nobody claimed is its own app, not the terminal's or browser's.
    if (WindowIcons.isTerminalClass(cls) || WindowIcons.webappHost(cls)) return null
    if (cls.indexOf(".") > 0) {
      const e = byKey[WindowIcons.norm(cls.split(".").pop())]
      if (e) return e
    }
    return cls ? DesktopEntries.heuristicLookup(cls) : null
  }

  function iconOf(entry) {
    return IconFiles.source(String(entry && entry.icon || ""), "application-x-executable")
  }

  // ------------------------------------------------------- the list
  // Bumped on window events, since toplevels' IPC objects change in place.
  property int revision: 0
  property Connections hyprWatch: Connections {
    target: Hyprland
    function onRawEvent(e) {
      const n = e.name
      if (n === "openwindow" || n === "closewindow" || n === "movewindow" || n === "movewindowv2"
          || n === "windowtitle" || n === "windowtitlev2" || n === "activewindowv2"
          || n === "changefloatingmode" || n === "workspacev2" || n === "fullscreen") {
        if (n !== "activewindowv2" && n !== "workspacev2") Hyprland.refreshToplevels()
        refreshDebounce.restart()
      }
    }
  }
  property Timer refreshDebounce: Timer {
    interval: 120
    onTriggered: root.revision++
  }

  readonly property string activeAddress: {
    const t = Sys.activeToplevel
    return t && t.lastIpcObject ? String(t.lastIpcObject.address || "") : ""
  }

  // [{ key, entry, pinned, name, icon, windows: [{ address, title, workspace,
  // monitor, at, size }], active }]
  readonly property var items: {
    void(revision)
    const pinned = (cfg.pinned || []).slice()
    const out = [], byKeyOut = {}
    for (const id of pinned) {
      const e = entryById(id)
      if (!e) continue
      const key = "app:" + e.id
      if (byKeyOut[key]) continue
      const it = { key: key, id: e.id, entry: e, pinned: true, name: e.name, icon: iconOf(e), windows: [] }
      byKeyOut[key] = it
      out.push(it)
    }
    const vals = Hyprland.toplevels.values
    for (let i = 0; i < vals.length; i++) {
      const d = vals[i].lastIpcObject
      if (!d || !d.address || d.mapped === false) continue
      // Special workspaces (the scratchpad) are left out, as the bar does.
      const ws = d.workspace || {}
      if (ws.id < 0 && String(ws.name || "").startsWith("special:")) continue
      const e = entryFor(d)
      const key = e ? "app:" + e.id : "class:" + (d.class || d.initialClass || d.address)
      let it = byKeyOut[key]
      if (!it) {
        if (!cfg.showRunning) continue
        it = { key: key, id: e ? e.id : "", entry: e, pinned: false,
               name: e ? e.name : (d.class || d.title || ""),
               icon: e ? iconOf(e) : WindowIcons.source(d), windows: [] }
        byKeyOut[key] = it
        out.push(it)
      }
      it.windows.push({ address: String(d.address), title: String(d.title || ""), workspace: ws.id || 0, toplevel: vals[i],
                        monitor: d.monitor === undefined ? -1 : d.monitor, at: d.at, size: d.size,
                        focus: d.focusHistoryID === undefined ? 1e9 : d.focusHistoryID })
    }
    for (const it of out) {
      it.windows.sort((a, b) => a.focus - b.focus)
      it.active = it.windows.some(w => w.address === activeAddress)
    }
    return out
  }

  // --------------------------------------------------------- actions
  // As Omarchy's AppLibrary launches: through uwsm, so the app gets its own
  // unit in app-graphical.slice.
  function launch(it) {
    if (it.entry) Quickshell.execDetached(["uwsm-app", "--", "gtk-launch", it.entry.id])
  }
  // Not running: launch. One window: focus it (again: nothing). Several:
  // its most recently used one, or, while one of them is focused, the least
  // recently used: clicking again walks through them all.
  function activate(it) {
    if (!it.windows.length) { launch(it); return }
    Sys.focusWindow(it.windows[it.active ? it.windows.length - 1 : 0].address)
  }
  function closeAll(it) { for (const w of it.windows) Sys.closeWindow(w.address) }

  function isPinned(id) { return !!id && (cfg.pinned || []).indexOf(id) >= 0 }
  function setPinned(id, on) {
    if (!id) return
    const list = (cfg.pinned || []).filter(x => x !== id)
    if (on) list.push(id)
    Config.set("dock.pinned", list)
  }
  // Pin id (again) just before the pin `before`, or last without one.
  function placePin(id, before) {
    const list = (cfg.pinned || []).filter(x => x !== id)
    const at = before ? list.indexOf(before) : -1
    list.splice(at < 0 ? list.length : at, 0, id)
    Config.set("dock.pinned", list)
  }
  function movePin(id, to) {
    const list = (cfg.pinned || []).filter(x => x !== id)
    list.splice(Math.max(0, Math.min(to, list.length)), 0, id)
    Config.set("dock.pinned", list)
  }

  // The first time the dock is turned on, its pins start as the launcher's
  // favourites.
  property Connections enableWatch: Connections {
    target: root.cfg
    function onEnabledChanged() { root.seed() }
  }
  function seed() {
    if (!cfg.enabled || cfg.seeded) return
    if (!(cfg.pinned || []).length) Config.set("dock.pinned", (Config.o.launcher.favouriteApps || []).slice())
    Config.set("dock.seeded", true)
  }
}
