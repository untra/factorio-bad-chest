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

data.raw["gui-style"]["default"]["recursive-blueprints-set-button"] = {
  type = "button_style",
  parent = "green_button",
  tooltip = "",
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

local graphical_set = table.deepcopy(data.raw["gui-style"]["default"]["filter_group_table"].background_graphical_set)
graphical_set.overall_tiling_vertical_spacing = 18
graphical_set.overall_tiling_vertical_padding = 9
graphical_set.overall_tiling_horizontal_spacing = 23
graphical_set.overall_tiling_horizontal_padding = 11
data.raw["gui-style"]["default"]["recursive-blueprints-scroll-frame2"] = {
  type = "frame_style",
  parent = "filter_scroll_pane_background_frame",
  width = 420,
  minimal_height = 64,
  graphical_set = {
    base = {
      center = table.deepcopy(data.raw["gui-style"]["default"]["slot_container_frame"].graphical_set.base.center)
    },
  },
  background_graphical_set = graphical_set,
  vertical_flow_style = {
    type = "vertical_flow_style",
    vertical_spacing = 0,
  }
}

data.raw["gui-style"]["default"]["recursive-blueprints-tabbed-pane"] = {
  type = "tabbed_pane_style",
  tab_content_frame = {
    type = "frame_style",
    top_padding = 8,
    bottom_padding = 6,
    left_padding = 10,
    right_padding = 10,
    top_margin = 2,
    graphical_set = {
      base = {
        center = table.deepcopy(data.raw["gui-style"]["default"]["filter_tabbed_pane"].tab_content_frame.graphical_set.base.center)
      },
    },
  },
}

-- Real tab button
data.raw["gui-style"]["default"]["recursive-blueprints-invisible-tab"] = {
  type = "tab_style",
  width = 0,
  padding = 0,
  font = "recursive-blueprints-invisible-font",
}

-- Fake tab buttons
local tab_button = {
  type = "button_style",
  width = 71,
  height = 64,
  padding = 0,
  font = "default-game",
  default_font_color = {255, 255, 255},
  hovered_font_color = {255, 255, 255},
  clicked_font_color = {255, 255, 255},
  default_graphical_set = table.deepcopy(data.raw["gui-style"]["default"]["tab"].default_graphical_set),
  hovered_graphical_set = table.deepcopy(data.raw["gui-style"]["default"]["tab"].hover_graphical_set),
  clicked_graphical_set = table.deepcopy(data.raw["gui-style"]["default"]["tab"].pressed_graphical_set),
  left_click_sound = table.deepcopy(data.raw["gui-style"]["default"]["filter_group_tab"].left_click_sound),
}
data.raw["gui-style"]["default"]["recursive-blueprints-tab-button"] = tab_button

local tab_button_selected = table.deepcopy(tab_button)
tab_button_selected.default_graphical_set = table.deepcopy(data.raw["gui-style"]["default"]["filter_group_tab"].selected_graphical_set)
tab_button_selected.hovered_graphical_set = tab_button_selected.default_graphical_set
tab_button_selected.clicked_graphical_set = tab_button_selected.default_graphical_set
data.raw["gui-style"]["default"]["recursive-blueprints-tab-button-selected"] = tab_button_selected

local tab_button_left = table.deepcopy(tab_button)
tab_button_left.default_graphical_set = table.deepcopy(data.raw["gui-style"]["default"]["filter_group_tab"].left_edge_selected_graphical_set)
tab_button_left.hovered_graphical_set = tab_button_left.default_graphical_set
tab_button_left.clicked_graphical_set = tab_button_left.default_graphical_set
data.raw["gui-style"]["default"]["recursive-blueprints-tab-button-left"] = tab_button_left

local tab_button_right = table.deepcopy(tab_button)
tab_button_right.default_graphical_set = table.deepcopy(data.raw["gui-style"]["default"]["filter_group_tab"].right_edge_selected_graphical_set)
tab_button_right.hovered_graphical_set = tab_button_right.default_graphical_set
tab_button_right.clicked_graphical_set = tab_button_right.default_graphical_set
data.raw["gui-style"]["default"]["recursive-blueprints-tab-button-right"] = tab_button_right
