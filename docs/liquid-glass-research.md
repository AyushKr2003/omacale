# Liquid glass for Omacale: research and plan

Status: option A is built (Settings › Glass, `core/Glass.qml`, the glass path in
`shaders/blob.frag`); option C is researched and planned, not built. Written
2026-10-13 against Hyprland 0.56.2 and Quickshell 0.3.1 (both what this machine
runs), Vitreus and pleamar as checked out under `shell/`. §8 lists what the second
pass checked and corrected.

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
| **2. Light** | A translucent tinted fill, the edge light (which can follow the pointer), "smoke" (darker) and "milk" (lighter) veils, a shadow round the shape | pleamar's shape shader, from the shape's signed distance | No |
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
| `ext-background-effect-v1` blur region (`BackgroundEffect.blurRegion` on a window) | **Yes**, checked: Quickshell 0.3.1 ships `Quickshell.Wayland._BackgroundEffect`, and Hyprland 0.56.2's binary carries `ext_background_effect_manager_v1` | An attached property on a window, taking a `Region`; `null` removes the blur. `Region` does rounded rects (`radius`, per-corner radii) and nests (`Intersection.Subtract`), but a wl_region is still a union of rectangles, so a rounded corner is a staircase, and a neck or a drop isn't a rounded rect at all |
| Custom fragment shaders (`ShaderEffect`, `.qsb`) | **Yes** | `blob.frag` already draws every drawer from SDFs: everything layer 2 needs is there |
| Pointer position over our surfaces | **Yes**, over the drawers (`MouseArea` hover) | Outside the input mask nothing arrives (see CLAUDE.md "The pointer leaving the bar reaches nothing"); fine for a shine that follows the pointer over a drawer |
| Live screen capture (`ScreencopyView { live: true; captureSource: screen }`) | **Yes** (wlr-screencopy / ext-image-copy-capture) | Includes our own surface, so we would have to unmix as pleamar does |
| Live window capture (`captureSource: Toplevel`) | **Yes** (hyprland-toplevel-export) | The overview uses it; one capture per window, so it can't stand in for "everything behind" |
| Reading the pixels behind our own surface directly | **No** | No Wayland or Qt API for it. This is the whole problem |
| Hiding our layer from screencopy (`no_screen_share` layer rule) | Exists | It blacks the surface out rather than skipping it. Our window is full-screen, so the capture would be black. No help |
| **HyprGlass** Hyprland plugin | Installable (`hyprpm`), not installed here (`hyprctl plugin list`: none) | Real refraction done *inside the compositor*; layer surfaces supported (beta, March 2026). See §3.C |

---

## 3. The options

### A. Drawn glass on compositor blur: Vitreus's default look, in Omacale's shader (built)

**What:** layers 1 and 2. Drawers become translucent with Hyprland's blur behind them
(the same layer rule as Transparency). `blob.frag` adds the light from the SDF it
already computes. This is pleamar's `shape.wgsl` path *without* a lens (the `else`
branch after `if (glass > 0.0 && u.backdrop.x > 0.5 …)`), which is all Vitreus's
default glass is:

- **Fill:** the surface colour at the body's opacity (pleamar: `mix(1, 0.36, glass)`;
  Omacale: Settings › Glass › Opacity, 30-100%), plus a 0.1 lift in the 2 px inside
  the edge (pleamar's `rim:`, which Vitreus sets to 10%).
- **Smoke / milk:** a veil of black at `0.35·smoke` and white at `0.3·milk` over the
  blur. pleamar's `glass_tone` only applies when it has the background (the lens);
  over the compositor's blur, a veil "is as near as it gets".
- **Edge light:** `shine = rim·(0.85·facing^1.6 + 0.4·away^1.6 + 0.12) + 0.14·fresnel`,
  with `rim = 1 − smoothstep(0.4, 3, inside)`, `fresnel = exp(−inside/10)`, the light
  from the top left `(−0.55, −0.83)`, painted white over everything. There's no
  Schlick term or specular lobe: the first draft of this doc had both, and pleamar
  has neither.
- **Light that follows the pointer** (`shine: pointer`): one direction per shape,
  from its centre to the pointer. In one merged SDF, "the shape" is the nearest rect
  (the smallest `d[i]`). The frame keeps the top-left light, and the fillet between a
  drawer and the frame turns from one to the other (`smoothstep(−k, k, dFrame − dn)`),
  so there's no seam.
- **Shadow round the shape only:** under glass, MultiEffect's shadow (drawn under the
  whole layer) would show through, so with glass on the layer is off and the shader
  draws `0.22·(1 − smoothstep(0, 18 px, d))²` outside the shape. That also saves the
  screen-sized offscreen pass.

