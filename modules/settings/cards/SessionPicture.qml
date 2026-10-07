import QtQuick
import QtQuick.Layouts
import "../../.."

// Settings › Session › Picture: Caelestia's paths.sessionGif. A GIF or image
// of the user's own between the session buttons, picked with Omacale's own
// FileDialog (Settings.fileRequested); empty is the bundled kurukuru.
ConnectedRect {
  id: root
  property var row
  property var settings
  property bool first
  property bool last

  readonly property string path: Config.o.session.gifPath
  implicitHeight: rl.implicitHeight + Tk.padding.medium * 2

  RowLayout {
    id: rl
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: Tk.padding.largeIncreased
    anchors.rightMargin: Tk.padding.medium
    spacing: Tk.spacing.medium
    AnimatedImage {
      Layout.preferredWidth: Tk.iconSize.large * 1.5
      Layout.preferredHeight: Layout.preferredWidth
      source: root.path ? "file://" + root.path : Qt.resolvedUrl("../../../assets/kurukuru.gif")
      fillMode: Image.PreserveAspectFit
      playing: false
    }
    RowLabel {
      Layout.fillWidth: true
      text: "Picture"
      subtext: root.path ? root.path.slice(root.path.lastIndexOf("/") + 1) : "The bundled animation"
    }
    IconButton {
      visible: root.path !== ""
      type: "text"
      icon: "restart_alt"
      onClicked: Config.set("session.gifPath", "")
    }
    IconButton {
      type: "tonal"
      icon: "folder_open"
      onClicked: root.settings.fileRequested("Select a session picture", ["gif", "png", "jpg", "jpeg", "webp"],
        p => Config.set("session.gifPath", p))
    }
  }
}
