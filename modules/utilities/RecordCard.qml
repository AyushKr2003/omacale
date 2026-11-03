import QtQuick
import QtQuick.Layouts
import "../.."

// Screen recorder card (Caelestia utilities/cards/Record.qml): a badge, title
// and a split Record button whose menu picks the mode; below it the recordings
// list, or, while recording, a REC pill, the elapsed time and a stop button.
GlassCard {
  id: root

  property var host
  property var scope

  // 0 = Recording, 1 = Screenshot (Omarchy's menu › Capture, less Screenrecord).
  property int tab: 0
  property string shot: "screenshot"
  readonly property var shots: [
    { icon: "screenshot_region", text: "Screenshot", activeText: "Screenshot", value: "screenshot" },
    { icon: "text_fields", text: "Text", activeText: "Text", value: "text" },
    { icon: "qr_code_scanner", text: "QR Code", activeText: "QR Code", value: "qr" },
    { icon: "colorize", text: "Color", activeText: "Color", value: "color" }
  ]
  readonly property var shotCmds: ({
    screenshot: "omarchy-capture-screenshot", text: "omarchy-capture-text",
    qr: "omarchy-capture-qr", color: "pkill hyprpicker || hyprpicker -a"
  })
  function takeShot() {
    // They draw their own overlay, so get the drawers out of the shot.
    if (scope) { scope.utilities = false; scope.sidebar = false }
    RecordService.capture(shotCmds[shot])
  }

  implicitHeight: layout.implicitHeight + Tk.padding.large * 2
  radius: Tk.rounding.large
  fill: Colours.m3surfaceContainer

  Component.onCompleted: RecordService.reloadRecordings()

  ColumnLayout {
    id: layout
    anchors.fill: parent
    anchors.margins: Tk.padding.large
    spacing: Tk.spacing.medium

    RowLayout {
      id: btnLayout
      spacing: Tk.spacing.medium
      // This card's mode menu is the one SplitSelect that opens downwards, so
      // the row has to paint over the recordings list it drops onto.
      z: 1

      Rectangle {
        implicitWidth: implicitHeight
        implicitHeight: { const h = icon.implicitHeight + Tk.padding.small * 2; return h - (h % 2) }
        radius: Tk.rounding.full
        color: RecordService.running ? Colours.m3secondary : Colours.m3secondaryContainer
        Behavior on color { CAnim {} }

        MIcon {
          id: icon
          anchors.centerIn: parent
          anchors.verticalCenterOffset: 1
          text: root.tab === 0 ? "screen_record" : "screenshot_monitor"
          size: Tk.iconSize.large
          color: RecordService.running ? Colours.m3onSecondary : Colours.m3onSecondaryContainer
          Behavior on color { CAnim {} }
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        MText {
          Layout.fillWidth: true
          text: root.tab === 0 ? "Screen recorder" : "Screenshot"
          font.pointSize: Tk.body.medium
          elide: Text.ElideRight
        }
        MText {
          Layout.fillWidth: true
          text: root.tab === 0 && RecordService.running ? "Running..." : "Ready"
          color: Colours.m3onSurfaceVariant
          font.pointSize: Tk.body.small
          elide: Text.ElideRight
          animate: true
        }
      }

      SplitSelect {
        visible: root.tab === 0
        filled: true
        mainClickable: true
        menuOnTop: false
        disabled: RecordService.running
        current: RecordService.source
        // Omarchy's menu › Capture › Screenrecord, entry for entry.
        items: [
          { icon: "volume_off", text: "No audio", activeText: "Record", value: "none" },
          { icon: "volume_up", text: "Desktop audio", activeText: "Record", value: "desktop" },
          { icon: "mic", text: "Desktop + mic", activeText: "Record", value: "mic" }
        ].concat(RecordService.hasWebcam ? [
          { icon: "videocam", text: "Desktop + mic + webcam", activeText: "Record", value: "webcam" }
        ] : [])
        onSelected: v => {
          RecordService.source = v
          // Caelestia's menu items each start their recording (Record.qml).
          RecordService.start()
        }
        onMainClicked: RecordService.start()
      }

      // Screenshot tab: the same split button over Omarchy's Capture entries.
      SplitSelect {
        visible: root.tab === 1
        filled: true
        mainClickable: true
        menuOnTop: false
        current: root.shot
        items: root.shots
        onSelected: v => { root.shot = v; root.takeShot() }
        onMainClicked: root.takeShot()
      }
    }

    // The two tabs, Caelestia's tonal/text button pair.
    RowLayout {
      Layout.alignment: Qt.AlignLeft
      spacing: Tk.spacing.small

      Repeater {
        model: [{ icon: "screen_record", text: "Record" }, { icon: "screenshot_monitor", text: "Screenshot" }]
        IconTextButton {
          required property var modelData
          required property int index
          isRound: true
          shapeMorph: true
          type: root.tab === index ? "tonal" : "text"
          icon: modelData.icon
          text: modelData.text
          fontSize: Tk.body.small
          onClicked: root.tab = index
        }
      }
    }

    // Caelestia fades the old content out, swaps it, then animates the
    // height for a moment while the new content fades in.
    Loader {
      id: listOrControls
      property bool running: RecordService.running

      Layout.fillWidth: true
      Layout.preferredHeight: implicitHeight
      sourceComponent: root.tab === 1 ? screenshots : running ? controls : recordings
      clip: Layout.preferredHeight < implicitHeight

      Behavior on Layout.preferredHeight {
        id: locHeightAnim
        enabled: false
        Anim {}
      }

      Behavior on running {
        SequentialAnimation {
          Anim { target: listOrControls; property: "opacity"; to: 0; type: "effects" }
          PropertyAction { target: locHeightAnim; property: "enabled"; value: true }
          PropertyAction {}
          ParallelAnimation {
            SequentialAnimation {
              PauseAnimation { duration: 100 }
              PropertyAction { target: locHeightAnim; property: "enabled"; value: false }
            }
            Anim { target: listOrControls; property: "opacity"; to: 1; type: "slowEffects" }
          }
        }
      }
    }
  }

  Component { id: screenshots; ScreenshotList { scope: root.scope } }
  Component { id: recordings; RecordingList { scope: root.scope } }

  Component {
    id: controls

    RowLayout {
      spacing: Tk.spacing.medium

      Rectangle {
        radius: Tk.rounding.full
        color: Colours.m3error
        implicitWidth: recText.implicitWidth + Tk.padding.medium * 2
        implicitHeight: recText.implicitHeight + Tk.padding.large

        MText {
          id: recText
          anchors.centerIn: parent
          animate: true
          text: "REC"
          color: Colours.m3onError
          font.family: Tk.mono
          font.pointSize: Tk.label.medium
        }

        SequentialAnimation on opacity {
          running: true
          loops: Animation.Infinite
          Anim { from: 1; to: 0; duration: Tk.durations.large; easing.bezierCurve: Tk.curves.emphasizedAccel }
          Anim { from: 0; to: 1; duration: Tk.durations.extraLarge; easing.bezierCurve: Tk.curves.emphasizedDecel }
        }
      }

      MText {
        Layout.fillWidth: true
        text: {
          const e = RecordService.elapsed
          const h = Math.floor(e / 3600), m = Math.floor((e % 3600) / 60)
          const s = String(Math.floor(e % 60)).padStart(2, "0")
          return "Recording for " + (h > 0 ? h + ":" + String(m).padStart(2, "0") + ":" + s : m + ":" + s)
        }
        font.pointSize: Tk.body.medium
        elide: Text.ElideMiddle
      }

      ButtonRow {
        spacing: Tk.spacing.extraSmall
        IconButton {
          shapeMorph: true
          round: true
          icon: "stop"
          inactiveColour: Colours.m3error
          inactiveOnColour: Colours.m3onError
          implicitWidth: implicitHeight + Tk.padding.small * 2
          onClicked: RecordService.stop()
        }
      }
    }
  }
}
