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
  local deployPrint = get_signal_value(deployer,{name="construction-robot",type="item"})
  if deployPrint > 0 then
    local bp = deployer.get_inventory(defines.inventory.chest)[1]
    if not bp.valid_for_read then return end
    if bp.is_blueprint then
      deploy_blueprint(bp, deployer)
    elseif bp.is_blueprint_book then
      local inventory = bp.get_inventory(defines.inventory.item_main)
      if deployPrint > inventory.get_item_count() then
        deployPrint = bp.active_index
      end
      deploy_blueprint(inventory[deployPrint], deployer)
    end
    return
  end

  local deconstructArea = get_signal_value(deployer,{name="deconstruction-planner",type="item"})
  if deconstructArea == -2 then
    -- Deconstruct Self
    deployer.order_deconstruction(deployer.force)
    return
  elseif deconstructArea == 1 then
    deconstruct_area(true, deployer)
    return
  elseif deconstructArea == -1 then
    deconstruct_area(false, deployer)
    return
  end

  local copy = get_signal_value(deployer,{name="signal-C",type="virtual"})
  if copy == 1 then
    -- Copy blueprint
    local inventory = deployer.get_inventory(defines.inventory.chest)
    for _, itemName in pairs(global.blueprint_signals) do
      if not inventory.is_empty() then return end
      if get_signal_value(deployer,{name=itemName,type="item"}) >= 1 then
        copy_stack(deployer, itemName)
      end
    end
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

  local R = get_signal_value(deployer,{name="signal-R",type="virtual"})
  local X = get_signal_value(deployer,{name="signal-X",type="virtual"})
  local Y = get_signal_value(deployer,{name="signal-Y",type="virtual"})

  -- Rotate
  local direction = defines.direction.north
  if (R == 1) then
    direction = defines.direction.east
    anchorX, anchorY = -anchorY, anchorX
  elseif (R == 2) then
    direction = defines.direction.south
    anchorX, anchorY = -anchorX, -anchorY
  elseif (R == 3) then
    direction = defines.direction.west
    anchorX, anchorY = anchorY, -anchorX
  end

  local position = {
    x = deployer.position.x + X - anchorX,
    y = deployer.position.y + Y - anchorY,
  }

  local result = bp.build_blueprint{
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
  local signal_groups = get_all_signals(deployer)
  local X,Y,W,H = 0,0,0,0
  for _,sig_group in pairs(signal_groups) do
    for _,sig in pairs(sig_group) do
      if sig.signal.name=="signal-X" then
        X = X + sig.count
      elseif sig.signal.name=="signal-H" then
        H = H + sig.count
      elseif sig.signal.name=="signal-W" then
        W = W + sig.count
      elseif sig.signal.name=="signal-Y" then
        Y = Y + sig.count
      end
    end
  end
  X = overflow_int32(X)
  Y = overflow_int32(Y)
  W = overflow_int32(W)
  H = overflow_int32(H)

  if W < 1 then W = 1 end
  if H < 1 then H = 1 end

  -- Align to grid
  if W % 2 == 0 then X = X + 0.5 end
  if H % 2 == 0 then Y = Y + 0.5 end

  -- Subtract 1 pixel from edges to avoid tile overlap
  W = W - 1/128
  H = H - 1/128

  local area = {
    {deployer.position.x+X-(W/2),deployer.position.y+Y-(H/2)},
    {deployer.position.x+X+(W/2),deployer.position.y+Y+(H/2)},
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

function copy_stack(deployer, itemName)
  local stack = find_stack_in_network(deployer, itemName)
  if not stack then return end
  deployer.get_inventory(defines.inventory.chest)[1].set_stack(stack)
end

function find_stack_in_network(deployer, itemName)
  -- Breadth-first search for the item in the network
  -- If there are multiple items, returns the closest one (least wire hops)
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

-- Correctly handle circuit network under/overflow
function overflow_int32(n)
  if n > 2147483647 then n = n - 4294967296 end
  if n < -2147483648 then n = n + 4294967296 end
  return n
end

-- Cache the circuit networks to speed up performance
function update_net_cache(ent)
  if not net_cache then
    net_cache = {}
  end

  local ent_cache = net_cache[ent.unit_number]
  if not ent_cache then
    ent_cache = {last_update=-1}
    net_cache[ent.unit_number] = ent_cache
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

-- Return integer value for given Signal: {type=, name=}
function get_signal_value(ent,signal)
  if signal == nil or signal.name == nil then return(0) end
  local ent_cache = update_net_cache(ent)

  local signal_val = 0

  if ent_cache.red_network then
    signal_val = signal_val + ent_cache.red_network.get_signal(signal)
  end

  if ent_cache.green_network then
    signal_val = signal_val + ent_cache.green_network.get_signal(signal)
  end

  return overflow_int32(signal_val);
end

-- Return array of signal groups. Each signal group is an array of Signal: {signal={type=, name=}, count=}
function get_all_signals(ent)
  local ent_cache = update_net_cache(ent)

  local signal_groups = {}
  if ent_cache.red_network then
    signal_groups[#signal_groups+1] = ent_cache.red_network.signals
  end

  if ent_cache.green_network then
    signal_groups[#signal_groups+1] = ent_cache.green_network.signals
  end

  return signal_groups
end


script.on_event(defines.events.on_tick, on_tick)
script.on_event(defines.events.on_built_entity, on_built)
script.on_event(defines.events.on_robot_built_entity, on_built)
script.on_event(defines.events.script_raised_built, on_built)
script.on_init(on_mods_changed)
script.on_configuration_changed(on_mods_changed)
