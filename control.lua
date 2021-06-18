require("util")

-- Command signals
local DEPLOY_SIGNAL = {name="construction-robot", type="item"}
local DECONSTRUCT_SIGNAL = {name="deconstruction-planner", type="item"}
local COPY_SIGNAL = {name="signal-C", type="virtual"}
local X_SIGNAL = {name="signal-X", type="virtual"}
local Y_SIGNAL = {name="signal-Y", type="virtual"}
local WIDTH_SIGNAL = {name="signal-W", type="virtual"}
local HEIGHT_SIGNAL = {name="signal-H", type="virtual"}
local ROTATE_SIGNAL = {name="signal-R", type="virtual"}

local STATUS_NAME = {
  [defines.entity_status.working] = "entity-status.working",
  [defines.entity_status.disabled] = "entity-status.disabled",
  [defines.entity_status.marked_for_deconstruction] = "entity-status.marked-for-deconstruction",
}
local STATUS_SPRITE = {
  [defines.entity_status.working] = "utility/status_working",
  [defines.entity_status.disabled] = "utility/status_not_working",
  [defines.entity_status.marked_for_deconstruction] = "utility/status_not_working",
}

function on_init()
  global.deployers = {}
  global.fuel_requests = {}
  global.networks = {}
  global.scanners = {}
  on_mods_changed()
end

