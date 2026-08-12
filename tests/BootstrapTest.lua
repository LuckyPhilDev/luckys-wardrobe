-- luacheck: globals CreateFrame IsShiftKeyDown LuckyLog LuckyMinimap LuckyUtils LuckysWardrobe LuckysWardrobeDB SlashCmdList SLASH_LUCKYSWARDROBE1 SLASH_LUCKYSWARDROBE2

LuckysWardrobe = {}
LuckysWardrobeDB = nil
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

local conflictsChecked = false
LuckysWardrobe.AddonConflicts = {
    Init = function()
        conflictsChecked = true
    end,
}

local welcomeDB
local welcomeShown, welcomeReset = false, false
LuckysWardrobe.Welcome = {
    Init = function(_, db)
        welcomeDB = db
    end,
    Show = function()
        welcomeShown = true
    end,
    Reset = function()
        welcomeReset = true
    end,
}

LuckysWardrobe.Settings = {
    Init = function(_, db)
        initializedDB = db
    end,
    Open = function()
        opened = true
    end,
}

LuckysWardrobe.SetTracking = {
    Init = function(_, db)
        trackingDB = db
    end,
}

local trackedAppearancesDB
LuckysWardrobe.TrackedAppearances = {
    Init = function(_, db)
        trackedAppearancesDB = db
    end,
}

local wowheadDB
LuckysWardrobe.WowheadLink = {
    Init = function(_, db)
        wowheadDB = db
    end,
}

local itemTooltipsDB
LuckysWardrobe.ItemTooltips = {
    Init = function(_, db)
        itemTooltipsDB = db
    end,
}

local tooltipModelDB
LuckysWardrobe.TooltipModel = {
    Init = function(_, db)
        tooltipModelDB = db
    end,
}

LuckysWardrobe.SetSearch = {
    Init = function() end,
}

LuckysWardrobe.SetsBrowser = {
    Init = function() end,
}

local previewSlotsDB
LuckysWardrobe.PreviewSlots = {
    Init = function(_, db)
        previewSlotsDB = db
    end,
}

local extraSetsInitialized = false
LuckysWardrobe.ExtraSets = {
    Init = function()
        extraSetsInitialized = true
    end,
}

local customSetsInitialized = false
LuckysWardrobe.CustomSets = {
    Init = function()
        customSetsInitialized = true
    end,
}

local transmogSetsDB
LuckysWardrobe.TransmogSets = {
    Init = function(_, db)
        transmogSetsDB = db
    end,
}

local transmogItemsInitialized = false
LuckysWardrobe.TransmogItems = {
    Init = function()
        transmogItemsInitialized = true
    end,
}

local setNamesDB
LuckysWardrobe.TransmogSetNames = {
    Init = function(_, db)
        setNamesDB = db
    end,
}

local transmogExtraSetsInitialized = false
LuckysWardrobe.TransmogExtraSets = {
    Init = function()
        transmogExtraSetsInitialized = true
    end,
}

local reportedVerbose
local catalogueStarted = false
LuckysWardrobe.ExtraSetsCatalog = {
    Init = function()
        catalogueStarted = true
    end,
    PrintReport = function(_, verbose)
        reportedVerbose = verbose
    end,
}

local measurementsPrinted, measurementsReset
LuckysWardrobe.Perf = {
    PrintReport = function() measurementsPrinted = true end,
    Reset = function() measurementsReset = true end,
}

LuckysWardrobe.Transmog = {
    Init = function(_, db)
        transmogDB = db
    end,
}

LuckysWardrobe.SituationPresets = {
    Init = function(_, db)
        presetsDB = db
    end,
}

LuckysWardrobe.SituationLabels = {
    Init = function(_, db)
        labelsDB = db
    end,
}

