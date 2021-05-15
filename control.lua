-- Command signals
local DEPLOY_SIGNAL = {name="construction-robot", type="item"}
local DECONSTRUCT_SIGNAL = {name="deconstruction-planner", type="item"}
local COPY_SIGNAL = {name="signal-C", type="virtual"}
local X_SIGNAL = {name="signal-X", type="virtual"}
local Y_SIGNAL = {name="signal-Y", type="virtual"}
local WIDTH_SIGNAL = {name="signal-W", type="virtual"}
local HEIGHT_SIGNAL = {name="signal-H", type="virtual"}
local ROTATE_SIGNAL = {name="signal-R", type="virtual"}

function on_init()
  global.deployers = {}
  global.fuel_requests = {}
  on_mods_changed()
end

function on_mods_changed(event)
  global.net_cache = {}
  global.tag_cache = {}

  -- Migration for fuel requests
  if event
  and event.mod_changes["recursive-blueprints"].old_version
  and event.mod_changes["recursive-blueprints"].old_version < "1.1.5" then
    local new_fuel_requests = {}
    for _, request in pairs(global.fuel_requests or {}) do
      if request.proxy and request.proxy.valid then
        new_fuel_requests[request.proxy.unit_number] = request.entity
      end
    end
    global.fuel_requests = new_fuel_requests
  end

  -- Construction robotics unlocks deployer chest
  for _, force in pairs(game.forces) do
    if force.technologies["construction-robotics"].researched then
      force.recipes["blueprint-deployer"].enabled = true
    end
  end

  -- Collect all modded blueprint signals in one table
  global.blueprint_signals = {}
  for _, item in pairs(game.item_prototypes) do
    if item.type == "blueprint"
    or item.type == "blueprint-book"
    or item.type == "upgrade-item"
    or item.type == "deconstruction-item" then
      table.insert(global.blueprint_signals, {name=item.name, type="item"})
    end
  end
end

function on_built(event)
  local entity = event.created_entity or event.entity or event.destination
  if not entity or not entity.valid then return end
  if entity.name == "blueprint-deployer" then
    table.insert(global.deployers, entity)
  elseif entity.train then
    on_built_carriage(entity, event.tags)
  end
end

function on_tick()
  for key, deployer in pairs(global.deployers) do
    if deployer.valid then
      on_tick_deployer(deployer)
    else
      global.deployers[key] = nil
    end
  end
end

function on_tick_deployer(deployer)
  local bp = nil
  local deploy = get_signal(deployer, DEPLOY_SIGNAL)
  if deploy > 0 then
    bp = deployer.get_inventory(defines.inventory.chest)[1]
    if not bp.valid_for_read then return end

    -- Pick item from blueprint book
    if bp.is_blueprint_book then
      local inventory = bp.get_inventory(defines.inventory.item_main)
      local size = inventory.get_item_count() + inventory.count_empty_stacks()
      if size < 1 then return end
      if deploy > size then
        deploy = bp.active_index
      end
      bp = inventory[deploy]
      if not bp.valid_for_read then return end
    end

    -- Pick active item from nested blueprint books
    bp = get_nested_blueprint(bp)
    if not bp or not bp.valid_for_read then return end

    if bp.is_blueprint then
      -- Deploy blueprint
      deploy_blueprint(bp, deployer)
    elseif bp.is_deconstruction_item then
      -- Deconstruct area
      deconstruct_area(bp, deployer, true)
    elseif bp.is_upgrade_item then
      -- Upgrade area
      upgrade_area(bp, deployer, true)
    end
    return
  end

  if deploy == -1 then
    bp = deployer.get_inventory(defines.inventory.chest)[1]
    if not bp.valid_for_read then return end
    if bp.is_deconstruction_item then
      -- Cancel deconstruction in area
      deconstruct_area(bp, deployer, false)
    elseif bp.is_upgrade_item then
      -- Cancel upgrade in area
      upgrade_area(bp, deployer, false)
    end
    return
  end

  local deconstruct = get_signal(deployer, DECONSTRUCT_SIGNAL)
  if deconstruct == -1 then
    -- Deconstruct area
    deconstruct_area(bp, deployer, true)
    return
  elseif deconstruct == -2 then
    -- Deconstruct self
    deployer.order_deconstruction(deployer.force)
    return
  elseif deconstruct == -3 then
    -- Cancel deconstruction in area
    deconstruct_area(bp, deployer, false)
    return
  end

  local copy = get_signal(deployer, COPY_SIGNAL)
  if copy == 1 then
    -- Copy blueprint
    copy_blueprint(deployer)
    return
  elseif copy == -1 then
    -- Delete blueprint
    local stack = deployer.get_inventory(defines.inventory.chest)[1]
    if not stack.valid_for_read then return end
    if stack.is_blueprint
    or stack.is_blueprint_book
    or stack.is_upgrade_item
    or stack.is_deconstruction_item then
      stack.clear()
    end
    return
  end
