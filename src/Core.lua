-- Lucky's Wardrobe: Addon initialization.
LuckysWardrobe = LuckysWardrobe or {}

local ADDON_NAME = "Luckys_Wardrobe"

local function initialize()
    LuckysWardrobeDB = LuckysWardrobeDB or {}
    LuckyUtils.ApplyDefaults(LuckysWardrobeDB, LuckysWardrobe.DB_DEFAULTS)
    LuckysWardrobe.DevLog = LuckyLog:New(LuckysWardrobe.Strings.addon.prefix, function()
        return LuckysWardrobeDB.devMode
    end)

    LuckysWardrobe.Settings:Init(LuckysWardrobeDB)
    LuckysWardrobe.SetsBrowser:Init()
    LuckysWardrobe.ExtraSets:Init()
    LuckysWardrobe.SetTracking:Init(LuckysWardrobeDB)
    LuckysWardrobe.SetCompletion:Init(LuckysWardrobeDB)
    LuckysWardrobe.LootAlerts:Init(LuckysWardrobeDB)
    LuckysWardrobe.Catalyst:Init()
    LuckysWardrobe.Transmog:Init(LuckysWardrobeDB)
    LuckysWardrobe.SituationLabels:Init(LuckysWardrobeDB)
    LuckysWardrobe.SituationPresets:Init(LuckysWardrobeDB)
    LuckyMinimap:Create({
        name = "LuckysWardrobeMinimapButton",
        icon = "Interface\\GossipFrame\\transmogrifyGossipIcon.blp",
        dbKey = "minimap",
        db = LuckysWardrobeDB,
        defaultAngle = 160,
        onClick = function(_, mouseButton)
            if mouseButton == "RightButton" then
                LuckysWardrobe.Settings:Open()
            elseif IsShiftKeyDown() then
                LuckysWardrobe.SetCompletion:Toggle()
            end
        end,
        tooltip = function(tooltip)
            tooltip:AddLine(LuckysWardrobe.Strings.addon.title)
            tooltip:AddLine(" ")
            tooltip:AddLine("Shift-click: Sets you can finish here", 0.91, 0.86, 0.78)
            tooltip:AddLine("Right-click: Open settings", 0.91, 0.86, 0.78)
            tooltip:AddLine("Drag: Move button", 0.54, 0.49, 0.42)
        end,
    })
    LuckysWardrobe.DevLog(LuckysWardrobe.Strings.addon.initialized)

    SLASH_LUCKYSWARDROBE1 = "/wardrobe"
    SLASH_LUCKYSWARDROBE2 = "/lw"
    SlashCmdList.LUCKYSWARDROBE = function(input)
        local command = (input or ""):match("^%s*(%S*)"):lower()
        if command == "sets" then
            LuckysWardrobe.SetCompletion:Toggle()
        elseif command == "scan" then
            LuckysWardrobe.SetCompletion:Diagnose()
        elseif command == "replay" then
            LuckysWardrobe.SetCompletion:ReplayEntry()
        else
            LuckysWardrobe.Settings:Open()
        end
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(_, _, loadedAddon)
    if loadedAddon ~= ADDON_NAME then return end
    eventFrame:UnregisterEvent("ADDON_LOADED")
    initialize()
end)
