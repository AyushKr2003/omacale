import QtQuick
import QtQuick.Layouts

MText {
  property var row
  property var settings
  property bool first
  property bool last
  text: row ? row.text : ""
  topPadding: first ? 0 : Tk.spacing.largeIncreased - Tk.spacing.extraSmall / 2
  bottomPadding: Tk.spacing.extraSmall
  leftPadding: Tk.padding.small
  color: Colours.m3onSurfaceVariant
  font.pointSize: Tk.label.medium
  elide: Text.ElideRight
}
