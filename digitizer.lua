--[[

Commands 

Reading a print leaves it in the inventory
in  signal-blue: =1 Read print
out signal-blue: =1 successfully read, loaded print for editing 
out signal-blue: =-1 read failed

Writing a print replaces the input print with the stored data
in  signal-blue: =2 Write print
out signal-blue: =2 print written 
out signal-blue: =-2 write failed (still in buffer)

Writing to a print
in  signal-blue: =4 Write content (combine with Report message / gets no response on success)
out signal-blue: =-4 write failed


in  blueprint: reserved by deployer (ignore)
in  blueprint-book: reserved by deployer (ignore)
in  construction-robot: reserved by deployer (abort)
in  deconstruction-planner: reserved by deployer (abort)

in  ?: Request BoM
out ?: Report BoM
in  3: Request stats
out 3: Report stats: S=1 0=#entities, 1=#tiles, 2=#icons, blue=#wholeprint
in  4: Request icon: I=icon number
out 4: Report icon: I=icon number, $iconsignal=1
in  5: Request tile: T=tile number
out 5: Report tile: T=tile number, X,Y, $tilesignal=1
in  6: Request entity: E=entity number
out 6: Report entities: E=enity number, X,Y,D=direction $entitysignal=1, R=hasrecipe, C=#connections, F=#filters?, modules as count, ???

in  ?: Request entity-connections: C=entity number,0=connection number
out ?: Report entity-connections: C=entity number,0=connection number,1=remote entity,2=remote connection port
in  ?: Request recipe: R=entity number
out ?: Report recipe: R=entity number,X,Y $inputs=1, $output=2 (if something is both, =3)
in  ?: Request filters: F=entity number
out ?: Report filters: F=entity number, signals=filters
in  ?: Request control behaviror: ?=entity number
out ?: Report control behavior: ?= entity number, $type=1,type-specific data.
in  ?: Request label: ?=character number
out ?: Report label: ?=character number,letter=1

print total size as serialized dump:
    1 stats
  0-4 icons
    n label
    n tiles
    n entities
    n recipies
    n filters
    n control behaviors
    n wire connections 
--]]


local function readPrint(digitizer,deployer)
  local inStack = deployer.get_inventory(defines.inventory.chest)[1]
  if not inStack or not inStack.valid then
    return false
  end 
  global.digitizerprints[digitizer.unit_number]={
    tiles=inStack.get_blueprint_tiles(),
    entities=inStack.get_blueprint_entities(),
    icons=inStack.blueprint_icons,
    label=inStack.label,
  }
  --inStack.count=0
  return true
end

local function writePrint(digitizer,deployer,index)
  local storedPrint = global.digitizerprints[digitizer.unit_number]
  
  local outInv = deployer.get_inventory(defines.inventory.chest)
  if not outInv[1] or outInv[1].name ~= "blueprint" then 
    return false
  end 
  local outStack = outInv[1]
  outStack.set_blueprint_entities(storedPrint.entities)
  outStack.set_blueprint_tiles(storedPrint.tiles)
  outStack.blueprint_icons = storedPrint.icons
  outStack.label = storedPrint.label or ""
  return true
end

local commandsig = {name="signal-blue",type="virtual"}

