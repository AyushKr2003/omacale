-- ╭─────────────────────────────────────────────────────────────────────────╮
-- │  Omacale keybindings — paste into ~/.config/hypr/bindings.lua           │
-- │  Each action is an IPC call into the running Omarchy shell:             │
-- │  omarchy-shell omacale <launcher|dashboard|session|settings|close>      │
-- │  Keys below are unbound in a stock Omarchy install. Check yours with:   │
-- │  omarchy menu keybindings --print                                       │
-- ╰─────────────────────────────────────────────────────────────────────────╯

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
