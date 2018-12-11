-- Command signals
local DEPLOY_SIGNAL = {name="construction-robot", type="item"}
local DECONSTRUCT_SIGNAL = {name="deconstruction-planner", type="item"}
local COPY_SIGNAL = {name="signal-C", type="virtual"}
local WIDTH_SIGNAL = {name="signal-W", type="virtual"}
local HEIGHT_SIGNAL = {name="signal-H", type="virtual"}
local X_SIGNAL = {name="signal-X", type="virtual"}
local Y_SIGNAL = {name="signal-Y", type="virtual"}
local ROTATE_SIGNAL = {name="signal-R", type="virtual"}

function on_mods_changed()
  -- Collect all modded blueprint signals in one table
  global.blueprint_signals = {}
  for _,item in pairs(game.item_prototypes) do
    if item.type == "blueprint" or item.type == "blueprint-book" then
      table.insert(global.blueprint_signals, item.name)
    end
  end
end

function on_built(event)
  local ent = event.created_entity
  if not ent or not ent.valid then return end
  if ent.name == "blueprint-deployer" then
    if not global.deployers then global.deployers={} end
    table.insert(global.deployers, ent)
  end
end

function on_tick(event)
  if global.deployers then
    for k,deployer in pairs(global.deployers) do
      if deployer.valid and deployer.name == "blueprint-deployer" then
        on_tick_deployer(deployer)
      else
        global.deployers[k]=nil
      end
    end
  end
end

function on_tick_deployer(deployer)
  local deployPrint = signal_value(deployer, DEPLOY_SIGNAL)
  if deployPrint > 0 then
    local bp = deployer.get_inventory(defines.inventory.chest)[1]
    if not bp.valid_for_read then return end
    if bp.is_blueprint then
      -- Deploy blueprint
      deploy_blueprint(bp, deployer)
    elseif bp.is_blueprint_book then
      -- Deploy blueprint from book
      local inventory = bp.get_inventory(defines.inventory.item_main)
      if deployPrint > inventory.get_item_count() then
        deployPrint = bp.active_index
      end
      deploy_blueprint(inventory[deployPrint], deployer)
    end
    return
  end

  local deconstructArea = signal_value(deployer, DECONSTRUCT_SIGNAL)
  if deconstructArea == -1 then
    -- Deconstruct area
    deconstruct_area(true, deployer)
    return
  elseif deconstructArea == 1 then
    -- Cancel deconstruction in area
    deconstruct_area(false, deployer)
    return
  elseif deconstructArea == -2 then
    -- Deconstruct Self
    deployer.order_deconstruction(deployer.force)
    return
  end

  local copy = signal_value(deployer, COPY_SIGNAL)
  if copy == 1 then
    -- Copy blueprint
    copy_blueprint(deployer)
    return
  elseif copy == -1 then
    -- Delete blueprint
    local stack = deployer.get_inventory(defines.inventory.chest)[1]
    if not stack.valid_for_read then return end
    if stack.is_blueprint or stack.is_blueprint_book then
      stack.clear()
    end
    return
  end
end

function deploy_blueprint(bp, deployer)
  if not bp then return end
  if not bp.valid_for_read then return end
  if not bp.is_blueprint_setup() then return end

  -- Find anchor point
  local anchorEntity = nil
  local bpEntities = bp.get_blueprint_entities()
  if bpEntities then
    for _,bpEntity in pairs(bpEntities) do
      if bpEntity.name == "wooden-chest" then
        anchorEntity = bpEntity
        break
      elseif bpEntity.name == "blueprint-deployer" and not anchorEntity then
        anchorEntity = bpEntity
      end
    end
  end
  local anchorX,anchorY = 0,0
  if anchorEntity then
    anchorX = anchorEntity.position.x
    anchorY = anchorEntity.position.y
  end

  -- Rotate
  local rotation = signal_value(deployer, ROTATE_SIGNAL)
  local direction = defines.direction.north
  if (rotation == 1) then
    direction = defines.direction.east
    anchorX, anchorY = -anchorY, anchorX
  elseif (rotation == 2) then
    direction = defines.direction.south
    anchorX, anchorY = -anchorX, -anchorY
  elseif (rotation == 3) then
    direction = defines.direction.west
    anchorX, anchorY = anchorY, -anchorX
  end

  local position = {
    x = deployer.position.x - anchorX + signal_value(deployer, X_SIGNAL),
    y = deployer.position.y - anchorY + signal_value(deployer, Y_SIGNAL),
  }

  bp.build_blueprint{
    surface = deployer.surface,
    force = deployer.force,
    position = position,
    direction = direction,
    force_build = true,
  }

  for _, entity in pairs(result) do
    script.raise_event(defines.events.on_robot_built_entity, {
      created_entity = entity,
      stack = bp,
      robot = {valid = false, type = "container", name = "blueprint-deployer"},
    })
  end
end

