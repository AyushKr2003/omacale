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
  readonly property color barForeground: Colours.m3onSurface
  readonly property color background: Colours.m3surfaceContainer
  readonly property color urgent: Colours.m3error
  readonly property string fontFamily: Tk.mono
  readonly property string position: "left"
  readonly property bool vertical: true
  readonly property int barSize: Tk.barWidth
  readonly property bool transparent: Config.o.appearance.transparency.enabled
  readonly property bool foregroundAnimationEnabled: true
  readonly property bool centerHoverRevealSuppressed: false
  readonly property bool centerSectionRevealHeld: false
  readonly property var clickTargets: []
  readonly property var layoutConfig: host.barConfig && host.barConfig.layout ? host.barConfig.layout : ({})
  readonly property var activePopout: host.activePopout
  // Widgets (e.g. ruixen.pluginpins) read bar.barWidgetRegistry.
  readonly property var barWidgetRegistry: host.barWidgetRegistry
  // Widgets read bar.barConfig for layout introspection.
  readonly property var barConfig: host.barConfig

  function showTooltip(target, text) { host.showTooltip(target, text) }
  function hideTooltip(target) { host.hideTooltip(target) }
  function requestPopout(owner) { host.requestPopout(owner) }
  function releasePopout(owner) { host.releasePopout(owner) }
  function registerClickTarget(target) {}
  function unregisterClickTarget(target) {}
  function switchPanelFrom(owner, direction) { return false }
  function targetBelongsToWindow(target, window) { return true }
  function run(command) { Sys.run(command) }

  // BarWidget.broadcast() needs this to relay IPC to every live instance
  // of a widget across monitors.  Without it, broadcast() falls back to
  // a single-item array, which is correct for Omacale's vertical bar
  // (one BarContent per screen).
  function moduleWidgets(id) {
    // Each screen has its own BarWidgetSlot instance, so collecting
    // across screens would need a host-level registry.  Return the
    // caller's own item for now — BarWidget.broadcast() gracefully
    // handles a single-element array.
    return []
  }

  function _scopedEntry() {
    return (host.shell && typeof host.shell.pluginShellForBarEntry === "function")
      ? host.shell.pluginShellForBarEntry("bar-entry:" + facade.moduleName, facade.moduleName)
      : null
  }

  readonly property var shell: QtObject {
    function serviceFor(id) { return null }
    function firstPartyServiceFor(id) {
      return host.shell && typeof host.shell.firstPartyServiceFor === "function"
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
      return host.shell && typeof host.shell.mutateShellConfig === "function"
        ? host.shell.mutateShellConfig(mutator) : false
    }
  }
}
