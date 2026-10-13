# betterlayout

Seamless **dwindle / master / scrolling** layout switching for Hyprland's Lua config, with a scrolling layout that actually remembers what you want.

Switch layouts with a keypress, keep your chosen layout across reloads and restarts, make chosen apps open near-fullscreen in scrolling, and zoom any window to full width and back. All the settings live in one small config file.

> **Note:** this project is partially vibe-coded, specifically the comments/notes and the work of making it modular (the separate config file). Apart from that, the logic and the code are mine.

---

## Features

- **One-key layout switching** between `dwindle`, `master` and `scrolling`, with a notification, plus an optional "cycle to next layout" function.
- **Your layout sticks.** The chosen layout is saved to disk and re-applied on every config load, so it survives `hyprctl reload` (wallpaper scripts and plugin updates tend to trigger one) and full restarts, instead of snapping back to a hardcoded default.
- **Zoom toggle** in scrolling: maximize the focused window to 0.98 width, or send it back to its normal width. Zoom is remembered **per app class**, so it persists across reloads and restarts.
- **Persistent widths for whitelisted apps.** List the apps you want near-fullscreen (browser, Spotify, Discord, Krita, Steam, ...) and each one gets its own width. New windows are sized from the start, and windows that were already open are fixed up when you land on their workspace.
- **Debounced resizing.** Rapid workspace switching can cause render glitches when several resize passes overlap; only the newest one runs, so switching fast is safe.
- **Scrolling-aware focus.** `focus_dir` scrolls columns in the scrolling layout and uses normal directional focus in the others, so the same keys work everywhere.
- **Extras:** `cycle_zoom` (step a window through several widths) and `clear_zoom` (reset every zoomed app).
- **Everything is configurable** from `betterlayout-config.lua`. Delete any key and a sensible default is used.

---

## Requirements

- A Hyprland build that supports the **Lua config API** (`hl.*`) and the **scrolling layout** (including the `scrolling_width` window rule).
- Write access to `~/.cache` (or whichever `state_dir` you set).

---

## Install

1. Copy the files into your Hyprland config folder:

   ```sh
   git clone https://github.com/sudo-hydrogenxd/betterlayout.git
   cp betterlayout/betterlayout.lua betterlayout/betterlayout-config.lua ~/.config/hypr/
   ```

   Both files must sit **in the same folder**; the script finds its config by its own path.

2. Load it from your Hyprland Lua config **before your binds**:

   ```lua
   require("betterlayout")
   ```

3. Add binds (see below), then reload:

   ```sh
   hyprctl reload
   ```

> If you were using another layout script that also registers a `workspace.active` handler, remove it. Two handlers resize everything twice and bring the glitches back.

---

## Binds

`example_binds.lua` has a complete, copy-pasteable set. The short version:

```lua
local mainMod = "SUPER"
local layout = require("betterlayout")

hl.bind(mainMod .. " + F1", function() layout.set_layout("dwindle", "Dwindle") end)
hl.bind(mainMod .. " + F2", function() layout.set_layout("master", "Master") end)
hl.bind(mainMod .. " + F3", function() layout.set_layout("scrolling", "Scrolling") end)
hl.bind(mainMod .. " + F4", layout.cycle_layout)

hl.bind(mainMod .. " + X", layout.toggle_zoom)
hl.bind(mainMod .. " + SHIFT + X", layout.cycle_zoom)
hl.bind(mainMod .. " + CTRL + X", layout.clear_zoom)

hl.bind(mainMod .. " + Left", layout.focus_dir("l"))
hl.bind(mainMod .. " + Right", layout.focus_dir("r"))
```

### Functions

| Function | What it does |
| --- | --- |
| `set_layout(name, label?)` | Switch to a layout, save it, notify. `label` is optional. |
| `cycle_layout()` | Jump to the next layout in the `layouts` list. |
| `toggle_zoom()` | Toggle the focused window's app between zoomed and normal width (scrolling only). Persisted. |
| `cycle_zoom()` | Step the focused window through the `zoom_cycle` widths (scrolling only, not persisted). |
| `clear_zoom()` | Forget every zoomed app and re-apply normal widths. |
| `focus_dir("l" \| "r")` | Returns a function for binds: scrolls columns in scrolling, normal focus elsewhere. |

---

## Configuration

Edit `betterlayout-config.lua`. Every key is optional.

| Key | Default | Meaning |
| --- | --- | --- |
| `default_layout` | `"master"` | Layout used on the very first run, before any saved choice exists. |
| `layouts` | `{ "dwindle", "master", "scrolling" }` | Layouts the switcher accepts and `cycle_layout` steps through. |
| `scroll_widths` | a few apps at `0.98` | Window class → column width. These apps always open and stay at that width in scrolling. |
| `zoom_width` | `0.98` | Width a window gets when zoomed. |
| `default_width` | `0.5` | Width a non-whitelisted window returns to when un-zoomed. |
| `zoom_cycle` | `{ 0.5, 0.66, 0.98 }` | Widths `cycle_zoom` steps through. |
| `notify` | enabled, 2000 ms | `enabled`, `timeout` and `icon` for the layout notification. |
| `debounce_ms` | `50` | Delay before resizing after a workspace switch. Raise it if fast switching still glitches. |
| `state_dir` | `~/.cache` | Where state files are stored. |
| `debug` | `false` | Show notifications describing what the script is doing. |

Find an app's class with:

```sh
hyprctl clients | grep class
```

Example whitelist:

```lua
scroll_widths = {
	zen = 0.98,
	Spotify = 0.98,
	kitty = 0.5,
	["org.telegram.desktop"] = 0.66,
},
```

---

## How it works

- **Persistence:** your layout is written to `~/.cache/hypr_betterlayout` and zoomed classes to `~/.cache/hypr_betterlayout_zoom`. On every config load the saved layout is read back and applied.
- **New windows:** each class in `scroll_widths` becomes a window rule using `scrolling_width`, so new windows open at the right size.
- **Existing windows:** `scrolling_width` only fires on creation, so when you land on a workspace in scrolling, windows already there are resized with `colresize` and focus is restored.
- **Debounce:** every workspace change increments a generation counter, and a delayed resize only runs if it is still the newest. Stale runs are dropped.

---

## Notes and limits

- Zoom and column widths only apply in the **scrolling** layout.
- A whitelisted app returns to its whitelist width when un-zoomed, not to `default_width`, so zooming one of those apps has no visible effect.
- Zoom is stored **per class**, so every window of the same app shares it.

---

## Troubleshooting

- **Layout resets after reload:** make sure `betterlayout` is required in your config and `~/.cache` is writable.
- **Config is ignored:** `betterlayout-config.lua` must be in the same folder as `betterlayout.lua`. Set `debug = true` to see what loads.
- **Glitches when switching workspaces quickly:** raise `debounce_ms` (try `80` to `120`) and make sure no other script resizes windows on `workspace.active`.
- **An app isn't resized:** check its class with `hyprctl clients` and make sure it matches the key in `scroll_widths` exactly (it is case-sensitive).

---

## Files

| File | Purpose |
| --- | --- |
| `betterlayout.lua` | The module. |
| `betterlayout-config.lua` | Your settings. |
| `example_binds.lua` | Copy-pasteable binds. |

---

## License

Released under the [MIT License](LICENSE).
