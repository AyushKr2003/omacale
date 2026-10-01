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

  // Fixed command strings only; a recording's path is a file name anyone can
  // pick, so play/reveal/remove pass it as argv, never through a shell.
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
    Quickshell.execDetached(["xdg-open", path])
  }

  function reveal(path) {
    if (!path) return
    Quickshell.execDetached(["xdg-open", path.substring(0, path.lastIndexOf("/"))])
  }
  function remove(path) {
    if (!path) return
    Quickshell.execDetached(["rm", "-f", "--", path])
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
  // Omarchy 4.0.x (stable) writes the marker to a fixed /tmp name instead;
  // later versions moved it into the runtime dir. Ask the installed script
  // which one it uses rather than watching both, since /tmp is noisy.
  property string markerDir: runtimeDir
  property Process markerProbe: Process {
    running: true
    command: ["bash", "-c", 'f=$(command -v omarchy-capture-screenrecording) && grep -q \'="/tmp/omarchy-screenrecord-filename"\' "$f"']
    onExited: code => {
      if (code !== 0) return
      root.markerDir = "/tmp"
      root.markerSettle.restart()
    }
  }

  property FileView marker: FileView {
    path: root.markerDir + "/omarchy-screenrecord-filename"
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
    path: root.markerDir
    watchChanges: true
    printErrors: false
    onFileChanged: root.markerSettle.restart()
  }

  // The folder is resolved the way omarchy-capture-screenrecording does it
  // (OMARCHY_SCREENRECORD_DIR, then XDG_VIDEOS_DIR from user-dirs.dirs, then
  // ~/Videos), and reported with the files so the watcher below can follow it.
  // Each file is "<mtime> <size> <path>", NUL-terminated, and jq turns the
  // lot into JSON. A file name may hold any character but NUL and "/", so any
  // other separator (the "|" and newline this used) could be faked by one.
  property Process recordingsProbe: Process {
    command: ["bash", "-c",
      '[[ -f ~/.config/user-dirs.dirs ]] && source ~/.config/user-dirs.dirs; ' +
      'OUTPUT_DIR="${OMARCHY_SCREENRECORD_DIR:-${XDG_VIDEOS_DIR:-$HOME/Videos}}"; ' +
      'mkdir -p "$OUTPUT_DIR"; ' +
      'find "$OUTPUT_DIR" -maxdepth 1 -type f \\( -name "*.mp4" -o -name "*.mkv" -o -name "*.webm" \\) -printf "%T@ %s %p\\0" 2>/dev/null | sort -zrn | head -zn 20 | ' +
      'jq -cRs --arg dir "$OUTPUT_DIR" \'{dir: $dir, files: [split("\\u0000")[] | select(length > 0) | index(" ") as $a | .[$a + 1:] as $r | ($r | index(" ")) as $b | {epoch: .[:$a], size: $r[:$b], path: $r[$b + 1:]}]}\'']
    stdout: StdioCollector {
      onStreamFinished: {
        let out
        try { out = JSON.parse(text) } catch (e) { return }
        if (out.dir) root.outputDir = out.dir
        root.recentRecordings = (out.files || []).map(f => ({
          epoch: parseFloat(f.epoch) || 0,
          path: f.path,
          name: f.path.slice(f.path.lastIndexOf("/") + 1),
          size: root.fmtBytes(parseInt(f.size) || 0)
        }))
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