function deconstruct_area(deconstruct, deployer)
  local W = signal_value(deployer, WIDTH_SIGNAL)
  local H = signal_value(deployer, HEIGHT_SIGNAL)
  local X = signal_value(deployer, X_SIGNAL)
  local Y = signal_value(deployer, Y_SIGNAL)

  if W < 1 then W = 1 end
  if H < 1 then H = 1 end

  -- Align to grid
  if W % 2 == 0 then X = X + 0.5 end
  if H % 2 == 0 then Y = Y + 0.5 end

  -- Subtract 1 pixel from edges to avoid tile overlap
  W = W - 1/128
  H = H - 1/128

  local area = {
    {deployer.position.x+X-(W/2), deployer.position.y+Y-(H/2)},
    {deployer.position.x+X+(W/2), deployer.position.y+Y+(H/2)},
  }

  if deconstruct == false then
    -- Cancel Area
    deployer.surface.cancel_deconstruct_area{area=area, force=deployer.force}
  else
    -- Deconstruct Area
    local deconstructSelf = deployer.to_be_deconstructed(deployer.force)
    deployer.surface.deconstruct_area{area=area, force=deployer.force}
    if not deconstructSelf then
       -- Don't deconstruct myself in an area order
      deployer.cancel_deconstruction(deployer.force)
    end
  end
end

function copy_blueprint(deployer)
  local inventory = deployer.get_inventory(defines.inventory.chest)
  if not inventory.is_empty() then return end
  for _, itemName in pairs(global.blueprint_signals) do
    -- Check for a signal before doing an expensive search
    if signal_value(deployer, {name=itemName, type="item"}) >= 1 then
      -- Signal exists, now we have to search for the blueprint
      local stack = find_stack_in_network(deployer, itemName)
      if stack then
        inventory[1].set_stack(stack)
        return
      end
    end
  end
end

-- Breadth-first search for an item in the circuit network
-- If there are multiple items, returns the closest one (least wire hops)
function find_stack_in_network(deployer, itemName)
  local present = {
    [con_hash(deployer, defines.circuit_connector_id.container, defines.wire_type.red)] =
    {
      entity = deployer,
      connector = defines.circuit_connector_id.container,
      wire = defines.wire_type.red,
    },
    [con_hash(deployer, defines.circuit_connector_id.container, defines.wire_type.green)] =
    {
      entity = deployer,
      connector = defines.circuit_connector_id.container,
      wire = defines.wire_type.green,
    }
  }
  local future = {}
  local past = {}
  while next(present) do
    for k,p in pairs(present) do
      -- Search connecting wires
      for _,f in pairs(p.entity.circuit_connection_definitions) do
        -- Wire color and connection points must match
        if f.target_entity.unit_number
        and f.wire == p.wire
        and f.source_circuit_id == p.connector then
          local hash = con_hash(f.target_entity, f.target_circuit_id, f.wire)
          if not past[hash] and not present[hash] and not future[hash] then
            -- Search inside the entity
            local stack = find_stack_in_container(f.target_entity, itemName)
            if stack then return stack end

            -- Add entity connections to future searches
            future[hash] = {
              entity = f.target_entity,
              connector = f.target_circuit_id,
              wire = f.wire
            }
          end
        end
      end
      past[k] = true
    end
    present = future
    future = {}
  end
end

function find_stack_in_container(entity, itemName)
  if entity.type == "container" or entity.type == "logistic-container" then
    local inventory = entity.get_inventory(defines.inventory.chest)
    for i = 1, #inventory do
      if inventory[i].valid_for_read and inventory[i].name == itemName then
        return inventory[i]
      end
    end
  elseif entity.type == "inserter" then
    local behavior = entity.get_control_behavior()
    if not behavior then return end
    if not behavior.circuit_read_hand_contents then return end
    if entity.held_stack.valid_for_read and entity.held_stack.name == itemName then
      return entity.held_stack
    end
  end
end

function con_hash(entity, connector, wire)
  return entity.unit_number .. "-" .. connector .. "-" .. wire
end

-- Return integer value for given Signal: {type=, name=}
function signal_value(ent, signal)
  local cache = get_net_cache(ent)
  local value = 0
  if cache.red_network then
    value = value + cache.red_network.get_signal(signal)
  end
  if cache.green_network then
    value = value + cache.green_network.get_signal(signal)
  end

  -- Correctly handle circuit network under/overflow
  if value > 2147483647 then value = value - 4294967296 end
  if value < -2147483648 then value = value + 4294967296 end
  return value;
end

-- Cache the circuit networks to speed up performance
function get_net_cache(ent)
  if not global.net_cache then
    global.net_cache = {}
  end

  local ent_cache = global.net_cache[ent.unit_number]
  if not ent_cache then
    ent_cache = {last_update = -1}
    global.net_cache[ent.unit_number] = ent_cache
  end

  -- Get the circuit networks at most once per tick per entity
  if game.tick > ent_cache.last_update then
    if not ent_cache.red_network or not ent_cache.red_network.valid then
      ent_cache.red_network = ent.get_circuit_network(defines.wire_type.red)
    end
    if not ent_cache.green_network or not ent_cache.green_network.valid then
      ent_cache.green_network = ent.get_circuit_network(defines.wire_type.green)
    end
    ent_cache.last_update = game.tick
  end

  return ent_cache;
end


script.on_event(defines.events.on_tick, on_tick)
script.on_event(defines.events.on_built_entity, on_built)
script.on_event(defines.events.on_robot_built_entity, on_built)
script.on_event(defines.events.script_raised_built, on_built)
script.on_init(on_mods_changed)
script.on_configuration_changed(on_mods_changed)
