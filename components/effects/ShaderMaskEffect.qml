import QtQuick
import QtQuick.Effects
import "../.."

// Clip an item's layer to the alpha of another item (e.g. an MShape).
MultiEffect {
  property Item maskItem
  maskEnabled: true
  maskThresholdMin: 0.5
  maskSpreadAtMin: 1
  maskSource: ShaderEffectSource { sourceItem: maskItem; hideSource: false; live: true }
}
