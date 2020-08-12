local _, addon = ...
local logger = addon.QuestEngine.ObjectiveLogger
local loader = addon.QuestScriptLoader
local tokens = addon.QuestScriptTokens

loader:AddScript(tokens.PARAM_AURA, tokens.METHOD_PARSE, function(auraNames)
  local t = type(auraNames)
  assert(t == "string" or t == "table", t.." is not a valid type for "..tokens.PARAM_AURA)

  if t == "string" then
    auraNames = { auraNames }
  end

  return addon:DistinctSet(auraNames)
end)

loader:AddScript(tokens.PARAM_AURA, tokens.METHOD_EVAL, function(obj, auraNames)
  local playerAuras = addon:GetPlayerAuraNames()

  for expectedAura in pairs(auraNames) do
    if playerAuras[expectedAura] then
      -- If any expected aura is found in the player's aura list, then evaluation passes
      logger:Debug(logger.pass.."Found aura match: %s", expectedAura)
      return true
    end
  end

  -- Otherwise, no expected auras were found
  logger:Debug(logger.fail.."No aura match found (%i checked)", addon:tlen(playerAuras))
  return false
end)