.pragma library

// Every Omacale setting and its default. Config.qml builds its JSON adapter
// from these values, and "reset" writes them back.
var values = {
  appearance: {
    palette: "material",     // material (M3 scheme from the seed) | omarchy (the theme's own colours)
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
    workspaces: { shown: 5, display: "shapes", activeIndicator: true, activeTrail: true, occupiedBg: false, showWindows: true, maxWindowIcons: 5, specialDisplay: "icons", specialShowWindows: true },
    activeWindow: { enabled: true, compact: false },
    tray: { enabled: true, background: false, recolour: false, compact: false, hiddenIcons: [] },
    plugins: { enabled: true, compact: false, unpinned: [] },
    clock: { showIcon: true, showDate: false, showSeconds: false, background: false },
    status: { lockStatus: true, audio: false, microphone: false, network: true, bluetooth: true, battery: true, keepAwake: true, update: true, notifications: true, bluetoothConnectedOnly: false, microphoneInUseOnly: false, kbLayout: false },
    popouts: { statusIcons: true, tray: true, activeWindow: true },
    scroll: { workspaces: true, volume: true, brightness: true }
  },
  dashboard: {
    enabled: true, showOnHover: true, clockSeconds: false, mediaGif: true, lyrics: true, visualiser: true,
    tabs: { dashboard: true, media: true, performance: true, weather: true },
    performance: { showCpu: true, showGpu: true, showMemory: true, showStorage: true, showNetwork: true, showBattery: true }
  },
  launcher: { enabled: true, maxShown: 7, maxWallpapers: 9, actionPrefix: ">", menuPrefix: ":", vimKeybinds: false, dangerousActions: true, dragThreshold: 50, wallpaperPicker: "omacale", themePicker: "omacale", favouriteApps: [], hiddenApps: [] },
  session: { enabled: true, gif: true, vimKeybinds: false, dragThreshold: 30, sleepAction: "hibernate" },
  sidebar: { enabled: true, width: 430 },
  // Workspace overview (SUPER + TAB). `scale` is a ceiling: the grid is shrunk
  // further whenever rows x columns would not fit the screen.
  overview: { enabled: true, position: "middle", detached: false, gap: 48, rows: 2, columns: 5, scale: 0.18, hideEmptyRows: true, previews: true, showIcons: true },
  // Off until the user turns it on: switching it on hands Omarchy's lock
  // plugin over to Omacale (omacale.bar/scripts/lock-screen), and switching
  // it off gives Omarchy's own lock view straight back.
  lock: {
    enabled: false,
    weather: true, fetch: true, media: true, resources: true, notifs: true,
    hideNotifs: false, recolourLogo: true, blur: true
  },
  utilities: {
    enabled: true, width: 430,
    // Caelestia's default quick toggles (utilitiesconfig.hpp), plus Omarchy's
    // night light, off by default so the card keeps Caelestia's single row.
    toggles: { wifi: true, bluetooth: true, mic: true, settings: true, gameMode: true, dnd: true, nightlight: false }
  },
  // Caelestia backgroundconfig.hpp (the wallpaper itself stays Omarchy's).
  background: {
    desktopClock: {
      enabled: false, scale: 1.0, position: "bottom-right", invertColors: false,
      background: { enabled: false, opacity: 0.7, blur: true },
      shadow: { enabled: true, opacity: 0.7, blur: 0.4 }
    },
    visualiser: { enabled: false, autoHide: true, blur: false, rounding: 1, spacing: 1 }
  },
  general: { clock24: true, weatherLocation: "", units: "metric" },
  // popups.enabled only takes effect once the notification daemon has handed
  // its own toasts over (shell/omacale/scripts/notif-popups).
  notifs: { groupPreviewNum: 3, openExpanded: false, popups: { enabled: true, width: 430 } },
  // Caelestia services / dashboard polling. Steps are Omarchy's 5%, not
  // Caelestia's 10%, so the bar scrolls like Omarchy's volume keys.
  services: { mediaUpdateInterval: 500, resourceUpdateInterval: 1000, volumeStep: 5, brightnessStep: 5, visualiserBars: 60 }
}

function get(obj, key) {
  var parts = key.split(".")
  for (var i = 0; i < parts.length; i++) {
    if (obj === undefined || obj === null) return undefined
    obj = obj[parts[i]]
  }
  return obj
}
