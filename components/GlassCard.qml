// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ilyamiro and the Serpantinum contributors (https://github.com/ilyamiro/serpantinum).
// Ported from Serpantinum (GlassFill.qml). See THIRD_PARTY.md.
import QtQuick
import QtQuick.Window
import Quickshell
import ".."

// A card in a drawer. Normally a Rectangle of `fill`. With glass cards on
// (Glass.nested) it is Serpantinum's nested glass (GlassFill.qml): clear
// glass of its own over the drawer's, its flat only its tint, its rim bending
// the drawer glass under it (shaders/glasscard.frag), lit along its edge,
// swelling under the pointer and bending harder while it moves. What it
// bends is ScreenScope's `glassSurface`, the frame and drawers drawn once to
// a texture; in a window without one (the toasts) it stays a Rectangle.
Rectangle {
  id: root

  property color fill: Colours.m3surfaceContainer

  readonly property var glassHost: QsWindow.window
  readonly property Item surface: glassHost && glassHost.glassSurface ? glassHost.glassSurface : null
  readonly property bool glassy: Glass.nested && surface !== null && width > 1 && height > 1

  color: glassy ? "transparent" : fill

  // Where the card sits on the surface, followed on every frame the window
  // draws while it is glass: drawers slide, pages scroll, and none of that is
  // a binding. A frame is never asked for to do it (a FrameAnimation would
  // keep an open drawer redrawing forever); anything that moves the card
  // draws one anyway.
  property rect surfaceRect: Qt.rect(0, 0, 0, 0)
  function place() {
    const a = surface.mapFromItem(root, 0, 0)
    const b = surface.mapFromItem(root, width, height)
    const x = Math.min(a.x, b.x), y = Math.min(a.y, b.y)
    const w = Math.abs(b.x - a.x), h = Math.abs(b.y - a.y)
    const r = surfaceRect
    if (x !== r.x || y !== r.y || w !== r.width || h !== r.height) surfaceRect = Qt.rect(x, y, w, h)
  }
  Connections {
    target: root.glassy && root.visible ? root.Window.window : null
    function onAfterAnimating() { root.place() }
  }
  onGlassyChanged: if (glassy) Qt.callLater(place)

  GlassMotion {
    id: moving
    enabled: Glass.motion && root.glassy
    rects: [[root.surfaceRect.x, root.surfaceRect.y, root.surfaceRect.width, root.surfaceRect.height]]
  }

  HoverHandler {
    id: pointer
    enabled: root.glassy && Glass.pointer
  }
  property real hoverAmount: pointer.hovered ? 1 : 0
  Behavior on hoverAmount { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

  Loader {
    anchors.fill: parent
    z: -1
    active: root.glassy
    sourceComponent: ShaderEffect {
      readonly property real sw: Math.max(1, root.surface.width)
      readonly property real sh: Math.max(1, root.surface.height)
      property variant src: root.surface
      property vector2d itemSize: Qt.vector2d(width, height)
      property vector4d radii: Qt.vector4d(root.topLeftRadius, root.topRightRadius, root.bottomRightRadius, root.bottomLeftRadius)
      property color tintColor: Qt.rgba(root.fill.r, root.fill.g, root.fill.b, 1)
      property real tintAmount: root.fill.a
      property real bezel: Math.max(3, Math.min(14, Math.min(width, height) * 0.28)) * Glass.bevel / Tk.px(18)
      property real thickness: bezel * 0.8 * Glass.refraction
      property real dispersion: Glass.dispersion * 0.06
      property real rim: 0.45 * (1 - 0.35 * 0.5) * Glass.light
      property vector4d srcRect: Qt.vector4d(root.surfaceRect.x / sw, root.surfaceRect.y / sh, root.surfaceRect.width / sw, root.surfaceRect.height / sh)
      property vector2d cursor: Qt.vector2d(pointer.point.position.x, pointer.point.position.y)
      property real hover: root.hoverAmount
      property real motion: moving.values[0] || 0
      fragmentShader: Qt.resolvedUrl("../shaders/glasscard.frag.qsb")
    }
  }
}
