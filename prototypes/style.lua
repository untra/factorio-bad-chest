data.raw["gui-style"]["default"]["recursive-blueprints-slot"] = {
  type = "button_style",
  parent = "slot_button_in_shallow_frame",
  font = "default-game",
  default_font_color = {1, 1, 1},
  hovered_font_color = {1, 1, 1},
  clicked_font_color = {1, 1, 1},
  horizontal_align = "center",
  minimal_width = 40,
  natural_width = 40,
  maximal_width = 80,
  draw_shadow_under_picture = false,
}

data.raw["gui-style"]["default"]["recursive-blueprints-slot-selected"] = {
  type = "button_style",
  parent = "recursive-blueprints-slot",
  default_graphical_set = table.deepcopy(data.raw["gui-style"]["default"]["slot_button"].selected_graphical_set),
  clicked_graphical_set = table.deepcopy(data.raw["gui-style"]["default"]["slot_button"].selected_graphical_set),
}

data.raw["gui-style"]["default"]["recursive-blueprints-filter-selected"] = {
  type = "button_style",
  parent = "recursive-blueprints-filter",
  default_graphical_set = table.deepcopy(data.raw["gui-style"]["default"]["slot_button"].selected_graphical_set),
  clicked_graphical_set = table.deepcopy(data.raw["gui-style"]["default"]["slot_button"].selected_graphical_set),
}

data.raw["gui-style"]["default"]["recursive-blueprints-output"] = {
  type = "button_style",
  parent = "slot_button",
  clicked_graphical_set = table.deepcopy(data.raw["gui-style"]["default"]["slot_button"].selected_graphical_set),
  hovered_graphical_set = table.deepcopy(data.raw["gui-style"]["default"]["slot_button"].selected_graphical_set),
  draw_shadow_under_picture = false,
}

data.raw["gui-style"]["default"]["recursive-blueprints-filter"] = {
  type = "button_style",
  parent = "slot_button",
}

data.raw["gui-style"]["default"]["recursive-blueprints-scroll"] = {
  type = "scroll_pane_style",
  parent = "naked_scroll_pane",
  padding = 2,
  minimal_height = 44,
}

data.raw["gui-style"]["default"]["recursive-blueprints-scroll-frame"] = {
  type = "frame_style",
  parent = "filter_scroll_pane_background_frame",
  width = 400,
  minimal_height = 40,
}

data.raw["gui-style"]["default"]["recursive-blueprints-gui"] = {
  type = "frame_style",
  vertical_flow_style = {
    type = "vertical_flow_style",
    vertical_spacing = 0,
  }
}

-- #1 Container for fake tab buttons
data.raw["gui-style"]["default"]["recursive-blueprints-group-flow"] = {
  type = "horizontal_flow_style",
  parent = "packed_horizontal_flow",
  top_padding = 0,
  bottom_padding = 0,
  left_padding = 1,
  right_padding = 1,
}

-- inside_shallow_frame without top
data.raw["gui-style"]["default"]["recursive-blueprints-tabbed-pane"] = {
  type = "tabbed_pane_style",
  tab_content_frame = {
    type = "frame_style",
    padding = 12,
    graphical_set = {
      base = {
        right = {position = {26, 8}, size = {8, 1}},
        left = {position = {17, 8}, size = {8, 1}},
        left_bottom = {position = {17, 9}, size = {8, 8}},
        bottom = {position = {25, 9}, size = {1, 8}},
        right_bottom = {position = {26, 9}, size = {8, 8}},
        center = {position = {76, 8}, size = {1, 1}},
        scale = 0.5,
        draw_type = "outer",
      },
      shadow = {
        right = {position = {192, 136}, size = {8, 1}},
        left = {position = {183, 136}, size = {8, 1}},
        left_bottom = {position = {183, 137}, size = {8, 8}},
        bottom = {position = {191, 137}, size = {1, 8}},
        right_bottom = {position = {192, 137}, size = {8, 8}},
        center = {position = {191, 136}, size = {1, 1}},
        tint = {0, 0, 0, 1},
        scale = 0.5,
        draw_type = "inner",
      },
    }
  }
}

data.raw["gui-style"]["default"]["recursive-blueprints-invisible-tab"] = {
  type = "tab_style",
  width = 0,
  padding = 0,
  font = "recursive-blueprints-invisible-font",
}

data.raw["gui-style"]["default"]["recursive-blueprints-group-bg"] = {
  type = "empty_widget_style",
  width = 64,
  height = 64,
}

-- #2 Tab buttons
data.raw["gui-style"]["default"]["recursive-blueprints-tab-button"] = {
  type = "button_style",
  minimal_width = 64,
  height = 64,
  padding = 4,
  horizontally_stretchable = "on",
  default_graphical_set = table.deepcopy(data.raw["gui-style"]["default"]["tab"].default_graphical_set),
  hovered_graphical_set = table.deepcopy(data.raw["gui-style"]["default"]["tab"].hover_graphical_set),
  clicked_graphical_set = table.deepcopy(data.raw["gui-style"]["default"]["tab"].pressed_graphical_set),
  left_click_sound = table.deepcopy(data.raw["gui-style"]["default"]["filter_group_tab"].left_click_sound),
}

-- #2 Selected tab button
local tab_button_selected = table.deepcopy(data.raw["gui-style"]["default"]["recursive-blueprints-tab-button"])
tab_button_selected.default_graphical_set = {
  base = {position = {136, 0}, corner_size = 8},
  shadow = tab_glow(default_shadow_color, 0.5),
}
tab_button_selected.hovered_graphical_set = tab_button_selected.default_graphical_set
tab_button_selected.clicked_graphical_set = tab_button_selected.default_graphical_set
data.raw["gui-style"]["default"]["recursive-blueprints-tab-button-selected"] = tab_button_selected

local tab_button_left = table.deepcopy(tab_button_selected)
tab_button_left.default_graphical_set = table.deepcopy(data.raw["gui-style"]["default"]["filter_group_tab"].left_edge_selected_graphical_set)
tab_button_left.hovered_graphical_set = tab_button_left.default_graphical_set
tab_button_left.clicked_graphical_set = tab_button_left.default_graphical_set
data.raw["gui-style"]["default"]["recursive-blueprints-tab-button-left"] = tab_button_left

local tab_button_right = table.deepcopy(tab_button_selected)
tab_button_right.default_graphical_set = table.deepcopy(data.raw["gui-style"]["default"]["filter_group_tab"].right_edge_selected_graphical_set)
tab_button_right.hovered_graphical_set = tab_button_right.default_graphical_set
tab_button_right.clicked_graphical_set = tab_button_right.default_graphical_set
data.raw["gui-style"]["default"]["recursive-blueprints-tab-button-right"] = tab_button_right
