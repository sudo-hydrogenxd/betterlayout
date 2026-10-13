-- example_binds.lua : copy what you need into your own binds.lua
-- (or `require` this file from it). Assumes betterlayout.lua and
-- betterlayout-config.lua sit in ~/.config/hypr/.

local mainMod = "SUPER"
local layout = require("betterlayout")

-- ── Pick a layout directly ─────────────────────────────────────
-- (the second argument is just the label shown in the notification;
--  you can leave it out and it will be capitalised automatically)

hl.bind(mainMod .. " + F1", function()
	layout.set_layout("dwindle", "Dwindle")
end)

hl.bind(mainMod .. " + F2", function()
	layout.set_layout("master", "Master")
end)

hl.bind(mainMod .. " + F3", function()
	layout.set_layout("scrolling", "Scrolling")
end)

-- or one key that steps through the list in betterlayout-config.lua
hl.bind(mainMod .. " + F4", layout.cycle_layout)

-- ── Zoom (scrolling layout only) ───────────────────────────────

-- toggle the focused window between zoomed (0.98) and its normal width.
-- Remembered per app class, so it survives reloads and restarts.
hl.bind(mainMod .. " + X", layout.toggle_zoom)

-- step the focused window through zoom_cycle widths (0.5 -> 0.66 -> 0.98)
hl.bind(mainMod .. " + SHIFT + X", layout.cycle_zoom)

-- un-zoom every app at once
hl.bind(mainMod .. " + CTRL + X", layout.clear_zoom)

-- ── Focus (scrolling-aware: scrolls columns instead of jumping) ─

hl.bind(mainMod .. " + Left", layout.focus_dir("l"))
hl.bind(mainMod .. " + Right", layout.focus_dir("r"))

-- mouse wheel version
hl.bind(mainMod .. " + SHIFT + mouse_down", layout.focus_dir("r"))
hl.bind(mainMod .. " + SHIFT + mouse_up", layout.focus_dir("l"))
