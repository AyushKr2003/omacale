import QtQuick
import QtQuick.Layouts
import Quickshell
import "../.."

// One app's notifications (Caelestia sidebar/NotifGroup.qml + NotifGroupList):
// a round app image on the left; on the right the app name, age and a
// count/expand pill, then the notifications (the newest few, or all when
// expanded). Group gestures (right-click, vertical drag, swipe) live on the
// dock's delegate; each notification swipes or middle-clicks away on its own.
Rectangle {
  id: root

  property var groupData // { app, appIcon, image, items: [...] }

  readonly property var items: groupData && groupData.items ? groupData.items : []
  readonly property string appName: groupData ? String(groupData.app || "System") : "System"
  readonly property string appIcon: groupData ? String(groupData.appIcon || "") : ""
  readonly property string image: groupData ? String(groupData.image || "") : ""
  readonly property bool expanded: NotifService.isExpanded(appName)
  readonly property var shown: expanded ? items : items.slice(0, Config.o.notifs.groupPreviewNum)
  readonly property int urgency: {
    let u = 0
    for (const n of items) u = Math.max(u, NotifService.urgencyOf(n))
    return u // 0 low, 1 normal, 2 critical
  }
  readonly property bool critical: urgency === 2
  readonly property bool low: urgency === 0
  readonly property color onIcon: critical ? Colours.m3onError : low ? Colours.m3onSurface : Colours.m3onSecondaryContainer
  readonly property real imageSize: Tk.sizes.notifImage

  // Height the card settles at; the dock sizes its slot from this so both
  // animate together instead of chasing each other.
  property int listRev: 0
  readonly property real listHeight: {
    listRev
    let h = 0, n = 0
    for (let i = 0; i < repeater.count; i++) {
      const it = repeater.itemAt(i)
      if (it) { h += it.nonAnimHeight; n++ }
    }
    return h + Math.max(0, n - 1) * list.spacing
  }
  readonly property real nonAnimHeight: {
    const headerHeight = header.implicitHeight + (expanded ? Math.round(Tk.spacing.extraSmall) : 0)
    return Math.round(Math.max(imageSize, headerHeight + listHeight) + Tk.padding.medium * 2)
  }

  function toggleExpand(expand) { NotifService.setExpanded(appName, expand) }
  function fileUrl(p) { return p.indexOf("/") === 0 ? "file://" + p : p }
  function iconUrl(p) { return p.indexOf("/") === -1 ? Quickshell.iconPath(p, true) : fileUrl(p) }

  radius: Tk.rounding.large
  color: Colours.layer(Colours.palette.m3surfaceContainer, 2)
  clip: true
  implicitHeight: nonAnimHeight
  Behavior on implicitHeight { Anim {} }

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
        color: root.critical ? Colours.m3error : root.low ? Colours.layer(Colours.palette.m3surfaceContainerHigh, 3) : Colours.m3secondaryContainer
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
        AppIcon {
          anchors.centerIn: parent
          visible: root.image === "" && root.appIcon !== ""
          size: Math.round(root.imageSize * 0.6)
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
        implicitWidth: Tk.sizes.notifBadge
        implicitHeight: Tk.sizes.notifBadge
        radius: Tk.rounding.full
        color: root.critical ? Colours.m3error : root.low ? Colours.palette.m3surfaceContainerHigh : Colours.m3secondaryContainer
        AppIcon {
          anchors.centerIn: parent
          size: Math.round(Tk.sizes.notifBadge * 0.6)
        }
      }
    }

    Column {
      id: column
      Layout.fillWidth: true
      spacing: root.expanded ? Math.round(Tk.spacing.extraSmall) : 0
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
          text: NotifService.timeStr(root.items[0])
          color: Colours.m3outline
          font.pointSize: Tk.body.small
        }

        Rectangle {
          implicitWidth: expandBtn.implicitWidth + Tk.padding.large
          implicitHeight: groupCount.implicitHeight + Tk.padding.extraSmall
          radius: Tk.rounding.full
          color: root.critical ? Colours.m3error : Colours.layer(Colours.palette.m3surfaceContainerHigh, 3)

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
        spacing: Math.round(Tk.spacing.extraSmall)

        Repeater {
          id: repeater
          model: root.shown
          onItemAdded: root.listRev++
          onItemRemoved: root.listRev++

          // Caelestia NotifGroupList's delegate.
          delegate: MouseArea {
            id: row
            required property var modelData
            readonly property real nonAnimHeight: notif.nonAnimHeight
            property int startY
            property bool closing: false

            function close() {
              if (closing) return
              closing = true
              closeAnim.start()
            }

            width: list.width
            implicitHeight: notif.implicitHeight
            height: notif.implicitHeight
            hoverEnabled: true
            cursorShape: pressed ? Qt.ClosedHandCursor : undefined
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            preventStealing: !root.expanded
            enabled: !closing
            drag.target: this
            drag.axis: Drag.XAxis
            Behavior on x { enabled: !row.closing; Anim {} }

            onPressed: e => {
              startY = e.y
              if (e.button === Qt.RightButton) root.toggleExpand(!root.expanded)
              else if (e.button === Qt.MiddleButton) close()
            }
            onPositionChanged: e => {
              if (pressed && !root.expanded && Math.abs(e.y - startY) > 20) root.toggleExpand(e.y - startY > 0)
            }
            onReleased: {
              if (Math.abs(x) < width * 0.3) x = 0
              else close()
            }

            // Slide out, then drop the record.
            ParallelAnimation {
              id: closeAnim
              Anim { target: row; property: "opacity"; to: 0; type: "effects" }
              Anim { target: row; property: "x"; to: row.x >= 0 ? row.width : -row.width }
              onFinished: NotifService.dismiss(row.modelData)
            }

            NotifItem {
              id: notif
              width: parent.width
              modelData: row.modelData
              expanded: root.expanded
              onDismissRequested: row.close()
            }
          }
        }
      }
    }
  }

  // Caelestia tints only symbolic icons; coloured app icons keep their colours.
  component AppIcon: Item {
    id: ai
    property real size
    readonly property bool symbolic: root.appIcon.endsWith("symbolic")
    implicitWidth: size
    implicitHeight: size

    ColouredIcon {
      anchors.fill: parent
      visible: ai.symbolic
      implicitSize: ai.size
      source: ai.symbolic && ai.size > 0 ? root.iconUrl(root.appIcon) : ""
      colour: root.onIcon
    }
    Image {
      anchors.fill: parent
      visible: !ai.symbolic
      source: !ai.symbolic && root.appIcon !== "" && ai.size > 0 ? root.iconUrl(root.appIcon) : ""
      sourceSize: Qt.size(ai.size * 2, ai.size * 2)
      fillMode: Image.PreserveAspectFit
      asynchronous: true
    }
  }
}
