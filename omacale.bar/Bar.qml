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
  // Polled by Sys, which the lock screen shares.
  readonly property bool capsLock: Sys.capsLock
  readonly property bool numLock: Sys.numLock

  readonly property string version: manifest && manifest.version ? manifest.version : "0.12.7"

  signal toggleRequested(string name, string screenName, string arg)

  function focusedScreen() {
    const m = Hyprland.focusedMonitor
    return m ? m.name : (Quickshell.screens.length ? Quickshell.screens[0].name : "")
  }
  function toggle(name, arg) { toggleRequested(name, focusedScreen(), arg || "") }

  function entryId(entry) {
    return typeof entry === "string" ? entry : (entry && entry.id ? entry.id : "")
  }

  function entrySettings(entry) {
    return (entry && typeof entry === "object") ? entry : ({})
  }

  // Aggregates genuinely 3rd-party bar plugins (installed in
  // ~/.config/omarchy/plugins/) from the shell.json layout.
  // Uses the registry metadata's firstParty flag instead of a hardcoded
  // exclusion list — the shell sets firstParty=true for every stock plugin
  // under /usr/share/omarchy/shell/plugins/.
  readonly property var thirdPartyPlugins: {
    if (!barConfig || !barConfig.layout) return []
    var reg = barWidgetRegistry
    if (!reg || !reg.widgets) return []
    // Create a binding dependency on the revision counter.
    void(reg.revision)
    var layout = barConfig.layout
    var collected = []
    var seen = {}
    var sections = ["left", "center", "right"]
    for (var s = 0; s < sections.length; s++) {
      var list = Array.isArray(layout[sections[s]]) ? layout[sections[s]] : []
      for (var i = 0; i < list.length; i++) {
        var entry = list[i]
        var id = root.entryId(entry)
        if (!id || seen[id]) continue
        if (!reg.widgets[id]) continue
        // Skip first-party (stock) widgets — only show user-installed ones.
        var meta = reg.metadataFor(id)
        if (meta && meta.firstParty) continue
        seen[id] = true
        collected.push(entry)
      }
    }
    return collected
  }

  // Facade cache for plugins
  property var pluginFacades: ({})
  function pluginBarFacadeFor(id) {
    var key = String(id || "")
    if (!pluginFacades[key]) {
      var comp = Qt.createComponent("PluginBarFacade.qml")
      if (comp.status === Component.Ready) {
        pluginFacades[key] = comp.createObject(root, { host: root, moduleName: key })
      }
    }
    return pluginFacades[key]
  }

  // Popout coordination
  property var activePopout: null
  function requestPopout(owner) {
    if (activePopout === owner) return
    if (activePopout) {
      if ("closeForPopoutSwitch" in activePopout) activePopout.closeForPopoutSwitch()
      else if ("close" in activePopout) activePopout.close()
    }
    activePopout = owner
  }
  function releasePopout(owner) {
    if (activePopout === owner) activePopout = null
  }

  // Tooltip tracking
  property var tooltipTarget: null
  property var pendingTooltipTarget: null
  property string tooltipText: ""
  property string pendingTooltipText: ""
  property bool tooltipShown: false
  property int tooltipRequest: 0

  function clearTooltip() {
    tooltipTimer.stop()
    pendingTooltipTarget = null
    pendingTooltipText = ""
    tooltipTarget = null
    tooltipText = ""
    tooltipShown = false
  }

  function showTooltip(target, text) {
    clearTooltip()
    if (!target || !text) return
    var req = ++tooltipRequest
    pendingTooltipTarget = target
    pendingTooltipText = text
    Qt.callLater(function() {
      if (req !== tooltipRequest) return
      tooltipTarget = pendingTooltipTarget
      tooltipText = pendingTooltipText
      pendingTooltipTarget = null
      pendingTooltipText = ""
      tooltipTimer.restart()
    })
  }

  function hideTooltip(target) {
    if (tooltipTarget !== target && pendingTooltipTarget !== target) return
    tooltipRequest++
    clearTooltip()
  }

  Timer {
    id: tooltipTimer
    interval: 350
    repeat: false
    onTriggered: {
      if (root.tooltipTarget && root.tooltipTarget.visible) root.tooltipShown = true
      else root.clearTooltip()
    }
  }

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
    function overview(): void { root.toggle("overview") }
    function toggles(): void { root.toggle("utilities") }
    function dashboardTab(tab: string): void { root.toggle("dashboard", tab) }
    function close(): void { root.toggle("close") }
    // Caelestia's launcher carousels: ">wallpaper " and ">theme ".
    // Settings › Keybinds › Picker picks the launcher carousel or Omarchy's
    // own menu, so one bind follows the setting without being rewritten.
    function wallpapers(): void {
      if (Config.o.launcher.wallpaperPicker === "omarchy") Sys.run("omarchy-menu toggle background")
      else root.toggle("launcher", "wallpaper")
    }
    function themes(): void {
      if (Config.o.launcher.themePicker === "omarchy") Sys.run("omarchy-menu toggle theme")
      else root.toggle("launcher", "theme")
    }
    // The Omarchy menu, walked inside the launcher (the ":" prefix).
    function menu(): void { root.toggle("launcher", "menu") }
  }

  // Created at startup so an old menu-route block gets cleaned up.
  readonly property string wallpapersScript: Wallpapers.script

  // Likewise: LockService checks the lock-screen handover at startup, and
  // installs it if the setting is on and it is missing.
  readonly property bool lockHandover: LockService.installed

  // Transparency: blur the Omacale layer behind translucent surfaces. This is
  // a runtime Hyprland rule (hyprctl eval) — nothing is written to
  // ~/.config/hypr, and it disappears on the next Hyprland reload.
  readonly property bool blur: Config.o.appearance.transparency.enabled
  readonly property real ignoreAlpha: Math.max(0, Config.o.appearance.transparency.layers - 0.05)
  // The toasts are a second surface (overlay layer, so a fullscreen window
  // can't cover them), and they take the same translucent surface colours as
  // the frame -- so they need the same blur behind them.
  function applyBlur() {
    Quickshell.execDetached(["hyprctl", "eval",
      'hl.layer_rule({ match = { namespace = "^omacale(-notifications)?$" }, blur = ' + (blur ? "true" : "false") +
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

}
