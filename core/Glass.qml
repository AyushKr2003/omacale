pragma Singleton
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
  // Auto: smoked behind light text (a dark scheme), milky behind dark text.
  readonly property string tone: cfg.tone === "auto" ? (Colours.light ? "milk" : "smoke") : cfg.tone
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

  readonly property vector4d a: enabled ? Qt.vector4d(1, opacity, smoke, milk) : Qt.vector4d(0, 0, 0, 0)
  readonly property vector4d b: enabled ? Qt.vector4d(light, shadow, Tk.px(18), pointer ? 1 : 0) : Qt.vector4d(0, 0, 0, 0)
}
