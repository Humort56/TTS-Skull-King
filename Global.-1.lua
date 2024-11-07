--[[ Lua code. See documentation: https://api.tabletopsimulator.com/ --]]

PLAYER_COLORS = {'Red','Green', 'Teal', 'Blue', 'White', 'Brown'}
SUITS = {'Red', 'Blue', 'Yellow', 'Black'}
TRUMP_SUIT = 'Black'
LEAD_SUIT = nil
SEATED_PLAYERS = {}
PLAYERS_BET = {}
PLAYERS_TRICKS = {}
GAME_STARTED = false
TRICK_CAN_BE_CLAIMED = false
BETTING_FINISHED = false
TRICK_FINISHED = false
FIRST_PLAYER_INDEX = nil
FIRST_PLAYER_SET_INDEX = nil
CURRENT_PLAYER_INDEX = nil
CARD_POSITION = 1


function onSave()
   local saved_data = JSON.encode({
      GAME_STARTED=GAME_STARTED,
      TRICK_CAN_BE_CLAIMED=TRICK_CAN_BE_CLAIMED,
      BETTING_FINISHED=BETTING_FINISHED,
      LEAD_SUIT=LEAD_SUIT,
      TRICK_FINISHED=TRICK_FINISHED,
      SEATED_PLAYERS=SEATED_PLAYERS,
      FIRST_PLAYER_INDEX=FIRST_PLAYER_INDEX,
      FIRST_PLAYER_SET_INDEX=FIRST_PLAYER_SET_INDEX,
      CARD_POSITION=CARD_POSITION,
      PLAYERS_BET=PLAYERS_BET,
      PLAYERS_TRICKS=PLAYERS_TRICKS,
      CURRENT_PLAYER_INDEX=CURRENT_PLAYER_INDEX
   })
   return saved_data
end

--[[ The onLoad event is called after the game save finishes loading. --]]
function onLoad(saved_data)
   MegaFreeze()

   if saved_data ~= '' then
      local loaded_data = JSON.decode(saved_data)
      GAME_STARTED = loaded_data.GAME_STARTED or GAME_STARTED
      TRICK_CAN_BE_CLAIMED = loaded_data.TRICK_CAN_BE_CLAIMED or TRICK_CAN_BE_CLAIMED
      BETTING_FINISHED = loaded_data.BETTING_FINISHED or BETTING_FINISHED
      TRICK_FINISHED = loaded_data.TRICK_FINISHED or TRICK_FINISHED
      LEAD_SUIT = loaded_data.LEAD_SUIT or LEAD_SUIT
      SEATED_PLAYERS = loaded_data.SEATED_PLAYERS or SEATED_PLAYERS
      FIRST_PLAYER_INDEX = loaded_data.FIRST_PLAYER_INDEX or FIRST_PLAYER_INDEX
      FIRST_PLAYER_SET_INDEX = loaded_data.FIRST_PLAYER_SET_INDEX or FIRST_PLAYER_SET_INDEX
      CARD_POSITION = loaded_data.CARD_POSITION or CARD_POSITION
      PLAYERS_BET = loaded_data.PLAYERS_BET or PLAYERS_BET
      PLAYERS_TRICKS = loaded_data.PLAYERS_TRICKS or PLAYERS_TRICKS
      CURRENT_PLAYER_INDEX = loaded_data.CURRENT_PLAYER_INDEX or CURRENT_PLAYER_INDEX
  end

  if GAME_STARTED and not BETTING_FINISHED then
      for _, pcolor in pairs(SEATED_PLAYERS) do
         for _, tile in pairs(GetTiles(pcolor)) do
            if not tile.is_face_down then
               TileCreateButton(tile, "ChooseBet")
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

function GetText()
   local text = getObjectFromGUID("4a6a13")

   return text.clone()
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

function GetLastPlayer()
   return SEATED_PLAYERS[GetPreviousPlayerIndex(FIRST_PLAYER_INDEX)]
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

function GetTricksPlayed()
   local tricks_count = 0

   for _, tricks_won in pairs(PLAYERS_TRICKS) do
      tricks_count = tricks_count + tricks_won
   end

   return tricks_count
end

function ResetTricks()
   for _, pcolor in pairs(SEATED_PLAYERS) do
      PLAYERS_TRICKS[pcolor] = 0
   end
end

function GroupCards(button, pcolor)
   if not TRICK_FINISHED then
      broadcastToColor("You can only claim the trick when everyone played a card", pcolor, "Red")
      return
   end

   if not TRICK_CAN_BE_CLAIMED then
      broadcastToColor("Wait for the end of a trick before clicking", pcolor, "Red")
      return
   end

   -- calculate best card of trick
   local winnerColor = GetBestCardPlayer()
   broadcastToAll(string.format(
      "The winner is [%s] %s",
      Color.fromString(winnerColor):toHex(),
      Player[winnerColor].steam_name
   ))

   LEAD_SUIT = nil
   TRICK_CAN_BE_CLAIMED = false

   local zone = getObjectFromGUID("2b6f57")

   CARD_POSITION = 1
   PLAYERS_TRICKS[winnerColor] = PLAYERS_TRICKS[winnerColor] + 1
   TRICK_FINISHED = false

   for _, card in pairs(zone.getObjects()) do
      card.setLock(false)
      card.removeTag('TrickCard')

      for position, pcolor in pairs(SEATED_PLAYERS) do
         card.removeTag('CardPosition' .. position)

         if card.hasTag('c'..pcolor) then
            if pcolor == winnerColor then
               card.addTag('Winner')
            end

            card.removeTag('c'..pcolor)
         end
      end

      if card.hasTag('Tigress') then
         card.removeTag('Pirate')
         card.removeTag('Escape')
      end

      if card.hasTag('Winner') then
         card.removeTag('Winner')
         MoveCardToSnapPoint(card, 'snapTrick' .. winnerColor .. PLAYERS_TRICKS[winnerColor], false)
      end
   end

   for _, text in pairs(getObjectsWithTag("TextToRemove")) do
      text.destruct()
   end

   Wait.time(
      function()
         local objects = zone.getObjects()
         local toMove = nil
         if #objects > 1 then
            toMove = group(objects)[1]
         else
            toMove = objects[1]
         end
         MoveToMainDeck(toMove)
      end,
      1
   )

   if GetTricksPlayed() == GetRound() then
      -- calculate score and modify player's counter
      Wait.time(
         function()
            ScorePoints()
         end,
         1
      )
   end

   FIRST_PLAYER_SET_INDEX = GetPlayerIndex(winnerColor)
   CURRENT_PLAYER_INDEX = FIRST_PLAYER_SET_INDEX
end

function ScorePoints()
   local round = GetRound()

   for _, pcolor in pairs(SEATED_PLAYERS) do
      local counter = GetObjectWithTag('count' .. pcolor)
      local points = 0

      if 0 == PLAYERS_BET[pcolor] then
         if 0 == PLAYERS_TRICKS[pcolor] then
            points = round * 10 
         else
            points = round * -10
         end
      else
         if PLAYERS_BET[pcolor] == PLAYERS_TRICKS[pcolor] then
            points = PLAYERS_TRICKS[pcolor] * 20
         else
            points = math.abs(PLAYERS_TRICKS[pcolor] - PLAYERS_BET[pcolor]) * - 10
         end
      end

      local verb = "lost"

      if points > 0 then
         verb = "won"
      end

      broadcastToColor("You have " .. verb .. " " .. math.abs(points) .. " points", pcolor)

      counter.setValue(counter.getValue() + points)
   end
end

function GetSnapPointWithTag(tag)
   for _, snapPoint in pairs(Global.getSnapPoints()) do
      for _, snapTag in pairs(snapPoint.tags) do
         if tag == snapTag then
            return snapPoint
         end
      end
   end
end

function MoveCardToSnapPoint(card, snapPointTag, fast)
   local snap = GetSnapPointWithTag(snapPointTag)

   local position = {snap.position.x, 2, snap.position.z}
   if fast then
      card.setPosition(position)
   else
      card.setPositionSmooth(position, false, false)
   end
   card.setRotationSmooth(
      {
         x=snap.rotation.x,
         y=snap.rotation.y,
         z=0
      },
      false,
      false
   )

   Wait.frames(function() card.setLock(true) end, 80)
end

function CanPlayerPlayLeadSuit(pcolor)   
   for _, card in pairs(Player[pcolor].getHandObjects()) do
      if card.hasTag('Suit') then
         if card.hasTag('Suit' .. LEAD_SUIT) then
            return true
         end
      end
   end

   return false
end

function PlayCard(card, pcolor, alt)
   if not BETTING_FINISHED or TRICK_FINISHED then
      return
   end

   if SEATED_PLAYERS[CURRENT_PLAYER_INDEX] ~= pcolor then
      broadcastToColor("It is not your turn to play.", pcolor, Color.fromString("Red"))
      return
   end

   -- There is a lead suit
   if false ~= LEAD_SUIT and nil ~= LEAD_SUIT then
      if card.hasTag('Suit') and GetSuitColor(card) ~= LEAD_SUIT and CanPlayerPlayLeadSuit(pcolor) then
         broadcastToColor("You must play the leading suit if you have one.", pcolor, Color.fromString("Red"))
         return
      end
   end

   if GetPreviousPlayerIndex(FIRST_PLAYER_SET_INDEX) == CURRENT_PLAYER_INDEX then
      TRICK_FINISHED = true
   end

   local snapTag = 'snapTrickCard' .. CARD_POSITION

   card.addTag('TrickCard')
   card.addTag('CardPosition' .. CARD_POSITION)
   CARD_POSITION = CARD_POSITION + 1
   CURRENT_PLAYER_INDEX = GetNextPlayerIndex(CURRENT_PLAYER_INDEX)

   card.clearButtons()

   if card.hasTag('Tigress') then
      local tag = 'Pirate'
      local name = 'a ' .. tag

      if true == alt then
         tag = 'Escape'
         name = 'an ' .. tag
      end

      card.addTag(tag)
      broadcastToColor("You played the Scary Mary as " .. name, pcolor)
   end

   if nil == LEAD_SUIT then
      if card.hasTag('Suit') then
         LEAD_SUIT = GetSuitColor(card)
      elseif card.hasTag('Face') and not card.hasTag('Escape') then
         LEAD_SUIT = false
      end
   end

   MoveCardToSnapPoint(card, snapTag, true)

   card.addTag('c'..pcolor)

   Wait.frames(
      function()
         local textTop = GetText()
         textTop.addTag("TextToRemove")
         textTop.TextTool.setValue(Player[pcolor].steam_name)
         textTop.TextTool.setFontColor(Color.fromString(pcolor))
         
         local textRotation = textTop.getRotation()
         local textBottom = textTop.clone()

         local snapPosition = GetSnapPointWithTag(snapTag).position
         textTop.setPosition({
            x=snapPosition.x,
            y=snapPosition.y,
            z=snapPosition.z + 2.8
         })

         textBottom.setPosition({
            x=snapPosition.x,
            y=snapPosition.y,
            z=snapPosition.z - 2.8
         })

         textTop.setRotation({x=textRotation.x, y=180, z=textRotation.z})
         textBottom.setRotation({x=textRotation.x, y=0, z=textRotation.z})
      end,
      30
   )

   if TRICK_FINISHED then
      Wait.time(
         function()
            TRICK_CAN_BE_CLAIMED = true
         end,
         3
      )
   end
end

function GetBestCardPlayer()
   local bestCard = nil
   local firstMermaid = nil

   for i = 1, #SEATED_PLAYERS do
      local card = getObjectsWithAllTags({'TrickCard', 'CardPosition'..i})[1]
      -- local card = GetObjectWithTag('CardPosition'..i)

      if bestCard ~= nil then
         if card.hasTag('Suit') then
            if bestCard.hasTag('Escape') then
               bestCard = card
            elseif bestCard.hasTag('Suit') then
               local cardSuit = GetSuitColor(card)
               local bestCardSuit = GetSuitColor(bestCard)

               if cardSuit == bestCardSuit then
                  if tonumber(card.getGMNotes()) > tonumber(bestCard.getGMNotes()) then
                     bestCard = card
                  end
               elseif cardSuit == TRUMP_SUIT then
                  bestCard = card
               end
            end
         elseif card.hasTag('Face') then
            if card.hasTag('Mermaid') and firstMermaid == nil then
               firstMermaid = card
            end

            if bestCard.hasTag('Face') and not bestCard.hasTag('Escape') then
               local cardFace = GetFaceValue(card)
               local bestCardFace = GetFaceValue(bestCard)

               if cardFace > bestCardFace then
                  bestCard = card
               end
            else
               bestCard = card
            end
         end
      else
         bestCard = card
      end
   end

   if bestCard.hasTag('SkullKing') and firstMermaid ~= nil then
      bestCard = firstMermaid
   end

   for _, tag in pairs(bestCard.getTags()) do
      local match = string.match(tag, '^c(.*)$')
      if match ~= nil then
         return match
      end
   end
end

function GetSuitColor(card)
   for _, suit in pairs(SUITS) do
      if card.hasTag('Suit'..suit) then
         return suit
      end
   end

   return false
end

function GetFaceValue(card)
   for value, face in pairs({'Mermaid', 'Pirate', 'SkullKing'}) do
      if card.hasTag(face) then
         return value
      end
   end
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
   FIRST_PLAYER_SET_INDEX = FIRST_PLAYER_INDEX
   CURRENT_PLAYER_INDEX = FIRST_PLAYER_INDEX
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
   FIRST_PLAYER_SET_INDEX = FIRST_PLAYER_INDEX
   CURRENT_PLAYER_INDEX = FIRST_PLAYER_INDEX
   SetFirstPlayerToken()
   ResetTricks()
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

function MoveToMainDeck(object)
   object.setRotation({0, 180, 180})
   object.setPosition({-45.00, 2.02, -3.00})
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
            obj.setLock(false)
            MoveToMainDeck(obj)
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

   BETTING_FINISHED = false

   if GAME_STARTED then
      NextFirstPlayer()
      SetFirstPlayerToken()
      ResetTricks()
   end

end

function TileCreateButton(tile, functionName)
   tile.createButton({
      click_function = functionName,
      width = 1000,
      height = 1000
   })
end

function HideNonBetTiles()
   for pcolor, bet in pairs(PLAYERS_BET) do
      for _, tile in pairs(GetTiles(pcolor)) do
         if not tile.is_face_down then
            tile.clearButtons()
         
            if tonumber(tile.getGMNotes()) ~= bet then
               tile.setLock(false)
               tile.flip()
               Wait.frames(
                  function()
                     tile.setLock(true)
                  end,
                  40
               )
            end
         end
      end
   end
end

function IsBettingFinished()
   for _, pcolor in pairs(SEATED_PLAYERS) do
      if false == PLAYERS_BET[pcolor] then
         return false
      end
   end

   return true
end

function ChooseBet(tile, pcolor)
   if not tile.hasTag('t' .. pcolor) then
      broadcastToColor("You can't click the tile of another player.", pcolor, Color.fromString("Red"))
      return
   end

   local stringValue = tile.getGMNotes()

   PLAYERS_BET[pcolor] = tonumber(stringValue)

   broadcastToColor("You are now betting on winning " .. stringValue .. " trick(s)", pcolor)

   if IsBettingFinished() then
      BETTING_FINISHED = true
      HideNonBetTiles()
   end
end

function GetTiles(pcolor)
   return getObjectsWithTag('t' .. pcolor)
end

--[[ The onUpdate event is called once per frame. --]]
function onUpdate()
    --[[ print('onUpdate loop!') --]]
end