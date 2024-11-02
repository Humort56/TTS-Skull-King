--[[ Lua code. See documentation: https://api.tabletopsimulator.com/ --]]

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
   printToColor(#objects, "Red")
   local roundCounter = objects[1]
   local value = roundCounter.getValue()

   return tonumber(value)
end

--[[ The onUpdate event is called once per frame. --]]
function onUpdate()
    --[[ print('onUpdate loop!') --]]
end