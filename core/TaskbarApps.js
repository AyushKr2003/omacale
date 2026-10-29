.pragma library

// Omacale's optional app section. Stored items are deliberately data only:
// desktop ids, named groups and absolute directory paths, never commands.
function list(v) {
  if (!v || typeof v === "string" || typeof v.length !== "number") return []
  return Array.from(v)
}
function text(v) { return typeof v === "string" ? v.trim() : "" }
function appId(v) { return text(v).replace(/\.desktop$/, "") }
function ids(v) { return list(v).map(appId).filter((id, i, a) => id && a.indexOf(id) === i) }
// HyprlandToplevel.address is bare hex; Sys's Lua window selectors use 0x.
function windowAddress(value) {
  const address = text(value).replace(/^0x/i, "")
  return /^[0-9a-f]+$/i.test(address) ? "0x" + address.toLowerCase() : ""
}
// Omarchy's web-app entries keep Chrome's class when the browser changes.
// Retain the full host/path/profile suffix, so apps on one site stay distinct.
function webappClass(value) {
  const match = text(value).match(/^(?:chrome|brave|msedge|vivaldi|opera|helium)-(.+__.*)$/i)
  return match ? match[1].toLowerCase() : ""
}
function folderPath(v, home) {
  const p = text(v)
  const full = p === "~" ? home : p.startsWith("~/") ? (home ? home + p.slice(1) : "") : p
  return full && full[0] === "/" && !/[\x00-\x1f\x7f]/.test(full) ? full : ""
}
function fileUrl(path) {
  // Encode path segments, including # and ?, so a filename cannot become a
  // URL fragment or query. The launcher receives one argv argument, no shell.
  return "file://" + path.split("/").map(encodeURIComponent).join("/")
}
function normalize(raw) {
  const out = [], seen = Object.create(null)
  for (const item of list(raw)) {
    if (!item || typeof item !== "object") continue
    let next
    if (item.type === "app") {
      const app = appId(item.app)
      if (!app) continue
      next = { id: "app:" + app, type: "app", app: app }
    } else if (item.type === "group" && text(item.id).startsWith("group:") && text(item.name)) {
      next = { id: text(item.id), type: "group", name: text(item.name), apps: ids(item.apps) }
    } else if (item.type === "folder" && text(item.id).startsWith("folder:") && folderPath(item.path, "")) {
      const p = folderPath(item.path, "")
      next = { id: text(item.id), type: "folder", name: text(item.name) || p.split("/").filter(Boolean).pop() || "/", path: p }
    }
    if (!next || seen[next.id]) continue
    seen[next.id] = true
    out.push(next)
  }
  return out
}
function move(raw, id, delta) {
  const out = normalize(raw), at = out.findIndex(i => i.id === id)
  if (at < 0) return out
  const to = Math.max(0, Math.min(out.length - 1, at + delta))
  out.splice(to, 0, out.splice(at, 1)[0])
  return out
}
function remove(raw, id) { return normalize(raw).filter(i => i.id !== id) }
function members(raw, groupId, app, on) {
  const id = appId(app)
  if (!id) return normalize(raw)
  return normalize(raw).map(i => {
    if (i.type !== "group" || i.id !== groupId) return i
    const apps = i.apps.filter(a => a !== id)
    return Object.assign({}, i, { apps: on ? apps.concat([id]) : apps })
  })
}
// Pinned groups claim their members: an app in a group never also appears
// as an unpinned running app. Uninstalled pins stay saved for reinstalls.
function build(raw, installed, windows, showRunning) {
  const allowed = ids(installed), pins = normalize(raw), claimed = Object.create(null), out = []
  for (const p of pins) {
    if (p.type === "app") {
      claimed[p.app] = true
      if (allowed.indexOf(p.app) >= 0) out.push(p)
    } else {
      if (p.type === "group") p.apps.forEach(id => claimed[id] = true)
      out.push(p)
    }
  }
  if (showRunning) for (const w of list(windows)) {
    if (!w || !w.app || claimed[w.app] || allowed.indexOf(w.app) < 0) continue
    claimed[w.app] = true
    out.push({ id: "app:" + w.app, type: "app", app: w.app })
  }
  return out
}
function pickWindow(windows, activeAddress, workspaceId) {
  if (!windows.length) return -1
  const active = windows.findIndex(w => w.address === activeAddress)
  if (active >= 0) return (active + 1) % windows.length
  const local = windows.findIndex(w => w.workspaceId === workspaceId)
  return local >= 0 ? local : 0
}
