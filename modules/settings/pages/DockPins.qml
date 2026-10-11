import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import "../../.."

// Settings › Panels › Dock › Pinned: the dock's pinned apps in dock order,
// moved up and down or unpinned here. Apps are pinned from the dock's own
// menu (right click) or Settings › Apps.
ColumnLayout {
  id: root
  property var row
  property var settings
  property bool first
  property bool last

  readonly property var pins: Config.o.dock.pinned
  readonly property var apps: pins.map(id => ({ id: id, entry: DockService.entryById(id) }))

  spacing: Tk.spacing.extraSmall / 2

  MText {
    Layout.fillWidth: true
    Layout.bottomMargin: Tk.spacing.small
    visible: root.pins.length === 0
    text: "Nothing is pinned yet. Right-click an app in the dock, or use Settings › Apps."
    color: Colours.m3outline
    wrapMode: Text.WordWrap
  }

  Repeater {
    id: rep
    model: root.apps

    ConnectedRect {
      id: pinRow
      required property var modelData
      required property int index
      Layout.fillWidth: true
      first: index === 0
      last: index === rep.count - 1
      implicitHeight: pr.implicitHeight + Tk.padding.small * 2

      RowLayout {
        id: pr
        anchors.fill: parent
        anchors.margins: Tk.padding.small
        anchors.leftMargin: Tk.padding.largeIncreased
        anchors.rightMargin: Tk.padding.medium
        spacing: Tk.spacing.medium
        IconImage {
          implicitSize: Tk.iconSize.large
          asynchronous: true
          source: DockService.iconOf(pinRow.modelData.entry)
        }
        RowLabel {
          Layout.fillWidth: true
          text: pinRow.modelData.entry ? pinRow.modelData.entry.name : pinRow.modelData.id
          subtext: pinRow.modelData.entry ? "" : "Not installed"
        }
        IconButton {
          type: "text"
          icon: "arrow_upward"
          disabled: pinRow.index === 0
          onClicked: DockService.movePin(pinRow.modelData.id, pinRow.index - 1)
        }
        IconButton {
          type: "text"
          icon: "arrow_downward"
          disabled: pinRow.index === rep.count - 1
          onClicked: DockService.movePin(pinRow.modelData.id, pinRow.index + 1)
        }
        IconButton {
          type: "text"
          icon: "keep_off"
          onClicked: DockService.setPinned(pinRow.modelData.id, false)
        }
      }
    }
  }
}
