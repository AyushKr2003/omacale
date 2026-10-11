import QtQuick
import Quickshell
import "../../.."

// A RowSelect whose choices are the screens: "all", "focused" or one screen by
// name (core/Screens.js targetFor), for row.key (notifs.screen, osd.screen).
Item {
  id: root
  property var row
  property var settings
  property bool first
  property bool last
  implicitHeight: sel.implicitHeight

  RowSelect {
    id: sel
    anchors.left: parent.left
    anchors.right: parent.right
    settings: root.settings
    first: root.first
    last: root.last
    row: ({
      key: root.row.key, label: root.row.label || "Screen", subtext: root.row.subtext || "",
      options: [
        { value: "all", label: "All screens", icon: "select_all" },
        { value: "focused", label: "Focused screen", icon: "center_focus_strong" }
      ].concat(Quickshell.screens.map(s => ({ value: s.name, label: s.name, icon: "monitor" })))
    })
  }
}
