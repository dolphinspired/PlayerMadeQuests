local builder = require("spec/addon-builder")
local events = require("spec/events")

describe("VersionCheck", function()
  describe("when the addon is loaded", function()
    local tempAddon, tempEventSpy
    before_each(function()
      tempAddon = builder:Build()
      tempEventSpy = events:SpyOnEvents(tempAddon.MessageEvents)
    end)
    it("can send out a version request", function()
      tempAddon:Init()
      tempEventSpy:AssertPublished("AddonVersionRequest")
    end)
    it("can send out a manual version request", function()
      tempAddon:Init()
      tempAddon:Advance()
      tempEventSpy:Reset()

      tempAddon:CheckForUpdates()
      tempEventSpy:AssertPublished("AddonVersionRequestManual")
    end)
  end)
  describe("when a version request is received", function()
    local addon, eventSpy
    local branch = "unit-test"

    local function publish(v, b, t)
      addon.MessageEvents:Publish("AddonVersionRequest", nil, v, b, t)
    end

    before_each(function()
      addon = builder:Build()
      addon:Init()
      addon:Advance()
      eventSpy = events:SpyOnEvents(addon.MessageEvents)
    end)
    it("newer versions are cached", function()
      publish(addon.VERSION + 1, branch, addon.TIMESTAMP)
      addon:Advance()

      local kvi = addon.SaveData:Load("KnownVersionInfo", true)
      assert.not_nil(kvi)
      assert.equals(addon.VERSION + 1, kvi.VERSION)
      assert.equals(branch, kvi.BRANCH)
      assert.equals(addon.TIMESTAMP, kvi.TIMESTAMP)
    end)
    it("newer timestamps are cached", function()
      publish(addon.VERSION, branch, addon.TIMESTAMP + 1)
      addon:Advance()

      local kvi = addon.SaveData:Load("KnownVersionInfo", true)
      assert.not_nil(kvi)
      assert.equals(addon.VERSION, kvi.VERSION)
      assert.equals(branch, kvi.BRANCH)
      assert.equals(addon.TIMESTAMP + 1, kvi.TIMESTAMP)
    end)
    it("same version is not cached", function()
      publish(addon.VERSION, branch, addon.TIMESTAMP)
      addon:Advance()

      local kvi = addon.SaveData:Load("KnownVersionInfo", true)
      assert.is_nil(kvi)
    end)
    it("older version is not cached", function()
      publish(addon.VERSION - 1, branch, addon.TIMESTAMP)
      addon:Advance()

      local kvi = addon.SaveData:Load("KnownVersionInfo", true)
      assert.is_nil(kvi)
    end)
    it("a version response is only returned if an older version is received", function()
      publish(addon.VERSION, branch, addon.TIMESTAMP)
      addon:Advance()

      eventSpy:AssertNotPublished("AddonVersionResponse")

      publish(addon.VERSION - 1, branch, addon.TIMESTAMP)
      addon:Advance()

      eventSpy:AssertPublished("AddonVersionResponse", 1)
    end)
  end)
  describe("when a version response is received", function()
    local addon, eventSpy

    before_each(function()
      addon = builder:Build()
      addon:Init()
      addon:Advance()
      eventSpy = events:SpyOnEvents(addon.MessageEvents)
    end)
    it("a version response is not published", function()
      addon.MessageEvents:Publish("AddonVersionResponse", nil, addon.VERSION, addon.BRANCH, addon.TIMESTAMP)
      eventSpy:Reset() -- Don't count ^ this response in the spy
      addon:Advance()

      eventSpy:AssertNotPublished("AddonVersionResponse")
    end)
  end)
end)