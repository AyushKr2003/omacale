import QtQuick
import Quickshell
import qs.Commons

// Slot that loads and hosts a single 3rd-party bar widget from the
// barWidgetRegistry, injecting the PluginBarFacade as `bar`.
// Includes a compatibility adapter that repairs positioning and geometry for
// widgets using Omarchy's KeyboardPanel or PopupCard, ensuring the popup opens
// directly next to Omacale's vertical bar and matches Caelestia M3 styling.
//
// Sizing. The widget is laid out in Omarchy's own units (barSize, iconSlot,
// iconCanvas) and scaled by host.pluginIconScale, so its mark is drawn at the
// size of Omacale's status icons whatever the plugin hardcodes. Three shapes:
//   icon    - fits the bar's breadth: one status-icon cell (cellHeight), or
//             its own height when it is a taller vertical stack.
//   rotated - a short horizontal label (e.g. "ELIZA ▮"): drawn whole and
//             turned 90°, as Caelestia turns the active window title.
//   proxy   - too long to read turned: a host icon stands in, and the real
//             item stays underneath as the popup anchor and click target.
Item {
  id: root

  required property var entry
  required property var host
  // One facade per slot, not per plugin id: a widget on each monitor gets its
  // own click targets and popout, and the facade dies with the widget.
  readonly property var bar: facade
  // Height of one status icon (an MIcon at the default size), from the pill.
  property real cellHeight: Tk.body.small * 2

  readonly property string moduleName: host.entryId(entry)
  readonly property var moduleSettings: host.entrySettings(entry)

  // Re-evaluate when the registry mutates. Touch revision for reactivity.
  readonly property var registryComponent: {
    var reg = host.barWidgetRegistry
    if (!reg || !reg.widgets) return null
    void(reg.revision)
    var w = reg.widgets
    return w[moduleName] ? w[moduleName].component : null
  }

  property Item activeItem: null
  readonly property var moduleMetadata: {
    var reg = host.barWidgetRegistry
    return reg && typeof reg.metadataFor === "function" ? reg.metadataFor(moduleName) : null
  }
  readonly property string displayName: moduleMetadata && moduleMetadata.displayName
    ? String(moduleMetadata.displayName) : moduleName

  readonly property real iconScale: host.pluginIconScale
  readonly property real logicalBreadth: host.pluginBarSize
  readonly property real logicalCell: cellHeight / iconScale
  // Longest label that is still turned rather than replaced, in bar widths.
  readonly property real maxRotatedSpan: 3

  readonly property real naturalWidth: activeItem ? Math.max(0, Number(activeItem.implicitWidth) || 0) : 0
  readonly property real naturalHeight: activeItem ? Math.max(0, Number(activeItem.implicitHeight) || 0) : 0

  // The widget's own bar button (the first WidgetButton in its tree). Read,
  // never restyled: it says whether the widget has anything to show and how
  // wide its label really is.
  property Item primaryButton: null
  // A text button whose label is wider than the bar, drawn inside a slot that
  // claims to fit (e.g. 9router's marquee, a label on a vertical bar): it can
  // only show a fragment, so it gets the stand-in icon.
  readonly property bool labelOverflows: {
    var b = primaryButton
    if (!b || "iconComponent" in b || !b.text) return false
    var margin = Number(b.scaledHorizontalMargin) || 0
    return labelProbe.implicitWidth + margin * 2 > logicalBreadth + 1
  }
  Text {
    id: labelProbe
    visible: false
    textFormat: Text.PlainText
    text: root.primaryButton && root.primaryButton.text ? String(root.primaryButton.text) : ""
    font.family: root.primaryButton && root.primaryButton.fontFamily ? root.primaryButton.fontFamily : Tk.mono
    font.pixelSize: root.primaryButton && root.primaryButton.fontSize > 0 ? root.primaryButton.fontSize : 12
  }
  // Indicator-style widgets (BarIndicator) stay in the tree and keep their
  // space while inactive, but paint nothing: opacity 0 / concealed.
  readonly property bool buttonHidden: {
    var b = primaryButton
    if (!b) return false
    return b.concealed === true || b.hasVisualContent === false || Number(b.opacity) <= 0.01
  }

  readonly property string shape: {
    if (labelOverflows) return "proxy"
    if (naturalWidth <= logicalBreadth + 0.5) return "icon"
    if (naturalHeight <= logicalBreadth + 0.5 && naturalWidth <= logicalBreadth * maxRotatedSpan) return "rotated"
    return "proxy"
  }
  readonly property bool compactProxy: shape === "proxy" || placeholder

  // Pinned, but the widget is painting nothing (an indicator waiting for its
  // service, like the location widget with its daemon stopped). It keeps its
  // cell and a stand-in that opens it -- otherwise a widget you pinned would
  // be missing from the bar with no way to reach its panel. Unpinned, it
  // collapses instead, so the pill stays clean.
  property bool pinned: true
  readonly property bool placeholder: pinned && buttonHidden && activeItem !== null && activeItem.visible

  // `visible` of the item is its effective visibility, so the slot never hides
  // itself on it (that would latch it hidden). Like the stock bar, a widget
  // with nothing to show gets a zero-height slot, which Column skips.
  readonly property bool shown: activeItem !== null && activeItem.visible
    && (!buttonHidden || pinned)
  readonly property real stageWidth: shape === "icon" ? logicalBreadth : naturalWidth
  readonly property real stageHeight: {
    if (shape !== "icon") return Math.max(1, naturalHeight)
    // An icon button is iconSlot tall on a vertical Omarchy bar: give it one
    // uniform cell. Anything taller is a stack and keeps its own height.
    return naturalHeight > Style.bar.iconSlot + 1 ? naturalHeight : logicalCell
  }
  readonly property real visualHeight: placeholder ? cellHeight
    : shape === "icon" ? stageHeight * iconScale
    : shape === "rotated" ? naturalWidth * iconScale
    : cellHeight

  // Unpinned and the pill's overflow closed: the widget keeps running (its
  // state, IPC and popups stay alive), it just takes no room.
  property bool collapsed: false

  implicitWidth: Tk.barInner
  implicitHeight: shown && !collapsed ? Math.round(visualHeight) : 0
  width: implicitWidth
  height: implicitHeight
  // Scaling, turning and the proxy never let a widget paint over its
  // neighbours or outside the pill; Qt Quick also drops input outside a clip.
  clip: true

  // Category → stand-in icon for the proxy, so two wide plugins don't look
  // alike. Unknown categories get the generic extension icon.
  readonly property var categoryIcons: ({
    "network": "lan", "fun": "mood", "media": "music_note", "system": "memory",
    "productivity": "task_alt", "developer": "code", "development": "code",
    "utilities": "build", "communication": "chat", "weather": "partly_cloudy_day",
    "time": "schedule", "ai": "smart_toy", "status": "monitor_heart",
    "plugin": "extension"
  })
  readonly property string proxyIcon: {
    var cat = moduleMetadata && moduleMetadata.category ? String(moduleMetadata.category).toLowerCase() : ""
    return categoryIcons[cat] || "extension"
  }

  // Hosted text is drawn as curves. Omarchy widgets use Native or
  // distance-field text, both hinted for one pixel size (scaled, they blur)
  // and both take GTK's subpixel (RGB) AA, which fringes red and blue once a
  // label is turned. Curve text has no subpixel pass and is exact at any scale
  // or angle. Only how the bar mark is drawn changes, never what it shows;
  // popups are separate windows and are not visual children.
  function adoptTextRendering(item, depth) {
    if (!item || depth > 16) return
    try {
      if ("renderType" in item && item.renderType !== Text.CurveRendering) item.renderType = Text.CurveRendering
    } catch (e) {}
    var kids = item.children
    if (!kids) return
    for (var i = 0; i < kids.length; i++) adoptTextRendering(kids[i], depth + 1)
  }
  function refreshRendering() { adoptTextRendering(activeItem, 0) }

  function findPrimaryButton(item) {
    if (!item) return null
    var queue = [{ it: item, d: 0 }]
    while (queue.length) {
      var n = queue.shift()
      if (typeof n.it.triggerPress === "function") return n.it
      if (n.d >= 5 || !n.it.children) continue
      for (var i = 0; i < n.it.children.length; i++) queue.push({ it: n.it.children[i], d: n.d + 1 })
    }
    return null
  }

  // Deferred set-up. A Timer rather than Qt.callLater: it dies with the slot,
  // so nothing runs against a destroyed slot when the shell reloads plugins.
  function settleLater() { settleTimer.restart() }
  Timer {
    id: settleTimer
    interval: 0
    onTriggered: {
      root.injectProps()
      root.primaryButton = root.findPrimaryButton(root.activeItem)
      root.refreshRendering()
      root.resolveCompatibilitySurface()
    }
  }
  // Content that appears later (a label turned on, a Loader) changes the size.
  onNaturalWidthChanged: settleLater()
  onNaturalHeightChanged: settleLater()

  function triggerCompactAction(button) {
    if (primaryButton && primaryButton.visible !== false) {
      primaryButton.triggerPress(button)
      return
    }
    var targets = bar && bar.clickTargets ? bar.clickTargets : []
    for (var i = targets.length - 1; i >= 0; i--) {
      var target = targets[i]
      if (target && target.visible !== false && typeof target.triggerPress === "function") {
        target.triggerPress(button)
        return
      }
    }
    if (button === Qt.LeftButton && activeItem) {
      if (typeof activeItem.toggle === "function") activeItem.toggle()
      else if (typeof activeItem.open === "function") activeItem.open()
    }
  }

  // Host panel popup placement correction for screen-sized window:
  // Omarchy KeyboardPanel/PopupCard derive their perpendicular offset from
  // anchorWindow.width. Because Omacale's window spans the full screen (1920px),
  // KeyboardPanel mistook the whole screen for the bar and projected the card
  // off-screen to the right (x: 1928px) while crushing its width to 120px.
  // These bindings repair x, y, width, and style the card with Caelestia tokens.
  property var compatibilityPanel: null
  property var compatibilityCard: null

  function isPanelCandidate(candidate) {
    if (!candidate || (typeof candidate !== "object" && typeof candidate !== "function")) return false
    try {
      return "anchorItem" in candidate
        && "cardOrigin" in candidate
        && "contentWidth" in candidate
        && "open" in candidate
    } catch (e) {
      return false
    }
  }

  function findCompatibilityPanel(owner) {
    if (!owner) return null
    var queue = [owner]
    var seen = []
    while (queue.length > 0 && seen.length < 64) {
      var curr = queue.shift()
      if (!curr || seen.indexOf(curr) >= 0) continue
      seen.push(curr)
      if (isPanelCandidate(curr)) return curr

      if (curr.children) {
        for (var i = 0; i < curr.children.length; i++) queue.push(curr.children[i])
      }
      if (curr.data) {
        for (var j = 0; j < curr.data.length; j++) queue.push(curr.data[j])
      }
      // Follow Loader.item if present
      try {
        if (curr.item && typeof curr.item === "object") queue.push(curr.item)
      } catch (e) {}
    }
    return null
  }

  function findCompatibilityCard(panel) {
    if (!panel) return null
    var objects = []
    if (panel.contentItem && panel.contentItem.children) objects = objects.concat(panel.contentItem.children)
    if (panel.data) objects = objects.concat(panel.data)
    if (panel.children) objects = objects.concat(panel.children)
    for (var i = 0; i < objects.length; i++) {
      var c = objects[i]
      if (c && "contentTopInset" in c && "radius" in c && "color" in c) return c
    }
    return null
  }

  function resolveCompatibilitySurface() {
    compatibilityPanel = findCompatibilityPanel(activeItem)
    compatibilityCard = findCompatibilityCard(compatibilityPanel)
  }

  readonly property real hostedCardY: {
    if (!cardSurfaceActive) return 0
    var cardH = Number(compatibilityCard.height) || 300
    // Map the slot's own centre, not KeyboardPanel's anchorScreenPos: that is
    // the widget's (0,0), which a scaled or turned widget moves to a corner.
    // Same space KeyboardPanel uses (the bar window's content item).
    var win = compatibilityPanel.anchorWindow
    var space = win && win.contentItem ? win.contentItem : null
    var centre = root.mapToItem(space, 0, root.height / 2).y
    var scrH = Number(compatibilityPanel.screenH) || (win ? Number(win.height) : 0) || 1080
    return Math.round(Math.max(Tk.padding.medium, Math.min(centre - cardH / 2, scrH - cardH - Tk.padding.medium)))
  }

  readonly property bool cardSurfaceActive: compatibilityPanel !== null && compatibilityCard !== null && (compatibilityPanel.open || compatibilityCard.opacity > 0)

  // KeyboardPanel takes the anchor window's width for the bar's width, and
  // Omacale's window is the whole screen. Every sum it builds on that is then
  // wrong: the card's own x (barW + gap), the room it thinks is left for the
  // card (screenW - barW - gap - margin, which clamps to its 120px floor and
  // cuts the content off), and the "bar strip" it forwards clicks in (the
  // whole screen). `gap` is its one writable term in all three, so correcting
  // it fixes all three: barW + gap becomes the real bar edge plus a gap. If
  // the anchor window is ever bar-sized, this leaves a plain gap behind.
  readonly property real panelGap: {
    const barW = compatibilityPanel ? Number(compatibilityPanel.barW) || 0 : 0
    return Math.round(Tk.barWidth + Tk.spacing.medium - barW)
  }
  Binding {
    target: root.compatibilityPanel
    property: "gap"
    value: root.panelGap
    when: root.compatibilityPanel !== null
    restoreMode: Binding.RestoreNone
  }

  // Anchor the popup card directly next to Omacale's vertical bar
  Binding {
    target: root.compatibilityCard
    property: "x"
    value: Tk.barWidth + Tk.spacing.medium
    when: root.cardSurfaceActive
    restoreMode: Binding.RestoreNone
  }

  // Align the popup card vertically with the widget icon
  Binding {
    target: root.compatibilityCard
    property: "y"
    value: root.hostedCardY
    when: root.cardSurfaceActive
    restoreMode: Binding.RestoreNone
  }

  // With the gap corrected the panel sizes its own card again (each asks for
  // its own width, 380-560 in Omarchy's panels). This is only a floor, for a
  // panel that still reports a crushed width.
  Binding {
    target: root.compatibilityCard
    property: "width"
    value: Math.max(340, root.compatibilityPanel ? Number(root.compatibilityPanel.contentWidth) || 340 : 340)
    when: root.cardSurfaceActive
    restoreMode: Binding.RestoreNone
  }

  // Caelestia M3 Surface Container styling
  Binding {
    target: root.compatibilityCard
    property: "color"
    value: Colours.m3surfaceContainer
    when: root.cardSurfaceActive
    restoreMode: Binding.RestoreNone
  }

  // Caelestia 24px container radius
  Binding {
    target: root.compatibilityCard
    property: "radius"
    value: Tk.rounding.large
    when: root.cardSurfaceActive
    restoreMode: Binding.RestoreNone
  }

  // Caelestia M3 outline
  Binding {
    target: root.compatibilityCard
    property: "borderSpec"
    value: ({
      color: Colours.m3outlineVariant,
      widths: { top: 1, right: 1, bottom: 1, left: 1 },
      gradient: { colors: [], angle: 0, enabled: false }
    })
    when: root.cardSurfaceActive
    restoreMode: Binding.RestoreNone
  }

  // Omarchy-unit stage, scaled (and for a label, turned) about its centre.
  Item {
    id: stage
    anchors.centerIn: parent
    width: root.stageWidth
    height: root.stageHeight
    scale: root.iconScale
    rotation: root.shape === "rotated" ? 90 : 0
    opacity: root.compactProxy ? 0 : 1

    // No Loader: the widget is created with bar, moduleName and settings as
    // initial properties, so they are already set when its own
    // Component.onCompleted runs. Assigned afterwards (as Loader.onLoaded
    // and the stock bar do), a widget that starts work on completion runs it
    // with default settings -- toggl-track then logged into its own plugin
    // folder, which makes the shell reload every plugin, forever.
  }

  // Declared after the stage: children are destroyed in order, so the
  // widget goes before the facade it calls on its way out.
  PluginBarFacade {
    id: facade
    host: root.host
    moduleName: root.moduleName
  }

  // The fallback is deliberately owned by Omacale rather than inferred from
  // a plugin's text tree. That avoids hiding arbitrary plugin state or
  // hardcoding special cases while ensuring no label can bleed outside the
  // Caelestia pill.
  Item {
    id: compactButton
    anchors.fill: parent
    visible: root.compactProxy
    z: 10

    MIcon {
      anchors.centerIn: parent
      text: root.proxyIcon
      // Dimmed while the widget itself has nothing to show, as Omarchy dims
      // an indicator that is not active.
      color: root.placeholder ? Colours.m3outline : Colours.m3secondary
    }
    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      cursorShape: Qt.PointingHandCursor
      onEntered: root.host.showTooltip(compactButton, root.placeholder ? root.displayName + " · idle" : root.displayName)
      onExited: root.host.hideTooltip(compactButton)
      onClicked: function(mouse) { root.triggerCompactAction(mouse.button) }
    }
  }

  Connections {
    target: root.activeItem
    ignoreUnknownSignals: true
    function onOpenedChanged() {
      if (root.activeItem) {
        root.resolveCompatibilitySurface()
        if (root.activeItem.opened) {
          if (root.host && typeof root.host.requestPopout === "function")
            root.host.requestPopout(root.activeItem)
        } else {
          if (root.host && typeof root.host.releasePopout === "function")
            root.host.releasePopout(root.activeItem)
        }
      }
    }
  }

  Connections {
    target: root.compatibilityPanel
    ignoreUnknownSignals: true
    function onOpenChanged() {
      if (root.compatibilityPanel) {
        if (root.compatibilityPanel.open) {
          if (root.host && typeof root.host.requestPopout === "function")
            root.host.requestPopout(root.activeItem)
        } else {
          if (root.host && typeof root.host.releasePopout === "function")
            root.host.releasePopout(root.activeItem)
        }
      }
    }
  }

  onActiveItemChanged: {
    primaryButton = null
    settleLater()
  }

  function createItem() {
    var comp = registryComponent
    if (activeItem) {
      var old = activeItem
      activeItem = null
      old.destroy()
    }
    if (!comp || comp.status !== Component.Ready) return
    var item = null
    try {
      item = comp.createObject(stage, {
        bar: root.bar,
        moduleName: root.moduleName,
        settings: root.moduleSettings
      })
    } catch (e) {
      console.warn("omacale: bar widget " + root.moduleName + " failed to start: " + e)
    }
    if (!item) return
    item.anchors.fill = stage
    activeItem = item
  }
  // The same Component (the registry re-registers on every rescan) keeps the
  // live widget; only a different one replaces it.
  property var createdFrom: null
  onRegistryComponentChanged: {
    if (registryComponent === createdFrom) return
    createdFrom = registryComponent
    createItem()
  }
  onModuleSettingsChanged: injectProps()

  function injectProps() {
    var target = activeItem
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("moduleName" in target) target.moduleName = root.moduleName
    if ("settings" in target) target.settings = root.moduleSettings
  }

  Component.onCompleted: {
    host.registerPluginSlot(root)
    createdFrom = registryComponent
    createItem()
  }
  Component.onDestruction: {
    if (host) host.unregisterPluginSlot(root)
  }
}
