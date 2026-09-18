import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

// Caelestia tonal SplitButton with its menu: [icon label | chevron]. The
// menu opens above (menuOnTop) or below the button.
Item {
  id: root
  property var items: []            // [{ icon, text, value }]
  property var current: null        // value of the active item
  property string fallbackIcon: "block"
  property string fallbackText: ""
  property bool menuOnTop: true
  property bool disabled: items.length === 0
  property real minLeftWidth: 0
  property bool expanded: false
  signal selected(var value)

  readonly property var active: items.find(i => i.value === current) || items[0] || null
  implicitWidth: row.implicitWidth
  implicitHeight: 40

  Row {
    id: row
    spacing: 2
    Rectangle {
      id: main
      height: 40
      width: Math.max(root.minLeftWidth, mainRow.implicitWidth + Tk.padding.large * 2)
      color: root.disabled ? Qt.alpha(Colours.m3onSurface, 0.1) : Colours.m3secondaryContainer
      topLeftRadius: height / 2; bottomLeftRadius: height / 2
      topRightRadius: Tk.rounding.extraSmall; bottomRightRadius: Tk.rounding.extraSmall
      Row {
        id: mainRow
        anchors.centerIn: parent
        spacing: Tk.spacing.small
        MIcon { anchors.verticalCenter: parent.verticalCenter; text: root.active ? (root.active.icon || root.fallbackIcon) : root.fallbackIcon; fill: 1; color: Colours.m3onSecondaryContainer }
        MText {
          anchors.verticalCenter: parent.verticalCenter
          width: Math.min(implicitWidth, main.width - Tk.padding.large * 2 - 28)
          elide: Text.ElideRight
          text: root.active ? root.active.text : root.fallbackText
          weight: Font.Medium
          color: Colours.m3onSecondaryContainer
          animate: true
        }
      }
    }
    Rectangle {
      id: chev
      height: 40; width: 36
      color: root.expanded ? Colours.m3secondary : (root.disabled ? Qt.alpha(Colours.m3onSurface, 0.1) : Colours.m3secondaryContainer)
      topRightRadius: height / 2; bottomRightRadius: height / 2
      topLeftRadius: root.expanded ? height / 2 : Tk.rounding.extraSmall; bottomLeftRadius: topLeftRadius
      Behavior on topLeftRadius { Anim { type: "effects" } }
      Behavior on color { CAnim {} }
      StateLayer { color: Colours.m3onSecondaryContainer; disabled: root.disabled; onClicked: root.expanded = !root.expanded }
      MIcon {
        anchors.centerIn: parent
        text: "expand_more"
        size: Tk.iconSize.medium
        color: root.expanded ? Colours.m3onSecondary : Colours.m3onSecondaryContainer
        rotation: (root.expanded ? 180 : 0) + (root.menuOnTop ? 180 : 0)
        Behavior on rotation { Anim {} }
      }
    }
  }

  Rectangle {
    id: menu
    z: 50
    width: Math.max(row.width, 200)
    x: row.width - width
    readonly property real fullHeight: menuCol.implicitHeight + Tk.padding.small * 2
    height: root.expanded ? fullHeight : 0
    y: root.menuOnTop ? -height - 6 : row.height + 6
    opacity: root.expanded ? 1 : 0
    visible: height > 1
    radius: Tk.rounding.large
    color: Colours.m3surfaceContainerHigh
    clip: true
    Behavior on height { Anim { type: "fastSpatial" } }
    Behavior on opacity { Anim { type: "effects" } }
    layer.enabled: visible
    layer.effect: MultiEffect { shadowEnabled: true; blurMax: 12; shadowColor: Qt.alpha("black", 0.4) }
    Column {
      id: menuCol
      x: Tk.padding.small; y: Tk.padding.small
      width: parent.width - Tk.padding.small * 2
      spacing: 2
      Repeater {
        model: root.items
        Rectangle {
          id: mi
          required property var modelData
          readonly property bool sel: root.active && modelData.value === root.active.value
          width: menuCol.width; height: 44; radius: height / 2
          color: sel ? Colours.m3secondaryContainer : "transparent"
          StateLayer { color: Colours.m3onSurface; onClicked: { root.selected(mi.modelData.value); root.expanded = false } }
          Row {
            anchors.left: parent.left; anchors.leftMargin: Tk.padding.medium
            anchors.verticalCenter: parent.verticalCenter
            spacing: Tk.spacing.medium
            MIcon { anchors.verticalCenter: parent.verticalCenter; text: mi.sel ? "check" : (mi.modelData.icon || ""); color: mi.sel ? Colours.m3onSecondaryContainer : Colours.m3onSurfaceVariant }
            MText { anchors.verticalCenter: parent.verticalCenter; width: menuCol.width - 60; elide: Text.ElideRight; text: mi.modelData.text; color: mi.sel ? Colours.m3onSecondaryContainer : Colours.m3onSurface }
          }
        }
      }
    }
  }
}
