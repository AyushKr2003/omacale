import QtQuick
import QtQuick.Layouts

// Screen recorder card (Caelestia utilities/cards/Record.qml): a badge, title
// and a split Record button whose menu picks the mode; below it the recordings
// list, or, while recording, a REC pill, the elapsed time and a stop button.
Rectangle {
  id: root

  property var host
  property var scope

  readonly property string modeValue: (RecordService.mode === "region" ? "region" : "fullscreen") + (RecordService.withAudio ? "-audio" : "")

  implicitHeight: layout.implicitHeight + Tk.padding.large * 2
  radius: Tk.rounding.large
  color: Colours.m3surfaceContainer
  Behavior on implicitHeight { Anim {} }

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
          text: "screen_record"
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
          text: "Screen recorder"
          font.pointSize: Tk.body.medium
          elide: Text.ElideRight
        }
        MText {
          Layout.fillWidth: true
          text: RecordService.running ? "Running..." : "Ready"
          color: Colours.m3onSurfaceVariant
          font.pointSize: Tk.body.small
          elide: Text.ElideRight
          animate: true
        }
      }

      SplitSelect {
        filled: true
        horizontalPadding: Tk.padding.medium
        mainClickable: true
        menuOnTop: false
        disabled: RecordService.running
        current: root.modeValue
        items: [
          { icon: "fullscreen", text: "Record fullscreen", activeText: "Fullscreen", value: "fullscreen" },
          { icon: "screenshot_region", text: "Record region", activeText: "Region", value: "region" },
          { icon: "select_to_speak", text: "Record fullscreen with sound", activeText: "Fullscreen", value: "fullscreen-audio" },
          { icon: "volume_up", text: "Record region with sound", activeText: "Region", value: "region-audio" }
        ]
        onSelected: v => {
          RecordService.mode = v.indexOf("region") === 0 ? "region" : "fullscreen"
          RecordService.withAudio = v.indexOf("-audio") !== -1
        }
        onMainClicked: RecordService.start()
      }
    }

    // Caelestia fades the old content out, swaps it, then animates the
    // height for a moment while the new content fades in.
    Loader {
      id: listOrControls
      property bool running: RecordService.running

      Layout.fillWidth: true
      Layout.preferredHeight: implicitHeight
      sourceComponent: running ? controls : recordings
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
