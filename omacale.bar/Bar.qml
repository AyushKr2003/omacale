import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Omacale — entry point of the `omacale.bar` bar plugin. The Omarchy shell
// host injects the properties below, exactly as it does for the stock bar.
Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var barWidgetRegistry: null
  property var pluginRegistry: null
  property var barConfig: ({})
  property var shell: null
  property var manifest: null

  // Mirrors `omarchy toggle bar` so the frame hides like the stock bar.
  property bool barHidden: false
  property bool capsLock: false
  property bool numLock: false

  readonly property string version: manifest && manifest.version ? manifest.version : "0.6.0"

  signal toggleRequested(string name, string screenName, string arg)

  function focusedScreen() {
    const m = Hyprland.focusedMonitor
    return m ? m.name : (Quickshell.screens.length ? Quickshell.screens[0].name : "")
  }
  function toggle(name, arg) { toggleRequested(name, focusedScreen(), arg || "") }

  // Bundled fonts (Caelestia's Google Sans Flex and Rubik).
  FontLoader { source: Qt.resolvedUrl("assets/fonts/GoogleSansFlex.ttf") }
  FontLoader { source: Qt.resolvedUrl("assets/fonts/Rubik.ttf") }

  Variants {
    model: Quickshell.screens
    delegate: ScreenScope { host: root }
  }

  IpcHandler {
    target: "omacale"
    // Quickshell IPC needs typed arguments and return types.
    function launcher(): void { root.toggle("launcher") }
    function dashboard(): void { root.toggle("dashboard") }
    function session(): void { root.toggle("session") }
    function settings(): void { root.toggle("settings") }
    // Open settings on one page, e.g. "network" or "bluetooth".
    function settingsPage(page: string): void { root.toggle("settings", page) }
    function sidebar(): void { root.toggle("sidebar") }
    function utilities(): void { root.toggle("utilities") }
    function toggles(): void { root.toggle("utilities") }
    function dashboardTab(tab: string): void { root.toggle("dashboard", tab) }
    function close(): void { root.toggle("close") }
    // Caelestia's launcher carousels: ">wallpaper " and ">theme ".
    function wallpapers(): void { root.toggle("launcher", "wallpaper") }
    function themes(): void { root.toggle("launcher", "theme") }
  }

  // Created at startup so an old menu-route block gets cleaned up.
  readonly property string wallpapersScript: Wallpapers.script

  // Transparency: blur the Omacale layer behind translucent surfaces. This is
  // a runtime Hyprland rule (hyprctl eval) — nothing is written to
  // ~/.config/hypr, and it disappears on the next Hyprland reload.
  readonly property bool blur: Config.o.appearance.transparency.enabled
  readonly property real ignoreAlpha: Math.max(0, Config.o.appearance.transparency.layers - 0.05)
  function applyBlur() {
    Quickshell.execDetached(["hyprctl", "eval",
      'hl.layer_rule({ match = { namespace = "omacale" }, blur = ' + (blur ? "true" : "false") +
      ', ignore_alpha = ' + ignoreAlpha.toFixed(2) + ' })'])
  }
  onBlurChanged: applyBlur()
  onIgnoreAlphaChanged: if (blur) applyBlur()
  Component.onCompleted: if (blur) applyBlur()
  Connections {
    target: Hyprland
    function onRawEvent(e) { if (e.name === "configreloaded" && root.blur) root.applyBlur() }
  }

  // omarchy-toggle-bar pings this target after flipping its flag.
  IpcHandler {
    target: "omarchy.bar"
    function syncHidden(): void { hiddenProbe.running = true }
  }
  Process {
    id: hiddenProbe
    running: true
    command: ["bash", "-c", "[[ -f $HOME/.local/state/omarchy/toggles/bar-off ]] && echo yes || echo no"]
    stdout: SplitParser { onRead: line => root.barHidden = String(line).trim() === "yes" }
  }
  FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/toggles"
    watchChanges: true
    printErrors: false
    onFileChanged: hiddenProbe.running = true
  }

  // Caps / num lock (Hyprland has no event for these).
  Process {
    id: lockProbe
    command: ["hyprctl", "devices", "-j"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const k = JSON.parse(text).keyboards.find(k => k.main) || {}
          root.capsLock = !!k.capsLock
          root.numLock = !!k.numLock
        } catch (e) {}
      }
    }
  }
  Timer { interval: 1500; running: true; repeat: true; onTriggered: lockProbe.running = true }
}
