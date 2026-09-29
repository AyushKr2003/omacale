pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// Clipboard history, read with Omarchy's own engine.
//
// Omarchy's `omarchy.clipboard` plugin owns the recording: its wl-paste
// watchers run `capture.sh` on every copy and keep the history in
// ~/.local/state/omarchy/clipboard-history.json (images as files under
// clipboard-images/). Omacale runs no watcher of its own; it reads that file
// and, for delete and clear, writes it back the way Omarchy's panel does.
// The plugin watches the file too, so it picks our writes up.
//
// Searching and shaping rows is `plugins/clipboard/ClipboardHistory.js`,
// plain JS loaded in place as MenuService loads MenuModel.js, so a row here
// is the row Omarchy's panel draws. Paste, copy and open are Omarchy's
// `omarchy-clipboard-*` commands, which look the entry up by its index.
QtObject {
  id: root

  readonly property string omarchyPath: Quickshell.env("OMARCHY_PATH") || "/usr/share/omarchy"
  readonly property string historyPath: Quickshell.env("HOME") + "/.local/state/omarchy/clipboard-history.json"
  // Omarchy's Clipboard.qml historyLimit and its displayRows cap.
  readonly property int historyLimit: 500
  readonly property int rowLimit: 50

  property var engine: null
  readonly property bool available: !!engine
  property var history: []
  // Whether Omarchy's clipboard plugin (the recorder) is enabled. Only asked
  // when the history is empty, to say why.
  property bool recording: true

  function rows(query) {
    return engine ? engine.displayRows(history, query, rowLimit) : []
  }

  function load(raw) {
    history = engine ? engine.parseHistory(raw) : []
    if (history.length === 0) pluginProc.running = true
  }

  function save() {
    historyFile.setText(JSON.stringify(history.slice(0, historyLimit), null, 2) + "\n")
  }

  function remove(historyIndex) {
    if (!engine) return
    history = engine.removeEntryAt(history, historyIndex)
    save()
  }

  function clear() {
    if (!engine || history.length === 0) return
    history = []
    save()
  }

  // Omarchy's Clipboard.qml applySelected / copySelected / openSelected.
  function paste(row) {
    if (!row) return
    if (row.entryType === "image") Quickshell.execDetached([omarchyPath + "/bin/omarchy-clipboard-paste-file", row.mime, row.path])
    else if (row.fullText) Quickshell.execDetached([omarchyPath + "/bin/omarchy-clipboard-paste-text", "--shift-insert", "--history-index", String(row.index)])
  }

  function copy(row) {
    if (!row) return
    if (row.entryType === "image") Quickshell.execDetached([omarchyPath + "/bin/omarchy-clipboard-paste-file", "--copy-only", row.mime, row.path])
    else if (row.fullText) Quickshell.execDetached([omarchyPath + "/bin/omarchy-clipboard-paste-text", "--copy-only", "--history-index", String(row.index)])
  }

  function open(row) {
    if (row) Quickshell.execDetached([omarchyPath + "/bin/omarchy-clipboard-open", "--history-index", String(row.index)])
  }

  function loadEngine() {
    const src = 'import QtQuick\nimport "ClipboardHistory.js" as H\nQtObject {\n'
      + '  function parseHistory(raw) { return H.parseHistory(raw) }\n'
      + '  function removeEntryAt(h, i) { return H.removeEntryAt(h, i) }\n'
      + '  function displayRows(h, q, n) { return H.displayRows(h, q, n) }\n'
      + '}'
    try {
      // The URL never has to exist: it only resolves the relative import.
      engine = Qt.createQmlObject(src, root, "file://" + omarchyPath + "/shell/plugins/clipboard/OmacaleClipboardEngine.qml")
    } catch (e) {
      engine = null
      console.warn("Omacale: Omarchy's clipboard engine could not be loaded:", e)
    }
  }

  Component.onCompleted: {
    loadEngine()
    if (historyFile.loaded) load(historyFile.text())
  }

  property FileView historyFile: FileView {
    path: root.historyPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.load(text())
    onLoadFailed: root.load("[]")
    onFileChanged: reload()
  }

  property Process pluginProc: Process {
    command: ["bash", "-c", "omarchy plugin list --json | jq -e 'any(.[]; (.id == \"omarchy.clipboard\" or .clonedFrom == \"omarchy.clipboard\") and .enabled)'"]
    onExited: code => root.recording = code === 0
  }
}
