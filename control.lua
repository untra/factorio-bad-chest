local crc32 = require('crc32')

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
	if signal == nil or signal.name == nil then return(0)	end
  local ent_cache = update_net_cache(ent)

  local signal_val = 0

	if ent_cache.red_network then
	  signal_val = signal_val + ent_cache.red_network.get_signal(signal)
	end

  if ent_cache.green_network then
    signal_val = signal_val + ent_cache.green_network.get_signal(signal)
  end

  return signal_val;
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
    ["0"]='signal-0',["1"]='signal-1',["2"]='signal-2',["3"]='signal-3',["4"]='signal-4',
    ["5"]='signal-5',["6"]='signal-6',["7"]='signal-7',["8"]='signal-8',["9"]='signal-9',
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
		return nil
	end
end

function sigchar(c)
	local charmap={
    ['signal-0']='0',['signal-1']='1',['signal-2']='2',['signal-3']='3',['signal-4']='4',
    ['signal-5']='5',['signal-6']='6',['signal-7']='7',['signal-8']='8',['signal-9']='9',
    ['signal-A']='A',['signal-B']='B',['signal-C']='C',['signal-D']='D',
    ['signal-E']='E',['signal-F']='F',['signal-G']='G',['signal-H']='H',
    ['signal-I']='I',['signal-J']='J',['signal-K']='K',['signal-L']='L',
    ['signal-M']='M',['signal-N']='N',['signal-O']='O',['signal-P']='P',
    ['signal-Q']='Q',['signal-R']='R',['signal-S']='S',['signal-T']='T',
    ['signal-U']='U',['signal-V']='V',['signal-W']='W',['signal-X']='X',
    ['signal-Y']='Y',['signal-Z']='Z',

    ['signal-blue']='',
    ['signal-white']='',

	}
	if charmap[c] then
		return charmap[c]
	else
		return ' '
	end
end


local function recipe_id(recipe)
  local id = crc32.Hash(recipe)
  if id > 2147483647 then
    id = id - 4294967295
  end
  return id
end

local function reindex_recipes()
  local recipemap={}

  for recipe,_ in pairs(game.forces['player'].recipes) do
    local id = recipe_id(recipe)
    recipemap[recipe] = id
    recipemap[id] = recipe
  end

  game.write_file('recipemap.txt',serpent.block(recipemap,{comment=false}))
  global.recipemap = recipemap
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


script.on_init(function()
  -- Index recipes for new install
  reindex_recipes()
end
)

script.on_configuration_changed(function(data)
  -- when any mods change, reindex recipes
  reindex_recipes()
end
)
