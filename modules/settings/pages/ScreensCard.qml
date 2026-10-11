import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../.."
import "../../../core/Screens.js" as Screens

// Settings › Taskbar › Screens and Panels › Desktop › Screens: one row per
// screen (connector name, as Caelestia's bar.excludedScreens), with a switch
// for whether it gets the bar (row.mode "bar") or the desktop widgets
// ("desktop"), and for the bar its own edge. A screen with a setting that is
// unplugged stays listed, like Tray › Icons' offline rows, so it can be reset.
ColumnLayout {
  id: root
  property var row
  property var settings
  property bool first
  property bool last

  readonly property bool barMode: !row || row.mode !== "desktop"
  readonly property string listKey: barMode ? "bar.excludedScreens" : "background.excludedScreens"
  readonly property var excluded: barMode ? Config.o.bar.excludedScreens : Config.o.background.excludedScreens
  readonly property var positions: Screens.positionsFrom(Config.o.bar.screenPositions)
  readonly property var connected: Quickshell.screens.map(s => s.name)
  readonly property var offline: {
    const named = Array.from(excluded).concat(barMode ? Object.keys(positions) : [])
    return named.filter((n, i) => named.indexOf(n) === i && connected.indexOf(n) < 0)
  }
  readonly property var edges: [
    { value: "", label: "Follows the bar", icon: "sync_alt" },
    { value: "left", label: "Left", icon: "align_horizontal_left" },
    { value: "right", label: "Right", icon: "align_horizontal_right" },
    { value: "top", label: "Top", icon: "vertical_align_top" },
    { value: "bottom", label: "Bottom", icon: "vertical_align_bottom" }
  ]

  function setShown(name, on) {
    const l = Array.from(excluded).filter(n => n !== name)
    Config.set(listKey, on ? l : l.concat([name]))
  }
  function setEdge(name, edge) { Config.set("bar.screenPositions", Screens.positionsWith(Config.o.bar.screenPositions, name, edge)) }

  spacing: Tk.spacing.extraSmall / 2

  Repeater {
    id: rep
    model: root.connected.concat(root.offline)

    ConnectedRect {
      id: sr
      required property string modelData
      required property int index
      readonly property var scr: Quickshell.screens.find(s => s.name === modelData) || null
      readonly property bool shown: root.barMode ? Screens.barOn(modelData, root.excluded, root.connected)
        : Screens.shownOn(modelData, root.excluded)
      // The last screen with a bar can't give it up (Screens.barOn keeps one).
      readonly property bool lastBar: root.barMode && shown && root.connected.filter(n => Screens.barOn(n, root.excluded, root.connected)).length <= 1
      readonly property string edge: root.positions[modelData] || ""
      Layout.fillWidth: true
      first: index === 0
      last: index === rep.count - 1
      implicitHeight: sl.implicitHeight + Tk.padding.medium * 2

      RowLayout {
        id: sl
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Tk.padding.largeIncreased
        anchors.rightMargin: Tk.padding.largeIncreased
        spacing: Tk.spacing.medium
        MIcon { text: sr.scr ? "monitor" : "desktop_access_disabled"; size: Tk.iconSize.medium; color: Colours.m3onSurfaceVariant; opacity: sr.shown ? 1 : 0.45 }
        RowLabel {
          Layout.fillWidth: true
          opacity: sr.shown ? 1 : 0.45
          text: sr.modelData
          subtext: !sr.scr ? "Not connected"
            : [sr.scr.model, sr.scr.width + "×" + sr.scr.height].filter(x => !!x).join(" · ")
        }
        IconTextButton {
          id: edgeBtn
          visible: root.barMode && sr.shown
          type: "tonal"
          isRound: true
          fontSize: Tk.body.small
          horizontalPadding: Tk.padding.medium
          verticalPadding: Tk.padding.extraSmall
          icon: (root.edges.find(e => e.value === sr.edge) || root.edges[0]).icon
          text: (root.edges.find(e => e.value === sr.edge) || root.edges[0]).label
          onClicked: root.settings.openMenu(edgeBtn, edgeBtn, root.edges, sr.edge, v => root.setEdge(sr.modelData, v))
        }
        MSwitch {
          checked: sr.shown
          disabled: sr.lastBar
          onToggled: c => root.setShown(sr.modelData, c)
        }
      }
    }
  }
}
