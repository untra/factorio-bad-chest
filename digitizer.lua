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
  local printStack = deployer.get_inventory(defines.inventory.chest)[1]
  if not printStack or not printStack.valid_for_read or not printStack.name == "blueprint" then
    return
  end

  local txSignals = {}

  local command = get_signal_value(deployer,commandsig)
  local write = get_signal_value(deployer,{name="signal-white",type="virtual"})

  if command == 0 then return end

  if get_signal_value(deployer,{name="construction-robot",type="item"}) ~= 0 or
    get_signal_value(deployer,{name="deconstruction-planner",type="item"}) ~= 0 then
    return -- commands reserved by the deployer itself
  end

  if command == 2 then -- Get print BoM
    txSignals[#txSignals+1]={index=#txSignals+1,count=command,signal=commandsig}
    for k,v in pairs(printStack.cost_to_build) do
      txSignals[#txSignals+1]={index=#txSignals+1,count=v,signal={name=k,type="item"}}
    end
  elseif command == 3 then -- Get print stats
    --print stats: E=#entities, T=#tiles, I=#icons, L=#label
    txSignals[#txSignals+1]={index=#txSignals+1,count=command,signal=commandsig}

    local e = printStack.get_blueprint_entities() or {}
    local t = printStack.get_blueprint_tiles() or {}
    local i = printStack.blueprint_icons or {}
    local l = printStack.label or ""
    txSignals[#txSignals+1]={index=#txSignals+1,count=#e,signal={name="signal-E",type="virtual"}}
    txSignals[#txSignals+1]={index=#txSignals+1,count=#t,signal={name="signal-T",type="virtual"}}
    txSignals[#txSignals+1]={index=#txSignals+1,count=#i,signal={name="signal-I",type="virtual"}}
    txSignals[#txSignals+1]={index=#txSignals+1,count=#l,signal={name="signal-L",type="virtual"}}

  elseif command == 4 then -- Get print icons
    --icons: I=icon number, iconsignal=1
    local sigI = get_signal_value(deployer,{name="signal-I",type="virtual"})
    local i = printStack.blueprint_icons
    if write == 1 and sigI.count>0 and sigI.count<5 then
      local deplNet=deployer.get_circuit_network(defines.wire_type.red)
                 or deployer.get_circuit_network(defines.wire_type.green)
      local signals=deplNet.signals
      if #signals == 4 then
        i[sigI.count] = {index=sigI.count,signal={}}
      end
    else
      txSignals[#txSignals+1]={index=#txSignals+1,count=command,signal=commandsig}
      txSignals[#txSignals+1]={index=#txSignals+1,count=sigI,signal={name="signal-I",type="virtual"}}
      if i[sigI] then txSignals[#txSignals+1]={index=#txSignals+1,count=1,signal=i[sigI].signal} end
    end
  elseif command == 5 then -- Get print tiles
    local t = printStack.get_blueprint_tiles()
    --tiles: T=tile number, X,Y=position, tilesignal=1
    local sigT = get_signal_value(deployer,{name="signal-T",type="virtual"})
    txSignals[#txSignals+1]={index=#txSignals+1,count=command,signal=commandsig}
    txSignals[#txSignals+1]={index=#txSignals+1,count=sigT,signal={name="signal-T",type="virtual"}}
    for k,_ in pairs(game.tile_prototypes[t[sigT].name].items_to_place_this) do
      txSignals[#txSignals+1]={index=#txSignals+1,count=1,signal={name=k,type="item"}}
    end
    txSignals[#txSignals+1]={index=#txSignals+1,count=t[sigT].position.x,signal={name="signal-X",type="virtual"}}
    txSignals[#txSignals+1]={index=#txSignals+1,count=t[sigT].position.y,signal={name="signal-Y",type="virtual"}}

  elseif command == 6 then -- Get print entities
    local e = printStack.get_blueprint_entities()
    --entities: E=tile number, X,Y=position, entitysignal=1, R=hasrecipe, C=#connections, F=#filters, modules as count, ???
    local sigE = get_signal_value(deployer,{name="signal-E",type="virtual"})
    txSignals[#txSignals+1]={index=#txSignals+1,count=1,signal={name="signal-E",type="virtual"}}
    for k,_ in pairs(game.entity_prototypes[e[sigE].name].items_to_place_this) do
      txSignals[#txSignals+1]={index=#txSignals+1,count=1,signal={name=k,type="item"}}
    end
    txSignals[#txSignals+1]={index=#txSignals+1,count=e[sigE].position.x,signal={name="signal-X",type="virtual"}}
    txSignals[#txSignals+1]={index=#txSignals+1,count=e[sigE].position.y,signal={name="signal-Y",type="virtual"}}
    txSignals[#txSignals+1]={index=#txSignals+1,count=e[sigE].direction, signal={name="signal-D",type="virtual"}}
    --TODO: other entity-specific? or dedicated messages?
  elseif command == 7 then -- Get Print Name, binary encoded, LSB leftmost
    if write == 1 then
      local deplNet=deployer.get_circuit_network(defines.wire_type.red)
                 or deployer.get_circuit_network(defines.wire_type.green)
      local signals=deplNet.signals
      local str=""
      for i=0,30 do
        local endOfString=true
        for _,sig in pairs(signals) do
          local sigbit = bit32.extract(sig.count,i)
          if sig.signal.type=="virtual" and sigbit==1 then
            endOfString=false
            str=str .. sigchar(sig.signal.name)
          end
        end

        if endOfString then break end
      end
      printStack.label=str
    else
      local s = string.upper(printStack.label or "")
      local letters = {}
      local i=1
      while s do
        local c
        if #s > 1 then
          c,s=s:sub(1,1),s:sub(2)
        else
          c,s=s,nil
        end
        letters[c]=(letters[c] or 0)+i
        i=i*2
      end

      for c,i in pairs(letters) do
        txSignals[#txSignals+1]={index=#txSignals+1,count=i,signal={name=charsig(c),type="virtual"}}
      end
    end
  end

  digitizer.get_or_create_control_behavior().parameters={parameters = txSignals}
end


local function onTickDigitizer(digitizer)
  local pairedEnt = global.digitizertargets[digitizer.unit_number]
  if not (pairedEnt and pairedEnt.valid) then
    global.digitizertargets[digitizer.unit_number] = nil
    digitizer.get_or_create_control_behavior().parameters=nil
    return
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
