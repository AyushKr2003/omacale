import QtQuick
import ".."

// Caelestia MaterialIcon: Material Symbols Rounded with fill/grade axes.
// opsz is the point size, as FontBuilder::size() sets it (the font clamps 20-48).
MText {
  property real fill: 0
  property int grade: Colours.light ? 0 : -25
  property real size: Tk.iconSize.small

  font.family: Tk.icon
  font.pointSize: size
  axes: ({ "FILL": Number(fill.toFixed(1)), "GRAD": grade, "opsz": Math.max(20, Math.min(48, Math.round(size))) })
  horizontalAlignment: Text.AlignHCenter
  verticalAlignment: Text.AlignVCenter
}
