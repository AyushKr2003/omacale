import QtQuick
import QtQuick.Layouts

// Utilities drawer (Caelestia modules/utilities): keep-awake, screen recorder
// and quick toggles stacked, inset from the frame by padding.large. The drawer
// background itself is drawn by the shader in ScreenScope.
Item {
  id: root

  property var host
  property var scope
  property bool active: false

  // The frame already supplies `border` of the inset on the right and bottom.
  readonly property real edgePad: Math.max(0, Tk.padding.large - Tk.border)

  implicitHeight: col.implicitHeight + Tk.padding.large + edgePad

  ColumnLayout {
    id: col
    x: Tk.padding.large
    y: Tk.padding.large
    width: root.width - Tk.padding.large - root.edgePad
    spacing: Tk.spacing.medium

    IdleInhibitCard { Layout.fillWidth: true }
    RecordCard { Layout.fillWidth: true; z: 1 }
    QuickToggles {
      Layout.fillWidth: true
      host: root.host
      scope: root.scope
    }
  }
}
