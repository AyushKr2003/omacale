.pragma library

// Every Omacale setting and its default. Config.qml builds its JSON adapter
// from these values, and "reset" writes them back.
var values = {
  appearance: {
    mode: "auto",            // auto | dark | light
    variant: "tonalspot",    // M3 dynamic scheme
    seed: "",                // "" = Omarchy theme accent, else "#rrggbb"
    animScale: 1.0,
    shadow: true,
    transparency: { enabled: false, base: 0.85, layers: 0.4 }
  },
  border: { thickness: 10, rounding: 25, smoothing: 20 },
  bar: {
    persistent: true,
    showOnHover: true,
    logo: true,
    logoIcon: "omarchy",   // see Logos.js
    power: true,
    workspaces: { shown: 5, display: "shapes", activeIndicator: true, activeTrail: true, occupiedBg: false, showWindows: true, maxWindowIcons: 5 },
    activeWindow: { enabled: true, compact: false },
    tray: { enabled: true, background: false, recolour: false },
    clock: { showIcon: true, showDate: false, showSeconds: false, background: false },
    status: { lockStatus: true, audio: false, microphone: false, network: true, bluetooth: true, battery: true, keepAwake: true, notifications: true },
    popouts: { statusIcons: true, tray: true, activeWindow: true },
    scroll: { workspaces: true, volume: true, brightness: true }
  },
  dashboard: {
    enabled: true, showOnHover: true, clockSeconds: false, mediaGif: true, lyrics: true, visualiser: true,
    tabs: { dashboard: true, media: true, performance: true, weather: true },
    performance: { showCpu: true, showGpu: true, showMemory: true, showStorage: true, showNetwork: true, showBattery: true }
  },
  launcher: { enabled: true, maxShown: 7, actionPrefix: ">", vimKeybinds: false, dangerousActions: true, dragThreshold: 50 },
  session: { enabled: true, gif: true, vimKeybinds: false, dragThreshold: 30, sleepAction: "hibernate" },
  sidebar: { enabled: true, width: 430 },
  utilities: {
    enabled: true, width: 430,
    // Caelestia's default quick toggles (utilitiesconfig.hpp), plus Omarchy's
    // night light, off by default so the card keeps Caelestia's single row.
    toggles: { wifi: true, bluetooth: true, mic: true, settings: true, gameMode: true, dnd: true, nightlight: false }
  },
  general: { clock24: true, weatherLocation: "", units: "metric" }
}

function get(obj, key) {
  var parts = key.split(".")
  for (var i = 0; i < parts.length; i++) {
    if (obj === undefined || obj === null) return undefined
    obj = obj[parts[i]]
  }
  return obj
}
