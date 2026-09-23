-- ╭─────────────────────────────────────────────────────────────────────────╮
-- │  Omacale look'n'feel — Caelestia's Hyprland styling for Omarchy         │
-- │  Load it from ~/.config/hypr/looknfeel.lua (before your own tweaks):    │
-- │                                                                         │
-- │    pcall(dofile, os.getenv("HOME")                                      │
-- │      .. "/.config/omarchy/plugins/omacale.bar/omacale.lua")             │
-- │                                                                         │
-- │  pcall keeps Hyprland starting if Omacale is uninstalled; dofile (not   │
-- │  require) re-reads it on every `hyprctl reload`.                        │
-- ╰─────────────────────────────────────────────────────────────────────────╯
--
-- Ported from caelestia-dots (hypr/variables.lua, hypr/hyprland/animations.lua,
-- decoration.lua, general.lua, rules.lua). Colours stay with the Omarchy
-- theme: border colours come from the theme's hyprland.lua, and the shadow
-- tint is read from its colors.toml accent.

-- ── Variables (caelestia-dots hypr/variables.lua) ───────────────────────────

local vars = {
  -- Blur
  blurEnabled = true,
  blurSpecialWs = false,
  blurPopups = true,
  blurInputMethods = true,
  blurSize = 8,
  blurPasses = 2,
  blurXray = false,

  -- Shadow
  shadowEnabled = true,
  shadowRange = 15,
  shadowRenderPower = 4,

  -- Gaps
  workspaceGaps = 20,
  windowGapsIn = 5,
  windowGapsOut = 10,
  singleWindowGapsOut = 20,

  -- Window styling
  windowOpacity = 0.95,
  windowRounding = 15,
  windowBorderSize = 3,
}

-- Caelestia tints the shadow with its scheme's inversePrimary at 0x10 alpha.
-- The closest Omarchy source is the theme accent.
local function theme_accent()
  local f = io.open(os.getenv("HOME") .. "/.local/state/omarchy/current/theme/colors.toml", "r")
  if not f then return nil end
  local text = f:read("a")
  f:close()
  return text:match('\naccent%s*=%s*"#(%x%x%x%x%x%x)"')
end
local shadow_colour = "rgba(" .. (theme_accent() or "000000") .. "10)"

-- ── General / decoration (general.lua, decoration.lua) ──────────────────────

hl.config({
  general = {
    gaps_workspaces = vars.workspaceGaps,
    gaps_in = vars.windowGapsIn,
    gaps_out = vars.windowGapsOut,
    border_size = vars.windowBorderSize,
  },

  dwindle = {
    preserve_split = true,
    smart_split = false,
    smart_resizing = true,
  },

  decoration = {
    rounding = vars.windowRounding,

    blur = {
      enabled = vars.blurEnabled,
      xray = vars.blurXray,
      special = vars.blurSpecialWs,
      ignore_opacity = true,
      new_optimizations = true,
      popups = vars.blurPopups,
      input_methods = vars.blurInputMethods,
      size = vars.blurSize,
      passes = vars.blurPasses,
    },

    shadow = {
      enabled = vars.shadowEnabled,
      range = vars.shadowRange,
      render_power = vars.shadowRenderPower,
      color = shadow_colour,
    },
  },

  misc = {
    animate_manual_resizes = false,
    animate_mouse_windowdragging = false,
  },

  animations = {
    enabled = true,
  },
})

-- ── Animations (animations.lua) ─────────────────────────────────────────────
-- Hyprland's windows are given the motion of Omacale's own drawers, so a
-- window and a blob drawer arriving at the same moment read as one gesture.
--
-- The two engines turn out to agree exactly, which is what makes this a port
-- and not an approximation:
--
--   * Hyprland's `speed` is deciseconds -- hyprutils' CBaseAnimatedVariable
--     computes SPENT = clamp((elapsed_ms / 100) / speed, 0, 1), so a leaf's
--     duration in ms is speed * 100. Every speed below is a Tk.durations
--     value divided by 100.
--   * `hl.curve{ points = { {x1,y1}, {x2,y2} } }` is a cubic bezier through
--     (0,0) and (1,1), evaluated as getYForPoint(SPENT) with NO clamping of
--     y. That is the same math as Qt's Easing.BezierSpline over a 6-value
--     [x1,y1,x2,y2,1,1] array, so the Tk.curves entries transfer verbatim --
--     overshoot (y > 1) included, which is what gives the spatial curves
--     their settle.
--
-- The one curve that cannot cross is `emphasized`: Caelestia's is a TWO
-- segment spline (12 values), and Hyprland's addBezierWithName only takes two
-- control points. It is fitted below.

