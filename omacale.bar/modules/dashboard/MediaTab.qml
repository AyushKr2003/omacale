import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Services.Mpris
import "../.."

// Caelestia dashboard "Media" tab: drifting background shapes, a spinning
// cookie-shaped cover ringed by an audio visualiser, track details with a
// wavy seek bar, and synced lyrics with a player selector.
Item {
  id: root
  property bool active: false
  readonly property var player: Sys.player
  readonly property bool playing: player ? player.isPlaying : false
  // Keys (ScreenScope's drawer cursor): n / p next and previous track.
  function navText(t) {
    if (!player) return
    if (t === "n" && player.canGoNext) player.next()
    else if (t === "p" && player.canGoPrevious) player.previous()
  }
  readonly property int sectionWidth: 300
  readonly property int coverSize: 200

  implicitWidth: 1000
  implicitHeight: 320

  // The visualiser only runs while this tab is on screen and music plays.
  readonly property bool wantVis: active && visible && playing && Config.o.dashboard.visualiser
  onWantVisChanged: Sys.visualiserWanted += wantVis ? 1 : -1
  Component.onDestruction: if (wantVis) Sys.visualiserWanted -= 1

  Timer {
    running: root.active && root.playing
    interval: Config.o.services.mediaUpdateInterval
    repeat: true
    triggeredOnStart: true
    onTriggered: if (root.player) root.player.positionChanged()
  }

  // ------------------------------------------------ drifting shapes
  Item {
    id: bg
    anchors.fill: parent
    clip: true
    readonly property var pool: ["circle", "cookie4", "cookie6", "cookie7", "cookie9", "cookie12", "sunny", "verySunny", "softBurst", "pentagon", "gem", "arch", "arrow", "pill", "triangle", "fan", "oval"]
    function rand(a, b) { return a + Math.random() * (b - a) }
    function srand(a, b) { return rand(a, b) * (Math.random() < 0.5 ? -1 : 1) }
    Repeater {
      id: drift
      model: 14
      MShape {
        required property int index
        property real vx: bg.srand(4, 18)
        property real vy: bg.srand(4, 18)
        property real vr: bg.rand(-12, 12)
        readonly property int ci: Math.floor(Math.random() * 4)
        implicitSize: 36 + (index / 14) * (124 - 36)
        width: implicitSize; height: implicitSize
        shape: bg.pool[Math.floor(Math.random() * bg.pool.length)]
        color: [Colours.m3primaryContainer, Colours.m3secondaryContainer, Colours.m3tertiaryContainer, Colours.m3outlineVariant][ci]
        opacity: Colours.light ? [0.34, 0.34, 0.08, 0.2][ci] : [0.16, 0.16, 0.04, 0.16][ci]
        rotation: bg.rand(0, 360)
        Component.onCompleted: { x = bg.rand(0, root.width - implicitSize); y = bg.rand(0, root.height - implicitSize) }
      }
    }
    FrameAnimation {
      running: root.active && root.playing && bg.width > 0
      onTriggered: {
        const dt = frameTime
        for (let i = 0; i < drift.count; i++) {
          const s = drift.itemAt(i)
          if (!s) continue
          s.x += s.vx * dt; s.y += s.vy * dt; s.rotation += s.vr * dt
          if (s.x + s.width < 0) s.x = bg.width; else if (s.x > bg.width) s.x = -s.width
          if (s.y + s.height < 0) s.y = bg.height; else if (s.y > bg.height) s.y = -s.height
        }
      }
    }
  }

  RowLayout {
    anchors.fill: parent
    anchors.margins: Tk.padding.large
    spacing: Tk.spacing.extraLarge

    // ------------------------------------------ cover + visualiser
    Item {
      id: vis
      Layout.fillHeight: true
      implicitWidth: root.sectionWidth
      readonly property real cx: width / 2
      readonly property real cy: height / 2
      readonly property real gap: Tk.spacing.medium
      readonly property real barWidth: 360 / Sys.visBars - Tk.spacing.small / 4
      readonly property real maxMag: (root.sectionWidth - root.coverSize) / 2 - gap

      Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        visible: Config.o.dashboard.visualiser
        opacity: Sys.visValues.length ? 1 : 0
        Behavior on opacity { Anim { type: "effects" } }
        ShapePath {
          strokeColor: Colours.m3primary
          strokeWidth: vis.barWidth
          capStyle: ShapePath.RoundCap
          fillColor: "transparent"
          PathMultiline {
            paths: {
              const n = Sys.visBars, v = Sys.visValues, out = []
              cover.shape.rotation   // re-evaluate as the cover turns
              for (let i = 0; i < n; i++) {
                const a = i * 2 * Math.PI / n, deg = i * 360 / n
                const edge = cover.shape.distanceAtAngle(deg) + vis.gap + vis.barWidth / 2
                const d = edge + Math.max(0.01, Math.min(1, v[i] || 0)) * vis.maxMag
                const c = Math.cos(a), s = Math.sin(a)
                out.push([Qt.point(vis.cx + edge * c, vis.cy + edge * s), Qt.point(vis.cx + d * c, vis.cy + d * s)])
              }
              return out
            }
          }
        }
      }
      CoverArt {
        id: cover
        anchors.centerIn: parent
        width: root.coverSize; height: root.coverSize
        shapeName: "cookie9"
        playing: root.playing
        source: root.player && root.player.trackArtUrl ? root.player.trackArtUrl : ""
      }
    }

    // ------------------------------------------ details + lyrics
    Item {
      Layout.fillWidth: true
      Layout.fillHeight: true

      // Nothing playing
      ColumnLayout {
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: -Tk.padding.extraLarge * 2
        spacing: Tk.spacing.small
        opacity: root.player ? 0 : 1
        visible: opacity > 0
        Behavior on opacity { Anim { type: "slowEffects" } }
        MShape {
          Layout.alignment: Qt.AlignHCenter
          Layout.bottomMargin: Tk.spacing.small
          implicitSize: nothingIcon.implicitHeight + Tk.padding.extraLarge * 2
          width: implicitSize; height: implicitSize * 0.8
          shape: "clamShell"
          color: Colours.m3primaryContainer
          MIcon { id: nothingIcon; anchors.centerIn: parent; text: "queue_music"; size: Tk.iconSize.large * 2; color: Colours.m3onPrimaryContainer }
        }
        MText { Layout.alignment: Qt.AlignHCenter; text: "Nothing playing"; font.pointSize: Tk.headline.medium; weight: Font.Medium }
        MText { text: "Play something for it to show up here!"; color: Colours.m3onSurfaceVariant; font.pointSize: Tk.body.large }
      }

      RowLayout {
        anchors.fill: parent
        spacing: Tk.spacing.extraLarge
        opacity: root.player ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { Anim { type: "slowEffects" } }

        // Details
        ColumnLayout {
          id: details
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignVCenter
          spacing: Tk.spacing.extraSmall
          readonly property real len: root.player ? root.player.length : 0
          readonly property bool unknownLen: len <= 0 || len > 2147483647
          function fmt(t) {
            if (t < 0 || isNaN(t)) return "-1:-1"
            const h = Math.floor(t / 3600), m = Math.floor((t % 3600) / 60), s = String(Math.floor(t % 60)).padStart(2, "0")
            return h > 0 ? h + ":" + String(m).padStart(2, "0") + ":" + s : m + ":" + s
          }

          MText { Layout.fillWidth: true; text: root.player ? (root.player.trackTitle || "") : ""; font.pointSize: Tk.title.large; weight: Font.Medium; elide: Text.ElideRight; animate: true }
          MText { Layout.fillWidth: true; text: root.player ? (root.player.trackArtist || "Unknown artist") : ""; color: Colours.m3onSurfaceVariant; font.pointSize: Tk.title.medium; weight: Font.Medium; elide: Text.ElideRight; animate: true }
          MText { Layout.fillWidth: true; text: root.player ? (root.player.trackAlbum || "Unknown album") : ""; color: Colours.m3secondary; font.pointSize: Tk.title.medium; weight: Font.Medium; elide: Text.ElideRight; animate: true }

          RowLayout {
            Layout.topMargin: Tk.spacing.extraLargeIncreased
            Layout.fillWidth: true
            spacing: Tk.spacing.small
            MText {
              id: posLabel
              Layout.preferredWidth: 44
              horizontalAlignment: Text.AlignHCenter
              text: details.fmt(seek.dragging ? seek.pos * details.len : (root.player ? root.player.position : -1))
              color: Colours.m3onSurfaceVariant
              font.pointSize: Tk.label.medium
            }
            MSlider {
              id: seek
              Layout.fillWidth: true
              implicitHeight: 12
              wavy: true
              animateWave: root.playing
              waveFrequency: 5
              value: root.player && !details.unknownLen ? root.player.position / details.len : 0
              interactive: root.player ? root.player.canSeek && !details.unknownLen : false
              fgColour: interactive ? Colours.m3primary : Qt.alpha(Colours.m3onSurface, 0.38)
              interactionOnMove: false
              onMoved: v => { if (root.player && root.player.canSeek) root.player.position = v * details.len }
            }
            MText {
              Layout.preferredWidth: 44
              horizontalAlignment: Text.AlignHCenter
              text: details.unknownLen ? "--:--" : details.fmt(details.len)
              color: Colours.m3onSurfaceVariant
              font.pointSize: Tk.label.medium
            }
          }

          // Caelestia media/Details.qml: a ButtonRow, so a pressed button
          // bulges while its neighbours give way.
          ButtonRow {
            Layout.topMargin: Tk.spacing.largeIncreased
            Layout.fillWidth: true
            implicitHeight: playBtn.implicitHeight
            spacing: Tk.spacing.extraSmall
            IconButton {
              type: "tonal"; icon: "shuffle"; toggle: true
              checked: root.player ? root.player.shuffle : false
              iconSize: Tk.iconSize.medium
              iconWeight: Font.Medium
              shapeMorph: true
              implicitWidth: Math.round(implicitHeight * 0.9)
              disabled: !root.player || !root.player.shuffleSupported
              onClicked: root.player.shuffle = !root.player.shuffle
            }
            IconButton { type: "tonal"; icon: "skip_previous"; iconSize: Tk.iconSize.large; shapeMorph: true; disabled: !root.player || !root.player.canGoPrevious; onClicked: root.player.previous() }
            IconButton {
              id: playBtn
              fillWidth: true
              shapeMorph: true
              icon: root.playing ? "pause" : "play_arrow"
              iconSize: Tk.iconSize.large
              toggle: true; checked: root.playing
              round: !root.playing
              disabled: !root.player || !root.player.canTogglePlaying
              onClicked: root.player.togglePlaying()
            }
            IconButton { type: "tonal"; icon: "skip_next"; iconSize: Tk.iconSize.large; shapeMorph: true; disabled: !root.player || !root.player.canGoNext; onClicked: root.player.next() }
            IconButton {
              type: "tonal"; toggle: true
              icon: root.player && root.player.loopState === MprisLoopState.Track ? "repeat_one" : "repeat"
              checked: root.player ? root.player.loopState !== MprisLoopState.None : false
              iconSize: Tk.iconSize.medium
              iconWeight: Font.Medium
              shapeMorph: true
              implicitWidth: Math.round(implicitHeight * 0.9)
              disabled: !root.player || !root.player.loopSupported
              onClicked: {
                const s = root.player.loopState
                root.player.loopState = s === MprisLoopState.None ? MprisLoopState.Track : s === MprisLoopState.Track ? MprisLoopState.Playlist : MprisLoopState.None
              }
            }
          }
        }

        // Lyrics + player selector
        ColumnLayout {
          Layout.fillHeight: true
          Layout.leftMargin: Tk.padding.medium
          implicitWidth: root.sectionWidth
          Layout.preferredWidth: root.sectionWidth
          spacing: Tk.spacing.medium

          RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: -Tk.spacing.medium
            spacing: Tk.spacing.medium
            z: 1
            MIcon { text: "lyrics"; size: Tk.iconSize.medium }
            MText { Layout.fillWidth: true; text: "Lyrics"; font.pointSize: Tk.title.medium; weight: Font.Medium }
            Rectangle {
              visible: Sys.lyricsState === "ready"
              implicitWidth: srcText.implicitWidth + Tk.padding.medium * 2
              implicitHeight: srcText.implicitHeight + Tk.padding.extraSmall * 2
              radius: height / 2
              color: Colours.m3secondaryContainer
              MText { id: srcText; anchors.centerIn: parent; text: "lrclib"; font.pointSize: Tk.label.small; weight: Font.Medium; color: Colours.m3onSecondaryContainer }
            }
          }

          Item {
            id: lyricBox
            Layout.fillWidth: true
            Layout.fillHeight: true
            readonly property int current: root.player ? Sys.lyricIndexAt(root.player.position) : -1

            // Loading
            ColumnLayout {
              anchors.centerIn: parent
              spacing: Tk.spacing.large
              opacity: Sys.lyricsState === "loading" ? 1 : 0
              visible: opacity > 0
              Behavior on opacity { Anim { type: "effects" } }
              Rectangle {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 60 + Tk.padding.medium * 2; implicitHeight: implicitWidth
                radius: width / 2
                color: Colours.m3primaryContainer
                MShape {
                  id: loadShape
                  anchors.centerIn: parent
                  implicitSize: 60
                  shape: ["cookie9", "softBurst", "pentagon", "gem", "sunny"][loadShape.k % 5]
                  property int k: 0
                  color: Colours.m3onPrimaryContainer
                  Timer { interval: 650; repeat: true; running: loadShape.visible; onTriggered: loadShape.k++ }
                  RotationAnimation on rotation { from: 0; to: 360; duration: 3000; loops: Animation.Infinite; running: loadShape.visible }
                }
              }
              MText { Layout.alignment: Qt.AlignHCenter; text: "Loading lyrics..."; color: Colours.m3onSurfaceVariant; font.pointSize: Tk.title.medium; weight: Font.Medium }
            }

            // None
            ColumnLayout {
              anchors.centerIn: parent
              spacing: Tk.spacing.small
              opacity: Sys.lyricsState === "none" ? 1 : 0
              visible: opacity > 0
              Behavior on opacity { Anim { type: "slowEffects" } }
              MIcon { Layout.alignment: Qt.AlignHCenter; text: Config.o.dashboard.lyrics ? "sentiment_sad" : "lyrics"; size: Tk.iconSize.large * 2; color: Colours.m3outline }
              MText { Layout.alignment: Qt.AlignHCenter; text: Config.o.dashboard.lyrics ? "No lyrics found" : "Lyrics are off"; color: Colours.m3outline; font.pointSize: Tk.title.medium; weight: Font.Medium }
            }

            // Lines
            Item {
              anchors.fill: parent
              opacity: Sys.lyricsState === "ready" ? 1 : 0
              visible: opacity > 0
              Behavior on opacity { Anim { type: "slowEffects" } }
              layer.enabled: true
              layer.effect: MultiEffect { maskEnabled: true; maskSource: lyricMask; maskThresholdMin: 0; maskSpreadAtMin: 0 }
              Rectangle {
                id: lyricMask
                anchors.fill: parent
                visible: false
                layer.enabled: true
                gradient: Gradient {
                  GradientStop { position: 0; color: "transparent" }
                  GradientStop { position: 0.12; color: "white" }
                  GradientStop { position: 0.88; color: "white" }
                  GradientStop { position: 1; color: "transparent" }
                }
              }
              ListView {
                id: lyricList
                anchors.fill: parent
                model: Sys.lyrics
                currentIndex: lyricBox.current
                spacing: Tk.spacing.small
                interactive: false
                highlightRangeMode: ListView.StrictlyEnforceRange
                preferredHighlightBegin: height / 2 - 12
                preferredHighlightEnd: height / 2 + 12
                highlightMoveDuration: Tk.durations.defaultSpatial
                highlightMoveVelocity: -1
                delegate: MText {
                  id: line
                  required property var modelData
                  required property int index
                  readonly property bool isCur: ListView.isCurrentItem
                  property real glow: isCur ? 1 : 0
                  Behavior on glow { Anim { type: "slowEffects" } }
                  width: lyricList.width
                  text: modelData.text || ". . ."
                  wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                  font.pointSize: Tk.body.medium
                  color: isCur ? Colours.m3primary : lm.containsMouse ? Colours.m3onSurface : Colours.m3outline
                  layer.enabled: glow > 0
                  layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Colours.m3primary; shadowOpacity: 0.5 * line.glow; shadowBlur: 0.6 * line.glow; blurEnabled: true; blur: 0.4 * line.glow * 0 }
                  MouseArea {
                    id: lm
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.player && root.player.canSeek) root.player.position = line.modelData.time
                  }
                }
              }
            }
          }

          SplitSelect {
            Layout.alignment: Qt.AlignHCenter
            menuOnTop: true
            minLeftWidth: root.sectionWidth - Tk.padding.medium - 38
            fallbackIcon: "music_off"
            fallbackText: "No players"
            items: Sys.players.map(p => ({ icon: "animated_images", text: Sys.playerName(p), value: p }))
            current: Sys.player
            onSelected: v => Sys.manualPlayer = v
          }
        }
      }
    }
  }
}
