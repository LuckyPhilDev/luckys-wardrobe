-- Lucky's Ensemble: Addon initialization.
LuckysEnsemble = LuckysEnsemble or {}

local ADDON_NAME = "Luckys_Ensemble"

local function initialize()
    LuckysEnsembleDB = LuckysEnsembleDB or {}
    LuckyUtils.ApplyDefaults(LuckysEnsembleDB, LuckysEnsemble.DB_DEFAULTS)
    LuckysEnsemble.DevLog = LuckyLog:New(LuckysEnsemble.Strings.addon.prefix, function()
        return LuckysEnsembleDB.devMode
    end)

    LuckysEnsemble.Settings:Init(LuckysEnsembleDB)
    LuckysEnsemble.SetsBrowser:Init()
    LuckysEnsemble.SetTracking:Init(LuckysEnsembleDB)
    LuckysEnsemble.SetCompletion:Init(LuckysEnsembleDB)
    LuckysEnsemble.LootAlerts:Init(LuckysEnsembleDB)
    LuckysEnsemble.Catalyst:Init()
    LuckysEnsemble.Transmog:Init(LuckysEnsembleDB)
    LuckysEnsemble.SituationLabels:Init(LuckysEnsembleDB)
    LuckysEnsemble.SituationPresets:Init(LuckysEnsembleDB)
    LuckyMinimap:Create({
        name = "LuckysEnsembleMinimapButton",
        icon = "Interface\\GossipFrame\\transmogrifyGossipIcon.blp",
        dbKey = "minimap",
        db = LuckysEnsembleDB,
        defaultAngle = 160,
        onClick = function(_, mouseButton)
            if mouseButton == "RightButton" then
                LuckysEnsemble.Settings:Open()
            elseif IsShiftKeyDown() then
                LuckysEnsemble.SetCompletion:Toggle()
            end
        end,
        tooltip = function(tooltip)
            tooltip:AddLine(LuckysEnsemble.Strings.addon.title)
            tooltip:AddLine(" ")
            tooltip:AddLine("Shift-click: Sets you can finish here", 0.91, 0.86, 0.78)
            tooltip:AddLine("Right-click: Open settings", 0.91, 0.86, 0.78)
            tooltip:AddLine("Drag: Move button", 0.54, 0.49, 0.42)
        end,
    })
    LuckysEnsemble.DevLog(LuckysEnsemble.Strings.addon.initialized)

    SLASH_LUCKYSENSEMBLE1 = "/ensemble"
    SlashCmdList.LUCKYSENSEMBLE = function(input)
        local command = (input or ""):match("^%s*(%S*)"):lower()
        if command == "sets" then
            LuckysEnsemble.SetCompletion:Toggle()
        elseif command == "scan" then
            LuckysEnsemble.SetCompletion:Diagnose()
        elseif command == "replay" then
            LuckysEnsemble.SetCompletion:ReplayEntry()
        else
            LuckysEnsemble.Settings:Open()
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
