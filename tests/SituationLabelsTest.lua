-- luacheck: globals C_Timer C_TransmogOutfitInfo CreateFrame EventUtil GRAY_FONT_COLOR GameTooltip GameTooltip_AddHighlightLine GameTooltip_Hide GameTooltip_SetTitle LuckyUI LuckysWardrobe TRANSMOG_SITUATION_CATEGORY_LIST_SEPARATOR TransmogFrame TransmogOutfitEntryMixin UnitGUID hooksecurefunc unpack

LuckysWardrobe = {}

LuckyStrings = { New = function(_, tbl) return tbl end }
dofile("src/Strings.lua")

unpack = unpack or table.unpack -- luacheck: ignore 143

local function stubRegion()
    return setmetatable({}, {
        __index = function(self, key)
            local method
            if key == "CreateTexture" or key == "CreateFontString" then
                method = function() return stubRegion() end
            else
                method = function() end
            end
            rawset(self, key, method)
            return method
        end,
    })
end

local eventFrames = {}
function CreateFrame()
    local frame = stubRegion()
    frame.registered = {}
    frame.RegisterEvent = function(_, event) frame.registered[event] = true end
    frame.UnregisterEvent = function(_, event) frame.registered[event] = nil end
    frame.SetScript = function(_, script, handler) frame[script] = handler end
    eventFrames[#eventFrames + 1] = frame
    return frame
end

local timers = {}
C_Timer = { After = function(_, callback) timers[#timers + 1] = callback end }
local function runTimers()
    local queued = timers
    timers = {}
    for _, callback in ipairs(queued) do callback() end
end

TRANSMOG_SITUATION_CATEGORY_LIST_SEPARATOR = ", "
GRAY_FONT_COLOR = { WrapTextInColorCode = function(_, text) return "|gray|" .. text .. "|r" end }
UnitGUID = function() return "Player-Test-GUID" end
EventUtil = { ContinueOnAddOnLoaded = function(_, callback) callback() end }
LuckyUI = {
    CreatePanel = function() return stubRegion() end,
    TITLE_FONT = "title",
    BODY_FONT = "body",
    C = setmetatable({}, { __index = function() return { 1, 1, 1 } end }),
    Backdrop = {},
}

function hooksecurefunc(target, method, callback)
    local original = target[method]
    target[method] = function(...)
        original(...)
        callback(...)
    end
end

-- Mirrors Blizzard's entry Init: every (re)initialize resets the situation line
-- back to plain category names, which the addon hook must override again.
TransmogOutfitEntryMixin = {}
function TransmogOutfitEntryMixin:Init(elementData)
    self.elementData = elementData
    local text = table.concat(elementData.situationCategories or {}, TRANSMOG_SITUATION_CATEGORY_LIST_SEPARATOR)
    self.OutfitButton.TextContent.SituationInfo:SetText(text)
    self.OutfitButton.TextContent.SituationInfo:SetShown(text ~= "")
end

local tooltip = { lines = {} }
GameTooltip = { SetOwner = function() end, SetPoint = function() end, Show = function() end }
GameTooltip_SetTitle = function(_, title) tooltip.title = title end
GameTooltip_AddHighlightLine = function(_, line) tooltip.lines[#tooltip.lines + 1] = line end
GameTooltip_Hide = function() end

local categories = {
    { name = "Zone", groupData = { { optionData = {
        { name = "Rested Areas", option = { situationID = 1 } },
        { name = "Cities", option = { situationID = 2 } },
    } } } },
    { name = "Combat", groupData = { { optionData = {
        { name = "In Combat", option = { situationID = 3 } },
    } } } },
}

local outfitSelections = {
    [10] = { [1] = true, [2] = true },
    [20] = { [3] = true },
}
local viewedOutfitID = 10
local outfits = {
    { outfitID = 10, situationCategories = { "Zone" } },
    { outfitID = 20, situationCategories = { "Zone", "Combat" } },
    { outfitID = 30, situationCategories = {} },
}
local fireEvents = true

C_TransmogOutfitInfo = {
    GetUISituationCategoriesAndOptions = function() return categories end,
    GetOutfitSituation = function(option)
        local selections = outfitSelections[viewedOutfitID]
        return selections and selections[option.situationID]
    end,
    GetOutfitsInfo = function() return outfits end,
    GetCurrentlyViewedOutfitID = function() return viewedOutfitID end,
    HasPendingOutfitSituations = function() return false end,
    HasPendingOutfitTransmogs = function() return false end,
    ChangeViewedOutfit = function(outfitID)
        viewedOutfitID = outfitID
        if fireEvents and eventFrames[1].OnEvent then
            eventFrames[1].OnEvent(nil, "VIEWED_TRANSMOG_OUTFIT_SITUATIONS_CHANGED")
        end
    end,
}

local entries = {}

TransmogFrame = {
    IsShown = function() return true end,
    OutfitCollection = {
        OutfitList = { ScrollBox = {
            ForEachFrame = function(_, apply)
                for _, entry in ipairs(entries) do apply(entry) end
            end,
        } },
    },
}

dofile("src/features/transmogrifier/SituationLabels.lua")

local labels = LuckysWardrobe.SituationLabels

local presetNames = {}
local allowedExtras
LuckysWardrobe.SituationPresets = {
    NameFor = function(_, values, maxExtras)
        allowedExtras = maxExtras
        return values and presetNames[values.Zone]
    end,
}

local db = {
    showSituationValues = true,
    showSituationTooltips = true,
    situationLabels = { ["Player-Test-GUID"] = { [99] = { Zone = "Cities" } } },
}
labels:Init(db)

-- The pool copies methods off the mixin after the hook has landed, exactly as
-- frames created after Blizzard_Transmog loads do in the client.
local function makeEntry(elementData)
    local entry = {}
    entry.elementData = elementData
    entry.Init = TransmogOutfitEntryMixin.Init
    entry.GetElementData = function() return entry.elementData end
    entry.OutfitButton = {
        TextContent = {
            SituationInfo = {
                SetShown = function(_, isShown) entry.infoShown = isShown end,
                SetText = function(_, text) entry.infoText = text end,
                IsShown = function() return entry.infoShown end,
            },
            Layout = function() end,
        },
        HookScript = function(button, script, handler) button[script] = handler end,
    }
    entries[#entries + 1] = entry
    entry:Init(elementData)
    return entry
end

local entry10 = makeEntry({ outfitID = 10, name = "Sunny", situationCategories = { "Zone" } })
local entry20 = makeEntry({ outfitID = 20, name = "Grim", situationCategories = { "Zone", "Combat" } })
local entry30 = makeEntry({ outfitID = 30, name = "Plain", situationCategories = {} })

assert(entry10.infoText == "Zone", "showed the category name before anything was cached")
assert(entry10.OutfitButton.OnEnter, "installed the tooltip hook from the entry initializer")

local frame = eventFrames[1]
frame.OnEvent(nil, "TRANSMOGRIFY_OPEN")
assert(frame.registered["TRANSMOG_OUTFITS_CHANGED"], "listened for outfit changes while open")
assert(frame.registered["VIEWED_TRANSMOG_OUTFIT_SITUATIONS_CHANGED"], "listened for situation changes while open")

runTimers()

local cache = db.situationLabels["Player-Test-GUID"]
assert(viewedOutfitID == 10, "restored the originally viewed outfit after the scan")
assert(cache[10].Zone == "Rested Areas+Cities", "read the viewed outfit without switching")
assert(cache[20].Combat == "In Combat", "scanned the unviewed outfit")
assert(type(cache[30]) == "table" and next(cache[30]) == nil, "cached an outfit without situations as empty")
assert(cache[99] == nil, "pruned a deleted outfit from the cache")
assert(entry10.infoText == "Rested Areas+Cities", "showed selected values on the entry")
assert(entry10.infoShown, "kept the situation line visible")
assert(entry20.infoText == "Zone, In Combat", "fell back to the category name when nothing is selected")
assert(entry30.infoShown == false, "hid the situation line without categories")

entry10:Init(entry10.elementData)
assert(entry10.infoText == "Rested Areas+Cities", "kept values on an entry recycled by scrolling")

runTimers()

outfitSelections[10] = { [2] = true }
frame.OnEvent(nil, "VIEWED_TRANSMOG_OUTFIT_SITUATIONS_CHANGED")
assert(cache[10].Zone == "Cities", "re-read the viewed outfit when its situations changed")
assert(entry10.infoText == "Cities", "refreshed the entry after the change")

entry20.OutfitButton.OnEnter()
assert(tooltip.title == "Grim", "titled the tooltip with the outfit name")
assert(tooltip.lines[1] == "Zone", "listed an unselected category by name alone")
assert(tooltip.lines[2] == "|gray|Combat:|r In Combat", "listed selected values under a grey category label")

db.showSituationValues = false
labels:Refresh()
assert(entry10.infoText == "Zone", "showed the category name when values are toggled off")

db.showSituationTooltips = false
tooltip.title = nil
tooltip.lines = {}
entry20.OutfitButton.OnEnter()
assert(tooltip.title == nil, "suppressed the tooltip when toggled off")

db.showSituationValues = true
db.showSituationTooltips = true

db.showSituationPresetNames = true
presetNames["Cities"] = "Errands"
labels:Refresh()
assert(entry10.infoText == "Errands", "named an outfit after the saved situation it matches")
assert(entry20.infoText == "Zone, In Combat", "kept the situation detail on an outfit matching nothing")
assert(entry30.infoShown == false, "left an outfit without situations unnamed")

assert(allowedExtras == 0, "allowed no extra values until the near match setting is on")

db.showSituationPresetExtras = true
db.situationPresetExtraLimit = 2
labels:Refresh()
assert(allowedExtras == 2, "passed on the extra values the player allows")

tooltip.title, tooltip.lines = nil, {}
entry10.OutfitButton.OnEnter()
assert(tooltip.lines[1] == "|gray|Zone:|r Cities", "kept the full detail in a named outfit's tooltip")

outfits[#outfits + 1] ={ outfitID = 40, situationCategories = { "Zone" } }
fireEvents = false
frame.OnEvent(nil, "TRANSMOG_OUTFITS_CHANGED")
assert(cache[40] == nil, "scan stayed pending while the outfit change was unconfirmed")
frame.OnEvent(nil, "TRANSMOGRIFY_CLOSE")
assert(not frame.registered["TRANSMOG_OUTFITS_CHANGED"], "stopped listening while closed")

fireEvents = true
frame.OnEvent(nil, "TRANSMOGRIFY_OPEN")
runTimers()
assert(type(cache[40]) == "table", "cached the interrupted outfit on the next open")
assert(viewedOutfitID == 40, "read the now-viewed outfit directly instead of switching away")

print("Lucky's Wardrobe situation labels test passed")
