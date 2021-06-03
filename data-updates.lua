local resources = {}
-- Water
resources["water"] = 1
-- Cliff explosives
if data.raw["capsule"]["cliff-explosives"] then
  resources["cliff-explosives"] = 1
end
-- Mining drill resources
for _, resource in pairs(data.raw["resource"]) do
  resources[resource.name] = 1
end
-- Deconstructible resources
for _, prototypes in pairs(data.raw) do
  for _, entity in pairs(prototypes) do
    if entity.autoplace and entity.minable then
      if entity.minable.result then
        resources[entity.minable.result] = 1
      end
      if entity.minable.results then
        for _, result in pairs(entity.minable.results) do
          if result.name then
            resources[result.name] = 1
          end
        end
      end
    end
  end
end
data.raw["constant-combinator"]["recursive-blueprints-scanner"].item_slot_count = table_size(resources)
