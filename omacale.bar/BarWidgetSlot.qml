import QtQuick
import Quickshell

// Slot that loads and hosts a single 3rd-party bar widget from the
// barWidgetRegistry, injecting the PluginBarFacade as `bar`.
// Includes a compatibility adapter that repairs positioning and geometry for
// widgets using Omarchy's KeyboardPanel or PopupCard, ensuring the popup opens
// directly next to Omacale's vertical bar and matches Caelestia M3 styling.
Item {
  id: root

  required property var entry
  required property var host
  property var bar: null

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

  property bool activeItemVisible: false
  property real activeItemHeight: 0

  function syncMetrics() {
    var it = activeItem
    if (it) {
      activeItemVisible = (it.visible !== false)
      var h = Number(it.implicitHeight) || Number(it.height) || 0
      activeItemHeight = Math.max(Tk.body.small * 2, h > 0 ? h : 28)
    } else {
      activeItemVisible = false
      activeItemHeight = 0
    }
  }

  implicitWidth: Tk.barInner
  implicitHeight: activeItem ? Math.max(Tk.body.small * 2, Number(activeItem.implicitHeight) || Number(activeItem.height) || 28) : 0
  width: implicitWidth
  height: implicitHeight
  visible: loader.status === Loader.Ready && implicitHeight > 0
  // Omarchy widgets are usually authored for a horizontal bar. A vertical
  // Caelestia slot is intentionally icon-sized, so never let a text label
  // paint over its neighbours or outside the pill.
  clip: true
  // A third-party widget's natural width is authoritative: QML anchors can
  // shrink `width`, but not its `implicitWidth`.  Keep widgets that already
  // adapt to a vertical bar (e.g. WARP) intact. For a horizontal, label-first
  // widget, use a host icon while retaining the real item underneath as the
  // popup anchor and action controller.
  readonly property bool compactProxy: activeItem !== null
    && Number(activeItem.implicitWidth) > Tk.barInner + 1

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
    var cardH = compatibilityCard ? (Number(compatibilityCard.height) || 300) : 300
    // mapToItem(null) resolves in the host scene, not KeyboardPanel's
    // screen-sized overlay. KeyboardPanel already tracks the anchor in the
    // correct output coordinate space; use it so a widget near the bottom
    // opens beside itself instead of at the top of the output.
    var anchorY = compatibilityPanel ? Number(compatibilityPanel.anchorScreenPos.y) : NaN
    var anchorH = compatibilityPanel ? Number(compatibilityPanel.anchorH) : NaN
    if (!isFinite(anchorY)) anchorY = 0
    if (!isFinite(anchorH) || anchorH <= 0) anchorH = root.height > 0 ? root.height : 28
    var targetY = anchorY + anchorH / 2 - cardH / 2
    var scrH = (compatibilityPanel && compatibilityPanel.screenH) ? Number(compatibilityPanel.screenH) : 1080
    return Math.round(Math.max(Tk.padding.medium, Math.min(targetY, scrH - cardH - Tk.padding.medium)))
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

  Loader {
    id: loader
    anchors.fill: parent
    active: root.registryComponent !== null
    sourceComponent: root.registryComponent
    opacity: root.compactProxy ? 0 : 1
    onLoaded: {
      root.injectProps()
      root.syncMetrics()
      Qt.callLater(root.injectProps)
      Qt.callLater(root.syncMetrics)
      Qt.callLater(root.resolveCompatibilitySurface)
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
      text: "extension"
      color: Colours.m3onSurfaceVariant
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
    function onVisibleChanged() { root.syncMetrics() }
    function onImplicitHeightChanged() { root.syncMetrics() }
    function onHeightChanged() { root.syncMetrics() }
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
    Qt.callLater(injectProps)
    Qt.callLater(syncMetrics)
  }
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
    if (loader.item) {
      injectProps()
      syncMetrics()
    }
  }
  Component.onDestruction: {
    if (host) host.unregisterPluginSlot(root)
  }
}
