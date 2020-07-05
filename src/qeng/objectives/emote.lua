local _, addon = ...
addon:traceFile("objectives/emote.lua")
local compiler, tokens = addon.QuestScriptCompiler, addon.QuestScript.tokens
local GetUnitName = addon.G.GetUnitName

addon:onload(function()
  addon.GameEvents:Subscribe("CHAT_MSG_TEXT_EMOTE", function(msg, playerName)
    if playerName == GetUnitName("player") and msg then
      -- Only handle emotes that the player performs
      addon.LastEmoteMessage = msg
      addon.QuestEvents:Publish(tokens.OBJ_EMOTE)
    end
  end)
end)