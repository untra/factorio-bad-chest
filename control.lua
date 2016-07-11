local CraftInverval = 20
local CraftIncrement = 0.01


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

function findEntityInBlueprint(bp,entityName)
  local bpEntities = bp.get_blueprint_entities()
  local e = nil
  for _,bpEntity in pairs(bpEntities) do
    if bpEntity.name == entityName then
      e = bpEntity
      break
    end
  end
  return(e)
end


function deployBlueprint(bp,deployer,offsetpos)
  if not bp then return end
  if not bp.valid_for_read then return end
  if not bp.is_blueprint_setup() then return end
  local bpEntities = bp.get_blueprint_entities()
  local anchorEntity = nil
  anchorEntity = findEntityInBlueprint(bp,"wooden-chest")
  if not anchorEntity then 
    anchorEntity = findEntityInBlueprint(bp,"blueprint-deployer")
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
    --TODO: count up needed materials for this blueprint
  end
end

function copyBlueprint(inStack,outStack)
  if not inStack.is_blueprint_setup() then return end
  outStack.set_blueprint_entities(inStack.get_blueprint_entities())
  outStack.set_blueprint_tiles(inStack.get_blueprint_tiles())
  outStack.blueprint_icons = inStack.blueprint_icons
end

function onTickPrinter(printer)
  if game.tick > printer.nextprogress then return end
  
  printer.nextprogress = game.tick+CraftInverval
  if not printer.entity.recipe then  
    return
  else
    if printer.entity.get_inventory(defines.inventory.assembling_machine_input)[1].valid_for_read then 
      printer.entity.crafting_progress = printer.entity.crafting_progress + CraftIncrement
    else 
      printer.entity.crafting_progress = 0
    end 
  end
  
  if printer.entity.crafting_progress >= 0.99 then
    printer.entity.crafting_progress = 0
    local inInv = printer.entity.get_inventory(defines.inventory.assembling_machine_input)
    local outInv = printer.entity.get_inventory(defines.inventory.assembling_machine_output)  
    if printer.entity.recipe.name == "clone-blueprint" then
      -- Copy Active print to all other prints in book
      if not inInv[1].valid_for_read then return end
      local inBook=inInv[1]
      local inBookActive = inBook.get_inventory(defines.inventory.item_active)
      local inBookMain = inBook.get_inventory(defines.inventory.item_main)
      
      if not inBookActive[1].valid_for_read then return end
      local inPrint = inBookActive[1]
      local inCopies = inBookMain.get_item_count("blueprint")
            
      if outInv[1].valid_for_read then return end -- previous output not taken away!
      outInv.insert{name="blueprint-book",count=1}
      local outBook = outInv[1]
      local outBookActive = outBook.get_inventory(defines.inventory.item_active)
      local outBookMain = outBook.get_inventory(defines.inventory.item_main)
      
      outBookActive.insert{name="blueprint",count=1}
      copyBlueprint(inPrint,outBookActive[1])
      outBookMain.insert{name="blueprint",count=inCopies}
      for i=1, inCopies,1 do
        if outBookMain[i].valid_for_read then
          copyBlueprint(inPrint,outBookMain[i])
        end
      end
      
      inInv.remove{name="blueprint-book",count=1}      
    elseif printer.entity.recipe.name == "insert-blueprint" then
      --Copy book to new book (prints are defragmented to the front of the book). 
      --Insert additional print in first available slot (active, then main) 
      --If book is already completely full, will overwrite Active print. (Useful for preparing to Clone)
      if not inInv[1].valid_for_read or not inInv[2].valid_for_read then return end
      if outInv[1].valid_for_read then return end -- previous output not taken away!
      
      local inBook=inInv[1]
      local inBookActive = inBook.get_inventory(defines.inventory.item_active)
      local inBookMain = inBook.get_inventory(defines.inventory.item_main)
      local inCount = inBookMain.get_item_count("blueprint")
      local inPrint = inInv[2]
      
      outInv.insert{name="blueprint-book",count=1}
      local outBook = outInv[1]
      local outBookActive = outBook.get_inventory(defines.inventory.item_active)
      local outBookMain = outBook.get_inventory(defines.inventory.item_main)
      
      local j = 1
      for i=1,#inBookMain,1 do
        if inBookMain[i].valid_for_read then
          outBookMain.insert{name="blueprint",count=1}
          copyBlueprint(inBookMain[i],outBookMain[j])
          j=j+1
        end
      end
    
      outBookActive.insert{name="blueprint",count=1}
      if outBookMain.get_item_count("blueprint") < #outBookMain then
        if inBookActive[1].valid_for_read then
          outBookMain.insert{name="blueprint",count=1}
          copyBlueprint(inPrint,outBookMain[j])
          copyBlueprint(inBookActive[1],outBookActive[1])
        else
          copyBlueprint(inPrint,outBookActive[1])
        end 
      else
        copyBlueprint(inPrint,outBookActive[1])
      end
      
      inInv.remove{name="blueprint-book",count=1}
      inInv.remove{name="blueprint",count=1}
    elseif printer.entity.recipe.name == "extract-blueprint" then
      --Remove first print from book and move to output. Active then Main print first. 
      --If book is empty, consume book
      if not inInv[1].valid_for_read then return end
      if outInv[1].valid_for_read then return end
      
      local inBook=inInv[1]
      local inBookActive = inBook.get_inventory(defines.inventory.item_active)
      local inBookMain = inBook.get_inventory(defines.inventory.item_main)
      
      if inBookActive[1].valid_for_read then
        outInv.insert{name="blueprint",count=1}
        local outPrint = outInv[1]
        copyBlueprint(inBookActive[1],outPrint)
        inBookActive.remove{name="blueprint",count=1}
      elseif inBookMain.get_item_count("blueprint") > 0 then
        outInv.insert{name="blueprint",count=1}
        local outPrint = outInv[1]
        i=0
        repeat i=i+1 until inBookMain[i].valid_for_read 
        copyBlueprint(inBookMain[i],outPrint)
        inBookMain.remove{name="blueprint",count=1}        
      else
        inInv.remove{name="blueprint-book",count=1}
      end      
    end
  end
end

function onTick(event)
  if global.deployers then
    for _,deployer in pairs(global.deployers) do
  		if deployer.valid and deployer.name == "blueprint-deployer" then
  		  onTickDeployer(deployer)
  		else
  		  global.deployers[_]=nil
  		end
    end
  end
  if global.printers then
    for _,printer in pairs(global.printers) do
  		if not printer.name and printer["entity"] and printer.entity.valid and printer.entity.name == "blueprint-printer" then
  		  onTickPrinter(printer)
  		else
  		  global.printers[_]=nil
  		end
    end
  end
end

function onBuiltEntity(event)
  local ent = event.created_entity
  if not ent or not ent.valid then return end
  if ent.name == "blueprint-deployer" then 
    if not global.deployers then global.deployers={} end
    table.insert(global.deployers,ent)
  end
  
  if ent.name == "blueprint-printer" then 
    if not global.printers then global.printers={} end
    ent.active=false
    table.insert(global.printers,{entity=ent,nextprogress=game.tick+CraftInverval})
  end
  
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

