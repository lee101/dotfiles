local wezterm = require("wezterm")
local act = wezterm.action

local config = wezterm.config_builder()

local is_windows = wezterm.target_triple:find("windows") ~= nil
local git_bash = "C:/Program Files/Git/bin/bash.exe"
local linux_bash = "/usr/bin/bash"

if is_windows then
  config.default_prog = { git_bash, "--login", "-i" }
else
  config.default_prog = { linux_bash, "--login", "-i" }
end
config.default_cwd = wezterm.home_dir

config.color_scheme = "Dotfiles Darkula 20-80"
config.color_schemes = {
  ["Dotfiles Darkula 20-80"] = {
    foreground = "#d6dbe3",
    background = "#20242c",
    cursor_bg = "#80cbc4",
    cursor_fg = "#20242c",
    cursor_border = "#80cbc4",
    selection_fg = "#20242c",
    selection_bg = "#596170",
    scrollbar_thumb = "#596170",
    split = "#596170",
    ansi = {
      "#20242c",
      "#f07178",
      "#c3e88d",
      "#ffcb6b",
      "#82aaff",
      "#c792ea",
      "#89ddff",
      "#d6dbe3",
    },
    brights = {
      "#596170",
      "#ff8b92",
      "#dbf9a7",
      "#ffd98f",
      "#9cc4ff",
      "#d7aefb",
      "#a7eeff",
      "#ffffff",
    },
  },
}

config.font = wezterm.font_with_fallback({
  "CaskaydiaCove NF",
  "JetBrainsMono Nerd Font",
  "Consolas",
})
config.font_size = 10.5
config.line_height = 1.0
config.window_padding = { left = 6, right = 6, top = 4, bottom = 4 }
config.window_background_opacity = 1.0
config.inactive_pane_hsb = { saturation = 0.85, brightness = 0.80 }
config.window_close_confirmation = "NeverPrompt"
config.audible_bell = "Disabled"
config.scrollback_lines = 100000
config.hide_tab_bar_if_only_one_tab = false
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = false
config.check_for_updates = false

config.keys = {
  { key = "t", mods = "CTRL", action = act.SpawnTab("CurrentPaneDomain") },
  { key = "w", mods = "CTRL", action = act.CloseCurrentTab({ confirm = false }) },
  { key = "d", mods = "ALT|SHIFT", action = act.SplitPane({ direction = "Right", size = { Percent = 50 } }) },
  { key = "-", mods = "CTRL|SHIFT", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
  { key = "\\", mods = "CTRL|SHIFT", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
  { key = "LeftArrow", mods = "ALT", action = act.ActivatePaneDirection("Left") },
  { key = "RightArrow", mods = "ALT", action = act.ActivatePaneDirection("Right") },
  { key = "UpArrow", mods = "ALT", action = act.ActivatePaneDirection("Up") },
  { key = "DownArrow", mods = "ALT", action = act.ActivatePaneDirection("Down") },
  { key = "f", mods = "CTRL|SHIFT", action = act.Search("CurrentSelectionOrEmptyString") },
  { key = "F11", mods = "NONE", action = act.ToggleFullScreen },
}

return config
