import QtQuick
import QtQuick.Layouts

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
  function setFrac(f) {
    const s = row.step || 0.01
    let v = row.from + f * (row.to - row.from)
    v = Math.round(v / s) * s
    Config.set(row.key, Number(v.toFixed(4)))
  }

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
        MText { text: root.fmt(root.value); color: Colours.m3outline }
      }
      MSlider {
        Layout.fillWidth: true
        implicitHeight: Tk.padding.medium * 2
        radius: Tk.rounding.small
        value: root.frac
        onMoved: v => root.setFrac(v)
        WheelHandler { onWheel: e => root.setFrac(Math.max(0, Math.min(1, root.frac + (e.angleDelta.y > 0 ? 0.05 : -0.05)))) }
      }
    }
  }
}
