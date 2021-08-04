-- Cache the circuit networks attached to the entity
-- The entity must be valid
function update_network(deployer)
  if deployer.name == "recursive-blueprints-scanner" then
    -- Resource scanner only uses circuit networks if one of the signals is set
    local scanner = global.scanners[deployer.unit_number]
    if not (scanner.x_signal or scanner.y_signal or scanner.width_signal or scanner.height_signal) then
      return
    end
  end
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

-- Create a unique key for a circuit connector
function con_hash(entity, connector, wire)
  return entity.unit_number .. "-" .. connector .. "-" .. wire
end

-- Create a unique key for a blueprint entity
function pos_hash(entity, x_offset, y_offset)
  return entity.name .. "_" .. (entity.position.x + x_offset) .. "_" .. (entity.position.y + y_offset)
end

function round(n)
  return math.floor(n + 0.5)
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

    -- Save the entity even if it has no custom tags
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

-- Train fuel item-request-proxy has been completed
function on_item_request(unit_number)
  local carriage = global.fuel_requests[unit_number]
  if not carriage then return end
  global.fuel_requests[unit_number] = nil
  if carriage.valid and carriage.train then
    -- Done waiting for fuel, we can turn on automatic mode now
    enable_automatic_mode(carriage.train)
  end
end
