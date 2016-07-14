local craftscripts = {
  ["clone-blueprint"]={ -- Copy Active print to all other prints in book
    checkInput=function(inInv)
      return inInv[1].valid_for_read
    end,
    doCraft=function(inInv,outInv)
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
      
      inBook.count=0
    end
  },
  
  ["insert-blueprint"]={
    checkInput=function(inInv)
      return inInv[1].valid_for_read and inInv[2].valid_for_read
    end,
    doCraft=function(inInv,outInv)
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
      
      inBook.count=0
      inPrint.count=0
    end
  },

  ["extract-blueprint"]={
    checkInput=function(inInv)
      return inInv[1].valid_for_read
    end,
    doCraft=function(inInv,outInv)
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
        inBook.count=0
      end
    end
  },

}

CraftInverval = 20
CraftIncrement = 0.01

function onTickPrinter(printer)
  if game.tick > printer.nextprogress then return end
  
  printer.nextprogress = game.tick+CraftInverval
  if not printer.entity.recipe then
    printer.entity.crafting_progress = 0  
    return
  end
    
  local craftscript = craftscripts[printer.entity.recipe.name]
  if craftscript and craftscript.checkInput(printer.entity.get_inventory(defines.inventory.assembling_machine_input)) then
    printer.entity.crafting_progress = printer.entity.crafting_progress + CraftIncrement
  else 
    printer.entity.crafting_progress = 0
  end
  
  if printer.entity.crafting_progress >= 0.99 then
    printer.entity.crafting_progress = 0
    local inInv = printer.entity.get_inventory(defines.inventory.assembling_machine_input)
    local outInv = printer.entity.get_inventory(defines.inventory.assembling_machine_output)
    if craftscript and craftscript.doCraft then craftscript.doCraft(inInv,outInv) end
  end  
end

function onBuiltPrinter(event)
  local ent = event.created_entity
  if not ent or not ent.valid then return end
  if ent.name == "blueprint-printer" then 
    if not global.printers then global.printers={} end
    ent.active=false
    table.insert(global.printers,{entity=ent,nextprogress=game.tick+CraftInverval})
  end
end

local function onTickPrinters(event)
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

return {
  [defines.events.on_tick]=onTickPrinters,
  [defines.events.on_built_entity]=onBuiltPrinter,
  [defines.events.on_robot_built_entity]=onBuiltPrinter,
}