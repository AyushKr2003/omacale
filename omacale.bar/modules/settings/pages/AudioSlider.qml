import QtQuick
import QtQuick.Layouts
import "../../.."

// Caelestia nexus/common/SliderRow.qml: icon, label and value on top, a
// slider underneath. Unlike RowSlider it isn't tied to a Config key.
ConnectedRect {
  id: root
  property string icon
  property string label
  property real value
  property bool muted: false
  signal moved(real value)

  // Caelestia services.audioIncrement
  readonly property real step: Config.o.services.volumeStep / 100

  Layout.fillWidth: true
  implicitHeight: rl.implicitHeight + Tk.padding.largeIncreased + Tk.padding.large

  RowLayout {
    id: rl
    anchors.fill: parent
    anchors.margins: Tk.padding.largeIncreased
    anchors.topMargin: Tk.padding.large
    spacing: Tk.spacing.medium

    MIcon { text: root.icon; size: Tk.iconSize.medium; color: Colours.m3onSurfaceVariant }
    ColumnLayout {
      Layout.fillWidth: true
      spacing: Tk.spacing.medium
      RowLayout {
        Layout.fillWidth: true
        spacing: Tk.spacing.small
        MText { Layout.fillWidth: true; text: root.label; elide: Text.ElideRight }
        MText { text: Math.round(root.value * 100) + "%"; color: Colours.m3outline }
      }
      MSlider {
        Layout.fillWidth: true
        implicitHeight: Tk.padding.medium * 2
        radius: Tk.rounding.small
        value: root.value
        opacity: root.muted ? 0.5 : 1
        Behavior on opacity { Anim { type: "effects" } }
        onMoved: v => root.moved(v)
        WheelHandler {
          onWheel: e => {
            if (e.angleDelta.y > 0) root.moved(Math.min(1, root.value + root.step))
            else if (e.angleDelta.y < 0) root.moved(Math.max(0, root.value - root.step))
          }
        }
      }
    }
  }
}
