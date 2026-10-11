import QtQuick
import QtQuick.Layouts
import "../../.."
import "../../../core/BarLayout.js" as BarLayout

// The chevron: the items behind it (bar.layout.drawer, and with
// bar.layout.maxShown the icons past that many) are ordinary entries laid out
// right after it, folded away (BarContent's Loader `folded`) until it opens.
// It opens on hover or a click and closes a moment after the pointer leaves
// it and its items, as the plugin pill's overflow does (Caelestia's compact
// tray chevron). It joins its neighbours' pill like an icon. No Caelestia
// original for the drawer itself.
Item {
  id: entry
  required property var bar
  Component.onCompleted: bar.registerEntry(entry)
  Component.onDestruction: { bar.unregisterEntry(entry); bar.drawerOpen = false }
  property string entryId: "overflow"

  // Anything to open: a drawer item that is on show.
  readonly property bool shown: {
    const r = bar.rendered
    for (const s of BarLayout.SECTIONS)
      for (const x of r[s]) if (x.drawer && bar.onShow(x.id)) return true
    return false
  }
  onShownChanged: if (!shown) bar.drawerOpen = false
  visible: shown

  readonly property bool joinable: true
  property bool joinBefore: false
  property bool joinAfter: false
  readonly property bool joined: joinBefore || joinAfter
  property real padStart: joinBefore ? 0 : Tk.padding.medium
  property real padEnd: joinAfter ? 0 : Tk.padding.medium
  // Joining and parting glide (a Behavior needs a plain property).
  Behavior on padStart { Anim {} }
  Behavior on padEnd { Anim {} }
  // In the end section the items open on its start side (BarLayout.render).
  readonly property bool opensBack: { const f = BarLayout.find(bar.layout, "overflow"); return !!f && f.sec === "end" }
  readonly property real iconLen: bar.vertical ? icon.implicitHeight : icon.implicitWidth
  Layout.alignment: bar.crossAlign
  implicitWidth: bar.vertical ? Tk.barInner : iconLen + padStart + padEnd
  implicitHeight: bar.vertical ? iconLen + padStart + padEnd : Tk.barInner

  // On its own it is a pill of its own.
  Rectangle {
    anchors.fill: parent
    visible: !entry.joined
    radius: (entry.bar.vertical ? width : height) / 2
    color: Colours.m3surfaceContainer
  }
  MIcon {
    id: icon
    x: entry.bar.vertical ? Math.round((parent.width - width) / 2) : entry.padStart
    y: entry.bar.vertical ? entry.padStart : Math.round((parent.height - height) / 2)
    // Pointing to where the items come out, turned back once they are.
    text: entry.bar.vertical ? (entry.opensBack ? "expand_less" : "expand_more") : (entry.opensBack ? "chevron_left" : "chevron_right")
    size: Tk.iconSize.medium
    color: Colours.m3onSurfaceVariant
    rotation: entry.bar.drawerOpen ? 180 : 0
    Behavior on rotation { Anim {} }
  }
  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: { closeTimer.stop(); entry.bar.drawerOpen = !entry.bar.drawerOpen }
  }

  Timer {
    id: closeTimer
    interval: 400
    onTriggered: entry.bar.drawerOpen = false
  }

  // Along the bar, where the chevron and its open items are, in the
  // chevron's own coordinates (the items may be on either side).
  function span() {
    let lo = 0, hi = bar.alen(entry)
    if (bar.drawerOpen)
      for (const it of bar.drawerItems()) {
        const p = bar.pointAlong(it.mapToItem(entry, 0, 0))
        lo = Math.min(lo, p)
        hi = Math.max(hi, p + bar.alen(it))
      }
    return [lo, hi]
  }
  function hoverAt(a, onBar) {
    const p = bar.pointAlong(bar.pointOn(entry, a))
    const sp = span()
    if (onBar && shown && p >= sp[0] && p <= sp[1]) {
      closeTimer.stop()
      bar.drawerOpen = true
    } else if (bar.drawerOpen && !closeTimer.running) closeTimer.start()
  }
  // Open while the bar focus cursor is on the chevron or one of its items.
  function cursorMoved(s) {
    const inside = !!s && (s.item === entry || bar.drawerItems().some(it => it === s.item || (s.item && isInside(s.item, it))))
    if (inside) { closeTimer.stop(); bar.drawerOpen = true }
    else if (bar.drawerOpen) closeTimer.restart()
  }
  function isInside(item, ancestor) {
    for (let p = item; p; p = p.parent) if (p === ancestor) return true
    return false
  }
  function navStops() {
    return shown ? [{ item: entry, act: () => { closeTimer.stop(); bar.drawerOpen = !bar.drawerOpen } }] : []
  }
}
