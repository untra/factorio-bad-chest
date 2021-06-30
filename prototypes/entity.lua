local deployer = table.deepcopy(data.raw["container"]["steel-chest"])
deployer.name = "blueprint-deployer"
deployer.icon = "__recursive-blueprints__/graphics/blueprint-deployer-icon.png"
deployer.minable.result = "blueprint-deployer"
deployer.inventory_size = 1
deployer.enable_inventory_bar = false
deployer.picture.layers = {
  {
    filename = "__recursive-blueprints__/graphics/blueprint-deployer.png",
    priority = "extra-high",
    width = 32,
    height = 36,
    shift = util.by_pixel(0, -2),
    hr_version = {
      filename = "__recursive-blueprints__/graphics/hr-blueprint-deployer.png",
      priority = "extra-high",
      width = 66,
      height = 72,
      shift = util.by_pixel(0, -2.5),
      scale = 0.5,
    }
  },
  {
    filename = "__base__/graphics/entity/roboport/roboport-base-animation.png",
    width = 42,
    height = 31,
    hr_version = {
        filename = "__base__/graphics/entity/roboport/hr-roboport-base-animation.png",
        width = 83,
        height = 59,
        priority = "medium",
        scale = 0.5,
        shift = util.by_pixel(0.25, -17),
    },
    priority = "medium",
    shift = util.by_pixel(0, -17.5),
  },
  {
    filename = "__base__/graphics/entity/logistic-chest/logistic-chest-shadow.png",
    priority = "extra-high",
    width = 48,
    height = 24,
    shift = util.by_pixel(8.5, 5.5),
    draw_as_shadow = true,
    hr_version =
    {
      filename = "__base__/graphics/entity/logistic-chest/hr-logistic-chest-shadow.png",
      priority = "extra-high",
      width = 96,
      height = 44,
      repeat_count = 7,
      shift = util.by_pixel(8.5, 5),
      draw_as_shadow = true,
      scale = 0.5
    }
  }
}
data:extend{deployer}

local substation = table.deepcopy(data.raw["electric-pole"]["substation"])
local connection_point = {
  wire = {green = {0.9375, 0.875}, red = {0.875, 0.640625}},
  shadow = {green = {1.078125, 1.171875}, red = {1.296875, 1.125}},
}
data:extend{
  {
    type = "constant-combinator",
    name = "recursive-blueprints-scanner",
    allow_copy_paste = false,
    activity_led_light_offsets = {{0,0}, {0,0}, {0,0}, {0,0}},
    activity_led_sprites = {filename = "__core__/graphics/empty.png", size = 1},
    circuit_wire_connection_points = {
      connection_point,
      connection_point,
      connection_point,
      connection_point,
    },
    circuit_wire_max_distance = 9,
    close_sound = substation.close_sound,
    collision_box = {{-0.7, -0.7}, {0.7, 0.7}},
    corpse = "substation-remnants",
    damaged_trigger_effect = substation.damaged_trigger_effect,
    drawing_box = {{-1, -2.5}, {1, 1}},
    dying_explosion = "substation-explosion",
    flags = {
      "placeable-neutral",
      "player-creation",
      "hide-alt-info",
      "not-rotatable",
    },
    icon = "__recursive-blueprints__/graphics/blueprint-deployer-icon.png",
    icon_mipmaps = 4,
    icon_size = 64,
    item_slot_count = 10,
    max_health = 200,
    minable = {mining_time = 0.1, result = "recursive-blueprints-scanner"},
    open_sound = substation.open_sound,
    selection_box = {{-1, -1}, {1, 1}},
    sprites = {
      layers = {
        {
          filename = "__recursive-blueprints__/graphics/scanner.png",
          width = 70,
          height = 136,
          hr_version = {
            filename = "__recursive-blueprints__/graphics/hr-scanner.png",
            width = 138,
            height = 270,
            priority = "high",
            scale = 0.5,
            shift = {0, -0.96875},
          },
          priority = "high",
          shift = {0, -0.96875},
        },
        {
          draw_as_shadow = true,
          filename = "__base__/graphics/entity/substation/substation-shadow.png",
          width = 186,
          height = 52,
          hr_version = {
            draw_as_shadow = true,
            filename = "__base__/graphics/entity/substation/hr-substation-shadow.png",
            width = 370,
            height = 104,
            priority = "high",
            scale = 0.5,
            shift = {1.9375, 0.3125},
          },
          priority = "high",
          shift = {1.9375, 0.3125},
        }
      }
    },
    vehicle_impact_sound = substation.vehicle_impact_sound,
  }
}
