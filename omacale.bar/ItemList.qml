import QtQuick
import QtQuick.Layouts

// Caelestia nexus/common/ItemList.qml: a connected card holding a list, or a
// centred placeholder when there is nothing to show. `scanning` adds the thin
// indeterminate bar Caelestia's NetworkList puts on top.
ConnectedRect {
  id: root

  property bool showList
  property string placeholderIcon
  property string placeholderText
  property bool scanning: false

  property alias model: list.model
  property alias delegate: list.delegate
  readonly property alias list: list
  readonly property real scanHeight: scanning ? Tk.rounding.extraSmall : 0

  Layout.fillWidth: true
  implicitHeight: (showList && list.count > 0 ? list.contentHeight : placeholder.implicitHeight + Tk.padding.extraLarge * 2) + scanHeight
  clip: true

  Behavior on implicitHeight { Anim {} }

  // Indeterminate scanning bar
  Item {
    id: scanBar
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: 1
    height: root.scanHeight
    clip: true
    Behavior on height { Anim { type: "effects" } }
    Rectangle {
      id: sweep
      width: parent.width * 0.35
      height: parent.height
      radius: height / 2
      color: Colours.m3primary
      NumberAnimation on x {
        running: root.scanning
        loops: Animation.Infinite
        from: -sweep.width
        to: scanBar.width
        duration: Tk.durations.extraLarge * 1.5
        easing.type: Easing.InOutQuad
      }
    }
  }

  Loader {
    id: placeholder
    anchors.centerIn: parent
    active: opacity > 0
    opacity: root.showList && list.count > 0 ? 0 : 1
    Behavior on opacity { Anim { type: "effects" } }

    sourceComponent: ColumnLayout {
      spacing: Tk.spacing.extraSmall
      MIcon {
        Layout.alignment: Qt.AlignHCenter
        text: root.placeholderIcon
        color: Colours.m3outline
        size: Tk.iconSize.large
        animate: true
      }
      MText {
        Layout.alignment: Qt.AlignHCenter
        text: root.placeholderText
        color: Colours.m3outline
        font.pointSize: Tk.body.large
        animate: true
      }
    }
  }

  ListView {
    id: list
    anchors.fill: parent
    anchors.topMargin: root.scanHeight
    spacing: 0
    interactive: false
    opacity: root.showList ? 1 : 0
    Behavior on opacity { Anim { type: "effects" } }

    add: Transition { Anim { property: "opacity"; from: 0; to: 1; type: "effects" } }
    remove: Transition { Anim { property: "opacity"; to: 0; type: "effects" } }
    move: Transition {
      Anim { property: "opacity"; to: 1; type: "effects" }
      Anim { property: "y" }
    }
    displaced: Transition {
      Anim { property: "opacity"; to: 1; type: "effects" }
      Anim { property: "y" }
    }
  }
}
