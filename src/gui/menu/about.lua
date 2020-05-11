local _, addon = ...
local CreateFrame = addon.G.CreateFrame

local menu = addon.MainMenu:NewMenuScreen([[help\about]], "About PMQ")

function menu:Create(parent)
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, 20)
  frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 20, 20)

  local label = frame:CreateFontString(nil, "BACKGROUND", "GameTooltipTextSmall")
  label:SetPoint("TOPLEFT", frame, "TOPLEFT")
  label:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT")
  label:SetText("About PMQ")
  label:SetAllPoints(true)

  return frame
end