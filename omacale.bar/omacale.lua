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
  windowBorderSize = 1,
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
-- Material 3 & Caelestia expressive spatial curves (the same ones Omacale's
-- SDF drawer shader and QML modals use in Tk.curves / Anim.qml).

hl.curve("specialWorkSwitch", { type = "bezier", points = { { 0.05, 0.7 }, { 0.1, 1 } } })
hl.curve("emphasizedAccel", { type = "bezier", points = { { 0.3, 0 }, { 0.8, 0.15 } } })
hl.curve("emphasizedDecel", { type = "bezier", points = { { 0.05, 0.7 }, { 0.1, 1 } } })
hl.curve("standard", { type = "bezier", points = { { 0.2, 0 }, { 0, 1 } } })

-- Expressive spatial curves (overshoot spring physics matching blob.frag drawers & modals)
hl.curve("spatial", { type = "bezier", points = { { 0.38, 1.21 }, { 0.22, 1 } } })
hl.curve("slowSpatial", { type = "bezier", points = { { 0.39, 1.29 }, { 0.35, 0.98 } } })
hl.curve("fastSpatial", { type = "bezier", points = { { 0.42, 1.67 }, { 0.21, 0.9 } } })

hl.animation({ leaf = "layersIn", enabled = true, speed = 5, bezier = "emphasizedDecel", style = "slide" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 4, bezier = "emphasizedAccel", style = "slide" })
hl.animation({ leaf = "fadeLayers", enabled = true, speed = 5, bezier = "standard" })

-- Window animations: open blooms with spatial spring popin matching SDF modals (450ms),
-- and close collapses swiftly with emphasizedAccel (250ms).
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.5, bezier = "spatial", style = "popin 65%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2.5, bezier = "emphasizedAccel", style = "popin 75%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 5, bezier = "spatial" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "standard" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 4, bezier = "specialWorkSwitch", style = "slidefadevert 15%" })

hl.animation({ leaf = "fade", enabled = true, speed = 6, bezier = "standard" })
hl.animation({ leaf = "fadeDim", enabled = true, speed = 6, bezier = "standard" })
hl.animation({ leaf = "border", enabled = true, speed = 6, bezier = "standard" })

-- Omarchy's looknfeel sets these child leaves explicitly, so they would not
-- inherit the parents above. Pin them to what Caelestia gets by inheritance.
-- Synchronize fadeIn and fadeOut with windowsIn and windowsOut.
hl.animation({ leaf = "fadeIn", enabled = true, speed = 4.5, bezier = "spatial" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 2.5, bezier = "emphasizedAccel" })
hl.animation({ leaf = "fadeSwitch", enabled = true, speed = 6, bezier = "standard" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 5, bezier = "standard" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 5, bezier = "standard" })

-- Omarchy's qconsole.lua sets the special-workspace children (a Quake-style
-- "slide top"/"slide bottom"), which would mask Caelestia's slidefadevert.
hl.animation({ leaf = "specialWorkspaceIn", enabled = true, speed = 4, bezier = "specialWorkSwitch", style = "slidefadevert 15%" })
hl.animation({ leaf = "specialWorkspaceOut", enabled = true, speed = 4, bezier = "specialWorkSwitch", style = "slidefadevert 15%" })

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
