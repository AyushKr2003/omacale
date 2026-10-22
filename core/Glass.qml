pragma Singleton
// Portions from Vitreus (MIT, Copyright (c) 2026 natepayn3) and pleamar (BSD-3-Clause, Copyright (c) 2026, Abel); see THIRD_PARTY.md.
import QtQuick
import ".."

// Glass (Settings › Glass), Omacale's own: Vitreus's default glass on the
// frame and drawers (pleamar's shape.wgsl without its lens; see
// docs/liquid-glass-research.md). The drawers turn translucent over
// Hyprland's blur (the layer rule in Bar.qml), smoked or milky, with light on
// their edge (shaders/blob.frag) and their shadow only round them. The one
// reader of Config.o.glass besides Colours' surface alpha. Off (the
// default), nothing here reaches the shader.
QtObject {
  id: root

  readonly property QtObject cfg: Config.o.glass
  readonly property bool enabled: cfg.enabled
  readonly property real opacity: Math.max(0.3, Math.min(1, cfg.opacity))
  // Frosted ("milk") is the default: Vitreus's glass reads lighter than what
  // is behind it (measured in its screenshots, 20-40 levels over the
  // wallpaper beside it), which only a lift towards white gives over a blur
  // we never see. "auto" was a setting before; it is frosted now.
  readonly property string tone: cfg.tone === "auto" ? "milk" : cfg.tone
  readonly property real toneAmount: Math.max(0, Math.min(1, cfg.toneAmount))
  readonly property real smoke: tone === "smoke" ? toneAmount : 0
  readonly property real milk: tone === "milk" ? toneAmount : 0
  readonly property real light: Math.max(0, cfg.light)
  readonly property bool pointer: enabled && cfg.pointer
  // Hyprland's blur under it (services/GlassBlur.qml).
  readonly property bool tuneBlur: cfg.tuneBlur
  readonly property int frost: Math.max(1, Math.min(12, Math.round(cfg.frost)))
  // pleamar's glass shadow (Vitreus: 24%), drawn by the shader round the
  // shape only, under Hyprland's blur threshold below so it isn't blurred.
  readonly property real shadow: Config.o.appearance.shadow ? 0.22 : 0
  // Hyprland blurs behind what is more opaque than this: the body, not
  // its shadow or the antialiased rim.
  readonly property real blurFloor: Math.min(0.25, opacity - 0.05)
  // Body opacity starts at 30%: under that, the floor would meet the shadow.

  // The bevel (shaders/blob.frag): its width, and the lens that bends what
  // is behind on it, from a backdrop rebuilt out of the wallpaper and the
  // windows (modules/drawers/GlassBackdrop.qml).
  readonly property real bevel: Tk.px(Math.max(6, Math.min(40, cfg.bevel)))
  readonly property bool lens: enabled && cfg.lens
  // With the lens the whole body is drawn from the backdrop, frosted by the
  // shader itself (0 is clear glass, what is behind sharp through the tint),
  // and Hyprland's blur is off behind it. Without, Hyprland's blur frosts.
  readonly property real lensFrost: Math.max(0, Math.min(1, cfg.lensFrost))
  readonly property real dome: Math.max(0, Math.min(1, cfg.dome))
  // The frosted backdrop's blur: 1 to 32 px, slow at first, so the low end
  // is Serpantinum's nearly clear glass (a few px of soften) and the top
  // Vitreus's frost.
  readonly property real frostPx: Tk.px(1 + 31 * lensFrost * lensFrost)
  readonly property real refraction: Math.max(0, Math.min(2, cfg.refraction))
  readonly property real dispersion: Math.max(0, Math.min(1, cfg.dispersion))
  // Serpantinum's motion energy: a drawer or card that moves gets thicker,
  // bends and splits the light more, and settles as it stops
  // (components/GlassMotion.qml).
  readonly property bool motion: lens && cfg.motion
  // Serpantinum's nested glass: the cards in a drawer are clear glass of
  // their own, bending the drawer's glass at their rim
  // (components/GlassCard.qml).
  readonly property bool nested: lens && cfg.nested
  readonly property vector4d a: enabled ? Qt.vector4d(1, opacity, smoke, milk) : Qt.vector4d(0, 0, 0, 0)
  readonly property vector4d b: enabled ? Qt.vector4d(light, shadow, Tk.px(18), pointer ? 1 : 0) : Qt.vector4d(0, 0, 0, 0)
  // The lens's on (x) is the backdrop's to say: ScreenScope sets it only
  // with one bound.
  readonly property vector4d c: enabled ? Qt.vector4d(lens ? 1 : 0, bevel, refraction, dispersion) : Qt.vector4d(0, 0, 0, 0)
  readonly property vector4d d: enabled ? Qt.vector4d(lensFrost, 0.6, 1, dome) : Qt.vector4d(0, 0, 0, 0)
}
