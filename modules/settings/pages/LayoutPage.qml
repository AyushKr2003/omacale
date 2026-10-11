import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import "../../.."
import "../../../core/BarLayout.js" as BarLayout

// Settings › Taskbar's bar: everything in it (bar.layout), Noctalia-style; no
// Caelestia original.
//
// The sections, and in each the items grouped as the bar draws them: neighbours that share a pill (BarLayout.groups) sit in one
// card. Omacale's own items, Omarchy's widgets and plugins are rows alike;
// only the last two carry a chip. The chevron's row opens to what is behind
// it (bar.layout.drawer) and the "at most N icons" limit; the plugin pill's
// row to its widgets. "Not shown" (bar.layout.removed) and "Add a widget"
// are folded away until opened.
//
// Rows are dragged by their handle to any place in any section, into or out
// of the chevron or the plugin pill, and into "Not shown" (which opens while
// a row is over it). The eye is the item's existing switch (Status icons ›
// Network, Clock › Show, ...): hidden, an item keeps its place; the gear
// opens its own settings.
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
  // The widget list (names, categories, which are enabled) comes from Omarchy.
  Component.onCompleted: PluginService.refresh()
  // New marks last until the page is left.
  Component.onDestruction: PluginService.clearFresh()

  readonly property var layout: {
    const l = Config.o.bar.layout
    void l.start; void l.center; void l.end; void l.removed; void l.drawer
    void PluginService.barWidgets
    return PluginService.barLayout()
  }
  readonly property bool vertical: Tk.barVertical
  // Nested lists first, so a drop over their rows lands in them rather than
  // in the section around them.
  readonly property var lists: ["pill", "drawer"].concat(BarLayout.SECTIONS).concat(["removed"])
  readonly property var pillIds: PluginService.pillWidgets.map(p => p.id)
  readonly property var placed: BarLayout.SECTIONS.concat(["drawer", "removed"]).reduce((out, s) =>
    out.concat(root.layout[s].filter(id => BarLayout.isPlugin(id)).map(id => BarLayout.pluginOf(id))), [])
  // Third-party widgets still in the pill, in the order the pill shows them.
  readonly property var pillMembers: PluginService.pillWidgets.filter(p => root.placed.indexOf(p.id) < 0).map(p => "plugin:" + p.id)
  readonly property bool chevronOff: root.layout.removed.indexOf("overflow") >= 0

  // Folded parts. The chevron's starts open, the rest closed.
  property bool chevronOpen: true
  property bool pillOpen: true
  property bool removedOpen: false
  property bool addOpen: false

  // A row's facts, built-in or widget.
  function info(id) {
    if (BarLayout.isPlugin(id)) {
      const pid = BarLayout.pluginOf(id)
      const p = PluginService.byId(pid)
      const err = PluginService.widgetErrors[pid] || ""
      return {
        label: p ? p.name : pid, icon: BarLayout.categoryIcon(p ? p.category : ""), source: p && p.firstParty ? "omarchy" : "plugin",
        note: err ? "Couldn't load: " + err : "", error: err !== "", key: "", page: "", plugin: true, pluginId: pid,
        inPill: root.pillIds.indexOf(pid) >= 0, fresh: Config.o.bar.layout.fresh.indexOf(pid) >= 0
      }
    }
    const it = BarLayout.ITEMS[id] || { label: id, icon: "help", key: "" }
    const behind = root.layout.drawer.length + root.limitFolded.length
    return {
      label: id === "plugins" ? "Plugin pill" : id === "overflow" ? "Chevron" : it.label, icon: it.icon, source: "",
      note: id === "overflow" ? (behind ? behind + " behind it" : "nothing behind it yet")
        : id === "plugins" ? (root.pillMembers.length ? root.pillMembers.length + " widgets" : "empty") : "",
      error: false, key: it.key, page: BarLayout.PAGES[id] || "", plugin: false, pluginId: "", inPill: false, fresh: false
    }
  }
  // Whether the bar draws an item now, decided as BarContent.onShow does:
  // an item can be on and still draw nothing (an empty tray, no battery).
  function drawnOnBar(id) {
    if (BarLayout.isPlugin(id)) {
      const pid = BarLayout.pluginOf(id)
      return PluginService.barWidgets.some(p => p.id === pid) && !(root.pillIds.indexOf(pid) >= 0 && PluginService.barMode(pid) === "hidden")
    }
    if (id === "plugins") return root.pillMembers.length > 0 && PluginService.itemShown(id)
    if (id === "tray") return Config.o.bar.tray.enabled && SystemTray.items.values.some(i => i.status !== Status.Passive
      && Config.o.bar.tray.hiddenIcons.indexOf(i.id) < 0)
    if (BarLayout.STATUS.indexOf(id) >= 0) return PluginService.statusOn(id)
    return PluginService.itemShown(id)
  }
  // Why an item that is on isn't on the bar now: the ones that only show
  // while there is something to say.
  function whenShown(id) {
    const why = {
      keepAwake: "shows only while keep awake is on",
      update: "shows only when an update is waiting",
      recording: "shows only while recording",
      lockStatus: "shows only while Caps or Num Lock is on",
      microphone: "shows only while an app uses the microphone",
      bluetooth: "shows only while a device is connected",
      tray: "shows only when an app is in the tray",
      plugins: "shows only when the pill has widgets"
    }
    return why[id] || "nothing to show now"
  }
  // The items the "at most N icons" limit puts behind the chevron, worked out
  // by the bar's own BarLayout.render.
  readonly property var limitFolded: {
    const max = Config.o.bar.layout.maxShown
    if (max <= 0) return []
    const r = BarLayout.render(root.layout, max, id => root.drawnOnBar(id))
    const drawer = root.layout.drawer
    const out = []
    for (const sec of BarLayout.SECTIONS)
      for (const e of r[sec]) if (e.drawer && drawer.indexOf(e.id) < 0) out.push(e.id)
    return out
  }

  function openSettings(it) {
    if (it.plugin) { root.settings.selectedPlugin = it.pluginId; root.settings.push("pluginInfo") }
    else if (it.page) root.settings.push(it.page)
  }
  function place(id, list, index) { PluginService.placeItem(id, list, index) }
  // "Add to" menu for a row: every section but the one it is in.
  function addOptions(from) {
    return BarLayout.SECTIONS.filter(s => s !== from).map(s => ({ value: s, label: BarLayout.sectionLabel(s, vertical), icon: s === "start" ? "first_page" : s === "end" ? "last_page" : "horizontal_distribute" }))
  }

  // Every row of a list, wherever its card put it, in page order.
  function rowsOf(item, list, out) {
    if (!item) return out
    for (const c of item.children) {
      if (c.barRow === true && c.list === list && c.visible) out.push(c)
      rowsOf(c, list, out)
    }
    return out
  }
  function rowsFor(list) {
    const s = sections[list]
    return s ? rowsOf(s, list, []).sort((a, b) => a.mapToItem(root, 0, 0).y - b.mapToItem(root, 0, 0).y) : []
  }
  // ------------------------------------------------------------- add list
  // Every bar widget that is nowhere in the bar: not placed, not in the pill
  // (third-party ones that are on are always there), not taken off. Omarchy's
  // versions of Omacale's own items only with the switch on.
  readonly property var addable: {
    void Config.o.bar.layout.removed
    const dup = Config.o.bar.layout.showDuplicates
    return PluginService.widgetCatalog.filter(p =>
      root.placed.indexOf(p.id) < 0 && !(p.source === "plugin" && p.enabled)
      && (dup || p.duplicateOf === null))
  }
  // [{ category, items }] sorted by category, then name.
  readonly property var addGroups: {
    const by = {}
    for (const p of root.addable) {
      const c = p.category || "Other"
      ;(by[c] = by[c] || []).push(p)
    }
    return Object.keys(by).sort().map(c => ({ category: c, items: by[c].sort((a, b) => a.name.localeCompare(b.name)) }))
  }
  readonly property int duplicateCount: PluginService.widgetCatalog.filter(p => p.duplicateOf !== null && root.placed.indexOf(p.id) < 0).length

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
  property var sections: ({})    // list -> the item holding its rows
  function register(list, item) { const m = root.sections; m[list] = item; root.sections = m }
  function unregister(list, item) { if (root.sections[list] === item) { const m = root.sections; delete m[list]; root.sections = m } }

  // The settings page's scroll view, for scrolling while dragging near its edge.
  readonly property Item flick: { let f = root.parent; while (f && f.contentY === undefined) f = f.parent; return f }
  property real flickPointer: 0  // pointer, in the scroll view's coordinates

  // Only a third-party widget can go into the pill; the chevron can't go
  // behind itself.
  function canDrop(list) {
    if (list === "pill") return BarLayout.isPlugin(dragId) && pillIds.indexOf(BarLayout.pluginOf(dragId)) >= 0
    if (list === "drawer") return dragId !== "overflow"
    return true
  }
  function rowsIn(list) { return rowsFor(list).filter(r => r.modelData !== dragId) }
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
    // The list the pointer is over, or the nearest one.
    let best = "", bestD = Infinity
    for (const l of lists) {
      const s = sections[l]
      if (!s || !s.visible || !canDrop(l)) continue
      const top = s.mapToItem(root, 0, 0).y, bottom = top + s.height
      const d = pointerY < top ? top - pointerY : pointerY > bottom ? pointerY - bottom : 0
      if (d < bestD) { bestD = d; best = l }
    }
    dropList = best
    if (!best) return
    // "Not shown" opens under a row held over it.
    if (best === "removed" && bestD === 0 && !removedOpen) removedOpen = true
    const rows = rowsIn(best)
    let i = 0
    for (const r of rows) if (pointerY > r.mapToItem(root, 0, 0).y + r.height / 2) i++
    dropIndex = i
    const gap = Tk.spacing.extraSmall / 2
    if (!rows.length) lineY = sections[best].emptyItem().mapToItem(root, 0, 0).y - gap / 2 - 1
    else if (i < rows.length) lineY = rows[i].mapToItem(root, 0, 0).y - gap / 2 - 1
    else { const r = rows[rows.length - 1]; lineY = r.mapToItem(root, 0, 0).y + r.height + gap / 2 - 1 }
  }
  function endDrag() {
    if (dragId && dropList === "pill") PluginService.putBackWidget(BarLayout.pluginOf(dragId))
    else if (dragId && dropList) place(dragId, dropList, dropIndex)
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

  // ------------------------------------------------------------- pieces
  // One compact row: handle, icon, name, chip, a short note, and its actions.
  component BarRow: ConnectedRect {
    id: r
    required property string modelData
    property string list            // which list it is a row of (drag and drop)
    readonly property bool barRow: true
    readonly property bool off: list === "removed"
    readonly property bool child: list === "pill"
    readonly property var it: root.info(modelData)
    readonly property string mode: it.inPill ? PluginService.barMode(it.pluginId) : ""
    // The eye: a built-in's existing switch; a pill widget's hidden mode.
    readonly property bool isShown: child ? mode !== "hidden" : it.plugin ? true : PluginService.itemShown(modelData)
    readonly property bool dim: off || !isShown
    // The extra line of a folding row (the chevron, the plugin pill).
    property bool foldable: false
    property bool folded: false
    signal toggleFold()

    Layout.fillWidth: true
    implicitHeight: rl.implicitHeight + Tk.padding.small * 2
    opacity: root.dragId === modelData ? 0.3 : 1

    RowLayout {
      id: rl
      anchors.fill: parent
      anchors.topMargin: Tk.padding.small
      anchors.bottomMargin: Tk.padding.small
      anchors.leftMargin: Tk.padding.extraSmall
      anchors.rightMargin: Tk.padding.small
      spacing: Tk.spacing.small

      // The drag handle.
      MouseArea {
        Layout.preferredWidth: Tk.iconSize.medium + Tk.padding.small
        Layout.fillHeight: true
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        preventStealing: true
        onPressed: m => root.startDrag(r, mapToItem(root, m.x, m.y).y)
        onPositionChanged: m => { if (pressed) root.moveDrag(mapToItem(root, m.x, m.y).y) }
        onReleased: root.endDrag()
        onCanceled: root.cancelDrag()
        MIcon { anchors.centerIn: parent; text: "drag_indicator"; size: Tk.iconSize.small; color: Colours.m3outline }
      }
      MIcon {
        text: r.it.error ? "error" : r.it.icon
        size: Tk.iconSize.small
        color: r.it.error ? Colours.m3error : r.modelData === "power" ? Colours.m3error : Colours.m3onSurfaceVariant
        opacity: r.dim && !r.it.error ? 0.45 : 1
      }
      RowLayout {
        Layout.fillWidth: true
        spacing: Tk.spacing.small
        opacity: r.dim && !r.it.error ? 0.5 : 1
        MText { text: r.it.label; font.pointSize: Tk.body.small; elide: Text.ElideRight; Layout.maximumWidth: rl.width * 0.45 }
        SourceChip { visible: r.it.source !== ""; source: r.it.source }
        SourceChip { visible: r.it.fresh; source: "new" }
        MText {
          Layout.fillWidth: true
          readonly property string note: r.it.error ? r.it.note
            : !r.off && !r.isShown ? "hidden" : r.child && r.mode === "overflow" ? "behind the pill's chevron"
            : r.list !== "drawer" && root.limitFolded.indexOf(r.modelData) >= 0 ? "behind the chevron (icon limit)"
            : !r.off && !r.child && r.list !== "removed" && !r.it.plugin && !root.drawnOnBar(r.modelData) ? root.whenShown(r.modelData)
            : r.it.note
          visible: note !== ""
          text: "· " + note
          color: r.it.error ? Colours.m3error : Colours.m3outline
          font.pointSize: Tk.label.small
          elide: Text.ElideRight
        }
        Item { Layout.fillWidth: true; visible: !r.it.note && r.isShown && !r.it.error }
      }
      // Three fixed columns (eye, settings or fold, remove), so the buttons
      // line up down the list whichever a row has.
      ActionSlot {
        shown: !r.off && (r.child || (!r.it.plugin && !!r.it.key))
        icon: r.isShown ? "visibility" : "visibility_off"
        onClicked: r.child ? PluginService.setBarMode(r.it.pluginId, r.isShown ? "hidden" : "pinned")
          : PluginService.setItemShown(r.modelData, !r.isShown)
      }
      ActionSlot {
        id: moreBtn
        shown: r.foldable || r.child || r.it.plugin || r.it.page !== ""
        icon: r.foldable ? (r.folded ? "expand_more" : "expand_less") : r.child ? "more_vert" : "settings"
        onClicked: {
          if (r.foldable) { r.toggleFold(); return }
          if (!r.child) { root.openSettings(r.it); return }
          root.settings.openMenu(moreBtn, moreBtn, [
            { value: "pinned", label: "Always in the pill", icon: "push_pin" },
            { value: "drawer", label: "Behind the chevron", icon: "expand_more" },
            { value: "out", label: "A place of its own", icon: "open_in_new" },
            { value: "info", label: "About this plugin", icon: "info" }
          ], r.mode, v => {
            if (v === "out") PluginService.takeOutWidget(r.it.pluginId)
            else if (v === "drawer") root.place(r.modelData, "drawer", root.layout.drawer.length)
            else if (v === "info") root.openSettings(r.it)
            else PluginService.setBarMode(r.it.pluginId, v)
          })
        }
      }
      ActionSlot {
        id: lastBtn
        // Off the bar (a third-party widget back into the pill instead), or,
        // under "Not shown", back onto it.
        shown: !r.child
        icon: r.off ? "add" : r.it.inPill ? "move_down" : "close"
        onClicked: {
          if (r.off) root.settings.openMenu(lastBtn, lastBtn, root.addOptions(""), "",
            v => root.place(r.modelData, v, (root.layout[v] || []).length))
          else if (r.it.inPill) PluginService.putBackWidget(r.it.pluginId)
          else root.place(r.modelData, "removed", 0)
        }
      }
    }
  }

  // One of a row's action columns: keeps its room when the row has no such action.
  component ActionSlot: Item {
    id: slot
    property bool shown: true
    property string icon
    signal clicked()
    implicitWidth: btn.implicitWidth
    implicitHeight: btn.implicitHeight
    IconButton {
      id: btn
      visible: slot.shown
      type: "text"
      icon: slot.icon
      iconSize: Tk.iconSize.small
      onClicked: slot.clicked()
    }
  }

  // Where a row comes from, when that isn't Omacale itself (or "new").
  component SourceChip: Rectangle {
    property string source
    readonly property var look: ({
      omarchy: { text: "Omarchy", bg: Colours.m3tertiaryContainer, fg: Colours.m3onTertiaryContainer },
      plugin: { text: "Plugin", bg: Colours.m3secondaryContainer, fg: Colours.m3onSecondaryContainer },
      "new": { text: "New", bg: Colours.m3primary, fg: Colours.m3onPrimary }
    })[source] || { text: source, bg: Colours.m3surfaceContainerHigh, fg: Colours.m3onSurface }
    implicitWidth: chipText.implicitWidth + Tk.padding.small * 2
    implicitHeight: chipText.implicitHeight + Tk.padding.extraSmall / 2
    radius: height / 2
    color: look.bg
    MText {
      id: chipText
      anchors.centerIn: parent
      text: parent.look.text
      color: parent.look.fg
      font.pointSize: Tk.label.small * 0.9
      weight: Font.Medium
    }
  }

  // A small heading, or a folding one with a count.
  component Heading: RowLayout {
    id: h
    property string text
    property int count: -1
    property bool foldable: false
    property bool open: true
    signal toggled()
    Layout.fillWidth: true
    Layout.topMargin: Tk.spacing.medium
    spacing: Tk.spacing.small
    MText {
      Layout.leftMargin: Tk.padding.small
      text: h.text + (h.count >= 0 ? "  " + h.count : "")
      color: Colours.m3onSurfaceVariant
      font.pointSize: Tk.label.large
      weight: Font.Medium
    }
    Item { Layout.fillWidth: true }
    IconButton {
      visible: h.foldable
      type: "text"
      icon: h.open ? "expand_less" : "expand_more"
      iconSize: Tk.iconSize.small
      onClicked: h.toggled()
    }
  }

  // ------------------------------------------------------------- page
  ColumnLayout {
    id: col
    anchors.left: parent.left
    anchors.right: parent.right
    spacing: Tk.spacing.extraSmall / 2

    // The three sections, each its groups.
    Repeater {
      model: BarLayout.SECTIONS

      ColumnLayout {
        id: sec
        required property string modelData
        readonly property var ids: root.layout[modelData]
        Layout.fillWidth: true
        spacing: Tk.spacing.extraSmall / 2
        Component.onCompleted: root.register(modelData, sec)
        Component.onDestruction: root.unregister(modelData, sec)
        function emptyItem() { return empty }

        Heading { text: BarLayout.sectionLabel(sec.modelData, root.vertical) }
        MText {
          id: empty
          Layout.fillWidth: true
          Layout.leftMargin: Tk.padding.small
          // Also the drop target of an empty section, so it keeps its room while dragging.
          visible: sec.ids.length === 0 || (sec.ids.length === 1 && sec.ids[0] === root.dragId)
          text: "Empty. Drag an item here."
          color: Colours.m3outline
          font.pointSize: Tk.label.small
        }

        Repeater {
          model: BarLayout.groups(sec.ids)

          // A pill group is one card with its rows inside; a lone item is a row.
          Rectangle {
            id: card
            required property var modelData
            readonly property bool pill: modelData.pill
            Layout.fillWidth: true
            implicitHeight: cardCol.implicitHeight + (pill ? Tk.padding.extraSmall * 2 : 0)
            radius: Tk.rounding.large
            color: pill ? Colours.m3surfaceContainerLow : "transparent"
            border.width: pill ? 1 : 0
            border.color: Qt.alpha(Colours.m3outlineVariant, 0.6)

            ColumnLayout {
              id: cardCol
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.margins: card.pill ? Tk.padding.extraSmall : 0
              spacing: Tk.spacing.extraSmall / 2

              Repeater {
                id: cardRows
                model: card.modelData.ids

                ColumnLayout {
                  id: entry
                  required property string modelData
                  required property int index
                  readonly property bool isChevron: modelData === "overflow"
                  readonly property bool isPill: modelData === "plugins" && root.pillMembers.length > 0
                  Layout.fillWidth: true
                  spacing: Tk.spacing.extraSmall / 2

                  BarRow {
                    modelData: entry.modelData
                    list: sec.modelData
                    first: entry.index === 0
                    last: entry.index === cardRows.count - 1 && !(entry.isChevron && root.chevronOpen) && !(entry.isPill && root.pillOpen)
                    foldable: entry.isChevron || entry.isPill
                    folded: entry.isChevron ? !root.chevronOpen : !root.pillOpen
                    onToggleFold: { if (entry.isChevron) root.chevronOpen = !root.chevronOpen; else root.pillOpen = !root.pillOpen }
                  }

                  // What is behind the chevron, and the limit.
                  ColumnLayout {
                    id: drawerRows
                    visible: entry.isChevron && root.chevronOpen
                    Layout.fillWidth: true
                    Layout.leftMargin: Tk.padding.large
                    spacing: Tk.spacing.extraSmall / 2
                    Component.onCompleted: if (entry.isChevron) root.register("drawer", drawerRows)
                    Component.onDestruction: root.unregister("drawer", drawerRows)
                    function emptyItem() { return drawerEmpty }
                    MText {
                      id: drawerEmpty
                      Layout.fillWidth: true
                      Layout.leftMargin: Tk.padding.small
                      visible: root.layout.drawer.length === 0 || (root.layout.drawer.length === 1 && root.layout.drawer[0] === root.dragId)
                      text: "Drag items here to fold them behind the chevron."
                      color: Colours.m3outline
                      font.pointSize: Tk.label.small
                    }
                    Repeater {
                      id: drawerRep
                      model: entry.isChevron ? root.layout.drawer : []
                      BarRow {
                        required property int index
                        list: "drawer"
                        first: false
                        last: false
                      }
                    }
                    RowStepper {
                      Layout.fillWidth: true
                      first: false
                      last: entry.index === cardRows.count - 1
                      settings: root.settings
                      row: ({ key: "bar.layout.maxShown", label: "Show at most this many icons",
                        subtext: Config.o.bar.layout.maxShown > 0 ? "The rest fold behind the chevron too" : "Off: only the items above",
                        from: 0, to: 20, step: 1 })
                    }
                  }

                  // The plugin pill's widgets.
                  ColumnLayout {
                    id: pillRows
                    visible: entry.isPill && root.pillOpen
                    Layout.fillWidth: true
                    Layout.leftMargin: Tk.padding.large
                    spacing: Tk.spacing.extraSmall / 2
                    Component.onCompleted: if (entry.modelData === "plugins") root.register("pill", pillRows)
                    Component.onDestruction: root.unregister("pill", pillRows)
                    function emptyItem() { return pillRows }
                    Repeater {
                      id: pillRep
                      model: entry.isPill ? root.pillMembers : []
                      BarRow {
                        required property int index
                        list: "pill"
                        first: false
                        last: entry.index === cardRows.count - 1 && index === pillRep.count - 1
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
    MText {
      Layout.fillWidth: true
      Layout.leftMargin: Tk.padding.small
      visible: root.chevronOff && root.layout.drawer.length > 0
      text: "The chevron is under Not shown, so what is behind it isn't on the bar."
      color: Colours.m3error
      font.pointSize: Tk.label.small
      wrapMode: Text.WordWrap
    }

    // ----------------------------------------------------------- not shown
    ColumnLayout {
      id: removedSec
      Layout.fillWidth: true
      spacing: Tk.spacing.extraSmall / 2
      Component.onCompleted: root.register("removed", removedSec)
      Component.onDestruction: root.unregister("removed", removedSec)
      function emptyItem() { return removedHead }
      Heading {
        id: removedHead
        text: "Not shown"
        count: root.layout.removed.length
        foldable: true
        open: root.removedOpen
        onToggled: root.removedOpen = !root.removedOpen
      }
      MText {
        Layout.fillWidth: true
        Layout.leftMargin: Tk.padding.small
        visible: root.removedOpen && root.layout.removed.length === 0
        text: "Everything is on the bar. Drag an item here to take it off."
        color: Colours.m3outline
        font.pointSize: Tk.label.small
      }
      Repeater {
        id: removedRep
        model: root.removedOpen ? root.layout.removed : []
        BarRow {
          required property int index
          list: "removed"
          first: index === 0
          last: index === removedRep.count - 1
        }
      }
    }

    // ----------------------------------------------------------- add list
    Heading {
      text: "Add a widget"
      count: root.addable.length
      foldable: true
      open: root.addOpen
      onToggled: root.addOpen = !root.addOpen
    }
    MText {
      Layout.fillWidth: true
      Layout.leftMargin: Tk.padding.small
      visible: root.addOpen && root.addGroups.length === 0
      text: PluginService.loaded ? "Every widget is on the bar or under Not shown." : "Reading the widgets..."
      color: Colours.m3outline
      font.pointSize: Tk.label.small
    }
    Repeater {
      model: root.addOpen ? root.addGroups : []
      ColumnLayout {
        id: grp
        required property var modelData
        Layout.fillWidth: true
        spacing: Tk.spacing.extraSmall / 2
        MText {
          Layout.topMargin: Tk.spacing.small
          Layout.leftMargin: Tk.padding.small
          text: grp.modelData.category
          color: Colours.m3outline
          font.pointSize: Tk.label.small
          weight: Font.Medium
        }
        Repeater {
          id: addRep
          model: grp.modelData.items
          ConnectedRect {
            id: ar
            required property var modelData
            required property int index
            readonly property bool busy: PluginService.busyId === modelData.id
            Layout.fillWidth: true
            first: index === 0
            last: index === addRep.count - 1
            implicitHeight: al.implicitHeight + Tk.padding.small * 2
            StateLayer { disabled: ar.busy || PluginService.busyId !== ""; onClicked: PluginService.addWidget(ar.modelData.id) }
            RowLayout {
              id: al
              anchors.fill: parent
              anchors.topMargin: Tk.padding.small
              anchors.bottomMargin: Tk.padding.small
              anchors.leftMargin: Tk.padding.medium
              anchors.rightMargin: Tk.padding.medium
              spacing: Tk.spacing.small
              MIcon { text: BarLayout.categoryIcon(ar.modelData.category); size: Tk.iconSize.small; color: Colours.m3onSurfaceVariant }
              MText { text: ar.modelData.name; font.pointSize: Tk.body.small }
              SourceChip { source: ar.modelData.source }
              MText {
                Layout.fillWidth: true
                text: "· " + (ar.modelData.duplicateOf !== null ? "Omarchy's version of an Omacale item" : ar.modelData.enabled ? (ar.modelData.description || "") : "off; adding turns it on")
                color: Colours.m3outline
                font.pointSize: Tk.label.small
                elide: Text.ElideRight
              }
              MIcon { text: ar.busy ? "hourglass_top" : "add"; size: Tk.iconSize.small; color: Colours.m3primary }
            }
          }
        }
      }
    }
    RowToggle {
      Layout.fillWidth: true
      Layout.topMargin: Tk.spacing.small
      visible: root.addOpen && (root.duplicateCount > 0 || Config.o.bar.layout.showDuplicates)
      first: true
      last: true
      text: "Show Omarchy's versions of Omacale items"
      subtext: "Its own volume, network, clock, ... to use instead of or beside Omacale's"
      checked: Config.o.bar.layout.showDuplicates
      onToggled: c => Config.set("bar.layout.showDuplicates", c)
    }
    MText {
      Layout.fillWidth: true
      visible: PluginService.error !== ""
      text: PluginService.error
      color: Colours.m3error
      wrapMode: Text.WordWrap
    }

    // Reset, confirmed by a second click as Settings › About's "Reset all settings".
    ConnectedRect {
      Layout.fillWidth: true
      Layout.topMargin: Tk.spacing.large
      first: true
      last: true
      color: root.confirmReset ? Colours.m3errorContainer : Colours.m3surfaceContainer
      implicitHeight: rr.implicitHeight + Tk.padding.medium * 2
      StateLayer {
        color: Colours.m3error
        onClicked: {
          if (root.confirmReset) { PluginService.resetBarLayout(); root.confirmReset = false }
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
          text: root.confirmReset ? "Click again to reset the bar" : "Reset the bar"
          subtext: "Every item back where it was, plugins back in the pill, Omarchy's widgets as on its own bar"
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
      anchors.leftMargin: Tk.padding.extraSmall
      anchors.rightMargin: Tk.padding.medium
      spacing: Tk.spacing.small
      MIcon { Layout.preferredWidth: Tk.iconSize.medium + Tk.padding.small; horizontalAlignment: Text.AlignHCenter; text: "drag_indicator"; size: Tk.iconSize.small; color: Colours.m3primary }
      MIcon { text: root.dragIcon; size: Tk.iconSize.small; color: Colours.m3onSurface }
      MText { Layout.fillWidth: true; text: root.dragLabel; color: Colours.m3onSurface; font.pointSize: Tk.body.small }
    }
  }
  // Where it will land.
  Rectangle {
    visible: root.dragId !== "" && root.dropList !== ""
    // Above the dragged row, which is under the pointer right where it lands.
    z: 11
    x: Tk.padding.small
    width: root.width - Tk.padding.small * 2
    y: root.lineY
    height: 3
    radius: 1.5
    color: Colours.m3primary
  }
}
