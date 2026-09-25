import QtQuick
import QtQuick.Layouts
import Quickshell
import "../.."

// One notification inside a group (Caelestia sidebar/Notif.qml). Collapsed it
// is a single line, "summary  body"; expanded it becomes a card with the full
// body, its age and the action row (NotifActionList).
Rectangle {
  id: root

  property var modelData
  property bool expanded: false
  signal dismissRequested()

  readonly property bool isCritical: NotifService.urgencyOf(modelData) === 2
  readonly property string bodyText: modelData ? String(modelData.body || "") : ""
  readonly property real nonAnimHeight: expanded
    ? summary.implicitHeight + expandedContent.implicitHeight + expandedContent.anchors.topMargin + Tk.padding.medium * 2
    : lineMetrics.height

  implicitHeight: nonAnimHeight
  Behavior on implicitHeight { Anim {} }

  radius: Tk.rounding.medium
  color: {
    const c = isCritical ? Colours.m3secondaryContainer : Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)
    return expanded ? c : Qt.alpha(c, 0)
  }
  Behavior on color { CAnim {} }

  // Caelestia animates the anchors' margins between 0 and padding.medium.
  property real pad: expanded ? Tk.padding.medium : 0
  Behavior on pad { Anim {} }

  TextMetrics {
    id: lineMetrics
    font: summary.font
    text: " " // Keeps odd characters from changing the line height
  }

  MText {
    id: summary
    x: root.pad
    y: root.pad
    width: root.expanded ? root.width - Tk.padding.medium * 2 - timeLabel.implicitWidth - Tk.spacing.small : root.width
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

  FadeLoader {
    id: compactBody
    shown: !root.expanded
    x: dummySummary.x + dummySummary.implicitWidth + Tk.spacing.small
    y: root.pad
    width: Math.max(0, root.width - root.pad - x)

    sourceComponent: MText {
      text: root.bodyText.replace(/\n/g, " ")
      color: root.isCritical ? Colours.m3secondary : Colours.m3outline
      elide: Text.ElideRight
    }
  }

  FadeLoader {
    id: timeLabel
    shown: root.expanded
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.margins: root.pad

    sourceComponent: MText {
      animate: true
      text: NotifService.timeStr(root.modelData)
      color: Colours.m3outline
      font.pointSize: Tk.body.small
    }
  }

  FadeLoader {
    id: expandedContent
    shown: root.expanded
    anchors.top: summary.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.margins: root.pad
    anchors.topMargin: Tk.spacing.extraSmall

    sourceComponent: ColumnLayout {
      spacing: Tk.spacing.medium

      MText {
        Layout.fillWidth: true
        textFormat: Text.MarkdownText
        text: root.bodyText.replace(/(.)\n(?!\n)/g, "$1\n\n") || "No body here! :/"
        color: root.isCritical ? Colours.m3secondary : Colours.m3outline
        wrapMode: Text.WordWrap
        onLinkActivated: link => Qt.openUrlExternally(link)
        HoverHandler { cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : undefined }
      }

      // Close / Open / Copy (Caelestia NotifActionList). Omarchy records a
      // notification's default action as `execArgv`; it has no other actions.
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
            readonly property string navKey: root.modelData ? "notif:" + root.modelData.id + ":" + root.modelData.timestamp + ":" + modelData.kind : ""

            Layout.fillWidth: true
            Layout.fillHeight: true
            implicitWidth: actionInner.implicitWidth + Tk.padding.medium * 2
            implicitHeight: actionInner.implicitHeight + Tk.padding.small
            Layout.preferredWidth: implicitWidth + (actionState.pressed ? Tk.padding.large : 0)
            Behavior on Layout.preferredWidth { Anim { type: "fastSpatial" } }
            radius: actionState.pressed ? Tk.rounding.medium / 2 : Tk.rounding.medium
            Behavior on radius { Anim { type: "fastSpatial" } }
            color: Colours.layer(Colours.palette.m3surfaceContainerHighest, 4)

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

            Loader {
              id: actionInner
              anchors.centerIn: parent
              sourceComponent: action.modelData.kind === "open" ? textComp : iconComp
            }
            Component {
              id: iconComp
              MIcon {
                animate: action.modelData.kind === "copy"
                text: action.modelData.kind === "close" ? "close" : action.copied ? "inventory" : "content_copy"
                color: Colours.m3onSurfaceVariant
              }
            }
            Component {
              id: textComp
              MText { text: "Open"; color: Colours.m3onSurfaceVariant }
            }
          }
        }
      }
    }
  }

  // Caelestia's WrappedLoader: loads on the frame it is shown (so its size is
  // known), fades in; fades out, then unloads.
  component FadeLoader: Loader {
    id: fl
    property bool shown: false
    active: false
    opacity: 0

    states: State {
      name: "active"
      when: fl.shown
      PropertyChanges { fl.opacity: 1; fl.active: true }
    }
    transitions: [
      Transition {
        from: ""; to: "active"
        SequentialAnimation {
          PropertyAction { property: "active" }
          Anim { type: "effects"; property: "opacity" }
        }
      },
      Transition {
        from: "active"; to: ""
        SequentialAnimation {
          Anim { type: "effects"; property: "opacity" }
          PropertyAction { property: "active" }
        }
      }
    ]
  }
}
