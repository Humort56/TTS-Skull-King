--[[ Lua code. See documentation: https://api.tabletopsimulator.com/ --]]

PLAYER_COLORS = {'Red','Green', 'Teal', 'Blue', 'White', 'Brown'}
GAME_STARTED = false

--[[ The onLoad event is called after the game save finishes loading. --]]
function onLoad()
    megaFreeze()
end

function megaFreeze()
   local megaFreezeIT = {'9a3403'}
   --megaFreeze ACTIVATE!
   for i = 1, #megaFreezeIT, 1 do
      obj = getObjectFromGUID(megaFreezeIT[i])
      if obj ~= nil then
         obj.interactable = false
         obj.tooltip = false
      end
   end
end

function GetRound()
   local objects = getObjectsWithTag("RoundCounter")
   local roundCounter = objects[1]
   local value = roundCounter.getValue()

   return tonumber(value)
end

function SetRound(value)
   local objects = getObjectsWithTag("RoundCounter")
   local roundCounter = objects[1]

   roundCounter.setValue(tonumber(value))
end

function StartGame()
   for _, pcolor in pairs(PLAYER_COLORS) do
      if not Player[pcolor].seated then
         local objects = getObjectsWithTag('count' .. pcolor)
         objects[1].destruct()

         for _, object in pairs(getObjectsWithTag('t' .. pcolor)) do
            object.destruct()
         end
      end
   end
end

function DealCards()
   if not GAME_STARTED then
      GAME_STARTED = true
      StartGame()
   end

   local round = GetRound()
   local objects = getAllObjects()
   for i = 1, #objects, 1 do
      local obj = objects[i]
      if(obj.name == 'Deck') then
        if obj ~= nil then
          obj.shuffle()
          obj.deal(round)
        end
     end
   end

   -- showing the tile
   for _, tile in pairs(getObjectsWithTag("Tile")) do
     if tile.is_face_down and tonumber(tile.getGMNotes()) <= round then
        tile.setLock(false)
        tile.flip()
        Wait.frames(
           function()
              TileCreateButton(tile, "ChooseBet")
              tile.setLock(true) 
           end,
           40
        )
     end
   end
end

function TileCreateButton(tile, functionName)
   tile.createButton({
      click_function = functionName,
      width = 1000,
      height = 1000
   })
end

function ChooseBet(tile, pcolor)
   local ptile = 't' .. pcolor

   if not tile.hasTag(ptile) then
      broadcastToColor("You can't click the tile of another player.", pcolor, Color.fromString("Red"))
      return
   end

   local stringValue = tile.getGMNotes()

   tile.clearButtons()

   for _, tileToFlip in pairs(getObjectsWithTag(ptile)) do
      if not tileToFlip.is_face_down and tileToFlip.getGMNotes() ~= stringValue then
         tileToFlip.setLock(false)
         tileToFlip.clearButtons()
         tileToFlip.flip()
         Wait.frames(function() tileToFlip.setLock(true) end, 40)
      end
   end

   Wait.frames(function() TileCreateButton(tile, "CancelBet") end, 40)

   -- need to use stringValue
end

function CancelBet(tile, pcolor, alt)
   local ptile = 't' .. pcolor

   if not tile.hasTag(ptile) then
      broadcastToColor("You can't click the tile of another player.", pcolor, Color.fromString("Red"))
      return
   end

   tile.clearButtons()

   local round = GetRound()

   for _, tile in pairs(getObjectsWithTag(ptile)) do
      if tonumber(tile.getGMNotes()) <= round then
         if tile.is_face_down then
            tile.setLock(false)
            tile.flip()
         end
         
         Wait.frames(
            function()
               TileCreateButton(tile, "ChooseBet")
               tile.setLock(true) 
            end,
            40
         )
      end
    end
end

--[[ The onUpdate event is called once per frame. --]]
function onUpdate()
    --[[ print('onUpdate loop!') --]]
end