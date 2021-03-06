local _, addon = ...
local logger = addon.Logger:NewLogger("Share")
local QuestCatalogStatus, QuestStatus = addon.QuestCatalogStatus, addon.QuestStatus
local MessageEvents, MessageDistribution = addon.MessageEvents, addon.MessageDistribution
local IsInGroup, IsInRaid = addon.G.IsInGroup, addon.G.IsInRaid

local function getNewerQuest(q1, s1, q2, s2)
  if (not q1 or not q1.metadata) and (not q2 or not q2.metadata) then
    error("Cannot determine newer question version - neither quest contains version information")
  elseif (q1 and q1.metadata) and (not q2 or not q2.metadata) then
    -- Quest 1 can be version-checked, but quest 2 cannot
    return q1, s1
  elseif (q2 and q2.metadata) and (not q1 or not q1.metadata) then
    -- Quest 2 can be version-checked, but quest 1 cannot
    return q2, s2
  end

  if q2.metadata.compileDate == nil then
    return q1, s1
  elseif q2.metadata.compileDate > q1.metadata.compileDate and q2.metadata.hash ~= q1.metadata.hash then
    -- q2 must be more recently compiled AND have a different hash in order to overtake q1
    return q2, s2
  end

  return q1, s1
end

local function findNewestQuestVersion(quest)
  local questId, source = quest.questId, "Shared"

  quest, source = getNewerQuest(quest, source, addon.QuestCatalog:FindByID(questId), "QuestCatalog")
  quest, source = getNewerQuest(quest, source, addon.QuestLog:FindByID(questId), "QuestLog")
  quest, source = getNewerQuest(quest, source, addon.QuestArchive:FindByID(questId), "QuestArchive")

  addon.Logger:Trace("Newest quest version resolved: %s (%s)", source, tostring(quest.metadata.compileDate))
  return quest, source
end

-- Suppression flag was added for unit tests
function addon:ShareQuest(quest, suppressMetadata)
  assert(type(quest) == "table", "Failed to ShareQuest: a quest must be provided")

  -- Make a copy for sharing, and clean the current player's status/progress from it
  quest = addon:CopyTable(quest)
  addon:CleanQuest(quest)
  addon.QuestEngine:Validate(quest) -- Sanity check, don't want to send players broken quests

  if not suppressMetadata then
    quest.metadata.giverName = addon:GetPlayerName()
    quest.metadata.giverRealm = addon:GetPlayerRealm()
    quest.metadata.giverGuild = addon:GetPlayerGuildName()
  end

  local opts = {}
  if IsInRaid() then
    opts.distribution = MessageDistribution.Raid
  elseif IsInGroup() then
    opts.distribution = MessageDistribution.Party
  else
    addon.Logger:Warn("You must be in a party or raid group to share a quest.")
    return
  end

  MessageEvents:Publish("QuestInvite", opts, quest)
  addon.Logger:Warn("Sharing quest %s...", quest.name)
end

