local _, addon = ...
addon:traceFile("cmd/objective.lua")

local unpack = addon.G.unpack
local QuestEngine = addon.QuestEngine

local conditions = {
  { "aura", "a" },
  { "emote", "em" },
  { "equip", "e" },
  { "item", "i" },
  { "target", "tar", "t" },
  { "spell", "sp" },
  { "zone", "z" }
}

local cmd = QuestEngine:NewCommand("objective", "obj", "o")

function cmd:Parse(quest, args)
  local rule = QuestEngine:GetArgsValue(args, 2)
  if rule == nil then
    error("Rule name is required")
  end

  rule = rule:lower()

  local objective = {
    --id = addon:CreateID("objective:"..rule.."-%i"),
    --rule = rules[p1], -- The objective contains a reference to its backing rule
    name = rule, -- objective name == rule name
    displayText = rule.." %p/%g",
    --progress = 0, -- All objectives start at 0 progress
    goal = 1, -- Objective goal will be 1 unless otherwise defined
    conditions = {}, -- The conditions under which this objective must be completed
    --metadata = {}, -- Additional data for this objective that can be written to save
    --tempdata = {} -- Additional data that will not be written to save
  }

  local goal = tonumber(QuestEngine:GetArgsValue(args, "goal", "g", 3))
  if goal and goal > 0 then
    objective.goal = goal

    local displayText = QuestEngine:GetArgsValue(args, "displaytext", "d", 4)
    if displayText then
      objective.displayText = displayText
    end
  else
    -- If param #3 was not a number, then it will be interpreted as the displayText
    local displayText = QuestEngine:GetArgsValue(args, "displaytext", "d", 3)
    if displayText then
      objective.displayText = displayText
    end
  end

  for _, names in ipairs(conditions) do
    local val = QuestEngine:GetArgsSet(args, unpack(names))
    if val then
      -- Group all aliased values and assign them to the primary condition name
      objective.conditions[names[1]] = val
    end
  end

  if not quest.objectives then
    quest.objectives = {}
  end

  table.insert(quest.objectives, objective)
end