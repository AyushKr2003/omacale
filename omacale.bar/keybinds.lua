-- ╭─────────────────────────────────────────────────────────────────────────╮
-- │  Omacale keybindings — paste into ~/.config/hypr/bindings.lua           │
-- │  Each action is an IPC call into the running Omarchy shell:             │
-- │  omarchy-shell omacale <launcher|dashboard|session|settings|close>      │
-- │  Keys below are unbound in a stock Omarchy install. Check yours with:   │
-- │  omarchy menu keybindings --print                                       │
-- ╰─────────────────────────────────────────────────────────────────────────╯

-- ── Helpers ─────────────────────────────────────────────────────────────────
-- o.rebind is provided by Omarchy (default/hypr/helpers.lua); restated here so
-- this file is self-contained when pasted. Same arguments as o.bind.

function o.rebind(keys, description, dispatcher, options)
  hl.unbind(keys)
  o.bind(keys, description, dispatcher, options)
end

-- ── Drawers ─────────────────────────────────────────────────────────────────

o.bind("SUPER + A", "Omacale launcher", "omarchy-shell omacale launcher")
o.bind("SUPER + D", "Omacale dashboard", "omarchy-shell omacale dashboard")
o.bind("SUPER + N", "Omacale notifications sidebar", "omarchy-shell omacale sidebar")
o.bind("SUPER + U", "Omacale quick toggles", "omarchy-shell omacale utilities")
o.bind("SUPER + SHIFT + ESCAPE", "Omacale session menu", "omarchy-shell omacale session")
o.bind("SUPER + SHIFT + I", "Omacale settings", "omarchy-shell omacale settings")

-- ── Dashboard tabs ──────────────────────────────────────────────────────────

o.bind("SUPER + ALT + D", "Omacale media", "omarchy-shell omacale dashboardTab media")
o.bind("SUPER + ALT + P", "Omacale performance", "omarchy-shell omacale dashboardTab performance")

-- ── Keyboard ────────────────────────────────────────────────────────────────
-- Omarchy's own SUPER + CTRL + A/B/W/P and 1..9 already open Omacale's popouts
-- (1..9 count the third-party widgets in the plugin pill). This one is the
-- bar focus mode: the bar takes the keyboard and a cursor walks its items --
-- j/k or arrows move, Enter/Space act, Menu or Shift+F10 opens a tray item's
-- menu, 1..9 switch workspace, Escape leaves. code:19 is the 0 key, which
-- Omarchy's code:10..18 loop leaves free.

o.bind("SUPER + CTRL + code:19", "Omacale bar focus", "omarchy-shell omacale barFocus")

-- Any bar popout straight from a key, opened with the keyboard (again closes
-- it). Omarchy's letters already cover network, bluetooth, power and audio;
-- these are the ones it has no key for (Y and U are free in a stock Omarchy;
-- check with: omarchy menu keybindings --print). Remove the "--" to use them.
-- o.bind("SUPER + CTRL + Y", "Omacale keyboard layouts", "omarchy-shell omacale popout kblayout")
-- o.bind("SUPER + CTRL + U", "Omacale pending update", "omarchy-shell omacale popout update")

-- ── Frame ───────────────────────────────────────────────────────────────────
-- SUPER + SHIFT + SPACE ("Toggle top bar") already hides/shows Omacale's
-- frame too; Omacale follows Omarchy's bar-off toggle.

-- ── Optional: make Omacale the main launcher ────────────────────────────────
-- These replace Omarchy defaults, so they are commented out. Remove the
-- leading "--" to use them. The picker binds open the launcher's carousel, or
-- Omarchy's own menu when Settings › Keybinds › Picker says "Omarchy default".
-- o.rebind("SUPER + SPACE", "Omacale launcher", "omarchy-shell omacale launcher")           -- was: Omarchy menu
-- ...or give the same key the Omarchy menu itself, drawn by Omacale (the ":"
-- prefix the launcher opens on). Pick one of these two, not both.
-- o.rebind("SUPER + SPACE", "Omacale menu", "omarchy-shell omacale menu")                   -- was: Omarchy menu
-- o.rebind("SUPER + ESCAPE", "Omacale session menu", "omarchy-shell omacale session")      -- was: System menu
-- o.rebind("SUPER + CTRL + SPACE", "Omacale wallpaper picker", "omarchy-shell omacale wallpapers")       -- was: Background switcher
-- o.rebind("SUPER + SHIFT + CTRL + SPACE", "Omacale theme picker", "omarchy-shell omacale themes")       -- was: Theme menu
-- o.rebind("SUPER + TAB", "Omacale workspace overview", "omarchy-shell omacale overview")                -- was: Next workspace
-- Details and actions for the focused window (also the chevron in the bar's active-window popout).
-- o.bind("SUPER + ALT + I", "Omacale window info", "omarchy-shell omacale windowInfo")