-- Tk.durations, in Hyprland's deciseconds (Tk.animScale = 1).
local D = {
  small = 2,          -- 200ms
  normal = 4,         -- 400ms
  large = 6,          -- 600ms
  fastSpatial = 3.5,  -- 350ms
  spatial = 5,        -- 500ms   (Tk.durations.defaultSpatial)
  slowSpatial = 6.5,  -- 650ms
  fastEffects = 1.5,  -- 150ms
  effects = 2,        -- 200ms
  slowEffects = 3,    -- 300ms
}

-- Tk.curves, verbatim (see the note above on why "verbatim" is literal here).
hl.curve("standard", { type = "bezier", points = { { 0.2, 0 }, { 0, 1 } } })
hl.curve("standardAccel", { type = "bezier", points = { { 0.3, 0 }, { 1, 1 } } })
hl.curve("standardDecel", { type = "bezier", points = { { 0, 0 }, { 0, 1 } } })
hl.curve("emphasizedAccel", { type = "bezier", points = { { 0.3, 0 }, { 0.8, 0.15 } } })
hl.curve("emphasizedDecel", { type = "bezier", points = { { 0.05, 0.7 }, { 0.1, 1 } } })

-- Tk.curves.emphasized is [0.05,0, 2/15,0.06, 1/6,0.4, 5/24,0.82, 0.25,1, 1,1]
-- -- two cubic segments, which a single Hyprland bezier cannot express. This
-- is the least-squares single-cubic fit over 1001 samples, constrained to
-- y <= 1 so it keeps emphasized's no-overshoot character: RMSE 0.043, worst
-- error 0.12 at t/T = 0.11 (the near-flat hold before emphasized's jump).
-- Reusing "standard" instead would be roughly twice as far off.
hl.curve("emphasized", { type = "bezier", points = { { 0.367, 0.665 }, { 0, 1 } } })

-- Expressive spatial curves. These overshoot: defaultSpatial peaks at 1.014
-- of the travel at t/T = 0.56, slowSpatial at 1.019, fastSpatial at 1.092.
hl.curve("spatial", { type = "bezier", points = { { 0.38, 1.21 }, { 0.22, 1 } } })
hl.curve("slowSpatial", { type = "bezier", points = { { 0.39, 1.29 }, { 0.35, 0.98 } } })
hl.curve("fastSpatial", { type = "bezier", points = { { 0.42, 1.67 }, { 0.21, 0.9 } } })

-- Tk.curves effects, used by the colour animations (CAnim.qml).
hl.curve("fastEffects", { type = "bezier", points = { { 0.31, 0.94 }, { 0.34, 1 } } })
hl.curve("effects", { type = "bezier", points = { { 0.34, 0.8 }, { 0.34, 1 } } })
hl.curve("slowEffects", { type = "bezier", points = { { 0.34, 0.88 }, { 0.34, 1 } } })

-- Windows move like drawers. Omacale's drawers are a constant-size rect that
-- translates out of the edge it is attached to (ScreenScope's `sbx`, `ly`,
-- `uy`, ... are all `edge + (size + 5) * off`, with off driven by a plain
-- `Anim {}` -- defaultSpatial over 500ms). Hyprland's "slide" style is the
-- same construction: CWindowAnimationController::applySlide pins size.from =
-- size.to and only animates position in from the nearest monitor edge, so the
-- client texture is never scaled and the window stays crisp while the spatial
-- curve carries it 1.4% past its resting spot and back.
--
-- "popin" would scale the window from its centre instead, which is the motion
-- of Settings (r4) and the overview (r7) rather than of the drawers, and it
-- renders the window briefly larger than its buffer at the overshoot peak.
hl.animation({ leaf = "windowsIn", enabled = true, speed = D.spatial, bezier = "spatial", style = "slide" })
-- Closing accelerates out instead of overshooting: past the ~40% mark a
-- sliding window is already off-screen, so an overshoot tail would be spent
-- on nothing. This is the same reasoning behind Omacale closing Settings and
-- the overview on `emphasized` while opening them on slowSpatial.
hl.animation({ leaf = "windowsOut", enabled = true, speed = D.normal, bezier = "emphasizedAccel", style = "slide" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = D.spatial, bezier = "spatial" })

hl.animation({ leaf = "layersIn", enabled = true, speed = D.normal, bezier = "emphasizedDecel", style = "slide" })
hl.animation({ leaf = "layersOut", enabled = true, speed = D.normal, bezier = "emphasizedAccel", style = "slide" })
hl.animation({ leaf = "fadeLayers", enabled = true, speed = D.normal, bezier = "standard" })

hl.animation({ leaf = "workspaces", enabled = true, speed = D.normal, bezier = "standard" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = D.normal, bezier = "emphasizedDecel", style = "slidefadevert 15%" })

hl.animation({ leaf = "fade", enabled = true, speed = D.normal, bezier = "standard" })
hl.animation({ leaf = "fadeDim", enabled = true, speed = D.normal, bezier = "standard" })
-- The border is a colour animation, so it takes CAnim.qml's pairing
-- (slowEffects over 300ms) rather than the geometry curves above.
hl.animation({ leaf = "border", enabled = true, speed = D.slowEffects, bezier = "slowEffects" })

-- Omarchy's looknfeel sets these child leaves explicitly, so they would not
-- inherit the parents above. Pin them to what Caelestia gets by inheritance.
-- fadeIn/fadeOut run for exactly as long as windowsIn/windowsOut so a window
-- finishes arriving and finishes appearing together. They use the decel/accel
-- curves rather than "spatial": a fade animates alpha, and spatial's
-- overshoot would drive it past 1.0.
hl.animation({ leaf = "fadeIn", enabled = true, speed = D.spatial, bezier = "emphasizedDecel" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = D.normal, bezier = "emphasizedAccel" })
hl.animation({ leaf = "fadeSwitch", enabled = true, speed = D.normal, bezier = "standard" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = D.normal, bezier = "standard" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = D.normal, bezier = "standard" })

-- Omarchy's qconsole.lua sets the special-workspace children (a Quake-style
-- "slide top"/"slide bottom"), which would mask Caelestia's slidefadevert.
-- Caelestia's own specialWorkSwitch curve is {0.05,0.7},{0.1,1} -- the same
-- two control points as emphasizedDecel, so it is not defined twice here.
hl.animation({ leaf = "specialWorkspaceIn", enabled = true, speed = D.normal, bezier = "emphasizedDecel", style = "slidefadevert 15%" })
hl.animation({ leaf = "specialWorkspaceOut", enabled = true, speed = D.normal, bezier = "emphasizedDecel", style = "slidefadevert 15%" })

