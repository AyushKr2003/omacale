import QtQuick
import QtQuick.Layouts
import "../../.."
import "../../../core/BarLayout.js" as BarLayout

// Settings › Taskbar › Layout: the bar's start, center and end sections
// (bar.layout), Noctalia-style; no Caelestia original. Rows are dragged by
// their handle to any place in any section, or into "Not in the bar" to take
// them off it (and back out to add them again). The eye is the item's
// existing switch (Status icons › Network, Clock › Show, ...): hidden, an
// item keeps its place. A widget taken out of the plugin group has an undo
// that puts it back in the group instead of a delete.
//
// The page is an Item rather than a layout so the dragged row's ghost and
// the drop line can float above the rows.
Item {
  id: root
  property var row
  property var settings
  property bool first
  property bool last

  implicitHeight: col.implicitHeight

  readonly property var layout: {
    const l = Config.o.bar.layout
    void l.start; void l.center; void l.end; void l.removed
    void PluginService.barWidgets
    return PluginService.barLayout()
  }
  readonly property bool vertical: Tk.barVertical
  readonly property var lists: BarLayout.SECTIONS.concat(["removed"])
  // Widgets still in the plugin group, which can be given a place of their own.
  readonly property var groupWidgets: PluginService.barWidgets.filter(p =>
    !BarLayout.SECTIONS.some(s => root.layout[s].indexOf("plugin:" + p.id) >= 0)
    && PluginService.barMode(p.id) !== "hidden")

  function title(list) { return list === "removed" ? "Not in the bar" : BarLayout.sectionLabel(list, vertical) }
  function info(id) {
    if (BarLayout.isPlugin(id)) {
      const p = PluginService.byId(BarLayout.pluginOf(id))
      return { label: p ? p.name : BarLayout.pluginOf(id), icon: "extension", sub: "Plugin, on its own", key: "", plugin: true }
    }
    return BarLayout.ITEMS[id]
  }
  function place(id, list, index) { PluginService.setBarLayout(BarLayout.place(layout, id, list, index)) }
  // "Add to" menu for a row: every section but the one it is in.
  function addOptions(from) {
    return BarLayout.SECTIONS.filter(s => s !== from).map(s => ({ value: s, label: title(s), icon: s === "start" ? "first_page" : s === "end" ? "last_page" : "horizontal_distribute" }))
  }

  // ------------------------------------------------------------- drag
  property string dragId: ""
  property string dragLabel: ""
  property string dragIcon: ""
  property real dragY: 0         // pointer, in root coordinates
  property real grabDy: 0        // pointer's offset into the row it grabbed
  property real rowH: 0
  property string dropList: ""
  property int dropIndex: -1
  property real lineY: 0
  property var sections: ({})    // list -> its section column

  // The settings page's scroll view, for scrolling while dragging near its edge.
  readonly property Item flick: { let f = root.parent; while (f && f.contentY === undefined) f = f.parent; return f }
  property real flickPointer: 0  // pointer, in the scroll view's coordinates

  function rowsIn(list) {
    const s = sections[list]
    return s ? s.rowItems().filter(r => r.modelData !== dragId) : []
  }
  function startDrag(row, pointerY) {
    const top = row.mapToItem(root, 0, 0).y
    dragId = row.modelData
    dragLabel = row.it.label
    dragIcon = row.it.icon
    rowH = row.height
    grabDy = pointerY - top
    moveDrag(pointerY)
  }
  function moveDrag(pointerY) {
    dragY = pointerY
    if (flick) flickPointer = root.mapToItem(flick, 0, pointerY).y
    // The section the pointer is over, or the nearest one.
    let best = "", bestD = Infinity
    for (const l of lists) {
      const s = sections[l]
      if (!s) continue
      const top = s.mapToItem(root, 0, 0).y, bottom = top + s.height
      const d = pointerY < top ? top - pointerY : pointerY > bottom ? pointerY - bottom : 0
      if (d < bestD) { bestD = d; best = l }
    }
    dropList = best
    const rows = rowsIn(best)
    let i = 0
    for (const r of rows) if (pointerY > r.mapToItem(root, 0, 0).y + r.height / 2) i++
    dropIndex = i
    const gap = col.spacing
    if (!rows.length) {
      const s = sections[best]
      lineY = s.emptyItem().mapToItem(root, 0, 0).y + s.emptyItem().height / 2
    } else if (i < rows.length) lineY = rows[i].mapToItem(root, 0, 0).y - gap / 2 - 1
    else { const r = rows[rows.length - 1]; lineY = r.mapToItem(root, 0, 0).y + r.height + gap / 2 - 1 }
  }
  function endDrag() {
    if (dragId && dropList) place(dragId, dropList, dropIndex)
    cancelDrag()
  }
  function cancelDrag() { dragId = ""; dropList = ""; dropIndex = -1 }

  // Near the scroll view's top or bottom edge the page scrolls under the
  // pointer, and the drop place follows.
  Timer {
    interval: 16
    repeat: true
    running: root.dragId !== "" && !!root.flick
    onTriggered: {
      const f = root.flick, edge = Tk.px(48)
      const step = root.flickPointer < edge ? -Tk.px(10) : root.flickPointer > f.height - edge ? Tk.px(10) : 0
      if (!step) return
      const max = Math.max(0, f.contentHeight - f.height + (f.bottomMargin || 0))
      const before = f.contentY
      f.contentY = Math.max(-(f.topMargin || 0), Math.min(max, f.contentY + step))
      if (f.contentY !== before) root.moveDrag(root.mapFromItem(f, 0, root.flickPointer).y)
    }
  }

  ColumnLayout {
    id: col
    anchors.left: parent.left
    anchors.right: parent.right
    spacing: Tk.spacing.extraSmall / 2

    Repeater {
      model: root.lists

      ColumnLayout {
        id: sec
        required property string modelData
        required property int index
        readonly property var ids: modelData === "removed" ? root.layout.removed : root.layout[modelData]
        Layout.fillWidth: true
        spacing: Tk.spacing.extraSmall / 2
        Component.onCompleted: { const m = root.sections; m[modelData] = sec; root.sections = m }
        function rowItems() {
          const out = []
          for (let i = 0; i < rowsRep.count; i++) { const r = rowsRep.itemAt(i); if (r) out.push(r) }
          return out
        }
        function emptyItem() { return empty }

        SectionHeader { first: sec.index === 0; row: ({ text: root.title(sec.modelData) }) }
        MText {
          id: empty
          Layout.fillWidth: true
          // Also the drop target of an empty section, so it keeps its room while dragging.
          visible: sec.ids.length === 0 || (sec.ids.length === 1 && sec.ids[0] === root.dragId)
          text: sec.modelData === "removed" ? "Everything is on the bar. Drag an item here to take it off."
            : "Empty. Drag an item here."
          color: Colours.m3outline
          wrapMode: Text.WordWrap
        }

        Repeater {
          id: rowsRep
          model: sec.ids

          ConnectedRect {
            id: r
            required property string modelData
            required property int index
            readonly property var it: root.info(modelData)
            readonly property bool off: sec.modelData === "removed"
            // A widget's own switch is bar.plugins.hidden (Settings › Taskbar › Plugins).
            readonly property bool isShown: it.plugin ? PluginService.barMode(BarLayout.pluginOf(modelData)) !== "hidden"
              : PluginService.itemShown(modelData)
            readonly property bool dim: off || !isShown
            Layout.fillWidth: true
            first: index === 0
            last: index === rowsRep.count - 1
            implicitHeight: rl.implicitHeight + Tk.padding.small * 2
            opacity: root.dragId === modelData ? 0.3 : 1

            RowLayout {
              id: rl
              anchors.fill: parent
              anchors.topMargin: Tk.padding.small
              anchors.bottomMargin: Tk.padding.small
              anchors.leftMargin: Tk.padding.small
              anchors.rightMargin: Tk.padding.medium
              spacing: Tk.spacing.medium

              // The drag handle.
              MouseArea {
                Layout.preferredWidth: Tk.iconSize.medium + Tk.padding.small * 2
                Layout.fillHeight: true
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                preventStealing: true
                onPressed: m => root.startDrag(r, mapToItem(root, m.x, m.y).y)
                onPositionChanged: m => { if (pressed) root.moveDrag(mapToItem(root, m.x, m.y).y) }
                onReleased: root.endDrag()
                onCanceled: root.cancelDrag()
                MIcon { anchors.centerIn: parent; text: "drag_indicator"; size: Tk.iconSize.medium; color: Colours.m3outline }
              }
              MIcon { text: r.it.icon; size: Tk.iconSize.medium; color: Colours.m3onSurfaceVariant; opacity: r.dim ? 0.45 : 1 }
              RowLabel {
                Layout.fillWidth: true
                opacity: r.dim ? 0.45 : 1
                text: r.it.label
                subtext: r.off ? "Not in the bar" : r.isShown ? r.it.sub : "Hidden"
              }
              IconButton {
                visible: !r.off && !r.it.plugin
                type: "text"
                icon: r.isShown ? "visibility" : "visibility_off"
                disabled: !r.it.key
                onClicked: PluginService.setItemShown(r.modelData, !r.isShown)
              }
              IconButton {
                visible: !r.off && !r.it.plugin
                type: "text"
                icon: "delete"
                onClicked: root.place(r.modelData, "removed", 0)
              }
              IconButton {
                visible: !!r.it.plugin
                type: "text"
                icon: "undo"
                onClicked: PluginService.putBackWidget(BarLayout.pluginOf(r.modelData))
              }
              IconButton {
                id: addBtn
                visible: r.off
                type: "text"
                icon: "add"
                onClicked: root.settings.openMenu(addBtn, addBtn, root.addOptions(""), "",
                  v => root.place(r.modelData, v, (root.layout[v] || []).length))
              }
            }
          }
        }
      }
    }

    SectionHeader { row: ({ text: "More" }) }
    RowSelect {
      Layout.fillWidth: true
      first: true
      last: false
      visible: root.groupWidgets.length > 0
      settings: root.settings
      row: ({
        label: "Take a plugin out of the group",
        subtext: "It gets a place of its own in the bar",
        options: [{ value: "", label: "Choose", icon: "add" }].concat(root.groupWidgets.map(p => ({ value: p.id, label: p.name, icon: "extension" })))
      })
      value: ""
      onPicked: v => { if (v) PluginService.takeOutWidget(v) }
    }

    // Reset, confirmed by a second click as Settings › About's "Reset all settings".
    ConnectedRect {
      Layout.fillWidth: true
      first: root.groupWidgets.length === 0
      last: true
      color: root.confirmReset ? Colours.m3errorContainer : Colours.m3surfaceContainer
      implicitHeight: rr.implicitHeight + Tk.padding.medium * 2
      StateLayer {
        color: Colours.m3error
        onClicked: {
          if (root.confirmReset) { PluginService.setBarLayout({ start: [], center: [], end: [], removed: [] }); root.confirmReset = false }
          else { root.confirmReset = true; confirmTimer.restart() }
        }
      }
      RowLayout {
        id: rr
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Tk.padding.largeIncreased
        anchors.rightMargin: Tk.padding.largeIncreased
        spacing: Tk.spacing.medium
        MIcon { text: root.confirmReset ? "warning" : "restart_alt"; size: Tk.iconSize.medium; fill: 1; color: Colours.m3error }
        RowLabel {
          Layout.fillWidth: true
          text: root.confirmReset ? "Click again to reset the layout" : "Reset layout"
          subtext: "Every item back where it was, plugins back in the group"
        }
      }
    }
  }
  property bool confirmReset: false
  Timer { id: confirmTimer; interval: 3000; onTriggered: root.confirmReset = false }

  // The dragged row, following the pointer.
  Rectangle {
    visible: root.dragId !== ""
    z: 10
    x: 0
    width: root.width
    y: root.dragY - root.grabDy
    height: root.rowH
    radius: Tk.rounding.small
    color: Colours.m3surfaceContainerHighest
    border.width: 1
    border.color: Colours.m3primary
    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: Tk.padding.small
      anchors.rightMargin: Tk.padding.medium
      spacing: Tk.spacing.medium
      MIcon { Layout.preferredWidth: Tk.iconSize.medium + Tk.padding.small * 2; horizontalAlignment: Text.AlignHCenter; text: "drag_indicator"; size: Tk.iconSize.medium; color: Colours.m3primary }
      MIcon { text: root.dragIcon; size: Tk.iconSize.medium; color: Colours.m3onSurface }
      MText { Layout.fillWidth: true; text: root.dragLabel; color: Colours.m3onSurface }
    }
  }
  // Where it will land.
  Rectangle {
    visible: root.dragId !== "" && root.dropList !== ""
    z: 9
    x: Tk.padding.small
    width: root.width - Tk.padding.small * 2
    y: root.lineY
    height: 3
    radius: 1.5
    color: Colours.m3primary
  }
}
