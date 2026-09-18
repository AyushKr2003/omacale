import QtQuick
import QtQuick.Layouts

// Caelestia SelectRow: a tonal split button showing the current choice; the
// chevron half opens a menu.
ConnectedRect {
  id: root
  property var row
  property var settings
  readonly property string value: String(Config.get(row.key))
  readonly property var current: (row.options || []).find(o => o.value === value) || (row.options || [])[0]

  implicitHeight: Math.max(lbl.implicitHeight, split.implicitHeight) + Tk.padding.medium * 2

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: Tk.padding.largeIncreased
    anchors.rightMargin: Tk.padding.largeIncreased
    spacing: Tk.spacing.medium
    RowLabel { id: lbl; Layout.fillWidth: true; text: root.row.label; subtext: root.row.where ? root.row.where + (root.row.subtext ? " · " + root.row.subtext : "") : (root.row.subtext || "") }
    Row {
      id: split
      spacing: 2
      readonly property bool open: root.settings && root.settings.menuOwner === root
      Rectangle {
        id: main
        height: 40
        width: mainRow.implicitWidth + Tk.padding.large * 2
        color: Colours.m3secondaryContainer
        topLeftRadius: height / 2; bottomLeftRadius: height / 2
        topRightRadius: Tk.rounding.extraSmall; bottomRightRadius: Tk.rounding.extraSmall
        StateLayer { color: Colours.m3onSecondaryContainer; onClicked: root.settings.openMenu(root, chev, root.row.options, root.value, v => Config.set(root.row.key, v)) }
        Row {
          id: mainRow
          anchors.centerIn: parent
          spacing: Tk.spacing.small
          MIcon { anchors.verticalCenter: parent.verticalCenter; text: root.current ? root.current.icon : ""; size: Tk.iconSize.small; fill: 1; color: Colours.m3onSecondaryContainer; animate: true }
          MText { anchors.verticalCenter: parent.verticalCenter; text: root.current ? root.current.label : ""; color: Colours.m3onSecondaryContainer; weight: Font.Medium; animate: true }
        }
      }
      Rectangle {
        id: chev
        height: 40
        width: 36
        color: split.open ? Colours.m3secondary : Colours.m3secondaryContainer
        topRightRadius: height / 2; bottomRightRadius: height / 2
        topLeftRadius: split.open ? height / 2 : Tk.rounding.extraSmall; bottomLeftRadius: topLeftRadius
        Behavior on topLeftRadius { Anim { type: "effects" } }
        Behavior on color { CAnim {} }
        StateLayer { color: Colours.m3onSecondaryContainer; onClicked: root.settings.openMenu(root, chev, root.row.options, root.value, v => Config.set(root.row.key, v)) }
        MIcon {
          anchors.centerIn: parent
          text: "expand_more"
          size: Tk.iconSize.medium
          color: split.open ? Colours.m3onSecondary : Colours.m3onSecondaryContainer
          rotation: split.open ? 180 : 0
          Behavior on rotation { Anim {} }
        }
      }
    }
  }
}
