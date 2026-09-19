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
  // Settings › Style › Switcher: Omarchy's own picker routes open ours.
  readonly property bool enabled: Config.o.appearance.switcher

  property var walls: []          // [{ key: path, thumb, label }]
  property string currentWall: ""
  property var themes: []         // [{ key: name, thumb: preview, label }]
  property string currentTheme: ""

  // Re-read on every open; an unchanged list is not reassigned, so the
  // carousel is not re-centred under the cursor.
  function reload() { wallProc.running = true; themeProc.running = true }
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

  // Keep Omarchy's menu routes in step with the setting (see switcher.sh).
  function syncMenu() { Quickshell.execDetached(["bash", script, "menu", enabled ? "on" : "off"]) }
  onEnabledChanged: if (Config.loaded) syncMenu()
  property Connections configLoad: Connections {
    target: Config
    function onLoadedChanged() { if (Config.loaded) root.syncMenu() }
  }
  Component.onCompleted: if (Config.loaded) syncMenu()
}
