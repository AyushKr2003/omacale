import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland

// Caelestia workspaces: a pill of M3 shapes (dot = empty, square = occupied,
// a random expressive shape = focused) with each workspace's windows listed
// underneath as app-category icons, and a primary "active" pill that slides
// between workspaces with a trailing edge.
Rectangle {
  id: root

  required property var screen
  readonly property var monitor: Hyprland.monitorFor(screen)
  readonly property var cfg: Config.o.bar.workspaces
  readonly property int shown: Math.max(1, cfg.shown)
  readonly property int activeId: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : 1
  readonly property int groupOffset: Math.floor((activeId - 1) / shown) * shown
  readonly property var focusedShapes: ["slanted", "oval", "pill", "triangle", "arrow", "diamond", "pentagon", "gem",
    "verySunny", "sunny", "cookie4", "cookie6", "cookie7", "cookie9", "cookie12", "clover4", "softBurst", "ghostish"]

  implicitWidth: Tk.barInner
  implicitHeight: list.implicitHeight + Tk.padding.extraSmall * 2
  radius: width / 2
  color: Colours.m3surfaceContainer
  Behavior on implicitHeight { Anim {} }

  function wsObject(id) {
    const v = Hyprland.workspaces.values
    for (let i = 0; i < v.length; i++) if (v[i].id === id) return v[i]
    return null
  }

  Connections {
    target: Hyprland
    function onRawEvent(e) {
      if (["openwindow", "closewindow", "movewindow", "movewindowv2", "windowtitle"].indexOf(e.name) >= 0)
        Hyprland.refreshToplevels()
    }
  }
  Component.onCompleted: Hyprland.refreshToplevels()

  Item {
    id: content
    anchors.fill: parent

    Column {
      id: list
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: Tk.padding.extraSmall
      spacing: Tk.spacing.extraSmall

      Repeater {
        id: rep
        model: root.shown

        Item {
          id: ws
          required property int index
          readonly property int wsId: root.groupOffset + index + 1
          readonly property var obj: root.wsObject(wsId)
          readonly property var toplevels: obj && obj.toplevels ? obj.toplevels.values : []
          readonly property bool occupied: toplevels.length > 0
          readonly property bool focused: wsId === root.activeId
          readonly property color fg: focused || occupied || root.cfg.occupiedBg ? Colours.m3onSurface : Colours.m3outlineVariant
          readonly property real cell: Tk.barInner - Tk.padding.small

          width: list.width
          readonly property bool hasWindows: occupied && root.cfg.showWindows && root.cfg.maxWindowIcons > 0
          height: col.implicitHeight + (hasWindows ? Tk.padding.extraSmall : 0)
          Behavior on height { Anim {} }

          function pickShape() {
            shape.shape = focused ? root.focusedShapes[Math.floor(Math.random() * root.focusedShapes.length)]
                                  : (occupied ? "square" : "circle")
          }
          onFocusedChanged: pickShape()
          onOccupiedChanged: if (!focused) pickShape()
          Component.onCompleted: pickShape()

          Column {
            id: col
            width: parent.width
            spacing: 0
            Item {
              width: parent.width
              height: ws.cell
              MText {
                anchors.centerIn: parent
                visible: root.cfg.display === "numbers"
                text: ws.wsId
                font.family: Tk.clock
                font.pointSize: Tk.body.small
                weight: ws.focused ? Font.DemiBold : Font.Normal
                color: ws.fg
              }
              MShape {
                id: shape
                visible: root.cfg.display !== "numbers"
                anchors.centerIn: parent
                implicitSize: ws.cell
                color: ws.fg
                scale: ws.focused ? 2 / 3 : ws.occupied ? 1 / 3 : 1 / 4
                Behavior on scale { Anim {} }
              }
            }
            Repeater {
              model: ws.hasWindows ? ws.toplevels.slice(0, root.cfg.maxWindowIcons) : []
              MIcon {
                required property var modelData
                width: col.width
                topPadding: -Tk.spacing.extraSmall / 2
                text: Sys.appIcon(modelData.wayland ? modelData.wayland.appId : (modelData.lastIpcObject || {}).class, "terminal")
                color: Colours.m3onSurfaceVariant
                opacity: 0
                Component.onCompleted: opacity = 1
                Behavior on opacity { Anim { type: "effects" } }
              }
            }
          }
        }
      }
    }
  }

  // Runs of consecutive occupied workspaces get a shared background pill.
  Repeater {
    model: {
      if (!root.cfg.occupiedBg) return []
      const runs = []
      let start = -1
      for (let i = 0; i <= root.shown; i++) {
        const it = i < root.shown ? rep.itemAt(i) : null
        const occ = it && it.occupied
        if (occ && start < 0) start = i
        if (!occ && start >= 0) { runs.push([start, i - 1]); start = -1 }
      }
      return runs
    }
    Rectangle {
      required property var modelData
      readonly property var a: rep.itemAt(modelData[0])
      readonly property var b: rep.itemAt(modelData[1])
      x: list.x
      y: a ? list.y + a.y : 0
      width: list.width
      height: a && b ? b.y + b.height - a.y : 0
      radius: width / 2
      color: Colours.m3secondaryContainer
      z: -1
    }
  }

  // Active pill with a trailing edge; its content is the list recoloured to onPrimary.
  Rectangle {
    id: indicator
    visible: root.cfg.activeIndicator
    property real start: 0
    property real end: 0
    readonly property var target: rep.count ? rep.itemAt(Math.max(0, Math.min(root.shown - 1, root.activeId - 1 - root.groupOffset))) : null

    function run() {
      if (!target) return
      const s = target.y, e = target.y + target.height
      const up = s < start
      const lead = Tk.durations.defaultSpatial, trail = lead * (root.cfg.activeTrail ? 1.5 : 1)
      sA.stop(); eA.stop()
      sA.to = s; eA.to = e
      sA.duration = up ? lead : trail
      eA.duration = up ? trail : lead
      sA.start(); eA.start()
    }
    onTargetChanged: run()
    Connections { target: indicator.target; function onYChanged() { indicator.run() } function onHeightChanged() { indicator.run() } }
    Component.onCompleted: run()

    NumberAnimation { id: sA; target: indicator; property: "start"; easing.type: Easing.BezierSpline; easing.bezierCurve: Tk.curves.defaultSpatial }
    NumberAnimation { id: eA; target: indicator; property: "end"; easing.type: Easing.BezierSpline; easing.bezierCurve: Tk.curves.defaultSpatial }

    x: list.x
    y: list.y + start
    width: list.width
    height: Math.max(0, end - start)
    radius: width / 2
    color: Colours.m3primary
    clip: true

    MultiEffect {
      x: 0
      y: -indicator.start
      width: list.width
      height: list.height
      source: ShaderEffectSource { sourceItem: list; hideSource: false; live: true }
      colorization: 1
      colorizationColor: Colours.m3onPrimary
      brightness: 1 - Colours.m3onSurface.hslLightness
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: function(e) {
      const p = mapToItem(list, e.x, e.y)
      const it = list.childAt(p.x, p.y)
      if (it && it.wsId !== undefined) Sys.workspace(it.wsId)
    }
    onWheel: function(e) { if (Config.o.bar.scroll.workspaces) Sys.workspace(e.angleDelta.y > 0 ? "r-1" : "r+1") }
  }
}
