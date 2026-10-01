import QtQuick
import QtQuick.Layouts
import "../../.."

// Caelestia SliderRow: icon, label and value on top, a slider underneath.
ConnectedRect {
  id: root
  property var row
  property var settings
  readonly property real value: Number(Config.get(row.key))
  readonly property real frac: (value - row.from) / (row.to - row.from)
  function fmt(v) {
    if (row.unit === "%") return Math.round(v * 100) + "%"
    if (row.unit === "x") return v.toFixed(2).replace(/0$/, "") + "×"
    if (row.unit === "px") return Math.round(v) + " px"
    return String(v)
  }
  function valueAt(f) {
    const s = row.step || 0.01
    const v = Math.round((row.from + f * (row.to - row.from)) / s) * s
    return Number(v.toFixed(4))
  }
  function setFrac(f) { Config.set(row.key, valueAt(f)) }
  // `commit: "release"` writes only when the drag ends, for settings that
  // re-lay out Settings itself (the scale) and would move the slider away
  // from the pointer mid-drag. The label still follows the drag.
  readonly property bool onRelease: row.commit === "release"
  readonly property real shown: onRelease && slider.dragging ? valueAt(slider.pos) : value

  implicitHeight: col.implicitHeight + Tk.padding.large + Tk.padding.largeIncreased

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: Tk.padding.largeIncreased
    anchors.rightMargin: Tk.padding.largeIncreased
    anchors.topMargin: Tk.padding.large
    anchors.bottomMargin: Tk.padding.largeIncreased
    spacing: Tk.spacing.medium
    MIcon { text: root.row.icon || "tune"; size: Tk.iconSize.medium; color: Colours.m3onSurfaceVariant }
    ColumnLayout {
      id: col
      Layout.fillWidth: true
      spacing: Tk.spacing.medium
      RowLayout {
        Layout.fillWidth: true
        spacing: Tk.spacing.small
        MText { Layout.fillWidth: true; text: root.row.where ? root.row.where + " · " + root.row.label : root.row.label; elide: Text.ElideRight }
        MText { text: root.fmt(root.shown); color: Colours.m3outline }
      }
      MSlider {
        id: slider
        Layout.fillWidth: true
        interactionOnMove: !root.onRelease
        implicitHeight: Tk.padding.medium * 2
        radius: Tk.rounding.small
        value: root.frac
        onMoved: v => root.setFrac(v)
        WheelHandler { onWheel: e => root.setFrac(Math.max(0, Math.min(1, root.frac + (e.angleDelta.y > 0 ? 0.05 : -0.05)))) }
      }
    }
  }
}
