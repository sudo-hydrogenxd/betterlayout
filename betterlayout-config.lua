-- betterlayout-config.lua : everything you're meant to tweak lives here.
-- betterlayout.lua loads this file and falls back to its own defaults for any key
-- you delete, so a partial config is fine.

return {
	-- layout used on the very first run (before ~/.cache/hypr_layout exists)
	default_layout = "master",

	-- layouts the switcher accepts / cycles through, in cycle order
	layouts = { "dwindle", "master", "scrolling" },

	-- ####################################
	-- SCROLLING: apps that always open at a fixed column width.
	-- key = window class (check with `hyprctl clients | grep class`)
	-- value = fraction of the screen (0.98 = near fullscreen, 0.5 = half)
	-- ####################################
	scroll_widths = {
		zen = 0.98,
		Spotify = 0.98,
		vesktop = 0.98,
		krita = 0.98,
		helium = 0.98,
		steam = 0.98,
		-- ["kitty"] = 0.5,
		-- ["org.telegram.desktop"] = 0.66,
	},

	-- ZOOM: width a window gets when you toggle zoom on it
	zoom_width = 0.98,
	-- width a non-whitelisted window returns to when un-zoomed
	-- (Hyprland's own scrolling.column_width default is 0.5)
	default_width = 0.5,

	-- widths that cycle_zoom() steps through, if you bind it
	zoom_cycle = { 0.5, 0.66, 0.98 },

	-- notifications on layout change
	notify = {
		enabled = true,
		timeout = 2000,
		icon = "info",
	},

	-- delay (ms) before re-sizing windows after a workspace switch.
	-- raise this if you still see render glitches when switching fast.
	debounce_ms = 50,

	-- where state files are stored (nil = ~/.cache)
	state_dir = nil,

	-- print what the script is doing via hl.notification (handy when debugging)
	debug = false,
}
