import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import "../.."

// What is behind the glass, rebuilt (Settings › Glass › Bend the edge,
// docs/liquid-glass-research.md §11). Wayland never shows a client what is
// under its own surface, and a screen capture has our own glass in it:
// pleamar unmixes that capture, with a feedback loop and a frame behind.
// Here nothing is captured that has us in it. Under the frame there is only
// the wallpaper, and Omacale knows the file; under a drawer, the windows of
// this screen's workspace, each captured on its own (toplevel export, as the
// overview does), which has no layer surface in it. Laid where Hyprland
// lays them, they are what is behind, live, with nothing to unmix.
//
// `texture` is that picture, and `frosted` the same blurred (Qt's
// MultiEffect, a real Gaussian; mip levels sampled deeper read back sharp). Transparent where nothing is known (a video wallpaper, a window
// whose first frame hasn't come): the shader's lens weighs itself by alpha
// and leaves those pixels to the drawn glass. The windows are captured once
// when they appear and live only while `live` (a drawer is open): with only
// the frame showing, the picture is the still wallpaper and costs nothing.
Item {
  id: root

  required property ShellScreen screen
  property bool live: false
  // How far `frosted` is blurred (px): the lens's frost, never under 8 so
  // the shader can tell busy from calm by it even on clear glass.
  property real frost: 12

  readonly property var monitor: Hyprland.monitorFor(screen)
  readonly property alias texture: source
  readonly property alias frosted: frostedSource

  // Hyprland's window rounding and border, which it draws round the
  // captures; read once and again on `configreloaded`.
  property real rounding: 0
  property real borderSize: 0
  property color borderActive: "transparent"
  property color borderInactive: "transparent"

  // Omarchy's background is the `current/background` link, drawn cropped to
  // fill (Omarchy's background plugin). A video has no still: unknown.
  readonly property string link: Quickshell.env("HOME") + "/.local/state/omarchy/current/background"
  property string wallPath: ""

  Process {
    id: resolve
    command: ["readlink", "-f", root.link]
    stdout: SplitParser {
      onRead: line => {
        const p = String(line).trim()
        root.wallPath = p && !Wallpapers.isVideo(p) ? p : ""
      }
    }
  }
  Timer {
    interval: 5000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: resolve.running = true
  }
  Connections {
    target: Wallpapers
    function onCurrentWallChanged() { resolve.running = true }
  }

  Process {
    id: deco
    command: ["bash", "-c", "for o in decoration:rounding general:border_size general:col.active_border general:col.inactive_border; do hyprctl getoption \"$o\" -j; done"]
    stdout: StdioCollector {
      onStreamFinished: {
        const objs = String(text).split(/\}\s*\{/).map((s, i, a) => (i > 0 ? "{" : "") + s + (i < a.length - 1 ? "}" : ""))
        for (const s of objs) {
          let o
          try { o = JSON.parse(s) } catch (e) { continue }
          if (o.option === "decoration:rounding") root.rounding = o.int || 0
          else if (o.option === "general:border_size") root.borderSize = o.int || 0
          else if (o.option === "general:col.active_border") root.borderActive = root.firstColour(o)
          else if (o.option === "general:col.inactive_border") root.borderInactive = root.firstColour(o)
        }
      }
    }
  }
  // A gradient border keeps its first colour: under the bevel it is a line a
  // few pixels wide, bent and frosted.
  function firstColour(o) {
    const s = String(o.custom || o.str || "").trim().split(/\s+/)[0] || ""
    const m = s.match(/^(?:0x|rgba\()?([0-9a-fA-F]{8})\)?$/)
    if (!m) return "transparent"
    const h = m[1]
    return Qt.rgba(parseInt(h.slice(0, 2), 16) / 255, parseInt(h.slice(2, 4), 16) / 255,
                   parseInt(h.slice(4, 6), 16) / 255, parseInt(h.slice(6, 8), 16) / 255)
  }
  Component.onCompleted: deco.running = true

  // Where the windows are: Hyprland's toplevels are refreshed on the events
  // that move them, and every second while a drawer is open (a drag or a
  // resize sends none).
  Connections {
    target: Hyprland
    function onRawEvent(e) {
      if (e.name === "configreloaded") deco.running = true
      if (["openwindow", "movewindow", "movewindowv2", "changefloatingmode", "activewindowv2",
           "workspacev2", "focusedmonv2", "activespecialv2"].includes(e.name)) Hyprland.refreshToplevels()
    }
  }
  Timer {
    interval: 1000
    running: root.live
    repeat: true
    triggeredOnStart: true
    onTriggered: Hyprland.refreshToplevels()
  }

  // What is shown on this screen: its workspace, and the special workspace
  // open over it.
  readonly property int workspaceId: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : 0
  readonly property var monitorIpc: monitor ? monitor.lastIpcObject : null
  readonly property int specialId: monitorIpc && monitorIpc.specialWorkspace ? monitorIpc.specialWorkspace.id : 0

  Item {
    id: picture
    width: root.width
    height: root.height

    Image {
      anchors.fill: parent
      visible: root.wallPath !== "" && status === Image.Ready
      source: root.wallPath ? Wallpapers.url(root.wallPath) : ""
      sourceSize: Qt.size(root.width, root.height)
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      cache: false
      smooth: true
    }

    // One delegate per toplevel, kept while it lives (a model rebuilt on each
    // refresh would start every capture over), placed and stacked from its
    // last IPC object: tiled first, then the floating ones by focus (the
    // most recent on top), the special workspace over them all.
    Repeater {
      model: Hyprland.toplevels
      delegate: Rectangle {
        id: client
        required property HyprlandToplevel modelData
        readonly property var o: modelData.lastIpcObject || ({})
        readonly property bool special: root.specialId !== 0 && !!o.workspace && o.workspace.id === root.specialId
        readonly property bool shown: !!o.at && !!o.size && !!o.workspace && !o.hidden && o.mapped !== false
          && (o.workspace.id === root.workspaceId || special)
        readonly property real bs: root.borderSize
        x: shown ? o.at[0] - (root.monitorIpc ? root.monitorIpc.x : 0) - bs : 0
        y: shown ? o.at[1] - (root.monitorIpc ? root.monitorIpc.y : 0) - bs : 0
        z: special ? 2000 - (o.focusHistoryID || 0) : o.floating ? 1000 - (o.focusHistoryID || 0) : 0
        width: shown ? o.size[0] + 2 * bs : 0
        height: shown ? o.size[1] + 2 * bs : 0
        radius: root.rounding > 0 ? root.rounding + bs : 0
        color: o.focusHistoryID === 0 ? root.borderActive : root.borderInactive
        visible: shown && shot.hasContent

        ClippingRectangle {
          x: client.bs
          y: client.bs
          width: Math.max(0, client.width - 2 * client.bs)
          height: Math.max(0, client.height - 2 * client.bs)
          radius: root.rounding
          color: "transparent"

          ScreencopyView {
            id: shot
            anchors.fill: parent
            captureSource: client.shown ? client.modelData.wayland : null
            live: root.live
          }
        }
      }
    }
  }

  ShaderEffectSource {
    id: source
    anchors.fill: parent
    sourceItem: picture
    hideSource: true
    live: true
    smooth: true
    visible: false
  }

  MultiEffect {
    id: blurred
    anchors.fill: parent
    source: source
    autoPaddingEnabled: false
    blurEnabled: true
    blur: 1
    blurMax: Math.max(8, Math.round(root.frost))
    blurMultiplier: 0
  }
  ShaderEffectSource {
    id: frostedSource
    anchors.fill: parent
    sourceItem: blurred
    hideSource: true
    live: true
    smooth: true
    visible: false
  }
}
