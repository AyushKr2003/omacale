import QtQuick
import QtQuick.Layouts

// Label with an optional muted subtext, used by every settings row.
ColumnLayout {
  property string text
  property string subtext
  spacing: 0
  MText { Layout.fillWidth: true; text: parent.text; elide: Text.ElideRight }
  MText {
    Layout.fillWidth: true
    visible: text !== ""
    text: parent.subtext
    color: Colours.m3outline
    font.pointSize: Tk.label.small
    elide: Text.ElideRight
  }
}
