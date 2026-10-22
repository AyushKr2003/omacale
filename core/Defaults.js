.pragma library

// Every Omacale setting and its default. Config.qml builds its JSON adapter
// from these values, and "reset" writes them back.
var values = {
  appearance: {
    palette: "material",     // material (M3 scheme from the seed) | omarchy (the theme's own colours)
    mode: "auto",            // auto | dark | light
    variant: "tonalspot",    // M3 dynamic scheme
    seed: "",                // "" = Omarchy theme accent, else "#rrggbb"
    seedTheme: "",           // the Omarchy theme a custom seed was picked under
    seedFollowsTheme: true,  // a theme switch drops a seed picked under another theme
    omarchySurfaces: false,  // Material colours on Omarchy's own menus too (a block in ~/.config/omarchy/shell.toml)
    animScale: 1.0,
    // Caelestia appearance.deformScale: how much drawers stretch as they
    // move (0 turns the jelly off).
    deformScale: 1.0,
    // UI scale. `source` omarchy follows ~/.config/omarchy/shell.toml ([font]
    // base-size, [spacing] scale); custom uses `ui`. font/padding/spacing/rounding
    // are Caelestia's appearance.*.scale, applied on top.
    scale: { source: "omarchy", ui: 1.0, font: 1.0, padding: 1.0, spacing: 1.0, rounding: 1.0 },
    shadow: true,
    transparency: { enabled: false, base: 0.85, layers: 0.4 }
  },
  border: { thickness: 10, rounding: 25, smoothing: 20 },
  bar: {
    position: "left",
    excludedScreens: [], screenPositions: [],   // per screen (core/Screens.js)
    persistent: true,
    showOnHover: true,
    logo: true,
    logoIcon: "omarchy",   // see Logos.js
    power: true,
    workspaces: { shown: 5, display: "shapes", activeIndicator: true, activeTrail: true, occupiedBg: false, showWindows: true, maxWindowIcons: 5, specialDisplay: "icons", specialShowWindows: true },
    activeWindow: { enabled: true, compact: false },
    tray: { enabled: true, background: false, recolour: false, compact: false, hiddenIcons: [] },
    plugins: { enabled: true, compact: false, unpinned: [], hidden: [] },
    // Settings › Taskbar › Layout. Empty lists mean the default order (BarLayout.js).
    layout: { start: [], center: [], end: [], removed: [], drawer: [], maxShown: 0, seen: [], adopted: false, fresh: [], showDuplicates: false },
    clock: { enabled: true, showIcon: true, showDate: false, showSeconds: false, background: false },
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
  session: {
    enabled: true, gif: true, vimKeybinds: false, dragThreshold: 30, sleepAction: "hibernate",
    menu: "omacale",        // what the session IPC opens: "omacale" (the drawer) or "omarchy" (its System menu)
    gifSpeed: 0.7, gifPath: "", extraButtons: true,
    // Settings › Session › Buttons: Lock and Screensaver "compact" (half-size,
    // side by side) or "full"; the drawer's items top to bottom; the ones left out.
    extraStyle: "compact",
    order: ["logout", "shutdown", "gif", "hibernate", "reboot", "lock", "screensaver"],
    hidden: [],
    // Caelestia session.icons / session.commands; "" = Omarchy's (or the built-in) default.
    icons: { logout: "", shutdown: "", hibernate: "", reboot: "", lock: "", screensaver: "" },
    commands: { logout: "", shutdown: "", hibernate: "", reboot: "", lock: "", screensaver: "" }
  },
  sidebar: { enabled: true, width: 430 },
  // Workspace overview (SUPER + TAB). `scale` is a ceiling: the grid is shrunk
  // further whenever rows x columns would not fit the screen.
  overview: { enabled: true, position: "middle", detached: false, gap: 48, rows: 2, columns: 5, scale: 0.18, hideEmptyRows: true, previews: true, showIcons: true },
  // Off until the user turns it on: switching it on hands Omarchy's lock
  // plugin over to Omacale (scripts/lock-screen), and switching
  // it off gives Omarchy's own lock view straight back.
  lock: {
    enabled: false,
    weather: true, fetch: true, media: true, resources: true, notifs: true,
    // Private by default: notification contents hidden, the wallpaper (not a
    // copy of the screen) behind the card, and no "show password" button.
    hideNotifs: true, recolourLogo: true, blur: true, useWallpaper: true, revealPassword: false,
    // Set when the watchdog gave the lock back to Omarchy after an update
    // broke it (services/Handover.qml), with the Omacale version it broke
    // under; reinstalling from Settings clears it, and a newer Omacale
    // tries once more by itself.
    autoFellBack: false, fellBackVersion: ""
  },
  utilities: {
    enabled: true, width: 430,
    // Caelestia utilities.maxToasts and utilities.toasts (utilitiesconfig.hpp),
    // for the toasts Omacale raises (services/Toaster.qml).
    maxToasts: 4,
    toasts: { chargingChanged: true, gameModeChanged: true, dndChanged: true, audioOutputChanged: true, audioInputChanged: true, nowPlaying: false },
    // Caelestia's default quick toggles (utilitiesconfig.hpp), plus Omarchy's
    // night light, off by default so the card keeps Caelestia's single row.
    toggles: { wifi: true, bluetooth: true, mic: true, settings: true, gameMode: true, dnd: true, nightlight: false }
  },
  // Caelestia osdconfig.hpp. Volume and brightness keys only reach it once
  // Omarchy's own OSD has stepped aside for them (scripts/osd-handover);
  // toasts (Omacale's): every other Omarchy OSD as a utilities toast;
  // autoFellBack: as lock's.
  osd: { enabled: true, hideDelay: 2000, enableBrightness: true, enableMicrophone: false, toasts: true, screen: "all", autoFellBack: false, fellBackVersion: "" },
  // Caelestia backgroundconfig.hpp (the wallpaper itself stays Omarchy's).
  // Settings › Display › Cursor: 0 / "auto" leave Omarchy's (or the user's) own.
  display: { cursorSize: 0, zeroScaling: "auto", linkBrightness: false, quickOnConnect: false, nightTemp: 4000, nightSchedule: "off", nightFrom: "20:00", nightTo: "07:00" },
  background: {
    excludedScreens: [],
    desktopClock: {
      enabled: false, scale: 1.0, position: "bottom-right", invertColors: false,
      background: { enabled: false, opacity: 0.7, blur: true },
      shadow: { enabled: true, opacity: 0.7, blur: 0.4 }
    },
    visualiser: { enabled: false, autoHide: true, blur: false, rounding: 1, spacing: 1 }
  },
  general: { clock24: true, weatherLocation: "", units: "metric" },
  // popups.enabled only takes effect once the notification daemon has handed
  // its own toasts over (scripts/notif-popups). autoFellBack: as lock's.
  notifs: { screen: "all", groupPreviewNum: 3, openExpanded: false, popups: { enabled: true, width: 430 }, autoFellBack: false, fellBackVersion: "" },
  // Caelestia services / dashboard polling. Steps are Omarchy's 5%, not
  // Caelestia's 10%, so the bar scrolls like Omarchy's volume keys.
  services: { mediaUpdateInterval: 500, resourceUpdateInterval: 1000, volumeStep: 5, brightnessStep: 5, visualiserBars: 60 },
  // Liquid motion (Settings › Motion): springs, necks and drops on
  // top of Caelestia's drawers. Off, Omacale moves exactly as
  // Caelestia does. `preset` other than "custom" overrides the numbers below
  // (core/LiquidMath.js PRESETS); "custom" uses them.
  liquid: {
    enabled: false,
    preset: "balanced",      // subtle | balanced | bouncy | custom
    style: "slide",          // slide (Caelestia's path) | drop (grow out of a narrow drop)
    drawers: { dashboard: true, launcher: true, session: true, utilities: true, sidebar: true, popouts: true, osd: true, settings: true, overview: true },
    stiffness: 170, damping: 18,
    bulge: 0.6,
    neck: true, neckWidth: 20,
    narrow: 0.07, rounding: true,
    sag: 220, wobble: 260,
    detach: { neckBreak: true, ripples: true, stray: true }
  },
  // Morph motion (Settings › Motion › Style, core/Morph.qml): drawers come
  // and go, and popouts morph into each other, as Serpantinum's panels do.
  // Never on with liquid motion.
  morph: { enabled: false },
  // Glass (Settings › Glass): Vitreus's glass on the frame and drawers --
  // translucent over Hyprland's blur, smoked or milky, lit on the edge.
  // Off, they are drawn as Caelestia's (or with Transparency, as that).
  glass: {
    enabled: false,
    opacity: 0.36,           // how much of the body covers what is behind (pleamar's glass: 36%)
    tone: "milk",            // milk (Frosted: lifted towards white, Vitreus's look) | clear | smoke
    toneAmount: 0.35,
    light: 1.0,              // edge light
    pointer: true,           // the light follows the pointer
    tuneBlur: true,          // Hyprland's blur set for glass while it is on (services/GlassBlur.qml)
    frost: 5,                // that blur's size
    bevel: 18,               // how wide the glass's rounded edge is (px)
    lens: true,              // the bevel bends what is behind (modules/drawers/GlassBackdrop.qml)
    lensFrost: 0.3,          // the lens's own frost (0 is clear glass; 0.3 is Serpantinum's light soften)
    dome: 0.35,              // what is behind, a little magnified towards a drawer's middle
    refraction: 1.0,         // how thick the glass is: how much it bends
    dispersion: 0.35,        // colour fringes where it bends hard
    motion: true,            // a moving drawer or card bends harder for a moment (Serpantinum's)
    nested: true             // the cards are glass of their own over the drawer's (components/GlassCard.qml)
  }
}

function get(obj, key) {
  var parts = key.split(".")
  for (var i = 0; i < parts.length; i++) {
    if (obj === undefined || obj === null) return undefined
    obj = obj[parts[i]]
  }
  return obj
}
