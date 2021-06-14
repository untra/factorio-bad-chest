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

data.raw["gui-style"]["default"]["recursive-blueprints-selected"] = {
  type = "button_style",
  parent = "recursive-blueprints-slot",
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

data.raw["gui-style"]["default"]["recursive-blueprints-scroll"] = {
  type = "scroll_pane_style",
  parent = "naked_scroll_pane",
  padding = 2,
  maximal_height = 164,
}
