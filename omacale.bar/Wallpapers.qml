pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Caelestia services/Wallpapers.qml (+ the launcher's Schemes service), backed
// by Omarchy: the current theme's backgrounds (omarchy-theme-bg-set) and the
// installed themes (omarchy-theme-set). Lists come from scripts/switcher.sh.
QtObject {
  id: root

  readonly property string script: Qt.resolvedUrl("scripts/switcher.sh").toString().replace("file://", "")
  property var walls: []          // [{ key: path, thumb, label }]
  property string currentWall: ""
  property var themes: []         // [{ key: name, thumb: preview, label }]
  property string currentTheme: ""

  // Re-read on every open; an unchanged list is not reassigned, so the
  // carousel is not re-centred under the cursor. A reload asked for while one
  // is running runs again after it, so a theme switch is never missed.
  property bool reloadPending: false
  function reload() {
    if (wallProc.running || themeProc.running) { reloadPending = true; return }
    wallProc.running = true
    themeProc.running = true
  }
  function reloadDone() {
    if (reloadPending && !wallProc.running && !themeProc.running) { reloadPending = false; reload() }
  }

  // The backgrounds belong to the current Omarchy theme: re-list them when it
  // changes, even with the carousel open. Debounced, as omarchy-theme-set
  // writes theme.name before it has finished swapping the theme directory.
  property FileView themeWatcher: FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme.name"
    watchChanges: true
    printErrors: false
    onFileChanged: { root.reload(); root.themeTimer.restart() }
  }
  property Timer themeTimer: Timer { interval: 800; onTriggered: root.reload() }
  function url(path) { return path ? "file://" + path.split("/").map(encodeURIComponent).join("/") : "" }
  // Thumbnail of the current background (videos have no image of their own).
  readonly property string currentThumb: {
    const w = walls.find(x => x.key === currentWall)
    return w ? w.thumb : isVideo(currentWall) ? "" : currentWall
  }
  function isVideo(path) { return /\.(mp4|m4v|mov|webm|mkv|avi)$/i.test(path) }
  function label(path) { return path.split("/").pop().replace(/\.[^.]+$/, "").replace(/^\d+-/, "").replace(/[-_]/g, " ") }

  // Live preview on the Omarchy background while the carousel scrolls, as
  // Caelestia's Wallpapers.preview. Videos are skipped: decoding one per step
  // is too heavy. The debounce keeps a fast scroll to one IPC call.
  property string previewPath: ""
  function preview(path) {
    if (isVideo(path) || path === previewPath) return
    previewPath = path
    previewTimer.restart()
  }
  function stopPreview() {
    previewTimer.stop()
    if (previewPath && previewPath !== currentWall && currentWall)
      Quickshell.execDetached(["omarchy-shell", "-q", "background", "set", currentWall])
    previewPath = ""
  }
  property Timer previewTimer: Timer {
    interval: 120
    onTriggered: if (root.previewPath) Quickshell.execDetached(["omarchy-shell", "-q", "background", "set", root.previewPath])
  }

  function setWallpaper(path) {
    previewTimer.stop()
    previewPath = ""
    currentWall = path
    Quickshell.execDetached(["omarchy-theme-bg-set", path])
  }
  function setTheme(name) {
    currentTheme = name
    Quickshell.execDetached(["bash", "-c", 'omarchy-theme-set "$1" >/dev/null 2>&1', "theme-set", name])
  }

  property Process wallProc: Process {
    command: ["bash", root.script, "walls"]
    onExited: root.reloadDone()
    stdout: StdioCollector {
      onStreamFinished: {
        const out = []
        for (const line of text.split("\n")) {
          if (line.startsWith("current:")) { root.currentWall = line.slice(8); continue }
          const [path, thumb] = line.split("\t")
          if (path) out.push({ key: path, thumb: thumb || path, label: root.label(path) })
        }
        if (JSON.stringify(out) !== JSON.stringify(root.walls)) root.walls = out
      }
    }
  }
  property Process themeProc: Process {
    command: ["bash", root.script, "themes"]
    onExited: root.reloadDone()
    stdout: StdioCollector {
      onStreamFinished: {
        const out = []
        for (const line of text.split("\n")) {
          if (line.startsWith("current:")) { root.currentTheme = line.slice(8); continue }
          const [name, lbl, preview] = line.split("\t")
          if (name) out.push({ key: name, thumb: preview || "", label: lbl || name })
        }
        if (JSON.stringify(out) !== JSON.stringify(root.themes)) root.themes = out
      }
    }
  }

  // Omacale no longer touches Omarchy's menu; drop the route block an older
  // version may have left in omarchy-menu.jsonc (a no-op when there is none).
  Component.onCompleted: Quickshell.execDetached(["bash", script, "menu", "off"])
}
