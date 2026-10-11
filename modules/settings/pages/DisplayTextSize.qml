import QtQuick
import QtQuick.Layouts
import "../../.."

// Settings › Display › Text and cursor: Omarchy's text size (the shell, GTK
// and the terminal together, `omarchy-display-text-size`).
ConnectedRect {
  id: root
  property var row
  property var settings
  Component.onCompleted: DisplayService.hold()
  Component.onDestruction: DisplayService.release()

  implicitHeight: tl.implicitHeight + Tk.padding.medium * 2
  RowLayout {
    id: tl
    anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: Tk.padding.largeIncreased; anchors.rightMargin: Tk.padding.medium
    spacing: Tk.spacing.medium
    MIcon { text: "format_size"; size: Tk.iconSize.medium; color: Colours.m3onSurfaceVariant }
    RowLabel { Layout.fillWidth: true; text: "Text size"; subtext: "Omarchy's text size for the shell, GTK and the terminal" }
    IconButton { type: "text"; icon: "remove"; disabled: DisplayService.textSize <= 9; onClicked: DisplayService.setTextSize(DisplayService.textSize - 1) }
    MText { Layout.preferredWidth: Tk.px(48); horizontalAlignment: Text.AlignHCenter; text: DisplayService.textSize ? DisplayService.textSize + " px" : "–" }
    IconButton { type: "text"; icon: "add"; disabled: DisplayService.textSize >= 20; onClicked: DisplayService.setTextSize(DisplayService.textSize + 1) }
  }
}
