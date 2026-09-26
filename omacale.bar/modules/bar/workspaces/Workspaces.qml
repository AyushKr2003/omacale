import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import "../../.."

// Caelestia workspaces: a pill of M3 shapes (dot = empty, square = occupied,
// a random expressive shape = focused) with each workspace's windows listed
// underneath as app-category icons, and a primary "active" pill that slides
// between workspaces with a trailing edge.
//
// While a special workspace (Omarchy's scratchpad, Super+S) is open, the
// normal list shrinks, fades and blurs behind a scrolling list of the special
// workspaces (modules/bar/components/workspaces/Workspaces.qml, `specialWs`).
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

  readonly property var special: monitor && monitor.lastIpcObject ? monitor.lastIpcObject.specialWorkspace : null
  readonly property string specialName: special && special.name ? special.name : ""
  readonly property bool inSpecial: specialName !== ""
  property real blur: inSpecial ? 1 : 0
  Behavior on blur { Anim { type: "standardSmall" } }

  // `rep.itemAt()` is not a binding dependency, and `rep.count` is already the
  // model size while the delegates are still being built: at login a binding
  // that reaches for a delegate resolves to null and, with nothing to depend
  // on, never runs again -- the active pill stayed invisible until switching
  // workspace changed activeId. Delegates bump this on completion so anything
  // resolving one re-evaluates once it exists.
  property int listGen: 0

  // Set by the bar when a short screen has no room for the window icons: the
  // clock, status icons and power must stay on screen, the icons can go.
  property bool iconsFit: true
  // Worked out from the workspaces, not measured, so both are the same
  // whether or not the icons are shown and the bar can decide on them.
  readonly property real bareHeight: shown * (Tk.barInner - Tk.padding.small)
    + (shown - 1) * Tk.spacing.extraSmall + Tk.padding.extraSmall * 2
  readonly property real iconsHeight: {
    if (!cfg.showWindows || cfg.maxWindowIcons <= 0) return 0
    let h = 0
    for (let i = 0; i < shown; i++) {
      const o = wsObject(groupOffset + i + 1)
      const n = Math.min(o && o.toplevels ? o.toplevels.values.length : 0, cfg.maxWindowIcons)
      if (n > 0) h += n * iconRef.implicitHeight + Tk.padding.extraSmall
    }
    return h
  }
  MIcon { id: iconRef; visible: false; topPadding: -Tk.spacing.extraSmall / 2; text: "terminal" }

  implicitWidth: Tk.barInner
  implicitHeight: list.implicitHeight + Tk.padding.extraSmall * 2
  radius: width / 2
  color: Colours.m3surfaceContainer
  Behavior on implicitHeight { Anim {} }

  // The workspace cells, top to bottom, for the bar focus mode's cursor.
  function navItems() {
    const out = []
    for (let i = 0; i < rep.count; i++) {
      const it = rep.itemAt(i)
      if (it) out.push(it)
    }
    return out
  }

  function wsObject(id) {
    const v = Hyprland.workspaces.values
    for (let i = 0; i < v.length; i++) if (v[i].id === id) return v[i]
    return null
  }

  // Caelestia's Bar.qml wheel: on a special workspace, scrolling closes it.
  function scroll(dy) {
    if (!Config.o.bar.scroll.workspaces) return
    if (inSpecial) Sys.toggleSpecial(specialName.slice("special:".length))
    else if (dy < 0 || activeId > 1) Sys.workspace(dy > 0 ? "r-1" : "r+1")
  }

  // Caelestia services/Hypr.qml: the monitor's specialWorkspace only lives in
  // lastIpcObject, which Quickshell refreshes on demand.
  Connections {
    target: Hyprland
    function onRawEvent(e) {
      const n = e.name
      if (n.endsWith("v2")) return
      if (["workspace", "moveworkspace", "activespecial", "focusedmon"].indexOf(n) >= 0) {
        Hyprland.refreshWorkspaces()
        Hyprland.refreshMonitors()
      } else if (["openwindow", "closewindow", "movewindow", "windowtitle"].indexOf(n) >= 0) {
        Hyprland.refreshToplevels()
        Hyprland.refreshWorkspaces()
      }
    }
  }
  Component.onCompleted: {
    Hyprland.refreshToplevels()
    Hyprland.refreshMonitors()
  }

  Item {
    id: normal
    anchors.fill: parent
    scale: root.inSpecial ? 0.8 : 1
    opacity: root.inSpecial ? 0.5 : 1
    Behavior on scale { Anim {} }
    Behavior on opacity { Anim { type: "effects" } }

    layer.enabled: root.blur > 0
    layer.effect: MultiEffect {
      blurEnabled: true
      blur: root.blur
      blurMax: 32
    }

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
          readonly property bool hasWindows: occupied && root.iconsFit && root.cfg.showWindows && root.cfg.maxWindowIcons > 0
          height: col.implicitHeight + (hasWindows ? Tk.padding.extraSmall : 0)
          Behavior on height { Anim {} }

          function pickShape() {
            shape.shape = focused ? root.focusedShapes[Math.floor(Math.random() * root.focusedShapes.length)]
                                  : (occupied ? "square" : "circle")
          }
          onFocusedChanged: pickShape()
          onOccupiedChanged: if (!focused) pickShape()
          Component.onCompleted: {
            pickShape()
            root.listGen++
          }

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

    // Runs of consecutive occupied workspaces get a shared background pill.
    Repeater {
      model: {
        if (!root.cfg.occupiedBg) return []
        root.listGen  // re-run once the delegates exist
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

    ActiveIndicator {
      visible: root.cfg.activeIndicator
      list: list
      target: {
        root.listGen  // re-run once the delegates exist
        return rep.count ? rep.itemAt(Math.max(0, Math.min(root.shown - 1, root.activeId - 1 - root.groupOffset))) : null
      }
    }

    // Caelestia: clicking the focused workspace toggles the default special
    // workspace, which on Omarchy is the scratchpad.
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: function(e) {
        const p = mapToItem(list, e.x, e.y)
        const it = list.childAt(p.x, p.y)
        if (!it || it.wsId === undefined) return
        if (it.wsId !== root.activeId) Sys.workspace(it.wsId)
        else Sys.toggleSpecial("scratchpad")
      }
      onWheel: function(e) { root.scroll(e.angleDelta.y) }
    }
  }

  Loader {
    anchors.fill: parent
    opacity: root.inSpecial ? 1 : 0
    active: opacity > 0
    Behavior on opacity { Anim { type: "effects" } }

    sourceComponent: Item {
      Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Qt.alpha(Colours.m3scrim, Colours.light ? 0 : 0.2)
      }

      SpecialWorkspaces {
        anchors.fill: parent
        anchors.margins: Tk.padding.extraSmall
        monitor: root.monitor
        focusedShapes: root.focusedShapes
        onWheel: dy => root.scroll(dy)

        scale: 0.5
        Component.onCompleted: scale = Qt.binding(() => root.inSpecial ? 1 : 0.5)
        Behavior on scale { Anim {} }
      }
    }
  }
}
