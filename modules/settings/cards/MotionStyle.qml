import QtQuick
import "../../.."

// Settings › Motion › Style: Caelestia's curves, liquid motion
// (core/Liquid.qml) or morph (core/Morph.qml). A select row over two
// keys, so the two motions are never on together.
RowSelect {
  value: Config.o.liquid.enabled ? "liquid" : Config.o.morph.enabled ? "morph" : "caelestia"
  onPicked: v => {
    Config.set("liquid.enabled", v === "liquid")
    Config.set("morph.enabled", v === "morph")
  }
}