end

function deploy_blueprint(bp, deployer)
  if not bp then return end
  if not bp.valid_for_read then return end
  if not bp.is_blueprint_setup() then return end

  -- Rotate
  local rotation = get_signal(deployer, ROTATE_SIGNAL)
  local direction = defines.direction.north
  if (rotation == 1) then
    direction = defines.direction.east
  elseif (rotation == 2) then
    direction = defines.direction.south
  elseif (rotation == 3) then
    direction = defines.direction.west
  end

  -- Shift x,y coordinates
  local position = {
    x = deployer.position.x + get_signal(deployer, X_SIGNAL),
    y = deployer.position.y + get_signal(deployer, Y_SIGNAL),
  }

  -- Check for building out of bounds
  if position.x > 1000000
  or position.x < -1000000
  or position.y > 1000000
  or position.y < -1000000 then
    return
  end

  -- Build blueprint
  local result = bp.build_blueprint{
    surface = deployer.surface,
    force = deployer.force,
    position = position,
    direction = direction,
    force_build = true,
  }

  -- Raise event for ghosts created
  for _, ghost in pairs(result) do
    script.raise_event(defines.events.script_raised_built, {
      entity = ghost,
      stack = bp,
    })
  end
end

function deconstruct_area(bp, deployer, deconstruct)
  local area = get_area(deployer)
  if deconstruct == false then
    -- Cancel area
    deployer.surface.cancel_deconstruct_area{
      area = area,
      force = deployer.force,
      skip_fog_of_war = false,
      item = bp,
    }
  else
    -- Deconstruct area
    local deconstruct_self = deployer.to_be_deconstructed(deployer.force)
    deployer.surface.deconstruct_area{
      area = area,
      force = deployer.force,
      skip_fog_of_war = false,
      item = bp,
    }
    if not deconstruct_self then
       -- Don't deconstruct myself in an area order
      deployer.cancel_deconstruction(deployer.force)
    end
  end
end

function upgrade_area(bp, deployer, upgrade)
  local area = get_area(deployer)
  if upgrade == false then
    -- Cancel area
    deployer.surface.cancel_upgrade_area{
      area = area,
      force = deployer.force,
      skip_fog_of_war = false,
      item = bp,
    }
  else
    -- Upgrade area
    deployer.surface.upgrade_area{
      area = area,
      force = deployer.force,
      skip_fog_of_war = false,
      item = bp,
    }
  end
end

