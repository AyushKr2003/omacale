import QtQuick
import "../.."

// One clipboard history row in the launcher: Omarchy's clipboard row (a
// thumbnail for images, the entry flattened to one line) laid out as the
// launcher's app rows are. `row` is a ClipboardHistory.js displayRows() row.
Item {
  id: root

  property var row: null
  readonly property bool hasThumb: !!row && row.previewImage !== ""

  Rectangle {
    id: thumb
    anchors.verticalCenter: parent.verticalCenter
    width: parent.height * 0.8
    height: width
    radius: Tk.rounding.small
    color: Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)
    clip: true

    Image {
      visible: root.hasThumb
      anchors.fill: parent
      source: root.hasThumb ? "file://" + root.row.previewImage : ""
      sourceSize.width: width * 2
      sourceSize.height: height * 2
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      smooth: true
    }
    MIcon {
      visible: !root.hasThumb
      anchors.centerIn: parent
      text: root.row && root.row.entryType === "file" ? "description" : "notes"
      size: Tk.iconSize.medium
      color: Colours.m3onSurfaceVariant
    }
  }

  Column {
    anchors.left: thumb.right
    anchors.leftMargin: Tk.spacing.medium
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter

    MText {
      width: parent.width
      text: root.row ? root.row.previewText : ""
      textFormat: Text.PlainText
      maximumLineCount: 1
      elide: Text.ElideRight
      font.pointSize: Tk.body.medium
    }
    MText {
      width: parent.width
      text: !root.row ? "" : root.row.entryType === "image" ? "Image · " + root.row.mime
        : root.row.entryType === "file" ? root.row.path || "Files"
        : "Text"
      color: Colours.m3outline
      elide: Text.ElideMiddle
    }
  }
}
