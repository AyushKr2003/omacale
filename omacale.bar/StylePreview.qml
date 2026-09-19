import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell

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
        readonly property real bw: Tk.barWidth * s
        readonly property real bt: Tk.border * s
        readonly property real dw: 860 * s
        readonly property real dh: 360 * s
        layer.enabled: Config.o.appearance.shadow
        layer.effect: MultiEffect { shadowEnabled: true; blurMax: 12; shadowColor: Qt.alpha("black", 0.6) }

        ShaderEffect {
          anchors.fill: parent
          fragmentShader: Qt.resolvedUrl("shaders/blob.frag.qsb")
          property size res: Qt.size(width, height)
          property real smoothing: Tk.smoothing * parent.s
          property real holeRadius: Tk.borderRounding * parent.s
          property real panelRadius: Tk.rounding.extraLarge * parent.s
          property rect hole: Qt.rect(parent.bw, parent.bt, width - parent.bw - parent.bt, height - 2 * parent.bt)
          property color color: Colours.m3surface
          property rect r0: Qt.rect(parent.bw + (width - parent.bw - parent.bt - parent.dw) / 2, parent.bt, parent.dw, parent.dh)
          property rect r1: Qt.rect(0, 0, 0, 0)
          property rect r2: Qt.rect(0, 0, 0, 0)
          property rect r3: Qt.rect(0, 0, 0, 0)
          property rect r4: Qt.rect(0, 0, 0, 0)
          property rect r5: Qt.rect(0, 0, 0, 0)
          // Edge each drawer grows out of (0 none, 1 top, 2 right, 3 bottom, 4 left).
          property vector4d attachA: Qt.vector4d(1, 0, 0, 0)
          property vector4d attachB: Qt.vector4d(0, 0, 0, 0)
        }

        // mini bar
        Column {
          x: (parent.bw - width) / 2
          y: 16 * parent.s
          spacing: 12 * parent.s
          width: 40 * parent.s
          Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 19 * card.s; height: width; radius: 4 * card.s; color: Colours.m3tertiary }
          Rectangle {
            width: parent.width; height: 5 * 36 * card.s + 8 * card.s
            radius: width / 2
            color: Colours.m3surfaceContainer
            Rectangle { x: 4 * card.s; y: 4 * card.s; width: parent.width - 8 * card.s; height: 32 * card.s; radius: width / 2; color: Colours.m3primary }
            Column {
              y: 4 * card.s + 32 * card.s + 4 * card.s
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: 4 * card.s
              Repeater { model: 4; Item { width: 32 * card.s; height: 32 * card.s
                Rectangle { anchors.centerIn: parent; width: (index === 0 ? 11 : 8) * card.s; height: width; radius: index === 0 ? 2 * card.s : width / 2; color: index === 0 ? Colours.m3onSurface : Colours.m3outlineVariant } } }
            }
          }
        }
        Column {
          x: (parent.bw - width) / 2
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 16 * parent.s
          spacing: 12 * parent.s
          width: 40 * parent.s
          Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 18 * card.s; height: 40 * card.s; radius: 4 * card.s; color: Qt.alpha(Colours.m3tertiary, 0.8) }
          Rectangle { width: parent.width; height: 110 * card.s; radius: width / 2; color: Colours.m3surfaceContainer
            Column { anchors.centerIn: parent; spacing: 10 * card.s
              Repeater { model: 3; Rectangle { width: 16 * card.s; height: width; radius: width / 2; color: Colours.m3secondary } } } }
          Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 18 * card.s; height: width; radius: width / 2; color: Colours.m3error }
        }

        // mini dashboard cards
        Grid {
          x: parent.bw + (parent.width - parent.bw - parent.bt - parent.dw) / 2 + 16 * card.s
          y: parent.bt + 70 * card.s
          columns: 3
          spacing: 12 * card.s
          Rectangle { width: 275 * card.s; height: 120 * card.s; radius: 42 * card.s; color: Colours.m3surfaceContainer
            Rectangle { x: 30 * card.s; anchors.verticalCenter: parent.verticalCenter; width: 60 * card.s; height: width; radius: width / 2; color: Colours.m3secondary } }
          Rectangle { width: 340 * card.s; height: 120 * card.s; radius: 28 * card.s; color: Colours.m3surfaceContainer
            Rectangle { x: 20 * card.s; y: 16 * card.s; width: 46 * card.s; height: width; radius: 12 * card.s; color: Colours.m3primaryContainer }
            Rectangle { x: 90 * card.s; y: 20 * card.s; width: 120 * card.s; height: 32 * card.s; radius: height / 2; color: Colours.m3secondaryContainer } }
          Rectangle { width: 170 * card.s; height: 250 * card.s; radius: 56 * card.s; color: Colours.m3surfaceContainer
            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 20 * card.s; width: 120 * card.s; height: width; radius: width / 2; color: Colours.m3surfaceContainerHigh; border.width: 5 * card.s; border.color: Colours.m3primary } }
        }
      }
    }
  }

  // Theme actions (Caelestia's "Wallpapers" / "Colours" buttons)
  RowLayout {
    Layout.alignment: Qt.AlignHCenter
    spacing: Tk.spacing.small
    component Action: Rectangle {
      id: a
      property string icon
      property string label
      property string cmd
      implicitWidth: ar.implicitWidth + Tk.padding.large * 2
      implicitHeight: ar.implicitHeight + Tk.padding.small * 2
      radius: st.pressed ? Tk.rounding.small : height / 2
      color: Colours.m3secondaryContainer
      Behavior on radius { Anim { type: "fastSpatial" } }
      StateLayer { id: st; color: Colours.m3onSecondaryContainer; onClicked: Sys.run(a.cmd) }
      Row {
        id: ar
        anchors.centerIn: parent
        spacing: Tk.spacing.small
        MIcon { anchors.verticalCenter: parent.verticalCenter; text: a.icon; fill: 1; color: Colours.m3onSecondaryContainer }
        MText { anchors.verticalCenter: parent.verticalCenter; text: a.label; color: Colours.m3onSecondaryContainer; weight: Font.Medium }
      }
    }
    Action { icon: "wallpaper"; label: "Wallpaper"; cmd: 'background=$(omarchy-theme-bg-switcher); [[ -n $background ]] && omarchy-theme-bg-set "$background"' }
    Action { icon: "skip_next"; label: "Next wallpaper"; cmd: "omarchy-theme-bg-next" }
    Action { icon: "palette"; label: "Theme"; cmd: 'theme=$(omarchy-theme-switcher); [[ -n $theme ]] && omarchy-theme-set "$theme"' }
  }
}
