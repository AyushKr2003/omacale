import QtQuick
import QtQuick.Layouts
import "../.."

// Caelestia components/filedialog/DialogButtons.qml: the filter, Select and
// Cancel.
Rectangle {
  id: root

  required property var dialog

  implicitHeight: inner.implicitHeight + Tk.padding.medium * 2

  color: Colours.m3surfaceContainer

  RowLayout {
    id: inner

    anchors.fill: parent
    anchors.margins: Tk.padding.medium
    spacing: Tk.spacing.small

    MText {
      visible: !root.dialog.selectFolder
      text: "Filter:"
    }

    Rectangle {
      visible: !root.dialog.selectFolder
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.rightMargin: Tk.spacing.medium

      color: Colours.m3surfaceContainerHigh
      radius: Tk.rounding.medium

      MText {
        anchors.fill: parent
        anchors.margins: Tk.padding.medium
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        text: root.dialog.filterLabel + " (" + root.dialog.filters.map(f => "*." + f).join(", ") + ")"
      }
    }

    Item { visible: root.dialog.selectFolder; Layout.fillWidth: true }

    Rectangle {
      objectName: "fileDialogSelect"
      color: Colours.m3surfaceContainerHigh
      radius: Tk.rounding.medium

      implicitWidth: selectText.implicitWidth + Tk.padding.medium * 2
      implicitHeight: selectText.implicitHeight + Tk.padding.medium * 2

      StateLayer {
        disabled: !root.dialog.selectionValid
        onClicked: root.dialog.accepted(root.dialog.selectedPath)
      }

      MText {
        id: selectText
        anchors.centerIn: parent
        text: root.dialog.selectFolder ? "Select folder" : "Select"
        color: root.dialog.selectionValid ? Colours.m3onSurface : Colours.m3outline
      }
    }

    Rectangle {
      objectName: "fileDialogCancel"
      color: Colours.m3surfaceContainerHigh
      radius: Tk.rounding.medium

      implicitWidth: cancelText.implicitWidth + Tk.padding.medium * 2
      implicitHeight: cancelText.implicitHeight + Tk.padding.medium * 2

      StateLayer {
        onClicked: root.dialog.rejected()
      }

      MText {
        id: cancelText
        anchors.centerIn: parent
        text: "Cancel"
      }
    }
  }
}
