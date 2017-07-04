local deployer = table.deepcopy(data.raw["container"]["steel-chest"])
deployer.name = "blueprint-deployer"
deployer.icon = "__recursive-blueprints__/graphics/blueprint-deployer-icon.png"
deployer.picture = {
  filename = "__recursive-blueprints__/graphics/blueprint-deployer-entity.png",
  priority = "extra-high",
  width = 39,
  height = 47,
  shift = {0.1, -0.23},
}
deployer.minable.result = "blueprint-deployer"
deployer.inventory_size = 1
data:extend{deployer}
