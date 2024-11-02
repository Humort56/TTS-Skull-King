function onLoad()
  startLuaCoroutine(self, "check_counter")
end

function check_counter()
  local round = getObjectFromGUID("e0f1ed")

  while true do
    if round.getValue() < 1 then
      round.setValue(1)
    end

    if round.getValue() > 10 then
      round.setValue(10)
    end
    wait(0.75)
  end
  return 1
end

function wait(time)
  local start = os.time()
  repeat coroutine.yield(0) until os.time() > start + time
end