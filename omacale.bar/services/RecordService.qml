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
  // Where Omarchy saves recordings, as the probe resolved it.
  property string outputDir: ""

  function run(cmd) { Quickshell.execDetached(["bash", "-c", cmd]) }

  function start() {
    const audioFlag = withAudio ? " --with-microphone-audio" : ""
    const modeFlag = mode === "fullscreen" ? " --fullscreen" : ""
    run("omarchy capture screenrecording" + modeFlag + audioFlag)
    running = true
    elapsed = 0
    // No pollTimer.restart() here: the timer follows `running` declaratively,
    // and restarting it imperatively would break that binding for good.
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

  function apply(isRun) {
    if (root.running === isRun)
      return
    root.running = isRun
    if (!isRun) {
      root.elapsed = 0
      root.reloadRecordings()
    }
  }

  // `pidof` straight, not through a shell, and read off the exit code: the
  // `bash -c ... && echo 1 || echo 0` around it doubled the process count
  // for one boolean.
  property Process checkProc: Process {
    command: ["pidof", "gpu-screen-recorder"]
    onExited: code => root.apply(code === 0)
  }

  // Omarchy's own marker for a capture in flight: omarchy-capture-screenrecording
  // writes the output filename here when it starts and removes it when it
  // stops, so a recording begun from the keybind or the menu shows up here
  // without anything having to poll for it.
  readonly property string runtimeDir:
    Quickshell.env("XDG_RUNTIME_DIR") || (Quickshell.env("HOME") + "/.local/state/omarchy")

  property FileView marker: FileView {
    path: root.runtimeDir + "/omarchy-screenrecord-filename"
    printErrors: false
    // The marker can outlive a recorder that crashed, so its presence is
    // confirmed against the process; its absence is conclusive on its own.
    onLoaded: if (!root.running) root.checkProc.running = true
    onLoadFailed: root.apply(false)
  }

  // The runtime directory is busy with locks and sockets that are nothing to
  // do with us, so coalesce: a re-read is free, and only a marker that is
  // actually there costs a `pidof`.
  property Timer markerSettle: Timer {
    interval: 200
    onTriggered: root.marker.reload()
  }
  property FileView markerWatcher: FileView {
    path: root.runtimeDir
    watchChanges: true
    printErrors: false
    onFileChanged: root.markerSettle.restart()
  }

  // The folder is resolved the way omarchy-capture-screenrecording does it
  // (OMARCHY_SCREENRECORD_DIR, then XDG_VIDEOS_DIR from user-dirs.dirs, then
  // ~/Videos), and printed first so the watcher below can follow it.
  property Process recordingsProbe: Process {
    command: ["bash", "-c",
      '[[ -f ~/.config/user-dirs.dirs ]] && source ~/.config/user-dirs.dirs; ' +
      'OUTPUT_DIR="${OMARCHY_SCREENRECORD_DIR:-${XDG_VIDEOS_DIR:-$HOME/Videos}}"; ' +
      'mkdir -p "$OUTPUT_DIR"; ' +
      'printf "DIR|%s\\n" "$OUTPUT_DIR"; ' +
      'find "$OUTPUT_DIR" -maxdepth 1 -type f \\( -name "*.mp4" -o -name "*.mkv" -o -name "*.webm" \\) -printf "%T@|%p|%f|%s\\n" 2>/dev/null | sort -rn | head -20']
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = String(text).trim().split("\n")
        const list = []
        for (let i = 0; i < lines.length; i++) {
          const l = lines[i].trim()
          if (!l) continue
          if (l.startsWith("DIR|")) { root.outputDir = l.slice(4); continue }
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

  // The recordings folder, so a video deleted, renamed or added from a file
  // manager (or anywhere else) shows in the list within a moment instead of
  // after a shell restart. Qt reports entries coming and going, not a
  // recording growing, and the short settle turns a burst of changes (a
  // multi-file delete, a copy) into one re-read.
  property Timer dirSettle: Timer {
    interval: 400
    onTriggered: root.reloadRecordings()
  }
  property FileView dirWatcher: FileView {
    path: root.outputDir
    watchChanges: root.outputDir !== ""
    printErrors: false
    onFileChanged: root.dirSettle.restart()
  }

  // Only while recording: the elapsed counter needs a second hand, and a
  // recorder that dies without clearing the marker has to be noticed. Idle,
  // the marker watcher above is what reports a capture starting, so this ran
  // `pidof` once a second for the whole session to learn nothing.
  property Timer pollTimer: Timer {
    interval: 1000
    running: root.running
    repeat: true
    onTriggered: {
      root.elapsed++
      if (!root.checkProc.running)
        root.checkProc.running = true
    }
  }

  Component.onCompleted: {
    checkProc.running = true
    reloadRecordings()
  }
}
