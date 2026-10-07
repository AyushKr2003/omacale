import QtQuick
import QtQuick.Layouts
import "../../.."

// The logo (Caelestia bar/components/OsIcon.qml): left click opens the
// launcher, right click Settings. Full-width row so the icon is centred with
// a rounded x: the bar is an even width and the slot odd, so AlignHCenter
// would put it on a half pixel and blur it.
Item {
  id: entry
  required property var bar
  property string entryId: "logo"
  readonly property bool shown: bar.cfg.logo
  visible: shown
  Layout.fillWidth: bar.vertical
  Layout.fillHeight: !bar.vertical
  implicitWidth: bar.vertical ? 0 : Tk.barInner
  implicitHeight: bar.vertical ? logo.height : 0
  LogoIcon {
    id: logo
    x: Math.round((parent.width - width) / 2)
    y: bar.vertical ? 0 : Math.round((parent.height - height) / 2)
    width: Math.round(Tk.body.large * 1.2)
    height: width
    value: bar.cfg.logoIcon
    size: width
    colour: Colours.m3tertiary
  }
  MouseArea {
    anchors.fill: logo
    anchors.margins: -Tk.px(4)
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: e => bar.host.toggle(e.button === Qt.RightButton ? "settings" : "launcher")
  }

  function navStops() {
    return [{ item: logo, act: () => bar.leaveFor("launcher") }]
  }
}