**Why not `BackgroundEffect.blurRegion`:** the layer rule with `ignore_alpha` blurs
exactly where our pixels are opaque enough, which follows the fillets, necks, drops
and ripples. A region would have to be rebuilt from the rects every frame of a
liquid animation and would still be rectangles. The rule stays. The threshold
(`Glass.blurFloor`) sits above the shadow's peak and below the body's opacity.

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

- `hg.config({ layers = { enabled = true } })`, then per namespace
  `hg.layer("omacale", { preset = …, mask_mode = "alpha", mask_threshold = …, mask_feather = …, live_resample = … })`
  (`exclude = true` opts a namespace out).
- **`mask_mode`**: `auto` (default: where the client asks for blur, otherwise where
  it is visible), `region` (only the `ext-background-effect` region), `alpha` (only
  where content is visible). Omacale wants **`alpha`**: it follows the blob's fillets,
  necks and drops exactly, as our Hyprland blur rule does. `mask_threshold` must sit
  above our shadow's opacity. With glass on that is `Glass.blurFloor` (0.25 at
  most), the same number the blur rule uses.
- `hyprglass_item_v1`, a protocol of its own for subsurfaces: a preset and a shape
  (rect + four radii) per item. Quickshell has no client for it, and our drawers
  aren't subsurfaces, so it's no use to us.
- Presets: `subtle`, `glass`, `clear`, `high_contrast`, `pomme`, or custom
  (`hg.preset(name, { … })`, with per-theme variants and `inherits`). Overridable
  options and their global defaults: `refraction_strength` 0.6,
  `chromatic_aberration` 0.5, `glass_opacity` 1.0, `blur_strength` 2.0,
  `edge_thickness` 0.06, `specular_strength` 0.8, `specular_angle` 0,
  `fresnel_strength` 0.6, `bevel_strength` 0, `bevel_size` 6, `lens_distortion` 0.5,
  `blur_iterations` 3, `tint_color` 0x8899aa22; per theme, `brightness`, `contrast`,
  `saturation`, `vibrancy`, `adaptive_dim`/`adaptive_boost`.
- `live_resample` (on by default, `live_resample_fps` 30) re-renders when what is
  behind changes, from a cached background; `force_live_resample` does every frame.
- `hyprctl hyprglass status` (`-j`) says whether it can draw; "hook missing" means a
  Hyprland update broke the layer hook. `stats` and `items` exist too.

**What Omacale would do:**

- Draw the drawers translucent (as with Transparency on) so there is something to
  see through.
- Detect the plugin (`hyprctl -j hyprglass status`; "hook missing" counts as absent),
  and offer "Use HyprGlass" in Settings only when it can draw.
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

## 5. Settings (as built, plus C)

Settings › Frame & motion › **Glass** (a page next to Motion), off by default. Off,
Omacale draws exactly as before: the shader returns its old output, the layer and
shadow are Caelestia's, and Colours only reads Transparency.

