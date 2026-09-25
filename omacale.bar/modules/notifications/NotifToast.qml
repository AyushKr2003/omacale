import QtQuick
import QtQuick.Shapes
import Quickshell
import "../.."

// One toast (Caelestia modules/notifications/Notification.qml).
//
// Collapsed it is a summary line over a one-line body preview; expanded it
// grows an app name, the full body and the action row. Dragging it sideways
// throws it away, dragging it up or down collapses or expands it, and hovering
// stops the countdown.
//
// Caelestia draws a progress arc around the icon from the notification's
// `value` hint. Omarchy's records don't carry hints, so that ring shows the
// popup's remaining lifetime instead -- the one thing on this card that
// Caelestia's doesn't have.
Rectangle {
  id: root

  required property var modelData
  readonly property string key: modelData ? String(modelData._key || "") : ""
  readonly property int urgency: NotifService.urgencyOf(modelData)
  readonly property bool isCritical: urgency === 2
  readonly property bool isLow: urgency === 0

  // A themed icon name, a file path, or nothing.
  function resolve(value) {
    const s = String(value || "")
    if (!s) return ""
    if (s.indexOf("file://") === 0 || s.charAt(0) === "/") return s
    return Quickshell.iconPath(s, true)
  }

  readonly property string imageSource: root.resolve(modelData ? modelData.image : "")
  readonly property string appIconSource: root.resolve(modelData ? modelData.appIcon : "")
  // Omarchy's own toasts carry a nerd-font glyph instead of an icon name.
  readonly property string glyph: modelData ? String(modelData.glyph || "") : ""
  readonly property bool hasImage: imageSource !== ""
  readonly property bool hasAppIcon: appIconSource !== "" || glyph !== ""
  readonly property string bodyText: modelData ? String(modelData.body || "") : ""
  readonly property int bodyTextFormat: /[<*_`#\[\]]/.test(bodyText) ? Text.MarkdownText : Text.PlainText

  // Expanded state lives in the service, so a record update that rebuilds
  // this delegate can't collapse the card under the pointer.
  readonly property bool expanded: NotifService.popupExpanded(key)
  function setExpanded(on) { NotifService.setPopupExpanded(key, on) }

  // The height the card settles at, which is what the stack measures itself
  // with while everything else animates (Caelestia's nonAnimHeight).
  readonly property real nonAnimHeight: summary.implicitHeight
    + (expanded ? Tk.spacing.extraSmall * 2 + appName.height + body.height + actions.height + Tk.spacing.small
                : bodyPreview.height)
    + Tk.padding.medium * 2

  readonly property color fg: isCritical ? Colours.m3onSecondaryContainer : Colours.m3onSurface
  readonly property color fgVariant: isCritical ? Colours.m3secondary : Colours.m3onSurfaceVariant

  signal dismissed()
  signal clicked()

  color: isCritical ? Colours.m3secondaryContainer : Colours.m3surfaceContainer
  radius: Tk.rounding.large
  implicitHeight: inner.implicitHeight
  Behavior on color { CAnim {} }

  // Slides in from the right edge, as Caelestia's does. The move has to wait
  // a tick: at completion the width this starts from has only just been bound.
  x: implicitWidth
  Component.onCompleted: Qt.callLater(() => root.x = 0)
  Behavior on x { Anim { easing.bezierCurve: Tk.curves.emphasizedDecel } }

  MouseArea {
    id: mouse

    property int startY

    anchors.fill: parent
    hoverEnabled: true
    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    preventStealing: true

    onEntered: NotifService.pausePopups(true)
    onExited: if (!pressed) NotifService.pausePopups(false)

    drag.target: root
    drag.axis: Drag.XAxis

    onPressed: e => {
      NotifService.pausePopups(true)
      startY = e.y
      if (e.button === Qt.MiddleButton) root.dismissed()
    }
    onReleased: e => {
      if (!containsMouse) NotifService.pausePopups(false)
      // A short throw springs back, a long one lets go (clearThreshold).
      if (Math.abs(root.x) < root.implicitWidth * 0.3) root.x = 0
      else root.dismissed()
    }
    onPositionChanged: e => {
      if (!pressed) return
      const diffY = e.y - startY
      if (Math.abs(diffY) > 20) root.setExpanded(diffY > 0)
    }
    onClicked: e => {
      if (e.button !== Qt.LeftButton || Math.abs(root.x) > 2) return
      root.clicked()
    }

    Item {
      id: inner

      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: Tk.padding.medium

      implicitHeight: root.nonAnimHeight
      Behavior on implicitHeight { Anim {} }

      // ---- image, app icon badge and the countdown ring

      Loader {
        id: image

        asynchronous: true
        active: root.hasImage

        anchors.left: parent.left
        anchors.top: parent.top
        width: Tk.sizes.notifImage
        height: Tk.sizes.notifImage
        visible: root.hasImage || root.hasAppIcon

        sourceComponent: Rectangle {
          radius: Tk.rounding.full
          color: root.isCritical ? Colours.m3error
            : root.isLow ? Colours.layer(Colours.palette.m3surfaceContainerHighest, 2)
            : Colours.m3secondaryContainer
          implicitWidth: Tk.sizes.notifImage
          implicitHeight: Tk.sizes.notifImage
          clip: true

          Image {
            anchors.fill: parent
            source: root.imageSource
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: Tk.sizes.notifImage * 2
            sourceSize.height: Tk.sizes.notifImage * 2
            cache: false
            asynchronous: true
          }
        }
      }

      Loader {
        id: appIcon

        asynchronous: true
        active: root.hasAppIcon || !root.hasImage

        anchors.horizontalCenter: root.hasImage ? undefined : image.horizontalCenter
        anchors.verticalCenter: root.hasImage ? undefined : image.verticalCenter
        anchors.right: root.hasImage ? image.right : undefined
        anchors.bottom: root.hasImage ? image.bottom : undefined

        sourceComponent: Rectangle {
          id: badge

          // Caelestia tints the badge by urgency; "fg" rather than a name
          // starting with "on" so QML doesn't read it as a signal handler.
          readonly property color fg: root.isCritical ? Colours.m3onError
            : root.isLow ? Colours.m3onSurface : Colours.m3onSecondaryContainer

          radius: Tk.rounding.full
          color: root.isCritical ? Colours.m3error
            : root.isLow ? Colours.layer(Colours.palette.m3surfaceContainerHighest, 2)
            : Colours.m3secondaryContainer
          implicitWidth: root.hasImage ? Tk.sizes.notifBadge : Tk.sizes.notifImage
          implicitHeight: implicitWidth

          Loader {
            asynchronous: true
            active: root.appIconSource !== ""
            anchors.centerIn: parent
            width: Math.round(badge.width * 0.6)
            height: width

            sourceComponent: ColouredIcon {
              anchors.fill: parent
              source: root.appIconSource
              colour: badge.fg
            }
          }

          // No icon: Omarchy's own glyph if it sent one, else the Material
          // symbol Caelestia picks from the summary.
          Loader {
            asynchronous: true
            active: root.appIconSource === ""
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 1

            sourceComponent: MText {
              text: root.glyph || NotifService.notifIcon(root.modelData ? root.modelData.summary : "", root.urgency)
              color: badge.fg
              font.family: root.glyph ? Tk.mono : Tk.icon
              font.pointSize: Tk.iconSize.medium
            }
          }
        }
      }

      // Remaining lifetime, drawn around whichever icon is showing. Critical
      // toasts never expire, so they get no ring.
      Shape {
        id: progress

        anchors.centerIn: appIcon
        width: appIcon.width + Tk.px(4)
        height: appIcon.height + Tk.px(4)
        preferredRendererType: Shape.CurveRenderer
        visible: root.modelData ? NotifService.popupDeadline(root.modelData) > 0 : false

        readonly property real remaining: {
          if (!visible || !root.modelData) return 0
          const deadline = NotifService.popupDeadline(root.modelData)
          const duration = NotifService.popupDuration(root.modelData)
          if (deadline <= 0 || duration <= 0) return 0
          return Math.max(0, Math.min(1, (deadline - NotifService.popupClock) / duration))
        }

        ShapePath {
          capStyle: ShapePath.RoundCap
          fillColor: "transparent"
          strokeWidth: 2
          strokeColor: root.isCritical ? Colours.m3onSecondaryContainer : Colours.m3primary

          PathAngleArc {
            radiusX: progress.width / 2 - Tk.padding.extraSmall / 2
            radiusY: progress.height / 2 - Tk.padding.extraSmall / 2
            centerX: progress.width / 2
            centerY: progress.height / 2
            startAngle: -90
            sweepAngle: progress.remaining * 360
          }
        }
      }

      // ---- header: app name (expanded only), summary, age, expand button

      MText {
        id: appName

        anchors.top: parent.top
        anchors.left: image.right
        anchors.leftMargin: Tk.spacing.medium

        animate: true
        text: appNameMetrics.elidedText
        maximumLineCount: 1
        color: root.fgVariant
        font.pointSize: Tk.label.medium
        weight: Font.Medium

        opacity: root.expanded ? 1 : 0
        Behavior on opacity { Anim { type: "effects" } }
      }

      TextMetrics {
        id: appNameMetrics
        text: root.modelData ? String(root.modelData.app || "") : ""
        font: appName.font
        elide: Text.ElideRight
        elideWidth: Math.max(0, expandBtn.x - time.width - timeSep.width - summary.x - Tk.spacing.small * 3)
      }

      MText {
        id: summary

        anchors.top: parent.top
        anchors.left: image.right
        anchors.leftMargin: Tk.spacing.medium

        animate: true
        text: summaryMetrics.elidedText
        maximumLineCount: 1
        height: implicitHeight
        color: root.fg

        states: State {
          name: "expanded"
          when: root.expanded

          PropertyChanges {
            summary.maximumLineCount: 9999
            summary.anchors.topMargin: Tk.spacing.extraSmall
            bodyPreview.anchors.topMargin: Tk.spacing.extraSmall
            body.anchors.topMargin: Tk.spacing.extraSmall
          }

          AnchorChanges {
            target: summary
            anchors.top: appName.bottom
          }
        }

        transitions: Transition {
          PropertyAction { target: summary; property: "maximumLineCount" }
          Anim { property: "topMargin" }
          AnchorAnimation {
            duration: Tk.durations.defaultSpatial
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Tk.curves.defaultSpatial
          }
        }

        Behavior on height { Anim {} }
      }

      TextMetrics {
        id: summaryMetrics
        text: root.modelData ? String(root.modelData.summary || "") : ""
        font: summary.font
        elide: Text.ElideRight
        elideWidth: Math.max(0, expandBtn.x - time.width - timeSep.width - summary.x - Tk.spacing.small * 3)
      }

      MText {
        id: timeSep

        anchors.top: parent.top
        anchors.left: summary.right
        anchors.leftMargin: Tk.spacing.small

        text: "•"
        color: root.fgVariant

        states: State {
          name: "expanded"
          when: root.expanded
          AnchorChanges {
            target: timeSep
            anchors.left: appName.right
          }
        }

        transitions: Transition {
          AnchorAnimation {
            duration: Tk.durations.defaultSpatial
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Tk.curves.defaultSpatial
          }
        }
      }

      MText {
        id: time

        anchors.top: parent.top
        anchors.left: timeSep.right
        anchors.leftMargin: Tk.spacing.small

        animate: true
        text: NotifService.timeStr(root.modelData)
        color: root.fgVariant
      }

      Item {
        id: expandBtn

        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: -Tk.padding.extraSmall

        implicitWidth: expandIcon.implicitHeight
        implicitHeight: expandIcon.implicitHeight

        StateLayer {
          radius: Tk.rounding.full
          color: root.fg
          onClicked: root.setExpanded(!root.expanded)
        }

        MIcon {
          id: expandIcon

          anchors.centerIn: parent
          anchors.verticalCenterOffset: root.expanded ? -1 : 1
          text: "expand_more"
          size: Tk.iconSize.medium
          color: root.fg
          rotation: root.expanded ? 180 : 0

          Behavior on anchors.verticalCenterOffset { Anim {} }
          Behavior on rotation { Anim {} }
        }
      }

      // ---- body

      MText {
        id: bodyPreview

        anchors.left: summary.left
        anchors.right: expandBtn.left
        anchors.top: summary.bottom
        anchors.rightMargin: Tk.spacing.small

        animate: true
        text: bodyPreviewMetrics.elidedText
        color: root.fgVariant

        opacity: root.expanded ? 0 : 1
        Behavior on opacity { Anim { type: "effects" } }
      }

      TextMetrics {
        id: bodyPreviewMetrics
        text: root.bodyText.replace(/\n/g, " ")
        font: bodyPreview.font
        elide: Text.ElideRight
        elideWidth: bodyPreview.width
      }

      MText {
        id: body

        anchors.left: summary.left
        anchors.right: expandBtn.left
        anchors.top: summary.bottom
        anchors.rightMargin: Tk.spacing.small

        textFormat: root.bodyTextFormat
        text: root.bodyText
        color: root.fgVariant
        wrapMode: Text.WordWrap
        height: text ? implicitHeight : 0

        onLinkActivated: link => {
          if (!root.expanded) return
          Qt.openUrlExternally(link)
          root.dismissed()
        }

        opacity: root.expanded ? 1 : 0
        Behavior on opacity { Anim { type: "effects" } }
      }

      // ---- actions
      //
      // Caelestia puts the sender's libnotify actions between close and copy.
      // Omarchy's records only keep the one default action (`execArgv`), so
      // that is all the middle can hold -- the same row the sidebar's
      // NotifItem draws.

      ButtonRow {
        id: actions

        anchors.left: body.left
        anchors.right: body.right
        anchors.top: body.bottom
        anchors.topMargin: Tk.spacing.small

        spacing: Tk.spacing.extraSmall
        opacity: root.expanded ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { Anim { type: "effects" } }

        readonly property bool hasOpen: !!(root.modelData && root.modelData.execArgv)
        readonly property color face: root.isCritical ? Colours.m3secondary : Colours.layer(Colours.palette.m3surfaceContainerHighest, 2)
        readonly property color faceOn: root.isCritical ? Colours.m3onSecondary : Colours.m3onSurfaceVariant

        IconButton {
          shapeMorph: true
          fillWidth: !actions.hasOpen
          inactiveColour: actions.face
          inactiveOnColour: actions.faceOn
          icon: "close"
          padding: Tk.padding.extraSmall
          onClicked: root.dismissed()
        }

        // Caelestia's TextButton, the shape its libnotify actions take.
        Rectangle {
          id: openBtn

          property bool fillWidth: true
          property real shapeMorphExpansion: openState.pressed ? 24 : 0
          Behavior on shapeMorphExpansion { Anim { type: "fastSpatial" } }

          visible: actions.hasOpen
          implicitWidth: openLabel.implicitWidth + Tk.padding.medium * 2
          implicitHeight: openLabel.implicitHeight + Tk.padding.small * 2
          radius: openState.pressed ? Tk.rounding.small : height / 2
          color: actions.face
          Behavior on radius { Anim { type: "fastSpatial" } }
          Behavior on color { CAnim {} }

          StateLayer {
            id: openState
            color: actions.faceOn
            shapeMorph: true
            onClicked: root.clicked()
          }

          MText {
            id: openLabel
            anchors.centerIn: parent
            text: "Open"
            color: actions.faceOn
            font.pointSize: Tk.body.medium
            elide: Text.ElideRight
          }
        }

        IconButton {
          shapeMorph: true
          fillWidth: !actions.hasOpen
          inactiveColour: actions.face
          inactiveOnColour: actions.faceOn
          icon: copyTimer.running ? "inventory" : "content_copy"
          padding: Tk.padding.extraSmall
          onClicked: {
            Quickshell.clipboardText = root.bodyText
            copyTimer.restart()
          }

          Timer { id: copyTimer; interval: 3000 }
        }
      }
    }
  }
}
