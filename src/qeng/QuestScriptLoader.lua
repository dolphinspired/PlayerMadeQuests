local _, addon = ...
local logger = addon.Logger:NewLogger("Loader")

addon.QuestScriptLoader = {}

local scripts = {}
local cleanNamePattern = "^[%l%d-]+$"

local function validateAndRegister(set, name, param)
  if not name or name == "" then
    error("Name cannot be nil or empty")
  end
  if type(name) ~= "string" or not name:match(cleanNamePattern) then
    error("Name must only contain lowercase alphanumeric characters or dashes")
  end
  if set[name] and set[name] ~= param then
    error("An item is already registered with name: "..name)
  end
  set[name] = param
end

local function applyTemplate(param, templateName)
  local templateNameType = type(templateName)
  assert(templateNameType == "string" or templateNameType == "table", "templateName must be a string or table")

  if templateNameType == "table" then
    for _, t in ipairs(templateName) do
      param = applyTemplate(param, t)
    end
    return param
  end

  local template = addon.QuestScriptTemplates[templateName]
  assert(template, templateName.." is not a recognized template")

  if template.template then
    -- apply nested templates first
    param = applyTemplate(param, template.template)
  end

  -- Merge the template table onto the param table, which will set and overwrite properties
  return addon:MergeTable(param, template)
end

local function getMethodScript(paramName, methodName, methodOptions)
  assert(type(methodName) == "string", type(methodName).." registered as methodName for "..paramName)
  assert(type(methodOptions) == "table", type(methodOptions).." registered as methodOptions for "..paramName)

  local method = scripts[paramName]
  if not method then
    if not methodOptions.required then return nil end
    error("No scripts registered for: "..paramName.." (looking for "..methodName..")")
  end

  method = method[methodName]
  if not method then
    if not methodOptions.required then return nil end
    error("No script registered for "..paramName.." with name: "..methodName)
  end

  assert(type(method) == "function", "Non-function registered as script for "..paramName..": "..methodName)
  return method
end

local function setup(set, name, param)
  assert(name, "name is required")
  assert(type(name) == "string", type(name).." is not a valid type for name")
  assert(param and type(param) == "table", "param is required")
  assert(type(param) == "table", type(param).." is not a valid type for param")
  param.name = name

  -- Since merging tables changes the table reference, need to apply templates
  -- before the param table is registered
  local template = param.template
  if template then
    param = applyTemplate(param, template)
    param.template = nil
  end

  validateAndRegister(set, name, param)
  if param.alias then
    validateAndRegister(set, param.alias, param)
  end

  local itemScripts = param.scripts
  if itemScripts then
    -- Replace the array of script names with a table like: { name = function }
    local newScripts = {}
    for methodName, methodOptions in pairs(itemScripts) do
      newScripts[methodName] = getMethodScript(name, methodName, methodOptions)
    end
    param.scripts = newScripts
  end

  local params = param.params
  if params then
    local newset = {}
    for pname, p in pairs(params) do
      -- Recursively set up parameters exactly like their parent items
      setup(newset, pname, p)
        end
    param.params = newset
  end
end

--[[
  Registers an arbitrary script by the specified unique name.
  Reference this script name in QuestScript.lua and it will be attached
  to the associated item and executed at the appropriate point in the quest lifecycle.
--]]
function addon.QuestScriptLoader:AddScript(itemName, methodName, fn)
  if not itemName or itemName == "" then
    logger:Error("AddScript: itemName is required (methodName: %s)", methodName)
    return
  end
  if not methodName or methodName == "" then
    logger:Error("AddScript: methodName is required (itemName: %s)", itemName)
    return
  end

  local existing = scripts[itemName]
  if not existing then
    existing = {}
    scripts[itemName] = existing
  end

  if existing[methodName] then
    logger:Error("AddScript: script is already registered for %s with name %s", itemName, methodName)
    return
  end

  existing[methodName] = fn
end

function addon.QuestScriptLoader:Init()
  local newset = {}
  for name, command in pairs(addon.QuestScript) do
    setup(newset, name, command)
  end
  addon.QuestScript = newset

  logger:Debug("QuestScript loaded OK!")
end