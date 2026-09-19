import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

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

        NotifDock { anchors.fill: parent; active: root.active }
      }

      Rectangle {
        Layout.topMargin: Tk.padding.large - Tk.spacing.medium
        Layout.fillWidth: true
        implicitHeight: 1
        color: Colours.m3outlineVariant
      }
    }
  }

  // Notification dock (Caelestia sidebar/NotifDock.qml).
  component NotifDock: Item {
    id: dock
    property bool active: false
    readonly property int notifCount: NotifService.count

    Item {
      id: title
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.margins: Tk.padding.medium + Tk.padding.extraSmall
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
      anchors.margins: Tk.padding.medium
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
            sourceSize.width: clipRect.width * 0.8

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
        contentHeight: listCol.implicitHeight
        clip: true
        ScrollBar.vertical: MScrollBar { flickable: view }

        ColumnLayout {
          id: listCol
          width: view.width
          spacing: Tk.spacing.small

          Repeater {
            model: NotifService.groups
            delegate: NotifGroup {
              Layout.fillWidth: true
              groupData: modelData
            }
          }
        }
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
        onClicked: NotifService.clearAll()

        // Elevation 3/4 shadow
        layer.enabled: true
        layer.effect: MultiEffect {
          shadowEnabled: true
          shadowColor: Qt.alpha(Colours.m3shadow, 0.55)
          shadowBlur: clearBtn.stateLayer.containsMouse ? 0.9 : 0.6
          shadowVerticalOffset: clearBtn.stateLayer.containsMouse ? 4 : 3
        }
      }
    }
  }
}
