pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// RecordService: Screen recording integration via Omarchy capture commands.
// Uses `omarchy capture screenrecording` and monitors `gpu-screen-recorder`.
QtObject {
  id: root

  property bool running: false
  property string mode: "fullscreen" // "fullscreen" | "region"
  property bool withAudio: false
  property int elapsed: 0
  property bool listExpanded: false
  property string confirmDelete: ""
  property var recentRecordings: [] // [{ path, name, size, time }]

  function run(cmd) { Quickshell.execDetached(["bash", "-c", cmd]) }

  function start() {
    const audioFlag = withAudio ? " --with-microphone-audio" : ""
    const modeFlag = mode === "fullscreen" ? " --fullscreen" : ""
    run("omarchy capture screenrecording" + modeFlag + audioFlag)
    running = true
    elapsed = 0
    pollTimer.restart()
  }

  function stop() {
    run("omarchy capture screenrecording --stop-recording")
    running = false
    elapsed = 0
    reloadRecordings()
  }

  function toggle() {
    if (running) stop()
    else start()
  }

  function play(path) {
    if (!path) return
    run("xdg-open " + JSON.stringify(path))
  }

  function reveal(path) {
    if (!path) return
    run("xdg-open " + JSON.stringify(path.substring(0, path.lastIndexOf("/"))))
  }
  function remove(path) {
    if (!path) return
    run("rm -f " + JSON.stringify(path))
    reloadRecordings()
  }

  function reloadRecordings() {
    recordingsProbe.running = true
  }

  function fmtTime(sec) {
    const m = Math.floor(sec / 60)
    const s = sec % 60
    return (m < 10 ? "0" + m : m) + ":" + (s < 10 ? "0" + s : s)
  }

  function fmtBytes(b) {
    const u = ["B", "KB", "MB", "GB"]
    let i = 0
    b = Math.max(0, b || 0)
    while (b >= 1024 && i < u.length - 1) { b /= 1024; i++ }
    return (i === 0 ? Math.round(b) : b.toFixed(1)) + " " + u[i]
  }

  property Process checkProc: Process {
    command: ["bash", "-c", "pidof gpu-screen-recorder >/dev/null && echo 1 || echo 0"]
    stdout: SplitParser {
      onRead: line => {
        const isRun = String(line).trim() === "1"
        if (root.running !== isRun) {
          root.running = isRun
          if (!isRun) {
            root.elapsed = 0
            root.reloadRecordings()
          }
        }
      }
    }
  }

  property Process recordingsProbe: Process {
    command: ["bash", "-c",
      'OUTPUT_DIR="${OMARCHY_SCREENRECORD_DIR:-$HOME/Videos}"; ' +
      'mkdir -p "$OUTPUT_DIR"; ' +
      'find "$OUTPUT_DIR" -maxdepth 1 -type f \\( -name "*.mp4" -o -name "*.mkv" -o -name "*.webm" \\) -printf "%T@|%p|%f|%s\\n" 2>/dev/null | sort -rn | head -20']
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = String(text).trim().split("\n")
        const list = []
        for (let i = 0; i < lines.length; i++) {
          const l = lines[i].trim()
          if (!l) continue
          const p = l.split("|")
          if (p.length >= 4) {
            list.push({
              epoch: parseFloat(p[0]) || 0,
              path: p[1],
              name: p[2],
              size: root.fmtBytes(parseInt(p[3]) || 0)
            })
          }
        }
        root.recentRecordings = list
      }
    }
  }

  property Timer pollTimer: Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: {
      root.checkProc.running = true
      if (root.running) root.elapsed++
    }
  }

  Component.onCompleted: {
    checkProc.running = true
    reloadRecordings()
  }
}
