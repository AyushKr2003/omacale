-- ╭─────────────────────────────────────────────────────────────────────────╮
-- │  Omacale keybindings — paste into ~/.config/hypr/bindings.lua          │
-- │  Each action is an IPC call into the running Omarchy shell:             │
-- │    omarchy-shell omacale <launcher|dashboard|session|settings|close>   │
-- │  Keys below are unbound in a stock Omarchy install. Check yours with:   │
-- │    omarchy menu keybindings --print                                     │
-- ╰─────────────────────────────────────────────────────────────────────────╯

-- ── Drawers ─────────────────────────────────────────────────────────────────

o.bind("SUPER + A", "Omacale launcher", "omarchy-shell omacale launcher")
o.bind("SUPER + D", "Omacale dashboard", "omarchy-shell omacale dashboard")
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
-- leading "--" to use them.
-- o.rebind("SUPER + SPACE", "Omacale launcher", "omarchy-shell omacale launcher")           -- was: Omarchy menu
-- o.rebind("SUPER + ESCAPE", "Omacale session menu", "omarchy-shell omacale session")      -- was: System menu
