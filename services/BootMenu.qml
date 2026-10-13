pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import ".."

// Settings › Boot menu: the look of the Limine boot menu. The page edits
// `boot.*` in Omacale's settings; nothing reaches /boot until Apply, which
// runs scripts/limine-style as root through pkexec (Omarchy's polkit agent
// asks the password). That script is the only part allowed to touch the
// bootloader, and it does so only within its own safety rules (see it).
QtObject {
  id: root

  readonly property string script: Qt.resolvedUrl("../scripts/limine-style").toString().replace("file://", "")
  readonly property var cfg: Config.o.boot

  // What the page sends: limine-style's fields, from the settings.
  readonly property var fields: {
    const c = cfg
    const f = {
      branding: c.branding.trim() || "Omarchy Bootloader",
      brandingColor: c.brandingColor, helpColor: c.brandingColor,
      foreground: c.foreground, background: c.background,
      // The page's 0-100 % transparency as Limine's TT byte.
      backgroundAlpha: Math.round(Math.max(0, Math.min(100, c.backgroundAlpha)) * 2.55),
      timeout: c.timeout > 0 ? c.timeout : null,
      rememberLast: c.rememberLast, hideHelp: c.hideHelp,
      margin: c.marginCustom ? c.margin : null,
      marginGradient: c.marginCustom ? Math.min(c.marginGradient, c.margin) : null,
      fontScale: c.fontScale || null,
      wallpaper: c.wallpaper
    }
    if (c.wallpaper) { f.wallpaperStyle = c.wallpaperStyle; f.backdrop = c.backdrop }
    return f
  }
  readonly property string fieldsJson: JSON.stringify(fields)
  readonly property bool applied: cfg.applied !== ""
  readonly property bool dirty: fieldsJson !== cfg.applied

  property bool busy: false
  property string message: ""
  property bool failed: false

  // Each field a valid value, as limine-style checks again: Apply stays off
  // rather than ask a password for something it would refuse.
  readonly property bool valid: {
    const hex = v => /^[0-9a-fA-F]{6}$/.test(v)
    const f = fields
    return hex(f.brandingColor) && hex(f.foreground) && hex(f.background)
      && (!f.wallpaper || hex(f.backdrop)) && f.branding.length <= 64
      && !/[\x00-\x1f\x7f]/.test(f.branding)
  }

  function apply() { run(["apply", fieldsJson], fieldsJson, "Applied. You'll see it the next time you start the computer.") }
  // What is on /boot after an undo is no longer what the page shows.
  function undo() { run(["undo"], "", "The previous boot menu is back.") }
  function restoreDefault() { run(["restore-default"], "", "Omarchy's boot menu is back.") }

  // The theme's own colours, as Omarchy's template takes Tokyo Night's.
  function fromTheme() {
    const h = c => String(c).replace("#", "").slice(-6)
    Config.set("boot.brandingColor", h(Color.accent))
    Config.set("boot.foreground", h(Color.foreground))
    Config.set("boot.background", h(Color.background))
    Config.set("boot.backdrop", h(Color.background))
  }

  property var pendingApplied: null
  property string pendingMessage: ""
  function run(args, appliedAfter, okMessage) {
    if (busy) return
    busy = true; failed = false; message = "Waiting for your password..."
    pendingApplied = appliedAfter
    pendingMessage = okMessage
    proc.command = ["pkexec", "/usr/bin/python3", "-I", script].concat(args)
    proc.running = true
  }

  property Process proc: Process {
    stdout: StdioCollector { id: out }
    stderr: StdioCollector { id: err }
    onExited: code => {
      root.busy = false
      if (code === 0) {
        root.failed = false
        root.message = root.pendingMessage
        if (root.pendingApplied !== null) Config.set("boot.applied", root.pendingApplied)
      } else if (code === 126 || code === 127) {
        // pkexec: the password prompt was dismissed or failed. Nothing ran.
        root.failed = false
        root.message = "Not applied: the password wasn't given. Nothing changed."
      } else {
        root.failed = true
        const why = (err.text || out.text || "").trim().split("\n").pop()
        root.message = (code === 4 ? "Nothing changed: " : "Didn't work: ") + (why || "exit " + code)
      }
    }
  }
}
