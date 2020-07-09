local builder = require("spec/addon-builder")
local addon = builder:Build()
local events = require("spec/events")
local compiler = addon.QuestScriptCompiler
local QuestLog, QuestStatus = addon.QuestLog, addon.QuestStatus

local goodScript = [[
  quest:
    name: Test Quest
    description: I sure hope these tests pass!
  objectives:
    - kill 5 Chicken
    - talkto 3 "Stormwind Guard"
    - emote dance 2 Cow
]]

describe("QuestLog", function()
  local eventSpy, messageSpy
  setup(function()
    addon:Init()
    addon:Advance()
    eventSpy = events:SpyOnEvents(addon.AppEvents)
    messageSpy = events:SpyOnEvents(addon.MessageEvents)
  end)
  before_each(function()
    QuestLog:Clear()
    addon:Advance()
    eventSpy:Reset()
    messageSpy:Reset()
  end)
  it("can clear the log", function()
    local quest = compiler:Compile(goodScript)
    QuestLog:SaveWithStatus(quest, QuestStatus.Active)
    QuestLog:Clear()

    local results = QuestLog:FindAll()
    assert.equals(0, #results)

    addon:Advance()
    eventSpy:AssertPublished("QuestLogReset", 1)
  end)
  describe("Validate", function()
    it("can save a quest with a valid status", function()
      local quest = compiler:Compile(goodScript)
      QuestLog:SaveWithStatus(quest, QuestStatus.Active)

      local results = QuestLog:FindAll()
      assert.equals(1, #results)

      local result = QuestLog:FindByID(quest.questId)
      -- remove timestamps for object comparison
      result.cd = nil
      result.ud = nil
      assert.same(result, quest)

      local payload = eventSpy:GetPublishPayload("QuestAdded", 1)
      assert.same(quest, payload)
    end)

  end)
  describe("SaveWithStatus", function()
    local quest
    before_each(function()
      quest = compiler:Compile(goodScript)
      quest.status = QuestStatus.Completed
      QuestLog:Save(quest)
      quest = QuestLog:FindByID(quest.questId)
      addon:Advance()
      eventSpy:Reset()
    end)
    it("can save status on quest", function()
      QuestLog:SaveWithStatus(quest, QuestStatus.Finished)
      quest = QuestLog:FindByID(quest.questId)
      assert.equals(QuestStatus.Finished, quest.status)
    end)
    it("can save status by questId", function()
      QuestLog:SaveWithStatus(quest.questId, QuestStatus.Finished)
      quest = QuestLog:FindByID(quest.questId)
      assert.equals(QuestStatus.Finished, quest.status)
    end)
    it("cannot save a quest without a status", function()
      assert.has_error(function() QuestLog:SaveWithStatus(quest) end)
      eventSpy:AssertNotPublished("QuestAdded")
    end)
    it("cannot save a quest with an invalid status", function()
      assert.has_error(function() QuestLog:SaveWithStatus(quest, "invalid") end)
      eventSpy:AssertNotPublished("QuestAdded")
    end)
    it("publishes event on status change", function()
      QuestLog:SaveWithStatus(quest, QuestStatus.Active)
      addon:Advance()
      eventSpy:AssertPublished("QuestStatusChanged")
    end)
    it("does not publish event on same status", function()
      QuestLog:SaveWithStatus(quest, quest.status)
      eventSpy:AssertNotPublished("QuestStatusChanged")
    end)
    it("resets quest progress on change to Active", function()
      quest.objectives[1].progress = 1
      QuestLog:SaveWithStatus(quest, QuestStatus.Active)
      addon:Advance()
      quest = QuestLog:FindByID(quest.questId)
      assert.equals(0, quest.objectives[1].progress)
    end)
  end)
end)