import QtQuick
import QtQuick.Layouts
import "../.."

// Caelestia components/filedialog/DialogButtons.qml: the filter, Select and
// Cancel.
Rectangle {
  id: root

  required property var dialog
  required property Item folder

  implicitHeight: inner.implicitHeight + Tk.padding.medium * 2

  color: Colours.m3surfaceContainer

  RowLayout {
    id: inner

    anchors.fill: parent
    anchors.margins: Tk.padding.medium
    spacing: Tk.spacing.small

    MText {
      text: "Filter:"
    }

    Rectangle {
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

    Rectangle {
      color: Colours.m3surfaceContainerHigh
      radius: Tk.rounding.medium

      implicitWidth: selectText.implicitWidth + Tk.padding.medium * 2
      implicitHeight: selectText.implicitHeight + Tk.padding.medium * 2

      StateLayer {
        disabled: !root.dialog.selectionValid
        onClicked: root.dialog.accepted(root.folder.currentItem.file.path)
      }

      MText {
        id: selectText
        anchors.centerIn: parent
        text: "Select"
        color: root.dialog.selectionValid ? Colours.m3onSurface : Colours.m3outline
      }
    }

    Rectangle {
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