function on_mods_changed(event)
  global.tag_cache = {}
  global.cliff_explosives = (game.item_prototypes["cliff-explosives"] ~= nil)

  -- Migrations
  if event
  and event.mod_changes
  and event.mod_changes["recursive-blueprints"]
  and event.mod_changes["recursive-blueprints"].old_version then
    -- Migrate fuel requests
    if event.mod_changes["recursive-blueprints"].old_version < "1.1.5" then
      local new_fuel_requests = {}
      for _, request in pairs(global.fuel_requests or {}) do
        if request.proxy and request.proxy.valid then
          new_fuel_requests[request.proxy.unit_number] = request.entity
        end
      end
      global.fuel_requests = new_fuel_requests
    end
    -- Migrate deployer index
    if event.mod_changes["recursive-blueprints"].old_version < "1.1.8" then
      global.net_cache = nil
      global.networks = {}
      local new_deployers = {}
      for _, deployer in pairs(global.deployers or {}) do
        if deployer.valid then
          new_deployers[deployer.unit_number] = deployer
        end
      end
      global.deployers = new_deployers
    end
  end

  -- Construction robotics unlocks deployer chest
  for _, force in pairs(game.forces) do
    if force.technologies["construction-robotics"]
    and force.technologies["construction-robotics"].researched then
      force.recipes["blueprint-deployer"].enabled = true
      force.recipes["recursive-blueprints-scanner"].enabled = true
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

  -- Collect all visible signals
  global.groups = {}
  for _, group in pairs(game.item_group_prototypes) do
    for _, subgroup in pairs(group.subgroups) do
      if subgroup.name == "other" or subgroup.name == "virtual-signal-special" then
        -- Hide special signals
      else
        local signals = {}
        -- Item signals
        local items = game.get_filtered_item_prototypes{
          {filter = "subgroup", subgroup = subgroup.name},
          {filter = "flag", flag = "hidden", invert = true, mode = "and"},
        }
        for _, item in pairs(items) do
          if item.subgroup == subgroup then
            table.insert(signals, {type = "item", name = item.name})
          end
        end
        -- Fluid signals
        local fluids = game.get_filtered_fluid_prototypes{
          {filter = "subgroup", subgroup = subgroup.name},
          {filter = "hidden", invert = true, mode = "and"},
        }
        for _, fluid in pairs(fluids) do
          if fluid.subgroup == subgroup then
            table.insert(signals, {type = "fluid", name = fluid.name})
          end
        end
        -- Virtual signals
        for _, signal in pairs(game.virtual_signal_prototypes) do
          if signal.subgroup == subgroup then
            table.insert(signals, {type = "virtual", name = signal.name})
          end
        end
        -- Cache the visible signals
        if #signals > 0 then
          if #global.groups == 0 or global.groups[#global.groups].name ~= group.name then
            table.insert(global.groups, {name = group.name, subgroups = {}})
          end
          table.insert(global.groups[#global.groups].subgroups, signals)
        end
      end
    end
  end

  -- Close all scanners
  for _, player in pairs(game.players) do
    if player.opened
    and player.opened.object_name == "LuaGuiElement"
    and player.opened.name:sub(1, 21) == "recursive-blueprints-" then
      player.opened = nil
    end
  end
end

function on_built(event)
  local entity = event.created_entity or event.entity or event.destination
  if not entity or not entity.valid then return end

  -- Support automatic mode for trains
  if entity.train then
    on_built_carriage(entity, event.tags)
    return
  end

  if entity.name == "recursive-blueprints-scanner" then
    on_built_scanner(entity, event)
    return
  end

  -- If entity is a blueprint deployer, cache circuit network connections
  if entity.name == "blueprint-deployer" then
    global.deployers[entity.unit_number] = entity
    update_network(entity)
    return
  end

  -- If neighbor is a blueprint deployer, update circuit network connections
  local connections = entity.circuit_connection_definitions
  if connections then
    for _, connection in pairs(connections) do
      if connection.target_entity.valid
      and connection.target_entity.name == "blueprint-deployer" then
        update_network(connection.target_entity)
      end
    end
  end
end

function on_tick()
  -- Check one deployer per tick for new circuit network connections
  local index = global.deployer_index
  global.deployer_index = next(global.deployers, global.deployer_index)
  if global.deployers[index] then
    if global.deployers[index].valid then
      update_network(global.deployers[index])
    else
      global.deployers[index] = nil
      global.networks[index] = nil
    end
  end

  -- Read all circuit networks
  for _, network in pairs(global.networks) do
    on_tick_network(network)
  end
end

function on_tick_network(network)
  -- Validate network
  if network.red and not network.red.valid then
    network.red = nil
  end
  if network.green and not network.green.valid then
    network.green = nil
  end
  if not network.red and not network.green then
    return
  end

  -- Read deploy signal
  local deploy = get_signal(network, DEPLOY_SIGNAL)
  local bp = nil
  if deploy > 0 then
    if not network.deployer.valid then return end
    bp = network.deployer.get_inventory(defines.inventory.chest)[1]
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
      deploy_blueprint(bp, network)
    elseif bp.is_deconstruction_item then
      -- Deconstruct area
      deconstruct_area(bp, network, true)
    elseif bp.is_upgrade_item then
      -- Upgrade area
      upgrade_area(bp, network, true)
    end
    return
  end

  if deploy == -1 then
    if not network.deployer.valid then return end
    bp = network.deployer.get_inventory(defines.inventory.chest)[1]
    if not bp.valid_for_read then return end
    if bp.is_deconstruction_item then
      -- Cancel deconstruction in area
      deconstruct_area(bp, network, false)
    elseif bp.is_upgrade_item then
      -- Cancel upgrade in area
      upgrade_area(bp, network, false)
    end
    return
  end

  -- Read deconstruct signal
  local deconstruct = get_signal(network, DECONSTRUCT_SIGNAL)
  if deconstruct == -1 then
    -- Deconstruct area
    if not network.deployer.valid then return end
    deconstruct_area(bp, network, true)
    return
  elseif deconstruct == -2 then
    -- Deconstruct self
    if not network.deployer.valid then return end
    network.deployer.order_deconstruction(network.deployer.force)
    return
  elseif deconstruct == -3 then
    -- Cancel deconstruction in area
    if not network.deployer.valid then return end
    deconstruct_area(bp, network, false)
    return
  end

  -- Read copy signal
  local copy = get_signal(network, COPY_SIGNAL)
  if copy == 1 then
    -- Copy blueprint
    if not network.deployer.valid then return end
    copy_blueprint(network)
    return
  elseif copy == -1 then
    -- Delete blueprint
    if not network.deployer.valid then return end
    local stack = network.deployer.get_inventory(defines.inventory.chest)[1]
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

-- Cache the circuit networks attached to the deployer
-- The deployer must be valid
function update_network(deployer)
  local network = global.networks[deployer.unit_number]
  if not network then
    network = {deployer = deployer}
    global.networks[deployer.unit_number] = network
  end
  if not network.red or not network.red.valid then
    network.red = deployer.get_circuit_network(defines.wire_type.red)
  end
  if not network.green or not network.green.valid then
    network.green = deployer.get_circuit_network(defines.wire_type.green)
  end
end

function deploy_blueprint(bp, network)
  if not bp then return end
  if not bp.valid_for_read then return end
  if not bp.is_blueprint_setup() then return end

  -- Rotate
  local rotation = get_signal(network, ROTATE_SIGNAL)
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
    x = network.deployer.position.x + get_signal(network, X_SIGNAL),
    y = network.deployer.position.y + get_signal(network, Y_SIGNAL),
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
    surface = network.deployer.surface,
    force = network.deployer.force,
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

function deconstruct_area(bp, network, deconstruct)
  local area = get_area(network)
  local force = network.deployer.force
  if deconstruct == false then
    -- Cancel area
    network.deployer.surface.cancel_deconstruct_area{
      area = area,
      force = force,
      skip_fog_of_war = false,
      item = bp,
    }
  else
    -- Deconstruct area
    local deconstruct_self = network.deployer.to_be_deconstructed(force)
    network.deployer.surface.deconstruct_area{
      area = area,
      force = force,
      skip_fog_of_war = false,
      item = bp,
    }
    if not deconstruct_self then
       -- Don't deconstruct myself in an area order
      network.deployer.cancel_deconstruction(force)
    end
  end
end

function upgrade_area(bp, network, upgrade)
  local area = get_area(network)
  if upgrade == false then
    -- Cancel area
    network.deployer.surface.cancel_upgrade_area{
      area = area,
      force = network.deployer.force,
      skip_fog_of_war = false,
      item = bp,
    }
  else
    -- Upgrade area
    network.deployer.surface.upgrade_area{
      area = area,
      force = network.deployer.force,
      skip_fog_of_war = false,
      item = bp,
    }
  end
end

-- Return integer value for given Signal: {type=, name=}
-- The red and green networks must be valid or nil
function get_signal(network, signal)
  local value = 0
  if network.red then
    value = value + network.red.get_signal(signal)
  end
  if network.green then
    value = value + network.green.get_signal(signal)
  end

  -- Mimic circuit network integer overflow
  if value > 2147483647 then value = value - 4294967296 end
  if value < -2147483648 then value = value + 4294967296 end
  return value
end

function get_area(network)
  local X = get_signal(network, X_SIGNAL)
  local Y = get_signal(network, Y_SIGNAL)
  local W = get_signal(network, WIDTH_SIGNAL)
  local H = get_signal(network, HEIGHT_SIGNAL)

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

  local position = network.deployer.position
  return {
    {position.x + X - W/2, position.y + Y - H/2},
    {position.x + X + W/2, position.y + Y + H/2},
  }
end

function copy_blueprint(network)
  local inventory = network.deployer.get_inventory(defines.inventory.chest)
  if not inventory.is_empty() then return end
  for _, signal in pairs(global.blueprint_signals) do
    -- Check for a signal before doing an expensive search
    if get_signal(network, signal) >= 1 then
      -- Signal exists, now we have to search for the blueprint
      local stack = find_stack_in_network(network.deployer, signal.name)
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

function on_built_scanner(entity, event)
  local scanner = {
    x = 0,
    y = 0,
    width = 64,
    height = 64,
  }
  local tags = event.tags
  if event.source and event.source.valid then
    -- Copy settings from clone
    tags = util.table.deepcopy(global.scanners[event.source.unit_number])
  end
  if tags then
    -- Copy settings from blueprint tags
    scanner.x = tags.x
    scanner.x_signal = tags.x_signal
    scanner.y = tags.y
    scanner.y_signal = tags.y_signal
    scanner.width = tags.width
    scanner.width_signal = tags.width_signal
    scanner.height = tags.height
    scanner.height_signal = tags.height_signal
  end
  scanner.entity = entity
  global.scanners[entity.unit_number] = scanner
  script.register_on_entity_destroyed(entity)
  scan_resources(scanner)
end

function on_entity_destroyed(event)
  if not event.unit_number then return end
  -- Train fuel item-request-proxy
  local carriage = global.fuel_requests[event.unit_number]
  if carriage then
    global.fuel_requests[event.unit_number] = nil
    if carriage.valid and carriage.train then
      enable_automatic_mode(carriage.train)
    end
    return
  end
  -- Resource scanner
  local scanner = global.scanners[event.unit_number]
  if scanner then
    global.scanners[event.unit_number] = nil
    for _, player in pairs(game.players) do
      if player.opened
      and player.opened.object_name == "LuaGuiElement"
      and player.opened.name == "recursive-blueprints-scanner"
      and player.opened.tags["recursive-blueprints-id"] == event.unit_number then
        player.opened.destroy()
      end
    end
    return
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
  local player = game.get_player(event.player_index)
  local entities = player.surface.find_entities_filtered {
    area = event.area,
    force = player.force,
    type = {
      "locomotive",
      "cargo-wagon",
      "fluid-wagon",
      "artillery-wagon",
      "straight-rail",
      "curved-rail",
      "constant-combinator",
    },
  }

  -- Check for trains in automatic mode
  local found_tag = false
  for _, entity in pairs(entities) do
    if entity.type == "locomotive" and not entity.train.manual_mode then
      found_tag = true
      break
    elseif entity.name == "recursive-blueprints-scanner" then
      found_tag = true
      break
    end
  end
  if not found_tag then return end

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
  -- Add custom tags to blueprint
  local tags = global.tag_cache[event.player_index]
  local bp = get_nested_blueprint(game.players[event.player_index].cursor_stack)
  if tags and bp and bp.valid_for_read and bp.is_blueprint then
    add_tags_to_blueprint(global.tag_cache[event.player_index], bp)
  end
  -- Discard old tags
  global.tag_cache[event.player_index] = nil
end

function on_setting_changed(event)
  if event.setting == "recursive-blueprints-area" then
    -- Refresh scanners
    for _, scanner in pairs(global.scanners) do
      scan_resources(scanner)
    end
  end
end

function on_gui_opened(event)
  -- Discard old tags when a different blueprint is opened
  if event.gui_type == defines.gui_type.item
  and event.item
  and event.item.valid_for_read
  and event.item.is_blueprint then
    global.tag_cache[event.player_index] = nil
  end
  -- Replace constant-combinator gui with a custom scanner gui
  if event.gui_type == defines.gui_type.entity
  and event.entity
  and event.entity.valid
  and event.entity.name == "recursive-blueprints-scanner" then
    local player = game.get_player(event.player_index)
    player.opened = create_scanner_gui(player, event.entity)
  end
end

function on_gui_closed(event)
  if event.gui_type == defines.gui_type.custom
  and event.element
  and event.element.valid
  and event.element.name == "recursive-blueprints-scanner" then
    destroy_gui(event.element)
  end
end

function on_gui_click(event)
  if not event.element.valid then return end
  local name = event.element.name
  if not name then return end
  if name:sub(1, 21) ~= "recursive-blueprints-" then return end

  if name == "recursive-blueprints-close" then
    destroy_gui(event.element.parent.parent)
  elseif name:sub(1, 29) == "recursive-blueprints-scanner-" then
    create_signal_gui(event.element)
  elseif name == "recursive-blueprints-set-constant" then
    set_scanner_value(event.player_index, event.element)
  elseif name:sub(1, 32) == "recursive-blueprints-tab-button-" then
    set_signal_gui_tab(event.element, tonumber(name:sub(33)))
  end
end

function destroy_gui(gui)
  -- Destroy dependent gui
  local screen = gui.gui.screen
  if gui.name == "recursive-blueprints-scanner" and screen["recursive-blueprints-signal"] then
    screen["recursive-blueprints-signal"].destroy()
  end
  -- Destroy gui
  gui.destroy()
  -- Turn off highlighted scanner button
  reset_scanner_gui_style(screen)
end

function on_gui_confirmed(event)
  if not event.element.valid then return end
  local name = event.element.name
  if not name then return end
  if name == "recursive-blueprints-constant" then
    set_scanner_value(event.player_index, event.element)
  end
end

function reset_scanner_gui_style(screen)
  local gui = screen["recursive-blueprints-scanner"]
  if not gui then return end
  local input_flow = gui.children[2].children[3].children[1].children[2]
  for i = 1, 4 do
    input_flow.children[i].children[2].style = "recursive-blueprints-slot"
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

    if entity.train and not entity.train.manual_mode then
      -- Write the automatic mode tag
      -- Also save the train length, to tell when the train is finished building
      tag.automatic_mode = true
      tag.length = #entity.train.carriages
    elseif entity.name == "recursive-blueprints-scanner" then
      -- Write the scanner settings
      local scanner = global.scanners[entity.unit_number]
      tag.x = scanner.x
      tag.x_signal = scanner.x_signal
      tag.y = scanner.y
      tag.y_signal = scanner.y_signal
      tag.width = scanner.width
      tag.width_signal = scanner.width_signal
      tag.height = scanner.height
      tag.height_signal = scanner.height_signal
    end

    -- Save the entity even if it has not custom tags
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

  -- Search for matching entities with custom tags
  local found = false
  for _, entity in pairs(blueprint_entities) do
    local settings = tags[pos_hash(entity, offset.x, offset.y)]
    if settings then
      if settings.automatic_mode then
        -- Add train tags
        if not entity.tags then entity.tags = {} end
        entity.tags.manual_mode = false
        entity.tags.train_length = settings.length
        found = true
      elseif settings.width then
        -- Add scanner tags
        if not entity.tags then entity.tags = {} end
        entity.tags.x = settings.x
        entity.tags.x_signal = settings.x_signal
        entity.tags.y = settings.y
        entity.tags.y_signal = settings.y_signal
        entity.tags.width = settings.width
        entity.tags.width_signal = settings.width_signal
        entity.tags.height = settings.height
        entity.tags.height_signal = settings.height_signal
        entity.control_behavior = nil
        found = true
      end
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

function add_titlebar(gui, caption, close_button_name, close_button_tooltip)
  local titlebar = gui.add{type = "flow"}
  titlebar.drag_target = gui
  titlebar.add{
    type = "label",
    style = "frame_title",
    caption = caption,
    ignored_by_interaction = true,
  }
  local filler = titlebar.add{
    type = "empty-widget",
    style = "draggable_space",
    ignored_by_interaction = true,
  }
  filler.style.height = 24
  filler.style.horizontally_stretchable = true
  if close_button_name then
    titlebar.add{
      type = "sprite-button",
      name = close_button_name,
      style = "frame_action_button",
      sprite = "utility/close_white",
      hovered_sprite = "utility/close_black",
      clicked_sprite = "utility/close_black",
      tooltip = close_button_tooltip,
    }
  end
end

function create_scanner_gui(player, entity)
  local scanner = global.scanners[entity.unit_number]
  if player.gui.screen["recursive-blueprints-scanner"] then
    player.gui.screen["recursive-blueprints-scanner"].destroy()
  end

  local gui = player.gui.screen.add{
    type = "frame",
    name = "recursive-blueprints-scanner",
    direction = "vertical",
    tags = {["recursive-blueprints-id"] = entity.unit_number}
  }
  gui.auto_center = true
  add_titlebar(gui, entity.localised_name, "recursive-blueprints-close", {"gui.close-instruction"})
  local inner_frame = gui.add{
    type = "frame",
    style = "entity_frame",
    direction = "vertical",
  }

  local status_flow = inner_frame.add{
    type = "flow",
    style = "status_flow",
  }
  status_flow.style.vertical_align = "center"
  status_flow.add{
    type = "sprite",
    style = "status_image",
    sprite = STATUS_SPRITE[entity.status],
  }
  status_flow.add{
    type = "label",
    caption = {STATUS_NAME[entity.status]},
  }

  local preview_frame = inner_frame.add{
    type = "frame",
    style = "entity_button_frame",
  }
  local preview = preview_frame.add{
    type = "entity-preview",
  }
  preview.entity = entity
  preview.style.height = 148
  preview.style.horizontally_stretchable = true

  local main_flow = inner_frame.add{
    type = "flow",
  }
  local left_flow = main_flow.add{
    type = "flow",
    direction = "vertical",
  }
  left_flow.style.right_margin = 8
  left_flow.add{
    type = "label",
    style = "heading_3_label",
    caption = {"description.scan-area"},
  }
  local input_flow = left_flow.add{
    type = "flow",
    direction = "vertical",
  }
  input_flow.style.horizontal_align = "right"

  local x_flow = input_flow.add{
    type = "flow",
  }
  x_flow.style.vertical_align = "center"
  x_flow.add{
    type = "label",
    caption = {"", {"description.x-offset"}, ":"}
  }
  x_flow.add{
    type = "sprite-button",
    style = "recursive-blueprints-slot",
    name = "recursive-blueprints-scanner-x"
  }

  local y_flow = input_flow.add{
    type = "flow",
  }
  y_flow.style.vertical_align = "center"
  y_flow.add{
    type = "label",
    caption = {"", {"description.y-offset"}, ":"}
  }
  y_flow.add{
    type = "sprite-button",
    style = "recursive-blueprints-slot",
    name = "recursive-blueprints-scanner-y"
  }

  local width_flow = input_flow.add{
    type = "flow",
  }
  width_flow.style.vertical_align = "center"
  width_flow.add{
    type = "label",
    caption = {"", {"gui-map-generator.map-width"}, ":"}
  }
  width_flow.add{
    type = "sprite-button",
    style = "recursive-blueprints-slot",
    name = "recursive-blueprints-scanner-width"
  }

  local height_flow = input_flow.add{
    type = "flow",
  }
  height_flow.style.vertical_align = "center"
  height_flow.add{
    type = "label",
    caption = {"", {"gui-map-generator.map-height"}, ":"}
  }
  height_flow.add{
    type = "sprite-button",
    style = "recursive-blueprints-slot",
    name = "recursive-blueprints-scanner-height"
  }

  local minimap_frame = main_flow.add{
    type = "frame",
    style = "entity_button_frame",
  }
  minimap_frame.style.size = 256
  minimap_frame.style.vertical_align = "center"
  minimap_frame.style.horizontal_align = "center"
  local minimap = minimap_frame.add{
    type = "minimap",
    surface_index = entity.surface.index,
    force = entity.force.name,
    position = entity.position,
  }
  minimap.style.minimal_width = 16
  minimap.style.minimal_height = 16
  minimap.style.maximal_width = 256
  minimap.style.maximal_height = 256

  inner_frame.add{type = "line"}

  inner_frame.add{
    type = "label",
    style = "heading_3_label",
    caption = {"description.output-signals"},
  }
  local scroll_pane = inner_frame.add{
    type = "scroll-pane",
    style = "recursive-blueprints-scroll",
    direction = "vertical",
    horizontal_scroll_policy = "never",
    vertical_scroll_policy = "auto",
  }
  scroll_pane.style.maximal_height = 164
  local scroll_frame = scroll_pane.add{
    type = "frame",
    style = "recursive-blueprints-scroll-frame",
    direction = "vertical",
  }
  local slots = scanner.entity.prototype.item_slot_count
  for i = 1, slots, 10 do
    local row = scroll_frame.add{
      type = "flow",
      style = "packed_horizontal_flow",
    }
    for j = 0, 9 do
      if i+j <= slots then
        row.add{
          type = "sprite-button",
          style = "recursive-blueprints-output",
        }
      end
    end
  end

  update_scanner_gui(gui)
  return gui
end

function create_signal_gui(element)
  local screen = element.gui.screen
  local primary_gui = element.parent.parent.parent.parent.parent.parent
  local id = primary_gui.tags["recursive-blueprints-id"]
  local scanner = global.scanners[id]
  local field = element.name:sub(30)
  local target = scanner[field.."signal"] or {}
  element.style = "recursive-blueprints-slot-selected"

  if screen["recursive-blueprints-signal"] then
    screen["recursive-blueprints-signal"].destroy()
  end

  local gui = screen.add{
    type = "frame",
    name = "recursive-blueprints-signal",
    direction = "vertical",
    tags = {
      ["recursive-blueprints-id"] = id,
      ["recursive-blueprints-field"] = field,
    }
  }
  gui.auto_center = true
  add_titlebar(gui, {"gui.select-signal"}, "recursive-blueprints-close")
  local inner_frame = gui.add{
    type = "frame",
    style = "inside_shallow_frame",
    direction = "vertical",
  }

  -- Add tab bar, but don't add tabs until we know which one is selected
  local scroll_pane = inner_frame.add{
    type = "scroll-pane",
    style = "naked_scroll_pane",
    direction = "vertical",
    horizontal_scroll_policy = "never",
    vertical_scroll_policy = "auto",
  }
  scroll_pane.style.maximal_height = 132
  local tab_bar = scroll_pane.add{
    type = "frame",
    style = "recursive-blueprints-scroll-frame2",
    direction = "vertical",
  }

  -- Open the signals tab if nothing is selected
  local selected_tab = 1
  for i = 1, #global.groups do
    if global.groups[i].name == "signals" then
      selected_tab = i
    end
  end

  -- Add tab pane
  local tabbed_pane = inner_frame.add{
    type = "tabbed-pane",
    style = "recursive-blueprints-tabbed-pane",
  }
  tabbed_pane.style.bottom_margin = 4
  for _, group in pairs(global.groups) do
    local tab = tabbed_pane.add{
      type = "tab",
      style = "recursive-blueprints-invisible-tab",
    }
    local scroll_pane = tabbed_pane.add{
      type = "scroll-pane",
      style = "recursive-blueprints-scroll",
      direction = "vertical",
      horizontal_scroll_policy = "never",
      vertical_scroll_policy = "auto",
    }
    scroll_pane.style.height = 364
    local scroll_frame = scroll_pane.add{
      type = "frame",
      style = "recursive-blueprints-scroll-frame",
      direction = "vertical",
    }
    -- Add signals
    for i = 1, #group.subgroups do
      for j = 1, #group.subgroups[i], 10 do
        local row = scroll_frame.add{
          type = "flow",
          style = "packed_horizontal_flow",
        }
        for k = 0, 9 do
          if j+k <= #group.subgroups[i] then
            local signal = group.subgroups[i][j+k]
            local button = row.add{
              type = "sprite-button",
              style = "recursive-blueprints-filter",
              sprite = get_signal_sprite(signal),
              tooltip = {"",
                "[font=default-bold][color=255,230,192]",
                get_localised_name(signal),
                "[/color][/font]",
              }
            }
            if signal.type == target.type and signal.name == target.name then
              -- This is the selected signal!
              selected_tab = i
              button.style = "recursive-blueprints-filter-selected"
              scroll_pane.scroll_to_element(button)
            end
          end
        end
      end
    end
    tabbed_pane.add_tab(tab, scroll_pane)
  end
  if #tabbed_pane.tabs >= 1 then
    tabbed_pane.selected_tab_index = selected_tab
  end

  -- Add tab buttons to tab bar
  for i = 1, #global.groups, 6 do
    local row = tab_bar.add{
      type = "flow",
      style = "packed_horizontal_flow",
    }
    for j = 0, 5 do
      if i+j <= #global.groups then
        local name = global.groups[i+j].name
        local button = row.add{
          type = "sprite-button",
          style = "recursive-blueprints-tab-button",
          name = "recursive-blueprints-tab-button-" .. (i+j),
          tooltip = {"item-group-name." .. name},
        }
        if game.is_valid_sprite_path("item-group/" .. name) then
          button.sprite = "item-group/" .. name
        else
          button.caption = {"item-group-name." .. name}
        end
        if i+j == selected_tab then
          if j == 0 then
            button.style = "recursive-blueprints-tab-button-left"
          elseif j == 5 then
            button.style = "recursive-blueprints-tab-button-right"
          else
            button.style = "recursive-blueprints-tab-button-selected"
          end
          button.parent.parent.parent.scroll_to_element(button)
        end
      end
    end
  end

  add_titlebar(gui, {"gui.or-set-a-constant"})
  local inner_frame = gui.add{
    type = "frame",
    style = "entity_frame",
    direction = "horizontal",
  }
  inner_frame.style.vertical_align = center
  local textfield = inner_frame.add{
    type = "textfield",
    name = "recursive-blueprints-constant",
    numeric = true,
    allow_negative = (field == "x" or field == "y"),
  }
  textfield.style.width = 83
  textfield.style.right_margin = 30
  textfield.style.horizontal_align = "center"
  if not scanner[field.."_signal"] then
    textfield.text = tostring(scanner[field])
  end
  inner_frame.add{
    type = "button",
    style = "recursive-blueprints-set-button",
    name = "recursive-blueprints-set-constant",
    caption = {"gui.set"},
  }

  return gui
end

function set_scanner_value(player_index, element)
  local screen = element.gui.screen
  local gui = screen["recursive-blueprints-scanner"]
  if not gui then return end
  reset_scanner_gui_style(screen)
  local scanner = global.scanners[gui.tags["recursive-blueprints-id"]]
  local key = element.parent.parent.tags["recursive-blueprints-field"]
  local value = tonumber(element.parent.children[1].text) or 0

  if value > 2000000 then value = 2000000 end
  if value < -2000000 then value = -2000000 end
  if key == "width" or key == "height" then
    if value < 0 then value = 0 end
    if value > 999 then value = 999 end
  end

  if scanner[key] ~= value then
    scanner[key] = value
    scan_resources(scanner)
  end

  update_scanner_gui(gui)
  -- Close signal gui
  element.parent.parent.destroy()
end

function set_signal_gui_tab(element, index)
  local tab_bar = element.parent.parent
  -- Unselect old tab
  for i = 1, #tab_bar.children do
    for j = 1, #tab_bar.children[i].children do
      tab_bar.children[i].children[j].style = "recursive-blueprints-tab-button"
    end
  end
  -- Select new tab
  local col = index % 6
  if col == 1 then
    element.style = "recursive-blueprints-tab-button-left"
  elseif col == 0 then
    element.style = "recursive-blueprints-tab-button-left"
  else
    element.style = "recursive-blueprints-tab-button-selected"
  end
  tab_bar.parent.parent.children[2].selected_tab_index = index
end

function update_scanner_gui(gui)
  local scanner = global.scanners[gui.tags["recursive-blueprints-id"]]
  if not scanner then return end
  if not scanner.entity.valid then return end

  local input_flow = gui.children[2].children[3].children[1].children[2]
  set_slot_button(input_flow.children[1].children[2], scanner.x, scanner.x_signal)
  set_slot_button(input_flow.children[2].children[2], scanner.y, scanner.y_signal)
  set_slot_button(input_flow.children[3].children[2], scanner.width, scanner.width_signal)
  set_slot_button(input_flow.children[4].children[2], scanner.height, scanner.height_signal)

  local x = scanner.x
  local y = scanner.y
  if settings.global["recursive-blueprints-area"].value == "corner" then
    -- Convert from top left corner to center
    x = x + math.floor(scanner.width/2)
    y = y + math.floor(scanner.width/2)
  end

  local minimap = gui.children[2].children[3].children[2].children[1]
  minimap.position = {
    scanner.entity.position.x + x,
    scanner.entity.position.y + y,
  }
  local largest = math.max(scanner.width, scanner.height)
  if largest == 0 then
    largest = 32
  end
  minimap.zoom = 256 / largest
  minimap.style.natural_width = scanner.width / largest * 256
  minimap.style.natural_height = scanner.height / largest * 256

  update_scanner_output(gui.children[2].children[6].children[1], scanner.entity)
end

function update_scanner_output(output_flow, entity)
  local behavior = entity.get_control_behavior()
  for i = 1, entity.prototype.item_slot_count do
    local row = math.ceil(i / 10)
    local col = (i-1) % 10 + 1
    local button = output_flow.children[row].children[col]
    local signal = behavior.get_signal(i)
    if signal and signal.signal and signal.signal.name then
      button.number = signal.count
      button.sprite = get_signal_sprite(signal.signal)
      button.tooltip = {"",
       "[font=default-bold][color=255,230,192]",
       {signal.signal.type .. "-name." .. signal.signal.name},
       ":[/color][/font] ",
       util.format_number(signal.count),
      }
    else
      button.number = nil
      button.sprite = nil
      button.tooltip = ""
    end
  end
end

function get_localised_name(signal)
  if not signal.type then return "" end
  if signal.type == "item" and game.item_prototypes[signal.name] then
    return game.item_prototypes[signal.name].localised_name
  elseif signal.type == "fluid" and game.fluid_prototypes[signal.name] then
    return game.fluid_prototypes[signal.name].localised_name
  elseif signal.type == "virtual" and game.virtual_signal_prototypes[signal.name] then
    return game.virtual_signal_prototypes[signal.name].localised_name
  else
    return {signal.name}
  end
end

function get_signal_sprite(signal)
  if not signal.name then return end
  if signal.type == "item" and game.item_prototypes[signal.name] then
    return "item/" .. signal.name
  elseif signal.type == "fluid" and game.fluid_prototypes[signal.name] then
    return "fluid/" .. signal.name
  elseif signal.type == "virtual" and game.virtual_signal_prototypes[signal.name] then
    return "virtual-signal/" .. signal.name
  else
    return "virtual-signal/signal-unknown"
  end
end

function set_slot_button(button, value, signal)
  if signal then
    button.caption = ""
    button.style.natural_width = 40
    button.sprite = get_signal_sprite(signal)
    button.tooltip = {"",
      "[font=default-bold][color=255,230,192]",
      get_localised_name(signal),
      "[/color][/font]",
    }
  else
    button.caption = format_amount(value)
    button.style.natural_width = button.caption:len() * 12 + 4
    button.sprite = nil
    button.tooltip = {"gui.constant-number"}
  end
end

function format_amount(amount)
  if amount >= 1000000000 then
    return math.floor(amount / 1000000000) .. "G"
  elseif amount >= 1000000 then
    return math.floor(amount / 1000000) .. "M"
  elseif amount >= 1000 then
    return math.floor(amount / 1000) .. "k"
  elseif amount > -1000 then
    return amount
  elseif amount > -1000000 then
    return math.ceil(amount / 1000) .. "k"
  elseif amount > -1000000000 then
    return math.ceil(amount / 1000000) .. "M"
  else
    return math.ceil(amount / 1000000000) .. "G"
  end
end

function count_resources(surface, area, resources, blacklist)
  local result = surface.find_entities_filtered{
    area = area,
    force = "neutral",
  }
  for _, resource in pairs(result) do
    local hash = pos_hash(resource, 0, 0)
    local prototype = resource.prototype
    if blacklist[hash] then
      -- We already counted this
    elseif resource.type == "cliff" and global.cliff_explosives then
      -- Cliff explosives
      resources.item["cliff-explosives"] = (resources.item["cliff-explosives"] or 0) - 1
    elseif resource.type == "resource" then
      -- Mining drill resources
      local type = prototype.mineable_properties.products[1].type
      local name = prototype.mineable_properties.products[1].name
      local amount = resource.amount
      if prototype.infinite_resource then
        amount = 1
      end
      resources[type][name] = (resources[type][name] or 0) + amount
    elseif (resource.type == "tree" or resource.type == "fish" or prototype.count_as_rock_for_filtered_deconstruction)
    and prototype.mineable_properties.minable
    and prototype.mineable_properties.products then
      -- Trees, fish, rocks
      for _, product in pairs(prototype.mineable_properties.products) do
        local amount = product.amount
        if product.amount_min and product.amount_max then
          amount = (product.amount_min + product.amount_max) / 2
          amount = amount * product.probability
        end
        resources[product.type][product.name] = (resources[product.type][product.name] or 0) + amount
      end
    end
    -- Mark as counted
    blacklist[hash] = true
  end
  -- Water
  resources.fluid["water"] = (resources.fluid["water"] or 0) + surface.count_tiles_filtered{
    area = area,
    collision_mask = "water-tile",
  }
end

function scan_resources(scanner)
  if not scanner then return end
  if not scanner.entity.valid then return end
  local resources = {item = {}, fluid = {}}
  local p = scanner.entity.position
  local force = scanner.entity.force
  local surface = scanner.entity.surface
  local x = scanner.x
  local y = scanner.y
  local blacklist = {}

  -- Align to grid
  if scanner.width % 2 ~= 0 then x = x + 0.5 end
  if scanner.height % 2 ~= 0 then y = y + 0.5 end

  if settings.global["recursive-blueprints-area"].value == "corner" then
    -- Convert from top left corner to center
    x = x + math.floor(scanner.width/2)
    y = y + math.floor(scanner.width/2)
  end

  local x1 = p.x + x - scanner.width/2 + 1/256
  local x2 = p.x + x + scanner.width/2 - 1/256
  local y1 = p.y + y - scanner.height/2 - 1/256
  local y2 = p.y + y + scanner.height/2 - 1/256

  -- Search one chunk at a time
  for x = x1, math.ceil(x2 / 32) * 32, 32 do
    for y = y1, math.ceil(y2 / 32) * 32, 32 do
      local chunk_x = math.floor(x / 32)
      local chunk_y = math.floor(y / 32)
      -- Chunk must be visible
      if force.is_chunk_charted(surface, {chunk_x, chunk_y}) then
        local left = chunk_x * 32
        local right = left + 32
        local top = chunk_y * 32
        local bottom = top + 32
        if left < x1 then left = x1 end
        if right > x2 then right = x2 end
        if top < y1 then top = y1 end
        if bottom > y2 then bottom = y2 end
        local area = {{left, top}, {right, bottom}}
        count_resources(surface, area, resources, blacklist)
      end
    end
  end

  -- Copy resources to combinator output
  local behavior = scanner.entity.get_control_behavior()
  local index = 1
  for type, resource in pairs(resources) do
    for name, count in pairs(resource) do
      -- Avoid int32 overflow
      if count > 2147483647 then count = 2147483647 end
      if count ~= 0 then
        behavior.set_signal(index, {signal={type=type, name=name}, count=count})
        index = index + 1
      end
    end
  end
  -- Set the remaining output slots to nil
  local max = scanner.entity.prototype.item_slot_count
  while index <= max do
    behavior.set_signal(index, nil)
    index = index + 1
  end
end

-- Global events
script.on_init(on_init)
script.on_configuration_changed(on_mods_changed)
script.on_event(defines.events.on_tick, on_tick)
script.on_event(defines.events.on_gui_opened, on_gui_opened)
script.on_event(defines.events.on_gui_closed, on_gui_closed)
script.on_event(defines.events.on_gui_click, on_gui_click)
script.on_event(defines.events.on_gui_confirmed, on_gui_confirmed)
script.on_event(defines.events.on_player_setup_blueprint, on_player_setup_blueprint)
script.on_event(defines.events.on_player_configured_blueprint, on_player_configured_blueprint)
script.on_event(defines.events.on_entity_destroyed, on_entity_destroyed)
script.on_event(defines.events.on_runtime_mod_setting_changed, on_setting_changed)

-- Filter out ghost build events
local filter = {
  {filter = "ghost", invert = true},
}
script.on_event(defines.events.on_built_entity, on_built, filter)
script.on_event(defines.events.on_entity_cloned, on_built, filter)
script.on_event(defines.events.on_robot_built_entity, on_built, filter)
script.on_event(defines.events.script_raised_built, on_built, filter)
script.on_event(defines.events.script_raised_revive, on_built, filter)

-- TODO: Check for obsolete scanner signals when mods change
