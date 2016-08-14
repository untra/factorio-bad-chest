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

function copyBlueprint(inStack,outStack)
  if not inStack.is_blueprint_setup() then return end
  outStack.set_blueprint_entities(inStack.get_blueprint_entities())
  outStack.set_blueprint_tiles(inStack.get_blueprint_tiles())
  outStack.blueprint_icons = inStack.blueprint_icons
  if inStack.label then outStack.label = inStack.label end
end

function charsig(c)
	local charmap={
		["A"]='signal-A',["B"]='signal-B',["C"]='signal-C',["D"]='signal-D',["E"]='signal-E',
		["F"]='signal-F',["G"]='signal-G',["H"]='signal-H',["I"]='signal-I',["J"]='signal-J',
		["K"]='signal-K',["L"]='signal-L',["M"]='signal-M',["N"]='signal-N',["O"]='signal-O',
		["P"]='signal-P',["Q"]='signal-Q',["R"]='signal-R',["S"]='signal-S',["T"]='signal-T',
		["U"]='signal-U',["V"]='signal-V',["W"]='signal-W',["X"]='signal-X',["Y"]='signal-Y',
		["Z"]='signal-Z'
	}
	if charmap[c] then
		return charmap[c]
	else
		return 'signal-blue'
	end
end


local scripts=
{
printer = require("printer"),
deployer = require("deployer"),
digitizer = require("digitizer"),
}

local function onEvent(event)
  for _,s in pairs(scripts) do
    if s[event.name] then
      s[event.name](event)
    end
  end
end

script.on_event(defines.events.on_tick, onEvent)
script.on_event(defines.events.on_built_entity, onEvent)
script.on_event(defines.events.on_robot_built_entity, onEvent)
