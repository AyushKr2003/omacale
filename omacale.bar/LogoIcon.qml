import QtQuick
import Quickshell
import "Logos.js" as Logos

// One bar-logo option drawn at `size`, in `colour` (see Logos.js).
Item {
  id: root
  property string value: "omarchy"
  property real size: Tk.body.large * 1.2
  property color colour: Colours.m3tertiary
  property string omarchyPath: Quickshell.env("OMARCHY_PATH") || "/usr/share/omarchy"
  readonly property var opt: Logos.byId(value)

  implicitWidth: size
  implicitHeight: size

  ColouredIcon {
    anchors.centerIn: parent
    visible: root.opt.kind === "image"
    implicitSize: root.size
    source: visible ? "file://" + root.omarchyPath + "/icon.png" : ""
    colour: root.colour
  }
  Text {
    anchors.centerIn: parent
    visible: root.opt.kind === "nerd"
    text: root.opt.glyph || ""
    color: root.colour
    font.family: Tk.mono
    font.pixelSize: Math.max(1, root.size)
    Behavior on color { CAnim {} }
  }
  MIcon {
    anchors.centerIn: parent
    visible: root.opt.kind === "material"
    text: root.opt.glyph || ""
    color: root.colour
    fill: 1
    // MIcon sizes in points; match the other kinds' pixel size.
    size: Math.max(1, root.size * 0.75)
  }
}
