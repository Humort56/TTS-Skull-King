--[[ Lua code. See documentation: https://api.tabletopsimulator.com/ --]]

PLAYER_COLORS = {'Red','Green', 'Teal', 'Blue', 'White', 'Brown'}
SEATED_PLAYERS = {}
GAME_STARTED = false
FIRST_PLAYER = nil
CARD_POSITION = 1

--[[ The onLoad event is called after the game save finishes loading. --]]
function onLoad()
    MegaFreeze()
end

function MegaFreeze()
   local megaFreezeIT = {'9a3403'}
   --megaFreeze ACTIVATE!
   for i = 1, #megaFreezeIT, 1 do
      local obj = getObjectFromGUID(megaFreezeIT[i])
      if obj ~= nil then
         obj.interactable = false
         obj.tooltip = false
      end
   end
end

function GetObjectWithTag(tag)
   local objects = getObjectsWithTag(tag)

   return objects[1]
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

function GetFirstPlayer()
   return SEATED_PLAYERS[FIRST_PLAYER_INDEX]
end

function CardCreateButton()
   for _, pcolor in pairs(SEATED_PLAYERS) do
      local player = Player[pcolor]
      
      for _, card in pairs(player.getHandObjects()) do
         card.createButton({
            click_function = "PlayCard",
            color = {r=0, g=0, b=0, a=0},
            width = 1050,
            height = 1500
         })
      end
   end
end

function GroupCards()
   local zone = getObjectFromGUID("2b6f57")
   local objects = zone.getObjects()

   for _, card in pairs(objects) do
      card.setLock(false)
   end

   local deck = group(objects)[1]
end

function PlayCard(card, pcolor)
   local snapPoints = Global.getSnapPoints()
   local snapTrickCard = nil

   for _, snapPoint in pairs(snapPoints) do
      for _, tag in pairs(snapPoint.tags) do
         if tag == 'snapTrickCard' .. CARD_POSITION then
            snapTrickCard = snapPoint
         end
      end
   end

   if snapTrickCard == nil then
      return
   end

   CARD_POSITION = CARD_POSITION + 1

   card.clearButtons()

   card.setPositionSmooth(snapTrickCard.position, false, false)
   card.setRotationSmooth({x=snapTrickCard.rotation.x, y=snapTrickCard.rotation.y, z=0}, false, false)
   card.setLock(true)
end

function NextFirstPlayer()
   if FIRST_PLAYER_INDEX == #SEATED_PLAYERS then
      FIRST_PLAYER_INDEX = 1
   else
      FIRST_PLAYER_INDEX = FIRST_PLAYER_INDEX + 1
   end
end

function SetFirstPlayerToken()
   local tokenFirstPlayer = GetObjectWithTag('tokenFirstPlayer')

   if tokenFirstPlayer == nil then
      return
   end

   local snapPoints = Global.getSnapPoints()
   local firstPlayerSnap = nil

   for _, snapPoint in pairs(snapPoints) do
      for _, tag in pairs(snapPoint.tags) do
         if tag == 'snapFirstPlayer' .. GetFirstPlayer() then
            firstPlayerSnap = snapPoint
         end
      end
   end

   if firstPlayerSnap == nil then
      return
   end

   tokenFirstPlayer.setPosition(firstPlayerSnap.position)
   tokenFirstPlayer.setRotation(firstPlayerSnap.rotation)
end

function StartGame()
   for _, pcolor in pairs(PLAYER_COLORS) do
      if Player[pcolor].seated then
         table.insert(SEATED_PLAYERS, pcolor)
      else
         local counter = GetObjectWithTag('count' .. pcolor)

         if counter ~= nil then
            counter.destruct()

            for _, tile in pairs(getObjectsWithTag('t' .. pcolor)) do
               tile.destruct()
            end
         end
      end
   end

   FIRST_PLAYER_INDEX = math.random(#SEATED_PLAYERS)
   SetFirstPlayerToken()
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

          Wait.frames(function() CardCreateButton() end, 50)
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

function ResetDeck()
   CARD_POSITION = 1
   local objects = getAllObjects()

   for i = 1, #objects, 1 do
      local obj = objects[i]
      if(obj.name == 'Deck' or obj.name == 'Card') then
        if obj ~= nil then
          objects[i].setRotation({0, 180, 180})
          objects[i].setPosition({-45.00, 2.02, -3.00})
        end
     end
   end

   for _, tile in pairs(getObjectsWithTag('Tile')) do
     if not tile.is_face_down then
       tile.setLock(false)
       tile.clearButtons()
       tile.flip()
       Wait.frames(function() tile.setLock(true) end, 50)
     end
   end

   local round = GetRound()
   SetRound(round + 1)

   if GAME_STARTED then
      NextFirstPlayer()
      SetFirstPlayerToken()
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