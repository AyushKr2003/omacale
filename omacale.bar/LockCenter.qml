import QtQuick
import QtQuick.Layouts
import Quickshell

// The middle column of the lock card (Caelestia modules/lock/Center.qml and
// its center/ components): the split clock, the date, the profile picture,
// the password field and the state message under it. Everything scales off
// the screen height, so a 1080p panel gets Caelestia's smaller layout.
ColumnLayout {
  id: root

  required property var lock

  // Caelestia reads the screen height here; ours comes from the surface,
  // which is zero for the first frame -- and a zero scale is a zero point
  // size, which Qt refuses.
  readonly property real centerScale: Math.min(1, (root.lock.height || 1440) / 1440)
  readonly property int centerWidth: Tk.sizes.lockCenterWidth * centerScale

  Layout.preferredWidth: centerWidth
  Layout.fillWidth: false
  Layout.fillHeight: true

  spacing: Tk.spacing.largeIncreased

  SystemClock {
    id: sysClock
    precision: SystemClock.Minutes
  }

  // ---------------------------------------------------------- the clock
  // Caelestia center/Clock.qml: hours over minutes, each trimmed to its tight
  // bounding box so the two sit flush, with the AM/PM pill beside the
  // minutes on a 12-hour clock.
  Item {
    id: clock

    Layout.alignment: Qt.AlignHCenter
    Layout.topMargin: Tk.padding.large

    function topOff(metrics) {
      return metrics.tightBoundingRect.y - metrics.boundingRect.y
    }

    implicitWidth: hours.implicitWidth + minutes.implicitWidth + Tk.spacing.small
    implicitHeight: hourMetrics.tightBoundingRect.height

    MText {
      id: hours

      y: -clock.topOff(hourMetrics)
      text: Sys.hour(sysClock.date)
      color: Colours.m3primary
      font.pointSize: Tk.headline.large * 7 * root.centerScale
      axes: ({ "ROND": 25, "wdth": 30 })

      TextMetrics {
        id: hourMetrics
        text: hours.text
        font: hours.font
      }
    }

    MText {
      id: minutes

      anchors.right: parent.right
      y: -clock.topOff(minuteMetrics)

      text: Qt.formatDateTime(sysClock.date, "mm")
      color: Colours.m3secondary
      font.pointSize: Tk.headline.large * (Sys.h12 ? 3.8 : 7) * root.centerScale
      axes: ({ "ROND": 25, "wdth": 30 })

      TextMetrics {
        id: minuteMetrics
        text: minutes.text
        font: minutes.font
      }
    }

    Loader {
      anchors.left: minutes.left
      anchors.leftMargin: minuteMetrics.tightBoundingRect.x
      y: hourMetrics.tightBoundingRect.height - implicitHeight

      active: Sys.h12
      asynchronous: true

      sourceComponent: Rectangle {
        color: Colours.m3surfaceContainerHigh
        radius: Tk.rounding.large

        implicitWidth: minuteMetrics.tightBoundingRect.width
        implicitHeight: amPmMetrics.tightBoundingRect.height + Tk.padding.large * 2

        MText {
          id: amPm

          anchors.centerIn: parent
          width: amPmMetrics.tightBoundingRect.width
          height: amPmMetrics.tightBoundingRect.height
          transform: Translate {
            x: -amPmMetrics.tightBoundingRect.x
            y: -clock.topOff(amPmMetrics)
          }

          text: Qt.formatDateTime(sysClock.date, "AP")
          color: Colours.m3onSurface
          font.pointSize: Tk.headline.small * 2 * root.centerScale
          axes: ({ "ROND": 25, "wdth": 30 })

          TextMetrics {
            id: amPmMetrics
            text: amPm.text
            font: amPm.font
          }
        }
      }
    }
  }

  MText {
    Layout.alignment: Qt.AlignHCenter

    text: Qt.formatDateTime(sysClock.date, "dddd • d MMM").toUpperCase()
    color: Colours.m3onSurface
    font.pointSize: Tk.title.medium
    weight: Font.DemiBold
  }

  // ---------------------------------------------------- profile picture
  // Caelestia center/ProfilePic.qml: ~/.face in a clam-shell shape, or a
  // person icon on the same shape when there is no picture.
  Item {
    id: profile

    Layout.alignment: Qt.AlignHCenter
    Layout.topMargin: Tk.spacing.extraLargeIncreased * root.centerScale
    Layout.bottomMargin: Tk.spacing.extraLarge * root.centerScale

    implicitWidth: Math.round(root.centerWidth * 0.7)
    implicitHeight: implicitWidth

    MShape {
      id: shape

      anchors.centerIn: parent
      implicitSize: profile.implicitWidth
      shape: "clamShell"
      color: Colours.m3surfaceContainerHighest
    }

    Item {
      anchors.fill: parent
      layer.enabled: true
      layer.effect: ShaderMaskEffect {
        maskItem: shape
      }

      Image {
        id: pfp

        anchors.fill: parent
        source: "file://" + Quickshell.env("HOME") + "/.face"
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: 512
        sourceSize.height: 512
        cache: false
      }

      MIcon {
        anchors.centerIn: parent
        visible: pfp.status !== Image.Ready
        text: "person"
        size: root.centerWidth / 4
        color: Colours.m3onSurfaceVariant
      }
    }
  }

  LockPassword {
    Layout.alignment: Qt.AlignHCenter
    centerScale: Math.max(0.8, root.centerScale)
    centerWidth: root.centerWidth
    lock: root.lock
  }

  LockMessage {
    Layout.fillWidth: true
    lock: root.lock
  }
}
