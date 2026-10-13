-- betterlayout.lua : seamless dwindle / master / scrolling switching for Hyprland.
-- Settings live in betterlayout-config.lua (same folder). Binds are exposed at the bottom.

-- ####################################
-- CONFIG (betterlayout-config.lua next to this file, merged over safe defaults)
-- ####################################

local defaults = {
	default_layout = "master",
	layouts = { "dwindle", "master", "scrolling" },
	scroll_widths = {},
	zoom_width = 0.98,
	default_width = 0.5,
	zoom_cycle = { 0.5, 0.66, 0.98 },
	notify = { enabled = true, timeout = 2000, icon = "info" },
	debounce_ms = 50,
	state_dir = nil,
	debug = false,
}

local function load_config()
	local cfg = {}
	for k, v in pairs(defaults) do
		cfg[k] = v
	end

	local src = debug.getinfo(1, "S").source
	local dir = src:match("^@(.*/)") or ""
	local ok, user = pcall(dofile, dir .. "betterlayout-config.lua")
	if not ok then
		ok, user = pcall(require, "betterlayout-config")
	end

	if ok and type(user) == "table" then
		for k, v in pairs(user) do
			if type(v) == "table" and type(defaults[k]) == "table" and not v[1] and next(v) ~= nil then
				-- keyed sub-tables (notify, scroll_widths) merge key by key
				local merged = {}
				for dk, dv in pairs(defaults[k]) do
					merged[dk] = dv
				end
				for uk, uv in pairs(v) do
					merged[uk] = uv
				end
				cfg[k] = merged
			else
				cfg[k] = v
			end
		end
	end
	return cfg
end

local cfg = load_config()

local function log(msg)
	if cfg.debug then
		hl.notification.create({ text = "[layout] " .. msg, timeout = 1500, icon = "info" })
	end
end

-- ####################################
-- PERSISTED LAYOUT (survives hyprctl reload and full restarts)
-- ####################################

local state_dir = cfg.state_dir or (os.getenv("HOME") .. "/.cache")
local state_file = state_dir .. "/hypr_betterlayout"
local zoom_file = state_dir .. "/hypr_betterlayout_zoom"

local function is_valid_layout(l)
	for _, name in ipairs(cfg.layouts) do
		if name == l then
			return true
		end
	end
	return false
end

local function read_layout()
	local f = io.open(state_file, "r")
	if f then
		local l = f:read("*l")
		f:close()
		if l and is_valid_layout(l) then
			return l
		end
	end
	return cfg.default_layout
end

local function write_layout(l)
	local f = io.open(state_file, "w")
	if f then
		f:write(l)
		f:close()
	end
end

local current_layout = read_layout()
hl.config({ general = { layout = current_layout } })

-- ####################################
-- ZOOM STATE (persisted by window class)
-- ####################################

local function read_zoomed()
	local zoomed = {}
	local f = io.open(zoom_file, "r")
	if f then
		for line in f:lines() do
			if line ~= "" then
				zoomed[line] = true
			end
		end
		f:close()
	end
	return zoomed
end

local function write_zoomed(zoomed)
	local f = io.open(zoom_file, "w")
	if f then
		for class, _ in pairs(zoomed) do
			f:write(class .. "\n")
		end
		f:close()
	end
end

-- what a window's column width SHOULD be right now, or nil if untracked
local function effective_width(class, zoomed)
	if zoomed[class] then
		return cfg.zoom_width
	elseif cfg.scroll_widths[class] then
		return cfg.scroll_widths[class]
	end
	return nil
end

-- ####################################
-- NEW WINDOWS: declarative rules, sized correctly on creation
-- ####################################

for class, width in pairs(cfg.scroll_widths) do
	hl.window_rule({
		name = "scroll-width-" .. class,
		match = { class = class },
		scrolling_width = width,
	})
end

-- ####################################
-- EXISTING WINDOWS: resize when you land on their workspace
-- (scrolling_width only fires on creation, not retroactively)
-- ####################################

