local _, addon = ...

addon.VERSION = 104
addon.BRANCH = "beta"

function addon.Ace:OnInitialize()
  addon:OnAddonReady(function()
    addon.Logger:Info("PlayerMadeQuests loaded. Type %s to open the main menu", addon:Colorize("orange", "/pmq"))
  end)
  addon:catch(function()
    addon.Lifecycle:Init()
  end)
end

-- Runs the provided function, catching any Lua errors and logging them to console
-- Returns up to 4 values... not sure how to effectively make this dynamic
function addon:catch(fn, ...)
  local ok, result, r2, r3, r4 = pcall(fn, ...)
  if not(ok) then
    -- Uncomment this as an escape hatch to print errors if logging breaks
    -- print("Lua script error") if result then print(result) end
    addon.Logger:Error("Lua script error: %s", result)
  end
  return ok, result, r2, r3, r4
end