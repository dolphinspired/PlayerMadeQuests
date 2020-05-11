local _, addon = ...
addon:traceFile("QuestLogFrame.lua")

local AceGUI = addon.AceGUI
local strjoin = addon.G.strjoin
local strsplit = addon.G.strsplit
local UIParent = addon.G.UIParent

local frames = {}
local subscriptions = {}
local savedSettings
local qlog = {}
local wp = {
  p1 = "RIGHT",
  p2 = "RIGHT",
  x = -100,
  y = 0,
  w = 250,
  h = 300
}

-- For some reason GetPoint() returns the wrong position unless you move the window
-- Still trying to figure this one out
local function isInaccuratePoint(p1, p2, x, y)
  return p1 == "CENTER" and p2 == "CENTER" and x == 0 and y == 0
end

local function SavePosition(widget)
  local p1, _, p2, x, y = widget:GetPoint()
  if isInaccuratePoint(p1, p2, x, y) then
    p1 = wp.p1
    p2 = wp.p2
    x = wp.x
    y = wp.y
  end
  local w, h = widget.frame:GetSize()
  savedSettings.QuestLogPosition = strjoin(",", p1, p2, x, y, w, h)
  -- addon:debug("Saving position:", p1, p2, x, y, w, h)
end

local function LoadPosition(widget)
  if savedSettings.QuestLogPosition then
    local p1, p2, x, y, w, h = strsplit(",", savedSettings.QuestLogPosition)
    wp.p1 = p1
    wp.p2 = p2
    wp.x = x
    wp.y = y
    wp.w = w
    wp.h = h
  end

  widget:SetPoint(wp.p1, UIParent, wp.p2, wp.x, wp.y)
  widget:SetWidth(wp.w)
  widget:SetHeight(wp.h)
end

local function OnOpen(widget)
  savedSettings.IsQuestLogShown = true
  LoadPosition(widget)
end

local function OnClose(widget)
  addon:catch(SavePosition, widget)
  savedSettings.IsQuestLogShown = nil
  frames = {}
  for event, key in pairs(subscriptions) do

    addon.AppEvents:Unsubscribe(event, key)
  end
  subscriptions = {}
  AceGUI:Release(widget)
end

local function SetQuestLogHeadingText(heading, qlog)
  local numQuests = addon:tlen(qlog)
  heading:SetText("You have "..numQuests.." "..addon:pluralize(numQuests, "quest").." in your log.")
end

local function SetQuestText(label, quest)
  local text = quest.name
  if quest.status == addon.QuestStatus.Completed then
    text = text.." (Complete)"
  end
  label:SetText(text)
end

local function SetObjectiveText(label, obj)
  local displayText = obj:GetDisplayText()
  label:SetText("    "..displayText.." "..obj.progress.."/"..obj.goal)
end

local function AddQuest(questList, quest)
  local qLabel = AceGUI:Create("InteractiveLabel")
  qLabel:SetFullWidth(true)
  questList:AddChild(qLabel)
  SetQuestText(qLabel, quest)
  frames[quest.id] = qLabel

  local objList = AceGUI:Create("SimpleGroup")
  questList:AddChild(objList)

  for _, obj in pairs(quest.objectives) do
    local oLabel = AceGUI:Create("InteractiveLabel")
    oLabel:SetFullWidth(true)
    objList:AddChild(oLabel)
    SetObjectiveText(oLabel, obj)
    frames[obj.id] = oLabel
  end
end

local function SetQuestLogText(questList, qlog)
  questList:ReleaseChildren()
  for _, quest in pairs(qlog) do
    AddQuest(questList, quest)
  end
end

local function BuildQuestLogFrame()
  local container = AceGUI:Create("Window")
  container:SetTitle("PMQ Quest Log")
  container:SetCallback("OnClose", OnClose)
  container:SetLayout("Flow")
  frames["main"] = container

  local questHeading = AceGUI:Create("Heading")
  questHeading:SetFullWidth(true)
  container:AddChild(questHeading)
  frames["heading"] = questHeading

  local scrollGroup = AceGUI:Create("SimpleGroup")
  scrollGroup:SetFullWidth(true)
  scrollGroup:SetFullHeight(true)
  scrollGroup:SetLayout("Fill")
  container:AddChild(scrollGroup)

  local scroller = AceGUI:Create("ScrollFrame")
  scroller:SetLayout("Flow")
  scrollGroup:AddChild(scroller)

  local questList = AceGUI:Create("SimpleGroup")
  questList:SetFullWidth(true)
  scroller:AddChild(questList)
  frames["questList"] = questList

  SetQuestLogHeadingText(questHeading, qlog)
  SetQuestLogText(questList, qlog)

  local subKey
  subKey = addon.AppEvents:Subscribe("QuestLogLoaded", function(qlog)
    SetQuestLogHeadingText(frames["heading"], qlog)
    SetQuestLogText(frames["questList"], qlog)
  end)
  subscriptions["QuestLogLoaded"] = subKey

  subKey = addon.AppEvents:Subscribe("QuestCreated", function(quest)
    SetQuestLogHeadingText(frames["heading"], qlog)
    AddQuest(frames["questList"], quest)
  end)
  subscriptions["QuestCreated"] = subKey

  subKey = addon.AppEvents:Subscribe("QuestCompleted", function(quest)
    SetQuestText(frames[quest.id], quest)
  end)
  subscriptions["QuestCompleted"] = subKey

  subKey = addon.AppEvents:Subscribe("ObjectiveUpdated", function(obj)
    SetObjectiveText(frames[obj.id], obj)
  end)
  subscriptions["ObjectiveUpdated"] = subKey

  OnOpen(container)
end

function addon:ShowQuestLog(show)
  local mainframe = frames["main"]
  if show == true then
    if mainframe == nil then
      BuildQuestLogFrame()
    end
  elseif mainframe ~= nil then
    OnClose(mainframe)
  end
end

addon:OnSaveDataLoaded(function()
  savedSettings = addon.SaveData:LoadTable("Settings")
  if savedSettings.IsQuestLogShown then
    addon:ShowQuestLog(true)
  end
end)

addon.AppEvents:Subscribe("QuestLogLoaded", function(quests)
  qlog = quests
end)