function get_area(deployer)
  local X = get_signal(deployer, X_SIGNAL)
  local Y = get_signal(deployer, Y_SIGNAL)
  local W = get_signal(deployer, WIDTH_SIGNAL)
  local H = get_signal(deployer, HEIGHT_SIGNAL)

  if W < 1 then W = 1 end
  if H < 1 then H = 1 end

  if settings.global["recursive-blueprints-area"].value == "corner" then
    -- Convert from top left corner to center
    X = X + math.floor((W - 1) / 2)
    Y = Y + math.floor((H - 1) / 2)
  end

  -- Align to grid
  if W % 2 == 0 then X = X + 0.5 end
  if H % 2 == 0 then Y = Y + 0.5 end

  -- Subtract 1 pixel from the edges to avoid tile overlap
  -- 2 / 256 = 0.0078125
  W = W - 0.0078125
  H = H - 0.0078125

  return {
    {deployer.position.x + X - W/2, deployer.position.y + Y - H/2},
    {deployer.position.x + X + W/2, deployer.position.y + Y + H/2},
  }
end

function copy_blueprint(deployer)
  local inventory = deployer.get_inventory(defines.inventory.chest)
  if not inventory.is_empty() then return end
  for _, signal in pairs(global.blueprint_signals) do
    -- Check for a signal before doing an expensive search
    if get_signal(deployer, signal) >= 1 then
      -- Signal exists, now we have to search for the blueprint
      local stack = find_stack_in_network(deployer, signal.name)
      if stack then
        inventory[1].set_stack(stack)
        return
      end
    end
  end
end

-- Breadth-first search for an item in the circuit network
-- If there are multiple items, returns the closest one (least wire hops)
function find_stack_in_network(deployer, item_name)
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
  local past = {}
  local future = {}
  while next(present) do
    for key, con in pairs(present) do
      -- Search connecting wires
      for _, def in pairs(con.entity.circuit_connection_definitions) do
        -- Wire color and connection points must match
        if def.target_entity.unit_number
        and def.wire == con.wire
        and def.source_circuit_id == con.connector then
          local hash = con_hash(def.target_entity, def.target_circuit_id, def.wire)
          if not past[hash] and not present[hash] and not future[hash] then
            -- Search inside the entity
            local stack = find_stack_in_container(def.target_entity, item_name)
            if stack then return stack end

            -- Add entity connections to future searches
            future[hash] = {
              entity = def.target_entity,
              connector = def.target_circuit_id,
              wire = def.wire
            }
          end
        end
      end
      past[key] = true
    end
    present = future
    future = {}
  end
end

-- Create a unique key for a circuit connector
function con_hash(entity, connector, wire)
  return entity.unit_number .. "-" .. connector .. "-" .. wire
end

-- Create a unique key for a blueprint entity
function pos_hash(entity, x_offset, y_offset)
  return entity.name .. "_" .. (entity.position.x + x_offset) .. "_" .. (entity.position.y + y_offset)
end

function find_stack_in_container(entity, item_name)
  if entity.type == "container" or entity.type == "logistic-container" then
    local inventory = entity.get_inventory(defines.inventory.chest)
    for i = 1, #inventory do
      if inventory[i].valid_for_read and inventory[i].name == item_name then
        return inventory[i]
      end
    end
  elseif entity.type == "inserter" then
    local behavior = entity.get_control_behavior()
    if behavior
    and behavior.circuit_read_hand_contents
    and entity.held_stack.valid_for_read
    and entity.held_stack.name == item_name then
      return entity.held_stack
    end
  end
end

-- Return integer value for given Signal: {type=, name=}
function get_signal(entity, signal)
  -- Cache the circuit networks to speed up performance
  local cache = global.net_cache[entity.unit_number]
  if not cache then
    cache = {last_update = -1}
    global.net_cache[entity.unit_number] = cache
  end
  -- Try to reload empty networks once per tick
  -- Never reload valid networks
  if cache.last_update < game.tick then
    if not cache.red_network or not cache.red_network.valid then
      cache.red_network = entity.get_circuit_network(defines.wire_type.red)
    end
    if not cache.green_network or not cache.green_network.valid then
      cache.green_network = entity.get_circuit_network(defines.wire_type.green)
    end
    cache.last_update = game.tick
  end

  -- Get the signal
  local value = 0
  if cache.red_network then
    value = value + cache.red_network.get_signal(signal)
  end
  if cache.green_network then
    value = value + cache.green_network.get_signal(signal)
  end

  -- Mimic circuit network integer overflow
  if value > 2147483647 then value = value - 4294967296 end
  if value < -2147483648 then value = value + 4294967296 end
  return value
