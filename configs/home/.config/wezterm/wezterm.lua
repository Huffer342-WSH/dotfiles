local wezterm = require 'wezterm'
local act = wezterm.action

local config = wezterm.config_builder()

-- Appearance
config.window_background_opacity = 0.95
config.font = wezterm.font_with_fallback {
  'Cascadia Mono NF',
  'Sarasa Mono SC',
}
config.font_size = 11


-- Window
config.window_decorations = 'INTEGRATED_BUTTONS|RESIZE'
config.use_fancy_tab_bar = true

config.integrated_title_buttons = {
  'Hide',
  'Maximize',
  'Close',
}

config.integrated_title_button_alignment = 'Right'

config.colors = {
  tab_bar = {
    -- The color of the inactive tab bar edge/divider
    inactive_tab_edge = '#575757',
  },
}

-- Copy selected text directly to the system clipboard.
config.mouse_bindings = {
  {
    event = { Up = { streak = 1, button = 'Left' } },
    mods = 'NONE',
    action = act.CompleteSelection 'Clipboard',
  },
  {
    event = { Up = { streak = 2, button = 'Left' } },
    mods = 'NONE',
    action = act.CompleteSelection 'Clipboard',
  },
  {
    event = { Up = { streak = 3, button = 'Left' } },
    mods = 'NONE',
    action = act.CompleteSelection 'Clipboard',
  },
}

config.keys = {
  -- Split
  {
    key = '+',
    mods = 'ALT|SHIFT',
    action = act.SplitPane { direction = 'Right' },
  },
  {
    key = '-',
    mods = 'ALT|SHIFT',
    action = act.SplitPane { direction = 'Down' },
  },
  {
    key = 'Backspace',
    mods = 'ALT|SHIFT',
    action = act.CloseCurrentPane { confirm = true },
  },

  -- Pane navigation
  {
    key = 'LeftArrow',
    mods = 'ALT|SHIFT',
    action = act.ActivatePaneDirection 'Left',
  },
  {
    key = 'DownArrow',
    mods = 'ALT|SHIFT',
    action = act.ActivatePaneDirection 'Down',
  },
  {
    key = 'UpArrow',
    mods = 'ALT|SHIFT',
    action = act.ActivatePaneDirection 'Up',
  },
  {
    key = 'RightArrow',
    mods = 'ALT|SHIFT',
    action = act.ActivatePaneDirection 'Right',
  },

  -- Resize pane. WezTerm resizes in cells; one cell is roughly the 10px
  -- increment used by the Ghostty config at this font size.
  {
    key = 'j',
    mods = 'ALT|SHIFT',
    action = act.AdjustPaneSize { 'Left', 1 },
  },
  {
    key = 'k',
    mods = 'ALT|SHIFT',
    action = act.AdjustPaneSize { 'Down', 1 },
  },
  {
    key = 'i',
    mods = 'ALT|SHIFT',
    action = act.AdjustPaneSize { 'Up', 1 },
  },
  {
    key = 'l',
    mods = 'ALT|SHIFT',
    action = act.AdjustPaneSize { 'Right', 1 },
  },

  -- Zoom
  {
    key = 'Enter',
    mods = 'ALT',
    action = act.TogglePaneZoomState,
  },

  -- Pass Ctrl+Enter through to terminal applications.
  {
    key = 'Enter',
    mods = 'CTRL',
    action = act.DisableDefaultAssignment,
  },
}


return config
