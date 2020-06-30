local _, addon = ...
addon:traceFile("objectives/talkto.lua")
local compiler, tokens = addon.QuestScriptCompiler, addon.QuestScript.tokens
local UnitExists = addon.G.UnitExists

-- Publish the TalkTo event anytime the player targets a friendly unit
-- that activates one of the registered events below
local function publishEvent()
  if UnitExists("target") then
    addon.QuestEvents:Publish(tokens.OBJ_TALKTO)
  end
end

addon:onload(function()
  addon.GameEvents:Subscribe("AUCTION_HOUSE_SHOW", publishEvent)
  addon.GameEvents:Subscribe("BANKFRAME_OPENED", publishEvent)
  addon.GameEvents:Subscribe("GOSSIP_SHOW", publishEvent)
  addon.GameEvents:Subscribe("MERCHANT_SHOW", publishEvent)
  addon.GameEvents:Subscribe("PET_STABLE_SHOW", publishEvent)
  addon.GameEvents:Subscribe("QUEST_DETAIL", publishEvent)
end)