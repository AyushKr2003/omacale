import QtQuick
import QtQuick.Layouts
import "../.."

// Caelestia modules/utilities/toasts/ToastItem.qml: one toast, coloured by
// its type (info on the surface, success, warning in secondary, error).
Rectangle {
  id: root

  required property var modelData

  readonly property int type: modelData ? modelData.type : 0
  readonly property bool isSuccess: type === Toaster.success
  readonly property bool isWarning: type === Toaster.warning
  readonly property bool isError: type === Toaster.error
  readonly property color onColour: isSuccess ? Colours.m3onSuccessContainer
    : isWarning ? Colours.m3onSecondary
    : isError ? Colours.m3onErrorContainer
    : Colours.m3onSurface

  anchors.left: parent.left
  anchors.right: parent.right
  implicitHeight: layout.implicitHeight + Tk.padding.large

  radius: Tk.rounding.large
  color: isSuccess ? Colours.m3successContainer
    : isWarning ? Colours.m3secondary
    : isError ? Colours.m3errorContainer
    : Colours.m3surface

  border.width: 1
  border.color: Qt.alpha(isSuccess ? Colours.m3success
    : isWarning ? Colours.m3secondaryContainer
    : isError ? Colours.m3error
    : Colours.m3outlineVariant, 0.3)

  Elevation {
    anchors.fill: parent
    radius: parent.radius
    opacity: parent.opacity
    z: -1
    level: 3
  }

  RowLayout {
    id: layout

    anchors.fill: parent
    anchors.margins: Tk.padding.small
    anchors.leftMargin: Tk.padding.medium
    anchors.rightMargin: Tk.padding.medium
    spacing: Tk.spacing.medium

    Rectangle {
      radius: Tk.rounding.large
      color: root.isSuccess ? Colours.m3success
        : root.isWarning ? Colours.m3secondaryContainer
        : root.isError ? Colours.m3error
        : Colours.m3surfaceContainerHigh

      implicitWidth: implicitHeight
      implicitHeight: icon.implicitHeight + Tk.padding.large

      MIcon {
        id: icon

        anchors.centerIn: parent
        text: root.modelData ? root.modelData.iconName : ""
        color: root.isSuccess ? Colours.m3onSuccess
          : root.isWarning ? Colours.m3onSecondaryContainer
          : root.isError ? Colours.m3onError
          : Colours.m3onSurfaceVariant
        // Caelestia's icon.large scaled by 1.2.
        size: Tk.iconPt(24 * 1.2)
      }
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: 0

      MText {
        Layout.fillWidth: true
        text: root.modelData ? root.modelData.title : ""
        color: root.onColour
        font.pointSize: Tk.title.small
        weight: Font.Medium
        elide: Text.ElideRight
      }

      MText {
        Layout.fillWidth: true
        textFormat: Text.StyledText
        text: root.modelData ? root.modelData.message : ""
        color: root.onColour
        opacity: 0.8
        elide: Text.ElideRight
      }
    }
  }

  Behavior on border.color {
    CAnim {}
  }
}
