import QtQuick

// Caelestia StyledSwitch (M3 switch with check / cross glyph).
Item {
  id: root
  property bool checked
  signal toggled(bool checked)

  implicitHeight: Tk.body.medium * 4 / 3 + Tk.padding.small * 2
  implicitWidth: implicitHeight * 1.7

  Rectangle {
    anchors.fill: parent
    radius: height / 2
    color: root.checked ? Colours.m3primary : Colours.m3surfaceContainerHighest
    Behavior on color { CAnim {} }

    Rectangle {
      readonly property real nonAnimWidth: mouse.pressed ? height * 1.2 : height
      width: nonAnimWidth
      height: parent.height - Tk.padding.extraSmall
      radius: height / 2
      anchors.verticalCenter: parent.verticalCenter
      x: root.checked ? parent.width - width - Tk.padding.extraSmall / 2 : Tk.padding.extraSmall / 2
      color: root.checked ? Colours.m3onPrimary : Colours.m3outline
      Behavior on x { Anim {} }
      Behavior on width { Anim { type: "fastSpatial" } }
      Behavior on color { CAnim {} }

      MIcon {
        anchors.centerIn: parent
        text: root.checked ? "check" : "close"
        size: Tk.iconSize.small * 0.75
        weight: 700
        color: root.checked ? Colours.m3primary : Colours.m3surfaceContainerHighest
      }
    }
  }
  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.toggled(!root.checked)
  }
}
