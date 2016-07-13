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
    table.insert(global.digitizers,ent)
  end
end

return {
  [defines.events.on_tick]=onTickDigitizers,
  [defines.events.on_built_entity]=onBuiltDigitizer,
  [defines.events.on_robot_built_entity]=onBuiltDigitizer,
}