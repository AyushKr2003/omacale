import QtQuick
import QtQuick.Layouts
import "../../.."
import "../../../services/DisplayModel.js" as Model

// Settings › Display › Profiles: hyprmoncfg's saved layouts. Apply tries one
// for 30 seconds behind the keep-or-revert card (DisplayService.applyProfile);
// hyprmoncfg does the saving and deleting. Shown only while it manages the
// displays. No Caelestia original; Nexus rows, as the rest of the page.
ColumnLayout {
  id: root
  property var row
  property var settings
  property bool first
  property bool last
  spacing: Tk.spacing.extraSmall / 2
  Component.onCompleted: DisplayService.hold()
  Component.onDestruction: DisplayService.release()

  property string confirmDelete: ""       // the profile whose Delete waits for a second click
  readonly property bool busy: DisplayService.profileBusy || DisplayService.previewBusy


  // hyprmoncfg's answer to the last request (a profile that can't be
  // applied, say), here as well as at the top of the page, out of view.
  ConnectedRect {
    Layout.fillWidth: true
    first: true
    last: true
    Layout.bottomMargin: Tk.spacing.small
    visible: DisplayService.lastError !== ""
    implicitHeight: el.implicitHeight + Tk.padding.medium * 2
    RowLayout {
      id: el
      anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Tk.padding.largeIncreased; anchors.rightMargin: Tk.padding.largeIncreased
      spacing: Tk.spacing.medium
      MIcon { text: "error"; size: Tk.iconSize.medium; color: Colours.m3error }
      MText { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: "hyprmoncfg: " + DisplayService.lastError; color: Colours.m3error; font.pointSize: Tk.body.small }
    }
  }
  RowToggle {
    Layout.fillWidth: true
    first: true
    text: "Switch automatically"
    subtext: DisplayService.auto.auto ? "hyprmoncfg picks the profile that fits the displays you connect"
      : "Kept on " + DisplayService.auto.pinned + " until you turn this back on"
    checked: DisplayService.auto.auto
    disabled: root.busy
    onToggled: c => DisplayService.setAuto(c)
  }

  Repeater {
    model: DisplayService.profiles
    ConnectedRect {
      id: pr
      required property var modelData
      readonly property bool asking: root.confirmDelete === modelData.name
      Layout.fillWidth: true
      implicitHeight: prl.implicitHeight + Tk.padding.medium * 2
      RowLayout {
        id: prl
        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Tk.padding.largeIncreased; anchors.rightMargin: Tk.padding.medium
        spacing: Tk.spacing.medium
        MIcon {
          text: pr.modelData.active ? "check_circle" : "desktop_windows"
          size: Tk.iconSize.medium
          fill: pr.modelData.active ? 1 : 0
          color: pr.modelData.active ? Colours.m3primary : Colours.m3onSurfaceVariant
        }
        RowLabel {
          Layout.fillWidth: true
          text: pr.asking ? "Delete " + pr.modelData.name + "?" : pr.modelData.name
          subtext: pr.asking ? "hyprmoncfg removes the saved layout"
            : [pr.modelData.active ? "In use" : "", pr.modelData.recommended ? "Recommended" : "",
               pr.modelData.fits ? "Fits these displays" : "", pr.modelData.shown + " of " + pr.modelData.total + " displays"].filter(x => x).join(" · ")
        }
        IconTextButton {
          visible: !pr.asking && !pr.modelData.active
          type: "tonal"; isRound: true; icon: "play_arrow"; text: "Apply"
          fontSize: Tk.body.small
          disabled: root.busy
          onClicked: DisplayService.applyProfile(pr.modelData.name)
        }
        IconButton {
          visible: !pr.asking && !pr.modelData.active
          type: "text"; icon: "delete"
          disabled: root.busy
          onClicked: root.confirmDelete = pr.modelData.name
        }
        IconTextButton {
          visible: pr.asking
          type: "text"; isRound: true; text: "Cancel"
          fontSize: Tk.body.small
          onClicked: root.confirmDelete = ""
        }
        IconTextButton {
          visible: pr.asking
          type: "filled"; isRound: true; icon: "delete"; text: "Delete"
          fontSize: Tk.body.small
          disabled: root.busy
          onClicked: { DisplayService.deleteProfile(pr.modelData.name); root.confirmDelete = "" }
        }
      }
    }
  }

  // Save the layout as it is now under a name (an existing name is replaced
  // only after "Replace").
  ConnectedRect {
    id: saveRow
    Layout.fillWidth: true
    last: true
    implicitHeight: sl.implicitHeight + Tk.padding.medium * 2
    readonly property bool taken: Model.nameTaken(DisplayService.statusDoc, nameField.text)
    RowLayout {
      id: sl
      anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Tk.padding.largeIncreased; anchors.rightMargin: Tk.padding.medium
      spacing: Tk.spacing.medium
      MIcon { text: "save"; size: Tk.iconSize.medium; color: Colours.m3onSurfaceVariant }
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: Tk.px(36)
        radius: height / 2
        color: Colours.m3surfaceContainerHighest
        border.width: nameField.activeFocus ? 2 : 0
        border.color: Colours.m3primary
        MTextField {
          id: nameField
          anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
          anchors.leftMargin: Tk.padding.large; anchors.rightMargin: Tk.padding.large
          font.pointSize: Tk.body.small
          clip: true
          onAccepted: saveBtn.clicked()
          MText { anchors.verticalCenter: parent.verticalCenter; visible: !nameField.text; text: "Save this layout as…"; color: Colours.m3outline }
        }
      }
      IconTextButton {
        id: saveBtn
        type: saveRow.taken ? "tonal" : "filled"; isRound: true
        icon: saveRow.taken ? "sync" : "save"
        text: saveRow.taken ? "Replace" : "Save"
        fontSize: Tk.body.small
        disabled: root.busy || !nameField.text.trim()
        onClicked: { if (disabled) return; DisplayService.saveAs(nameField.text); nameField.text = "" }
      }
    }
  }
}
