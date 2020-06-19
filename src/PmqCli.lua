local _, addon = ...
addon:traceFile("PmqCli.lua")

local SlashCmdList = addon.G.SlashCmdList
local strsplit = addon.G.strsplit

SLASH_PMQ1 = "/pmq"

SlashCmdList.PMQ = function(msg, editbox)
  addon:catch(function()
    local args = { strsplit(" ", msg) }
    local cmd = (args[1] or ""):lower()

    if cmd == "reset" then
      addon.QuestLog:Clear()
      addon:PlaySound("QuestAbandoned")
    elseif cmd == "add" then
      local ok, quest = addon.QuestDemos:CompileDemo(args[2])
      if not ok then
        addon.Logger:Error("Failed to add demo quest:", quest)
        return
      end
      addon.QuestLog:AddQuest(quest, addon.QuestStatus.Active)
      addon:PlaySound("QuestAccepted")
    elseif cmd == "log" then
      addon.PlayerSettings.MinLogLevel = addon:SetGlobalLogLevel(args[2])
    elseif cmd == "show" then
      addon:ShowQuestLog(true)
    elseif cmd == "hide" then
      addon:ShowQuestLog(false)
    elseif cmd == "toggle" then
      addon:ShowQuestLog(not(addon.PlayerSettings.IsQuestLogShown))
    elseif cmd == "dump" then
      local varname = args[2]
      local func = loadstring("return "..varname)
      setfenv(func, addon)
      local val = func()
      varname = "addon."..varname

      if type(val) == "table" then
        addon.Logger:Table(val)
        addon.Logger:Debug("^ Dumped table value for:", varname)
      else
        addon.Logger:Debug(varname..":", val)
      end
    else
      addon.MainMenu:Show()
    end
  end)
end