pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Audio for Settings › Audio. Port of Caelestia's services/Audio.qml, driven
// the way Omarchy's own audio panel (shell/plugins/panels/audio) drives
// Pipewire: the same sink/source/stream filters, hidden unavailable sinks
// (omarchy-audio-sink-availability), output volume on the physical sink behind
// any speaker tuning (omarchy-audio-output-sink), and defaults persisted with
// omarchy-audio-{output,input}-set-default.
Singleton {
  id: root

  // Pages using the lists bump this; availability is only polled while > 0.
  property int users: 0

  readonly property var sink: Pipewire.defaultAudioSink
  readonly property var source: Pipewire.defaultAudioSource
  readonly property var nodes: Pipewire.nodes ? Pipewire.nodes.values : []

  // A tuning / EasyEffects sink fronts the speakers; its volume is the level
  // going into the processing, so the slider acts on the resolved sink instead.
  property string volumeSinkName: ""
  readonly property var volumeSink: {
    if (volumeSinkName === "" || !sink || volumeSinkName === String(sink.name)) return sink
    for (const n of nodes)
      if (n && n.isSink && !n.isStream && n.audio && String(n.name) === volumeSinkName) return n
    return sink
  }

  readonly property bool muted: !!(volumeSink && volumeSink.audio && volumeSink.audio.muted)
  readonly property real volume: volumeSink && volumeSink.audio ? volumeSink.audio.volume : 0
  readonly property bool sourceMuted: !!(source && source.audio && source.audio.muted)
  readonly property real sourceVolume: source && source.audio ? source.audio.volume : 0

  // Snapshots, not live lists: Omarchy found rebuilding a view from inside
  // Pipewire's node-removed signal can crash Quickshell, so let it settle.
  property var sinks: []
  property var sources: []
  property var streams: []

  property var availability: ({})

  function setVolume(v) {
    if (volumeSink && volumeSink.audio) { volumeSink.audio.muted = false; volumeSink.audio.volume = clamp(v) }
  }
  function setSourceVolume(v) {
    if (source && source.audio) { source.audio.muted = false; source.audio.volume = clamp(v) }
  }
  function setMuted(m) { if (volumeSink && volumeSink.audio) volumeSink.audio.muted = m }
  function setSourceMuted(m) { if (source && source.audio) source.audio.muted = m }
  function setStreamVolume(s, v) {
    if (s && s.audio) { s.audio.muted = false; s.audio.volume = clamp(v) }
  }

  function setAudioSink(node) {
    if (!node) return
    Pipewire.preferredDefaultAudioSink = node
    Quickshell.execDetached(["omarchy-audio-output-set-default", String(node.id), String(node.name)])
  }
  function setAudioSource(node) {
    if (!node) return
    Pipewire.preferredDefaultAudioSource = node
    Quickshell.execDetached(["omarchy-audio-input-set-default", String(node.id), String(node.name)])
  }

  function clamp(v) { return Math.max(0, Math.min(1, v)) }

  // Omarchy panels/audio/Model.js nodeLabel / friendlyDeviceLabel.
  function friendly(text) {
    return String(text || "").trim()
      .replace(/^sof-soundwire\s+/i, "").replace(/^built-?in audio\s+/i, "")
      .replace(/\s+Output$/i, "").replace(/\s+Input$/i, "")
      .replace(/\bMicrophones\b/g, "Microphone")
  }
  function props(n) { return n && n.ready && n.properties ? n.properties : {} }
  function deviceName(n) {
    if (!n) return "Unknown"
    const p = props(n)
    return friendly(n.nickname || p["node.nick"] || p["device.profile.description"] || "")
      || friendly(n.description || p["node.description"] || n.name || "Unknown")
  }
  function streamName(n) {
    if (!n) return "Unknown"
    const p = props(n)
    return p["application.name"] || n.description || p["media.name"] || n.name || "Unknown application"
  }
  function volumeIcon(v, m) { return m ? "no_sound" : v >= 0.5 ? "volume_up" : v > 0 ? "volume_down" : "volume_mute" }
  function micIcon(v, m) { return !m && v > 0 ? "mic" : "mic_off" }

  // Omarchy Model.isPlaybackStream: no node.properties read here (see there).
  function isPlayback(n) {
    if (!n || !n.isStream) return false
    if (n.isSink === true) return true
    const t = String(n.type || "")
    return t.indexOf("Stream/Output/Audio") !== -1 || t.indexOf("AudioOutStream") !== -1 || t.indexOf("Output") !== -1
  }

  function snapshot() {
    const k = [], s = [], st = []
    for (const n of nodes) {
      if (!n) continue
      if (!n.isStream && n.isSink) {
        if (availability[String(n.name)] !== false || n === sink) k.push(n)
      } else if (!n.isStream && n.audio && n.name !== "quickshell") {
        s.push(n)
      } else if (isPlayback(n) && n.audio && String(n.name || "").indexOf("omarchy_speaker_tuning") !== 0) {
        st.push(n)
      }
    }
    const byName = (a, b) => deviceName(a).localeCompare(deviceName(b))
    sinks = k.sort(byName)
    sources = s.sort(byName)
    streams = st
  }

  function refresh() {
    if (!availProc.running) availProc.running = true
    if (!sinkProc.running) sinkProc.running = true
    snapshotTimer.restart()
  }

  onNodesChanged: snapshotTimer.restart()
  onSinkChanged: { if (!sinkProc.running) sinkProc.running = true; snapshotTimer.restart() }
  onSourceChanged: snapshotTimer.restart()
  onUsersChanged: if (users > 0) refresh()

  Timer { id: snapshotTimer; interval: 75; onTriggered: root.snapshot() }
  Timer { interval: 5000; running: root.users > 0; repeat: true; onTriggered: root.refresh() }

  Process {
    id: availProc
    command: ["omarchy-audio-sink-availability"]
    stdout: StdioCollector {
      onStreamFinished: {
        const next = {}
        for (const line of String(text).split("\n")) {
          const parts = line.trim().split("\t")
          if (parts.length >= 2) next[parts[0]] = parts[1] !== "0"
        }
        root.availability = next
        root.snapshot()
      }
    }
  }
  Process {
    id: sinkProc
    command: ["omarchy-audio-output-sink"]
    stdout: StdioCollector { onStreamFinished: root.volumeSinkName = String(text).trim() }
  }

  PwObjectTracker {
    objects: [root.sink, root.source, root.volumeSink].concat(root.users > 0 ? root.sinks.concat(root.sources, root.streams) : []).filter(n => n)
  }
}