LuckysWardrobe.SetCompletion = {
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

LuckysWardrobe.LootAlerts = {
    Init = function(_, db)
        alertsDB = db
    end,
}

LuckysWardrobe.Catalyst = {
    Init = function()
        catalystStarted = true
    end,
}

dofile("src/Strings.lua")
dofile("src/Utils.lua")
dofile("src/Defaults.lua")
dofile("src/Core.lua")

eventHandler(nil, "ADDON_LOADED", "Another_Addon")
assert(LuckysWardrobeDB == nil, "ignored another addon's load event")

eventHandler(nil, "ADDON_LOADED", "Luckys_Wardrobe")
assert(conflictsChecked, "looked for conflicting wardrobe addons")
assert(welcomeDB == LuckysWardrobeDB, "initialized the first-run note with saved variables")
assert(LuckysWardrobeDB.welcomeShown == false, "owed the first-run note by default")
assert(initializedDB == LuckysWardrobeDB, "initialized settings with saved variables")
assert(trackingDB == LuckysWardrobeDB, "initialized set tracking with saved variables")
assert(trackedAppearancesDB == LuckysWardrobeDB, "initialized the tracked appearance marks with saved variables")
assert(wowheadDB == LuckysWardrobeDB, "initialized Wowhead links with saved variables")
assert(itemTooltipsDB == LuckysWardrobeDB, "initialized item tooltips with saved variables")
assert(tooltipModelDB == LuckysWardrobeDB, "initialized the tooltip preview model with saved variables")
assert(catalogueStarted, "set the Extra Sets catalogue building without waiting for Collections")
assert(extraSetsInitialized, "initialized the Extra Sets subtab")
assert(customSetsInitialized, "initialized the Custom Sets subtab")
assert(previewSlotsDB == LuckysWardrobeDB, "initialized the preview slots with saved variables")
assert(type(LuckysWardrobeDB.hiddenSetSlots) == "table", "applied the preview-slots default")
assert(transmogSetsDB == LuckysWardrobeDB, "initialized the transmogrifier Sets tab with saved variables")
assert(transmogItemsInitialized, "initialized the transmogrifier Items tab")
assert(transmogExtraSetsInitialized, "initialized the transmogrifier Extra Sets tab")
assert(setNamesDB == LuckysWardrobeDB, "initialized the set card names with saved variables")
assert(transmogDB == LuckysWardrobeDB, "initialized transmog tab memory with saved variables")
assert(presetsDB == LuckysWardrobeDB, "initialized situation presets with saved variables")
assert(type(LuckysWardrobeDB.situationPresets) == "table", "applied the situation presets default")
assert(labelsDB == LuckysWardrobeDB, "initialized situation labels with saved variables")
assert(completionDB == LuckysWardrobeDB, "initialized the set tracker with saved variables")
assert(alertsDB == LuckysWardrobeDB, "initialized loot alerts with saved variables")
assert(catalystStarted, "started the catalyst module")
assert(LuckysWardrobeDB.showInstanceSets == true, "opened the instance set list by default")
assert(LuckysWardrobeDB.instanceSetsMaxMissing == 3, "applied the missing-piece limit default")
assert(LuckysWardrobeDB.includeCurrentTier == false, "left the current tier out by default")
assert(LuckysWardrobeDB.includeOtherClassSets == false, "left other classes' sets out by default")
assert(LuckysWardrobeDB.instanceSetsDwellSeconds == 4, "applied the dwell default")
assert(type(LuckysWardrobeDB.instanceSetsPosition) == "table", "applied the window position default")
assert(LuckysWardrobeDB.alertSetPieceLoot == true, "alerted on set pieces by default")
assert(LuckysWardrobeDB.alertWithSound == true and LuckysWardrobeDB.alertWithChat == true,
    "alerted through both sound and chat by default")
assert(LuckysWardrobeDB.showSituationValues == true, "enabled situation values by default")
assert(LuckysWardrobeDB.showSituationTooltips == true, "enabled situation tooltips by default")
assert(LuckysWardrobeDB.devMode == false, "applied database defaults")
assert(LuckysWardrobeDB.keepTransmogTab == false, "disabled transmog tab memory by default")
assert(LuckysWardrobeDB.hideUnwearableSets == true, "hid sets this character cannot wear by default")
assert(LuckysWardrobeDB.showSetNames == true, "named the set cards by default")
assert(LuckysWardrobeDB.trackSetsOnShiftClick == true, "enabled set tracking by default")
assert(LuckysWardrobeDB.markTrackedAppearances == true, "marked tracked appearances by default")
assert(LuckysWardrobeDB.tooltipSetProgress == true, "said which set a piece belongs to by default")
assert(logCreated, "created development logger")
assert(SLASH_LUCKYSWARDROBE1 == "/wardrobe", "registered slash command")
assert(SLASH_LUCKYSWARDROBE2 == "/lw", "registered short slash alias")
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
SlashCmdList.LUCKYSWARDROBE()
assert(opened, "slash command opened settings")

setListToggled = false
opened = false
SlashCmdList.LUCKYSWARDROBE("sets")
assert(setListToggled and not opened, "/wardrobe sets opened the set list rather than settings")

opened = false
SlashCmdList.LUCKYSWARDROBE("welcome")
assert(welcomeShown and not opened, "/wardrobe welcome brought the note back rather than opening settings")

welcomeShown = false
SlashCmdList.LUCKYSWARDROBE("  WELCOME   Reset  ")
assert(welcomeReset and not welcomeShown, "/wardrobe welcome reset put it back on the slate, whatever the spacing and case")

opened = false
SlashCmdList.LUCKYSWARDROBE("scan")
assert(diagnosed and not opened, "/wardrobe scan reported the scan rather than opening settings")

opened = false
SlashCmdList.LUCKYSWARDROBE("replay")
assert(replayed and not opened, "/wardrobe replay redid the entry rather than opening settings")

opened = false
SlashCmdList.LUCKYSWARDROBE("extrasets")
assert(not opened and reportedVerbose == false, "extrasets printed the summary report")
SlashCmdList.LUCKYSWARDROBE("  ExtraSets   FULL  ")
assert(reportedVerbose == true, "extrasets full listed everything, whatever the spacing and case")

opened = false
SlashCmdList.LUCKYSWARDROBE("extrasets perf")
assert(not opened and measurementsPrinted, "extrasets perf printed what the page has measured")
SlashCmdList.LUCKYSWARDROBE("extrasets perf reset")
assert(measurementsReset, "extrasets perf reset cleared the measurements")

opened = false
SlashCmdList.LUCKYSWARDROBE("something else")
assert(opened, "an unrecognised argument still opens settings")

print("Lucky's Wardrobe bootstrap test passed")
