import QtQuick
import QtQuick.Layouts
import Quickshell

// One app's notifications (Caelestia sidebar/NotifGroup.qml): a round app
// image on the left; on the right the app name, time and a count/expand pill,
// then the notifications (the newest few, or all when expanded).
// Right-click or drag vertically to expand, middle-click or swipe to dismiss.
Rectangle {
  id: root

  property var groupData // { app, appIcon, image, items: [...] }

  readonly property var items: groupData && groupData.items ? groupData.items : []
  readonly property string appName: groupData ? String(groupData.app || "System") : "System"
  readonly property string appIcon: groupData ? String(groupData.appIcon || "") : ""
  readonly property string image: groupData ? String(groupData.image || "") : ""
  readonly property bool expanded: NotifService.isExpanded(appName)
  readonly property int previewNum: 3
  readonly property var shown: expanded ? items : items.slice(0, previewNum)
  readonly property int urgency: {
    let u = 0
    for (const n of items) u = Math.max(u, n.urgency || 0)
    return u // 0 low, 1 normal, 2 critical
  }
  readonly property bool critical: urgency === 2
  readonly property bool low: urgency === 0
  readonly property color onIcon: critical ? Colours.m3onError : low ? Colours.m3onSurface : Colours.m3onSecondaryContainer
  readonly property real imageSize: 42

  function toggleExpand(expand) { NotifService.setExpanded(appName, expand) }
  function fileUrl(p) { return p.indexOf("/") === 0 ? "file://" + p : p }
  function timeOf(n) {
    return n && n.timestamp ? Sys.time(new Date(n.timestamp)) : ""
  }

  radius: Tk.rounding.large
  color: Colours.m3surfaceContainer
  clip: true
  implicitHeight: Math.round(Math.max(imageSize, column.implicitHeight) + Tk.padding.medium * 2)
  Behavior on implicitHeight { Anim {} }

  // Group-level gestures live under the notifications so their own win.
  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.RightButton | Qt.MiddleButton
    onPressed: e => {
      if (e.button === Qt.RightButton) root.toggleExpand(!root.expanded)
      else NotifService.dismissGroup(root.appName)
    }
  }

  RowLayout {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: Tk.padding.medium
    spacing: Tk.spacing.medium

    Item {
      Layout.alignment: Qt.AlignLeft | Qt.AlignTop
      implicitWidth: root.imageSize
      implicitHeight: root.imageSize

      Rectangle {
        id: circle
        anchors.fill: parent
        radius: Tk.rounding.full
        color: root.critical ? Colours.m3error : root.low ? Colours.m3surfaceContainerHigh : Colours.m3secondaryContainer
        clip: true

        // Photo, else the app's icon, else a glyph picked from the summary.
        Image {
          anchors.fill: parent
          visible: root.image !== ""
          source: root.image !== "" ? root.fileUrl(root.image) : ""
          fillMode: Image.PreserveAspectCrop
          sourceSize: Qt.size(root.imageSize * 2, root.imageSize * 2)
          asynchronous: true
          cache: false
        }
        Image {
          anchors.centerIn: parent
          width: Math.round(root.imageSize * 0.6)
          height: width
          visible: root.image === "" && root.appIcon !== ""
          source: visible ? (root.appIcon.indexOf("/") === -1 ? Quickshell.iconPath(root.appIcon, true) : root.fileUrl(root.appIcon)) : ""
          sourceSize: Qt.size(width * 2, height * 2)
          fillMode: Image.PreserveAspectFit
          asynchronous: true
        }
        MIcon {
          anchors.centerIn: parent
          anchors.verticalCenterOffset: 1
          visible: root.image === "" && root.appIcon === ""
          text: NotifService.notifIcon(root.items.length ? root.items[0].summary : "", root.urgency)
          size: Tk.iconSize.medium
          color: root.onIcon
        }
      }

      // App badge over a photo
      Rectangle {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: root.appIcon !== "" && root.image !== ""
        implicitWidth: 20
        implicitHeight: 20
        radius: Tk.rounding.full
        color: root.critical ? Colours.m3error : root.low ? Colours.m3surfaceContainerHigh : Colours.m3secondaryContainer
        Image {
          anchors.centerIn: parent
          width: 12
          height: 12
          source: root.appIcon.indexOf("/") === -1 ? Quickshell.iconPath(root.appIcon, true) : root.fileUrl(root.appIcon)
          sourceSize: Qt.size(24, 24)
          fillMode: Image.PreserveAspectFit
        }
      }
    }

    Column {
      id: column
      Layout.fillWidth: true
      spacing: root.expanded ? Tk.spacing.extraSmall : 0
      Behavior on spacing { Anim {} }

      RowLayout {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Tk.spacing.small

        MText {
          Layout.fillWidth: true
          text: root.appName
          color: Colours.m3onSurfaceVariant
          font.pointSize: Tk.body.small
          elide: Text.ElideRight
        }
        MText {
          animate: true
          text: root.timeOf(root.items.length ? root.items[0] : null)
          color: Colours.m3outline
          font.pointSize: Tk.body.small
        }

        Rectangle {
          implicitWidth: expandBtn.implicitWidth + Tk.padding.large
          implicitHeight: groupCount.implicitHeight + Tk.padding.extraSmall
          radius: Tk.rounding.full
          color: root.critical ? Colours.m3error : Colours.m3surfaceContainerHigh

          StateLayer {
            color: root.critical ? Colours.m3onError : Colours.m3onSurface
            onClicked: root.toggleExpand(!root.expanded)
          }

          RowLayout {
            id: expandBtn
            anchors.centerIn: parent
            spacing: Tk.spacing.extraSmall

            MText {
              id: groupCount
              Layout.leftMargin: Tk.padding.extraSmall / 2
              animate: true
              text: root.items.length
              color: root.critical ? Colours.m3onError : Colours.m3onSurfaceVariant
              font.pointSize: Tk.body.small
            }
            MIcon {
              Layout.rightMargin: -Tk.padding.extraSmall / 2
              Layout.topMargin: root.expanded ? -Math.floor(Tk.padding.extraSmall) : 0
              text: "expand_more"
              color: root.critical ? Colours.m3onError : Colours.m3onSurfaceVariant
              rotation: root.expanded ? 180 : 0
              Behavior on rotation { Anim {} }
              Behavior on Layout.topMargin { Anim {} }
            }
          }
        }
      }

      Column {
        id: list
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Tk.spacing.extraSmall

        Repeater {
          model: root.shown

          delegate: MouseArea {
            id: row
            required property var modelData
            property int startY

            width: list.width
            implicitHeight: notif.implicitHeight
            height: notif.implicitHeight
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            preventStealing: !root.expanded
            drag.target: this
            drag.axis: Drag.XAxis

            opacity: 1 - Math.min(1, Math.abs(x) / width)
            Behavior on x { Anim {} }

            onPressed: e => {
              startY = e.y
              if (e.button === Qt.RightButton) root.toggleExpand(!root.expanded)
              else if (e.button === Qt.MiddleButton) NotifService.dismiss(modelData)
            }
            onPositionChanged: e => {
              if (pressed && !root.expanded && Math.abs(e.y - startY) > 20) root.toggleExpand(e.y - startY > 0)
            }
            onReleased: {
              if (Math.abs(x) < width * 0.3) x = 0
              else NotifService.dismiss(modelData)
            }

            NotifItem {
              id: notif
              width: parent.width
              modelData: row.modelData
              expanded: root.expanded
              onDismissRequested: NotifService.dismiss(row.modelData)
            }
          }
        }
      }
    }
  }
}
