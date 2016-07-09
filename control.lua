function get_signal_value(entity,signal)
	local behavior = entity.get_control_behavior()
	if behavior == nil then	return(0)	end
	
	if signal == nil or signal.name == nil then return(0)	end
	
	local redval,greenval=0,0
	
	local rednetwork = entity.get_circuit_network(defines.wire_type.red)
	if rednetwork then
	  redval = rednetwork.get_signal(signal)  
	end
	
	local greennetwork = entity.get_circuit_network(defines.wire_type.green)
	if greennetwork then
	  greenval = greennetwork.get_signal(signal)
	end
	return(redval + greenval)
end

function deployBlueprint(bp,deployer,offsetpos)
  if not bp then return end
  if not bp.valid_for_read then return end
  if not bp.is_blueprint_setup() then return end
  local bpEntities = bp.get_blueprint_entities()
  local anchorEntity = nil
  for _,bpEntity in pairs(bpEntities) do
    if bpEntity.name == "wooden-chest" then
      anchorEntity = bpEntity
      break
    end
  end
  if not anchorEntity then
    for _,bpEntity in pairs(bpEntities) do
      if bpEntity.name == "blueprint-deployer" then
        anchorEntity = bpEntity
        break
      end
    end 
  end
		
  local anchorPosition = {x=0,y=0}
  if anchorEntity then
    anchorPosition = anchorEntity.position
  end 
  
  local deploypos = {
    x = deployer.position.x + offsetpos.x - anchorPosition.x,
	 y = deployer.position.y + offsetpos.y - anchorPosition.y
	 }
    
  bp.build_blueprint{
    surface=deployer.surface,
    force=deployer.force,
    position=deploypos,
    force_build=true
  }  
end  

function onTickDeployer(deployer)
  local deployPrint = get_signal_value(deployer,{name="construction-robot",type="item"})
  local deconstructArea = get_signal_value(deployer,{name="deconstruction-planner",type="item"})
  local reportPrintNeeds = get_signal_value(deployer,{name="logistic-robot",type="item"})
  local X = get_signal_value(deployer,{name="signal-X",type="virtual"})
  local Y = get_signal_value(deployer,{name="signal-Y",type="virtual"})
  local W = get_signal_value(deployer,{name="signal-W",type="virtual"})
  local H = get_signal_value(deployer,{name="signal-H",type="virtual"})

  -- Check chest inventory for blueprint
  local deployerInventory = deployer.get_inventory(defines.inventory.chest)
  local deployerItemStack = deployerInventory[1]

  if not deployerItemStack.valid_for_read then
    return
  end

  
  if deployPrint > 0 then
    if deployerItemStack.name == "blueprint" then
      deployBlueprint(deployerItemStack,deployer,{x=X,y=Y})
    elseif deployerItemStack.name == "blueprint-book" then
      local bookInv = deployerItemStack.get_inventory(defines.inventory.item_main)
      if deployPrint > #bookInv then
        local bookActiveInv = deployerItemStack.get_inventory(defines.inventory.item_active)
        deployBlueprint(bookActiveInv[1],deployer,{x=X,y=Y})    
      else
        deployBlueprint(bookInv[deployPrint],deployer,{x=X,y=Y})
      end
    end
  elseif deconstructArea == -1 then
    deployer.surface.deconstruct_area{
	   area={
	     {deployer.position.x+X-(H/2),deployer.position.y+Y-(W/2)},
		  {deployer.position.x+X+(H/2),deployer.position.y+Y+(W/2)}
		  },
		force=deployer.force}
    deployer.cancel_deconstruction(deployer.force) -- Don't deconstruct myself in an area order
  elseif deconstructArea == -2 then
    deployer.order_deconstruction(deployer.force) -- Okay, you really meant it. Deconstruct myself.
  elseif reportPrintNeeds then
    --TODO: count up needed materials for this blueprint
  end
end

function onTick(event)
  if global.deployers then
    for _,deployer in pairs(global.deployers) do
  		if type(deployer)=="table" and deployer.valid and deployer.name == "blueprint-deployer" then
  		  onTickDeployer(deployer)
  		else
  		  global.deployers[_]=nil
  		  --game.players[1].print("removed deployer")
  		end
    end
  end
end

function onBuiltEntity(event)
  local ent = event.created_entity
  if not ent or not ent.valid or ent.name ~= "blueprint-deployer" then return end
  if not global.deployers then global.deployers={} end
  table.insert(global.deployers,ent)
  --game.players[1].print("built deployer")
end


function onInit()
  
end

function onLoad()
  
end

script.on_init(onInit)
script.on_load(onLoad)

script.on_event(defines.events.on_tick, onTick)
script.on_event(defines.events.on_built_entity, onBuiltEntity)
script.on_event(defines.events.on_robot_built_entity, onBuiltEntity)

