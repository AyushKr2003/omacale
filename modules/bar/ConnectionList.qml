import QtQuick
import QtQuick.Layouts
import "../.."

// Caelestia PR #2149 modules/bar/popouts/ConnectionList.qml: the rows of the
// network and bluetooth popouts. Scrolls past `maxRows` instead of growing
// the popout; the rows slide in one after another when the popout opens and
// animate as the list changes. An empty (or switched-off) list shows a
// placeholder on a card instead.
Item {
  id: root
  property alias model: list.model
  property alias delegate: list.delegate
  readonly property alias list: list

  property bool showList: true
  property string placeholderIcon
  property string placeholderText
  property real maxRows: 5.5

  readonly property bool hasItems: showList && list.count > 0
  readonly property real rowHeight: sizer.implicitHeight
  readonly property real listHeight: list.count * (rowHeight + list.spacing) - list.spacing
  property bool ready

  Layout.fillWidth: true
  implicitHeight: hasItems ? Math.min(listHeight, (rowHeight + list.spacing) * maxRows) : placeholder.implicitHeight + Tk.padding.extraLarge * 2
  clip: true

  Rectangle {
    anchors.fill: parent
    radius: Tk.rounding.large
    color: Colours.m3surfaceContainer
    opacity: root.hasItems ? 0 : 1
    Behavior on opacity { Anim { type: "effects" } }
  }

  MListView {
    id: list
    anchors.fill: parent
    spacing: Tk.spacing.extraSmall / 2
    interactive: contentHeight > height
    // Every row exists, scrolled out of sight or not, so the keyboard
    // cursor (PopoutContent.navTargets) can reach and reveal each one.
    cacheBuffer: Math.max(0, Math.ceil(root.listHeight))
    boundsBehavior: Flickable.StopAtBounds

    opacity: root.hasItems ? 1 : 0
    visible: opacity > 0

    // Rows slide in one after another when the popout opens.
    populate: Transition {
      id: populateTrans
      SequentialAnimation {
        PropertyAction { property: "opacity"; value: 0 }
        PauseAnimation { duration: populateTrans.ViewTransition.index * Tk.durations.small / 5 }
        ParallelAnimation {
          Anim { property: "opacity"; to: 1; type: "effects" }
          Anim { property: "x"; from: -Tk.padding.large; to: 0 }
        }
      }
    }
    add: Transition {
      Anim { property: "opacity"; from: 0; to: 1; type: "effects" }
      Anim { property: "scale"; from: 0.9; to: 1 }
    }
    remove: Transition {
      Anim { property: "opacity"; to: 0; type: "effects" }
      Anim { property: "scale"; to: 0.9 }
    }
    displaced: Transition {
      Anim { property: "y" }
      Anim { properties: "opacity,scale"; to: 1; type: "effects" }
    }
    move: Transition {
      Anim { property: "y" }
      Anim { properties: "opacity,scale"; to: 1; type: "effects" }
    }

    Behavior on opacity { Anim { type: "effects" } }
  }

  ColumnLayout {
    id: placeholder
    anchors.centerIn: parent
    spacing: Tk.spacing.extraSmall
    opacity: root.hasItems ? 0 : 1
    scale: root.hasItems ? 0.8 : 1
    visible: opacity > 0

    MIcon {
      Layout.alignment: Qt.AlignHCenter
      animate: true
      text: root.placeholderIcon
      size: Tk.iconSize.large
      color: Colours.m3outline
    }
    MText {
      Layout.alignment: Qt.AlignHCenter
      animate: true
      text: root.placeholderText
      color: Colours.m3outline
      font.pointSize: Tk.body.medium
    }

    Behavior on opacity { Anim { type: "effects" } }
    Behavior on scale { Anim {} }
  }

  // Sizes the list before its delegates exist; never shown.
  ConnectionRow {
    id: sizer
    visible: false
    title: " "
    subtitle: " "
  }

  // Size changes only animate after the first layout, or the popout would
  // grow as it opens.
  Timer {
    running: true
    interval: Tk.durations.small
    onTriggered: root.ready = true
  }

  Behavior on implicitHeight {
    enabled: root.ready
    Anim {}
  }
}
