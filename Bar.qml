import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons
import "core/Screens.js" as Screens

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

  // The edge the bar is on, which the host (`shell.bar.position`, read for the
  // plugin bar state and by KeyboardPanel / PopupCard) and every hosted widget
  // (`bar.position` / `bar.vertical`) are told. Omacale's own setting; "omarchy"
  // follows the position Omarchy's Style > Bar > Position writes to shell.json.
  readonly property string position: {
    const p = Config.o.bar.position
    const edges = ["left", "right", "top", "bottom"]
    if (p === "omarchy") {
      const o = barConfig ? barConfig.position : ""
      return edges.indexOf(o) >= 0 ? o : "top"
    }
    return edges.indexOf(p) >= 0 ? p : "left"
  }
  readonly property bool vertical: position === "left" || position === "right"
  // Settings, the carousels and the style preview open on the focused screen:
  // its bar's edge.
  Binding {
    target: Tk; property: "barEdge"
    value: Screens.edgeFor(Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "", Screens.positionsFrom(Config.o.bar.screenPositions), root.position)
  }
  // The bar's breadth in px, for the host (Omarchy's notification service sizes
  // itself around a visible bar with it).
  readonly property int barSize: barHidden ? 0 : Tk.barWidth
  // Polled by Sys, which the lock screen shares.
  readonly property bool capsLock: Sys.capsLock
  readonly property bool numLock: Sys.numLock

  readonly property string version: manifest && manifest.version ? manifest.version : "0.55.1"

  signal toggleRequested(string name, string screenName, string arg)

  function focusedScreen() {
    const m = Hyprland.focusedMonitor
    return m ? m.name : (Quickshell.screens.length ? Quickshell.screens[0].name : "")
  }
  // Where something of the bar's opens from a key: the focused screen, or the
  // nearest one that has a bar when that one has none (Settings › Taskbar ›
  // Screens).
  function barScreen() {
    return Screens.barScreen(focusedScreen(), Config.o.bar.excludedScreens, Quickshell.screens.map(s => s.name))
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

  // Every bar widget the shell has loaded (Omarchy's own included), as
  // [{ id, firstParty, name, enabled }]: what a widget of its own in
  // bar.layout can be. Read from the registry, so a widget a later Omarchy
  // adds is here without Omacale knowing it. Omarchy registers its own
  // widgets whether they are on or not; on means in its bar layout
  // (shell.json, what `omarchy plugin enable` adds to), which is all a
  // custom bar is shown of the plugin registry.
  readonly property var omarchyLayoutIds: {
    var layout = barConfig && barConfig.layout ? barConfig.layout : {}
    return ["left", "center", "right"].reduce((out, s) =>
      out.concat((Array.isArray(layout[s]) ? layout[s] : []).map(e => root.entryId(e))), [])
  }
  readonly property var registryWidgets: {
    var reg = barWidgetRegistry
    if (!reg || !reg.widgets) return []
    void(reg.revision)
    var on = omarchyLayoutIds
    return Object.keys(reg.widgets).sort().map(id => {
      var meta = reg.metadataFor(id) || {}
      return { id: id, firstParty: !!meta.firstParty, name: meta.displayName ? String(meta.displayName) : id,
        enabled: on.indexOf(id) >= 0 }
    })
  }
  property var widgetIds: []
  onRegistryWidgetsChanged: {
    // Only widgets that are on are drawn: one turned off leaves its place.
    var ids = registryWidgets.filter(w => w.enabled).map(w => w.id)
    if (JSON.stringify(ids) !== JSON.stringify(widgetIds)) widgetIds = ids
    adoptTimer.restart()
  }
  // The hosted entry for a widget: its shell.json entry (with its settings)
  // when Omarchy's layout has one, else a bare { id }.
  function widgetEntry(id) {
    if (!id || widgetIds.indexOf(id) < 0) return null
    var layout = barConfig && barConfig.layout ? barConfig.layout : {}
    var sections = ["left", "center", "right"]
    for (var s = 0; s < sections.length; s++) {
      var list = Array.isArray(layout[sections[s]]) ? layout[sections[s]] : []
      for (var i = 0; i < list.length; i++)
        if (entryId(list[i]) === id) return list[i]
    }
    return { id: id }
  }
  Connections {
    target: PluginService
    function onAdoptRequested() { adoptTimer.restart() }
  }
  // New widgets go on the bar (PluginService.adoptWidgets). The registry
  // fills in one widget at a time while the shell starts: wait for it to settle.
  Timer {
    id: adoptTimer
    interval: 3000
    // An empty registry is a shell still starting (or reloading plugins),
    // not one without widgets: adopting then would mark nothing seen.
    onTriggered: {
      if (!root.registryWidgets.length) return
      PluginService.adoptWidgets(root.registryWidgets, root.omarchyLayoutIds)
      PluginService.moveUnpinned()
    }
  }

  // Omarchy widgets draw their mark in Style.bar.iconCanvas (16px) with a
  // 13px glyph; Omacale's status icons are Material glyphs at iconSize.small
  // (15pt = a 20px em). Hosted widgets are laid out in Omarchy's units and
  // scaled by this, so a plugin's canvas lands on a status icon's em and every
  // mark in the bar reads at one size. pluginBarSize is the pill's breadth in
  // those units: what a vertical widget is told the bar is.
  readonly property real pluginIconScale: (Tk.iconSize.small * 4 / 3) / Math.max(1, Style.bar.iconCanvas)
  readonly property int pluginBarSize: Math.floor(Tk.barInner / pluginIconScale)

  // A hosted widget's buttons call their `bar` while they are destroyed
  // (WidgetButton hides its tooltip), and by then the slot's own facade has
  // lost its QML context ("evaluate a function in an invalid context"). A
  // slot on its way out hands its widget one of these instead: made here, so
  // it outlives the slot; it still releases the popout and click targets the
  // widget held through the old facade, and does nothing else. Gone a few
  // seconds later.
  Component {
    id: retiredFacade
    PluginBarFacade {
      property var original: null
      function requestPopout(owner) {}
      function releasePopout(owner) { _call("releasePluginPopout", [original, owner]) }
      function registerClickTarget(target) {}
      function unregisterClickTarget(target) { _call("unregisterPluginClickTarget", [original, target]) }
      function showTooltip(target, text) {}
    }
  }
  function retireFacade(facade, name) {
    const r = retiredFacade.createObject(root, { host: root, moduleName: String(name || ""), original: facade })
    if (r) r.destroy(5000)
    return r
  }

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
    "omarchy.active-window": { popout: "activewindow" },
    // SUPER+CTRL+D (Omarchy's "Display"): Settings › Display.
    "omarchy.monitor": { settings: "display" }
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

  // The hosted widgets with a panel (in the plugin pill or placed on their
  // own, Omarchy's included), in the order they are drawn on that screen: top
  // to bottom on a column, left to right on a row.
  function panelOrder(screenName) {
    var s = scopeFor(screenName)
    if (!s) return []
    return pluginSlots.filter(slot => slot && slot.shown && slotScreen(slot) === s.screen.name
        && slot.activeItem && typeof slot.activeItem.open === "function")
      .sort((a, b) => {
        const pa = a.mapToItem(null, 0, 0), pb = b.mapToItem(null, 0, 0)
        return vertical ? pa.y - pb.y : pa.x - pb.x
      })
      .map(slot => slot.moduleName)
  }

  function openBarWidget(id, screenName) {
    // Bar hidden: nothing to open a bar panel from.
    if (barHidden) return false
    // Omarchy's own widget on the bar (Settings › Taskbar) answers its own
    // hotkey, ahead of the Omacale popout it stands in for.
    var own = hostedSlot(id, screenName)
    if (own && typeof own.activeItem.open === "function") {
      own.activeItem.open()
      return true
    }
    var t = widgetTargets[id]
    var s = scopeFor(screenName)
    if (t && t.settings && s) {
      toggleRequested("settings", s.screen.name, t.settings)
      return true
    }
    if (t && s) {
      if (t.onBar && s.statusPopouts().indexOf(t.popout) < 0) return false
      s.openPopoutKeys(t.popout)
      return true
    }
    return false
  }

  function summonBarWidget(id) {
    return openBarWidget(String(id || ""), barScreen())
  }
  function hideBarWidget(id) {
    if (hostedSlot(id, barScreen())) return closeHosted(id)
    var t = widgetTargets[id]
    if (t && t.settings) {
      for (const s of scopes) if (s.settings && s.nexusPage === t.settings) s.settings = false
      return true
    }
    if (t) {
      for (const s of scopes) if (s.popout === t.popout) s.popout = ""
      return true
    }
    return closeHosted(id)
  }
  function closeHosted(id) {
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
    var t = hostedSlot(id, barScreen()) ? null : widgetTargets[id]
    if (t && t.settings) return scopes.some(s => s.settings && s.nexusPage === t.settings)
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
  // `togglePanelAt <section> <n>` (SUPER+CTRL+1..9): the nth hosted widget
  // you can see (1-based), whatever the section --
  // Omacale's own popouts have their letter hotkeys. "" when there is none,
  // and the host then does nothing.
  function panelWidgetIdAt(section, index) {
    if (barHidden) return ""
    var ids = panelOrder(barScreen())
    var n = parseInt(index, 10)
    return n >= 1 && n <= ids.length ? ids[n - 1] : ""
  }
  // Service cache for hosted 3rd-party plugins that require a companion service.
  // Avoid reassigning the property to prevent declarative binding loops in hosted panels.
  QtObject {
    id: serviceStore
    property var instances: ({})
  }

  // Only for a plugin id as Omarchy writes them (no "/" or "..", so the path
  // below stays inside the plugins folder), registered as a bar widget, and
  // enabled -- the service a hosted widget would get from Omarchy itself.
  // PluginBarFacade only asks for the widget's own id, as Omarchy's service
  // scoping does.
  function hostedServiceFor(pluginId) {
    var key = String(pluginId || "")
    if (!/^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(key) || key.indexOf("..") >= 0) return null
    if (serviceStore.instances[key]) return serviceStore.instances[key]

    var reg = root.barWidgetRegistry
    var meta = reg && typeof reg.metadataFor === "function" ? reg.metadataFor(key) : null
    if (!meta) return null
    var registry = root.shell ? root.shell.pluginRegistry : null
    if (registry && typeof registry.resolveEnabledId === "function" && registry.resolveEnabledId(key) !== key) return null
    var sourceDir = meta.sourceDir ? String(meta.sourceDir) : ""
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

  // Caelestia's Lock.qml warm-up: the first screen capture of a session loads
  // its backend asynchronously, and if the lock's is that first one it lands
  // after Hyprland has locked and been refused. One throwaway capture at
  // start means the lock's is never the first (modules/lock/LockUi.qml).
  Loader {
    active: Config.o.lock.enabled && !Config.o.lock.useWallpaper && Quickshell.screens.length > 0
    asynchronous: true
    onLoaded: active = false
    sourceComponent: ScreencopyView {
      captureSource: Quickshell.screens[0]
    }
  }

  // Bundled fonts (Caelestia's Google Sans Flex and Rubik).
  FontLoader { source: Qt.resolvedUrl("assets/fonts/GoogleSansFlex.ttf") }
  FontLoader { source: Qt.resolvedUrl("assets/fonts/Rubik.ttf") }

  Variants {
    model: Quickshell.screens
    delegate: ScreenScope { host: root }
  }

  // The session IPC (the power button's binds, and SUPER+ESC / the power key
  // with keybinds.lua's optional rebinds): the drawer, or Omarchy's System
  // menu when Settings › Session › Menu says so, when the drawer is off, when
  // a fullscreen window would cover it (Omarchy's menu is an overlay), or
  // while the screen is locked (there Omarchy's own behaviour is the safe one).
  // The wallpaper and theme pickers, as Settings › Keybinds › Picker says:
  // the launcher's carousel, or Omarchy's own menu. The IPC, Settings ›
  // Wallpaper & style and the launcher's ":" menu all come through here.
  function openWallpapers() {
    if (Config.o.launcher.wallpaperPicker === "omarchy") Sys.run("omarchy-menu toggle background")
    else toggle("launcher", "wallpaper")
  }
  function openThemes() {
    if (Config.o.launcher.themePicker === "omarchy") Sys.run("omarchy-menu toggle theme")
    else toggle("launcher", "theme")
  }

  function openSession() {
    const s = scopeFor(focusedScreen())
    if (Config.o.session.menu === "omarchy" || !Config.o.session.enabled || (s && s.hasFullscreen))
      Sys.run("omarchy-menu toggle system")
    else lockProbe.running = true
  }
  Process {
    id: lockProbe
    command: ["omarchy-shell", "lock", "isLocked"]
    // No answer (no lock service) counts as unlocked.
    stdout: StdioCollector {
      onStreamFinished: {
        if (text.trim() === "true") Sys.run("omarchy-menu toggle system")
        else root.toggle("session")
      }
    }
  }

  IpcHandler {
    target: "omacale"
    // Quickshell IPC needs typed arguments and return types.
    function launcher(): void { root.toggle("launcher") }
    function dashboard(): void { root.toggle("dashboard") }
    function session(): void { root.openSession() }
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
    // The brightness keys (optional binds in keybinds.lua): the focused
    // screen steps; with "Same brightness on every display" all of them do.
    function brightness(step: string): void {
      if (!/^(\+\d+%|\d+%-|\d+%)$/.test(step)) return
      const m = Hyprland.focusedMonitor
      DisplayService.stepBrightness(m ? m.name : (Quickshell.screens[0] ? Quickshell.screens[0].name : ""), step)
    }
    // Settings › Display's pending change: keep | revert | status.
    function display(action: string): string {
      if (action === "menu") root.displayMenu()
      else if (action === "keep") DisplayService.keep()
      else if (action === "revert") DisplayService.revert()
      return DisplayService.confirming ? "confirming " + DisplayService.seconds : DisplayService.previewPending ? "applying" : "idle"
    }
    // Any bar popout by Omacale's own name (network, bluetooth, audio,
    // battery, kblayout, lockstatus, update, activewindow), opened with the
    // keyboard on the focused monitor; again closes it.
    // SUPER+CTRL+0: the bar takes the keyboard, a cursor walks its items.
    function barFocus(): void {
      const s = root.scopeFor(root.barScreen())
      if (s) s.toggleBarFocus()
    }
    function popout(name: string): void {
      const s = root.scopeFor(root.barScreen())
      if (!s) return
      if (s.popout === name) s.popout = ""
      else s.openPopoutKeys(name)
    }
    // Caelestia's launcher carousels: ">wallpaper " and ">theme ".
    // Settings › Keybinds › Picker picks the launcher carousel or Omarchy's
    // own menu, so one bind follows the setting without being rewritten.
    function wallpapers(): void { root.openWallpapers() }
    function themes(): void { root.openThemes() }
    // The Omarchy menu, walked inside the launcher (the ":" prefix).
    function menu(): void { root.toggle("launcher", "menu") }
    // Omarchy's clipboard history, in the launcher (">clipboard ").
    function clipboard(): void { root.toggle("launcher", "clipboard") }
    // UI scale: "omarchy" follows shell.toml, a number (0.5-2) sets a custom
    // one. Also the way back from a size too broken to use Settings at.
    // Prints the effective scale.
    function scale(value: string): string {
      const v = value.trim().toLowerCase()
      if (v === "omarchy") Config.set("appearance.scale.source", "omarchy")
      else if (v !== "") {
        const n = Number(v.replace(/%$/, "")) / (v.endsWith("%") ? 100 : 1)
        if (!isFinite(n) || n < 0.5 || n > 2) return "scale: expected omarchy or 0.5-2 (or 50%-200%)"
        Config.set("appearance.scale.ui", n)
        Config.set("appearance.scale.source", "custom")
      }
      return Config.o.appearance.scale.source + " " + Tk.uiScale.toFixed(2)
    }
    // Caelestia's `toaster` IPC (Shortcuts.qml info/success/warn/error) as
    // one call: type is info, success, warning or error; an empty icon takes
    // the type's own.
    function toast(type: string, title: string, message: string, icon: string): void {
      Toaster.toast(title, message, icon, Toaster.typeOf(type))
    }
    // Dev loop: the lock's unlock animation over the desktop on every
    // screen. Nothing else shows it, since only the real password ends a
    // real lock and the preview never unlocks.
    function unlockFx(): void { LockFx.test() }
  }

  // Created at startup so an old menu-route block gets cleaned up.
  readonly property string wallpapersScript: Wallpapers.script

  // Likewise: LockService checks the lock-screen handover at startup, and
  // installs it if the setting is on and it is missing. Both handovers then
  // keep their clones in step with Omarchy updates (services/Handover.qml).
  readonly property bool lockHandover: LockService.installed
  readonly property bool notifHandover: NotifHandover.installed
  readonly property bool osdHandover: OsdHandover.installed
  // Keeps Hyprland's gaps and window rounding in step with the UI scale
  // through omacale.lua (services/HyprLook.qml). Referenced to create it.
  readonly property string hyprLook: HyprLook.args
  // Hyprland's blur while Settings › Glass tunes it (services/GlassBlur.qml).
  readonly property string glassBlur: GlassBlur.args
  // Omarchy's own menus in Omacale's colours, when chosen (services/OmarchySurfaces.qml).
  readonly property bool omarchySurfaces: OmarchySurfaces.on
  // Settings › Display › Identify: every screen's name on it for a moment.
  Variants {
    model: DisplayService.identifying ? Quickshell.screens : []
    DisplayIdentify {}
  }
  // Settings › Display › Apply: keep or revert, on every screen.
  Variants {
    model: DisplayService.confirming ? Quickshell.screens : []
    DisplayConfirm {}
  }
  Connections {
    target: DisplayService
    function onPreviewEnded(fromSettings) { if (fromSettings) root.toggle("settings", "display") }
  }
  // Night light's schedule lives in a singleton, created on first use: use
  // it here so it runs from startup, not only once Settings is opened.
  readonly property bool nightOn: NightLight.on
  // The display-switch menu, on the screen that had focus when it opened.
  property string quickScreen: ""
  function displayMenu() {
    if (DisplayService.quickOpen) { DisplayService.quickShow(false); return }
    quickScreen = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : (Quickshell.screens[0] ? Quickshell.screens[0].name : "")
    DisplayService.quickShow(true)
  }
  Variants {
    model: DisplayService.quickOpen && !DisplayService.confirming ? Quickshell.screens.filter(s => s.name === root.quickScreen) : []
    DisplayQuick {}
  }
  // Settings › Display › "Ask when a display is connected": the menu, once
  // hyprmoncfg has had a moment to apply its own profile for the new set.
  Timer {
    id: connectedAsk
    interval: 1500
    onTriggered: if (!DisplayService.quickOpen && !DisplayService.confirming) root.displayMenu()
  }

  // Transparency: blur the Omacale layer behind translucent surfaces. This is
  // a runtime Hyprland rule (hyprctl eval) — nothing is written to
  // ~/.config/hypr, and it disappears on the next Hyprland reload.
  // Glass (core/Glass.qml) is translucent too, and its threshold leaves out
  // its shadow, which it draws round the shape itself.
  // With the lens on, the glass draws what is behind itself, frosted its own
  // way, so Hyprland's blur stays off behind the frame and drawers; the
  // toasts aren't drawn by the lens and keep it.
  readonly property bool blur: Config.o.appearance.transparency.enabled || (Glass.enabled && !Glass.lens)
  readonly property bool toastBlur: Config.o.appearance.transparency.enabled || Glass.enabled
  readonly property real ignoreAlpha: Glass.enabled ? Glass.blurFloor : Math.max(0, Config.o.appearance.transparency.layers - 0.05)
  // The toasts are a second surface (overlay layer, so a fullscreen window
  // can't cover them), and they take the same translucent surface colours as
  // the frame -- so they need the same blur behind them.
  // Named, so each call replaces the last: Hyprland adds an unnamed Lua rule
  // beside the old ones, and `blur = false` never undid an earlier `true`.
  function applyBlur() {
    Quickshell.execDetached(["hyprctl", "eval",
      'hl.layer_rule({ name = "omacale-blur", match = { namespace = "^omacale$" }, blur = ' + (blur ? "true" : "false") +
      ', ignore_alpha = ' + ignoreAlpha.toFixed(2) + ' }); ' +
      'hl.layer_rule({ name = "omacale-blur-toasts", match = { namespace = "^omacale-notifications$" }, blur = ' + (toastBlur ? "true" : "false") +
      ', ignore_alpha = ' + ignoreAlpha.toFixed(2) + ' })'])
  }
  onBlurChanged: applyBlur()
  onToastBlurChanged: applyBlur()
  onIgnoreAlphaChanged: if (blur || toastBlur) applyBlur()

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
  // The lock card is drawn by an overlay Hyprland puts above the session
  // lock (modules/lock/LockUnlockFx.qml): `above_lock = 2` draws it over the
  // lock and gives it the pointer on its input region (the card); the
  // keyboard always stays with the lock. Runtime only, like the blur.
  function applyLockRule() {
    Quickshell.execDetached(["hyprctl", "eval",
      'hl.layer_rule({ match = { namespace = "^omacale-unlock$" }, no_anim = true, above_lock = 2 })'])
  }

  onClockBlurChanged: applyDesktopBlur()
  onClockIgnoreAlphaChanged: if (clockBlur) applyDesktopBlur()
  onVisBlurChanged: applyDesktopBlur()

  Component.onCompleted: {
    thirdPartyPlugins = collectedPlugins
    if (blur || toastBlur) applyBlur()
    if (clockBlur || visBlur) applyDesktopBlur()
    applyLockRule()
    // The OSD handover's clone only takes Omarchy's OSDs while this bar is
    // running in this shell (services/OsdService.qml claim()).
    OsdService.claim(true)
    // Likewise the notification clone's toast window (NotifService.claimPopups()).
    NotifService.claimPopups(true)
  }
  Component.onDestruction: {
    OsdService.claim(false)
    NotifService.claimPopups(false)
  }
  Connections {
    target: Hyprland
    function onRawEvent(e) {
      if (e.name === "monitoraddedv2" && Config.o.display.quickOnConnect) connectedAsk.restart()
      if (e.name !== "configreloaded") return
      if (root.blur || root.toastBlur) root.applyBlur()
      if (root.clockBlur || root.visBlur) root.applyDesktopBlur()
      root.applyLockRule()
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
