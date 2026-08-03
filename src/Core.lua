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
