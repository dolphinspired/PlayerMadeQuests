local _, addon = ...
local SlashCmdList, unpack = addon.G.SlashCmdList, addon.G.unpack

local handlers

SLASH_PMQ1 = "/pmq"
SlashCmdList.PMQ = function(msg)
  addon:catch(function()
    local args = addon:SplitWords(msg)
    if not args[1] then
      -- By default, show the Main Menu if no command is specified
      addon.MainMenu:Show()
      return
    end

    local cmd = (args[1]):lower()
    local handler = handlers[cmd]
    if not handler then
      addon.Logger:Warn("Unrecognized command:", cmd)
      return
    end

    table.remove(args, 1)
    handler(unpack(args))
  end)
end

local function dumpToConsole(name, val)
  if type(val) == "table" then
    addon.Logger:Table(val)
    addon.Logger:Debug("^ Dumped table value for:", name)
  else
    addon.Logger:Debug(name..":", val)
  end
end

handlers = {
  ["reset"] = function()
    addon.QuestLog:Clear()
    addon:PlaySound("QuestAbandoned")
  end,
  ["add"] = function(demoId)
    local ok, quest = addon.QuestDemos:CompileDemo(demoId)
    if not ok then
      addon.Logger:Error("Failed to add demo quest:", quest)
      return
    end
    addon.QuestLog:SaveWithStatus(quest, addon.QuestStatus.Active)
    addon:PlaySound("QuestAccepted")
  end,
  ["log"] = function(name, level)
    addon:SetUserLogLevel(name, level)
  end,
  ["logstats"] = function()
    local stats = addon:GetLogStats()
    table.sort(stats, function(a, b) return a.name < b.name end)
    addon.Logger:Info("Logger stats:")
    for _, stat in pairs(stats) do
      addon.Logger:Info("    ", stat.name, "("..stat.stats.printed, "printed,", stat.stats.received, "received @", stat.levelname..")")
    end
  end,
  ["show"] = function()
    addon:ShowQuestLog(true)
  end,
  ["hide"] = function()
    addon:ShowQuestLog(false)
  end,
  ["toggle"] = function()
    addon:ShowQuestLog(not(addon.PlayerSettings.IsQuestLogShown))
  end,
  ["dump"] = function(varname)
    local func = loadstring("return "..varname)
    setfenv(func, addon)
    local val = func()
    varname = "addon."..varname
    dumpToConsole(varname, val)
  end,
  ["dump-quest"] = function(nameOrId)
    local quest = addon.QuestLog:FindByID(nameOrId)
    if not quest then
      quest = addon.QuestLog:FindByQuery(function(q) return q.name == nameOrId end)
    end
    if not quest then
      addon.Logger:Warn("Quest not found:", nameOrId)
    else
      dumpToConsole(nameOrId, quest)
    end
  end,
  ["get"] = function(name)
    if not name then
      addon.Logger:Table(addon.PlayerSettings)
      return
    end

    addon.Logger:Info(name..":", addon.PlayerSettings[name] or "not configured")
  end,
  ["set"] = function(name, value)
    if not name or not value then
      addon.Logger:Warn("/pmq set - name and value are required")
      return
    end

    addon.PlayerSettings[name] = addon:TryConvertString(value)
    addon.SaveData:Save("Settings", addon.PlayerSettings)
    addon.Logger:Info(name..":", addon.PlayerSettings[name])
  end,
  ["unset"] = function(name)
    if not name then
      addon.Logger:Warn("/pmq unset - name or \"all\" is required")
      return
    end

    if name == "all" then
      addon.PlayerSettings = {}
      addon.SaveData:Save("Settings", addon.PlayerSettings)
      addon.Logger:Info("All player settings have been cleared.")
      return
    end

    if addon.PlayerSettings[name] then
      addon.PlayerSettings[name] = nil
      addon.SaveData:Save("Settings", addon.PlayerSettings)
      addon.Logger:Info("Cleared setting:", name)
    end
  end
}