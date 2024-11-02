function onLoad(save_state)
   self.createButton({
      click_function = "DealCards",
      function_owner = self,
      label = "",
      width = 2900,
      height = 950
   })
end

function DealCards()
    local round = Global.call('GetRound')
    local objects = getAllObjects()
    for i = 1, #objects, 1 do
       obj = objects[i]
       if(obj.name == 'Deck') then
         if obj ~= nil then
           obj.shuffle()
           obj.deal(round)
         end
      end
    end
end