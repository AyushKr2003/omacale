pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "Defaults.js" as D

// Omacale settings, persisted to ~/.config/omacale/settings.json.
// The file only exists once something is changed; edits made by hand are
// picked up live. Read values with Config.o.<section>.<key>.
QtObject {
  id: root

  readonly property string dir: Quickshell.env("HOME") + "/.config/omacale"
  readonly property string path: dir + "/settings.json"
  readonly property var o: file.adapter
  property bool loaded: false
  property real lastLoad: 0

  function get(key) {
    const parts = key.split(".")
    let obj = o
    for (let i = 0; i < parts.length && obj; i++) obj = obj[parts[i]]
    return obj
  }
  function set(key, value) {
    const parts = key.split(".")
    let obj = o
    for (let i = 0; i < parts.length - 1; i++) obj = obj[parts[i]]
    if (obj[parts[parts.length - 1]] !== value) obj[parts[parts.length - 1]] = value
  }
  function defaultOf(key) { return D.get(D.values, key) }
  function isDefault(key) { return get(key) === defaultOf(key) }

  // Put every key back to its default.
  function resetAll() {
    const walk = (defs, prefix) => {
      for (const k in defs) {
        const key = prefix ? prefix + "." + k : k
        if (typeof defs[k] === "object" && !Array.isArray(defs[k])) walk(defs[k], key)
        else set(key, defs[k])
      }
    }
    walk(D.values, "")
  }

  // Coalesce bursts of changes (sliders) into one write.
  property Timer saveTimer: Timer {
    interval: 250
    onTriggered: root.mkdir.running = true
  }
  property Process mkdir: Process {
    command: ["mkdir", "-p", root.dir]
    onExited: root.file.writeAdapter()
  }

  property FileView file: FileView {
    path: root.path
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: { root.loaded = true; root.lastLoad = Date.now() }
    onLoadFailed: root.loaded = true
    // Changes that come from reading the file itself must not be written back.
    onAdapterUpdated: if (root.loaded && Date.now() - root.lastLoad > 300) root.saveTimer.restart()

    JsonAdapter {
      property JsonObject appearance: JsonObject {
        property string palette: "material"
        property string mode: "auto"
        property string variant: "tonalspot"
        property string seed: ""
        property real animScale: 1.0
        property bool shadow: true
        property JsonObject transparency: JsonObject {
          property bool enabled: false
          property real base: 0.85
          property real layers: 0.4
        }
      }
      property JsonObject border: JsonObject {
        property int thickness: 10
        property int rounding: 25
        property int smoothing: 20
      }
      property JsonObject bar: JsonObject {
        property bool persistent: true
        property bool showOnHover: true
        property bool logo: true
        property string logoIcon: "omarchy"
        property bool power: true
        property JsonObject workspaces: JsonObject {
          property int shown: 5
          property string display: "shapes"
          property bool activeIndicator: true
          property bool activeTrail: true
          property bool occupiedBg: false
          property bool showWindows: true
          property int maxWindowIcons: 5
          property string specialDisplay: "icons"
          property bool specialShowWindows: true
        }
        property JsonObject activeWindow: JsonObject {
          property bool enabled: true
          property bool compact: false
        }
        property JsonObject tray: JsonObject {
          property bool enabled: true
          property bool background: false
          property bool recolour: false
        }
        property JsonObject clock: JsonObject {
          property bool showIcon: true
          property bool showDate: false
          property bool showSeconds: false
          property bool background: false
        }
        property JsonObject status: JsonObject {
          property bool lockStatus: true
          property bool audio: false
          property bool microphone: false
          property bool network: true
          property bool bluetooth: true
          property bool battery: true
          property bool keepAwake: true
          property bool notifications: true
        }
        property JsonObject popouts: JsonObject {
          property bool statusIcons: true
          property bool tray: true
          property bool activeWindow: true
        }
        property JsonObject scroll: JsonObject {
          property bool workspaces: true
          property bool volume: true
          property bool brightness: true
        }
      }
      property JsonObject dashboard: JsonObject {
        property bool enabled: true
        property bool showOnHover: true
        property bool clockSeconds: false
        property bool mediaGif: true
        property bool lyrics: true
        property bool visualiser: true
        property JsonObject tabs: JsonObject {
          property bool dashboard: true
          property bool media: true
          property bool performance: true
          property bool weather: true
        }
        property JsonObject performance: JsonObject {
          property bool showCpu: true
          property bool showGpu: true
          property bool showMemory: true
          property bool showStorage: true
          property bool showNetwork: true
          property bool showBattery: true
        }
      }
      property JsonObject launcher: JsonObject {
        property bool enabled: true
        property int maxShown: 7
        property int maxWallpapers: 9
        property string actionPrefix: ">"
        property bool vimKeybinds: false
        property bool dangerousActions: true
        property int dragThreshold: 50
        // What `omacale wallpapers` / `themes` (the optional picker binds) open:
        // "omacale" (the launcher carousel) or "omarchy" (Omarchy's own menu).
        property string wallpaperPicker: "omacale"
        property string themePicker: "omacale"
        property list<string> favouriteApps: []
        property list<string> hiddenApps: []
      }
      property JsonObject session: JsonObject {
        property bool enabled: true
        property bool gif: true
        property bool vimKeybinds: false
        property int dragThreshold: 30
        property string sleepAction: "hibernate"
      }
      property JsonObject sidebar: JsonObject {
        property bool enabled: true
        property int width: 430
      }
      property JsonObject lock: JsonObject {
        property bool enabled: false
        property bool weather: true
        property bool fetch: true
        property bool media: true
        property bool resources: true
        property bool notifs: true
        property bool hideNotifs: false
        property bool recolourLogo: true
        property bool blur: true
      }
      property JsonObject utilities: JsonObject {
        property bool enabled: true
        property int width: 430
        property JsonObject toggles: JsonObject {
          property bool wifi: true
          property bool bluetooth: true
          property bool mic: true
          property bool settings: true
          property bool gameMode: true
          property bool dnd: true
          property bool nightlight: false
        }
      }
      property JsonObject general: JsonObject {
        property bool clock24: true
        property string weatherLocation: ""
        property string units: "metric"
      }
      property JsonObject notifs: JsonObject {
        property int groupPreviewNum: 3
        property bool openExpanded: false
        property JsonObject popups: JsonObject {
          property bool enabled: true
          property int width: 430
        }
      }
      property JsonObject services: JsonObject {
        property int mediaUpdateInterval: 500
        property int resourceUpdateInterval: 1000
        property int volumeStep: 5
        property int brightnessStep: 5
        property int visualiserBars: 60
      }
    }
  }
}
