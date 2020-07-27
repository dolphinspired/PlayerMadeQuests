local _, addon = ...
local QuestLog, QuestStatus = addon.QuestLog, addon.QuestStatus
local QuestArchive = addon.QuestArchive

addon.StaticPopupsList = {
  ["AbandonQuest"] = {
    message = function(quest)
      return "Are you sure you want to abandon\n"..
             "\"%s\"?", quest.name
    end,
    yesText = "OK",
    noText = "Cancel",
    yesHandler = function(quest)
      QuestLog:SaveWithStatus(quest, QuestStatus.Abandoned)
      addon:PlaySound("QuestAbandoned")
      addon.Logger:Warn("Quest abandoned: %s", quest.name)
    end,
  },
  ["ArchiveQuest"] = {
    message = function(quest)
      return "Archive \"%s\"?\n"..
             "This will hide the quest from your Quest Log, but PMQ will remember that you completed it.", quest.name
    end,
    yesText = "OK",
    noText = "Cancel",
    yesHandler = function(quest)
      QuestArchive:Save(quest)
      QuestLog:Delete(quest)
    end,
  },
  ["DeleteQuest"] = {
    message = function(quest)
      return "Are you sure you want to delete \"%s\"?\n"..
             "This will delete the quest entirely from your log, and PMQ will forget you ever had it!", quest.name
    end,
    yesText = "OK",
    noText = "Cancel",
    yesHandler = function(quest)
      QuestLog:Delete(quest.questId)
      addon.Logger:Warn("Quest deleted: %s", quest.name)
    end,
  },
  ["ResetQuestLog"] = {
    message = "Are you sure you want to reset your quest log?\n"..
              "This will delete ALL quests in your log!",
    yesText = "OK",
    noText = "Cancel",
    yesHandler = function()
      QuestLog:DeleteAll()
      addon:PlaySound("QuestAbandoned")
      addon.Logger:Warn("Quest Log reset")
    end,
  },
  ["RetryQuest"] = {
    message = function(quest)
      if quest.status == QuestStatus.Finished then
        -- Provide an additional warning only if the quest has already been successfully finished
        return "Replay \"%s\"?\n"..
               "This will erase your previous completion of this quest.", quest.name
      else
        return "Replay \"%s\"?", quest.name
      end
    end,
    yesText = "OK",
    noText = "Cancel",
    yesHandler = function(quest)
      QuestLog:SaveWithStatus(quest, QuestStatus.Active)
      if QuestArchive:FindByID(quest.questId) then
        -- If the quest was in the archive, remove it from there
        QuestArchive:Delete(quest.questId)
      end
    end,
  },
  ["StartQuestBelowRequirements"] = {
    message = function(quest, recsResult)
      return "You do not meet the recommended criteria to start this quest.\n"..
             "Accept anyway?"
    end,
    yesText = "OK",
    noText = "Cancel",
    yesHandler = function() end, -- Need an empty function to trigger the OnYes handler
  },
  ["DeleteCatalogItem"] = {
    message = function(catalogItem)
      return "Are you sure you want to delete\n"..
             "\"%s\"?", catalogItem.quest.name
    end,
    yesText = "OK",
    noText = "Cancel",
    yesHandler = function(catalogItem)
      addon.QuestCatalog:Delete(catalogItem.quest.questId)
      addon.Logger:Warn("Catalog item deleted: %s", catalogItem.quest.name)
    end,
  },
  ["ExitDraft"] = {
    message = "You have unsaved changes.\n"..
              "Would you like to save?",
    yesText = "Discard",
    noText = "Cancel",
    otherText = "Save",
    yesHandler = function()
      addon.MainMenu:NavToMenuScreen("drafts")
    end,
    otherHandler = function(saveFunction)
      saveFunction()
      addon.MainMenu:NavToMenuScreen("drafts")
    end,
  },
  ["DeleteDraft"] = {
    message = function(draftId, draftName)
      return "Are you sure you want to delete\n"..
             "\"%s\"?", draftName
    end,
    yesText = "OK",
    noText = "Cancel",
    yesHandler = function(draftId, draftName)
      addon.QuestDrafts:Delete(draftId)
      addon.Logger:Warn("Draft deleted: %s", draftName)
    end,
  },
  ["DeleteArchive"] = {
    message = function(quest)
      return "Are you sure you want to delete \"%s\"?\n"..
             "This will delete the quest entirely from your archive, and PMQ will forget you ever had it!", quest.name
    end,
    yesText = "OK",
    noText = "Cancel",
    yesHandler = function(quest)
      QuestArchive:Delete(quest.questId)
      addon.Logger:Warn("Quest removed from archive: %s", quest.name)
    end,
  },
  ["ResetArchive"] = {
    message = "Are you sure you want to reset your quest archive?\n"..
              "This will remove all quests from your archive, and PMQ will forget you ever had them!",
    yesText = "OK",
    noText = "Cancel",
    yesHandler = function()
      QuestArchive:DeleteAll()
      addon:PlaySound("QuestAbandoned")
      addon.Logger:Warn("Quest Archive reset")
    end,
  },
  ["ResetSaveData"] = {
    message = "Are you sure you want to clear all save data?\n"..
              "This will remove all drafts, quests, quest progress, and settings from PMQ.\n"..
              "Once you click, there is no going back! This cannot be undone!",
    yesText = "OK",
    noText = "Cancel",
    yesHandler = function()
      addon.SaveData:ClearAll()
      addon.SaveData:ClearAll(true)
      addon.G.ReloadUI()
    end,
  },
}