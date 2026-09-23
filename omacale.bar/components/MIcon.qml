import QtQuick
import ".."

// Caelestia MaterialIcon: Material Symbols Rounded with fill/grade axes.
MText {
  property real fill: 0
  property int grade: Colours.light ? 0 : -25
  property real size: Tk.iconSize.small

  font.family: Tk.icon
  font.pointSize: size
  axes: ({ "FILL": Number(fill.toFixed(1)), "GRAD": grade, "opsz": Math.max(20, Math.min(48, Math.round(size * 4 / 3))) })
  horizontalAlignment: Text.AlignHCenter
  verticalAlignment: Text.AlignVCenter
}
