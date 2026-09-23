pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import ".."

// KbService: the keyboard layouts behind the bar's kbLayout icon and popout.
// Port of Caelestia's bar/popouts/kblayout/KbLayoutModel.qml and the layout
// half of services/Hypr.qml (kbMap, kbLayout, kbLayoutFull).
//
// Omarchy has no layout command, so this reads Hyprland: the configured list
// from `getoption input:kb_layout` (falling back to the main keyboard's
// `layout`), the active one from the main keyboard in `devices`, re-read on
// Hyprland's `activelayout` event rather than polled, and it switches with
// `switchxkblayout`. Names come from xkeyboard-config's base.lst, which has
// both the layout and variant descriptions (Caelestia reads base.xml through
// xmllint for the popout; the .lst serves both without the extra tool).
Singleton {
  id: root

  // [{ index, token, code, label }], deduplicated as Caelestia's _setLayouts.
  property var layouts: []
  property int activeIndex: -1
  // Hyprland's active_keymap, e.g. "English (US)".
  property string activeKeymap: ""
  readonly property string activeLabel: activeIndex >= 0 && activeIndex < layouts.length ? layouts[activeIndex].label : ""
  // Caelestia Hypr.kbLayout: the active keymap's code, e.g. "us".
  readonly property string code: descToCode[activeKeymap]
    || (activeIndex >= 0 && activeIndex < layouts.length ? layouts[activeIndex].code : "??")

  // base.lst: layout code -> description, and description -> code for both
  // layouts and variants (Caelestia's kbMap).
  property var codeToDesc: ({})
  property var descToCode: ({})

  function refresh() { layoutOpt.running = true }
  function switchTo(index) {
    if (index < 0 || index > 3) return   // XKB holds at most 4 layouts
    switcher.command = ["hyprctl", "switchxkblayout", "all", String(index)]
    switcher.running = true
  }

  // Caelestia _short: "German (Austria)" -> "German (AU)".
  function shortDesc(desc) {
    const m = desc.match(/^(.*)\((.*)\)$/)
    if (!m) return desc
    const region = m[2].trim()
    return m[1].trim() + " (" + (region.split(/[,\s-]/)[0] || region).slice(0, 2).toUpperCase() + ")"
  }
  // Caelestia _pretty: "US - English (US)".
  function pretty(token) {
    const code = token.replace(/\(.*\)$/, "").trim()
    return code.toUpperCase() + " - " + (codeToDesc[code] ? shortDesc(codeToDesc[code]) : code)
  }
  function setLayouts(raw) {
    const seen = new Set()
    const next = []
    for (const p of raw.split(",").map(s => s.trim()).filter(Boolean)) {
      if (seen.has(p)) continue
      seen.add(p)
      next.push({ index: next.length, token: p, code: p.replace(/\(.*\)$/, "").trim(), label: pretty(p) })
    }
    layouts = next
  }
  function mainKeyboard(text) {
    const kbs = JSON.parse(text).keyboards || []
    return kbs.find(k => k.main) || kbs[0] || null
  }

  property FileView rules: FileView {
    path: "/usr/share/X11/xkb/rules/base.lst"
    onLoaded: {
      const text = root.rules.text()
      const toDesc = {}, toCode = {}
      const layoutSec = text.match(/! layout\n([\s\S]*?)\n\n/)
      if (layoutSec) for (const line of layoutSec[1].split("\n")) {
        const m = line.match(/^\s*([a-z]{2,})\s+(.+)$/)
        if (m) { toDesc[m[1]] = m[2].trim(); toCode[m[2].trim()] = m[1] }
      }
      const variantSec = text.match(/! variant\n([\s\S]*?)\n\n/)
      if (variantSec) for (const line of variantSec[1].split("\n")) {
        const m = line.match(/^\s*([a-zA-Z0-9_-]+)\s+([a-z]{2,}): (.+)$/)
        if (m) toCode[m[3].trim()] = m[2]
      }
      root.codeToDesc = toDesc
      root.descToCode = toCode
      // Labels built before the names arrived.
      if (root.layouts.length) root.setLayouts(root.layouts.map(l => l.token).join(","))
    }
  }

  property Process layoutOpt: Process {
    command: ["hyprctl", "-j", "getoption", "input:kb_layout"]
    stdout: StdioCollector {
      onStreamFinished: {
        let raw = ""
        try { const j = JSON.parse(text); raw = String(j.str || j.value || "").trim() } catch (e) {}
        if (raw) { root.setLayouts(raw); root.devices.fallback = false }
        else root.devices.fallback = true
        root.devices.read()
      }
    }
  }

  // The active layout, and the layout list when getoption had none.
  property Process devices: Process {
    property bool fallback: false
    // An `activelayout` event that lands mid-read asks for one more.
    property bool again: false
    function read() { if (running) again = true; else running = true }
    onRunningChanged: if (!running && again) { again = false; running = true }
    command: ["hyprctl", "-j", "devices"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const kb = root.mainKeyboard(text)
          if (!kb) return
          if (root.devices.fallback && kb.layout) root.setLayouts(String(kb.layout))
          root.activeIndex = kb.active_layout_index ?? -1
          root.activeKeymap = kb.active_keymap || ""
        } catch (e) {
          root.activeIndex = -1
          root.activeKeymap = ""
        }
      }
    }
  }

  property Process switcher: Process {
    onExited: root.devices.read()
  }

  property Connections hypr: Connections {
    target: Hyprland
    function onRawEvent(e) {
      if (e.name === "activelayout") root.devices.read()
      else if (e.name === "configreloaded") root.refresh()
    }
  }

  Component.onCompleted: refresh()
}
