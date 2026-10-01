import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import "../.."

// Utilities drawer (Caelestia modules/utilities): keep-awake, screen recorder
// and quick toggles stacked, inset from the frame by padding.large, with the
// recording delete dialog over them. The drawer background itself is drawn by
// the shader in ScreenScope.
Item {
  id: root

  property var host
  property var scope
  property bool active: false
  // The x scale of this drawer's deformation (ScreenScope's utilDeform).
  property real hStretch: 1

  // The frame already supplies `border` of the inset on the right and bottom
  // (left and bottom, with a right-hand bar).
  readonly property real edgePad: Math.max(0, Tk.padding.large - Tk.border)
  readonly property bool mirror: !!scope && scope.mirror
  // A bottom bar puts this drawer above the sidebar, against the top frame.
  readonly property bool flip: !!scope && scope.flipV
  readonly property var navRoots: [root]

  implicitHeight: col.implicitHeight + Tk.padding.large + edgePad

  ColumnLayout {
    id: col
    x: root.mirror ? root.edgePad : Tk.padding.large
    y: root.flip ? root.edgePad : Tk.padding.large
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

      // The scrim covers the drawer out to the frame's edges, and two fading
      // fillets carry it along the frame where the drawer's blob curves into
      // it, so the dim follows the blob's outline. Drawn for utilities in the
      // bottom-right corner (the frame on its right and bottom), and flipped
      // to wherever they are.
      Item {
        id: scrim
        anchors.fill: parent
        anchors.leftMargin: -Tk.padding.large - (root.mirror ? Tk.border : 0)
        anchors.rightMargin: -Tk.padding.large - (root.mirror ? 0 : Tk.border)
        anchors.topMargin: -Tk.padding.large - (root.flip ? Tk.border : 0)
        anchors.bottomMargin: -Tk.padding.large - (root.flip ? 0 : Tk.border)
        opacity: 0.5
        transform: Scale {
          origin.x: scrim.width / 2
          origin.y: scrim.height / 2
          xScale: root.mirror ? -1 : 1
          yScale: root.flip ? -1 : 1
        }
        readonly property real s: Tk.smoothing
        readonly property real t: Tk.border
        // How much wider the drawer's blob is than this, while it deforms.
        readonly property real stretch: (1 - root.hStretch) * width / 2

        Rectangle {
          anchors.fill: parent
          anchors.rightMargin: -scrim.stretch
          // The drawer's overshoot lifts it off the frame for a moment.
          anchors.bottomMargin: -parent.height * 0.1
          topLeftRadius: Tk.rounding.extraLarge
          color: Colours.m3scrim
        }

        Shape {
          anchors.fill: parent
          preferredRendererType: Shape.CurveRenderer

          // Along the bottom of the frame, left of the drawer.
          ShapePath {
            strokeWidth: 0
            startX: -scrim.s * 2
            startY: scrim.height - scrim.t
            fillGradient: LinearGradient {
              x1: -scrim.s * 2
              x2: 0
              GradientStop { position: 0; color: Qt.alpha(Colours.m3scrim, 0) }
              GradientStop { position: 1; color: Colours.m3scrim }
            }
            PathLine { relativeX: scrim.s; relativeY: 0 }
            PathCubic {
              relativeX: scrim.s; relativeY: -scrim.s
              relativeControl1X: scrim.s * 0.93; relativeControl1Y: -scrim.s * 0.07
              relativeControl2X: scrim.s * 0.93; relativeControl2Y: -scrim.s * 0.07
            }
            PathLine { relativeX: 0; relativeY: scrim.s + scrim.t }
            PathLine { relativeX: -scrim.s * 2; relativeY: 0 }
          }

          // Up the right of the frame, over the drawer.
          ShapePath {
            strokeWidth: 0
            startX: scrim.width - scrim.s - scrim.t + scrim.stretch
            startY: 0
            fillGradient: LinearGradient {
              y1: -scrim.s * 2
              y2: 0
              GradientStop { position: 0; color: Qt.alpha(Colours.m3scrim, 0) }
              GradientStop { position: 1; color: Colours.m3scrim }
            }
            PathCubic {
              relativeX: scrim.s; relativeY: -scrim.s
              relativeControl1X: scrim.s * 0.93; relativeControl1Y: -scrim.s * 0.07
              relativeControl2X: scrim.s * 0.93; relativeControl2Y: -scrim.s * 0.07
            }
            PathLine { relativeX: 0; relativeY: -scrim.s }
            PathLine { relativeX: scrim.t; relativeY: 0 }
            PathLine { relativeX: 0; relativeY: scrim.s * 2 }
          }
        }
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
