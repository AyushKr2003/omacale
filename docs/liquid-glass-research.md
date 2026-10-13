# Liquid glass for Omacale: research and plan

Status: research, nothing built yet. Written 2026-10-13 against Hyprland 0.56.2 and
Quickshell 0.3.1 (both what this machine runs), Vitreus and pleamar as checked out
under `shell/`.

Liquid motion (Settings › Motion) gave Omacale Vitreus's *movement*. This document
is about the other half of Vitreus: the *material*, the "liquid glass" the drawers
are made of. The question is how close Omacale can get to it inside Quickshell,
and at what cost.

---

## 1. What Vitreus's glass actually is

Vitreus's glass is three separate layers. Only the third one needs to see the
pixels behind the window.

| Layer | What it does | Who does it in Vitreus | Needs the pixels behind? |
|---|---|---|---|
| **1. Frost** | The blurred background seen through the drawer | The compositor, asked through `ext-background-effect-v1` (Hyprland, KWin) | No: the compositor has them |
| **2. Light** | Tint, rim light, a shine that follows the pointer, fresnel at the edge, shadow; "smoke" (darker) and "milk" (lighter) tones | pleamar's shape shader, from the shape's signed distance | No |
| **3. Lens** | Real refraction: the background bent at the bevel, colour fringes (dispersion), a magnifying "dome", `frost: auto` (frosted only over busy content) | pleamar itself: it screen-captures the output and computes the background | **Yes** |

The key fact for planning: **Vitreus ships with the lens off.** Its default glass is
layers 1 and 2. In `vitreus.plm` the surface is `lens: glass_bend`, and `glass_bend`
is a switch on its Glass page ("The glass only blurs what is behind it (the
compositor does it; `lens: false`, unless the Glass page turns bending on)"). Real
refraction is the expensive extra, not the base look.

### 1.1 How pleamar's lens sees behind itself (`src/lens.rs`, `src/backdrop.wgsl`)

Wayland never gives a client the pixels behind its own surface, so pleamar
reconstructs them:

1. It asks the compositor for a screen capture of the area (`wlr-screencopy`). The
   capture necessarily includes pleamar's own surface on top.
2. It **unmixes** it. The compositor blended `capture = ours + (1 − α_ours) · background`.
   pleamar knows `ours` exactly (it keeps the last frame it presented), so
   `background = (capture − ours) / (1 − α_ours)`. pleamar measured the error at
   under half a level out of 255 at a 30% tint.
3. Where its own paint is nearly opaque (text, icons), the background can't be
   recovered. Those pixels are marked unknown and filled by the blur. When the
   capture belongs to a different frame (something moved), the result goes out of
   range and the previous background is kept.
4. The clean background is blurred (two-pass Gaussian at half resolution) for frost.
5. The shape shader reads it displaced. The bevel profile is `(1 − (1 − t)³)^⅓`;
   Snell's law uses n = 1.5 with a per-channel index for dispersion (Cauchy fit,
   R 611 / G 549 / B 464 nm), eased into a cap of half a bevel so corners don't
   fold. There is also a crease-free depth for rounded corners (an idea credited
   to HyprGlass) and an "auto frost" that measures how busy the background is.
6. To avoid a feedback loop (painting the lens changes the next capture), it
   compares one byte in thirteen of each capture with the last one and stops
   recapturing when nothing behind has moved. New surfaces are "warmed up" for
   1.5 s, because the compositor fades a layer in and early captures unmix wrong.

That is the full machinery Omacale would need to copy for real refraction in-process.

---

## 2. What Quickshell and Hyprland give us

| Capability | Available here? | Notes |
|---|---|---|
| Compositor blur behind a layer (`hl.layer_rule … blur`) | **Yes**, used today | Omacale's Transparency setting already does this (`Bar.qml applyBlur`) |
| `ext-background-effect-v1` blur region (`BackgroundEffect.blurRegion` on a window) | **Yes**: Quickshell 0.3.x, Hyprland supports the protocol | A `Region` of rects or items; lets us ask for blur exactly where the drawers are, instead of the whole layer |
| Custom fragment shaders (`ShaderEffect`, `.qsb`) | **Yes** | `blob.frag` already draws every drawer from SDFs: everything layer 2 needs is there |
| Pointer position over our surfaces | **Yes**, over the drawers (`MouseArea` hover) | Outside the input mask nothing arrives (see CLAUDE.md "The pointer leaving the bar reaches nothing"); fine for a shine that follows the pointer over a drawer |
| Live screen capture (`ScreencopyView { live: true; captureSource: screen }`) | **Yes** (wlr-screencopy / ext-image-copy-capture) | Includes our own surface, so we would have to unmix as pleamar does |
| Live window capture (`captureSource: Toplevel`) | **Yes** (hyprland-toplevel-export) | The overview uses it; one capture per window, so it can't stand in for "everything behind" |
| Reading the pixels behind our own surface directly | **No** | No Wayland or Qt API for it. This is the whole problem |
| Hiding our layer from screencopy (`no_screen_share` layer rule) | Exists | It blacks the surface out rather than skipping it. Our window is full-screen, so the capture would be black. No help |
| **HyprGlass** Hyprland plugin | Installable (`hyprpm`) | Real refraction done *inside the compositor*; layer surfaces supported (beta, March 2026). See §3.C |