end

function get_nested_blueprint(bp)
  if not bp then return end
  if not bp.valid_for_read then return end
  while bp.is_blueprint_book do
    if not bp.active_index then return end
    bp = bp.get_inventory(defines.inventory.item_main)[bp.active_index]
    if not bp.valid_for_read then return end
  end
  return bp
end

function on_built_carriage(entity, tags)
  -- Check for automatic mode tag
  if tags and tags.manual_mode ~= nil and tags.manual_mode == false then
    -- Wait for the entire train to be built
    if tags.train_length == #entity.train.carriages then
      -- Turn on automatic mode
      enable_automatic_mode(entity.train)
    end
  end
end

function on_entity_destroyed(event)
  -- Look for completed train fuel item-request-proxy
  local carriage = global.fuel_requests[event.unit_number]
  global.fuel_requests[event.unit_number] = nil
  if carriage and carriage.valid and carriage.train then
    enable_automatic_mode(carriage.train)
  end
end

function enable_automatic_mode(train)
  -- Train is already driving
  if train.speed ~= 0 then return end
  if not train.manual_mode then return end

  -- Train is marked for deconstruction
  for _, carriage in pairs(train.carriages) do
    if carriage.to_be_deconstructed(carriage.force) then return end
  end

  -- Train is waiting for fuel
  for _, carriage in pairs(train.carriages) do
    local requests = carriage.surface.find_entities_filtered{
      type = "item-request-proxy",
      position = carriage.position,
    }
    for _, request in pairs(requests) do
      if request.proxy_target == carriage then
        global.fuel_requests[request.unit_number] = carriage
        script.register_on_entity_destroyed(request)
        return
      end
    end
  end

  -- Turn on automatic mode
  train.manual_mode = false
end

-- Add automatic mode tags to blueprint
function on_player_setup_blueprint(event)
  -- Discard old tags
  global.tag_cache[event.player_index] = nil

  -- Search the selected area for trains
  local player = game.players[event.player_index]
  local entities = player.surface.find_entities_filtered {
    area = event.area,
    force = player.force,
    type = {"locomotive", "cargo-wagon", "fluid-wagon", "artillery-wagon", "straight-rail", "curved-rail"},
  }

  -- Check for trains in automatic mode
  local found_train = false
  for _, entity in pairs(entities) do
    if entity.type == "locomotive" and not entity.train.manual_mode then
      found_train = true
      break
    end
  end
  if not found_train then return end

  -- Add automatic mode tags to blueprint
  local tags = create_tags(entities)
  local bp = get_nested_blueprint(player.cursor_stack)
  if bp and bp.valid_for_read and bp.is_blueprint then
    add_tags_to_blueprint(tags, bp)
  else
    -- They are editing a new blueprint and we can't access it
    -- Save the tags and add them later
    global.tag_cache[event.player_index] = tags
  end
end

function on_player_configured_blueprint(event)
  -- Finally, we can access the blueprint!
  -- Add automatic mode tags to blueprint
  local tags = global.tag_cache[event.player_index]
  local bp = get_nested_blueprint(game.players[event.player_index].cursor_stack)
  if tags and bp and bp.valid_for_read and bp.is_blueprint then
    add_tags_to_blueprint(global.tag_cache[event.player_index], bp)
  end

  -- Discard old tags
  global.tag_cache[event.player_index] = nil
end

function on_gui_opened(event)
  -- Discard old tags when a different blueprint is opened
  if event.gui_type == defines.gui_type.item
  and event.item
  and event.item.valid_for_read
  and event.item.is_blueprint then
    global.tag_cache[event.player_index] = nil
  end
end