-- ── Rules (rules.lua) ───────────────────────────────────────────────────────

-- Caelestia's window opacity, applied through Omarchy's default-opacity tag
-- so apps that opt out (terminals, video, games) keep doing so.
o.window({ tag = "default-opacity" }, { opacity = vars.windowOpacity .. " " .. vars.windowOpacity })

-- A lone window gets wider outer gaps.
hl.workspace_rule({ workspace = "w[tv1]s[false]", gaps_out = vars.singleWindowGapsOut })
hl.workspace_rule({ workspace = "f[1]s[false]", gaps_out = vars.singleWindowGapsOut })

-- Shell layers: Caelestia fades its drawers/background and never animates the
-- border exclusion zone. Omacale's drawers animate themselves inside the layer.
hl.layer_rule({ match = { namespace = "omacale-reserve" }, no_anim = true })
hl.layer_rule({ match = { namespace = "^(omacale|omarchy-background)$" }, animation = "fade" })

-- Caelestia's layersIn/layersOut slide would drop Omarchy's own overlays (OSD,
-- notifications, polkit, the overview plugin, ...) in from the top and pull
-- them back up. Keep them on Omarchy's stock fade; layers Omarchy marks
-- no_anim (bar, menu, pickers) stay instant.
hl.layer_rule({ match = { namespace = "^(omarchy-.*|quickshell:overview.*)$" }, animation = "fade" })

-- Screenshot, OCR and the colour picker all run hyprpicker (the screen freeze
-- or the picker itself), which would otherwise take the slide too. Keep it
-- instant, as Omarchy already does for slurp's "selection" layer.
hl.layer_rule({ match = { namespace = "^(hyprpicker|selection)$" }, no_anim = true, animation = "none" })
