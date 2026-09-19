import QtQuick
import QtQuick.Layouts
import Quickshell

// One notification inside a group (Caelestia sidebar/Notif.qml). Collapsed it
// is a single line, "summary  body"; expanded it becomes a card with the full
// body and an action row.
Rectangle {
  id: root

  property var modelData
  property bool expanded: false
  signal dismissRequested()
  signal toggleExpandRequested(bool expand)

  readonly property bool isCritical: !!(modelData && modelData.urgency === 2)
  readonly property string bodyText: modelData ? String(modelData.body || "") : ""
  readonly property string timeText: {
    if (!modelData || !modelData.timestamp) return ""
    return Sys.time(new Date(modelData.timestamp))
  }
  readonly property real nonAnimHeight: expanded
    ? summary.implicitHeight + expandedContent.implicitHeight + Tk.spacing.extraSmall + Tk.padding.medium * 2
    : lineMetrics.height

  implicitHeight: nonAnimHeight
  Behavior on implicitHeight { Anim {} }

  radius: Tk.rounding.medium
  color: {
    const c = isCritical ? Colours.m3secondaryContainer : Colours.m3surfaceContainerHigh
    return expanded ? c : Qt.alpha(c, 0)
  }
  Behavior on color { CAnim {} }

  property real pad: expanded ? Tk.padding.medium : 0
  Behavior on pad { Anim {} }

  TextMetrics {
    id: lineMetrics
    font: summary.font
    text: " "
  }

  MText {
    id: summary
    x: root.pad
    y: root.pad
    width: root.expanded ? root.width - root.pad * 2 - timeLabel.implicitWidth - Tk.spacing.small : root.width
    text: root.modelData ? String(root.modelData.summary || "") : ""
    color: root.isCritical ? Colours.m3onSecondaryContainer : Colours.m3onSurface
    elide: Text.ElideRight
    wrapMode: Text.WordWrap
    maximumLineCount: root.expanded ? 9999 : 1
    Behavior on width { Anim {} }
  }

  // Invisible twin used to place the compact body right after the summary.
  MText {
    id: dummySummary
    x: root.pad
    y: root.pad
    visible: false
    text: summary.text
  }

  MText {
    id: compactBody
    x: dummySummary.x + Math.min(dummySummary.implicitWidth, root.width) + Tk.spacing.small
    y: 0
    width: Math.max(0, root.width - x)
    opacity: root.expanded ? 0 : 1
    visible: opacity > 0
    text: root.bodyText.replace(/\n/g, " ")
    color: root.isCritical ? Colours.m3secondary : Colours.m3outline
    elide: Text.ElideRight
    Behavior on opacity { Anim { type: "effects" } }
  }

  MText {
    id: timeLabel
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.margins: root.pad
    opacity: root.expanded ? 1 : 0
    visible: opacity > 0
    text: root.timeText
    color: Colours.m3outline
    Behavior on opacity { Anim { type: "effects" } }
  }

  ColumnLayout {
    id: expandedContent
    anchors.top: summary.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.margins: root.pad
    anchors.topMargin: Tk.spacing.extraSmall
    spacing: Tk.spacing.medium
    opacity: root.expanded ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { Anim { type: "effects" } }

    MText {
      Layout.fillWidth: true
      textFormat: Text.MarkdownText
      text: root.bodyText.replace(/(.)\n(?!\n)/g, "$1\n\n") || "No body here! :/"
      color: root.isCritical ? Colours.m3secondary : Colours.m3outline
      wrapMode: Text.WordWrap
      onLinkActivated: link => Qt.openUrlExternally(link)
    }

    // Close / Open / Copy (Caelestia NotifActionList)
    RowLayout {
      Layout.fillWidth: true
      spacing: Tk.spacing.small

      Repeater {
        model: {
          const acts = [{ kind: "close" }]
          if (root.modelData && root.modelData.execArgv) acts.push({ kind: "open" })
          acts.push({ kind: "copy" })
          return acts
        }

        delegate: Rectangle {
          id: action
          required property var modelData
          property bool copied: false

          Layout.fillWidth: true
          implicitWidth: (action.modelData.kind === "open" ? label.implicitWidth : glyph.implicitWidth) + Tk.padding.medium * 2
          implicitHeight: Math.max(label.implicitHeight, glyph.implicitHeight) + Tk.padding.small
          Layout.preferredWidth: implicitWidth + (actionState.pressed ? Tk.padding.large : 0)
          Behavior on Layout.preferredWidth { Anim { type: "fastSpatial" } }
          radius: actionState.pressed ? Tk.rounding.medium / 2 : Tk.rounding.medium
          Behavior on radius { Anim { type: "effects" } }
          color: Colours.m3surfaceContainerHighest

          Timer { id: copyTimer; interval: 3000; onTriggered: action.copied = false }

          StateLayer {
            id: actionState
            onClicked: {
              if (action.modelData.kind === "close") root.dismissRequested()
              else if (action.modelData.kind === "open") {
                Quickshell.execDetached(["bash", "-c", root.modelData.execArgv])
                root.dismissRequested()
              } else {
                Quickshell.clipboardText = root.bodyText
                action.copied = true
                copyTimer.restart()
              }
            }
          }

          MText {
            id: label
            anchors.centerIn: parent
            visible: action.modelData.kind === "open"
            text: "Open"
            color: Colours.m3onSurfaceVariant
          }
          MIcon {
            id: glyph
            anchors.centerIn: parent
            visible: action.modelData.kind !== "open"
            text: action.modelData.kind === "close" ? "close" : action.copied ? "inventory" : "content_copy"
            color: Colours.m3onSurfaceVariant
          }
        }
      }
    }
  }
}
