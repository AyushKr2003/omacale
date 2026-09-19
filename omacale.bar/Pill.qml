import QtQuick

// Pill-shaped action button (filled or tonal) for the Keybinds and
// Look'n'feel settings pages.
Rectangle {
  id: p
  property string icon
  property string label
  property bool filled: false
  signal clicked()
  implicitWidth: pr.implicitWidth + Tk.padding.large * 2
  implicitHeight: pr.implicitHeight + Tk.padding.small * 2
  radius: ps.pressed ? Tk.rounding.small : height / 2
  color: filled ? Colours.m3primary : Colours.m3secondaryContainer
  Behavior on radius { Anim { type: "fastSpatial" } }
  StateLayer { id: ps; color: p.filled ? Colours.m3onPrimary : Colours.m3onSecondaryContainer; onClicked: p.clicked() }
  Row {
    id: pr
    anchors.centerIn: parent
    spacing: Tk.spacing.small
    MIcon { anchors.verticalCenter: parent.verticalCenter; text: p.icon; fill: 1; color: p.filled ? Colours.m3onPrimary : Colours.m3onSecondaryContainer }
    MText { anchors.verticalCenter: parent.verticalCenter; text: p.label; weight: Font.Medium; color: p.filled ? Colours.m3onPrimary : Colours.m3onSecondaryContainer }
  }
}
