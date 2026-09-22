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
  property var bar: null
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

  readonly property Item activeItem: loader.item
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

  readonly property string shape: {
    if (naturalWidth <= logicalBreadth + 0.5) return "icon"
    if (naturalHeight <= logicalBreadth + 0.5 && naturalWidth <= logicalBreadth * maxRotatedSpan) return "rotated"
    return "proxy"
  }
  readonly property bool compactProxy: shape === "proxy"

  // `visible` of the item is its effective visibility, so the slot never hides
  // itself on it (that would latch it hidden). Like the stock bar, a widget
  // with nothing to show gets a zero-height slot, which Column skips.
  readonly property bool shown: loader.status === Loader.Ready && activeItem !== null && activeItem.visible
  readonly property real stageWidth: shape === "icon" ? logicalBreadth : naturalWidth
  readonly property real stageHeight: {
    if (shape !== "icon") return Math.max(1, naturalHeight)
    // An icon button is iconSlot tall on a vertical Omarchy bar: give it one
    // uniform cell. Anything taller is a stack and keeps its own height.
    return naturalHeight > Style.bar.iconSlot + 1 ? naturalHeight : logicalCell
  }
  readonly property real visualHeight: shape === "icon" ? stageHeight * iconScale
    : shape === "rotated" ? naturalWidth * iconScale
    : cellHeight

  implicitWidth: Tk.barInner
  implicitHeight: shown ? Math.round(visualHeight) : 0
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
    "time": "schedule", "ai": "smart_toy"
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
  // Content that appears later (a label turned on, a Loader) changes the size.
  onNaturalWidthChanged: Qt.callLater(refreshRendering)
  onNaturalHeightChanged: Qt.callLater(refreshRendering)

  function triggerCompactAction(button) {
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

  // Anchor the popup card directly next to Omacale's vertical bar
  Binding {
    target: root.compatibilityCard
    property: "x"
    value: Tk.barWidth + (root.compatibilityPanel && root.compatibilityPanel.gap !== undefined ? root.compatibilityPanel.gap : Tk.spacing.medium)
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

  // Prevent KeyboardPanel from crushing width to 120px
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

    Loader {
      id: loader
      anchors.fill: parent
      active: root.registryComponent !== null
      sourceComponent: root.registryComponent
      onLoaded: {
        root.injectProps()
        Qt.callLater(root.injectProps)
        Qt.callLater(root.refreshRendering)
        Qt.callLater(root.resolveCompatibilitySurface)
      }
    }
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
      color: Colours.m3secondary
    }
    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      cursorShape: Qt.PointingHandCursor
      onEntered: root.host.showTooltip(compactButton, root.displayName)
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

  onActiveItemChanged: Qt.callLater(injectProps)
  onModuleSettingsChanged: injectProps()

  function injectProps() {
    var target = loader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("moduleName" in target) target.moduleName = root.moduleName
    if ("settings" in target) target.settings = root.moduleSettings
  }

  Component.onCompleted: {
    host.registerPluginSlot(root)
    if (loader.item) injectProps()
  }
  Component.onDestruction: {
    if (host) host.unregisterPluginSlot(root)
  }
}
