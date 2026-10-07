import QtQuick
import QtQuick.Layouts
import "../../.."

// Workspaces as a bar entry; the indicator itself is workspaces/Workspaces.qml.
Workspaces {
  id: entry
  required property var bar
  Component.onCompleted: bar.registerEntry(entry)
  Component.onDestruction: bar.unregisterEntry(entry)
  property string entryId: "workspaces"
  readonly property bool shown: true
  Layout.alignment: bar.crossAlign
  vertical: bar.vertical
  screen: bar.screen
  iconsFit: bar.windowIconsFit

  function navStops() {
    return navItems().map(ws => ({ item: ws, kind: "workspace", wsId: ws.wsId, act: () => bar.scope.switchWorkspace(ws.wsId) }))
  }
  function scrollAt(a, dy) {
    const p = bar.pointAlong(bar.pointOn(entry, a))
    if (p < 0 || p > bar.alen(entry)) return false
    scroll(dy)
    return true
  }
}
