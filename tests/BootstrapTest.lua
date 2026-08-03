-- luacheck: globals CreateFrame LuckyLog LuckyMinimap LuckyUtils LuckysEnsemble LuckysEnsembleDB SlashCmdList SLASH_LUCKYSENSEMBLE1

LuckysEnsemble = {}
LuckysEnsembleDB = nil
SlashCmdList = {}

local eventHandler
local logCreated = false
local opened = false
local initializedDB
local minimapOptions

function CreateFrame()
    return {
        RegisterEvent = function() end,
        UnregisterEvent = function() end,
        SetScript = function(_, _, handler)
            eventHandler = handler
        end,
    }
end

LuckyUtils = {
    ApplyDefaults = function(target, defaults)
        for key, value in pairs(defaults) do
            if target[key] == nil then target[key] = value end
        end
    end,
}

LuckyLog = {
    New = function()
        logCreated = true
        return function() end
    end,
}

LuckyMinimap = {
    Create = function(_, options)
        minimapOptions = options
        return {}
    end,
}

LuckysEnsemble.Settings = {
    Init = function(_, db)
        initializedDB = db
    end,
    Open = function()
        opened = true
    end,
}

dofile("src/Strings.lua")
dofile("src/Defaults.lua")
dofile("src/Core.lua")

eventHandler(nil, "ADDON_LOADED", "Another_Addon")
assert(LuckysEnsembleDB == nil, "ignored another addon's load event")

eventHandler(nil, "ADDON_LOADED", "Luckys_Ensemble")
assert(initializedDB == LuckysEnsembleDB, "initialized settings with saved variables")
assert(LuckysEnsembleDB.devMode == false, "applied database defaults")
assert(logCreated, "created development logger")
assert(SLASH_LUCKYSENSEMBLE1 == "/ensemble", "registered slash command")
assert(minimapOptions, "created minimap button")

minimapOptions.onClick(nil, "LeftButton")
assert(not opened, "left-click did not open settings")
minimapOptions.onClick(nil, "RightButton")
assert(opened, "right-click opened settings")

opened = false
SlashCmdList.LUCKYSENSEMBLE()
assert(opened, "slash command opened settings")

print("Lucky's Ensemble bootstrap test passed")
