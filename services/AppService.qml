pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// The installed-application list, filtered exactly as Omarchy filters its own.
//
// Quickshell's DesktopEntries only exposes `noDisplay`, so Omacale listed
// entries the Omarchy menu never shows. Omarchy's AppLibrary drops three more
// classes of entry: `Hidden=true`, an `OnlyShowIn` that does not name this
// desktop, and a `NotShowIn` that does -- which is what hides the GNOME/KDE
// -only entries that were showing up in the launcher.
//
// Per the engine rule, none of that is reimplemented here: this runs Omarchy's
// own `shell/services/hidden-entries.sh` and reads its own `launcher.hides`,
// so the two lists cannot drift when Omarchy changes the rules.
QtObject {
  id: root

  readonly property string omarchyPath: Quickshell.env("OMARCHY_PATH") || "/usr/share/omarchy"

  // Desktop ids Omarchy hides. Kept as maps so lookup stays O(1) over a list
  // that is rebuilt on every keystroke in the launcher.
  property var desktopHidden: ({})     // from hidden-entries.sh
  property var configuredHidden: ({})  // from default/omarchy/launcher.hides

  function normalizeId(id) {
    let v = String(id || "").trim()
    if (v.slice(-8) === ".desktop") v = v.slice(0, -8)
    return v
  }

  // Omarchy's AppLibrary.isHiddenEntry, plus the noDisplay that Quickshell
  // already gives us.
  function hiddenByOmarchy(entry) {
    if (!entry || entry.noDisplay) return true
    const id = root.normalizeId(entry.id)
    return root.desktopHidden[id] === true || root.configuredHidden[id] === true
  }

  // Everything Omarchy would show. Settings › Apps › All apps lists this, so
  // an app Omacale itself hides is still reachable there to be un-hidden.
  readonly property var entries: {
    // Touch both maps so the binding re-runs when a scan lands.
    root.desktopHidden; root.configuredHidden
    return (DesktopEntries.applications.values || []).filter(e => !root.hiddenByOmarchy(e))
  }

  // What the launcher and the menu list: the above, minus Omacale's own
  // hidden-apps setting.
  readonly property var launchable: {
    const own = (Config.o.launcher && Config.o.launcher.hiddenApps) || []
    return root.entries.filter(e => own.indexOf(e.id) < 0)
  }

  function loadIds(rawText) {
    const next = ({})
    const lines = String(rawText || "").split(/\n/)
    for (let i = 0; i < lines.length; i++) {
      const id = root.normalizeId(lines[i])
      if (id.length > 0) next[id] = true
    }
    return next
  }

  property string _scanOut: ""

  // Omarchy's warning, which applies verbatim here: this must run in a
  // non-login shell. A login shell sources the user's profile, and tools like
  // mise touch ~/.local/share on activation -- a directory the desktop-entry
  // watcher monitors -- so every scan would trigger the next one and pin a
  // core at idle. The argv form below never reads a profile.
  property Process scan: Process {
    command: ["bash", root.omarchyPath + "/shell/services/hidden-entries.sh",
      [Quickshell.env("XDG_CURRENT_DESKTOP"), Quickshell.env("XDG_SESSION_DESKTOP"), Quickshell.env("DESKTOP_SESSION")]
        .filter(v => String(v || "").length > 0).join(":")]
    stdout: SplitParser { onRead: line => root._scanOut += line + "\n" }
    onStarted: root._scanOut = ""
    // A missing or failed Omarchy leaves the map empty, which degrades to the
    // old noDisplay-only list rather than to an empty launcher.
    onExited: root.desktopHidden = root.loadIds(root._scanOut)
  }

  property FileView hides: FileView {
    path: root.omarchyPath + "/default/omarchy/launcher.hides"
    watchChanges: true
    printErrors: false
    onLoaded: root.configuredHidden = root.loadIds(text())
    onFileChanged: root.configuredHidden = root.loadIds(text())
    onLoadFailed: root.configuredHidden = ({})
  }

  // Omarchy rescans on the same signal: an install or removal changes the set
  // of .desktop files, and their OnlyShowIn/NotShowIn can only be read off disk.
  property Connections appsConn: Connections {
    target: DesktopEntries.applications
    function onValuesChanged() { root.scan.running = true }
  }

  Component.onCompleted: scan.running = true
}
