local _, addon = ...
local QuestRewards, QuestRewardStatus = addon.QuestRewards, addon.QuestRewardStatus
local QuestLog, QuestArchive = addon.QuestLog, addon.QuestArchive
local StaticPopups = addon.StaticPopups
local CreateFrame = addon.G.CreateFrame

local rewardRows = {}

local menu = addon.MainMenu:NewMenuScreen("QuestRewardsMenu")

local rewardStatusText = {}

addon:OnGuiStart(function()
  -- Delayed because colors aren't available when the file is loaded
  rewardStatusText = {
    [QuestRewardStatus.Unclaimed] = addon:Colorize("red", "Unclaimed"),
    [QuestRewardStatus.MailSent] = addon:Colorize("yellow", "Sent"),
    [QuestRewardStatus.MailReceived] = addon:Colorize("green", "Received"),
    [QuestRewardStatus.Traded] = addon:Colorize("green", "Traded"),
    [QuestRewardStatus.Claimed] = addon:Colorize("green", "Claimed"),
  }
end)

local options = {
  colInfo = {
    {
      name = "Reward",
      width = { flexSize = 3, min = 60 },
      align = "LEFT",

    },
    {
      name = "From",
      width = { flexSize = 2, min = 60 },
      align = "LEFT",
    },
    {
      name = "Status",
      width = 65,
      align = "CENTER"
    },
  },
  dataSource = function()
    rewardRows = {}
    local rewards = QuestRewards:FindAll()
    table.sort(rewards, function(a, b) return a.rewardId < b.rewardId end)

    for _, reward in ipairs(rewards) do
      local rewardText = addon.QuestRewards:GetRewardName(reward)

      local givers = ""
      if #reward.givers == 1 then
        givers = reward.givers[1]
      elseif #reward.givers > 1 then
        givers = string.format("%s (+%i more)", reward.givers[1], #reward.givers - 1)
      end

      local status = ""
      if reward.status then
        status = rewardStatusText[reward.status] or reward.status
      end

      local row = {
        rewardText,
        givers,
        status,
        -- Hidden cols
        reward.rewardId,
      }

      rewardRows[#rewardRows+1] = row
    end
    return rewardRows
  end,
  buttons = {
    {
      text = "View Quest Info",
      anchor = "TOP",
      enabled = "Row",
      handler = function(reward, dataTable)
        local quest = QuestLog:FindByID(reward.questId)
        if not quest then
          quest = QuestArchive:FindByID(reward.questId)
          if not quest then
            addon.Logger:Warn("Unable to show quest info: quest is no longer available in log or archive")
            return
          end
        end
        addon.QuestInfoFrame:ShowQuest(quest, "TerminatedQuest")
        dataTable:ClearSelection()
      end,
    },
    {
      text = "Mark Claimed",
      anchor = "TOP",
      enabled = "Row",
      condition = function(reward)
        return reward.status ~= QuestRewardStatus.Claimed
      end,
      handler = function(reward, dataTable)
        reward.status = QuestRewardStatus.Claimed
        QuestRewards:Save(reward)
      end,
    },
    {
      text = "Clear All",
      anchor = "BOTTOM",
      enabled = "Always",
      handler = function()
        StaticPopups:Show("ResetRewards")
      end,
    },
    {
      text = "Clear Claimed",
      anchor = "BOTTOM",
      enabled = "Conditional",
      condition = function()
        return #QuestRewards:FindClaimedRewards() > 0
      end,
      handler = function()
        StaticPopups:Show("DeleteClaimedRewards")
      end,
    },
    {
      text = "Delete",
      anchor = "BOTTOM",
      enabled = "Row",
      handler = function(reward)
        StaticPopups:Show("DeleteReward", reward)
      end,
    },
  }
}

function menu:Create(frame)
  local textinfo = {
    static = true,
    styles = addon.DefaultArticleTextStyle,
    text = {
      {
        style = "page-header",
        text = "Quest Rewards",
      },
      {
        style = "default",
        text = "When you complete a quest that offers money or item rewards, they will be shown here. "..
               "Message the players listed below to find out how to claim your rewards.",
      }
    }
  }

  local article = addon.CustomWidgets:CreateWidget("ArticleText", frame, textinfo)
  article:ClearAllPoints(true)
  article:SetPoint("TOPLEFT", frame, "TOPLEFT")
  article:SetPoint("TOPRIGHT", frame, "TOPRIGHT")
  article:SetHeight(90)

  local dtFrame = CreateFrame("Frame", nil, frame)
  dtFrame:SetPoint("TOPLEFT", article, "BOTTOMLEFT")
  dtFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT")

  local dtwb = addon.CustomWidgets:CreateWidget("DataTableWithButtons", dtFrame, options)
  local dataTable = dtwb:GetDataTable()
  dataTable:SubscribeMethodToEvents("RefreshData", "RewardDataLoaded", "RewardAdded", "RewardUpdated", "RewardDeleted", "RewardDataReset")
  dataTable:SubscribeMethodToEvents("ClearSelection", "RewardDataLoaded", "RewardDeleted", "RewardDataReset")
  dataTable:OnGetSelectedItem(function(row)
    return QuestRewards:FindByID(row[4])
  end)

  frame.dataTable = dataTable
end

function menu:OnShowMenu(frame)
  frame.dataTable:RefreshData()
  frame.dataTable:EnableUpdates(true)
end

function menu:OnLeaveMenu(frame)
  frame.dataTable:EnableUpdates(false)
end