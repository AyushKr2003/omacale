pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The icon for a Hyprland window, with layers of fallback for the windows a
// plain class lookup gets wrong: web apps (a Chromium --app window's class is
// "chrome-<host>__<path>-Default"), TUIs (a terminal whose class says nothing
// about the program in it) and apps with custom classes.
//
// No Caelestia original. Ported from the omarchy-overview plugin
// (services/FallbackIcon.qml, OverviewWindow.iconName), plus two exact
// matches from Omarchy's own launchers: web apps by the URL their desktop
// entry opens (`omarchy-launch-webapp <url>`), TUIs by the command their
// entry runs (`xdg-terminal-exec --app-id=TUI.* -e <cmd>`).
QtObject {
  id: root

  // Omarchy's own choice of default browser / terminal, for the last layer.
  property string defaultBrowser: ""
  property string defaultTerminal: ""

  readonly property var browserIds: ["chromium", "google-chrome", "google-chrome-stable", "brave-browser", "brave",
    "microsoft-edge", "microsoft-edge-stable", "opera", "vivaldi-stable", "vivaldi", "helium", "chromium-browser"]
  readonly property var terminalIds: ["alacritty", "kitty", "com.mitchellh.ghostty", "ghostty", "foot", "footclient",
    "org.wezfurlong.wezterm", "wezterm"]
  // Words in a terminal title that are never the program in it.
  readonly property var tuiIgnored: ["bash", "zsh", "fish", "sh", "ksh", "csh", "tcsh", "nu", "nushell",
    "alacritty", "kitty", "foot", "footclient", "ghostty", "com.mitchellh.ghostty", "wezterm",
    "org.wezfurlong.wezterm", "st", "urxvt", "xterm", "terminal", "tui", "omarchy", "root", "user",
    "home", "dev", "tmp", "etc", "usr", "var", "bin", "opt", "sudo", "i", "e"]

  function norm(v) {
    let s = String(v || "").trim().toLowerCase()
    if (s.indexOf("/") >= 0) s = s.split("/").pop()
    return s.replace(/\.desktop$/, "")
  }

  function isBrowserClass(v) {
    const c = norm(v)
    return c !== "" && (c.indexOf("chrom") >= 0 || c.indexOf("brave") >= 0 || c.indexOf("vivaldi") >= 0
      || c.indexOf("microsoft-edge") >= 0 || c.indexOf("opera") >= 0 || c.indexOf("helium") >= 0
      || c.indexOf("crx_") === 0 || c.indexOf("webapp") >= 0)
  }
  function isTerminalClass(v) {
    const c = norm(v)
    return c !== "" && (c.indexOf("org.omarchy.") === 0 || c.indexOf("tui.") === 0
      || terminalIds.indexOf(c) >= 0 || ["st", "urxvt", "xterm", "rio", "konsole", "gnome-terminal"].indexOf(c) >= 0)
  }

  // "chrome-web.whatsapp.com__-Default" -> "web.whatsapp.com"; "" otherwise.
  function webappHost(cls) {
    const s = String(cls || "")
    if (!/^(chrome|brave|msedge|vivaldi|opera|helium)-/i.test(s)) return ""
    const m = s.replace(/^[a-z]+-/i, "").match(/^([a-z0-9.-]+\.[a-z]{2,})/i)
    return m ? m[1].toLowerCase() : ""
  }
  // The site's name: "web.whatsapp.com" -> "whatsapp", "discord.com" -> "discord".
  function hostName(host) {
    const parts = String(host || "").split(".").filter(p => p !== "")
    return parts.length >= 2 ? parts[parts.length - 2] : (parts[0] || "")
  }

  // --------------------------------------------------------- the index
  // Built once per change of the desktop-entry list, not per window: the
  // chain below runs for every tile in the overview.
  property int revision: 0
  property var byKey: ({})        // normalised id / name / StartupWMClass -> icon
  property var webapps: []        // { host, icon }
  property var tuis: []           // { words: [...], icon }
  property var cache: ({})    // only ever reset together with revision++

  function commandOf(e) {
    const c = e.command
    if (c && c.length !== undefined && typeof c !== "string") return Array.from(c).join(" ")
    return String(e.execString || c || "")
  }

  function rebuild() {
    const keys = {}, web = [], tui = []
    const entries = DesktopEntries.applications.values || []
    for (const e of entries) {
      if (!e) continue
      const icon = String(e.icon || "").trim()
      if (!icon) continue
      for (const k of [e.id, e.name, e.startupClass])
        if (k && keys[norm(k)] === undefined) keys[norm(k)] = icon
      const cmd = commandOf(e)
      const url = cmd.match(/(?:omarchy-launch-webapp|--app=)\s*"?(https?:\/\/[^\s"]+)/)
      if (url) {
        const host = url[1].replace(/^https?:\/\//, "").split(/[\/?#]/)[0].toLowerCase()
        if (host) web.push({ host: host, icon: icon })
      }
      if (/--app-id[= ]"?TUI\./i.test(cmd)) {
        const run = cmd.split(/\s-e\s/).slice(1).join(" ")
        const words = run.split(/[\s"'\/;&|]+/).map(w => w.toLowerCase())
          .filter(w => w.length > 1 && tuiIgnored.indexOf(w) < 0 && w !== "-c")
        if (words.length) tui.push({ words: words, icon: icon })
      }
    }
    byKey = keys
    webapps = web
    tuis = tui
    cache = {}
    revision++
  }

  function lookup(key) {
    const k = norm(key)
    if (!k) return ""
    if (byKey[k]) return byKey[k]
    const h = DesktopEntries.heuristicLookup(k)
    return h && h.icon ? String(h.icon).trim() : ""
  }
  function themed(name) {
    const n = norm(name)
    return n && Quickshell.iconPath(n, true) !== "" ? n : ""
  }

  function webappIcon(cls) {
    const host = webappHost(cls)
    if (!host) return ""
    // Exact: the entry that opens this site (sub-domains either way).
    for (const w of webapps)
      if (w.host === host || host.endsWith("." + w.host) || w.host.endsWith("." + host)) return w.icon
    const name = hostName(host)
    return lookup(name) || themed(name)
  }

  function words(s) {
    return String(s || "").trim().split(/[\s:|\-—–\/\\()[\]{}~]+/).map(t => t.toLowerCase())
      .filter(t => t.length > 1 && tuiIgnored.indexOf(t) < 0)
  }
  function tuiIcon(title, initialTitle) {
    const toks = words(initialTitle).concat(words(title))
    if (!toks.length) return ""
    // Exact: an Omarchy TUI entry whose command names this program.
    for (const t of tuis)
      for (const w of t.words)
        if (toks.indexOf(w) >= 0) return t.icon
    for (const t of toks) {
      const icon = lookup(t) || themed(t)
      if (icon) return icon
    }
    return ""
  }

  function genericIcon(cls, initialClass) {
    let list = []
    if (isTerminalClass(cls) || isTerminalClass(initialClass)) list = [defaultTerminal].concat(terminalIds)
    else if (isBrowserClass(cls) || isBrowserClass(initialClass)) list = [defaultBrowser].concat(browserIds)
    for (const id of list) {
      const icon = lookup(id)
      if (icon) return icon
    }
    return ""
  }

  // The icon name (or path) for a window's IPC object (class, initialClass,
  // title, initialTitle), "" when every layer comes up empty.
  function iconName(d) {
    if (!d) return ""
    void(revision)
    const cls = String(d.class || "").trim()
    const initialClass = String(d.initialClass || "").trim()
    const title = String(d.title || "").trim()
    const initialTitle = String(d.initialTitle || "").trim()
    const key = cls + "\u0001" + initialClass + "\u0001" + title + "\u0001" + initialTitle
    if (cache[key] !== undefined) return cache[key]

    let icon = ""
    // 1. A TUI: the program named in the terminal's title.
    if (isTerminalClass(cls) || isTerminalClass(initialClass)) icon = tuiIcon(title, initialTitle)
    // 2. A web app: the entry that opens its site, else the site's name.
    if (!icon) icon = webappIcon(cls) || webappIcon(initialClass)
    // 3-4. The class, then the initial class.
    if (!icon) icon = lookup(cls)
    if (!icon && initialClass !== cls) icon = lookup(initialClass)
    // 5. Reverse-DNS classes: "com.github.user.App" -> "app".
    if (!icon && cls.indexOf(".") > 0) {
      const last = cls.split(".").pop()
      icon = lookup(last) || themed(last)
    }
    // 6-7. The initial title, then the title up to " - App" / " | Site".
    if (!icon && initialTitle) icon = lookup(initialTitle)
    if (!icon && title) icon = lookup(title.split(/\s+[-|–—]\s+/)[0])
    // 8. A themed icon named like the window.
    if (!icon)
      for (const c of [cls, initialClass, initialTitle]) {
        if (browserIds.indexOf(norm(c)) >= 0) continue
        icon = themed(c)
        if (icon) break
      }
    // 9. The default terminal or browser for windows of that kind.
    if (!icon) icon = genericIcon(cls, initialClass)

    icon = String(icon || "").replace(/^image:\/\/icon\//, "").split("?")[0].trim()
    // Mutated in place: no change signal, so filling it from a binding doesn't
    // re-run every tile. `revision` is what invalidates.
    cache[key] = icon
    return icon
  }

  function source(d) {
    const icon = iconName(d)
    if (icon.startsWith("/")) return "file://" + icon
    if (icon.startsWith("file://") || icon.startsWith("image://") || icon.startsWith("qrc:/")) return icon
    return Quickshell.iconPath(icon, "application-x-executable")
  }

  property Connections entriesWatch: Connections {
    target: DesktopEntries.applications
    function onValuesChanged() { root.rebuild() }
  }

  property Process defaults: Process {
    running: true
    command: ["bash", "-c", "echo \"b:$(omarchy-default-browser 2>/dev/null)\"; echo \"t:$(omarchy-default-terminal 2>/dev/null)\""]
    stdout: StdioCollector {
      onStreamFinished: {
        for (const line of String(text).split("\n")) {
          if (line.startsWith("b:")) root.defaultBrowser = line.slice(2).trim()
          if (line.startsWith("t:")) root.defaultTerminal = line.slice(2).trim()
        }
        root.cache = {}
        root.revision++
      }
    }
  }

  Component.onCompleted: rebuild()
}
