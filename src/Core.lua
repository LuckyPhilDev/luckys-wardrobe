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
    LuckyMinimap:Create({
        name = "LuckysEnsembleMinimapButton",
        icon = "Interface\\GossipFrame\\transmogrifyGossipIcon.blp",
        dbKey = "minimap",
        db = LuckysEnsembleDB,
        defaultAngle = 160,
        onClick = function(_, mouseButton)
            if mouseButton == "RightButton" then
                LuckysEnsemble.Settings:Open()
            end
        end,
        tooltip = function(tooltip)
            tooltip:AddLine(LuckysEnsemble.Strings.addon.title)
            tooltip:AddLine(" ")
            tooltip:AddLine("Right-click: Open settings", 0.91, 0.86, 0.78)
            tooltip:AddLine("Drag: Move button", 0.54, 0.49, 0.42)
        end,
    })
    LuckysEnsemble.DevLog(LuckysEnsemble.Strings.addon.initialized)

    SLASH_LUCKYSENSEMBLE1 = "/ensemble"
    SlashCmdList.LUCKYSENSEMBLE = function()
        LuckysEnsemble.Settings:Open()
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(_, _, loadedAddon)
    if loadedAddon ~= ADDON_NAME then return end
    eventFrame:UnregisterEvent("ADDON_LOADED")
    initialize()
end)
