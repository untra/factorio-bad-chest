-- correctly handle under/overflow
function overflow_int32(n)
  if n > 2147483647 then n = n - 4294967296 end
  if n < -2147483648 then n = n + 4294967296 end
  return n
end

-- cache the circuit networks to speed up performance
function update_net_cache(ent)
  if not net_cache then
    net_cache = {}
  end

  local ent_cache = net_cache[ent.unit_number]
  if not ent_cache then
    ent_cache = {last_update=-1}
    net_cache[ent.unit_number] = ent_cache
  end

  -- get the circuit networks at most once per tick per entity
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

function findEntityInBlueprint(bp,entityName)
  local bpEntities = bp.get_blueprint_entities()
  if not bpEntities then return nil end
  for _,bpEntity in pairs(bpEntities) do
    if bpEntity.name == entityName then
      return(bpEntity)
    end
  end
end

function deployBlueprint(bp, deployer, offsetpos, R)
  if not bp then return end
  if not bp.valid_for_read then return end
  if not bp.is_blueprint_setup() then return end
  local bpEntities = bp.get_blueprint_entities()
  local anchorEntity = nil
  anchorEntity = findEntityInBlueprint(bp,"wooden-chest")
  if not anchorEntity then
    anchorEntity = findEntityInBlueprint(bp,"blueprint-deployer")
  end

  local anchorX = 0
  local anchorY = 0
  if anchorEntity then
    anchorX = anchorEntity.position.x
    anchorY = anchorEntity.position.y
  end

  -- Rotate
  local direction = defines.direction.north
  if (R == 1) then
    direction = defines.direction.east
    anchorX, anchorY = -anchorY, anchorX
  end
  if (R == 2) then
    direction = defines.direction.south
    anchorX, anchorY = -anchorX, -anchorY
  end
  if (R == 3) then
    direction = defines.direction.west
    anchorX, anchorY = anchorY, -anchorX
  end
  
  local deploypos = {
    x = deployer.position.x + offsetpos.x - anchorX,
    y = deployer.position.y + offsetpos.y - anchorY
  }

  bp.build_blueprint{
    surface=deployer.surface,
    force=deployer.force,
    position=deploypos,
    force_build=true,
    direction=direction
  }
end

local function onTickDeployer(deployer)
  local deployPrint = get_signal_value(deployer,{name="construction-robot",type="item"})
  -- deployment-related actions
  if deployPrint > 0 then
    -- Check chest inventory for blueprint
    local deployerItemStack = deployer.get_inventory(defines.inventory.chest)[1]
    if not deployerItemStack.valid_for_read then return end

    local R = get_signal_value(deployer,{name="signal-R",type="virtual"})
    local X = get_signal_value(deployer,{name="signal-X",type="virtual"})
    local Y = get_signal_value(deployer,{name="signal-Y",type="virtual"})
    
    if deployerItemStack.name == "blueprint" then
      deployBlueprint(deployerItemStack, deployer, {x=X,y=Y}, R)
    elseif deployerItemStack.name == "blueprint-book" then
      local bookInv = deployerItemStack.get_inventory(defines.inventory.item_main)
      if deployPrint > bookInv.get_item_count() then
        deployPrint = deployerItemStack.active_index
      end
      deployBlueprint(bookInv[deployPrint], deployer, {x=X,y=Y}, R)
    end
    return
  end
  
  local deconstructArea = get_signal_value(deployer,{name="deconstruction-planner",type="item"})
  -- deconstruction-related actions
  if deconstructArea == -2 then -- decon=-2 Deconstruct Self
    deployer.order_deconstruction(deployer.force)
  elseif deconstructArea == -1 or deconstructArea == 1 then
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
    
    -- align to grid
    if W % 2 == 0 then X = X + 0.5 end
    if H % 2 == 0 then Y = Y + 0.5 end

    -- subtract 1 pixel from edges to avoid tile overlap
    W = W - 1/128
    H = H - 1/128
    
    local area = {
      {deployer.position.x+X-(W/2),deployer.position.y+Y-(H/2)},
      {deployer.position.x+X+(W/2),deployer.position.y+Y+(H/2)},
    }

    if deconstructArea == -1 then -- decon=-1 Deconstruct Area
      deployer.surface.deconstruct_area{area=area, force=deployer.force}
      deployer.cancel_deconstruction(deployer.force) -- Don't deconstruct myself in an area order
    elseif deconstructArea == 1 then -- decon=1 Cancel Area
      deployer.surface.cancel_deconstruct_area{area=area, force=deployer.force}
    end
  end
end

local function onTickDeployers(event)
  if global.deployers then
    for k,deployer in pairs(global.deployers) do
      if deployer.valid and deployer.name == "blueprint-deployer" then
        onTickDeployer(deployer)
      else
        global.deployers[k]=nil
      end
    end
  end
end

local function onBuiltDeployer(event)
  local ent = event.created_entity
  if not ent or not ent.valid then return end
  if ent.name == "blueprint-deployer" then 
    if not global.deployers then global.deployers={} end
    table.insert(global.deployers,ent)
  end
end

script.on_event(defines.events.on_tick, onTickDeployers)
script.on_event(defines.events.on_built_entity, onBuiltDeployer)
script.on_event(defines.events.on_robot_built_entity, onBuiltDeployer)