local function onTickDigitizerDeployer(digitizer,deployer)
  
  local txSignals = {}
  
  local command = get_signal_value(deployer,commandsig)
  
  if get_signal_value(deployer,{name="construction-robot",type="item"}) ~= 0 or 
    get_signal_value(deployer,{name="deconstruction-planner",type="item"}) ~= 0 then
    return -- commands reserved by the deployer itself
  end
      
  if command == 1 then -- Read print from item
    if readPrint(digitizer,deployer) then
      txSignals[#txSignals+1]={index=#txSignals+1,count=1,signal=commandsig} 
    else 
      txSignals[#txSignals+1]={index=#txSignals+1,count=-1,signal=commandsig}
    end
    
--[[
  elseif command == ??? then -- Write print to item
    game.players[1].print("writing print")
    if writePrint(digitizer,deployer) then
      txSignals[#txSignals+1]={index=#txSignals+1,count=???,signal=commandsig} 
    else 
      txSignals[#txSignals+1]={index=#txSignals+1,count=-???,signal=commandsig}
    end
  ]]
  
  elseif command == 2 then -- Get print BoM
    txSignals[#txSignals+1]={index=#txSignals+1,count=2,signal=commandsig}
    local bp = global.digitizerprints[digitizer.unit_number]
    if bp then
      local items={} 
      
      for _,t in pairs(bp.tiles) do
        for k,_ in pairs(game.tile_prototypes[t.name].items_to_place_this) do 
          items[k]=(items[k] or 0)+1            
        end  
      end
      
      for _,e in pairs(bp.entities) do
        for k,_ in pairs(game.entity_prototypes[e.name].items_to_place_this) do 
          items[k]=(items[k] or 0)+1            
        end
      end
      
      for k,v in pairs(items) do 
        txSignals[#txSignals+1]={index=#txSignals+1,count=v,signal={name=k,type="item"}}
      end
    end
    
  elseif command == 3 then -- Get print stats
    --print stats: E=#entities, T=#tiles, I=#icons, L=#label
    local bp = global.digitizerprints[digitizer.unit_number]
    txSignals[#txSignals+1]={index=#txSignals+1,count=3,signal=commandsig}
    if bp then
      txSignals[#txSignals+1]={index=#txSignals+1,count=#bp.entities,signal={name="signal-E",type="virtual"}}
      txSignals[#txSignals+1]={index=#txSignals+1,count=#bp.tiles,signal={name="signal-T",type="virtual"}}
      txSignals[#txSignals+1]={index=#txSignals+1,count=#bp.icons,signal={name="signal-I",type="virtual"}}
      txSignals[#txSignals+1]={index=#txSignals+1,count=(bp.label and #bp.label) or 0,signal={name="signal-L",type="virtual"}}
    end
    
  elseif command == 4 then -- Get print icons
    --icons: I=icon number, iconsignal=1
    local sigI = get_signal_value(deployer,{name="signal-I",type="virtual"})
    txSignals[#txSignals+1]={index=#txSignals+1,count=4,signal=commandsig}
    txSignals[#txSignals+1]={index=#txSignals+1,count=sigI,signal={name="signal-I",type="virtual"}}
    if bp then txSignals[#txSignals+1]={index=#txSignals+1,count=1,signal=bp.icons[sigI].signal} end
    
  elseif command == 5 then -- Get print tiles
    --tiles: T=tile number, X,Y=position, tilesignal=1
    local sigT = get_signal_value(deployer,{name="signal-T",type="virtual"})
    txSignals[#txSignals+1]={index=#txSignals+1,count=5,signal=commandsig}
    txSignals[#txSignals+1]={index=#txSignals+1,count=sigT,signal={name="signal-T",type="virtual"}}
    for k,_ in pairs(game.tile_prototypes[bp.tiles[sigT].name].items_to_place_this) do 
      txSignals[#txSignals+1]={index=#txSignals+1,count=1,signal={name=k,type="item"}}
    end
    txSignals[#txSignals+1]={index=#txSignals+1,count=bp.tiles[sigT].position.x,signal={name="signal-X",type="virtual"}}
    txSignals[#txSignals+1]={index=#txSignals+1,count=bp.tiles[sigT].position.y,signal={name="signal-Y",type="virtual"}}
    
  elseif command == 6 then -- Get print entities
    --entities: E=tile number, X,Y=position, entitysignal=1, R=hasrecipe, C=#connections, F=#filters, modules as count, ???
    local sigE = get_signal_value(deployer,{name="signal-E",type="virtual"})
    txSignals[#txSignals+1]={index=#txSignals+1,count=1,signal={name="signal-E",type="virtual"}}
    for k,_ in pairs(game.entity_prototypes[bp.entities[sigE].name].items_to_place_this) do 
      txSignals[#txSignals+1]={index=#txSignals+1,count=1,signal={name=k,type="item"}}
    end
    txSignals[#txSignals+1]={index=#txSignals+1,count=bp.entities[sigE].position.x,signal={name="signal-X",type="virtual"}}
    txSignals[#txSignals+1]={index=#txSignals+1,count=bp.entities[sigE].position.y,signal={name="signal-Y",type="virtual"}}
    txSignals[#txSignals+1]={index=#txSignals+1,count=bp.entities[sigE].direction, signal={name="signal-D",type="virtual"}}
    --TODO: other entity-specific? or dedicated messages?
  end
  
  digitizer.get_or_create_control_behavior().parameters={parameters = txSignals}
end


local function onTickDigitizer(digitizer)
  local pairedEnt = global.digitizertargets[digitizer.unit_number]
  if not pairedEnt.valid then
    --TODO: unpair
  end
  if pairedEnt.name == "blueprint-deployer" then
    onTickDigitizerDeployer(digitizer,pairedEnt)
  --elseif pairedEnt.name == "blueprint-printer" then
    --TODO: more specific blueprint page manipulation?
  --elseif pairedEnt.name == "??radar??" then
    --TODO: radar data?
  --elseif pairedEnt.name == "???" then
    --TODO: ???
  end
end

local function onTickDigitizers(event)
  if global.digitizers then
    for id,digitizer in pairs(global.digitizers) do
  		if digitizer.valid and digitizer.name == "blueprint-digitizer" then
  		  onTickDigitizer(digitizer)
  		else
  		  global.digitizers[id]=nil
  		end
    end
  end
end



function getConnectedEntity(ent)
	local connectedEntities = ent.surface.find_entities({{x = ent.position.x - 1, y = ent.position.y - 1}, {x = ent.position.x + 1, y = ent.position.y + 1}})
	for _,entity in pairs(connectedEntities) do
		if (entity.valid and (entity.name == "blueprint-deployer")) then
			return entity
		end
	end
end

local function onBuiltDigitizer(event)
  local ent = event.created_entity
  if not ent or not ent.valid then return end
  if ent.name == "blueprint-digitizer" then 
    if not global.digitizers then global.digitizers={} end
    if not global.digitizerprints then global.digitizerprints={} end
    if not global.digitizertargets then global.digitizertargets={} end
    
    ent.operable = false
    table.insert(global.digitizers,ent)
    
	 global.digitizertargets[ent.unit_number]=getConnectedEntity(ent)
    global.digitizerprints[ent.unit_number]=nil
    
  end
  
end

return {
  [defines.events.on_tick]=onTickDigitizers,
  [defines.events.on_built_entity]=onBuiltDigitizer,
  [defines.events.on_robot_built_entity]=onBuiltDigitizer,
}