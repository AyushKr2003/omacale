import QtQuick
import Quickshell

// Facade passed to Omarchy bar-widget plugins as the `bar` property.
// Conforms to /usr/share/omarchy/shell/Ui/PluginBarApi.qml and mirrors
// the same contract ruixen-shell's inline PluginBarFacade provides.
QtObject {
  id: facade

  required property var host
  required property string moduleName

  readonly property color foreground: Colours.m3onSurface
  // Bar marks take the status icons' colour; popups keep `foreground`.
  readonly property color barForeground: Colours.m3secondary
  readonly property color background: Colours.m3surfaceContainer
  readonly property color urgent: Colours.m3error
  readonly property string fontFamily: Tk.mono
  readonly property string position: "left"
  readonly property bool vertical: true
  // WidgetButton uses barSize as the extent of its icon slot. Widgets are
  // laid out in Omarchy's units and scaled up to Omacale's icon size (see
  // Bar.pluginIconScale), so this is the 40px pill measured in those units.
  readonly property int barSize: host ? host.pluginBarSize : Tk.barInner
  readonly property bool transparent: Config.o.appearance.transparency.enabled
  readonly property bool foregroundAnimationEnabled: true
  readonly property bool centerHoverRevealSuppressed: false
  readonly property bool centerSectionRevealHeld: false
  // Widgets register their trigger buttons here so KeyboardPanel can forward
  // a click through its overlay to another widget on the same bar.
  property var clickTargets: []
  readonly property var layoutConfig: host && host.barConfig && host.barConfig.layout ? host.barConfig.layout : ({})
  readonly property var foreignPopoutMarker: ({ foreign: true })
  readonly property var activePopout: !host ? null
    : host.pluginOwnsPopout(facade, host.activePopout) ? host.activePopout
    : (host.activePopout ? foreignPopoutMarker : null)
  // Widgets (e.g. ruixen.pluginpins) read bar.barWidgetRegistry.
  readonly property var barWidgetRegistry: host ? host.barWidgetRegistry : null
  // Widgets read bar.barConfig for layout introspection.
  readonly property var barConfig: host ? host.barConfig : ({})

  // Every call into the host is guarded: widgets call these from their own
  // teardown (hideTooltip on destruction), which can run after the bar that
  // hosts them is gone when the shell reloads plugins.
  function _call(name, args, fallback) {
    try {
      if (host && typeof host[name] === "function") return host[name].apply(host, args)
    } catch (e) {}
    return fallback
  }
  function showTooltip(target, text) { _call("showTooltip", [target, String(text || "")]) }
  function hideTooltip(target) { _call("hideTooltip", [target]) }
  function requestPopout(owner) { _call("requestPluginPopout", [facade, owner]) }
  function releasePopout(owner) { _call("releasePluginPopout", [facade, owner]) }
  function registerClickTarget(target) { _call("registerPluginClickTarget", [facade, target]) }
  function unregisterClickTarget(target) { _call("unregisterPluginClickTarget", [facade, target]) }
  function switchPanelFrom(owner, direction) { return _call("switchPluginPanelFrom", [facade, owner, direction], false) }
  function targetBelongsToWindow(target, window) { return _call("targetBelongsToWindow", [target, window], false) }
  function run(command) { if (command) Sys.run(String(command)) }

  function moduleWidgets(id) {
    return String(id || "") === facade.moduleName ? _call("moduleWidgets", [facade.moduleName], []) : []
  }

  function _scopedEntry() {
    return (host && host.shell && typeof host.shell.pluginShellForBarEntry === "function")
      ? host.shell.pluginShellForBarEntry("bar-entry:" + facade.moduleName, facade.moduleName)
      : null
  }

  readonly property var shell: QtObject {
    function serviceFor(id) {
      var targetId = String(id || "")
      if (!targetId) return null
      if (host && host.shell && typeof host.shell.scopedPluginShellForId === "function") {
        var scoped = host.shell.scopedPluginShellForId(facade.moduleName)
        if (scoped && typeof scoped.serviceFor === "function") {
          var s = scoped.serviceFor(targetId)
          if (s) return s
        }
      }
      if (host && host.shell && typeof host.shell.serviceFor === "function") {
        if (targetId === facade.moduleName || !host.shell.pluginRegistry || host.shell.pluginRegistry.resolveEnabledId(targetId) === facade.moduleName) {
          var s2 = host.shell.serviceFor(targetId)
          if (s2) return s2
        }
      }
      if (host && typeof host.hostedServiceFor === "function") {
        var s3 = host.hostedServiceFor(targetId)
        if (s3) return s3
      }
      return null
    }
    function firstPartyServiceFor(id) {
      return host && host.shell && typeof host.shell.firstPartyServiceFor === "function"
        ? host.shell.firstPartyServiceFor(id) : null
    }
    function summon(id, payloadJson) {
      var entry = facade._scopedEntry()
      return entry ? entry.summon(id, payloadJson) : false
    }
    function hide(id) {
      var entry = facade._scopedEntry()
      return entry ? entry.hide(id) : false
    }
    function toggle(id, payloadJson) {
      var entry = facade._scopedEntry()
      return entry ? entry.toggle(id, payloadJson) : false
    }
    function isPluginOpen(id) {
      var entry = facade._scopedEntry()
      return entry ? entry.isPluginOpen(id) : false
    }
    function updateEntryInline(id, settings) {
      var entry = facade._scopedEntry()
      return entry ? entry.updateEntryInline(id, settings) : false
    }
    function mutateShellConfig(mutator) {
      return host && host.shell && typeof host.shell.mutateShellConfig === "function"
        ? host.shell.mutateShellConfig(mutator) : false
    }
  }
}
