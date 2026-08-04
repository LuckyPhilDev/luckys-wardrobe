-- luacheck: globals CreateFrame IsShiftKeyDown LuckyLog LuckyMinimap LuckyUtils LuckysEnsemble LuckysEnsembleDB SlashCmdList SLASH_LUCKYSENSEMBLE1

LuckysEnsemble = {}
LuckysEnsembleDB = nil
SlashCmdList = {}

local eventHandler
local logCreated = false
local opened = false
local initializedDB
local minimapOptions
local trackingDB
local transmogDB
local presetsDB
local labelsDB
local completionDB
local alertsDB
local catalystStarted
local setListToggled
local diagnosed
local replayed

local shiftDown = false
function IsShiftKeyDown()
    return shiftDown
end

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

LuckysEnsemble.SetTracking = {
    Init = function(_, db)
        trackingDB = db
    end,
}

LuckysEnsemble.SetsBrowser = {
    Init = function() end,
}

LuckysEnsemble.Transmog = {
    Init = function(_, db)
        transmogDB = db
    end,
}

LuckysEnsemble.SituationPresets = {
    Init = function(_, db)
        presetsDB = db
    end,
}

LuckysEnsemble.SituationLabels = {
    Init = function(_, db)
        labelsDB = db
    end,
}

LuckysEnsemble.SetCompletion = {
    Init = function(_, db)
        completionDB = db
    end,
    Toggle = function()
        setListToggled = true
    end,
    Diagnose = function()
        diagnosed = true
    end,
    ReplayEntry = function()
        replayed = true
    end,
}

LuckysEnsemble.LootAlerts = {
    Init = function(_, db)
        alertsDB = db
    end,
}

LuckysEnsemble.Catalyst = {
    Init = function()
        catalystStarted = true
    end,
}

dofile("src/Strings.lua")
dofile("src/Defaults.lua")
dofile("src/Core.lua")

eventHandler(nil, "ADDON_LOADED", "Another_Addon")
assert(LuckysEnsembleDB == nil, "ignored another addon's load event")

eventHandler(nil, "ADDON_LOADED", "Luckys_Ensemble")
assert(initializedDB == LuckysEnsembleDB, "initialized settings with saved variables")
assert(trackingDB == LuckysEnsembleDB, "initialized set tracking with saved variables")
assert(transmogDB == LuckysEnsembleDB, "initialized transmog tab memory with saved variables")
assert(presetsDB == LuckysEnsembleDB, "initialized situation presets with saved variables")
assert(type(LuckysEnsembleDB.situationPresets) == "table", "applied the situation presets default")
assert(labelsDB == LuckysEnsembleDB, "initialized situation labels with saved variables")
assert(completionDB == LuckysEnsembleDB, "initialized the set tracker with saved variables")
assert(alertsDB == LuckysEnsembleDB, "initialized loot alerts with saved variables")
assert(catalystStarted, "started the catalyst module")
assert(LuckysEnsembleDB.showInstanceSets == true, "opened the instance set list by default")
assert(LuckysEnsembleDB.instanceSetsMaxMissing == 3, "applied the missing-piece limit default")
assert(LuckysEnsembleDB.includeCurrentTier == false, "left the current tier out by default")
assert(LuckysEnsembleDB.includeOtherClassSets == false, "left other classes' sets out by default")
assert(LuckysEnsembleDB.instanceSetsDwellSeconds == 4, "applied the dwell default")
assert(type(LuckysEnsembleDB.instanceSetsPosition) == "table", "applied the window position default")
assert(LuckysEnsembleDB.alertSetPieceLoot == true, "alerted on set pieces by default")
assert(LuckysEnsembleDB.alertWithSound == true and LuckysEnsembleDB.alertWithChat == true,
    "alerted through both sound and chat by default")
assert(LuckysEnsembleDB.showSituationValues == true, "enabled situation values by default")
assert(LuckysEnsembleDB.showSituationTooltips == true, "enabled situation tooltips by default")
assert(LuckysEnsembleDB.devMode == false, "applied database defaults")
assert(LuckysEnsembleDB.keepTransmogTab == false, "disabled transmog tab memory by default")
assert(LuckysEnsembleDB.trackSetsOnShiftClick == true, "enabled set tracking by default")
assert(logCreated, "created development logger")
assert(SLASH_LUCKYSENSEMBLE1 == "/ensemble", "registered slash command")
assert(minimapOptions, "created minimap button")

minimapOptions.onClick(nil, "LeftButton")
assert(not opened, "left-click did not open settings")
minimapOptions.onClick(nil, "RightButton")
assert(opened, "right-click opened settings")

-- Hiding the minimap button is a supported setting, so the list has a slash command
-- and a keybinding as well. All three reach the same toggle.
shiftDown = true
minimapOptions.onClick(nil, "LeftButton")
assert(setListToggled, "shift-click opened the set list")
shiftDown = false

opened = false
SlashCmdList.LUCKYSENSEMBLE()
assert(opened, "slash command opened settings")

setListToggled = false
opened = false
SlashCmdList.LUCKYSENSEMBLE("sets")
assert(setListToggled and not opened, "/ensemble sets opened the set list rather than settings")

opened = false
SlashCmdList.LUCKYSENSEMBLE("scan")
assert(diagnosed and not opened, "/ensemble scan reported the scan rather than opening settings")

opened = false
SlashCmdList.LUCKYSENSEMBLE("replay")
assert(replayed and not opened, "/ensemble replay redid the entry rather than opening settings")

print("Lucky's Ensemble bootstrap test passed")
