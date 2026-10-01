import QtQuick
import QtQuick.Layouts
import "../.."

// One clipboard history row in the launcher, after Caelestia PR #1298's
// items/ClipboardItem.qml: a plain icon, the entry on one line dimmed until
// the row is selected, its size under it, and a delete button. Image rows
// keep a thumbnail in place of the icon; the PR's pin button is left out
// (Omarchy's history has no pins). `row` is a ClipboardHistory.js
// displayRows() row.
Item {
  id: root

  property var row: null
  property bool current: false
  signal deleteRequested()

  readonly property bool hasThumb: !!row && row.previewImage !== ""
  readonly property string detail: {
    if (!row) return ""
    if (row.entryType === "image") return "Image · " + row.mime
    if (row.entryType === "file") return row.path || row.previewText
    const text = row.fullText
    const words = text.trim() ? text.trim().split(/\s+/).length : 0
    // displayRows caps the text it keeps; past that the counts are a floor.
    const more = text.length >= 8192 ? "+" : ""
    return text.length + more + " characters, " + words + more + " words"
  }

  RowLayout {
    anchors.fill: parent
    spacing: Tk.spacing.medium

    // One slot width for the icon and the thumbnail, so every row's text
    // starts at the same place.
    Item {
      Layout.preferredWidth: root.height
      Layout.fillHeight: true

      MIcon {
        id: icon
        visible: !root.hasThumb
        anchors.centerIn: parent
        text: root.row && root.row.entryType === "file" ? "draft" : "description"
        size: Tk.iconSize.large
        color: Colours.m3onSurfaceVariant
      }

      Rectangle {
        visible: root.hasThumb
        anchors.fill: parent
        radius: Tk.rounding.small
        color: Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)
        clip: true

        Image {
          anchors.fill: parent
          source: root.hasThumb ? "file://" + root.row.previewImage : ""
          sourceSize.width: width * 2
          sourceSize.height: height * 2
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          smooth: true
        }
      }
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: Tk.spacing.extraSmall

      MText {
        Layout.fillWidth: true
        text: root.row ? root.row.previewText : ""
        textFormat: Text.PlainText
        maximumLineCount: 1
        elide: Text.ElideRight
        font.pointSize: Tk.body.medium
        color: root.current ? Colours.m3onSurface : Colours.m3onSurfaceVariant
        Behavior on color { CAnim {} }
      }
      MText {
        Layout.fillWidth: true
        text: root.detail
        elide: Text.ElideMiddle
        font.pointSize: Tk.label.medium
        color: Colours.m3onSurfaceVariant
      }
    }

    IconButton {
      Layout.alignment: Qt.AlignVCenter
      type: "text"
      icon: "delete"
      padding: Tk.padding.small
      onClicked: root.deleteRequested()
    }
  }
}
