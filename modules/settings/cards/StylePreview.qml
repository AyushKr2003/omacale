import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import "../../.."

// Caelestia's wallpaper card, upgraded: the current wallpaper with a live
// miniature of Omacale on top, drawn by the same blob shader as the real
// frame, so every colour/border/rounding change is previewed instantly.
ColumnLayout {
  id: root
  property var settings
  property var row
  property bool first
  property bool last
  spacing: Tk.spacing.large

  readonly property real sw: settings ? settings.screenWidth : 1920
  readonly property real sh: settings ? settings.screenHeight : 1080

  Item {
    id: card
    Layout.alignment: Qt.AlignHCenter
    Layout.fillWidth: true
    implicitHeight: Math.round(width / root.sw * root.sh)
    readonly property real s: width / root.sw
    // The miniature UI at Omacale's scale; the frame (border, rounding) is px, so `s`.
    readonly property real u: s * Tk.uiScale

    Rectangle { id: mask; anchors.fill: parent; radius: Tk.rounding.large; visible: false; layer.enabled: true }

    Item {
      anchors.fill: parent
      layer.enabled: true
      layer.effect: ShaderMaskEffect { maskItem: mask }

      Rectangle { anchors.fill: parent; color: Colours.m3surfaceContainer }
      Image {
        anchors.fill: parent
        source: "file://" + Quickshell.env("HOME") + "/.local/state/omarchy/current/background"
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: 1024
        asynchronous: true
        cache: false
      }

      // Miniature shell
      Item {
        anchors.fill: parent
        readonly property real s: card.s
        readonly property real u: card.u
        readonly property real bw: Tk.barWidth * s
        readonly property real bt: Tk.border * s
        // The frame's breadth on each edge: the bar's on its own, the border's elsewhere.
        readonly property real il: Tk.barEdge === "left" ? bw : bt
        readonly property real ir: Tk.barEdge === "right" ? bw : bt
        readonly property real it: Tk.barEdge === "top" ? bw : bt
        readonly property real ib: Tk.barEdge === "bottom" ? bw : bt
        readonly property real dw: 860 * u
        readonly property real dh: 360 * u
        layer.enabled: Config.o.appearance.shadow
        layer.effect: MultiEffect { shadowEnabled: true; blurMax: 12; shadowColor: Qt.alpha("black", 0.6) }

        BlobSurface {
          anchors.fill: parent
          smoothing: Tk.smoothing * parent.s
          frameRadius: Tk.borderRounding * parent.s
          radius: Tk.rounding.extraLarge * parent.s
          hole: Qt.rect(parent.il, parent.it, width - parent.il - parent.ir, height - parent.it - parent.ib)
          rects: [[parent.il + (width - parent.il - parent.ir - parent.dw) / 2, parent.it, parent.dw, parent.dh]]
        }

        // mini bar: a strip along the left edge, turned a quarter for the top and
        // bottom ones (its start stays at the left) and moved across for the
        // right and bottom.
        Item {
          id: miniBar
          readonly property bool vert: Tk.barVertical
          width: parent.bw
          height: vert ? parent.height : parent.width
          transformOrigin: Item.TopLeft
          rotation: vert ? 0 : -90
          x: Tk.barEdge === "right" ? parent.width - parent.bw : 0
          y: Tk.barEdge === "top" ? parent.bw : Tk.barEdge === "bottom" ? parent.height : 0

          Column {
            x: (miniBar.width - width) / 2
            y: 16 * card.u
            spacing: 12 * card.u
            width: 40 * card.u
            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 19 * card.u; height: width; radius: 4 * card.u; color: Colours.m3tertiary }
            Rectangle {
              width: parent.width; height: 5 * 36 * card.u + 8 * card.u
              radius: width / 2
              color: Colours.m3surfaceContainer
              Rectangle { x: 4 * card.u; y: 4 * card.u; width: parent.width - 8 * card.u; height: 32 * card.u; radius: width / 2; color: Colours.m3primary }
              Column {
                y: 4 * card.u + 32 * card.u + 4 * card.u
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 4 * card.u
                Repeater { model: 4; Item { width: 32 * card.u; height: 32 * card.u
                  Rectangle { anchors.centerIn: parent; width: (index === 0 ? 11 : 8) * card.u; height: width; radius: index === 0 ? 2 * card.u : width / 2; color: index === 0 ? Colours.m3onSurface : Colours.m3outlineVariant } } }
              }
            }
          }
          Column {
            x: (miniBar.width - width) / 2
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 16 * card.u
            spacing: 12 * card.u
            width: 40 * card.u
            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 18 * card.u; height: 40 * card.u; radius: 4 * card.u; color: Qt.alpha(Colours.m3tertiary, 0.8) }
            Rectangle { width: parent.width; height: 110 * card.u; radius: width / 2; color: Colours.m3surfaceContainer
              Column { anchors.centerIn: parent; spacing: 10 * card.u
                Repeater { model: 3; Rectangle { width: 16 * card.u; height: width; radius: width / 2; color: Colours.m3secondary } } } }
            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 18 * card.u; height: width; radius: width / 2; color: Colours.m3error }
          }
        }

        // mini dashboard cards
        Grid {
          x: parent.il + (parent.width - parent.il - parent.ir - parent.dw) / 2 + 16 * card.u
          y: parent.it + 70 * card.u
          columns: 3
          spacing: 12 * card.u
          Rectangle { width: 275 * card.u; height: 120 * card.u; radius: 42 * card.u; color: Colours.m3surfaceContainer
            Rectangle { x: 30 * card.u; anchors.verticalCenter: parent.verticalCenter; width: 60 * card.u; height: width; radius: width / 2; color: Colours.m3secondary } }
          Rectangle { width: 340 * card.u; height: 120 * card.u; radius: 28 * card.u; color: Colours.m3surfaceContainer
            Rectangle { x: 20 * card.u; y: 16 * card.u; width: 46 * card.u; height: width; radius: 12 * card.u; color: Colours.m3primaryContainer }
            Rectangle { x: 90 * card.u; y: 20 * card.u; width: 120 * card.u; height: 32 * card.u; radius: height / 2; color: Colours.m3secondaryContainer } }
          Rectangle { width: 170 * card.u; height: 250 * card.u; radius: 56 * card.u; color: Colours.m3surfaceContainer
            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 20 * card.u; width: 120 * card.u; height: width; radius: width / 2; color: Colours.m3surfaceContainerHigh; border.width: 5 * card.u; border.color: Colours.m3primary } }
        }
      }
    }
  }

  // Theme actions (Caelestia's "Wallpapers" / "Colours" buttons): a
  // ButtonRow of tonal pills that bulge when pressed. Sized as the other
  // Settings action buttons (body.medium, padding large/small): Caelestia's
  // body.large with extra-large padding came out bigger than anything else
  // on the page, with three buttons where Caelestia has two.
  ButtonRow {
    Layout.alignment: Qt.AlignHCenter
    spacing: Tk.spacing.small
    component Action: IconTextButton {
      property string cmd
      type: "tonal"
      isRound: true
      shapeMorph: true
      fontSize: Tk.body.medium
      horizontalPadding: Tk.padding.large
      verticalPadding: Tk.padding.small
      onClicked: Sys.run(cmd)
    }
    Action { icon: "wallpaper"; text: "Wallpaper"; cmd: 'background=$(omarchy-theme-bg-switcher); [[ -n $background ]] && omarchy-theme-bg-set "$background"' }
    Action { icon: "skip_next"; text: "Next wallpaper"; cmd: "omarchy-theme-bg-next" }
    Action { icon: "palette"; text: "Theme"; cmd: 'theme=$(omarchy-theme-switcher); [[ -n $theme ]] && omarchy-theme-set "$theme"' }
  }
}
