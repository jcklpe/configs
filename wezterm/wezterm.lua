local wezterm = require("wezterm")
local config = wezterm.config_builder()

-- Font (from Hyper: "FiraCode Nerd Font, Courier")
config.font = wezterm.font_with_fallback({
    "FiraCode Nerd Font",
    "Courier",
})
config.font_size = 19.0

-- Cursor (from Hyper: BEAM, blinking, pink)
config.default_cursor_style = "BlinkingBar"
config.cursor_blink_rate = 500
config.force_reverse_video_cursor = false

-- Scrollback (from Hyper: 60000)
config.scrollback_lines = 60000

-- Copy on select (from Hyper: copyOnSelect: true)
config.selection_word_boundary = " \t\n{}[]()\"'`,;:│"

-- Window
config.window_decorations = "RESIZE"
config.window_padding = {
    left = 30,
    right = 30,
    top = 24,
    bottom = 24,
}

-- Border (diagonal solid approximation of hyperborder gradient)
-- hyperborder: #D4F442 (yellow-green) → #02F758 (green) at 135°
-- Using 4 interpolated colors to simulate the diagonal gradient
config.window_frame = {
    border_left_width = "4px",
    border_right_width = "4px",
    border_top_height = "4px",
    border_bottom_height = "4px",
    border_top_color = "#D4F442",
    border_left_color = "#6BF56D",
    border_bottom_color = "#02F758",
    border_right_color = "#9CF86A",
}

-- Colors (from hyper-bloody theme: github.com/EliverLara/hyper-bloody)
config.colors = {
    foreground = "#AAAAAA",
    background = "#1E1F29",
    cursor_bg = "#DD2476",
    cursor_border = "#DD2476",
    cursor_fg = "#1E1F29",
    selection_bg = "rgba(221, 36, 118, 0.3)",
    ansi = {
        "#1E1F29",   -- black (background)
        "#FF512F",   -- red
        "#B2FFA9",   -- green
        "#FFFD82",   -- yellow
        "#3185FC",   -- blue
        "#DD2476",   -- magenta
        "#66D7D1",   -- cyan
        "#F2EFEA",   -- white
    },
    brights = {
        "#555753",   -- bright black
        "#FF512F",   -- bright red
        "#B2FFA9",   -- bright green
        "#FFFD82",   -- bright yellow
        "#3185FC",   -- bright blue
        "#DD2476",   -- bright magenta
        "#66D7D1",   -- bright cyan
        "#F2EFEA",   -- bright white
    },
    tab_bar = {
        background = "#1E1F29",
        active_tab = {
            bg_color = "#1E1F29",
            fg_color = "#AAAAAA",
            underline = "Single",
        },
        inactive_tab = {
            bg_color = "#1E1F29",
            fg_color = "#555753",
        },
        inactive_tab_hover = {
            bg_color = "#2a2b38",
            fg_color = "#AAAAAA",
        },
    },
}

return config