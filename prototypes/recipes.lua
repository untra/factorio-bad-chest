data:extend(
{
  {
    type = "recipe",
    name = "blueprint-deployer",
    enabled = false,
    ingredients =
    {
      {"steel-chest", 1},
      {"electronic-circuit", 1}
    },
    result = "blueprint-deployer"
  },
  {
    type = "recipe",
    name = "blueprint-digitizer",
    enabled = false,
    ingredients =
    {
      {"steel-chest", 1},
      {"advanced-circuit", 1},
    },
    result = "blueprint-digitizer"
  },
  {
    type = "recipe",
    name = "blueprint-printer",
    enabled = false,
    ingredients =
    {
      {"advanced-circuit", 1},
      {"electronic-circuit", 2},
      {"iron-gear-wheel", 3},
      {"iron-plate", 5}
    },
    result = "blueprint-printer"
  },
  {
    type = "recipe",
    name = "wipe-blueprint",
    enabled = false,
    energy_required = 1,
    ingredients =
    {
      {"blueprint", 1},
      {"electronic-circuit", 1},
    },
    result = "blueprint",
    icon = "__recursive-blueprints__/graphics/wipe-blueprint-icon.png",
  },
  {
    type = "recipe-category",
    name = "blueprints"
  },
  {
    type = "recipe",
    name = "clone-blueprint",
    enabled = false,
    energy_required = 1,
    category = "blueprints",
    ingredients =
    {
      {"blueprint-book", 1}
    },
    result = "blueprint-book",
    result_count = 1,
    icon = "__recursive-blueprints__/graphics/clone-blueprint-icon.png",
  },
  {
    type = "recipe",
    name = "insert-blueprint",
    enabled = false,
    energy_required = 1,
    category = "blueprints",
    ingredients =
    {
      {"blueprint-book", 1},
      {"blueprint", 1}
    },
    result = "blueprint-book",
    result_count = 1,
    icon = "__recursive-blueprints__/graphics/clone-blueprint-icon.png",
  },
  {
    type = "recipe",
    name = "extract-blueprint",
    enabled = false,
    energy_required = 1,
    category = "blueprints",
    ingredients =
    {
      {"blueprint-book", 1}
    },
    result = "blueprint",
    result_count = 1,
    icon = "__recursive-blueprints__/graphics/clone-blueprint-icon.png",
  },
  
}
)