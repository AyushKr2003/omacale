import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Window

// Sidebar drawer (Caelestia modules/sidebar): a rounded surfaceContainerLow
// card holding the notification dock, with a hairline under it where the
// utilities drawer attaches. The drawer background is drawn by the shader.
Item {
  id: root

  property var host
  property var scope
  property bool active: false

  // The frame already supplies `border` of the inset on top and right.
  readonly property real edgePad: Math.max(0, Tk.padding.large - Tk.border)

  Item {
    id: content
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.leftMargin: Tk.padding.large
    anchors.topMargin: root.edgePad
    anchors.rightMargin: root.edgePad

    ColumnLayout {
      anchors.fill: parent
      spacing: Tk.spacing.medium

      Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: Tk.rounding.large
        color: Colours.m3surfaceContainerLow

        NotifDock {
          anchors.fill: parent
          anchors.margins: Tk.padding.medium
        }
      }

      Rectangle {
        Layout.topMargin: Tk.padding.large - Tk.spacing.medium
        Layout.fillWidth: true
        implicitHeight: 1
        color: Colours.layer(Colours.m3outlineVariant)
      }
    }
  }

  // Notification dock (Caelestia sidebar/NotifDock.qml + NotifDockList.qml).
  component NotifDock: Item {
    id: dock
    readonly property int notifCount: NotifService.count
    // Off until the first sync, so opening the sidebar doesn't animate every
    // group in (Caelestia's list is already populated by then).
    property bool populated: false

    // Groups keyed by app name, like Caelestia's ScriptModel over app names:
    // a group keeps its delegate while its notifications change, moves when a
    // newer notification reorders it, and is marked `closing` (animated out,
    // then removed) instead of vanishing.
    ListModel { id: apps }
    function indexOf(app) {
      for (let i = 0; i < apps.count; i++) if (apps.get(i).app === app) return i
      return -1
    }
    function sync() {
      const want = NotifService.groups.map(g => g.app)
      for (let i = 0; i < apps.count; i++) {
        const gone = want.indexOf(apps.get(i).app) === -1
        if (apps.get(i).closing !== gone) apps.setProperty(i, "closing", gone)
      }
      let pos = 0
      for (const app of want) {
        while (pos < apps.count && apps.get(pos).closing) pos++
        const idx = indexOf(app)
        if (idx === -1) apps.insert(pos, { app: app, closing: false })
        else if (idx !== pos) apps.move(idx, pos, 1)
        pos++
      }
      populated = true
    }
    function remove(app) {
      const i = indexOf(app)
      if (i !== -1 && apps.get(i).closing) apps.remove(i)
    }
    Connections { target: NotifService; function onGroupsChanged() { dock.sync() } }
    Component.onCompleted: sync()

    Item {
      id: title
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.margins: Tk.padding.extraSmall
      implicitHeight: Math.max(countText.implicitHeight, titleText.implicitHeight)
      height: implicitHeight

      MText {
        id: countText
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: dock.notifCount > 0 ? 0 : -width - titleText.anchors.leftMargin
        opacity: dock.notifCount > 0 ? 1 : 0
        text: dock.notifCount
        color: Colours.m3outline
        font.pointSize: Tk.label.large
        weight: Font.Medium
        Behavior on anchors.leftMargin { Anim {} }
        Behavior on opacity { Anim { type: "effects" } }
      }

      MText {
        id: titleText
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: countText.right
        anchors.right: parent.right
        anchors.leftMargin: Tk.spacing.extraSmall
        text: dock.notifCount > 0 ? (dock.notifCount === 1 ? "notification" : "notifications") : "Notifications"
        color: Colours.m3outline
        font.pointSize: Tk.label.large
        weight: Font.Medium
        elide: Text.ElideRight
      }
    }

    // The list is clipped to a rounded rect, as Caelestia's ClippingRectangle.
    Item {
      id: clipRect
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: title.bottom
      anchors.bottom: parent.bottom
      anchors.topMargin: Tk.spacing.medium

      layer.enabled: true
      layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: clipMask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
      }
      Rectangle {
        id: clipMask
        anchors.fill: parent
        radius: Tk.rounding.medium
        visible: false
        layer.enabled: true
      }

      // Empty state
      Loader {
        anchors.centerIn: parent
        active: opacity > 0
        opacity: dock.notifCount > 0 ? 0 : 1
        Behavior on opacity { Anim { type: "standardExtraLarge" } }

        sourceComponent: ColumnLayout {
          spacing: Tk.spacing.extraLarge

          Image {
            Layout.alignment: Qt.AlignHCenter
            source: Qt.resolvedUrl("assets/dino.png")
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            sourceSize.width: clipRect.width * 0.8 * Screen.devicePixelRatio

            layer.enabled: true
            layer.effect: MultiEffect {
              colorization: 1
              brightness: 1
              colorizationColor: Colours.m3outlineVariant
            }
          }

          MText {
            Layout.alignment: Qt.AlignHCenter
            text: "All up to date!"
            color: Colours.m3outlineVariant
            font.pointSize: Tk.headline.small
            weight: Font.Medium
            // Caelestia: headline.builders.small.width(90)
            axes: ({ "ROND": 25, "wdth": 90 })
          }
        }
      }

      MFlickable {
        id: view
        anchors.fill: parent
        flickableDirection: Flickable.VerticalFlick
        contentWidth: width
        contentHeight: Math.max(0, listCol.height - Tk.spacing.small)
        ScrollBar.vertical: MScrollBar { flickable: view }

        // Each slot carries the list spacing under it, so a closing group's
        // gap shrinks with it.
        Column {
          id: listCol
          width: view.width

          Repeater {
            model: apps

            // Caelestia NotifDockList's delegate.
            delegate: MouseArea {
              id: slot
              required property string app
              required property bool closing
              property var group: null
              property bool adding: dock.populated
              property int startY

              function refresh() {
                const g = NotifService.groups.find(g => g.app === slot.app)
                if (g) group = g
              }
              function closeAll() { NotifService.dismissGroup(slot.app) }

              Connections { target: NotifService; function onGroupsChanged() { slot.refresh() } }
              // Rows made by the first sync start settled; later ones grow
              // in. Assigning breaks the binding either way.
              Component.onCompleted: {
                refresh()
                if (adding) Qt.callLater(() => slot.adding = false)
                else adding = false
              }

              width: listCol.width
              height: closing || adding ? 0 : inner.nonAnimHeight + Tk.spacing.small
              Behavior on height { Anim {} }

              opacity: closing || adding ? 0 : 1
              Behavior on opacity { Anim { type: "effects" } }
              Behavior on x { Anim {} }

              hoverEnabled: true
              cursorShape: pressed ? Qt.ClosedHandCursor : undefined
              acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
              preventStealing: true
              enabled: !closing
              drag.target: this
              drag.axis: Drag.XAxis

              onPressed: e => {
                startY = e.y
                if (e.button === Qt.RightButton) inner.toggleExpand(!inner.expanded)
                else if (e.button === Qt.MiddleButton) closeAll()
              }
              onPositionChanged: e => {
                if (pressed && Math.abs(e.y - startY) > 20) inner.toggleExpand(e.y - startY > 0)
              }
              onReleased: {
                if (Math.abs(x) < width * 0.3) x = 0
                else closeAll()
              }

              // Drop the row once its close animation has played.
              Timer {
                running: slot.closing
                interval: Tk.durations.normal
                onTriggered: dock.remove(slot.app)
              }

              NotifGroup {
                id: inner
                width: parent.width
                groupData: slot.group
                scale: slot.closing ? 0.6 : slot.adding ? 0 : 1
                Behavior on scale { Anim {} }
              }
            }
          }
        }
      }
    }

    // Caelestia clears one app at a time, faster the more there are.
    Timer {
      id: clearTimer
      property string last: ""
      repeat: true
      triggeredOnStart: true
      interval: Math.max(15, Math.min(80, 69.8 - 12.3 * Math.log(Math.max(1, NotifService.count))))
      onTriggered: {
        const g = NotifService.groups[0]
        if (!g || g.app === last) {
          stop()
          last = ""
          NotifService.clearAll()
          return
        }
        last = g.app
        NotifService.dismissGroup(g.app)
      }
    }

    // Clear-all button
    Loader {
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.margins: Tk.padding.medium
      scale: dock.notifCount > 0 ? 1 : 0.5
      opacity: dock.notifCount > 0 ? 1 : 0
      active: opacity > 0
      Behavior on scale { Anim { type: "fastSpatial" } }
      Behavior on opacity { Anim { type: "effects" } }

      sourceComponent: IconButton {
        id: clearBtn
        icon: "clear_all"
        iconSize: Tk.iconSize.large
        onClicked: clearTimer.start()

        Elevation {
          anchors.fill: parent
          radius: parent.radius
          z: -1
          level: clearBtn.stateLayer.containsMouse ? 4 : 3
        }
      }
    }
  }
}
