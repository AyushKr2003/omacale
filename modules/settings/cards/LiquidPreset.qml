import QtQuick
import "../../.."

// Settings › Motion › Preset: a select row that goes through
// Liquid.choosePreset, so Custom starts from the preset it leaves.
RowSelect {
  value: Config.o.liquid.preset
  onPicked: v => Liquid.choosePreset(v)
}