---

## 3. The options

### A. Drawn glass on compositor blur: Vitreus's default look, in Omacale's shader

**What:** layers 1 and 2. Drawers become translucent with Hyprland's blur behind them
(already there as Transparency). `blob.frag` adds the light from the SDF it already
computes:

- **Bevel normal** from the distance field's gradient near the edge: `n = normalize(vec3(-∇d * slope(t), 1))`, with pleamar's `rim_height`/`rim_slope` profile over a bevel width.
- **Rim light:** a thin bright line on the edge facing the light, a softer one on the opposite edge (pleamar: `rim * (0.85·facing + 0.4·away + 0.12)`).
- **Fresnel:** Schlick with F0 = 0.04, brightening the edge seen edge-on.
- **Specular / shine:** from a fixed top-left light, or from the pointer while it is over a drawer (Vitreus `shine: pointer`).
- **Tint, smoke, milk:** pleamar's `glass_tone` (darken brights for light text, lift darks for dark text), applied to the surface colour.
- **Inner shadow** under the bevel, so the glass reads as having thickness.
- **Blur region:** `BackgroundEffect.blurRegion` covering the drawers' rects, instead of a whole-layer rule. It's tighter and can be switched off per drawer.

**Can't do:** bend what is behind, colour fringes on the background, auto-frost.
Frost strength is Hyprland's global blur, not per drawer.

**Cost:** a few more ALU ops per pixel in a shader that already runs full-screen.
No new captures. Works on any Hyprland, with nothing to install.

