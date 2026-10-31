pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import "../../.."

// Optional dock in the existing bar. Layout, popouts and keyboard focus use
// the same edge abstraction as Caelestia's tray, including its space budget.
Rectangle {
  id: entry
  required property var bar
  property string entryId: "apps"
  readonly property bool showSettings: bar.cfg.apps.showSettings
  readonly property bool empty: slots.count === 0 && !showSettings
  readonly property bool shown: bar.cfg.apps.enabled && !empty
  visible: shown
  Layout.alignment: bar.crossAlign
  color: Colours.m3surfaceContainer
  radius: Tk.rounding.full
  readonly property real cell: Tk.barInner - Tk.padding.small * 2
  readonly property real pad: Tk.padding.small
  readonly property real spacingN: Tk.spacing.small
  readonly property int pinnedCount: TaskbarApps.items.filter(i => TaskbarApps.isSaved(i)).length
  readonly property bool divided: pinnedCount > 0 && pinnedCount < slots.count
  readonly property real dividerSpace: divided ? Tk.spacing.small + Tk.px(2) : 0
  readonly property int cellCount: slots.count + (showSettings ? 1 : 0)
  readonly property real naturalLen: empty ? 0 : cellCount * (cell + spacingN) - spacingN + pad * 2 + dividerSpace
  readonly property real fullLen: bar.cfg.apps.useAvailableSpace ? naturalLen
    : Math.min(naturalLen, Math.max(1, bar.cfg.apps.maxShown) * (cell + spacingN) - spacingN + pad * 2)
  readonly property real minLen: Math.min(fullLen, cell + pad * 2)
  readonly property real sizeLen: shown ? Math.min(fullLen, minLen + bar.appsExtra) : 0
  implicitWidth: bar.vertical ? Tk.barInner : sizeLen
  implicitHeight: bar.vertical ? sizeLen : Tk.barInner
  clip: true
  Behavior on implicitHeight { enabled: bar.vertical; Anim {} }
  Behavior on implicitWidth { enabled: !bar.vertical; Anim {} }

  Component.onCompleted: { bar.registerEntry(entry); sync() }
  Component.onDestruction: bar.unregisterEntry(entry)
  ListModel { id: slots }
  // Retain delegates during focus changes and pin reordering. A pressed cell
  // keeps its pointer grab; configuration is committed only on drop.
  function sync() {
    const ids = TaskbarApps.items.map(i => i.id)
    if (dragItem && ids.indexOf(dragItem.id) < 0) cancelDrag()
    for (let i = 0; i < ids.length; i++) {
      if (i < slots.count && slots.get(i).key === ids[i]) continue
      let from = -1
      for (let j = i + 1; j < slots.count; j++) if (slots.get(j).key === ids[i]) { from = j; break }
      if (from >= 0) slots.move(from, i, 1)
      else slots.insert(i, { key: ids[i] })
    }
    if (slots.count > ids.length) slots.remove(ids.length, slots.count - ids.length)
    Qt.callLater(clampScroll)
  }
  function clampScroll() {
    flick.contentX = Math.max(0, Math.min(flick.contentX, flick.contentWidth - flick.width))
    flick.contentY = Math.max(0, Math.min(flick.contentY, flick.contentHeight - flick.height))
  }
  Connections { target: TaskbarApps; function onItemsChanged() { entry.sync() } }
  onSizeLenChanged: Qt.callLater(clampScroll)
  function openItem(item, target, newInstance) {
    if (!item) return
    if (item.type === "group") {
      if (bar.scope.popout === "appgroup" && bar.scope.appGroup === item.id) { bar.scope.popout = ""; return }
      bar.scope.appGroup = item.id
      bar.scope.openPopoutKeys("appgroup")
      bar.scope.popoutCenter = bar.centreOf(target)
    } else {
      bar.scope.barFocus = false
      bar.scope.popout = ""
      TaskbarApps.activate(item, bar.host, newInstance)
    }
  }
  property string menuKey: ""
  function openMenu(item, target) {
    if (!item) return
    menuKey = item.id
    bar.scope.appMenuItem = item
    bar.scope.openPopoutKeys("appmenu")
    bar.scope.popoutCenter = bar.centreOf(target)
  }
  function configure() { bar.scope.barFocus = false; bar.host.toggle("settings", "taskbarApps") }

  property var dragItem: null
  property point pressPoint
  property bool dragging: false
  property bool dropValid: false
  property string beforeId: ""
  property real dropLine: 0
  function beginPress(item, point) {
    dragItem = item
    pressPoint = point
    dragging = false
    dropValid = false
  }
  function moveDrag(point) {
    if (!dragItem) return
    const distance = Math.hypot(point.x - pressPoint.x, point.y - pressPoint.y)
    if (!dragging && distance < Tk.px(8)) return
    if (!dragging) { dragging = true; bar.scope.popout = "" }
    dropValid = point.x >= 0 && point.y >= 0 && point.x <= width && point.y <= height
    if (!dropValid) return
    // Move toward a clipped edge to reveal more pins without a polling timer.
    const a = bar.vertical ? point.y : point.x, length = bar.vertical ? height : width
    if (a < pad + cell / 2 || a > length - pad - cell / 2) {
      const step = a < length / 2 ? -cell / 2 : cell / 2
      if (bar.vertical) flick.contentY += step
      else flick.contentX += step
      clampScroll()
    }
    beforeId = ""
    dropLine = pad
    for (let i = 0; i < rep.count; i++) {
      const button = rep.itemAt(i).button
      if (!TaskbarApps.isSaved(button.appItem)) break
      const p = button.mapToItem(entry, 0, 0), start = bar.vertical ? p.y : p.x
      if (a < start + cell / 2) { beforeId = button.appItem.id; dropLine = start - spacingN / 2; return }
      dropLine = start + cell + spacingN / 2
    }
  }
  function finishDrag() {
    const item = dragItem, commit = dragging && dropValid
    const before = beforeId
    cancelDrag()
    if (commit) TaskbarApps.place(item, before)
  }
  function cancelDrag() { dragItem = null; dragging = false; dropValid = false }

  MFlickable {
    id: flick
    anchors.fill: parent
    anchors.margins: entry.pad
    contentWidth: bar.vertical ? width : cells.implicitWidth
    contentHeight: bar.vertical ? cells.implicitHeight : height
    interactive: !entry.dragging && (bar.vertical ? contentHeight > height : contentWidth > width)
    clip: true
    Grid {
      id: cells
      columns: bar.vertical ? 1 : 1000
      spacing: entry.spacingN
      Repeater {
        id: rep
        model: slots
        Item {
          id: wrapper
          required property string key
          required property int index
          readonly property bool hasDivider: entry.divided && index === entry.pinnedCount
          readonly property real lead: hasDivider ? entry.dividerSpace : 0
          property alias button: slot
          width: bar.vertical ? entry.cell : entry.cell + lead
          height: bar.vertical ? entry.cell + lead : entry.cell
          Rectangle {
            objectName: "taskbarAppsDivider"
            visible: wrapper.hasDivider
            width: bar.vertical ? entry.cell * 0.7 : Tk.px(2)
            height: bar.vertical ? Tk.px(2) : entry.cell * 0.7
            x: bar.vertical ? (entry.cell - width) / 2 : wrapper.lead / 2
            y: bar.vertical ? wrapper.lead / 2 : (entry.cell - height) / 2
            radius: Tk.px(1)
            color: Colours.m3outline
          }
          Rectangle {
            id: slot
            readonly property var appItem: TaskbarApps.items.find(i => i.id === wrapper.key) || null
            readonly property bool saved: TaskbarApps.isSaved(appItem)
            readonly property bool active: TaskbarApps.active(appItem)
            readonly property real iconOpacity: active || saved || state.containsMouse ? 1 : 0.65
            x: bar.vertical ? 0 : wrapper.lead
            y: bar.vertical ? wrapper.lead : 0
            width: entry.cell
            height: width
            radius: Tk.rounding.small
            color: active ? Colours.m3secondaryContainer : "transparent"
            opacity: entry.dragging && entry.dragItem && entry.dragItem.id === wrapper.key ? 0.4 : 1
            Behavior on color { CAnim {} }
            StateLayer {
              id: state
              property bool moved: false
              acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
              preventStealing: true
              cursorShape: entry.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
              onPressed: e => {
                moved = false
                if (e.button === Qt.LeftButton) entry.beginPress(slot.appItem, mapToItem(entry, e.x, e.y))
              }
              onPositionChanged: e => {
                if (pressed && (pressedButtons & Qt.LeftButton)) {
                  entry.moveDrag(mapToItem(entry, e.x, e.y))
                  moved = moved || entry.dragging
                }
              }
              onReleased: e => {
                if (e.button === Qt.LeftButton) {
                  entry.moveDrag(mapToItem(entry, e.x, e.y))
                  moved = moved || entry.dragging
                  entry.finishDrag()
                }
              }
              onCanceled: { moved = true; entry.cancelDrag() }
              onClicked: e => {
                if (moved) return
                if (e && e.button === Qt.RightButton) entry.openMenu(slot.appItem, slot)
                else entry.openItem(slot.appItem, slot, !!e && e.button === Qt.MiddleButton)
              }
            }
            IconImage {
              anchors.centerIn: parent
              implicitSize: entry.cell
              source: TaskbarApps.icon(slot.appItem)
              visible: !!slot.appItem && slot.appItem.type === "app"
              opacity: slot.iconOpacity
            }
            MIcon {
              anchors.centerIn: parent
              visible: !!slot.appItem && (slot.appItem.type === "folder" || (slot.appItem.type === "group" && preview.count === 0))
              text: slot.appItem && slot.appItem.type === "group" ? "apps" : "folder"
              color: Colours.m3primary
              size: entry.cell * 0.75
            }
            Grid {
              anchors.centerIn: parent
              columns: preview.count === 1 ? 1 : 2
              spacing: Tk.px(2)
              visible: preview.count > 0
              Repeater {
                id: preview
                model: slot.appItem && slot.appItem.type === "group" ? slot.appItem.apps.filter(id => TaskbarApps.entry(id)).slice(0, 4) : []
                IconImage {
                  required property string modelData
                  implicitSize: preview.count === 1 ? entry.cell : (entry.cell - Tk.px(2)) / 2
                  source: TaskbarApps.icon({ type: "app", app: modelData })
                }
              }
            }
            Rectangle {
              visible: TaskbarApps.windowsFor(slot.appItem).length > 0
              width: Tk.px(4)
              height: width
              radius: width / 2
              color: slot.active ? Colours.m3onSecondaryContainer : Colours.m3primary
              x: bar.edge === "right" ? Tk.px(2) : bar.vertical ? parent.width - width - Tk.px(2) : (parent.width - width) / 2
              y: bar.edge === "bottom" ? Tk.px(2) : bar.vertical ? (parent.height - height) / 2 : parent.height - height - Tk.px(2)
            }
            Accessible.role: Accessible.Button
            Accessible.name: TaskbarApps.label(appItem) + (saved ? ", pinned" : ", running")
            Accessible.onPressAction: entry.openItem(appItem, slot, false)
          }
        }
      }
      IconButton {
        id: settingsButton
        visible: entry.showSettings
        width: entry.cell
        height: width
        implicitWidth: width
        implicitHeight: height
        padding: 0
        icon: "tune"
        type: "text"
        iconSize: Tk.iconSize.medium
        onClicked: entry.configure()
        Accessible.name: "Configure taskbar apps"
      }
    }
  }
  Rectangle {
    visible: entry.dragging && entry.dropValid
    width: bar.vertical ? entry.cell : Tk.px(2)
    height: bar.vertical ? Tk.px(2) : entry.cell
    x: bar.vertical ? entry.pad : entry.dropLine
    y: bar.vertical ? entry.dropLine : entry.pad
    color: Colours.m3primary
    radius: Tk.px(1)
  }
  function navStops() {
    const out = []
    for (let i = 0; i < rep.count; i++) {
      const it = rep.itemAt(i).button
      out.push({ item: it, kind: "taskbarApp", flick: flick, act: () => entry.openItem(it.appItem, it, false), menu: () => entry.openMenu(it.appItem, it) })
    }
    if (showSettings) out.push({ item: settingsButton, kind: "taskbarApp", flick: flick, act: () => entry.configure() })
    return out
  }
  function cursorMoved(stop) {
    if (!stop || stop.kind !== "taskbarApp") return
    const pos = stop.item.mapToItem(cells, 0, 0), a = bar.vertical ? pos.y : pos.x, size = entry.cell
    if (bar.vertical) flick.contentY = Math.max(0, Math.min(a, Math.max(flick.contentY, a + size - flick.height)))
    else flick.contentX = Math.max(0, Math.min(a, Math.max(flick.contentX, a + size - flick.width)))
  }
  function scrollAt(a, dy) { return shown && bar.scrollList(flick, a, dy) }
  function popoutCenterFor(name) {
    if (name !== "appgroup" && name !== "appmenu") return undefined
    if (name === "appmenu") for (let i = 0; i < rep.count; i++)
      if (rep.itemAt(i).key === menuKey) return bar.centreOf(rep.itemAt(i).button)
    return bar.centreOf(entry)
  }
}
