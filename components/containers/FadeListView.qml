import QtQuick
import QtQuick.Effects
import "../.."

// Caelestia components/containers/VerticalFadeListView.qml: the ListView twin
// of FadeFlickable. The top and bottom fadeAmount of the view fade out while
// there is more to scroll that way, easing in and out as the edge is reached.
MListView {
  id: root
  property real fadeAmount: 0.2
  // Omarchy's menu scrims (plugins/menu/Menu.qml) instead of Caelestia's
  // fade: a fixed band of this many px, whose strength follows how much is
  // still hidden past each edge rather than easing on a clock, so a jump
  // (wrapping from the last row to the first) lands with the fade already
  // right, and the first and last rows show in full at the ends. 0 keeps
  // Caelestia's fadeAmount.
  property real fadeSize: 0
  readonly property real fadeBand: fadeSize > 0 && height > 0 ? Math.min(fadeSize, height / 2) / height : fadeAmount
  readonly property real hiddenAbove: contentY - originY + topMargin
  readonly property real hiddenBelow: originY + contentHeight + bottomMargin - height - contentY
  property real topFadeOpacity: fadeSize > 0 ? edgeOpacity(hiddenAbove) : fadeShouldBeActive(true) ? 0 : 1
  property real bottomFadeOpacity: fadeSize > 0 ? edgeOpacity(hiddenBelow) : fadeShouldBeActive(false) ? 0 : 1

  function edgeOpacity(hidden) {
    return 1 - Math.max(0, Math.min(1, hidden / Math.max(1, fadeBand * height)))
  }

  function fadeShouldBeActive(isStart) {
    // Content shorter than the view: drop the fade while it rebounds.
    if (contentHeight + topMargin + bottomMargin < height && rebound.running && (isStart ? verticalOvershoot > 0 : verticalOvershoot < 0))
      return false
    if (isStart) return visibleArea.yPosition > 0
    return visibleArea.yPosition + visibleArea.heightRatio < 1
  }

  flickableDirection: Flickable.VerticalFlick
  orientation: ListView.Vertical
  layer.enabled: true
  layer.effect: MultiEffect {
    maskEnabled: true
    maskSpreadAtMin: 1
    maskThresholdMin: 0.5
    maskSource: mask
  }
  Rectangle {
    id: mask
    parent: root
    anchors.fill: parent
    visible: false
    layer.enabled: true
    gradient: Gradient {
      GradientStop { position: 0; color: Qt.rgba(0, 0, 0, root.topFadeOpacity) }
      GradientStop { position: root.fadeBand; color: Qt.rgba(0, 0, 0, 1) }
      GradientStop { position: 1 - root.fadeBand; color: Qt.rgba(0, 0, 0, 1) }
      GradientStop { position: 1; color: Qt.rgba(0, 0, 0, root.bottomFadeOpacity) }
    }
  }
  Behavior on topFadeOpacity { enabled: root.fadeSize <= 0; Anim { type: "slowEffects" } }
  Behavior on bottomFadeOpacity { enabled: root.fadeSize <= 0; Anim { type: "slowEffects" } }
}
