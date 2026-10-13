import QtQuick
import QtQuick.Layouts
import "../../.."

// Omarchy's mirror toggle left on while hyprmoncfg manages the displays: it
// mirrors over every layout and profile hyprmoncfg applies, so they seem to do
// nothing. Shown on Settings › Display and its Profiles page, with the way out.
// No Caelestia original; a Nexus row like the rest of the page.
ConnectedRect {
  id: root
  Layout.fillWidth: true
  first: true
  last: true
  visible: DisplayService.omarchyMirror && DisplayService.backend === "hyprmoncfg"
  implicitHeight: ml.implicitHeight + Tk.padding.medium * 2
  RowLayout {
    id: ml
    anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: Tk.padding.largeIncreased; anchors.rightMargin: Tk.padding.medium
    spacing: Tk.spacing.medium
    MIcon { text: "screen_share"; size: Tk.iconSize.medium; color: Colours.m3error }
    RowLabel {
      Layout.fillWidth: true
      text: "Omarchy is mirroring the laptop screen"
      subtext: "Its mirror overrides every layout and profile hyprmoncfg applies"
    }
    IconTextButton {
      type: "filled"; isRound: true; icon: "close"; text: "Stop mirroring"
      fontSize: Tk.body.small
      onClicked: DisplayService.setMirror(false)
    }
  }
}
