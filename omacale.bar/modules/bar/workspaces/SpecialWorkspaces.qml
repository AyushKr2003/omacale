import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import "../../.."

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
  // A column on a left or right bar, a row on a top or bottom one.
  property bool vertical: true
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
  // How far the list is scrolled along the bar (<= 0), and how far it can be.
  property real scrollPos: 0
  readonly property real viewLen: vertical ? view.height : view.width
  readonly property real rootLen: vertical ? height : width
  readonly property real maxScroll: Math.max(0, viewLen - rootLen)
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
    const top = vertical ? activeWs.y : activeWs.x
    const bottom = top + (vertical ? activeWs.height : activeWs.width)
    let target = scrollPos
    if (top < -target) target = -top
    else if (bottom > -target + rootLen) target = -(bottom - rootLen)
    target = clamp(target, -maxScroll, 0)
    if (target === scrollPos) return
    if (animate === false) {
      scrollBehavior.enabled = false
      scrollPos = target
      scrollBehavior.enabled = true
    } else {
      scrollAnim.type = "spatial"
      scrollPos = target
      scrollAnim.type = "fastEffects"
    }
  }
  Behavior on scrollPos {
    id: scrollBehavior
    Anim { id: scrollAnim; type: "fastEffects" }
  }
  onActiveWsChanged: ensureVisible()
  onRootLenChanged: ensureVisible(false)
  onMaxScrollChanged: ensureVisible()
  Component.onCompleted: ensureVisible(false)
  Connections {
    target: root.activeWs
    function onYChanged() { root.ensureVisible() }
    function onHeightChanged() { root.ensureVisible() }
    function onXChanged() { root.ensureVisible() }
    function onWidthChanged() { root.ensureVisible() }
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
      radius: Math.min(width, height) / 2
      gradient: Gradient {
        orientation: root.vertical ? Gradient.Vertical : Gradient.Horizontal
        GradientStop { position: 0; color: "transparent" }
        GradientStop { position: 0.2; color: "white" }
        GradientStop { position: 0.8; color: "white" }
        GradientStop { position: 1; color: "transparent" }
      }
    }
    // The half at each end that stays solid while the list is scrolled to it.
    Rectangle {
      x: 0
      y: 0
      width: root.vertical ? parent.width : parent.width / 2
      height: root.vertical ? parent.height / 2 : parent.height
      radius: Math.min(width, height) / 2
      opacity: root.scrollPos < -Tk.padding.extraSmall ? 0 : 1
      Behavior on opacity { Anim { type: "effects" } }
    }
    Rectangle {
      x: root.vertical ? 0 : parent.width - width
      y: root.vertical ? parent.height - height : 0
      width: root.vertical ? parent.width : parent.width / 2
      height: root.vertical ? parent.height / 2 : parent.height
      radius: Math.min(width, height) / 2
      opacity: root.scrollPos > -root.maxScroll + Tk.padding.extraSmall ? 0 : 1
      Behavior on opacity { Anim { type: "effects" } }
    }
  }

  Grid {
    id: view
    // Scrolled along the bar, filling it across (see Workspaces `list` for why
    // this is not anchored).
    x: root.vertical ? 0 : root.scrollPos
    y: root.vertical ? root.scrollPos : 0
    width: root.vertical ? parent.width : implicitWidth
    height: root.vertical ? implicitHeight : parent.height
    columns: root.vertical ? 1 : 1000
    spacing: Tk.spacing.small
    onHeightChanged: root.ensureVisible()
    onWidthChanged: root.ensureVisible()

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

        width: root.vertical ? view.width : col.implicitWidth + (hasWindows ? Tk.padding.extraSmall : 0)
        height: root.vertical ? col.implicitHeight + (hasWindows ? Tk.padding.extraSmall : 0) : view.height
        Behavior on height { enabled: root.vertical; Anim {} }
        Behavior on width { enabled: !root.vertical; Anim {} }
        opacity: 0
        Component.onCompleted: { opacity = 1; pickShape(); root.listGen++ }
        Behavior on opacity { Anim { type: "effects" } }

        Grid {
          id: col
          width: root.vertical ? ws.width : implicitWidth
          height: root.vertical ? implicitHeight : ws.height
          columns: root.vertical ? 1 : 1000
          spacing: 0
          Item {
            width: root.vertical ? col.width : Tk.barInner - Tk.padding.small
            height: root.vertical ? Tk.barInner - Tk.padding.small : col.height
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
              implicitSize: Tk.barInner - Tk.padding.small
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
              width: root.vertical ? col.width : implicitWidth
              height: root.vertical ? implicitHeight : col.height
              topPadding: root.vertical ? -Tk.spacing.extraSmall / 2 : 0
              leftPadding: root.vertical ? 0 : -Tk.spacing.extraSmall / 2
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
    vertical: root.vertical
    list: view
    target: root.activeWs
    color: Colours.m3tertiary
    contentColour: Colours.m3onTertiary
  }

  MouseArea {
    property real startPos
    property real startScroll
    property bool dragging

    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor

    onPressed: e => { startPos = root.vertical ? e.y : e.x; startScroll = root.scrollPos; dragging = false }
    onPositionChanged: e => {
      const p = root.vertical ? e.y : e.x
      if (!dragging && Math.abs(p - startPos) > drag.threshold) dragging = true
      if (dragging) root.scrollPos = root.clamp(startScroll + (p - startPos), -root.maxScroll, 0)
    }
    onClicked: e => {
      if (dragging) return
      const it = view.childAt(root.vertical ? e.x : e.x - root.scrollPos, root.vertical ? e.y - root.scrollPos : e.y)
      Sys.toggleSpecial(it && it.wsId !== undefined ? it.name : "scratchpad")
    }
    onWheel: e => root.wheel(e.angleDelta.y)
  }
}
