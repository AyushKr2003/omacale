import QtQuick
import QtQuick.Layouts
import "../../.."

// Caelestia StepperRow: [-] [value] [+] with joined inner corners.
ConnectedRect {
  id: root
  property var row
  property var settings
  readonly property real value: Number(Config.get(row.key))
  function step(d) { Config.set(row.key, Math.max(row.from, Math.min(row.to, value + d * (row.step || 1)))) }

  implicitHeight: Math.max(lbl.implicitHeight, spin.implicitHeight) + Tk.padding.medium * 2

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: Tk.padding.largeIncreased
    anchors.rightMargin: Tk.padding.largeIncreased
    spacing: Tk.spacing.medium
    RowLabel { id: lbl; Layout.fillWidth: true; text: root.row.label; subtext: root.row.where ? root.row.where + (root.row.subtext ? " · " + root.row.subtext : "") : (root.row.subtext || "") }
    Row {
      id: spin
      spacing: Tk.spacing.extraSmall / 2
      component Btn: Rectangle {
        id: b
        property string icon
        property bool leftSide
        property bool disabled
        readonly property alias pressed: st.pressed
        signal clicked()
        // Caelestia StyledSpinBox: IconButton (text type) with extraSmall padding.
        height: { const h = ic.implicitHeight + Tk.padding.extraSmall * 2; return h % 2 ? h + 1 : h }
        width: height
        color: disabled ? Qt.alpha(Colours.m3surfaceContainerHighest, 0.4) : Colours.m3surfaceContainerHighest
        topLeftRadius: leftSide ? height / 2 : (st.pressed ? Tk.rounding.small : Tk.rounding.extraSmall)
        bottomLeftRadius: topLeftRadius
        topRightRadius: leftSide ? (st.pressed ? Tk.rounding.small : Tk.rounding.extraSmall) : height / 2
        bottomRightRadius: topRightRadius
        Behavior on topLeftRadius { Anim { type: "effects" } }
        Behavior on topRightRadius { Anim { type: "effects" } }
        StateLayer { id: st; disabled: b.disabled }
        MIcon { id: ic; anchors.centerIn: parent; anchors.verticalCenterOffset: 1; anchors.horizontalCenterOffset: st.pressed ? 0 : (b.leftSide ? 2 : -2); text: b.icon; size: Tk.iconSize.medium; color: b.disabled ? Qt.alpha(Colours.m3onSurface, 0.38) : Colours.m3onSurfaceVariant
          Behavior on anchors.horizontalCenterOffset { Anim { type: "effects" } } }
      }
      // Held buttons repeat, speeding up (Caelestia repeatRate 400, decay 50).
      Timer {
        id: repeat
        running: down.pressed || up.pressed
        onRunningChanged: if (!running) interval = 400
        interval: 400
        repeat: true
        triggeredOnStart: true
        onTriggered: {
          root.step(up.pressed ? 1 : -1)
          if (interval > 50) interval -= 50
        }
      }
      Btn { id: down; icon: "remove"; leftSide: true; disabled: root.value <= root.row.from }
      Rectangle {
        width: 65; height: down.height
        radius: Tk.rounding.extraSmall
        color: Colours.m3surfaceContainerHighest
        MTextField {
          anchors.fill: parent
          horizontalAlignment: TextInput.AlignHCenter
          verticalAlignment: TextInput.AlignVCenter
          text: String(root.value)
          font.pointSize: Tk.body.small
          validator: IntValidator { bottom: root.row.from; top: root.row.to }
          onEditingFinished: Config.set(root.row.key, Math.max(root.row.from, Math.min(root.row.to, parseInt(text) || root.row.from)))
        }
        WheelHandler { onWheel: e => root.step(e.angleDelta.y > 0 ? 1 : -1) }
      }
      Btn { id: up; icon: "add"; disabled: root.value >= root.row.to }
    }
  }
}
