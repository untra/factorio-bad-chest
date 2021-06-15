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

data.raw["gui-style"]["default"]["recursive-blueprints-flow-debug"] = {
  type = "horizontal_flow_style",
  margin = 0,
  padding = 0,
  vertical_spacing = 0,
  horizontally_stretchable = "off",
}

data.raw["gui-style"]["default"]["recursive-blueprints-filter"] = {
  type = "button_style",
  parent = "slot_button",
}

data.raw["gui-style"]["default"]["recursive-blueprints-scroll"] = {
  type = "scroll_pane_style",
  parent = "naked_scroll_pane",
  padding = 2,
  maximal_height = 164,
}

data.raw["gui-style"]["default"]["recursive-blueprints-invisible-tab"] = {
  type = "tab_style",
  height = 0,
}

data.raw["gui-style"]["default"]["recursive-blueprints-group-bg"] = {
  type = "empty_widget_style",
  width = 64,
  height = 64,
}

data.raw["gui-style"]["default"]["recursive-blueprints-slot-bg"] = {
  type = "empty_widget_style",
  width = 40,
  height = 40,
}

data.raw["gui-style"]["default"]["recursive-blueprints-group"] = {
  type = "button_style",
  height = 64,
  width = 64,
  padding = 4,
  default_graphical_set =
  {
    base =
    {
      -- basically button without bottom side
      left_top = {position = {0, 17}, size = {8, 8}},
      left = {position = {0, 25}, size = {8, 1}},
      left_bottom = {position = {0, 25}, size = {8, 1}},
      top = {position = {8, 17}, size = {1, 8}},
      center = {position = {8, 25}, size = {1, 1}},
      bottom = {position = {8, 25}, size = {1, 1}},
      right_top = {position = {9, 17}, size = {8, 8}},
      right = {position = {9, 25}, size = {8, 1}},
      right_bottom = {position = {9, 25}, size = {8, 1}}
    },
    shadow = default_glow(default_shadow_color, 0.5)
  },
  selected_graphical_set =
  {
    base =
    {
      left_top = {position = {68, 0}, size = {8, 8}},
      left = {position = {68, 8}, size = {8, 1}},
      left_bottom = {position = {136, 9}, size = {8, 8}},
      top = {position = {76, 0}, size = {1, 8}},
      center = {position = {76, 8}, size = {1, 1}},
      bottom = {position = {144, 9}, size = {1, 8}},
      right_top = {position = {77, 0}, size = {8, 8}},
      right = {position = {77, 8}, size = {8, 1}},
      right_bottom = {position = {145, 9}, size = {8, 8}}
    },
    shadow = default_glow(default_shadow_color, 0.5)
  },
  hover_graphical_set =
  {
    base =
    {
      left_top = {position = {34, 17}, size = {8, 8}},
      left = {position = {34, 25}, size = {8, 1}},
      left_bottom = {position = {34, 25}, size = {8, 1}},
      top = {position = {42, 17}, size = {1, 8}},
      center = {position = {42, 25}, size = {1, 1}},
      bottom = {position = {42, 25}, size = {1, 1}},
      right_top = {position = {43, 17}, size = {8, 8}},
      right = {position = {43, 25}, size = {8, 1}},
      right_bottom = {position = {43, 25}, size = {8, 1}}
    },
    glow = default_glow(default_glow_color, 0.5)
  },
  press_graphical_set =
  {
    base = {position = {51, 17}, corner_size = 8},
    shadow = default_glow(default_glow_color, 0.5)
  },
  disabled_graphical_set =
  {
    base = {position = {208, 17}, corner_size = 8},
    shadow = default_glow(default_shadow_color, 0.5)
  },
  override_graphics_on_edges = true,
  left_edge_selected_graphical_set =
  {
    base =
    {
      left_top = {position = {68, 0}, size = {8, 8}},
      left = {position = {68, 8}, size = {8, 1}},
      left_bottom = {position = {68, 4}, size = {8, 8}}, -- cutout from size of no.5 tile, need 8x8 for image set to work right.
      top = {position = {76, 0}, size = {1, 8}},
      center = {position = {76, 8}, size = {1, 1}},
      bottom = {position = {144, 9}, size = {1, 8}},
      right_top = {position = {77, 0}, size = {8, 8}},
      right = {position = {77, 8}, size = {8, 1}},
      right_bottom = {position = {145, 9}, size = {8, 8}}
    },
    shadow = default_glow(default_shadow_color, 0.5)
  },
  right_edge_selected_graphical_set =
  {
    base =
    {
      left_top = {position = {68, 0}, size = {8, 8}},
      left = {position = {68, 8}, size = {8, 1}},
      left_bottom = {position = {136, 9}, size = {8, 8}},
      top = {position = {76, 0}, size = {1, 8}},
      center = {position = {76, 8}, size = {1, 1}},
      bottom = {position = {144, 9}, size = {1, 8}},
      right_top = {position = {77, 0}, size = {8, 8}},
      right = {position = {77, 8}, size = {8, 1}},
      right_bottom = {position = {77, 8}, size = {8, 1}}
    },
    shadow = default_glow(default_shadow_color, 0.5)
  },
  left_click_sound = {{ filename = "__core__/sound/gui-square-button-large.ogg", volume = 1 }}
}
