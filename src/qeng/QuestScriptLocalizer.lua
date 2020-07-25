local _, addon = ...

addon.QuestScriptLocalizer = {}

local localizables = {}
local rules -- defined below

-- If the condition value is a table of values, then returns each value in that table
-- in a reader-friendly comma-separated string, with the last two items separated by "or"
local function defaultConditionTextHandler(condVal)
  if condVal == nil then return end

  if type(condVal) == "table" then
    local len, result = addon:tlen(condVal), ""
    if len == 1 then
      for v in pairs(condVal) do
        result = v
      end
    elseif len > 1 then
      local i = 1
      for v in pairs(condVal) do
        if i == len then
          return result.." or "..v
        else
          result = result..", "..v
        end
        i = i + 1
      end
    end
    condVal = result
  end

  return condVal
end

local function parseConditionValueText(obj, handlerArg, handlerFn)
  local arg
  if handlerArg then
    arg = obj.conditions[handlerArg]
    if not arg then
      addon.UILogger:Warn("Failed to parse display text: objective has no var for", handlerArg)
      return
    end
  else
    arg = obj
  end

  local result
  if handlerFn then
    result = handlerFn(arg)
  else
    if not handlerArg then
      addon.UILogger:Warn("Failed to parse display text: a param name must be provided to use the default text handler")
      return
    end
    result = defaultConditionTextHandler(arg)
  end
  return result
end

local function populateDisplayText(text, obj)
  -- print("=> received:", text)
  for _, mod in ipairs(rules.standard) do
    text = addon:strmod(text, mod.pattern, mod.fn, obj)
  end
  -- Once all substitutions are made, clean up extra spaces
  -- print("<= resolved:", text)
  return text
end

rules = {
  standard = {
    { -- Contents of bracketed sets are analyzed recursively, innermost first
      pattern = "%b[]",
      fn = function(str, obj)
        -- print("     match: []", str)
        str = str:match("^%[(.+)%]$") -- extract contents from brackets

        local condition, valIfTrue, valIfFalse
        for _, br in ipairs(rules.bracketed) do
          -- Pattern returns up to three capture groups
          condition, valIfTrue, valIfFalse = str:match(br.pattern)
          if condition then
            -- If matched, an associated function will map to the appropriate values
            condition, valIfTrue, valIfFalse = br.fn(condition, valIfTrue, valIfFalse)
            -- print("     ^ ctf:", condition, valIfTrue, valIfFalse)
            break
          end
        end

        if not condition then
          -- Unable to parse bracket formula, try to parse the string as a whole
          -- print("     ^ unmatched bracket formula")
          return populateDisplayText(str, obj)
        end

        -- Determine which text to parse next, based on condition's parsed value
        local ret
        condition = populateDisplayText(condition, obj)
        if condition and condition ~= "" then
          ret = valIfTrue
        else
          ret = valIfFalse
        end
        ret = ret or "" -- As a failsafe, never send nil to parse

        return populateDisplayText(ret, obj)
      end
    },
    { -- Any %var gets the value for the mapped condition returned
      pattern = "%%%w+",
      fn = function(pctstr, obj)
        -- print("     match: %var", str)
        local template = localizables[obj.name]
        if not template then return pctstr end -- objective does not have any localizable content

        local str = pctstr:sub(2) -- Remove the leading %
        local handler
        local dt = localizables[obj.name].displaytext
        if dt and dt.vars then
          handler = dt.vars[str]
        end
        if not handler then return pctstr end -- objective has no displaytext handler for this var name

        -- Handlers under displaytext.vars[varname] can be registered in multiple ways, but two values are required:
        --   * fn: given some context, returns the value to be displayed (will be converted to string)
        --   * arg: a token name to define which param value should be passed to the fn
        -- This can be registed as a displaytext var in the following ways:
        --   * table: consisting of one or both of the above properties
        --   * string: the param name - a default handler fn will be used
        --   * function: a handler - the whole objective will be passed as a parameter
        local result
        if type(handler) == "table" then
          -- print("     ^ handler: table", addon:Enquote(handler.arg, "()"))
          result = parseConditionValueText(obj, handler.arg, handler.fn)
        elseif type(handler) == "string" then
          -- print("     ^ handler: string", addon:Enquote(handler, "()"))
          result = parseConditionValueText(obj, handler, nil)
        elseif type(handler) == "function" then
          -- print("     ^ handler: function")
          result = parseConditionValueText(obj, nil, handler)
        else
          -- print("     ^ handler: not found", addon:Enquote(pctstr, "()"))
          result = pctstr
        end

        if result == nil then return "" end
        return tostring(result)
      end
    }
  },
  bracketed = {
    { -- If A, then show B, else show C
      pattern = "^(.-):(.-)|(.-)$",
      fn = function(a, b, c)
        -- print("     ^ match: [a:b|c]")
        return a, b, c
      end
    },
    { -- If A, then show A, else show B
      pattern = "^(.-)|(.-)$",
      fn = function(a, b)
        -- print("     ^ match: [a|b]")
        return a, a, b
      end
    },
    { -- If A, then show B, else show nothing
      pattern = "^(.-):(.-)$",
      fn = function(a, b)
        -- print("     ^ match: [a:b]")
        return a, b, nil
      end
    },
    { -- If A, then show A, else show nothing
      -- A courtesy space is added after the var to make this more useful
      pattern = "^(.-)$",
      fn = function(a)
        -- print("     ^ match: [a]")
        return a, a.." ", nil
      end
    }
  }
}

--------------------
-- Public methods --
--------------------

-- Valid values for scope are: log [default], progress, quest, full
-- Use this method at runtime
function addon.QuestScriptLocalizer:GetDisplayText(obj, scope)
  scope = scope or "log"
  local displayText
  if obj.displaytext then
    -- Custom displayText is set for this instance of the objective
    displayText = obj.displaytext[scope]
  end
  if not displayText then
    -- Otherwise, use default displayText for this objective
    local dirTemplate = localizables[obj.name]
    assert(dirTemplate, "Invalid directive: "..obj.name)
    displayText = dirTemplate.displaytext[scope]
  end

  assert(displayText, "Cannot determine how to display text for directive: "..obj.name.." in scope "..scope)
  return populateDisplayText(displayText, obj)
end

-----------------------
-- Event Subscribers --
-----------------------

addon.AppEvents:Subscribe("QuestScriptLoaded", function()
  local queryHasDisplayText = function(cmd) return cmd.displaytext end
  localizables = addon.QuestScriptCompiler:Find(queryHasDisplayText)
  addon.AppEvents:Publish("LocalizerLoaded")
end)