| Row | Key | Default |
|---|---|---|
| Glass (master toggle) | `glass.enabled` | off |
| Opacity (how much of the body covers what is behind) | `glass.opacity` | 0.36, pleamar's (30-100%) |
| Tone: Clear / Auto / Smoked / Milky | `glass.tone` | clear, as Vitreus (auto: smoked on a dark scheme, milky on a light one) |
| Smoke / Milk / Tone strength (the one row for the tone chosen) | `glass.toneAmount` | 0.5 |
| Tune Hyprland's blur for glass | `glass.tuneBlur` | on (§9) |
| Frost (Hyprland's blur size; passes follow) | `glass.frost` | 5 (1-12) |
| Edge light | `glass.light` | 1x (0-2x) |
| Light follows the pointer | `glass.pointer` | on |
| *Planned:* Use HyprGlass when installed (shown only if detected) | `glass.hyprglass` | off |
| *Planned:* HyprGlass preset | `glass.hyprglassPreset` | subtle |

Glass implies Transparency's palette (`Colours.transparent`), with the body's
opacity as the base alpha, so the cards inside the drawers are veils over the glass,
as Vitreus's are, not opaque plates on it. The toasts' window gets the same
translucent colours and blur, but not the edge light (it isn't drawn by `blob.frag`).

Left out on purpose, for now: presets (four numbers don't need them), a bevel
(pleamar draws no bevel without the lens), per-drawer toggles (a glass frame with one
opaque drawer reads as a bug), and a preview card (the drawers themselves are the
preview).

---

## 6. The shader (as built)

Three uniforms at the end of `blob.frag`'s block: `glassA` (on, body opacity, smoke,
milk), `glassB` (edge light, shadow alpha, shadow reach, pointer on) and `pointer`.
With `glassA.x == 0` the shader writes exactly its old output and returns, so every
other `BlobSurface` (Settings' frame, the style and Motion previews, `BlobPopup`),
which leaves them at zero, is unchanged. The glass path, in order:

1. `outward` from `dFdx/dFdy(merged)`, `inside = max(−merged, 0)`.
2. The light direction: top left, or towards the pointer from the nearest rect's
   centre, blended into the top left over the frame fillet.
3. `shine` as pleamar's (above), times the edge light.
4. Premultiplied `over`s: the shadow outside the shape, the fill (lifted on its
   inner 2 px) at the body's opacity, the smoke veil, the milk veil, the white shine.

The pointer is `ScreenScope`'s `interactions` MouseArea, bound only while the light
follows it, so moving the pointer doesn't redraw the frame otherwise. When the
pointer leaves the input mask, the light stays where it last pointed (see CLAUDE.md,
"The pointer leaving the bar reaches nothing").

---

## 7. Risks and open questions

- **Readability.** Translucent drawers over a busy window hurt text. Vitreus answers
  with smoke/milk and auto-frost. We get smoke/milk (Auto picks smoke on dark
  schemes), but auto-frost needs the background (option B or C). Seen over a playing
  video: the smoked body plus the cards' layer alpha keeps the dashboard and sidebar
  readable at the default 50%.
- **Blur region shape.** Settled: the alpha-based layer rule stays (see §3.A).
- **Shadow.** Settled: with glass on, the shader draws it round the shape only.
- **Pointer cost.** With the light following the pointer, every pointer move over the
  frame or a drawer is one full-screen pass of `blob.frag`. It's the same pass a drawer
  animation already costs each frame. The toggle turns it off.
- **HyprGlass churn.** Every Omarchy Hyprland bump needs a matching plugin branch.
  `scripts/upstream-check` should report the plugin's status, and Settings should
  say when it is paused.
- **The toast window.** The toasts live on a separate overlay surface. They get the
  translucent colours and the blur (the rule matches `omacale-notifications`), but
  not the edge light. Under HyprGlass their namespace goes in the same rule.

---

## 8. Second pass (2026-10-13): what was checked and corrected

- **Checked on this machine:** Quickshell 0.3.1 has `BackgroundEffect` (attached
  `blurRegion: Region`). Hyprland 0.56.2 implements `ext-background-effect-v1`.
  HyprGlass isn't installed. Hyprland's blur is 3 passes of size 8.
- **Corrected:** pleamar's no-lens light has no Schlick fresnel and no specular lobe.
  Its fresnel is `exp(−inside/10)`, and `facing`/`away` are raised to 1.6. Smoke and
  milk without the lens are black/white veils, not `glass_tone`. The fill is 36%
  opaque at `glass: 100%`. Vitreus's `rim: 10%` is the 2 px inner lift, not the
  edge light. (§3.A, §6.)
- **Corrected:** Quickshell's `Region` *does* take corner radii. The reason to keep
  the layer rule is the liquid shapes, not the rounding.
- **New about HyprGlass:** `mask_mode = "alpha"` is the setting Omacale needs.
  `hyprglass_item_v1` is subsurface-only. The full option list and defaults are in §3.C.
- **Next for C:** a `HyprGlassService` that polls `hyprctl -j hyprglass status` on
  start and on `configreloaded`; Settings rows shown only when it can draw; and
  `hg.layer("^omacale(-notifications)?$", { mask_mode = "alpha", mask_threshold = Glass.blurFloor, preset = … })`
  through `hyprctl eval`, guarded by `if hg then … end`, mirrored in `omacale.lua`.
  With it on, `Glass.light` goes to 0 so the two rims don't double up.

---

## 9. Third pass: why it didn't look like Vitreus, and the blur under it

The first build looked flat and dirty next to Vitreus. Most of that wasn't the shader:

- **The blur was the user's, made for opaque windows.** This machine's
  `~/.config/hypr/looknfeel.lua` sets `noise = 0.1` (Hyprland's default is 0.0117,
  so ~8.5x the grain), `vibrancy = 0.5` (default 0.1696) and size 8 × 3 passes.
  Through a clear body that reads as film grain, neon colour and a smear. Vitreus
  doesn't set Hyprland's blur at all. Its look assumes the stock noise and vibrancy,
  and a light frost (the Glass page's slider runs Hyprland's size 0-20, passes
  `1 + floor((size − 1) / 6)`).
- **Hyprland 0.56 can't scope this to our layer.** Checked against the binary and by
  `hyprctl eval`: a layer rule takes `blur`, `ignore_alpha`, `xray`, `blur_popups`,
  `no_anim`, `above_lock`, `no_screen_share`, and nothing else (`blur_size`:
  "unknown field"). Noise, vibrancy, size and passes are global.
- **So `services/GlassBlur.qml` sets them globally, at runtime, only while glass is
  on** (Settings › Glass › "Tune Hyprland's blur for glass", on by default):
  `enabled = true`, noise and vibrancy back to Hyprland's defaults, size = Frost,
  passes 1/2/3 for sizes ≤3/≤8/more. The user's values are read once into
  `$XDG_RUNTIME_DIR/omacale-glass-blur.orig` and put back, exactly, when glass or the
  tuning goes off. `hyprctl reload` re-reads them from the user's config before
  re-tuning, and a shell restart keeps the file (Hyprland is still running ours).
  Windows that blur (a translucent terminal) get the same blur while glass is on.
  That is the cost, and why it's a switch.
- **The material was heavier than Vitreus's.** Body at 50% with a 17% smoke veil
  (tone "auto" on a dark scheme), against Vitreus's tint at 36% with no smoke. The
  defaults are now pleamar's: 36%, clear.

Verified live: off → on → `hyprctl reload` → frost change → off. Each left Hyprland
with the expected values, and off restored `size 8, passes 3, noise 0.1,
vibrancy 0.5` and removed the file.

---

## Sources

- Vitreus: `shell/Vitreus/vitreus.plm` (glass bodies, `lens: glass_bend`), `pages/bar_glass.plm`. Upstream: <https://github.com/natepayn3/Vitreus> (MIT)
- pleamar: `shell/pleamar/src/lens.rs`, `src/backdrop.wgsl`, `src/shape.wgsl`, `src/platform/wayland.rs`. Upstream: <https://github.com/k4ditano/pleamar>
- HyprGlass: [repository and README](https://github.com/hyprnux/hyprglass) (layer options, `mask_mode`, `hyprglass_item_v1`, option defaults), [issue #6, glass on layer surfaces](https://github.com/hyprnux/hyprglass/issues/6)
- Quickshell: [Region](https://quickshell.org/docs/v0.3.1/types/Quickshell/Region) (corner radii, nesting)
- Quickshell: [ScreencopyView](https://quickshell.org/docs/v0.3.1/types/Quickshell.Wayland/ScreencopyView), [BackgroundEffect](https://quickshell.org/docs/v0.3.1/types/Quickshell.Wayland/BackgroundEffect), [ext-background-effect support commit](https://git.outfoxxed.me/quickshell/quickshell/commit/d7451848238f7f7ade38f00fe7ef91da1cc719a6)
- Protocol: [ext-background-effect-v1](https://wayland.app/protocols/ext-background-effect-v1), [Phoronix on its merge](https://www.phoronix.com/news/Wayland-Background-Effect)
- Hyprland: [layer rules](https://wiki.hypr.land/configuring/core/rules/layer-rules/) (`blur`, `ignore_alpha`, `no_screen_share`)