-- Create automatic mode tags for each train
function create_tags(entities)
  local result = {}
  for _, entity in pairs(entities) do
    local tag = {
      name = entity.name,
      position = entity.position,
    }

    -- Write the automatic mode tag
    -- Also save the train length, to tell when the train is finished building
    if entity.train and not entity.train.manual_mode then
      tag.automatic_mode = true
      tag.length = #entity.train.carriages
    end

    -- Save the entity even if it is not a train in automatic mode
    -- This ensures that the offset is calculated correctly
    result[pos_hash(entity, 0, 0)] = tag
  end
  return result
end

function add_tags_to_blueprint(tags, blueprint)
  if not tags then return end
  if next(tags) == nil then return end
  if not blueprint then return end
  if not blueprint.is_blueprint_setup() then return end
  local blueprint_entities = blueprint.get_blueprint_entities()
  if not blueprint_entities then return end
  if #blueprint_entities < 1 then return end

  -- Calculate offset
  local offset = calculate_offset(tags, blueprint_entities)
  if not offset then return end

  -- Search for matching train carriages
  local found = false
  for _, entity in pairs(blueprint_entities) do
    local carriage = tags[pos_hash(entity, offset.x, offset.y)]
    if carriage and carriage.automatic_mode then
      -- Add tags to the blueprint entity
      if not entity.tags then
        entity.tags = {}
      end
      entity.tags.manual_mode = false
      entity.tags.train_length = carriage.length
      found = true
    end
  end

  -- Update blueprint
  if found then
    blueprint.set_blueprint_entities(blueprint_entities)
  end
end

-- Calculate the position offset between two sets of entities
-- Returns nil if the two sets cannot be aligned
-- Requires that table1's keys are generated using pos_hash()
function calculate_offset(table1, table2)
  -- Scan table 1
  local table1_names = {}
  for _, entity in pairs(table1) do
    -- Build index of entity names
    table1_names[entity.name] = true
  end

  -- Scan table 2
  local total = 0
  local anchor = nil
  for _, entity in pairs(table2) do
    if table1_names[entity.name] then
      -- Count appearances
      total = total + 1
      -- Pick an anchor entity to compare with table 1
      if not anchor then anchor = entity end
    end
  end
  if not anchor then return end

  for _, entity in pairs(table1) do
    if anchor.name == entity.name then
      -- Calculate the offset to an entity in table 1
      local x_offset = entity.position.x - anchor.position.x
      local y_offset = entity.position.y - anchor.position.y

      -- Check if the offset works for every entity in table 2
      local count = 0
      for _, entity in pairs(table2) do
        if table1[pos_hash(entity, x_offset, y_offset)] then
          count = count + 1
        end
      end
      if count == total then
        return {x = x_offset, y = y_offset}
      end
    end
  end
end


-- Global events
script.on_init(on_init)
script.on_configuration_changed(on_mods_changed)
script.on_event(defines.events.on_tick, on_tick)
script.on_event(defines.events.on_gui_opened, on_gui_opened)
script.on_event(defines.events.on_player_setup_blueprint, on_player_setup_blueprint)
script.on_event(defines.events.on_player_configured_blueprint, on_player_configured_blueprint)
script.on_event(defines.events.on_entity_destroyed, on_entity_destroyed)

-- Filter events for deployer chest and trains
local filter = {
  {filter = "name", name = "blueprint-deployer"},
  {filter = "type", type = "locomotive"},
  {filter = "type", type = "cargo-wagon"},
  {filter = "type", type = "fluid-wagon"},
  {filter = "type", type = "artillery-wagon"},
}
script.on_event(defines.events.on_built_entity, on_built, filter)
script.on_event(defines.events.on_entity_cloned, on_built, filter)
script.on_event(defines.events.on_robot_built_entity, on_built, filter)
script.on_event(defines.events.script_raised_built, on_built, filter)
script.on_event(defines.events.script_raised_revive, on_built, filter)
