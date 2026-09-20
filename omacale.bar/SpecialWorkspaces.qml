import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland

// Caelestia modules/bar/components/workspaces/SpecialWorkspaces.qml: the
// special workspaces on this monitor as icons (Caelestia's
// specialDisplayType Icons + specialWorkspaceIcons), each with its windows
// underneath, a tertiary active pill, and a drag-to-scroll list whose ends
// fade out when there's more to see.
//
// Settings › Taskbar › Workspaces › Special workspaces › Display:
//   icons   the named icon below, ★ for any other name (Caelestia would show
//           the name's first letter here)
//   star    ★ for every special workspace
//   letters the name's first letter (Caelestia's Text display)
//   shapes  the normal workspaces' M3 shapes (Caelestia's Shapes display)
Item {
  id: root

  required property var monitor
  readonly property var cfg: Config.o.bar.workspaces
  property var focusedShapes: []
  readonly property string display: cfg.specialDisplay
  signal wheel(real dy)

  // Caelestia barconfig.hpp specialWorkspaceIcons, plus Omarchy's scratchpad
  // (its Super+S special, the counterpart of Caelestia's "special").
  readonly property var iconRules: ({
    special: "star",
    scratchpad: "star",
    communication: "forum",
    music: "music_cast",
    todo: "checklist",
    sysmon: "monitor_heart"
  })

  readonly property int activeSpecialId: {
    const s = monitor && monitor.lastIpcObject ? monitor.lastIpcObject.specialWorkspace : null
    return s ? s.id : 0
  }
  readonly property var wsIds: Hyprland.workspaces.values
    .filter(w => w.name.startsWith("special:") && w.monitor === root.monitor)
    .map(w => w.id)
  readonly property int activeIdx: wsIds.indexOf(activeSpecialId)
  readonly property real maxViewY: Math.max(0, view.height - height)
  // See Workspaces.qml `listGen`: `rep.count` is the model size before the
  // delegates exist and `rep.itemAt()` is not a dependency, so without this the
  // tertiary pill and the scroll-into-view resolve to null once and stay there.
  property int listGen: 0
  readonly property Item activeWs: {
    root.listGen
    return activeIdx >= 0 ? rep.itemAt(activeIdx) : null
  }

  function trim(name) { return name.startsWith("special:") ? name.slice("special:".length) : name }
  function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }

  function ensureVisible(animate) {
    if (!activeWs) return
    const top = activeWs.y, bottom = top + activeWs.height
    let target = view.y
    if (top < -target) target = -top
    else if (bottom > -target + height) target = -(bottom - height)
    target = clamp(target, -maxViewY, 0)
    if (target === view.y) return
    if (animate === false) {
      viewYBehavior.enabled = false
      view.y = target
      viewYBehavior.enabled = true
    } else {
      viewYAnim.type = "spatial"
      view.y = target
      viewYAnim.type = "fastEffects"
    }
  }
  onActiveWsChanged: ensureVisible()
  onHeightChanged: ensureVisible(false)
  onMaxViewYChanged: ensureVisible()
  Component.onCompleted: ensureVisible(false)
  Connections {
    target: root.activeWs
    function onYChanged() { root.ensureVisible() }
    function onHeightChanged() { root.ensureVisible() }
  }

  layer.enabled: true
  layer.effect: MultiEffect {
    maskEnabled: true
    maskSource: mask
    maskThresholdMin: 0
    maskSpreadAtMin: 0
  }

  // Fade the ends, but keep an end solid while the list is scrolled to it.
  Item {
    id: mask
    anchors.fill: parent
    layer.enabled: true
    visible: false

    Rectangle {
      anchors.fill: parent
      radius: width / 2
      gradient: Gradient {
        GradientStop { position: 0; color: "transparent" }
        GradientStop { position: 0.2; color: "white" }
        GradientStop { position: 0.8; color: "white" }
        GradientStop { position: 1; color: "transparent" }
      }
    }
    Rectangle {
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      height: parent.height / 2
      radius: width / 2
      opacity: view.y < -Tk.padding.extraSmall ? 0 : 1
      Behavior on opacity { Anim { type: "effects" } }
    }
    Rectangle {
      anchors.bottom: parent.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      height: parent.height / 2
      radius: width / 2
      opacity: view.y > -root.maxViewY + Tk.padding.extraSmall ? 0 : 1
      Behavior on opacity { Anim { type: "effects" } }
    }
  }

  Column {
    id: view
    anchors.left: parent.left
    anchors.right: parent.right
    spacing: Tk.spacing.small
    onHeightChanged: root.ensureVisible()

    Behavior on y {
      id: viewYBehavior
      Anim { id: viewYAnim; type: "fastEffects" }
    }

    Repeater {
      id: rep
      model: ScriptModel { values: root.wsIds }

      Item {
        id: ws
        required property var modelData
        readonly property int wsId: modelData
        readonly property var obj: {
          const v = Hyprland.workspaces.values
          for (let i = 0; i < v.length; i++) if (v[i].id === wsId) return v[i]
          return null
        }
        readonly property string name: obj ? root.trim(obj.name) : ""
        readonly property string icon: root.display === "star" ? "star"
          : root.display === "icons" ? root.iconRules[name] || "star" : ""
        readonly property var toplevels: obj && obj.toplevels ? obj.toplevels.values : []
        readonly property bool occupied: toplevels.length > 0
        readonly property bool focused: wsId === root.activeSpecialId
        readonly property color fg: focused || occupied || root.cfg.occupiedBg ? Colours.m3onSurface : Colours.m3outlineVariant
        readonly property bool hasWindows: occupied && root.cfg.specialShowWindows && root.cfg.maxWindowIcons > 0

        function pickShape() {
          shape.shape = focused && root.focusedShapes.length ? root.focusedShapes[Math.floor(Math.random() * root.focusedShapes.length)]
                                                             : (occupied ? "square" : "circle")
        }
        onFocusedChanged: pickShape()
        onOccupiedChanged: if (!focused) pickShape()

        width: view.width
        height: col.implicitHeight + (hasWindows ? Tk.padding.extraSmall : 0)
        Behavior on height { Anim {} }
        opacity: 0
        Component.onCompleted: { opacity = 1; pickShape(); root.listGen++ }
        Behavior on opacity { Anim { type: "effects" } }

        Column {
          id: col
          width: parent.width
          spacing: 0
          Item {
            width: parent.width
            height: Tk.barInner - Tk.padding.small
            MIcon {
              anchors.centerIn: parent
              visible: ws.icon !== ""
              text: ws.icon
              fill: 1
              grade: 25
              color: ws.fg
            }
            MShape {
              id: shape
              anchors.centerIn: parent
              visible: root.display === "shapes"
              implicitSize: parent.height
              color: ws.fg
              scale: ws.focused ? 2 / 3 : ws.occupied ? 1 / 3 : 1 / 4
              Behavior on scale { Anim {} }
            }
            MText {
              anchors.centerIn: parent
              visible: root.display === "letters"
              text: ws.name.charAt(0)
              font.family: Tk.clock
              font.pointSize: Tk.body.small
              color: ws.fg
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

  ActiveIndicator {
    visible: root.cfg.activeIndicator
    list: view
    target: root.activeWs
    color: Colours.m3tertiary
    contentColour: Colours.m3onTertiary
  }

  MouseArea {
    property real startY
    property real startViewY
    property bool dragging

    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor

    onPressed: e => { startY = e.y; startViewY = view.y; dragging = false }
    onPositionChanged: e => {
      if (!dragging && Math.abs(e.y - startY) > drag.threshold) dragging = true
      if (dragging) view.y = root.clamp(startViewY + (e.y - startY), -root.maxViewY, 0)
    }
    onClicked: e => {
      if (dragging) return
      const it = view.childAt(e.x, e.y - view.y)
      Sys.toggleSpecial(it && it.wsId !== undefined ? it.name : "scratchpad")
    }
    onWheel: e => root.wheel(e.angleDelta.y)
  }
}
