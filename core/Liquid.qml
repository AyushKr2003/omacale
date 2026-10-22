pragma Singleton
// Portions from Vitreus (MIT, Copyright (c) 2026 natepayn3); see THIRD_PARTY.md.
import QtQuick
import "LiquidMath.js" as M
import ".."

// Liquid motion (Settings › Motion), Omacale's own: Vitreus's springs,
// necks and drops on top of Caelestia's drawers (core/LiquidMath.js). The
// one place the feature is read: the preset resolved into final numbers,
// scaled by the UI and the animation-duration settings. Off (the default),
// every drawer moves on Caelestia's curves, exactly as without it.
QtObject {
  id: root

  readonly property QtObject cfg: Config.o.liquid
  readonly property bool enabled: cfg.enabled
  readonly property string preset: cfg.preset
  readonly property bool drop: cfg.style === "drop"

  readonly property var params: M.resolve(preset, {
    stiffness: cfg.stiffness, damping: cfg.damping, bulge: cfg.bulge, neckWidth: cfg.neckWidth,
    narrow: cfg.narrow, sag: cfg.sag, wobble: cfg.wobble
  })
  // Settings › Frame & motion › Animation duration slows the springs as it
  // lengthens the curves.
  readonly property var spring: M.slowed(params.stiffness, params.damping, Tk.animScale)
  readonly property real stiffness: spring[0]
  readonly property real damping: spring[1]
  readonly property var hang: M.slowed(M.HANG.stiffness, M.HANG.damping, Tk.animScale)
  readonly property var splash: M.slowed(M.SPLASH.stiffness, M.SPLASH.damping, Tk.animScale)
  // The neck follows the rounding scale, as the base blend (Tk.smoothing) does.
  readonly property real neckWidth: cfg.neck ? params.neckWidth * Tk.roundScale : 0
  readonly property bool rounding: cfg.rounding
  // Landing kicks, in px/s for the sag (UI-scaled) and a plain shove for the wobble.
  readonly property real sag: params.sag * Tk.uiScale / Tk.animScale
  readonly property real wobble: params.wobble / Tk.animScale
  readonly property bool neckBreak: cfg.detach.neckBreak
  readonly property bool ripples: cfg.detach.ripples
  readonly property bool stray: cfg.detach.stray

  // Is liquid motion on for this drawer (a key of liquid.drawers).
  function on(name) { return enabled && cfg.drawers[name] !== false }

  // Settings' preset row. Custom starts from the preset it leaves, so the
  // sliders open where the motion already was.
  function choosePreset(v) {
    if (v === "custom" && preset !== "custom") {
      const from = M.resolve(preset, null)
      for (let i = 0; i < M.NUMBERS.length; i++) Config.set("liquid." + M.NUMBERS[i], from[M.NUMBERS[i]])
    }
    Config.set("liquid.preset", v)
  }
}
