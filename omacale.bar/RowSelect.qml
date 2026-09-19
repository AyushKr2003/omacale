import QtQuick
import QtQuick.Layouts

// Caelestia SelectRow: a tonal split button showing the current choice; the
// chevron half opens a menu. Bound to a Config key when `row.key` is set;
// otherwise drive `value` and handle `picked` (default apps, ...).
ConnectedRect {
  id: root
  property var row
  property var settings
  property string value: row.key ? String(Config.get(row.key)) : ""
  signal picked(string value)
  function choose(v) { if (root.row.key) Config.set(root.row.key, v); root.picked(v) }
  readonly property var current: (row.options || []).find(o => o.value === value) || (row.options || [])[0]

  implicitHeight: Math.max(lbl.implicitHeight, split.implicitHeight) + Tk.padding.medium * 2

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: Tk.padding.largeIncreased
    anchors.rightMargin: Tk.padding.largeIncreased
    spacing: Tk.spacing.medium
    MIcon { visible: !!root.row.icon; text: root.row.icon || ""; size: Tk.iconSize.medium; fill: 1; color: Colours.m3onSurfaceVariant }
    RowLabel { id: lbl; Layout.fillWidth: true; text: root.row.label; subtext: root.row.where ? root.row.where + (root.row.subtext ? " · " + root.row.subtext : "") : (root.row.subtext || "") }
    // Caelestia components/controls/SplitButton.qml (tonal).
    Row {
      id: split
      spacing: Math.floor(Tk.spacing.extraSmall / 2)
      readonly property bool open: root.settings && root.settings.menuOwner === root
      readonly property real vPad: Tk.padding.small
      function toggle() { root.settings.openMenu(root, chev, root.row.options, root.value, v => root.choose(v)) }
      Rectangle {
        id: main
        height: chev.height
        width: textRow.implicitWidth + Tk.padding.medium * 2
        color: Colours.m3secondaryContainer
        topLeftRadius: height / 2; bottomLeftRadius: height / 2
        topRightRadius: Tk.rounding.medium / 2; bottomRightRadius: Tk.rounding.medium / 2
        StateLayer { color: Colours.m3onSecondaryContainer; onClicked: split.toggle() }
        RowLayout {
          id: textRow
          anchors.centerIn: parent
          anchors.horizontalCenterOffset: Math.floor(split.vPad / 4)
          spacing: Tk.spacing.small
          MIcon { Layout.alignment: Qt.AlignVCenter; text: root.current ? root.current.icon : ""; fill: 1; color: Colours.m3onSecondaryContainer; animate: true }
          MText { Layout.alignment: Qt.AlignVCenter; text: root.current ? root.current.label : ""; color: Colours.m3onSecondaryContainer; animate: true }
        }
      }
      Rectangle {
        id: chev
        property real rad: split.open ? height / 2 : Tk.rounding.medium / 2
        height: expandIcon.implicitHeight + split.vPad * 2
        width: height
        color: Colours.m3secondaryContainer
        topRightRadius: height / 2; bottomRightRadius: height / 2
        topLeftRadius: rad; bottomLeftRadius: rad
        Behavior on rad { Anim {} }
        StateLayer { color: Colours.m3onSecondaryContainer; onClicked: split.toggle() }
        MIcon {
          id: expandIcon
          anchors.centerIn: parent
          anchors.horizontalCenterOffset: split.open ? 0 : -Math.floor(split.vPad / 4)
          text: "expand_more"
          color: Colours.m3onSecondaryContainer
          rotation: split.open ? 180 : 0
          Behavior on anchors.horizontalCenterOffset { Anim {} }
          Behavior on rotation { Anim {} }
        }
      }
    }
  }
}