**Effort:** small to medium. It's all in `blob.frag` + `BlobSurface` + one Settings
page. It fits the existing liquid motion (the neck, drops and ripples get the same
glass for free, since they're the same SDF).

### B. Real refraction inside Quickshell (pleamar's method, in QML)

**What:** layer 3, done ourselves. A live `ScreencopyView` of the screen, a texture of
the frame we presented (`ShaderEffectSource` of the window's content), an unmix pass
and a blur pass in `ShaderEffect`s, and `blob.frag` sampling the result through the
bevel's refraction.

**Problems:**

- **Frame sync.** The capture is of the previous composited frame, and QML gives us
  no reliable handle on "the frame the compositor actually used". While a drawer
  moves, which is exactly when liquid motion is happening, the unmix is wrong, and
  pleamar's fallback (keep the old background) shows as smearing.
- **Feedback loop.** Our glass is part of the next capture. pleamar breaks the loop
  by sampling capture bytes on the CPU, which isn't available to us in QML. We would
  have to recapture every frame (60 full-screen captures a second) or guess.
- **Cost.** Full-screen screencopy at up to 60 Hz, plus a full-screen copy of our own
  output, an unmix pass and two blur passes. That's several times today's GPU work,
  on battery too.
- **Opaque content.** Text and icons on the drawers can't be unmixed. That's fine for
  frost (the blur fills it in) but visible as holes in sharp refraction.
- **Privacy and other windows.** Windows marked `noscreenshare` come back black and
  would refract as black.

**Verdict:** possible as an experiment, not as a feature. Doing this well needs
control of the render loop (pleamar is its own renderer for this reason).

### C. HyprGlass: real refraction done by the compositor

**What:** [hyprglass](https://github.com/hyprnux/hyprglass) (BSD-3-Clause) is a
Hyprland plugin that draws frosted blur, edge refraction, chromatic aberration,
specular and bevel on windows, and since March 2026 (beta) on layer surfaces. The
compositor has the real background, so there's no unmixing, no lag and no feedback
loop. pleamar's own glass profile credits it.

Layer support:

- `layers = { enabled = true }`, then `hg.layer("omacale", { preset = …, mask_threshold = … })`.
- **Alpha mask** mode: glass follows our visible alpha, so it follows the blob's
  fillets, necks and drops exactly. `mask_threshold` must sit above our shadow's
  opacity.
- Or it takes our `ext-background-effect-v1` region.
- Presets: `subtle`, `glass`, `clear`, `high_contrast`, `pomme`, or custom
  (`refraction_strength`, `chromatic_aberration`, `specular_strength`/`angle`,
  `bevel_*`, `tint_color`).
- `live_resample` capped at 30 fps per layer, with cached backgrounds.

**What Omacale would do:**

- Draw the drawers translucent (as with Transparency on) so there is something to
  see through.
- Detect the plugin (`hyprctl hyprglass status`), and offer "Use HyprGlass" in
  Settings only when it is loaded.
- Ship the `hg.layer("^omacale(-notifications)?$", …)` lines in `omacale.lua`,
  guarded so they do nothing without the plugin. Settings changes apply live through
  `hyprctl eval`, the same way `HyprLook` does it.
- Turn Omacale's own drawn rim/specular down when HyprGlass draws them, so they
  don't double up.

**Problems:**

- It's a separate install, through `hyprpm`, which needs sudo once and a build
  against the matching Hyprland branch (`hyprland-0.56` today).
- Layer support is beta and hooks a private Hyprland function (`renderLayer`). An
  Omarchy Hyprland update can break it until the plugin catches up. The plugin
  pauses rather than crashing, so Omacale must degrade to option A by itself.
- GPU cost while live-resampling, especially behind a moving drawer.
- Omacale's scope rule: nothing outside `shell/omacale/`, Hyprland bits only in
  `omacale.lua`. Installing a compositor plugin is the user's decision. Omacale can
  only detect and configure it, never install it.

### D. Refract the wallpaper only (a cheap hybrid)

**What:** behind the frame and the bar there is only ever the wallpaper (windows sit
inside the reserved frame), and Omacale knows the wallpaper file. `blob.frag` could
sample the wallpaper image through the bevel and get real refraction there for free.
Drawers over windows would fall back to option A.

**Problem:** inconsistent. A drawer that bends the wallpaper next to the frame but
not the window under it reads as a trick. At most a garnish for the frame and bar.

---

## 4. Recommendation

1. **Build A first ("Glass", in Settings).** It is Vitreus's own default look, it
   needs nothing installed, it costs almost nothing, and it composes with liquid
   motion because the necks, drops and ripples are the same SDF.
2. **Then C as an optional upgrade ("Use HyprGlass when it is installed").** It's the
   only route to real refraction that is smooth while drawers move. Omacale detects
   it, configures it from Settings, and falls back to A when it's missing or paused.
3. **Skip B** unless A + C turn out not to be enough. If it is ever tried, do it as
   an experiment behind a flag, frost only (no sharp refraction), and recapture only
   while nothing of ours is moving.
4. D is optional decoration for the frame and bar, after A.

---

## 5. Settings sketch (option A, plus C)

A new page next to Motion, Appearance › **Glass**, off by default. "Off" means
Omacale draws exactly as today.

| Row | Key | Default |
|---|---|---|
| Glass (master toggle) | `glass.enabled` | off |
| Preset: Clear / Frosted / Smoked / Milky / Custom | `glass.preset` | Frosted |
| Surface opacity (how much shows through) | `glass.opacity` | 0.55 |
| Tint strength | `glass.tint` | 0.2 |
| Rim light | `glass.rim` | 0.6 |
| Shine (specular) | `glass.shine` | 0.5 |
| Shine follows the pointer | `glass.shinePointer` | on |
| Bevel width (at 100% scale) | `glass.bevel` | 16 px |
| Smoke / Milk (Custom only) | `glass.smoke`, `glass.milk` | 0 |
| Blur behind | `glass.blur` | on (uses `BackgroundEffect`) |
| Use HyprGlass when installed (shown only if detected) | `glass.hyprglass` | off |
| HyprGlass preset (subtle / glass / clear / high contrast) | `glass.hyprglassPreset` | subtle |
| Per-drawer toggles | `glass.drawers.*` | all on |

As with liquid motion: one reader singleton (`core/Glass.qml`), pure math in a `.js`
with node tests, zero-cost paths when off, a live preview card (the Motion preview
drawn in glass over the current wallpaper).

---

## 6. Shader sketch for option A

`blob.frag` already ends with the merged signed distance `merged` and an
antialiased `alpha`. Glass adds roughly this before the final colour:

```glsl
// Bevel: t = 0 at the edge, 1 where the flat top starts.
float inside = -merged;                              // px inside the shape
float t = clamp(inside / bevel, 0.0, 1.0);
vec2 g = vec2(dFdx(merged), dFdy(merged));           // or central differences of the SDF
vec2 outward = length(g) > 1e-4 ? normalize(g) : vec2(0.0);
float slope = (t < 1.0) ? rimSlope(t) : 0.0;         // pleamar's (1-(1-t)^3)^(1/3) derivative
vec3 n = normalize(vec3(outward * slope, 1.0));

// Light: fixed top-left, or the pointer while it is over a drawer.
vec2 toLight = pointerOn > 0.5 ? normalize(pointer - pixel) : normalize(vec2(-0.55, -0.83));
float facing = max(dot(outward, -toLight), 0.0);
float away   = max(dot(outward,  toLight), 0.0);
float rimBand = 1.0 - smoothstep(0.4, 3.0, inside);   // a 1-3 px band at the edge
float fresnel = 0.04 + 0.96 * pow(1.0 - n.z, 5.0);
float light = rimBand * (0.85 * facing + 0.4 * away + 0.12) * rim + 0.14 * fresnel;
float spec = pow(max(dot(reflect(vec3(-toLight, -1.0), n), vec3(0, 0, 1)), 0.0), 32.0) * shine;

vec3 c = glassTone(color.rgb, smoke, milk);          // pleamar glass_tone
c = mix(c, tintColor, tint);
c += vec3(light + spec);
float a = opacity * alpha;                           // translucent: the compositor's blur shows
fragColor = vec4(c * a, a);                          // premultiplied, as today
```

New uniforms: `bevel`, `rim`, `shine`, `tint`, `tintColor`, `smoke`, `milk`,
`opacity`, `pointer`, `pointerOn`. All of them are 0 or no-ops when glass is off,
the same rule as the liquid neck.

---

## 7. Risks and open questions

- **Readability.** Translucent drawers over a busy window hurt text. Vitreus answers
  with smoke/milk and auto-frost. We get smoke/milk, but auto-frost needs the
  background (option B or C). Mitigation: a higher default opacity, and smoke on for
  dark themes.
- **Blur region shape.** `ext-background-effect` regions are rectangles. Rounded
  corners, necks and drops would blur a little outside the shape, unless the region
  is built from the blob's rects inset by their radii, or we keep the alpha-based
  layer rule (Hyprland's `ignore_alpha`), which follows the real shape. Test both.
- **Shadow.** Today's MultiEffect shadow sits under an opaque blob. Under glass it
  would show through, so it has to be cut out under the shape (pleamar: "under
  glass the shadow does not show through, only around it").
- **HyprGlass churn.** Every Omarchy Hyprland bump needs a matching plugin branch.
  `scripts/upstream-check` should report the plugin's status, and Settings should
  say when it is paused.
- **Fullscreen and the toast window.** The toasts live on a separate overlay surface.
  They get glass only if that window gets the same treatment (its own
  `BackgroundEffect` and namespace in the HyprGlass rule).

---

## Sources

- Vitreus: `shell/Vitreus/vitreus.plm` (glass bodies, `lens: glass_bend`), `pages/bar_glass.plm`. Upstream: <https://github.com/natepayn3/Vitreus> (MIT)
- pleamar: `shell/pleamar/src/lens.rs`, `src/backdrop.wgsl`, `src/shape.wgsl`, `src/platform/wayland.rs`. Upstream: <https://github.com/k4ditano/pleamar>
- HyprGlass: [repository and README](https://github.com/hyprnux/hyprglass), [issue #6, glass on layer surfaces](https://github.com/hyprnux/hyprglass/issues/6)
- Quickshell: [ScreencopyView](https://quickshell.org/docs/v0.3.1/types/Quickshell.Wayland/ScreencopyView), [BackgroundEffect](https://quickshell.org/docs/v0.3.1/types/Quickshell.Wayland/BackgroundEffect), [ext-background-effect support commit](https://git.outfoxxed.me/quickshell/quickshell/commit/d7451848238f7f7ade38f00fe7ef91da1cc719a6)
- Protocol: [ext-background-effect-v1](https://wayland.app/protocols/ext-background-effect-v1), [Phoronix on its merge](https://www.phoronix.com/news/Wayland-Background-Effect)
- Hyprland: [layer rules](https://wiki.hypr.land/configuring/core/rules/layer-rules/) (`blur`, `ignore_alpha`, `no_screen_share`)
