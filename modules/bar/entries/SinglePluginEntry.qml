import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../.."

// One widget on the bar by itself (bar.layout's "plugin:<id>"): one of
// Omarchy's own (the AI agents, weather, ...) or a third-party one taken out
// of the plugin pill, in a small pill of its own laid out like the plugin
// pill's cells. The plugin pill leaves it out while it has a place here.
//
// As with PluginsEntry, the entry is an empty placeholder and the pill is
// drawn on the bar's overlay: a widget that paints nothing reports itself
// invisible, and a pill hidden for that could never come back. The pill
// folds to nothing instead.
Item {
  id: singlePluginEntry
  required property var bar
  Component.onCompleted: bar.registerEntry(singlePluginEntry)
  Component.onDestruction: bar.unregisterEntry(singlePluginEntry)
  property string pluginId: ""
  property string entryId: "plugin:" + pluginId
  // The host's registry entry for the widget; null while it isn't one.
  readonly property var hostEntry: bar.host.widgetEntry(pluginId)
  readonly property bool hidden: bar.cfg.plugins.hidden.indexOf(pluginId) >= 0
  readonly property Item slot: slotLoader.item
  readonly property bool shown: !hidden && !!slot && slot.shown
  // Next to status icons or another widget, they share one pill (BarContent's
  // Section.runs draws it): no background of its own, no padding where joined.
  // Behind a closed chevron (BarContent's Loader): the pill lives on the
  // overlay, outside the Loader, so it has to hide itself.
  readonly property bool folded: !!parent && parent.folded === true
  // How far its Loader is unfolded (BarContent): the overlay pill follows it.
  readonly property real fold: !!parent && parent.foldProg !== undefined ? parent.foldProg : 1
  readonly property bool joinable: true
  property bool joinBefore: false
  property bool joinAfter: false
  visible: shown
  Layout.alignment: bar.crossAlign
  implicitWidth: bar.vertical ? Tk.barInner : pill.implicitWidth
  implicitHeight: bar.vertical ? pill.implicitHeight : Tk.barInner
  // Where the placeholder is in the bar's coordinates (see PluginsEntry).
  readonly property real ox: { let x = singlePluginEntry.x, p = singlePluginEntry.parent; while (p && p !== bar) { x += p.x; p = p.parent } return x }
  readonly property real oy: { let y = singlePluginEntry.y, p = singlePluginEntry.parent; while (p && p !== bar) { y += p.y; p = p.parent } return y }

  Rectangle {
    id: pill
    parent: singlePluginEntry.bar.overlay
    // The padding at each end of the pill, along the bar, as the plugin pill's.
    property real padStart: singlePluginEntry.joinBefore ? 0 : Tk.padding.medium
    property real padEnd: singlePluginEntry.joinAfter ? 0 : Tk.padding.medium
    // Joining and parting glide (a Behavior needs a plain property).
    Behavior on padStart { Anim {} }
    Behavior on padEnd { Anim {} }
    readonly property real slotLen: !singlePluginEntry.slot ? 0
      : singlePluginEntry.bar.vertical ? singlePluginEntry.slot.implicitHeight : singlePluginEntry.slot.implicitWidth
    visible: slotLoader.active && singlePluginEntry.fold > 0.001
    opacity: singlePluginEntry.shown ? singlePluginEntry.fold : 0
    x: singlePluginEntry.ox
    y: singlePluginEntry.oy
    implicitWidth: singlePluginEntry.bar.vertical ? Tk.barInner : (singlePluginEntry.shown ? slotLen + padStart + padEnd : 0)
    implicitHeight: singlePluginEntry.bar.vertical ? (singlePluginEntry.shown ? slotLen + padStart + padEnd : 0) : Tk.barInner
    // Drawn as long as its Loader is unfolded; the placeholder keeps the full size.
    width: singlePluginEntry.bar.vertical ? implicitWidth : implicitWidth * singlePluginEntry.fold
    height: singlePluginEntry.bar.vertical ? implicitHeight * singlePluginEntry.fold : implicitHeight
    radius: (singlePluginEntry.bar.vertical ? width : height) / 2
    color: singlePluginEntry.joinBefore || singlePluginEntry.joinAfter ? "transparent" : Colours.m3surfaceContainer
    clip: true

    Loader {
      id: slotLoader
      active: !!singlePluginEntry.hostEntry && !singlePluginEntry.hidden
      x: singlePluginEntry.bar.vertical ? 0 : pill.padStart
      y: singlePluginEntry.bar.vertical ? pill.padStart : 0
      sourceComponent: BarWidgetSlot {
        // Through the entry's id: BarWidgetSlot has its own `bar` (the plugin
        // facade) and `entry` (its plugin), which would shadow ours here.
        entry: singlePluginEntry.hostEntry
        host: singlePluginEntry.bar.host
        vertical: singlePluginEntry.bar.vertical
        edge: singlePluginEntry.bar.edge
        cellLen: singlePluginEntry.bar.cellLen
        pinned: true
        collapsed: false
      }
    }
  }

  function navStops() {
    const s = slot
    return s && s.shown && s.activeItem ? [{ item: s, kind: "plugin", act: () => bar.openPlugin(s) }] : []
  }
}
