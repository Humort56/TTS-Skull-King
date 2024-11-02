function onLoad(save_state)
   self.createButton({
      click_function = "resetDeck",
      function_owner = self,
      label = "",
      width = 2900,
      height = 950
   })
end

function resetDeck()
  local objects = getAllObjects()

  for i = 1, #objects, 1 do
     obj = objects[i]
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

  local round = Global.call('GetRound')
  Global.call('SetRound', round + 1)

end