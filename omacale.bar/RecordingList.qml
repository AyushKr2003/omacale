import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Recordings list (Caelestia utilities/cards/RecordingList.qml): a header with
// an unfold toggle, then the newest recordings with play / folder / delete.
// Delete asks through the drawer's dialog (Utilities.qml).
ColumnLayout {
  id: root

  property var scope

  spacing: 0

  function label(name) {
    const m = name.match(/(\d{4})-(\d{2})-(\d{2})[_ T-](\d{2})[-:](\d{2})[-:](\d{2})/) || name.match(/(\d{4})(\d{2})(\d{2})_(\d{2})-(\d{2})-(\d{2})/)
    if (!m) return name.replace(/\.[^.]+$/, "")
    return "Recording at " + Sys.dateTime(new Date(+m[1], +m[2] - 1, +m[3], +m[4], +m[5], +m[6]))
  }
  // Caelestia closes the drawers before handing a recording to another app.
  function closeDrawers() {
    if (scope) { scope.utilities = false; scope.sidebar = false }
  }

  MouseArea {
    Layout.fillWidth: true
    implicitHeight: header.implicitHeight
    cursorShape: Qt.PointingHandCursor
    onClicked: RecordService.listExpanded = !RecordService.listExpanded

    RowLayout {
      id: header
      anchors.left: parent.left
      anchors.right: parent.right
      spacing: Tk.spacing.medium

      MIcon { Layout.alignment: Qt.AlignVCenter; text: "list"; size: Tk.iconSize.large }
      MText { Layout.alignment: Qt.AlignVCenter; Layout.fillWidth: true; text: "Recordings"; font.pointSize: Tk.body.medium }
      IconButton {
        type: "text"
        icon: RecordService.listExpanded ? "unfold_less" : "unfold_more"
        onClicked: RecordService.listExpanded = !RecordService.listExpanded
      }
    }
  }

  MListView {
    id: list
    Layout.fillWidth: true
    Layout.rightMargin: -Tk.spacing.small
    implicitHeight: (Tk.body.large + Tk.padding.small) * (RecordService.listExpanded ? 10 : 3)
    Behavior on implicitHeight { Anim {} }
    clip: true
    ScrollBar.vertical: MScrollBar { flickable: list }
    model: RecordService.recentRecordings

    delegate: RowLayout {
      id: rec
      required property var modelData

      anchors.left: parent ? parent.left : undefined
      anchors.right: parent ? parent.right : undefined
      anchors.rightMargin: Tk.spacing.small
      spacing: Tk.spacing.extraSmall

      MText {
        Layout.fillWidth: true
        Layout.rightMargin: Tk.spacing.extraSmall
        text: root.label(rec.modelData.name)
        color: Colours.m3onSurfaceVariant
        elide: Text.ElideRight
      }
      IconButton {
        type: "text"
        icon: "play_arrow"
        onClicked: { root.closeDrawers(); RecordService.play(rec.modelData.path) }
      }
      IconButton {
        type: "text"
        icon: "folder"
        onClicked: { root.closeDrawers(); RecordService.reveal(rec.modelData.path) }
      }
      IconButton {
        type: "text"
        icon: "delete_forever"
        inactiveOnColour: Colours.m3error
        onClicked: RecordService.confirmDelete = rec.modelData.path
      }
    }

    add: Transition { Anim { type: "effects"; property: "opacity"; from: 0; to: 1 } }
    remove: Transition { Anim { type: "effects"; property: "opacity"; to: 0 } }
    displaced: Transition {
      Anim { type: "effects"; property: "opacity"; to: 1 }
      Anim { property: "y" }
    }

    // Empty state: a large icon over the label when unfolded, a small one
    // beside it when folded.
    Loader {
      anchors.centerIn: parent
      opacity: list.count === 0 ? 1 : 0
      active: opacity > 0
      Behavior on opacity { Anim { type: "effects" } }

      sourceComponent: ColumnLayout {
        spacing: Tk.spacing.small

        MIcon {
          Layout.alignment: Qt.AlignHCenter
          text: "scan_delete"
          color: Colours.m3outline
          size: Tk.iconSize.extraLarge
          opacity: RecordService.listExpanded ? 1 : 0
          scale: RecordService.listExpanded ? 1 : 0
          Layout.preferredHeight: RecordService.listExpanded ? implicitHeight : 0
          Behavior on opacity { Anim { type: "effects" } }
          Behavior on scale { Anim {} }
          Behavior on Layout.preferredHeight { Anim {} }
        }

        RowLayout {
          spacing: Tk.spacing.medium

          MIcon {
            Layout.alignment: Qt.AlignHCenter
            text: "scan_delete"
            color: Colours.m3outline
            opacity: !RecordService.listExpanded ? 1 : 0
            scale: !RecordService.listExpanded ? 1 : 0
            Layout.preferredWidth: !RecordService.listExpanded ? implicitWidth : 0
            Behavior on opacity { Anim { type: "effects" } }
            Behavior on scale { Anim {} }
            Behavior on Layout.preferredWidth { Anim {} }
          }
          MText { text: "No recordings found"; color: Colours.m3outline }
        }
      }
    }
  }
}
