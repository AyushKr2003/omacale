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
  // Next to status icons or widgets it joins their pill (BarContent's
  // Section.runs), with the pill's padding on its outer side; on its own it
  // stays a bare icon, as Caelestia's.
  readonly property bool joinable: true
  property bool joinBefore: false
  property bool joinAfter: false
  readonly property bool joined: joinBefore || joinAfter
  property real padStart: joined && !joinBefore ? Tk.padding.medium : 0
  property real padEnd: joined && !joinAfter ? Tk.padding.medium : 0
  // Joining and parting glide (a Behavior needs a plain property).
  Behavior on padStart { Anim {} }
  Behavior on padEnd { Anim {} }
  readonly property real iconLen: powerIcon.implicitHeight + (bar.vertical ? 0 : Tk.padding.small)
  implicitWidth: bar.vertical ? (joined ? Tk.barInner : powerIcon.implicitHeight + Tk.padding.small) : iconLen + padStart + padEnd
  implicitHeight: bar.vertical ? iconLen + padStart + padEnd : powerIcon.implicitHeight
  Item {
    x: Math.round((parent.width - width) / 2) + (bar.vertical ? 0 : (entry.padStart - entry.padEnd) / 2)
    y: Math.round((parent.height - height) / 2) + (bar.vertical ? (entry.padStart - entry.padEnd) / 2 : 0)
    width: powerIcon.implicitHeight + Tk.padding.small
    height: width
    property real radius: width / 2
    StateLayer { onClicked: bar.host.toggle("session") }
  }
  MIcon {
    id: powerIcon
    anchors.centerIn: parent
    anchors.horizontalCenterOffset: bar.vertical ? 0 : (entry.padStart - entry.padEnd) / 2
    anchors.verticalCenterOffset: bar.vertical ? (entry.padStart - entry.padEnd) / 2 : 0
    text: "power_settings_new"
    color: Colours.m3error
    weight: 700
  }

  function navStops() {
    return [{ item: entry, act: () => bar.leaveFor("session") }]
  }
}
