local ADDON, ns = ...
local STONE_ITEM_ID = 94221
local STONE_ICON = "Interface\\AddOns\\ThunderCheck\\media\\icon_stone"

-- Table with quest IDs to track
local quests = {
    ["Loot: Incantation (Deng/Vu/Haqin)"] = 32611,
    ["Loot: Rare Mob (Ritual Stone)"]     = 32610,
    ["Loot: Key to the Palace"]           = 32626,
    ["Loot: Trove Chest"]                 = 32609,
    ["Quest: Champions of Thunder"]       = {32640, 32641},  -- faction-specific
    ["Quest: The Crumbled Chamberlain"]   = 32505,
	["Kill: Nalak (World Boss)"]		  = 32518,
}

-- Set fixed display order
local questOrder = {
    "Loot: Incantation (Deng/Vu/Haqin)",
    "Loot: Rare Mob (Ritual Stone)",
    "Loot: Key to the Palace",
    "Loot: Trove Chest",
    "Quest: Champions of Thunder",
    "Quest: The Crumbled Chamberlain",
	"Kill: Nalak (World Boss)",
}

-- LibDataBroker object
local LDB = LibStub("LibDataBroker-1.1"):NewDataObject("ThunderCheck", {
    type = "data source",
    text = "Thunder Check (0/7)",  -- initial text
    icon = "Interface\\AddOns\\ThunderCheck\\media\\icon.tga",
})

-- Count Shan'ze Ritual Stones
local function GetStoneCount()
    local count = GetItemCount(STONE_ITEM_ID, true) -- true = include bank
    return count or 0
end

local function UpdateStatus()
    -- ensure account-wide DB exists
	ThunderCheckDB = ThunderCheckDB or {}
	ThunderCheckDB.settings = ThunderCheckDB.settings or {}
    local charKey = UnitName("player") .. "-" .. GetRealmName()
    ThunderCheckDB[charKey] = ThunderCheckDB[charKey] or {}
	
	-- Store class/level/stone data
	local _, class = UnitClass("player")
	local level = UnitLevel("player")
	ThunderCheckDB[charKey].class = class
	ThunderCheckDB[charKey].level = level
	ThunderCheckDB[charKey].stones = GetStoneCount()
    local complete, total = 0, 0

    for _, key in ipairs(questOrder) do
        total = total + 1
        local questID = quests[key]
        local done = false  -- default

        if type(questID) == "table" then
            for _, id in ipairs(questID) do
                local status = C_QuestLog.IsQuestFlaggedCompleted(id)
                if status then
                    done = true
                    break
                end
            end
        elseif questID then
            local status = C_QuestLog.IsQuestFlaggedCompleted(questID)
            if status then done = true end
        end

        -- safe assignment
        ThunderCheckDB[charKey][key] = done
        if done then complete = complete + 1 end
    end

    LDB.text = "Thunder Check (" .. complete .. "/" .. #questOrder .. ")"

    if complete == #questOrder then
        LDB.icon = "Interface\\AddOns\\ThunderCheck\\media\\icon_green.tga"
    else
        LDB.icon = "Interface\\AddOns\\ThunderCheck\\media\\icon_red.tga"
    end
end


-- Options menu
	local menuFrame = CreateFrame("Frame", "ThunderCheckRightClickMenu", UIParent, "UIDropDownMenuTemplate")

	local function ToggleHideDone()
		ThunderCheckDB.settings.hideDone = not ThunderCheckDB.settings.hideDone
		UpdateStatus()
	end

	local function ShowMenu(anchor)
		local menuList = {
        {
            text = "Show/Hide Done Quests",
            func = ToggleHideDone,
            checked = ThunderCheckDB.settings.hideDone
        },
        {
            text = "Close",
            func = function() end
        }
    }
    local function initialize(self, level)
        for _, info in ipairs(menuList) do
            UIDropDownMenu_AddButton(info, level)
        end
    end

    UIDropDownMenu_Initialize(menuFrame, initialize, "MENU")
    ToggleDropDownMenu(1, nil, menuFrame, anchor, 0, 0, "MENU")
end


	LDB.OnClick = function(self, button)
    if button == "RightButton" then
        ShowMenu("cursor")
    else
        UpdateStatus()
    end
end


-- Tooltip
function LDB:OnTooltipShow()
    GameTooltip:AddLine("Isle of Thunder Weekly Progress")
    GameTooltip:AddLine(" ")

for storedCharKey, charData in pairs(ThunderCheckDB) do
    if storedCharKey ~= "settings" and charData.level == 90 then
        -- Get class color from stored class
        local class = charData.class
        local color = RAID_CLASS_COLORS[class] or { r = 1, g = 1, b = 1 }

        -- Count completed quests
        local complete = 0
        for _, key in ipairs(questOrder) do
            if charData[key] then
                complete = complete + 1
            end
        end

        -- Character line: name and progress formatted in colours
        local charNameColored = string.format("|cff%02x%02x%02x%s|r",
            color.r*255, color.g*255, color.b*255,
            storedCharKey
        )
        local progressText = string.format("|cffffffff(%d/%d)|r", complete, #questOrder)
		local stoneCount = charData.stones or 0
		local stoneText = string.format("|T%s:14:14:0:0|t x%d", STONE_ICON, stoneCount)

		GameTooltip:AddDoubleLine(
			charNameColored .. "  " .. stoneText,
			progressText
		)

        -- Quest statuses under character
        local hideDone = ThunderCheckDB.settings.hideDone
        for _, key in ipairs(questOrder) do
            local done = charData[key]
            if not (hideDone and done) then
                GameTooltip:AddDoubleLine(
                    "  " .. key,
                    done and "|cff00ff00Done|r" or "|cffff0000Not Done|r"
                )
            end
        end

        GameTooltip:AddLine(" ")
		end
	end
end


-- Events
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("QUEST_TURNED_IN")
f:RegisterEvent("QUEST_COMPLETE")
f:RegisterEvent("BAG_UPDATE")
f:RegisterEvent("BANKFRAME_OPENED")
f:RegisterEvent("BANKFRAME_CLOSED")

f:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN"
       or event == "QUEST_TURNED_IN"
       or event == "QUEST_COMPLETE"
	   or event == "QUEST_LOG_UPDATE"
       or event == "BAG_UPDATE"
       or event == "BANKFRAME_OPENED"
       or event == "BANKFRAME_CLOSED" then
        UpdateStatus()
    end
end)