import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../../.."
import "../../../core/LiquidMath.js" as M

// Settings › Motion's preview, Omacale's own: a miniature frame with a
// drawer coming out of its top edge, drawn by the same blob shader and moved
// by the same LiquidDrawer as the real ones, so every setting on the page
// shows here as it is changed; then, with the neck break on, a panel pulled
// off its left edge into the middle and back (LiquidDetach, as the window
// info panel and Settings leave the bar). With liquid motion off it moves on
// Caelestia's curves, for comparison. It replays by itself after a change.
ColumnLayout {
  id: root
  property var row
  property var settings
  property bool first
  property bool last
  spacing: Tk.spacing.medium

  readonly property real sw: settings ? settings.screenWidth : 1920

  function play() {
    detachStart.stop()
    detachHold.stop()
    // The detach demo goes home first, so the two never melt together.
    if (card.det > 0.01) {
      card.detached = false
      replay.restart()
      return
    }
    card.open = true
    hold.restart()
  }
  Timer { id: hold; interval: 1100 * Tk.animScale; onTriggered: { card.open = false; if (Liquid.enabled && Liquid.neckBreak) detachStart.restart() } }
  Timer { id: detachStart; interval: 700 * Tk.animScale; onTriggered: { card.detached = true; detachHold.restart() } }
  Timer { id: detachHold; interval: 1300 * Tk.animScale; onTriggered: card.detached = false }
  // A change replays it, once the slider has stopped moving.
  Timer { id: replay; interval: 350; onTriggered: root.play() }
  Connections {
    target: Config.o.liquid
    function onEnabledChanged() { replay.restart() }
    function onPresetChanged() { replay.restart() }
    function onStyleChanged() { replay.restart() }
    function onStiffnessChanged() { replay.restart() }
    function onDampingChanged() { replay.restart() }
    function onBulgeChanged() { replay.restart() }
    function onNeckChanged() { replay.restart() }
    function onNeckWidthChanged() { replay.restart() }
    function onNarrowChanged() { replay.restart() }
    function onRoundingChanged() { replay.restart() }
    function onSagChanged() { replay.restart() }
    function onWobbleChanged() { replay.restart() }
  }
  Connections {
    target: Config.o.liquid.detach
    function onNeckBreakChanged() { replay.restart() }
    function onRipplesChanged() { replay.restart() }
    function onStrayChanged() { replay.restart() }
  }
  Component.onCompleted: replay.restart()

  Item {
    id: card
    Layout.fillWidth: true
    implicitHeight: Math.round(width * 0.42)
    // Screen px to card px.
    readonly property real s: width / root.sw
    // The miniature's own unit: twice the screen's, so the drawer reads.
    readonly property real u: s * 2
    property bool open: false

    readonly property real bt: Math.max(2, Tk.border * s)
    readonly property real dw: Math.round(width * 0.46)
    readonly property real dh: Math.round(height * 0.55)
    readonly property real dx: Math.round((width - dw) / 2)

    LiquidDrawer {
      id: liq
      force: true
      name: "dashboard"
      open: card.open
      edge: "top"
      canDrop: true
      unit: card.u
    }
    property real offC: open ? 0 : 1
    Behavior on offC { enabled: !liq.active; Anim {} }
    readonly property real off: liq.active ? liq.off : offC
    // How far it slides (ScreenScope.slid).
    readonly property real slide: liq.drop ? 0 : liq.active ? Math.max(0, off) : off
    readonly property var rect: off < 1 ? liq.rect([dx, bt + (-dh - 5) * slide, dw, dh]) : null
    // The detach demo: a panel that grows out of a small rect behind the left
    // edge into the middle, on the drawers' spring, and goes back.
    property bool detached: false
    Spring {
      id: detSpring
      live: Liquid.enabled
      target: card.detached ? 1 : 0
      absorb: 0
      stiffness: Liquid.stiffness / 1.69
      damping: Liquid.damping / 1.3
    }
    readonly property real det: Liquid.enabled ? detSpring.value : 0
    readonly property real pw: Math.round(width * 0.3)
    readonly property real ph: Math.round(height * 0.45)
    readonly property var detFrom: [bt - pw * 0.25 - 5, (height - ph * 0.4) / 2, pw * 0.25, ph * 0.4]
    readonly property var detTo: [(width - pw) / 2, (height - ph) / 2, pw, ph]
    readonly property var detRect: det > 0.001 ? [0, 1, 2, 3].map(i => detFrom[i] + (detTo[i] - detFrom[i]) * det) : null
    LiquidDetach {
      id: detach
      active: Liquid.enabled
      t: Math.max(0, Math.min(1, card.det))
      edge: "left"
      ex: card.bt
      ey: card.height / 2
      unit: card.u
    }
    BlobDeform {
      id: detDeform
      extra: detach.thread
      amount: 0.05
      cx: card.detRect ? card.detRect[0] + card.detRect[2] / 2 : 0
      cy: card.height / 2
    }
    BlobDeform {
      id: deform
      extra: liq.neck
      amount: 0.1
      cx: card.dx + card.dw / 2
      cy: card.bt + (-card.dh - 5) * card.slide + card.dh / 2
    }

    Rectangle { id: mask; anchors.fill: parent; radius: Tk.rounding.large; visible: false; layer.enabled: true }

    Item {
      anchors.fill: parent
      layer.enabled: true
      layer.effect: ShaderMaskEffect { maskItem: mask }

      Rectangle { anchors.fill: parent; color: Colours.m3surfaceContainerHighest }

      Item {
        anchors.fill: parent
        layer.enabled: Config.o.appearance.shadow
        layer.effect: MultiEffect { shadowEnabled: true; blurMax: 12; shadowColor: Qt.alpha(Colours.m3shadow, 0.6) }
        BlobSurface {
          id: blob
          anchors.fill: parent
          smoothing: Math.max(1, Tk.smoothing * card.u)
          frameRadius: Tk.borderRounding * card.u
          radius: Tk.rounding.extraLarge * card.u
          hole: Qt.rect(card.bt, card.bt, width - card.bt * 2, height - card.bt * 2)
          rects: [card.rect, card.detRect]
          corners: [liq.corner(card.rect, radius), -1]
          deforms: [deform.vec, detDeform.vec]
          bumps: detach.bumps
          color: Colours.m3surface
        }
      }

      // Its content: three lines, coming in with the drawer.
      Column {
        x: card.dx + Tk.padding.large * card.u
        y: card.bt + (-card.dh - 5) * card.slide + Tk.padding.large * card.u
        width: card.dw - Tk.padding.large * card.u * 2
        spacing: Math.max(2, Tk.spacing.small * card.u)
        visible: card.off < 1
        opacity: liq.active ? liq.contentOpacity : 1 - card.off
        transform: [
          Matrix4x4 { matrix: deform.matrixAt(card.dw / 2 - Tk.padding.large * card.u, card.dh / 2 - Tk.padding.large * card.u) },
          Scale { origin.x: card.dw / 2 - Tk.padding.large * card.u; origin.y: -Tk.padding.large * card.u; xScale: liq.contentScale[0]; yScale: liq.contentScale[1] }
        ]
        Repeater {
          model: [1, 0.7, 0.85]
          Rectangle {
            required property real modelData
            width: parent.width * modelData
            height: Math.max(3, card.dh * 0.14)
            radius: height / 2
            color: Colours.m3surfaceContainerHigh
          }
        }
      }
    }
    StateLayer { radius: Tk.rounding.large; color: Colours.m3onSurface; onClicked: root.play() }
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Tk.spacing.medium
    MText {
      Layout.fillWidth: true
      leftPadding: Tk.padding.small
      color: Colours.m3onSurfaceVariant
      elide: Text.ElideRight
      // Settle time of an underdamped unit-mass spring: ~4 / (zeta * omega) = 8 / c.
      text: !Liquid.enabled ? "Off: drawers move on Caelestia's curves"
        : "Overshoot " + Math.round(M.overshoot(Liquid.stiffness, Liquid.damping) * 100) + "% · settles in "
          + (8 / Math.max(0.1, Liquid.damping)).toFixed(2) + " s · " + (Liquid.drop ? "drops" : "slides")
    }
    IconButton {
      type: "tonal"
      icon: "replay"
      onClicked: root.play()
    }
  }
}
