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
-- The one curve that cannot cross is `emphasized`: Omacale's is a TWO segment
-- spline (12 values), and Hyprland's addBezierWithName only takes two control
-- points. It is fitted below.
--
-- ── Matching the motion, not just the numbers ───────────────────────────────
--
-- A curve and a duration alone do NOT make two animations match, because the
-- things being moved are not the same size. Omacale's drawers are small: the
-- sidebar and utilities are 430px wide and slide in by their own width plus
-- 5px, so 435px over 500ms. A maximised window here is 1824px wide and a
-- workspace switch crosses the whole 1920px monitor. Handing those the same
-- 500ms makes them travel 4-7x faster than the drawers, which is what broke
-- the illusion even though every curve and duration was already "correct".
--
-- So each leaf is matched on PEAK EDGE VELOCITY against the drawer, which is
-- 435px * 3.29 (spatial's peak rate) / 0.5s = 2859 px/s. Two levers do it:
--
--   1. Shorten the travel. `popin P%` starts a window at P% of its size, so
--      each edge only moves (1-P)/2 of that size -- popin 50% turns an 1824px
--      window into a 456px edge move, the drawer's 435px almost exactly.
--      Window `slide` has NO percentage (applyWindowStyle only parses a
--      direction), so it always travels the full window width and cannot be
--      velocity-matched at any duration -- 870 px/s would need 2100ms.
--      `slidefade P%` / `slidefadevert P%` are the same lever for workspaces,
--      moving monitor_size * P/100 while cross-fading.
--   2. Stretch the duration, but only as far as Omacale itself does. Its own
--      tokens imply a strongly sub-linear law: fastSpatial moves ~40px in
--      350ms and spatial moves 435px in 500ms, so duration = 500 * (d/435)^0.15.
--      Ten times the distance buys barely half again the time. Every duration
--      below agrees with that law to within a few ms.
--
-- Resulting peak velocities, as a multiple of the drawer's:
--   windowsIn popin 50%    1.05x      layersIn slide        0.99x
--   workspaces slidefade   1.10x      specialWorkspace      0.93x
--   windowsMove            1.75x  <-- the one that cannot be fixed; its travel
--                                     is set by the tiling layout, not by us.
-- The *Out leaves land near 1.6x, but on emphasizedAccel the peak falls at the
-- very END of the curve, by which point the window has already shrunk and
-- faded to nothing, so it is not seen.

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

-- Windows grow like Settings and the overview. Omacale's floating drawers
-- (r4, r7) open by scaling out of a small centred pill -- ScreenScope's
-- `nw = nfw * (1 - 0.55 * nOff)`, so 45% of full width up to 100%. "popin 50%"
-- is that same construction: applyPopin seeds size.from at GOALSIZE * 0.5 and
-- pos.from at the centre, then animates both to the goal.
--
-- 50% is not a taste pick, it is the number that makes a window's edges move
-- at the drawers' speed: (1 - 0.50)/2 * 1824px = 456px, against the drawers'
-- 435px, both over 500ms. "slide" was the faithful *shape* of the drawer
-- motion but it travels the window's whole width, which is 4.2x the drawers'
-- velocity and has no percentage to dial it back.
hl.animation({ leaf = "windowsIn", enabled = true, speed = D.spatial, bezier = "spatial", style = "popin 50%" })
-- Closing accelerates out instead of overshooting: an overshoot tail would be
-- spent on a window that has already collapsed. This is the same reasoning
-- behind Omacale closing Settings and the overview on `emphasized` while
-- opening them on slowSpatial.
hl.animation({ leaf = "windowsOut", enabled = true, speed = D.normal, bezier = "emphasizedAccel", style = "popin 50%" })
-- The one leaf whose travel we do not control: a tiling reflow moves a window
-- edge by whatever the layout says, ~912px on a two-window split here. The
-- sub-linear law puts that at 558ms, so it takes D.large and still runs ~1.75x
-- the drawers. Shortening it is not possible without changing the layout.
hl.animation({ leaf = "windowsMove", enabled = true, speed = D.large, bezier = "spatial" })

-- A layer surface slides in by its own size, and Omarchy's layers (the OSD,
-- notification toasts) are drawer-sized -- ~430px -- so "slide" is already
-- velocity-matched here without a percentage. This is the one place the
-- drawers' literal motion transfers unchanged.
hl.animation({ leaf = "layersIn", enabled = true, speed = D.spatial, bezier = "spatial", style = "slide" })
hl.animation({ leaf = "layersOut", enabled = true, speed = D.normal, bezier = "emphasizedAccel", style = "slide" })

-- A plain "slide" drags the whole 1920px monitor across in one go, 6.9x the
-- drawers. slidefade moves monitor_size * P/100 and cross-fades the rest, so
-- 25% is 480px -- the drawers' 435px again.
hl.animation({ leaf = "workspaces", enabled = true, speed = D.spatial, bezier = "spatial", style = "slidefade 25%" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = D.normal, bezier = "spatial", style = "slidefadevert 30%" })

-- Fades take Omacale's own opacity curve (ScreenScope's `Anim { type:
-- "effects" }`), not the geometry curves: `spatial` would drive alpha past 1.0
-- on its overshoot, and `emphasizedDecel` has a peak rate of 13.97 -- it snaps
-- to 70% opacity in the first few frames, which defeats the fade entirely.
hl.animation({ leaf = "fade", enabled = true, speed = D.normal, bezier = "effects" })
hl.animation({ leaf = "fadeDim", enabled = true, speed = D.normal, bezier = "effects" })
-- The border is a colour animation, so it takes CAnim.qml's pairing
-- (slowEffects over 300ms) rather than the geometry curves above.
hl.animation({ leaf = "border", enabled = true, speed = D.slowEffects, bezier = "slowEffects" })

-- Omarchy's looknfeel sets these child leaves explicitly, so they would not
-- inherit the parents above. fadeIn/fadeOut run for exactly as long as
-- windowsIn/windowsOut, so a window finishes growing and finishes appearing
-- together.
hl.animation({ leaf = "fadeIn", enabled = true, speed = D.spatial, bezier = "effects" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = D.normal, bezier = "emphasizedAccel" })
hl.animation({ leaf = "fadeSwitch", enabled = true, speed = D.normal, bezier = "effects" })
hl.animation({ leaf = "fadeLayers", enabled = true, speed = D.normal, bezier = "effects" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = D.normal, bezier = "effects" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = D.normal, bezier = "effects" })

-- Omarchy's qconsole.lua sets the special-workspace children (a Quake-style
-- "slide top"/"slide bottom"), which would mask the slidefadevert above.
hl.animation({ leaf = "specialWorkspaceIn", enabled = true, speed = D.normal, bezier = "spatial", style = "slidefadevert 30%" })
hl.animation({ leaf = "specialWorkspaceOut", enabled = true, speed = D.normal, bezier = "spatial", style = "slidefadevert 30%" })

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
