import QtQuick
import QtQuick.Layouts
import Quickshell

// Caelestia nexus/common/AudioDeviceList.qml: the devices of one direction,
// the current one filled and ticked. Click makes it the default.
ItemList {
  id: root
  property var nodes: []
  property var current: null
  property string iconName: "speaker"
  signal selected(var node)

  last: true
  showList: true
  model: ScriptModel { values: root.nodes }

  delegate: Item {
    id: device
    required property var modelData
    required property int index
    readonly property bool active: modelData === root.current

    width: ListView.view ? ListView.view.width : 0
    implicitHeight: dl.implicitHeight + Tk.padding.medium * 2

    StateLayer {
      radius: Tk.rounding.extraSmall
      bottomLeftRadius: device.index === root.list.count - 1 ? Tk.rounding.extraLarge : radius
      bottomRightRadius: device.index === root.list.count - 1 ? Tk.rounding.extraLarge : radius
      onClicked: root.selected(device.modelData)
    }

    RowLayout {
      id: dl
      anchors.fill: parent
      anchors.margins: Tk.padding.medium
      anchors.leftMargin: Tk.padding.largeIncreased
      anchors.rightMargin: Tk.padding.largeIncreased
      spacing: Tk.spacing.medium

      Rectangle {
        implicitWidth: implicitHeight
        implicitHeight: devIcon.implicitHeight + Tk.padding.small * 2
        radius: height / 2
        color: device.active ? Colours.m3primary : Colours.m3secondaryContainer
        Behavior on color { CAnim {} }
        MIcon {
          id: devIcon
          anchors.centerIn: parent
          text: root.iconName
          size: Tk.iconSize.medium
          fill: device.active ? 1 : 0
          color: device.active ? Colours.m3onPrimary : Colours.m3onSecondaryContainer
          Behavior on fill { Anim {} }
        }
      }
      MText {
        Layout.fillWidth: true
        text: AudioService.deviceName(device.modelData)
        elide: Text.ElideRight
      }
      MIcon {
        text: "check"
        size: Tk.iconSize.medium
        color: Colours.m3primary
        opacity: device.active ? 1 : 0
        Behavior on opacity { Anim { type: "effects" } }
      }
    }
  }
}
