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

  readonly property string version: manifest && manifest.version ? manifest.version : "0.32.1"

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
  // A hosted panel's Tab (Omarchy's Ui/Panel.switchPanel): the next or
  // previous third-party panel in the plugin pill on the same screen.
  function switchPluginPanelFrom(facade, owner, direction) {
    var ownerSlot = null
    for (var i = 0; i < pluginSlots.length; i++) {
      var slot = pluginSlots[i]
      if (slot && slot.activeItem === owner) { ownerSlot = slot; break }
    }
    if (!ownerSlot) return false
    var screenName = slotScreen(ownerSlot)
    var order = panelOrder(screenName)
    var index = order.indexOf(ownerSlot.moduleName)
    if (index < 0 || order.length < 2) return false
    var next = order[(index + (direction < 0 ? -1 : 1) + order.length) % order.length]
    if (typeof owner.close === "function") owner.close()
    return openBarWidget(next, screenName)
  }

  // ------------------------------------------------------ bar contract
  //
  // The host routes every bar-widget summon through the active bar
  // (shell.qml summon / hide / isPluginOpen / togglePanelAt), so Omarchy's
  // panel hotkeys -- SUPER+CTRL+A/B/W/P, SUPER+CTRL+ALT+D, SUPER+CTRL+1..9 --
  // land here with Omarchy ids. Each maps to the Omacale popout that does
  // that job; a hosted third-party widget opens its own panel. They open on
  // the focused monitor, with the keyboard (ScreenScope.openPopoutKeys).
  // SUPER+CTRL+1..9 counts the third-party widgets only.

  property var scopes: []
  function registerScope(s) { if (scopes.indexOf(s) < 0) scopes = scopes.concat([s]) }
  function unregisterScope(s) { scopes = scopes.filter(x => x !== s) }
  function scopeFor(screenName) {
    for (const s of scopes) if (s.screen && s.screen.name === screenName) return s
    return scopes.length ? scopes[0] : null
  }

  // Omarchy id -> the Omacale popout for it. Not mapped, so their hotkeys do
  // nothing: omarchy.monitor (no Omacale display panel yet), and the clock
  // and weather (SUPER+CTRL+ALT+D) -- the dashboard has its own binds.
  // `onBar`: only while that popout's icon is on the status bar.
  readonly property var widgetTargets: ({
    "omarchy.network": { popout: "network" },
    "omarchy.bluetooth": { popout: "bluetooth" },
    "omarchy.audio": { popout: "audio", onBar: true },
    "omarchy.power": { popout: "battery" },
    "omarchy.keyboard-layout": { popout: "kblayout" },
    "omarchy.system-update": { popout: "update" },
    "omarchy.active-window": { popout: "activewindow" }
  })
  function popoutId(name) {
    for (const id in widgetTargets) if (widgetTargets[id].popout === name) return id
    return ""
  }

  function slotScreen(slot) {
    var w = slot && slot.QsWindow ? slot.QsWindow.window : null
    return w && w.screen ? w.screen.name : ""
  }
  function hostedSlot(id, screenName) {
    var fallback = null
    for (var i = 0; i < pluginSlots.length; i++) {
      var slot = pluginSlots[i]
      if (!slot || slot.moduleName !== id || !slot.activeItem) continue
      if (slotScreen(slot) === screenName) return slot
      if (!fallback) fallback = slot
    }
    return fallback
  }

  // The third-party widgets in the plugin pill that have a panel, top to
  // bottom as they are drawn on that screen.
  function panelOrder(screenName) {
    var s = scopeFor(screenName)
    if (!s) return []
    return pluginSlots.filter(slot => slot && slot.shown && slotScreen(slot) === s.screen.name
        && slot.activeItem && typeof slot.activeItem.open === "function")
      .sort((a, b) => a.mapToItem(null, 0, 0).y - b.mapToItem(null, 0, 0).y)
      .map(slot => slot.moduleName)
  }

  function openBarWidget(id, screenName) {
    var t = widgetTargets[id]
    var s = scopeFor(screenName)
    if (t && s) {
      if (t.onBar && s.statusPopouts().indexOf(t.popout) < 0) return false
      s.openPopoutKeys(t.popout)
      return true
    }
    var slot = hostedSlot(id, screenName)
    if (slot && typeof slot.activeItem.open === "function") {
      slot.activeItem.open()
      return true
    }
    return false
  }

  function summonBarWidget(id) {
    return openBarWidget(String(id || ""), focusedScreen())
  }
  function hideBarWidget(id) {
    var t = widgetTargets[id]
    if (t) {
      for (const s of scopes) if (s.popout === t.popout) s.popout = ""
      return true
    }
    var hidden = false
    for (var i = 0; i < pluginSlots.length; i++) {
      var slot = pluginSlots[i]
      if (slot && slot.moduleName === id && slot.activeItem && typeof slot.activeItem.close === "function") {
        slot.activeItem.close()
        hidden = true
      }
    }
    return hidden
  }
  function isBarWidgetOpen(id) {
    var t = widgetTargets[id]
    if (t) {
      for (const s of scopes) if (s.popout === t.popout) return true
      return false
    }
    for (var i = 0; i < pluginSlots.length; i++) {
      var slot = pluginSlots[i]
      if (slot && slot.moduleName === id && slot.activeItem && slot.activeItem.opened === true) return true
    }
    return false
  }
  // `togglePanelAt <section> <n>` (SUPER+CTRL+1..9): the nth third-party
  // widget you can see in the plugin pill (1-based), whatever the section --
  // Omacale's own popouts have their letter hotkeys. "" when there is none,
  // and the host then does nothing.
  function panelWidgetIdAt(section, index) {
    var ids = panelOrder(focusedScreen())
    var n = parseInt(index, 10)
    return n >= 1 && n <= ids.length ? ids[n - 1] : ""
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
    // The active window's details and actions (Caelestia's window info).
    function windowInfo(): void { root.toggle("windowInfo") }
    function dashboardTab(tab: string): void { root.toggle("dashboard", tab) }
    function close(): void { root.toggle("close") }
    // Any bar popout by Omacale's own name (network, bluetooth, audio,
    // battery, kblayout, lockstatus, update, activewindow), opened with the
    // keyboard on the focused monitor; again closes it.
    // SUPER+CTRL+0: the bar takes the keyboard, a cursor walks its items.
    function barFocus(): void {
      const s = root.scopeFor(root.focusedScreen())
      if (s) s.toggleBarFocus()
    }
    function popout(name: string): void {
      const s = root.scopeFor(root.focusedScreen())
      if (!s) return
      if (s.popout === name) s.popout = ""
      else s.openPopoutKeys(name)
    }
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
  // installs it if the setting is on and it is missing. Both handovers then
  // keep their clones in step with Omarchy updates (services/Handover.qml).
  readonly property bool lockHandover: LockService.installed
  readonly property bool notifHandover: NotifHandover.installed

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

  // The desktop clock's plate and the desktop visualiser blur the wallpaper
  // behind them (Caelestia's background blur options). Omarchy draws the
  // wallpaper in its own window, so the blur is Hyprland's, set the same way
  // as the frame's; the alpha floor keeps it to the plate and the bars.
  readonly property var clockCfg: Config.o.background.desktopClock
  readonly property bool clockBlur: clockCfg.background.enabled && clockCfg.background.blur
  readonly property real clockIgnoreAlpha: Math.max(0, clockCfg.background.opacity - 0.05)
  readonly property bool visBlur: Config.o.background.visualiser.blur
  function applyDesktopBlur() {
    Quickshell.execDetached(["hyprctl", "eval",
      'hl.layer_rule({ match = { namespace = "^omacale-clock$" }, blur = ' + (clockBlur ? "true" : "false") +
      ', ignore_alpha = ' + clockIgnoreAlpha.toFixed(2) + ' }); ' +
      'hl.layer_rule({ match = { namespace = "^omacale-visualiser$" }, blur = ' + (visBlur ? "true" : "false") +
      ', ignore_alpha = 0.5 })'])
  }
  onClockBlurChanged: applyDesktopBlur()
  onClockIgnoreAlphaChanged: if (clockBlur) applyDesktopBlur()
  onVisBlurChanged: applyDesktopBlur()

  Component.onCompleted: {
    thirdPartyPlugins = collectedPlugins
    if (blur) applyBlur()
    if (clockBlur || visBlur) applyDesktopBlur()
  }
  Connections {
    target: Hyprland
    function onRawEvent(e) {
      if (e.name !== "configreloaded") return
      if (root.blur) root.applyBlur()
      if (root.clockBlur || root.visBlur) root.applyDesktopBlur()
    }
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
