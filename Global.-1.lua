--[[ Lua code. See documentation: https://api.tabletopsimulator.com/ --]]

PLAYER_COLORS = {'Red','Green', 'Teal', 'Blue', 'White', 'Brown'}
SEATED_PLAYERS = {}
PLAYERS_BET = {}
GAME_STARTED = false
FIRST_PLAYER_INDEX = nil
CURRENT_BETTOR_INDEX = nil
CARD_POSITION = 1


function onSave()
   local saved_data = JSON.encode({
      GAME_STARTED=GAME_STARTED,
      SEATED_PLAYERS=SEATED_PLAYERS,
      FIRST_PLAYER_INDEX=FIRST_PLAYER_INDEX,
      CARD_POSITION=CARD_POSITION,
      PLAYERS_BET=PLAYERS_BET,
      CURRENT_BETTOR_INDEX=CURRENT_BETTOR_INDEX
   })
   return saved_data
end

--[[ The onLoad event is called after the game save finishes loading. --]]
function onLoad(saved_data)
   MegaFreeze()

   if saved_data ~= '' then
      local loaded_data = JSON.decode(saved_data)
      GAME_STARTED = loaded_data.GAME_STARTED or GAME_STARTED
      SEATED_PLAYERS = loaded_data.SEATED_PLAYERS or SEATED_PLAYERS
      FIRST_PLAYER_INDEX = loaded_data.FIRST_PLAYER_INDEX or FIRST_PLAYER_INDEX
      CARD_POSITION = loaded_data.CARD_POSITION or CARD_POSITION
      PLAYERS_BET = loaded_data.PLAYERS_BET or PLAYERS_BET
      CURRENT_BETTOR_INDEX = loaded_data.CURRENT_BETTOR_INDEX or CURRENT_BETTOR_INDEX
  end

  if GAME_STARTED then
      for pcolor, ready in pairs(PLAYERS_BET) do
         for _, tile in pairs(GetTiles(pcolor)) do
            if not tile.is_face_down then
               if ready then
                  TileCreateButton(tile, "CancelBet")
               else
                  TileCreateButton(tile, "ChooseBet")
               end
            end
         end
      end
  end

  CardCreateButton()
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

function PlayCardAvailable()
   local isAvailable = true

   for _, ready in pairs(PLAYERS_BET) do
      isAvailable = isAvailable and ready
   end

   return isAvailable
end

function GroupCards()
   local zone = getObjectFromGUID("2b6f57")
   local objects = zone.getObjects()

   CARD_POSITION = 1

   for _, card in pairs(objects) do
      card.setLock(false)
   end

   local deck = group(objects)[1]
end

function PlayCard(card, pcolor)
   if not PlayCardAvailable() then
      return
   end

   if SEATED_PLAYERS[CURRENT_BETTOR_INDEX] ~= pcolor then
      broadcastToColor("It is not your turn to play.", pcolor, Color.fromString("Red"))
      return
   end

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
   CURRENT_BETTOR_INDEX = GetNextPlayerIndex(CURRENT_BETTOR_INDEX)

   card.clearButtons()

   card.setPositionSmooth(snapTrickCard.position, false, false)
   card.setRotationSmooth({x=snapTrickCard.rotation.x, y=snapTrickCard.rotation.y, z=0}, false, false)
   card.setLock(true)
end

function GetPlayerIndex(player_color)
   for index, color in ipairs(SEATED_PLAYERS) do
      if player_color == color then
         return index
      end
   end
end

function GetNextPlayerIndex(player_index)
   if player_index == #SEATED_PLAYERS then
      return 1
   else
      return player_index + 1
   end
end

function GetPreviousPlayerIndex(player_index)
   if player_index == 1 then
      return #SEATED_PLAYERS
   else
      return player_index - 1
   end
end

function NextFirstPlayer()
   FIRST_PLAYER_INDEX = GetNextPlayerIndex(FIRST_PLAYER_INDEX)
   CURRENT_BETTOR_INDEX = FIRST_PLAYER_INDEX
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

   tokenFirstPlayer.setLock(false)
   tokenFirstPlayer.setPosition(firstPlayerSnap.position)
   tokenFirstPlayer.setRotation(firstPlayerSnap.rotation)
   tokenFirstPlayer.setLock(true)
end

function StartGame()
   for _, pcolor in pairs(PLAYER_COLORS) do
      if Player[pcolor].seated then
         table.insert(SEATED_PLAYERS, pcolor)
         PLAYERS_BET[pcolor] = false
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
   CURRENT_BETTOR_INDEX = FIRST_PLAYER_INDEX
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

   for _, pcolor in pairs(SEATED_PLAYERS) do
      PLAYERS_BET[pcolor] = false
   end

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
   if not tile.hasTag('t' .. pcolor) then
      broadcastToColor("You can't click the tile of another player.", pcolor, Color.fromString("Red"))
      return
   end

   if SEATED_PLAYERS[CURRENT_BETTOR_INDEX] ~= pcolor then
      broadcastToColor("It is not your turn to bet.", pcolor, Color.fromString("Red"))
      return
   end

   PLAYERS_BET[pcolor] = true

   local stringValue = tile.getGMNotes()

   tile.clearButtons()

   for _, tileToFlip in pairs(GetTiles(pcolor)) do
      if not tileToFlip.is_face_down and tileToFlip.getGMNotes() ~= stringValue then
         tileToFlip.setLock(false)
         tileToFlip.clearButtons()
         tileToFlip.flip()
         Wait.frames(
            function()
               tileToFlip.setLock(true)
            end,
            40
         )
      end
   end

   CURRENT_BETTOR_INDEX = GetNextPlayerIndex(CURRENT_BETTOR_INDEX)

   Wait.frames(
      function()
         TileCreateButton(tile, "CancelBet")
      end,
      40
   )

   -- need to use stringValue
end

function CancelBet(tile, pcolor)
   if not tile.hasTag('t' .. pcolor) then
      broadcastToColor("You can't click the tile of another player.", pcolor, Color.fromString("Red"))
      return
   end

   local player_index = GetPlayerIndex(pcolor)

   -- or if you are the last player and first player did not play cards
   if PLAYERS_BET[SEATED_PLAYERS[GetNextPlayerIndex(player_index)]] then
      broadcastToColor("You can no longer cancel your bet.", pcolor, Color.fromString("Red"))
      return
   end

   PLAYERS_BET[pcolor] = false

   tile.clearButtons()

   local round = GetRound()

   for _, tile in pairs(GetTiles(pcolor)) do
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

   CURRENT_BETTOR_INDEX = player_index
end

function GetTiles(pcolor)
   return getObjectsWithTag('t' .. pcolor)
end

--[[ The onUpdate event is called once per frame. --]]
function onUpdate()
    --[[ print('onUpdate loop!') --]]
end