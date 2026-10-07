import QtQuick
import QtQuick.Layouts
import "../../.."

// The power button: opens the session menu.
Item {
  id: entry
  required property var bar
  Component.onCompleted: bar.registerEntry(entry)
  Component.onDestruction: bar.unregisterEntry(entry)
  property string entryId: "power"
  readonly property bool shown: bar.cfg.power
  visible: shown
  Layout.alignment: bar.crossAlign
  implicitWidth: powerIcon.implicitHeight + Tk.padding.small
  implicitHeight: powerIcon.implicitHeight
  Item {
    anchors.centerIn: parent
    width: powerIcon.implicitHeight + Tk.padding.small
    height: width
    property real radius: width / 2
    StateLayer { onClicked: bar.host.toggle("session") }
  }
  MIcon {
    id: powerIcon
    anchors.centerIn: parent
    text: "power_settings_new"
    color: Colours.m3error
    weight: 700
  }

  function navStops() {
    return [{ item: entry, act: () => bar.leaveFor("session") }]
  }
}
