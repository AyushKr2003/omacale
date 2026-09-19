import QtQuick
import QtQuick.Layouts

// Label with an optional muted subtext, used by every settings row.
ColumnLayout {
  id: root
  property string text
  property string subtext
  property real textSize: Tk.body.small
  spacing: 0
  MText { Layout.fillWidth: true; text: root.text; font.pointSize: root.textSize; elide: Text.ElideRight }
  MText {
    Layout.fillWidth: true
    visible: text !== ""
    text: root.subtext
    color: Colours.m3outline
    font.pointSize: Tk.label.small
    elide: Text.ElideRight
  }
}
