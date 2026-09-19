import QtQuick
import QtQuick.Layouts

// Caelestia ButtonBase as used in its nexus detail pages: a wide pill with a
// stacked icon and label that squares off while pressed.
Rectangle {
  id: bb
  property string icon
  property string text
  property color bg: Colours.m3primaryContainer
  property color fg: Colours.m3onPrimaryContainer
  property bool disabled: false
  signal clicked()

  Layout.fillWidth: true
  implicitWidth: col.implicitWidth + Tk.padding.extraLarge * 2
  implicitHeight: col.implicitHeight + Tk.padding.medium * 2
  radius: st.pressed ? Tk.rounding.medium : height / 2
  color: bg
  opacity: disabled ? 0.5 : 1
  Behavior on radius { Anim { type: "fastSpatial" } }
  Behavior on opacity { Anim { type: "effects" } }

  StateLayer { id: st; disabled: bb.disabled; color: bb.fg; onClicked: bb.clicked() }
  ColumnLayout {
    id: col
    anchors.centerIn: parent
    spacing: 0
    MIcon { Layout.alignment: Qt.AlignHCenter; text: bb.icon; size: Tk.iconSize.medium; color: bb.fg }
    MText { Layout.alignment: Qt.AlignHCenter; text: bb.text; color: bb.fg }
  }
}
