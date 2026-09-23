import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Commons

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

  readonly property string version: manifest && manifest.version ? manifest.version : "0.20.0"

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
  readonly property var collectedPlugins: {
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
  // The list the pill's Repeater uses, reassigned only when it really changes.
  // The registry bumps its revision for every (re)registration -- each plugin
  // on start, all of them on a plugin reload -- and a new array makes the
  // Repeater destroy and rebuild every widget, popups and state included.
  property var thirdPartyPlugins: []
  onCollectedPluginsChanged: {
    var next = collectedPlugins
    if (JSON.stringify(next) !== JSON.stringify(thirdPartyPlugins)) thirdPartyPlugins = next
  }

  // Omarchy widgets draw their mark in Style.bar.iconCanvas (16px) with a
  // 13px glyph; Omacale's status icons are Material glyphs at iconSize.small
  // (15pt = a 20px em). Hosted widgets are laid out in Omarchy's units and
  // scaled by this, so a plugin's canvas lands on a status icon's em and every
  // mark in the bar reads at one size. pluginBarSize is the pill's breadth in
  // those units: what a vertical widget is told the bar is.
  readonly property real pluginIconScale: (Tk.iconSize.small * 4 / 3) / Math.max(1, Style.bar.iconCanvas)
  readonly property int pluginBarSize: Math.floor(Tk.barInner / pluginIconScale)

  // Slots exist once per output. Keep a host-level list so widgets that use
  // BarWidget.broadcast() receive every live instance, like they do on the
  // stock Omarchy bar.
  property var pluginSlots: []
  property var pluginPopoutOwners: ({})

  function registerPluginSlot(slot) {
    if (!slot || pluginSlots.indexOf(slot) >= 0) return
    pluginSlots = pluginSlots.concat([slot])
  }
  function unregisterPluginSlot(slot) {
    pluginSlots = pluginSlots.filter(function(candidate) { return candidate && candidate !== slot })
  }
  function moduleWidgets(id) {
    var key = String(id || "")
    if (!key) return []
    var widgets = []
    for (var i = 0; i < pluginSlots.length; i++) {
      var slot = pluginSlots[i]
      if (slot && slot.moduleName === key && slot.activeItem) widgets.push(slot.activeItem)
    }
    return widgets
  }
  function registerPluginClickTarget(facade, target) {
    if (!facade || !target) return
    var targets = facade.clickTargets || []
    if (targets.indexOf(target) < 0) facade.clickTargets = targets.concat([target])
  }
  function unregisterPluginClickTarget(facade, target) {
    if (!facade) return
    facade.clickTargets = (facade.clickTargets || []).filter(function(candidate) { return candidate && candidate !== target })
  }
  function requestPluginPopout(facade, owner) {
    if (!facade || !owner) return
    pluginPopoutOwners[facade.moduleName] = owner
    requestPopout(owner)
  }
  function releasePluginPopout(facade, owner) {
    if (!facade) return
    if (pluginPopoutOwners[facade.moduleName] === owner) delete pluginPopoutOwners[facade.moduleName]
    releasePopout(owner)
  }
  function pluginOwnsPopout(facade, owner) {
    return !!facade && pluginPopoutOwners[facade.moduleName] === owner
  }
  function targetBelongsToWindow(target, window) {
    return !!target && !!window && target.QsWindow && target.QsWindow.window === window
  }
  function switchPluginPanelFrom(facade, owner, direction) {
    var ownerSlot = null
    for (var i = 0; i < pluginSlots.length; i++) {
      var slot = pluginSlots[i]
      if (slot && slot.activeItem === owner) { ownerSlot = slot; break }
    }
    if (!ownerSlot) return false
    var window = ownerSlot.QsWindow ? ownerSlot.QsWindow.window : null
    var candidates = pluginSlots.filter(function(slot) {
      return slot && slot.shown && slot.activeItem
        && (!window || !slot.QsWindow || slot.QsWindow.window === window)
    })
    if (!candidates.length) return false
    var index = candidates.indexOf(ownerSlot)
    if (index < 0) return false
    var next = candidates[(index + (direction < 0 ? -1 : 1) + candidates.length) % candidates.length]
    if (!next || next === ownerSlot || !next.activeItem || typeof next.activeItem.open !== "function") return false
    next.activeItem.open()
    return true
  }
  // Service cache for hosted 3rd-party plugins that require a companion service.
  // Avoid reassigning the property to prevent declarative binding loops in hosted panels.
  QtObject {
    id: serviceStore
    property var instances: ({})
  }

  function hostedServiceFor(pluginId) {
    var key = String(pluginId || "")
    if (!key) return null
    if (serviceStore.instances[key]) return serviceStore.instances[key]

    var reg = root.barWidgetRegistry
    var meta = reg && typeof reg.metadataFor === "function" ? reg.metadataFor(key) : null
    var sourceDir = meta && meta.sourceDir ? meta.sourceDir : ""
    if (!sourceDir) {
      sourceDir = Quickshell.env("HOME") + "/.config/omarchy/plugins/" + key
    }
    var serviceUrl = "file://" + sourceDir + "/Service.qml"
    var comp = Qt.createComponent(serviceUrl)
    if (comp.status === Component.Ready) {
      var inst = comp.createObject(root, {
        shell: root.shell,
        manifest: meta
      })
      if (inst) {
        serviceStore.instances[key] = inst
        return inst
      }
    } else if (comp.status === Component.Error) {
      console.warn("omacale: failed to create hosted service for", key, comp.errorString())
    }
    return null
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
  Component.onCompleted: {
    thirdPartyPlugins = collectedPlugins
    if (blur) applyBlur()
  }
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
