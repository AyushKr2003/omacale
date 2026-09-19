import QtQuick
import QtQuick.Layouts

// Utilities drawer (Caelestia modules/utilities): keep-awake, screen recorder
// and quick toggles stacked, inset from the frame by padding.large, with the
// recording delete dialog over them. The drawer background itself is drawn by
// the shader in ScreenScope.
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
    RecordCard {
      Layout.fillWidth: true
      z: 1
      host: root.host
      scope: root.scope
    }
    QuickToggles {
      Layout.fillWidth: true
      host: root.host
      scope: root.scope
    }
  }

  // Caelestia utilities/RecordingDeleteModal.qml: a scrim over the whole
  // drawer and a dialog that scales in. Clicking the scrim cancels.
  Loader {
    anchors.fill: col
    z: 2
    opacity: RecordService.confirmDelete ? 1 : 0
    active: opacity > 0
    Behavior on opacity { Anim { type: "effects" } }

    sourceComponent: MouseArea {
      id: modal
      property string path
      Component.onCompleted: path = RecordService.confirmDelete

      hoverEnabled: true
      onClicked: RecordService.confirmDelete = ""

      Rectangle {
        anchors.fill: parent
        anchors.margins: -Tk.padding.large
        anchors.rightMargin: -Tk.padding.large - Tk.border
        anchors.bottomMargin: -Tk.padding.large - Tk.border
        topLeftRadius: Tk.rounding.extraLarge
        color: Colours.m3scrim
        opacity: 0.5
      }

      Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width - Tk.padding.extraLargeIncreased, implicitWidth)
        implicitWidth: dialog.implicitWidth + Tk.padding.extraExtraLarge
        implicitHeight: dialog.implicitHeight + Tk.padding.extraExtraLarge
        radius: Tk.rounding.extraLarge
        color: Colours.palette.m3surfaceContainerHigh

        scale: 0
        Component.onCompleted: scale = Qt.binding(() => RecordService.confirmDelete ? 1 : 0)
        Behavior on scale { Anim {} }

        // Swallow clicks so they don't reach the scrim.
        MouseArea { anchors.fill: parent }

        Elevation {
          anchors.fill: parent
          radius: parent.radius
          z: -1
          level: 3
        }

        ColumnLayout {
          id: dialog
          anchors.fill: parent
          anchors.margins: Tk.padding.large * 1.5
          spacing: Tk.spacing.medium

          MText {
            text: "Delete recording?"
            font.pointSize: Tk.body.large
          }

          MText {
            Layout.fillWidth: true
            text: "Recording '" + modal.path + "' will be permanently deleted."
            color: Colours.m3onSurfaceVariant
            font.pointSize: Tk.body.small
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
          }

          RowLayout {
            Layout.topMargin: Tk.spacing.medium
            Layout.alignment: Qt.AlignRight
            spacing: Tk.spacing.medium

            IconTextButton {
              type: "text"
              text: "Cancel"
              fontSize: Tk.body.small
              onClicked: RecordService.confirmDelete = ""
            }
            IconTextButton {
              type: "text"
              text: "Delete"
              fontSize: Tk.body.small
              onClicked: {
                RecordService.remove(RecordService.confirmDelete)
                RecordService.confirmDelete = ""
              }
            }
          }
        }
      }
    }
  }
}
