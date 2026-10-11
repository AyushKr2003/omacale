import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../.."

// Dedicated Caelestia pill for 3rd-party bar widgets (installed in
// ~/.config/omarchy/plugins/), laid out like the status pill: same padding,
// same spacing, one status-icon cell per widget (BarWidgetSlot scales each
// widget's mark to the status icons' size). Sits on this entry.
//
// Pinned widgets (Settings › Taskbar › Plugins) always show; the others
// wait behind a chevron that hovering expands, like the compact tray.
// Hidden ones (bar.plugins.hidden) aren't made at all.
//
// The entry is an empty placeholder holding the pill's place in its section;
// the pill is drawn on the bar's overlay at the placeholder's position.
// Hiding a parent of a widget makes the widget itself report visible=false,
// so a pill inside a placeholder hidden because every widget had hidden
// itself could never come back. Hiding the empty placeholder instead also
// lets the layout drop its spacing.
Item {
  id: pluginsEntry
  required property var bar
  Component.onCompleted: bar.registerEntry(pluginsEntry)
  Component.onDestruction: bar.unregisterEntry(pluginsEntry)
  property string entryId: "plugins"
  property alias pill: pill
  readonly property bool shown: pill.visible && pill.anyShown
  // Next to status icons or widgets, they share one pill (BarContent's
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
  property alias expanded: pill.expanded
  // Where the placeholder is in the bar's coordinates: its offset plus every
  // parent's up to the bar (a section, a Loader, the column), so the pill
  // follows the layout.
  readonly property real ox: { let x = pluginsEntry.x, p = pluginsEntry.parent; while (p && p !== bar) { x += p.x; p = p.parent } return x }
  readonly property real oy: { let y = pluginsEntry.y, p = pluginsEntry.parent; while (p && p !== bar) { y += p.y; p = p.parent } return y }

  Rectangle {
    id: pill
    // Drawn on the bar's overlay, not in the layout: see the header.
    parent: bar.overlay
    readonly property var pluginsList: (bar.host.thirdPartyPlugins || [])
      .filter(e => bar.cfg.plugins.hidden.indexOf(bar.host.entryId(e)) < 0
        && bar.placedWidgets.indexOf(bar.host.entryId(e)) < 0)
    readonly property var unpinned: bar.cfg.plugins.unpinned
    // The padding at each end of the list, along the bar: none on a side
    // joined to a neighbour.
    property real padStart: pluginsEntry.joinBefore ? 0 : Tk.padding.medium
    property real padEnd: pluginsEntry.joinAfter ? 0 : Tk.padding.medium
    // Joining and parting glide (a Behavior needs a plain property).
    Behavior on padStart { Anim {} }
    Behavior on padEnd { Anim {} }
    readonly property real listLen: bar.vertical ? pluginCol.implicitHeight : pluginCol.implicitWidth
    // From the counted slots, not the list's length: that includes the
    // padding, which depends on joining, which depends on this.
    readonly property bool anyShown: overflowCount > 0 || pinnedLen > 0
    property bool expanded: false
    onOverflowCountChanged: if (overflowCount === 0) expanded = false

    // Counted by hand: Repeater.itemAt is not a binding dependency, so every
    // slot asks for a recount when its size, content or pin changes.
    property int overflowCount: 0
    property real pinnedLen: 0
    function recount() { countTimer.restart() }
    Timer {
      id: countTimer
      interval: 0
      onTriggered: {
        let n = 0, h = 0
        for (let i = 0; i < pluginRep.count; i++) {
          const slot = pluginRep.itemAt(i)
          if (!slot || !slot.shown) continue
          if (slot.pinned) h += Math.round(slot.visualLen) + pluginCol.gapPx
          else n++
        }
        pill.overflowCount = n
        pill.pinnedLen = h
      }
    }
    // The pill's size along the bar with the overflow closed: what the budget plans for.
    readonly property real collapsedLen: overflowCount === 0 && pinnedLen === 0 ? 0
      : padStart + padEnd + pinnedLen
        + (overflowCount > 0 ? (bar.vertical ? overflowIcon.implicitHeight : overflowIcon.implicitWidth) : -pluginCol.gapPx)

    visible: bar.cfg.plugins.enabled !== false && pluginsList.length > 0 && pluginsEntry.fold > 0.001
    opacity: anyShown ? pluginsEntry.fold : 0
    x: pluginsEntry.ox
    y: pluginsEntry.oy
    // Scrolled down to a single cell, pinned widgets included, when even they
    // don't fit: the pill gives way before the clock and status icons do.
    readonly property real minLen: padStart + padEnd + bar.cellLen
    // Capped by the space budget, leaving the tray its (collapsed) share.
    readonly property real sizeLen: anyShown ? Math.min(Math.max(minLen, bar.budget - bar.trayReserve), listLen) : 0
    implicitWidth: bar.vertical ? Tk.barInner : sizeLen
    implicitHeight: bar.vertical ? sizeLen : Tk.barInner
    // Drawn as long as its Loader is unfolded; the placeholder keeps the full size.
    width: bar.vertical ? implicitWidth : implicitWidth * pluginsEntry.fold
    height: bar.vertical ? implicitHeight * pluginsEntry.fold : implicitHeight
    radius: (bar.vertical ? width : height) / 2
    color: pluginsEntry.joinBefore || pluginsEntry.joinAfter ? "transparent" : Colours.m3surfaceContainer
    clip: true

    Behavior on implicitHeight { enabled: bar.vertical; Anim {} }
    Behavior on implicitWidth { enabled: !bar.vertical; Anim {} }

    Timer {
      id: collapsePluginsTimer
      interval: 400
      onTriggered: pill.expanded = false
    }

    // More widgets than fit scroll rather than being cut off.
    MFlickable {
      id: pluginFlick
      anchors.fill: parent
      contentWidth: bar.vertical ? width : pluginCol.implicitWidth
      contentHeight: bar.vertical ? pluginCol.implicitHeight : height
      interactive: bar.vertical ? contentHeight > height + 0.5 : contentWidth > width + 0.5

      Grid {
        id: pluginCol
        readonly property real gapPx: Tk.spacing.medium / 2
        width: bar.vertical ? parent.width : implicitWidth
        height: bar.vertical ? implicitHeight : parent.height
        columns: bar.vertical ? 1 : 1000
        topPadding: bar.vertical ? pill.padStart : 0
        bottomPadding: bar.vertical ? pill.padEnd : 0
        leftPadding: bar.vertical ? 0 : pill.padStart
        rightPadding: bar.vertical ? 0 : pill.padEnd
        spacing: gapPx

        Repeater {
          id: pluginRep
          model: pill.pluginsList

          BarWidgetSlot {
            required property var modelData
            pinned: pill.unpinned.indexOf(moduleName) < 0
            entry: modelData
            // `pluginsEntry.bar`, not `bar`: BarWidgetSlot has a `bar` of its own
            // (the plugin facade), which would shadow ours here.
            host: pluginsEntry.bar.host
            vertical: pluginsEntry.bar.vertical
            edge: pluginsEntry.bar.edge
            cellLen: pluginsEntry.bar.cellLen
            collapsed: !pinned && !pill.expanded
            onShownChanged: pill.recount()
            onPinnedChanged: pill.recount()
            onVisualLenChanged: pill.recount()
            Component.onCompleted: pill.recount()
            Component.onDestruction: pill.recount()
          }
        }

        // Caelestia's tray chevron, for the widgets that aren't pinned.
        Item {
          width: bar.vertical ? parent.width : (pill.overflowCount > 0 ? overflowIcon.implicitWidth : 0)
          height: bar.vertical ? (pill.overflowCount > 0 ? overflowIcon.implicitHeight : 0) : parent.height
          MIcon {
            id: overflowIcon
            anchors.centerIn: parent
            visible: pill.overflowCount > 0
            text: bar.vertical ? "expand_less" : "chevron_left"
            size: Tk.iconSize.medium
            color: Colours.m3onSurfaceVariant
            rotation: pill.expanded ? 180 : 0
            Behavior on rotation { Anim {} }
          }
          MouseArea {
            anchors.fill: parent
            enabled: pill.overflowCount > 0
            cursorShape: Qt.PointingHandCursor
            onClicked: { collapsePluginsTimer.stop(); pill.expanded = !pill.expanded }
          }
        }
      }
    }

    // Omarchy's WidgetButton takes every wheel, so hosted widgets would eat
    // the scroll of an overfull pill. Wheel only: clicks and hover go through,
    // and while the pill fits the wheel is left to the widget.
    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.NoButton
      onWheel: e => {
        if (!pluginFlick.interactive) { e.accepted = false; return }
        bar.scrollBy(pluginFlick, e.angleDelta.y)
      }
    }
  }

  function navStops() {
    const out = []
    if (!pill.visible || !pill.anyShown) return out
    for (let i = 0; i < pluginRep.count; i++) {
      const slot = pluginRep.itemAt(i)
      if (slot && slot.shown && slot.activeItem)
        out.push({ item: slot, kind: "plugin", group: pill, act: () => bar.openPlugin(slot) })
    }
    return out
  }
  function hoverAt(a, onBar) {
    const p = bar.pointAlong(bar.pointOn(pill, a))
    if (onBar && pill.visible && p >= 0 && p <= bar.alen(pill)) {
      collapsePluginsTimer.stop()
      if (pill.overflowCount > 0) pill.expanded = true
    } else if (pill.expanded && !collapsePluginsTimer.running) collapsePluginsTimer.start()
  }
  // The overflow opens while the bar focus cursor is in the pill.
  function cursorMoved(s) {
    if (!!s && s.group === pill) { collapsePluginsTimer.stop(); if (pill.overflowCount > 0) pill.expanded = true }
    else if (pill.expanded) collapsePluginsTimer.restart()
  }
}
