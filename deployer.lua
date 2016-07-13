local function onTickDeployer(deployer)
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
  elseif deconstructArea == -1 then -- decon=-1 Deconstruct Area
    deployer.surface.deconstruct_area{
	   area={
	     {deployer.position.x+X-(H/2),deployer.position.y+Y-(W/2)},
		  {deployer.position.x+X+(H/2),deployer.position.y+Y+(W/2)}
		  },
		force=deployer.force}
    deployer.cancel_deconstruction(deployer.force) -- Don't deconstruct myself in an area order
  elseif deconstructArea == -2 then -- decon=-2 Deconstruct Self
    deployer.order_deconstruction(deployer.force)
  elseif deconstructArea == 1 then -- decon=1 Cancel Area
    deployer.surface.cancel_deconstruct_area{
	   area={
	     {deployer.position.x+X-(H/2),deployer.position.y+Y-(W/2)},
		  {deployer.position.x+X+(H/2),deployer.position.y+Y+(W/2)}
		  },
		force=deployer.force}
  elseif reportPrintNeeds then
    --TODO: count up needed materials for this blueprint (api!)
    --TODO: output needs for ghosts in area
  end
end

local function onTickDeployers(event)
  if global.deployers then
    for _,deployer in pairs(global.deployers) do
  		if deployer.valid and deployer.name == "blueprint-deployer" then
  		  deployerscripts.onTick(deployer)
  		else
  		  global.deployers[_]=nil
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

return {
  [defines.events.on_tick]=onTickDeployers,
  [defines.events.on_built_entity]=onBuiltDeployer,
  [defines.events.on_robot_built_entity]=onBuiltDeployer,
}