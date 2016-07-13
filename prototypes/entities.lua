data:extend{
  {
    type = "container",
    name = "blueprint-deployer",
    icon = "__recursive-blueprints__/graphics/blueprint-deployer-icon.png",
    flags = {"placeable-neutral", "player-creation"},
    minable = {mining_time = 1, result = "blueprint-deployer"},
    max_health = 200,
    corpse = "small-remnants",
    open_sound = { filename = "__base__/sound/metallic-chest-open.ogg", volume=0.65 },
    close_sound = { filename = "__base__/sound/metallic-chest-close.ogg", volume = 0.7 },
    resistances =
    {
      {
        type = "fire",
        percent = 90
      }
    },
    collision_box = {{-0.35, -0.35}, {0.35, 0.35}},
    selection_box = {{-0.5, -0.5}, {0.5, 0.5}},
    fast_replaceable_group = "container",
    inventory_size = 1,
    vehicle_impact_sound =  { filename = "__base__/sound/car-metal-impact.ogg", volume = 0.65 },
    picture =
    {
      filename = "__recursive-blueprints__/graphics/blueprint-deployer-entity.png",
      priority = "extra-high",
      width = 39,
      height = 47,
      frame_count = 8,
      animation_speed = 0.5,
      shift = {0.1, -0.23}
    },
    circuit_wire_connection_point =
    {
      shadow ={red = {0.734375, 0.453125},green = {0.609375, 0.515625},},
      wire ={red = {0.40625, 0.21875},green = {0.40625, 0.375},}
    },
    circuit_connector_sprites = get_circuit_connector_sprites({0.1875, 0.15625}, nil, 18),
    circuit_wire_max_distance = 7.5
  }}

local bpDigitizer = copyPrototype("container","blueprint-deployer","blueprint-digitizer")
data:extend{bpDigitizer}  
  
local bpPrinter = copyPrototype("assembling-machine","assembling-machine-2","blueprint-printer")  
    bpPrinter.minable.result = "blueprint-printer"
    bpPrinter.fast_replaceable_group = "blueprint-printer"
    bpPrinter.crafting_categories = {"blueprints"}
    bpPrinter.crafting_speed = 1
    bpPrinter.ingredient_count = 4
    bpPrinter.module_specification = nil
data:extend{bpPrinter}