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


in  B: Request BoM
out B: Report BoM
in  S: Request stats
out S: Report stats: S=1 0=#entities, 1=#tiles, 2=#icons, blue=#wholeprint
in  I: Request icon: I=icon number
out I: Report icon: I=icon number, $iconsignal=1
in  T: Request tile: T=tile number
out T: Report tile: T=tile number, X,Y, $tilesignal=1
in  E: Request entity: E=entity number
out E: Report entities: E=enity number, X,Y,D=direction $entitysignal=1, R=hasrecipe, C=#connections, F=#filters?, modules as count, ???
in  C: Request entity-connections: C=entity number,0=connection number
out C: Report entity-connections: C=entity number,0=connection number,1=remote entity,2=remote connection port
in  R: Request recipe: R=entity number
out R: Report recipe: R=entity number,X,Y $inputs=1, $output=2 (if something is both, =3)
in  F: Request filters: F=entity number
out F: Report filters: F=entity number, signals=filters
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

local function readSignalsFromEntity(entity)
  
end

local function readPrint(digitizer,signals)
  --TODO: digitizertargets[digitizer.unit_number] = adjacent deployer
  --TODO: inStack = digitizertarget's stack, input stack for printer, inventory[1] for deployer
  global.digitizerprints[digitizer.unit_number]={
    tiles=inStack.get_blueprint_tiles(),
    entites=inStack.get_blueprint_entities(),
    icons=inStack.blueprint_icons,
    label=inStack.label,
  }
  inStack.count=0
end

local function writePrint(digitizer,signals)
  --TODO: Assemble a print in the output slot and
  local storedPrint = global.digitizerprints[digitizer.unit_number]
  
  --TODO: outStack = newly created print in target slot
  local outStack
  outStack.set_blueprint_entities(storedPrint.entities)
  outStack.set_blueprint_tiles(storedPrint.tiles)
  outStack.blueprint_icons = storedPrint.icons
  outStack.label = storedPrint.label 
end

local function bpTileFromSignals(digitizer,signals)
  if not global.digitizerprints[digitizer.unit_number] then return end
  local tiles = global.digitizerprints[digitizer.unit_number].tiles
  --tiles[T] = 
  --{
  --  position={x=X,y=Y},
  --  name=tilesignal, 
  --}
end

local function bpSignalsFromTile(digitizer,signals)
  if not global.digitizerprints[digitizer.unit_number] then return end
  local tiles = global.digitizerprints[digitizer.unit_number].tiles
  --TODO: output signal from tiles[T]: T=T, X=position.x, Y=position.y, tilesignal=1
end

local function bpEntityFromSignals(digitizer,signals)
  if not global.digitizerprints[digitizer.unit_number] then return end
  local entities = global.digitizerprints[digitizer.unit_number].entities
  --TODO: entities[E] = { position={x=X,y=Y},name=entitysignal,entity_number=E,direction=D,recipe,filters,etc... }
end

local function bpSignalsFromEntity(digitizer,signals)
  if not global.digitizerprints[digitizer.unit_number] then return end
  local entities = global.digitizerprints[digitizer.unit_number].entities
  --TODO: signal the entity
end

local function bpConnectionFromSignals(digitizer,signals)
  if not global.digitizerprints[digitizer.unit_number] then return end
  local entities = global.digitizerprints[digitizer.unit_number].entities
  --TODO: entities[E].connections[?] = {?}
end

local function bpSignalsFromConnection(digitizer,signals)
  if not global.digitizerscripts[digitizer.unit_number] then return end
  local entities = global.digitizerprints[digitizer.unit_number].entities
end





local function onTickDigitizer(digitizer)
  -- Check chest inventory for blueprint
  local digitizerInventory = digitizer.get_inventory(defines.inventory.chest)
  local digitizerItemStack = digitizerInventory[1]
  if not digitizerItemStack.valid_for_read then
    --TODO: clear all output signals
    return
  end
  
  --TODO: ?: report all print item needs
  
  --TODO: ?: report print stats: #entities, #tiles, #icons
  --
  --TODO: I: report icons: I=icon number, iconsignal=1
  --TODO: T: report tiles: T=tile number, X,Y=position, tilesignal=1
  --TODO: E: report entities: E=tile number, X,Y=position, entitysignal=1, R=hasrecipe, C=#connections, F=#filters, modules as count, ???
  --TODO: C: report entity connections E=tile number, X,Y=position, C=connection number, R=remote entity,W=remote connection port
  --TODO: R: report recipe: E,X,Y as entity, recipe inputs=1, output=2 (if something is both, =3)
  --TODO: ?: report control behavior settings (type specific)
  --TODO: 
  
end



local function onTickDigitizers(event)
  if global.digitizers then
    for _,digitizer in pairs(global.digitizers) do
  		if digitizer.valid and digitizer.name == "blueprint-digitizer" then
  		  digitizerscripts.onTick(digitizer)
  		else
  		  global.digitizers[_]=nil
  		end
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
    table.insert(global.digitizers,ent)
  end
end

return {
  [defines.events.on_tick]=onTickDigitizers,
  [defines.events.on_built_entity]=onBuiltDigitizer,
  [defines.events.on_robot_built_entity]=onBuiltDigitizer,
}