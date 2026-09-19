import QtQuick
import QtQuick.Layouts

// Caelestia ToggleRow. Bound to a Config key when `row.key` is set; otherwise
// drive `checked` and handle `toggled` (Wi-Fi, Bluetooth, ...).
ConnectedRect {
  id: root
  property var row: ({})
  property var settings
  property string text: row.label || ""
  property string subtext: row.where ? row.where + (row.subtext ? " · " + row.subtext : "") : (row.subtext || "")
  // `row.invert` shows a key the other way round (12-hour clock on = clock24 off).
  property bool checked: row.key ? !!Config.get(row.key) !== !!row.invert : false
  property bool disabled: false
  property real labelSize: Tk.body.small
  signal toggled(bool checked)

  function flip(c) {
    if (root.disabled) return
    if (root.row.key) Config.set(root.row.key, root.row.invert ? !c : c)
    root.toggled(c)
  }

  implicitHeight: Math.max(lbl.implicitHeight, sw.implicitHeight) + Tk.padding.medium * 2

  StateLayer {
    id: rowState
    disabled: root.disabled
    onClicked: root.flip(!root.checked)
  }
  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: Tk.padding.largeIncreased
    anchors.rightMargin: Tk.padding.largeIncreased
    spacing: Tk.spacing.medium
    RowLabel { id: lbl; Layout.fillWidth: true; text: root.text; subtext: root.subtext; textSize: root.labelSize }
    MSwitch { id: sw; checked: root.checked; disabled: root.disabled; pressOverride: rowState.pressed; hoverOverride: rowState.containsMouse; onToggled: c => root.flip(c) }
  }
}
