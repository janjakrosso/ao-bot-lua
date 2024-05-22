LatestGameState = LatestGameState or nil

function inRange(x1, y1, x2, y2, range)
  return math.abs(x1 - x2) <= range and math.abs(y1 - y2) <= range
end

function findHighestHealthPlayer()
  local highestHealth = -1
  local highestHealthPlayer = nil
  for target, state in pairs(LatestGameState.Players) do
    if target ~= ao.id and state.health > highestHealth then
      highestHealth = state.health
      highestHealthPlayer = target
    end
  end
  return highestHealthPlayer
end

function decideNextAction()
  local player = LatestGameState.Players[ao.id]
  local targetInRange = false
  local highestHealthPlayer = findHighestHealthPlayer()
  local otherPlayers = false

  for target, state in pairs(LatestGameState.Players) do
    if target ~= ao.id then
      otherPlayers = true
      if target ~= highestHealthPlayer and inRange(player.x, player.y, state.x, state.y, 1) then
        targetInRange = true
        break
      end
    end
  end

  if player.energy > 5 and targetInRange then
    print("Player in range. Attacking.")
    ao.send({Target = Game, Action = "PlayerAttack", Player = ao.id, AttackEnergy = tostring(player.energy)})
  elseif otherPlayers then
    print("No player in range or insufficient energy. Moving randomly.")
    local directionMap = {"Up", "Down", "Left", "Right", "UpRight", "UpLeft", "DownRight", "DownLeft"}
    local randomIndex = math.random(#directionMap)
    ao.send({Target = Game, Action = "PlayerMove", Player = ao.id, Direction = directionMap[randomIndex]})
  else
    print("No other players remaining. Attacking the highest health player.")
    if player.energy > 5 and inRange(player.x, player.y, LatestGameState.Players[highestHealthPlayer].x, LatestGameState.Players[highestHealthPlayer].y, 1) then
      ao.send({Target = Game, Action = "PlayerAttack", Player = ao.id, AttackEnergy = tostring(player.energy)})
    else
      print("Highest health player not in range or insufficient energy. Moving randomly.")
      local directionMap = {"Up", "Down", "Left", "Right", "UpRight", "UpLeft", "DownRight", "DownLeft"}
      local randomIndex = math.random(#directionMap)
      ao.send({Target = Game, Action = "PlayerMove", Player = ao.id, Direction = directionMap[randomIndex]})
    end
  end
end

Handlers.add(
  "HandleAnnouncements",
  Handlers.utils.hasMatchingTag("Action", "Announcement"),
  function (msg)
    ao.send({Target = Game, Action = "GetGameState"})
    print(msg.Event .. ": " .. msg.Data)
  end
)

Handlers.add(
  "UpdateGameState",
  Handlers.utils.hasMatchingTag("Action", "GameState"),
  function (msg)
    local json = require("json")
    LatestGameState = json.decode(msg.Data)
    ao.send({Target = ao.id, Action = "UpdatedGameState"})
  end
)

Handlers.add(
  "decideNextAction",
  Handlers.utils.hasMatchingTag("Action", "UpdatedGameState"),
  function ()
    if LatestGameState.GameMode ~= "Playing" then
      return
    end
    print("Deciding next action.")
    decideNextAction()
  end
)

Handlers.add(
  "ReturnAttack",
  Handlers.utils.hasMatchingTag("Action", "Hit"),
  function (msg)
    local playerEnergy = LatestGameState.Players[ao.id].energy
    if playerEnergy == nil then
      print("Unable to read energy.")
      ao.send({Target = Game, Action = "Attack-Failed", Reason = "Unable to read energy."})
    elseif playerEnergy == 0 then
      print("Player has insufficient energy.")
      ao.send({Target = Game, Action = "Attack-Failed", Reason = "Player has no energy."})
    else
      print("Returning attack.")
      ao.send({Target = Game, Action = "PlayerAttack", Player = ao.id, AttackEnergy = tostring(playerEnergy)})
    end
    InAction = false
    ao.send({Target = ao.id, Action = "Tick"})
  end
)
