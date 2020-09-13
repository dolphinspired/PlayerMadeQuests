local _, addon = ...
local MessageEvents, MessageDistribution, MessagePriority = addon.MessageEvents, addon.MessageDistribution, addon.MessagePriority
local time = addon.G.time

--- Only notify player of version updates once per session
local hasNotifiedVersion
local updateNotificationsEnabled
local knownVersionInfo

local function saveVersionInfo(version, branch)
  version = version or addon.VERSION
  branch = branch or addon.BRANCH

  knownVersionInfo.version = version
  knownVersionInfo.branch = branch
  knownVersionInfo.date = time()
  addon.SaveData:Save("KnownVersionInfo", knownVersionInfo, true)
end

local function loadVersionInfo()
  knownVersionInfo = addon.SaveData:LoadTable("KnownVersionInfo", true)

  if not knownVersionInfo.version then
    -- Nothing is saved, save current addon version as highest known version
    saveVersionInfo()
    return
  end

  local ttl = addon.Config:GetValue("VERSION_INFO_TTL")
  local expires = knownVersionInfo.date + ttl
  if time() > expires then
    -- Cached version info is expired, overwrite w/ current version info
    saveVersionInfo()
  end
end

local function notifyVersion(version, branch)
  if version > knownVersionInfo.version then
    saveVersionInfo(version, branch)
    if updateNotificationsEnabled and not hasNotifiedVersion then
      local newVersionText = addon:GetVersionText(version, branch)
      addon.Logger:Warn("A new version of PMQ is available (%s).", newVersionText)
      hasNotifiedVersion = true
    end
  end
end

local function tellVersion(event, distro, target)
  MessageEvents:Publish(event,
    { distribution = distro, target = target, priority = MessagePriority.Bulk },
    addon.VERSION, addon.BRANCH)
end

function addon:BroadcastAddonVersion()
  tellVersion("AddonVersionRequest", MessageDistribution.Yell)
  tellVersion("AddonVersionRequest", MessageDistribution.Guild)
end

function addon:RequestAddonVersion(distro, target)
  tellVersion("AddonVersionRequest", distro, target)
end

addon:OnBackendStart(function()
  loadVersionInfo()
  updateNotificationsEnabled = addon.Config:GetValue("ENABLE_UPDATE_NOTIFICATIONS")

  MessageEvents:Subscribe("AddonVersionRequest", function(distribution, sender, version, branch)
    notifyVersion(version, branch)
    tellVersion("AddonVersionResponse", MessageDistribution.Whisper, sender)
  end)
  MessageEvents:Subscribe("AddonVersionResponse", function(distribution, sender, version, branch)
    notifyVersion(version, branch)
  end)
end)

addon:OnAddonReady(function()
  addon:BroadcastAddonVersion()
end)