addon:OnBackendStart(function()
  local considerDuplicate = {
    [QuestStatus.Active] = {
      message = "%s is already on that quest."
    },
    [QuestStatus.Finished] = {
      message = "%s has finished that quest, but has not turned it in.",
    },
    [QuestStatus.Completed] = {
      message = "%s has completed that quest."
    }
  }

  MessageEvents:Subscribe("QuestInvite", function(distribution, sender, quest)
    if quest.quest then
      -- The payload is probably a QuestCatalog item, stop handling now
      -- todo: come up with a better method for handling version incompatibilities
      addon.Logger:Warn("%s tried to share a quest with you, but their addon is out-of-date.", sender)
      addon.Logger:Warn("Please ask them to update PMQ to %s or later and restart their game.", addon:GetVersionText())
      MessageEvents:Publish("QuestInviteDeclined", { distribution = MessageDistribution.Whisper, target = sender })
      return
    end

    -- Need to determine the most recent known version of this quest from all possible sources
    local source
    quest, source = findNewestQuestVersion(quest)
    addon:CleanQuest(quest) -- Failsafe: erase any previous progress from quest, in case it got sent over
    addon.QuestEngine:Validate(quest) -- Sanity check: ensure quest is playable before proceeding

    -- Once we've found the most recent one, perform any migrations (if necessary) to bring the quest up to the current addon version
    local ok, err = addon:MigrateQuest(quest)
    if not ok then
      addon.Logger:Warn("%s tried to share a quest with you, but there was a migration error: %s", sender, err)
      addon.Logger:Warn("Please ask them to update PMQ to %s or later and restart their game.", addon:GetVersionText())
      MessageEvents:Publish("QuestInviteDeclined", { distribution = MessageDistribution.Whisper, target = sender })
      return
    end

    -- Get or create the catalog entry for this quest
    local doSaveCatalog, catalogQuestVersionUpdated = false, false
    local catalogItem = addon.QuestCatalog:FindByID(quest.questId)
    if not catalogItem then
      catalogItem = addon.QuestCatalog:NewCatalogItem(quest)
      doSaveCatalog = true
    else
      -- If necessary, update the catalog to have the now-latest known version of the quest
      quest, source = getNewerQuest(catalogItem.quest, "QuestCatalog", quest, source)
      if source ~= "QuestCatalog" then
        catalogItem.quest = quest
        doSaveCatalog = true
        catalogQuestVersionUpdated = true
      end
    end

    -- If there were any updates made to the catalog entry (or a new entry was created), save it now
    -- Update the "from" information to be whoever sent this QuestInvite
    if doSaveCatalog then
      addon.QuestCatalog:Save(catalogItem, QuestCatalogStatus.Invited)
    end

    -- Now that we have catalogued the latest version of the quest, how do we notify the receiving player?
    local duplicateStatus

    -- Quest is considered a duplicate if it's already in the log or archive with a recognized "duplicate" status
    local questLogQuest = addon.QuestLog:FindByID(quest.questId)
    if questLogQuest and considerDuplicate[questLogQuest.status] then
      logger:Trace("Quest is duplicate: already in log with status '%s'", questLogQuest.status)
      duplicateStatus = questLogQuest.status
    else
      local archiveQuest = addon.QuestArchive:FindByID(quest.questId)
      if archiveQuest and considerDuplicate[archiveQuest.status] then
        logger:Trace("Quest is duplicate: already in archive with status '%s'", archiveQuest.status)
        duplicateStatus = archiveQuest.status
      end
    end

    -- If the quest is a duplicate, simply notify the receiver that a quest in their catalog has been updated
    if duplicateStatus then
      MessageEvents:Publish("QuestInviteDuplicate", { distribution = MessageDistribution.Whisper, target = sender }, quest.questId, duplicateStatus)
      if catalogQuestVersionUpdated then
        addon.Logger:Warn("%s shared a new version of a quest: %s", sender, quest.name)
        addon.Logger:Warn("Start this quest from your Catalog to play this new version.")
      end
      return
    end

    addon.Logger:Warn("%s has invited you to a quest: %s", sender, catalogItem.quest.name)

    -- Finally, check the quest's requirements to ensure the player can start it
    local meetsRequirements = addon.QuestEngine:EvaluateRequirements(quest)
    if meetsRequirements then
      logger:Trace("Quest requirements met, showing QuestInfoFrame")
      if addon.QuestInfoFrame then
        addon.QuestInfoFrame:ShowQuest(catalogItem.quest)
      end
    else
      addon.Logger:Warn("You do not meet the requirements, but it has been saved to your Catalog.")
      MessageEvents:Publish("QuestInviteRequirements", { distribution = MessageDistribution.Whisper, target = sender }, quest.questId)
    end
  end)

  MessageEvents:Subscribe("QuestInviteAccepted", function(distribution, sender, questId)
    addon.Logger:Warn("%s has accepted your quest.", sender)
  end)
  MessageEvents:Subscribe("QuestInviteDeclined", function(distribution, sender, questId)
    addon.Logger:Warn("%s has declined your quest.", sender)
  end)
  MessageEvents:Subscribe("QuestInviteDuplicate", function(distribution, sender, questId, status)
    if status and considerDuplicate[status] then
      addon.Logger:Warn(considerDuplicate[status].message, sender)
    end
  end)
  MessageEvents:Subscribe("QuestInviteRequirements", function(distribution, sender, questId)
    addon.Logger:Warn("%s does not meet the requirements for that quest.", sender)
  end)

  -- Respond to certain quest actions by notifying the sender
  local function notifySender(quest, event)
    if quest.metadata.giverName then
      MessageEvents:Publish(event, { distribution = MessageDistribution.Whisper, target = quest.metadata.giverName }, quest.questId)
    end
  end

  addon.AppEvents:Subscribe("QuestAccepted", function(quest)
    notifySender(quest, "QuestInviteAccepted")
  end)
  addon.AppEvents:Subscribe("QuestDeclined", function(quest)
    notifySender(quest, "QuestInviteDeclined")
  end)
end)