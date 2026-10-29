pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import "../../.."

// Optional dock in the bar. The pill, metrics and scrolling follow the
// Caelestia tray (bar/components/Tray.qml), using Omacale's edge abstraction.
Rectangle {
  id: entry
  required property var bar
  property string entryId: "apps"
  readonly property bool shown: bar.cfg.apps.enabled
  visible: shown
  Layout.alignment: bar.crossAlign
  color: Colours.m3surfaceContainer
  radius: Tk.rounding.full
  readonly property real cell: Tk.barInner - Tk.padding.small * 2
  readonly property real pad: Tk.padding.small
  readonly property real spacingN: Tk.spacing.small
  readonly property real minLen: cell + pad * 2
  readonly property real fullLen: Math.min(slots.count + 1, Math.max(1, bar.cfg.apps.maxShown)) * (cell + spacingN) - spacingN + pad * 2
  readonly property real sizeLen: shown ? Math.min(fullLen, minLen + bar.appsExtra) : 0
  implicitWidth: bar.vertical ? Tk.barInner : sizeLen
  implicitHeight: bar.vertical ? sizeLen : Tk.barInner
  clip: true
  Behavior on implicitHeight { enabled: bar.vertical; Anim {} }
  Behavior on implicitWidth { enabled: !bar.vertical; Anim {} }

  Component.onCompleted: { bar.registerEntry(entry); sync() }
  Component.onDestruction: bar.unregisterEntry(entry)
  ListModel { id: slots }
  // A running app's state may change every focus event. Retain its slot so
  // a change cannot destroy a pressed button or the keyboard's cursor.
  function sync() {
    const ids = TaskbarApps.items.map(i => i.id)
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
  function configure() { bar.scope.barFocus = false; bar.host.toggle("settings", "taskbarApps") }

  MFlickable {
    id: flick
    anchors.fill: parent
    anchors.margins: entry.pad
    contentWidth: bar.vertical ? width : cells.implicitWidth
    contentHeight: bar.vertical ? cells.implicitHeight : height
    interactive: bar.vertical ? contentHeight > height : contentWidth > width
    clip: true
    Grid {
      id: cells
      columns: bar.vertical ? 1 : 1000
      spacing: entry.spacingN
      Repeater {
        id: rep
        model: slots
        Rectangle {
          id: slot
          required property string key
          readonly property var appItem: TaskbarApps.items.find(i => i.id === key) || null
          readonly property bool active: TaskbarApps.active(appItem)
          width: entry.cell
          height: width
          radius: Tk.rounding.small
          color: active ? Colours.m3secondaryContainer : "transparent"
          Behavior on color { CAnim {} }
          StateLayer {
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            onClicked: e => {
              if (e && e.button === Qt.RightButton) entry.configure()
              else entry.openItem(slot.appItem, slot, !!e && e.button === Qt.MiddleButton)
            }
          }
          IconImage {
            anchors.centerIn: parent
            implicitSize: entry.cell
            source: TaskbarApps.icon(slot.appItem)
            visible: !!slot.appItem && slot.appItem.type === "app"
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
          Accessible.name: TaskbarApps.label(appItem)
          Accessible.onPressAction: entry.openItem(appItem, slot, false)
        }
      }
      IconButton {
        id: settingsButton
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
  function navStops() {
    const out = []
    for (let i = 0; i < rep.count; i++) {
      const it = rep.itemAt(i)
      if (it) out.push({ item: it, kind: "taskbarApp", flick: flick, act: () => entry.openItem(it.appItem, it, false) })
    }
    out.push({ item: settingsButton, kind: "taskbarApp", flick: flick, act: () => entry.configure() })
    return out
  }
  function cursorMoved(stop) {
    if (!stop || stop.kind !== "taskbarApp") return
    const pos = bar.apos(stop.item), size = bar.alen(stop.item)
    if (bar.vertical) flick.contentY = Math.max(0, Math.min(pos, Math.max(flick.contentY, pos + size - flick.height)))
    else flick.contentX = Math.max(0, Math.min(pos, Math.max(flick.contentX, pos + size - flick.width)))
  }
  function scrollAt(a, dy) { return shown && bar.scrollList(flick, a, dy) }
  function popoutCenterFor(name) { return name === "appgroup" ? bar.centreOf(entry) : undefined }
}
