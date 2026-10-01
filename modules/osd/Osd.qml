import QtQuick
import QtQuick.Layouts
import "../.."

// Caelestia modules/osd/Content.qml: the volume, microphone and brightness
// sliders. Only the content; the drawer behind it is ScreenScope's r9.
// Wheel over a slider steps it, as Caelestia's CustomMouseArea does.
Item {
  id: root

  // With a right-hand bar the drawer comes out of the left edge, so the frame
  // is on the other side of it.
  property bool mirror: false
  // Caelestia hides the microphone while the session menu holds the space,
  // when brightness is shown too.
  property bool sessionOpen: false
  readonly property var cfg: Config.o.osd

  // Caelestia's anchors.horizontalCenterOffset: half of what the frame
  // border leaves of the large padding, towards the frame (the border is
  // part of the same blob, so it counts as padding on that side).
  readonly property real offset: Math.max(0, Math.min(Tk.padding.large, Tk.padding.large - Tk.border)) / 2

  implicitWidth: layout.implicitWidth + Tk.padding.large + offset * 2
  implicitHeight: layout.implicitHeight + Tk.padding.large * 2

  ColumnLayout {
    id: layout

    anchors.centerIn: parent
    anchors.horizontalCenterOffset: root.mirror ? -root.offset : root.offset
    spacing: Tk.spacing.medium

    // Speaker volume
    SliderArea {
      onStep: d => OsdService.stepVolume(d)

      FilledSlider {
        anchors.fill: parent

        icon: AudioService.volumeIcon(value, OsdService.muted)
        value: OsdService.volume
        onMoved: OsdService.setVolume(value)
      }
    }

    // Microphone volume
    WrappedLoader {
      shouldBeActive: root.cfg.enableMicrophone && (!root.brightnessShown || !root.sessionOpen)

      sourceComponent: SliderArea {
        onStep: d => OsdService.stepSourceVolume(d)

        FilledSlider {
          anchors.fill: parent

          icon: AudioService.micIcon(value, OsdService.sourceMuted)
          value: OsdService.sourceVolume
          onMoved: OsdService.setSourceVolume(value)
        }
      }
    }

    // Brightness
    WrappedLoader {
      shouldBeActive: root.brightnessShown

      sourceComponent: SliderArea {
        onStep: d => OsdService.stepBrightness(d)

        FilledSlider {
          anchors.fill: parent

          icon: "brightness_" + (Math.round(value * 6) + 1)
          value: OsdService.brightness
          onMoved: OsdService.setBrightness(value)
        }
      }
    }
  }

  readonly property bool brightnessShown: cfg.enableBrightness && OsdService.hasBrightness

  component SliderArea: MouseArea {
    signal step(int direction)

    implicitWidth: Tk.sizes.osdSliderWidth
    implicitHeight: Tk.sizes.osdSliderHeight
    acceptedButtons: Qt.NoButton
    onWheel: e => {
      if (e.angleDelta.y > 0)
        step(1)
      else if (e.angleDelta.y < 0)
        step(-1)
    }
  }

  component WrappedLoader: Loader {
    required property bool shouldBeActive

    asynchronous: true
    Layout.preferredWidth: Tk.sizes.osdSliderWidth
    Layout.preferredHeight: shouldBeActive ? Tk.sizes.osdSliderHeight : 0
    opacity: shouldBeActive ? 1 : 0
    active: opacity > 0
    visible: active

    Behavior on Layout.preferredHeight {
      Anim {
        type: "emphasized"
      }
    }

    Behavior on opacity {
      Anim {
        type: "effects"
      }
    }
  }
}
