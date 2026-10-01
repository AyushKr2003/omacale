import QtQuick
import QtQuick.Layouts
import "../.."

// Caelestia components/controls/SplitButton.qml with its Menu.qml:
// [icon label | chevron], the menu opening above (menuOnTop) or below the
// chevron, right-aligned to it.
Item {
  id: root
  property var items: []            // [{ icon, text, value }]
  property var current: null        // value of the active item
  property string fallbackIcon: "block"
  property string fallbackText: ""
  property bool menuOnTop: true
  property bool disabled: items.length === 0
  property real minLeftWidth: 0
  property real horizontalPadding: Tk.padding.medium
  property real verticalPadding: Tk.padding.small
  property bool expanded: false
  // Caelestia SplitButton type: filled (primary) instead of tonal, and a main
  // half that acts (mainClicked, Caelestia's `active.clicked()`) rather than
  // only showing the selection.
  property bool filled: false
  property bool mainClickable: false
  readonly property color colour: filled ? Colours.m3primary : Colours.m3secondaryContainer
  readonly property color textColour: filled ? Colours.m3onPrimary : Colours.m3onSecondaryContainer
  // Caelestia SplitButton disabledColour/disabledTextColour: the content has to
  // dim with the container, or an onPrimary label is left on a bare surface.
  readonly property color disabledColour: Qt.alpha(Colours.m3onSurface, 0.1)
  readonly property color disabledTextColour: Qt.alpha(Colours.m3onSurface, 0.38)
  readonly property color contentColour: disabled ? disabledTextColour : textColour
  readonly property real fullRadius: chev.height / 2 * Math.min(1, Tk.clamp(Tk.scaleCfg.rounding, 0, 4))
  signal selected(var value)
  signal mainClicked()

  readonly property var active: items.find(i => i.value === current) || items[0] || null
  implicitWidth: row.implicitWidth
  implicitHeight: row.implicitHeight

  Row {
    id: row
    spacing: Math.floor(Tk.spacing.extraSmall / 2)

    Rectangle {
      id: main
      height: chev.height
      width: Math.max(root.minLeftWidth, mainRow.implicitWidth + root.horizontalPadding * 2)
      color: root.disabled ? root.disabledColour : root.colour
      Behavior on color { CAnim {} }
      topLeftRadius: root.fullRadius; bottomLeftRadius: root.fullRadius
      topRightRadius: Tk.rounding.medium / 2; bottomRightRadius: Tk.rounding.medium / 2

      StateLayer {
        color: root.textColour
        disabled: root.disabled
        onClicked: if (root.mainClickable) root.mainClicked()
      }
      RowLayout {
        id: mainRow
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: Math.floor(root.verticalPadding / 4)
        spacing: Tk.spacing.small
        MIcon {
          Layout.alignment: Qt.AlignVCenter
          animate: true
          text: root.active ? (root.active.icon || root.fallbackIcon) : root.fallbackIcon
          fill: 1
          color: root.contentColour
        }
        MText {
          Layout.alignment: Qt.AlignVCenter
          Layout.preferredWidth: implicitWidth
          animate: true
          text: root.active ? (root.active.activeText || root.active.text) : root.fallbackText
          color: root.contentColour
          clip: true
          Behavior on Layout.preferredWidth { Anim { type: "emphasized" } }
        }
      }
    }

    Rectangle {
      id: chev
      property real rad: root.expanded ? root.fullRadius : Tk.rounding.medium / 2
      implicitHeight: expandIcon.implicitHeight + root.verticalPadding * 2
      height: implicitHeight
      width: height
      color: root.disabled ? root.disabledColour : root.colour
      topRightRadius: root.fullRadius; bottomRightRadius: root.fullRadius
      topLeftRadius: rad; bottomLeftRadius: rad
      Behavior on rad { Anim {} }
      Behavior on color { CAnim {} }
      StateLayer { color: root.textColour; disabled: root.disabled; onClicked: root.expanded = !root.expanded }
      MIcon {
        id: expandIcon
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: root.expanded ? 0 : -Math.floor(root.verticalPadding / 4)
        text: "expand_more"
        color: root.contentColour
        rotation: root.expanded ? 180 : 0
        Behavior on anchors.horizontalCenterOffset { Anim {} }
        Behavior on rotation { Anim {} }
      }
    }
  }

  // Caelestia Menu.qml: an elevated surfaceContainerLow card that unfolds
  // (yScale 0.1 -> 1) from the side against the button.
  Item {
    id: menu
    z: 50
    width: Math.max(Tk.px(200), menuCol.implicitWidth + Tk.padding.extraSmall * 2)
    height: menuCol.implicitHeight + Tk.padding.extraSmall * 2
    x: row.width - width
    y: root.menuOnTop ? -height - Tk.spacing.small : row.height + Tk.spacing.small
    opacity: root.expanded ? 1 : 0
    visible: opacity > 0
    layer.enabled: opacity < 1
    Behavior on opacity { Anim { type: "effects" } }
    transform: Scale {
      yScale: root.expanded ? 1 : 0.1
      origin.y: root.menuOnTop ? menu.height : 0
      Behavior on yScale { Anim {} }
    }

    Elevation { anchors.fill: parent; radius: Tk.rounding.large; level: 2 }
    Rectangle {
      anchors.fill: parent
      radius: Tk.rounding.large
      color: Colours.palette.m3surfaceContainerLow
    }
    // Swallow the wheel and clicks between the items.
    MouseArea { anchors.fill: parent; hoverEnabled: true; onWheel: e => e.accepted = true }

    ColumnLayout {
      id: menuCol
      anchors.fill: parent
      anchors.margins: Tk.padding.extraSmall
      spacing: 0
      Repeater {
        id: rep
        model: root.items
        Rectangle {
          id: mi
          required property var modelData
          required property int index
          readonly property bool sel: !!root.active && modelData.value === root.active.value
          readonly property real outer: Tk.rounding.medium
          Layout.fillWidth: true
          implicitWidth: miRow.implicitWidth + Tk.padding.medium * 2
          implicitHeight: miRow.implicitHeight + Tk.padding.medium * 2
          radius: sel ? Tk.rounding.medium : Tk.rounding.extraSmall
          topLeftRadius: index === 0 ? outer : radius
          topRightRadius: index === 0 ? outer : radius
          bottomLeftRadius: index === rep.count - 1 ? outer : radius
          bottomRightRadius: index === rep.count - 1 ? outer : radius
          color: Qt.alpha(Colours.m3tertiaryContainer, sel ? 1 : 0)
          Behavior on radius { Anim {} }
          Behavior on color { CAnim {} }
          StateLayer {
            topLeftRadius: parent.topLeftRadius
            topRightRadius: parent.topRightRadius
            bottomLeftRadius: parent.bottomLeftRadius
            bottomRightRadius: parent.bottomRightRadius
            color: mi.sel ? Colours.m3onTertiaryContainer : Colours.m3onSurface
            disabled: !root.expanded
            onClicked: { root.selected(mi.modelData.value); root.expanded = false }
          }
          RowLayout {
            id: miRow
            anchors.fill: parent
            anchors.margins: Tk.padding.medium
            spacing: Tk.spacing.small
            MIcon {
              Layout.alignment: Qt.AlignVCenter
              text: mi.modelData.icon || ""
              color: mi.sel ? Colours.m3onTertiaryContainer : Colours.m3onSurfaceVariant
            }
            MText {
              Layout.alignment: Qt.AlignVCenter
              Layout.fillWidth: true
              elide: Text.ElideRight
              text: mi.modelData.text
              color: mi.sel ? Colours.m3onTertiaryContainer : Colours.m3onSurface
            }
          }
        }
      }
    }
  }
}
