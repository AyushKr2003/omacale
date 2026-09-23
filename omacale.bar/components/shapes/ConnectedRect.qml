import QtQuick
import "../.."

// Caelestia ConnectedRect: rows in a group share one rounded silhouette —
// the first and last rows get large outer corners, inner seams stay tight.
Rectangle {
  property bool first
  property bool last
  color: Colours.m3surfaceContainer
  topLeftRadius: first ? Tk.rounding.extraLarge : Tk.rounding.extraSmall
  topRightRadius: first ? Tk.rounding.extraLarge : Tk.rounding.extraSmall
  bottomLeftRadius: last ? Tk.rounding.extraLarge : Tk.rounding.extraSmall
  bottomRightRadius: last ? Tk.rounding.extraLarge : Tk.rounding.extraSmall
  Behavior on topLeftRadius { Anim { type: "effects" } }
  Behavior on topRightRadius { Anim { type: "effects" } }
  Behavior on bottomLeftRadius { Anim { type: "effects" } }
  Behavior on bottomRightRadius { Anim { type: "effects" } }
  Behavior on color { CAnim {} }
}
