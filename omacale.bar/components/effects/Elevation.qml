import QtQuick
import QtQuick.Effects
import "../.."

// Caelestia components/effects/Elevation.qml: an M3 elevation shadow.
RectangularShadow {
  property int level
  property real dp: [0, 1, 3, 6, 8, 12][level]
  color: Qt.alpha(Colours.m3shadow, 0.7)
  blur: Math.pow(dp * 5, 0.7)
  spread: -dp * 0.3 + Math.pow(dp * 0.1, 2)
  offset.y: dp / 2
  Behavior on dp { Anim { type: "slowEffects" } }
}
