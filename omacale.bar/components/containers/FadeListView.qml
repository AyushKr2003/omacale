import QtQuick
import QtQuick.Effects
import "../.."

// Caelestia components/containers/VerticalFadeListView.qml: the ListView twin
// of FadeFlickable. The top and bottom fadeAmount of the view fade out while
// there is more to scroll that way, easing in and out as the edge is reached.
MListView {
  id: root
  property real fadeAmount: 0.2
  property real topFadeOpacity: fadeShouldBeActive(true) ? 0 : 1
  property real bottomFadeOpacity: fadeShouldBeActive(false) ? 0 : 1

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
      GradientStop { position: root.fadeAmount; color: Qt.rgba(0, 0, 0, 1) }
      GradientStop { position: 1 - root.fadeAmount; color: Qt.rgba(0, 0, 0, 1) }
      GradientStop { position: 1; color: Qt.rgba(0, 0, 0, root.bottomFadeOpacity) }
    }
  }
  Behavior on topFadeOpacity { Anim { type: "slowEffects" } }
  Behavior on bottomFadeOpacity { Anim { type: "slowEffects" } }
}