local function fix_scroll_widths(ws)
	if not ws or ws.tiled_layout ~= "scrolling" then
		return
	end

	local original = hl.get_active_window()
	local wins = hl.get_workspace_windows(ws)
	local zoomed = read_zoomed()

	for _, w in ipairs(wins) do
		local width = effective_width(w.class, zoomed)
		if width then
			hl.dispatch(hl.dsp.focus({ window = w }))
			hl.dispatch(hl.dsp.layout("colresize " .. width))
		end
	end

	if original then
		hl.dispatch(hl.dsp.focus({ window = original }))
	end
	log("resized windows on workspace")
end

-- debounce: rapid switches queue several timers; only the newest one runs,
-- so stale runs never dispatch focus/colresize against the wrong workspace.
local fix_generation = 0

local function schedule_fix(ws)
	fix_generation = fix_generation + 1
	local my_gen = fix_generation
	hl.timer(function()
		if my_gen == fix_generation then
			fix_scroll_widths(ws)
		end
	end, { timeout = cfg.debounce_ms, type = "oneshot" })
end

hl.on("workspace.active", schedule_fix)

-- ####################################
-- ZOOM ACTIONS
-- ####################################

local function active_scrolling_window()
	local ws = hl.get_active_workspace()
	if not ws or ws.tiled_layout ~= "scrolling" then
		return nil
	end
	return hl.get_active_window()
end

-- toggle zoom on the focused window's class
local function toggle_zoom()
	local w = active_scrolling_window()
	if not w then
		return
	end

	local zoomed = read_zoomed()
	local class = w.class
	zoomed[class] = (not zoomed[class]) or nil
	write_zoomed(zoomed)

	local width = zoomed[class] and cfg.zoom_width or (cfg.scroll_widths[class] or cfg.default_width)
	hl.dispatch(hl.dsp.layout("colresize " .. width))
end

-- step the focused window through cfg.zoom_cycle (not persisted)
local cycle_index = {}
local function cycle_zoom()
	local w = active_scrolling_window()
	if not w then
		return
	end
	local i = ((cycle_index[w.class] or 0) % #cfg.zoom_cycle) + 1
	cycle_index[w.class] = i
	hl.dispatch(hl.dsp.layout("colresize " .. cfg.zoom_cycle[i]))
end

-- forget every zoomed class and re-apply default widths
local function clear_zoom()
	write_zoomed({})
	schedule_fix(hl.get_active_workspace())
	if cfg.notify.enabled then
		hl.notification.create({ text = "Zoom cleared", timeout = cfg.notify.timeout, icon = cfg.notify.icon })
	end
end

-- ####################################
-- LAYOUT SWITCHING
-- ####################################

local function set_layout(layout, label)
	if not is_valid_layout(layout) then
		log("unknown layout: " .. tostring(layout))
		return
	end

	current_layout = layout
	hl.config({ general = { layout = layout } })
	write_layout(layout)

	if cfg.notify.enabled then
		local text = label or (layout:sub(1, 1):upper() .. layout:sub(2))
		hl.notification.create({
			text = "Layout: " .. text,
			timeout = cfg.notify.timeout,
			icon = cfg.notify.icon,
		})
	end

	if layout == "scrolling" then
		schedule_fix(hl.get_active_workspace())
	end
end

-- jump to the next layout in cfg.layouts
local function cycle_layout()
	for i, name in ipairs(cfg.layouts) do
		if name == current_layout then
			set_layout(cfg.layouts[(i % #cfg.layouts) + 1])
			return
		end
	end
	set_layout(cfg.layouts[1])
end

-- ####################################
-- FOCUS (scrolling-aware)
-- ####################################

local function focus_dir(dir)
	return function()
		local ws = hl.get_active_workspace()
		if ws and ws.tiled_layout == "scrolling" then
			hl.dispatch(hl.dsp.layout("focus " .. dir))
		else
			hl.dispatch(hl.dsp.focus({ direction = dir == "l" and "left" or "right" }))
		end
	end
end

-- exported for binds.lua  (local layout = require("betterlayout"))
return {
	set_layout = set_layout,
	cycle_layout = cycle_layout,
	toggle_zoom = toggle_zoom,
	cycle_zoom = cycle_zoom,
	clear_zoom = clear_zoom,
	focus_dir = focus_dir,
}
