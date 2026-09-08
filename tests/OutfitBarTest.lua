-- luacheck: globals C_AddOns C_Spell Constants CooldownFrame_Clear CooldownFrame_Set C_Transmog C_TransmogOutfitInfo CreateFrame GameTooltip GameTooltip_Hide InCombatLockdown LuckyStrings LuckyUI LuckysWardrobe ScrollBoxListMixin TransmogFrame TransmogOutfitEntryMixin UIParent UISpecialFrames tinsert unpack

-- Covers where a tile's right-click is pointed: at Blizzard's own row while the
-- list holds one for that outfit, and at nothing once that row is dealt elsewhere.
-- The grid's own arithmetic is left alone.

LuckysWardrobe = {}

LuckyStrings = { New = function(_, tbl) return tbl end }
dofile("src/Strings.lua")

-- Every method the bar calls and nothing else, so a frame answers what it is asked
-- and a missing key stays missing. A catch-all metatable would hand back a function
-- for a cleared outfitID, and the clear tile would read as an outfit.
local NOOP_METHODS = {
    "SetSize", "SetPoint", "SetAllPoints", "SetFrameStrata", "SetFrameLevel",
    "RegisterEvent", "SetHighlightTexture", "SetPushedTexture",
    "SetTexture", "SetDesaturated", "SetVertexColor", "SetAtlas",
    "SetFont", "SetTextColor", "SetJustifyH", "SetWordWrap", "SetDrawBling", "SetHideCountdownNumbers",
}

local function makeFrame(name)
    local frame = { name = name, scripts = {}, attributes = {}, events = {} }
    for _, method in ipairs(NOOP_METHODS) do frame[method] = function() end end

    frame.RegisterEvent = function(self, event) self.events[event] = true end
    frame.SetText = function(self, text) self.text = text end
    frame.SetScript = function(self, script, handler) self.scripts[script] = handler end
    frame.RegisterForClicks = function(self, ...) self.clicks = table.concat({ ... }, " ") end
    frame.SetAttribute = function(self, key, value) self.attributes[key] = value end
    frame.GetAttribute = function(self, key) return self.attributes[key] end
    frame.CreateTexture = function() return makeFrame() end
    frame.CreateFontString = function() return makeFrame() end
    frame.GetName = function(self) return self.name end
    frame.GetStringWidth = function() return 0 end
    frame.IsShown = function(self) return self.shown == true end
    frame.Hide = function(self) self.shown = false end
    frame.ShowAutoCastEnabled = function(self, enabled) self.autoCast = enabled end

    frame.SetShown = function(self, shown)
        self.shown = shown and true or false
        if self.shown and self.scripts.OnShow then self.scripts.OnShow(self) end
    end
    frame.Show = function(self) self:SetShown(true) end

    return frame
end

local frames = {}
function CreateFrame(_, name)
    local frame = makeFrame(name)
    frames[#frames + 1] = frame
    return frame
end

local panel
UIParent, UISpecialFrames = {}, {}
tinsert = table.insert
-- The bar unpacks one colour, so three values is the whole of it.
unpack = function(colour) return colour[1], colour[2], colour[3] end -- luacheck: ignore 121
LuckyUI = {
    BODY_FONT = "font",
    C = setmetatable({}, { __index = function() return { 0, 0, 0 } end }),
    CreatePanel = function(name)
        panel = makeFrame(name)
        return panel
    end,
    CreateHeader = function(frame)
        frame.header = makeFrame()
        frame.titleText = makeFrame()
    end,
    EnableDrag = function() end,
    EnableAutoHide = function(frame, seconds)
        frame.autoHideSeconds = seconds
        frame.StartAutoHide = function(self) self.autoHiding = true end
        frame.StopAutoHide = function(self) self.autoHiding = false end
    end,
}

local tooltipLines = {}
GameTooltip = {
    SetOwner = function() end,
    SetText = function(_, text) tooltipLines = { text } end,
    AddLine = function(_, text) tooltipLines[#tooltipLines + 1] = text end,
    Show = function() end,
}
function GameTooltip_Hide() end

local inCombat = false
function InCombatLockdown() return inCombat end

C_AddOns = { IsAddOnLoaded = function() return true end, LoadAddOn = function() end }

local cooldownInfo = { startTime = 0, duration = 0, isEnabled = true }
Constants = { TransmogOutfitDataConsts = { EQUIP_TRANSMOG_OUTFIT_MANUAL_SPELL_ID = 9876 } }
C_Spell = { GetSpellCooldown = function(spellID)
    assert(spellID == Constants.TransmogOutfitDataConsts.EQUIP_TRANSMOG_OUTFIT_MANUAL_SPELL_ID)
    return cooldownInfo
end }
function CooldownFrame_Set(frame, startTime, duration, enabled)
    frame.startTime, frame.duration, frame.enabled = startTime, duration, enabled
end
function CooldownFrame_Clear(frame) frame.startTime, frame.duration = 0, 0 end


local CASUAL, RAID, HIDDEN = 7, 12, 30
local outfits = {
    { outfitID = CASUAL, name = "Casual", icon = "icon-casual", playerFacingOutfitIndex = 1 },
    { outfitID = RAID, name = "Raid", icon = "icon-raid", playerFacingOutfitIndex = 2 },
    { outfitID = HIDDEN, name = "Scrolled Away", icon = "icon-away", playerFacingOutfitIndex = 3 },
}

-- The outfit list virtualises, so only the rows it has rendered exist as frames.
-- The third outfit is scrolled out of the list and has none.
TransmogOutfitEntryMixin = { Init = function() end }

local function makeRow(outfitID)
    local row = { OutfitIcon = makeFrame("BlizzardOutfitIcon" .. outfitID) }
    row.Init = TransmogOutfitEntryMixin.Init
    row.elementData = { outfitID = outfitID }
    row.GetElementData = function(self) return self.elementData end
    return row
end

local renderedRows = { makeRow(CASUAL), makeRow(RAID) }
local clearTarget = makeFrame("BlizzardShowEquippedGear")
local windowShown, atNPC, windowShows = true, false, 0
local activeOutfitID = RAID
ScrollBoxListMixin = { Event = { OnInitializedFrame = "OnInitializedFrame", OnReleasedFrame = "OnReleasedFrame" } }
local rowCallbacks = {}
local function rowEvent(event, row)
    local callback = rowCallbacks[event]
    if callback then callback.func(callback.owner, row, row.elementData) end
end
local function initializeRow(row)
    row:Init(row.elementData)
    rowEvent(ScrollBoxListMixin.Event.OnInitializedFrame, row)
end

TransmogFrame = {
    OutfitCollection = {
        OutfitList = {
            ScrollBox = {
                RegisterCallback = function(_, event, func, owner)
                    assert(not rowCallbacks[event], "row callbacks are registered only once")
                    rowCallbacks[event] = { func = func, owner = owner }
                end,
                ForEachFrame = function(_, callback)
                    for _, row in ipairs(renderedRows) do callback(row) end
                end,
            },
        },
        ShowEquippedGearSpellFrame = { Button = clearTarget },
    },
    IsShown = function() return windowShown end,
    Hide = function() windowShown = false end,
}

C_Transmog = { IsAtTransmogNPC = function() return atNPC end }

-- Blizzard selects and scrolls to the active outfit when the window opens.
local RENDERED = 2
function TransmogFrame:Show()
    windowShown, windowShows = true, windowShows + 1
    renderedRows = {}
    local first = 1
    for index, outfit in ipairs(outfits) do
        if outfit.outfitID == activeOutfitID then first = math.max(1, index - RENDERED + 1) end
    end
    for index = first, math.min(#outfits, first + RENDERED - 1) do
        local row = makeRow(outfits[index].outfitID)
        renderedRows[#renderedRows + 1] = row
        initializeRow(row)
    end
end

local lockedOutfits = { [RAID] = true }
local gearDisplayed, gearLocked = false, false

local outfitReads = 0
C_TransmogOutfitInfo = {
    GetOutfitsInfo = function() outfitReads = outfitReads + 1; return outfits end,
    GetActiveOutfitID = function() return activeOutfitID end,
    IsLockedOutfit = function(outfitID) return lockedOutfits[outfitID] == true end,
    IsEquippedGearOutfitDisplayed = function() return gearDisplayed end,
    IsEquippedGearOutfitLocked = function() return gearLocked end,
}

dofile("src/features/transmogrifier/OutfitBar.lua")

local OutfitBar = LuckysWardrobe.OutfitBar
local strings = LuckysWardrobe.Strings.outfitBar

local function tile(index)
    for _, frame in ipairs(frames) do
        if frame.name == "LuckysWardrobeOutfitTile" .. index then return frame end
    end
end

local function hover(index)
    local frame = tile(index)
    frame.scripts.OnEnter(frame)
    return table.concat(tooltipLines, "\n")
end

local function refresh()
    panel.scripts.OnEvent()
end

local said
LuckysWardrobe.Utils = { Say = function(line) said = line end }

OutfitBar:Init({})
OutfitBar:Toggle()

-- The clear tile leads, so an outfit's tile is its position plus one.
local CLEAR, FIRST, SECOND, THIRD = 1, 2, 3, 4

assert(panel:IsShown(), "opening the bar shows the panel")
assert(panel.autoHiding, "and starts counting it down to closing itself again")
assert(panel.autoHideSeconds == 5, "over five seconds")

-- The press half of the click has to be registered even though the action runs on
-- the release, or the CVar default acts on a press the button never hears about.
assert(tile(FIRST).clicks:find("LeftButtonDown", 1, true), "a tile hears the press as well as the release")
assert(tile(FIRST).clicks:find("RightButtonDown", 1, true), "on both buttons")
assert(tile(FIRST):GetAttribute("useOnKeyDown") == false, "and acts on the release")

assert(tile(FIRST):GetAttribute("type") == "outfit", "a left-click still runs the outfit action")
assert(tile(FIRST):GetAttribute("action") == "toggle", "wearing an outfit toggles it")
assert(tile(FIRST):GetAttribute("outfit-index") == 1, "the action is given the player-facing index")

assert(tile(FIRST):GetAttribute("type2") == "click", "a right-click clicks a button instead")
assert(tile(FIRST):GetAttribute("clickbutton2") == renderedRows[1].OutfitIcon,
    "and the button is Blizzard's row for that outfit")
assert(tile(SECOND):GetAttribute("clickbutton2") == renderedRows[2].OutfitIcon,
    "each tile finds its own row")

assert(tile(THIRD):GetAttribute("type2") == nil, "an outfit the list has not rendered has nothing to click")
assert(tile(THIRD):GetAttribute("clickbutton2") == nil, "so no button is left pointed at")
assert(tile(THIRD):GetAttribute("type") == "outfit",
    "and its right-click falls through to wearing the outfit")
assert(tile(THIRD):GetAttribute("action2") == "change",
    "repeated right-clicks cannot remove the outfit while its lock target is missing")

assert(tile(CLEAR):GetAttribute("clickbutton2") == clearTarget,
    "the clear tile clicks the button for the gear you are wearing")
assert(tile(CLEAR):GetAttribute("action") == "clear", "while a left-click still clears")

-- Scrolling deals a rendered row to a different outfit, which is the moment a tile
-- still pointed at it would lock a stranger.
local recycled = renderedRows[1]
recycled.elementData = { outfitID = HIDDEN }
initializeRow(recycled)

assert(tile(FIRST):GetAttribute("clickbutton2") == nil, "the outfit that lost its row lets go of it")
assert(tile(FIRST):GetAttribute("type2") == nil, "and stops claiming a right-click")
assert(tile(THIRD):GetAttribute("clickbutton2") == recycled.OutfitIcon,
    "the outfit that gained the row picks it up")
assert(tile(SECOND):GetAttribute("clickbutton2") == renderedRows[2].OutfitIcon,
    "a tile whose row did not move is left alone")

assert(hover(THIRD):find(strings.lockHint, 1, true), "a tile that can lock says so")
assert(hover(FIRST):find(strings.lockPrepareHint, 1, true), "an offscreen outfit explains the two right-clicks")
assert(not hover(THIRD):find(strings.lockPrepareHint, 1, true), "a ready lock target needs no two-click warning")
assert(not hover(CLEAR):find(strings.lockPrepareHint, 1, true), "Clear needs no two-click warning")

assert(tile(SECOND).active.shown == true, "the outfit you are wearing is marked")
assert(tile(FIRST).locked.shown == false, "an unlocked outfit shows no shimmer")
assert(tile(SECOND).locked.shown == true and tile(SECOND).locked.autoCast == true,
    "a locked outfit shimmers")
assert(tile(CLEAR).locked.shown == false, "the clear tile carries no shimmer until it is locked")

assert(panel.activeName.text == "Raid", "the header names the outfit you are wearing")

gearDisplayed, gearLocked = true, true
refresh()
assert(tile(CLEAR).active.shown == true, "the clear tile is marked while your own gear is on")
assert(tile(CLEAR).locked.shown == true and tile(CLEAR).locked.autoCast == true,
    "locking your own gear shimmers on the clear tile")

-- A secure tile cannot be touched mid-fight, so the bar holds still and catches up
-- when the fight ends.
inCombat = true
lockedOutfits[RAID] = nil
activeOutfitID = CASUAL
refresh()
assert(tile(SECOND).locked.shown == true, "combat leaves the tiles as they were")
assert(panel.activeName.text == "Casual",
    "while a situation swapping outfits as the fight starts still renames the header")

inCombat = false
refresh()
assert(tile(SECOND).locked.shown == false, "and leaving combat brings them up to date")

-- The window was already open, so its rows were there to be found and there was no
-- call to borrow them.
assert(windowShows == 0, "an open window is left alone")

windowShown, atNPC = false, true
refresh()
assert(windowShows == 0, "and so is a transmogrifier, where closing it would end the visit")

atNPC = false
renderedRows = {}
refresh()
assert(windowShows == 1, "otherwise the window is opened and shut to build its rows")
assert(tile(FIRST):GetAttribute("clickbutton2") == renderedRows[1].OutfitIcon,
    "which is where the tiles find theirs")
assert(not windowShown, "and it does not stay open")

refresh()
assert(windowShows == 1, "the rows are borrowed once, not on every refresh")

local function postClick(index, down, button)
    local frame = tile(index)
    if frame.scripts.PostClick then frame.scripts.PostClick(frame, button or "LeftButton", down) end
end

postClick(THIRD, true)
assert(windowShows == 1, "the press does not prepare an outfit before its secure action")
postClick(THIRD, false)
assert(windowShows == 1, "the old active outfit is not borrowed before the equip completes")
activeOutfitID = HIDDEN
refresh()
assert(tile(THIRD):GetAttribute("clickbutton2") ~= nil,
    "a delayed outfit change prepares the lock target without another click")
assert(windowShows == 2 and not windowShown, "the missing target gets another native show/hide")
assert(tile(THIRD):GetAttribute("clickbutton2") == renderedRows[2].OutfitIcon,
    "the prepared target belongs to the selected outfit")
postClick(THIRD, false)
assert(windowShows == 2, "an available lock target needs no further show/hide")
assert(tile(THIRD):GetAttribute("action2") == nil, "a ready lock target drops the fallback action")

renderedRows = { makeRow(CASUAL), makeRow(RAID) }
refresh()
postClick(THIRD, false, "RightButton")
assert(windowShows == 3 and tile(THIRD):GetAttribute("clickbutton2") ~= nil,
    "a right-click that equips an offscreen outfit also prepares its next lock click")

activeOutfitID = CASUAL
inCombat = true
postClick(FIRST, false)
assert(windowShows == 3, "combat cannot prepare secure targets")
inCombat = false
atNPC = true
postClick(FIRST, false)
assert(windowShows == 3, "preparing a target cannot close a transmogrifier visit")
atNPC = false
windowShown = true
postClick(FIRST, false)
assert(windowShows == 3 and windowShown, "preparing a target leaves an open window alone")
windowShown = false
postClick(THIRD, false)
assert(windowShows == 3, "a click that did not equip its outfit does not reopen the window")
postClick(CLEAR, false)
assert(windowShows == 3, "clearing does not borrow an outfit row")

-- The list finishes scrolling after the equip event, reusing a pre-existing row.
activeOutfitID = HIDDEN
renderedRows = { recycled, makeRow(RAID) }
recycled.elementData = { outfitID = CASUAL }
windowShown = true
refresh()
windowShown = false
recycled.elementData = { outfitID = HIDDEN }
initializeRow(recycled)
assert(tile(THIRD):GetAttribute("clickbutton2") == recycled.OutfitIcon,
    "a row initialized after refresh is ready before the second click")
assert(tile(FIRST):GetAttribute("clickbutton2") == nil,
    "the previous outfit cannot click the recycled row")
rowEvent(ScrollBoxListMixin.Event.OnReleasedFrame, recycled)
assert(tile(THIRD):GetAttribute("clickbutton2") == nil,
    "releasing a row clears its lock target before another outfit reuses it")

activeOutfitID = 0
refresh()
assert(panel.activeName.text == strings.noOutfit, "the header says so when no outfit is in use")

-- The grid cannot be laid out mid-fight, so the bar declines to open rather than
-- opening empty.
panel:Hide()
inCombat = true
OutfitBar:Toggle()
assert(not panel:IsShown(), "the bar does not open in combat")
assert(said == strings.inCombat, "and says why")

inCombat = false
OutfitBar:Toggle()
assert(panel:IsShown(), "and opens again once the fight is over")

assert(panel.events.SPELL_UPDATE_COOLDOWN, "the bar listens for the shared outfit cooldown")
assert(tile(FIRST).cooldown and tile(FIRST).cooldown.duration == 0,
    "opening the bar initializes its cooldown display")
local previousOutfitReads = outfitReads
cooldownInfo = { startTime = 10, duration = 1.5, isEnabled = true }
inCombat = true
panel.scripts.OnEvent(panel, "SPELL_UPDATE_COOLDOWN")
assert(outfitReads == previousOutfitReads, "cooldown events do not rebuild the secure outfit grid")
for index = CLEAR, THIRD do
    assert(tile(index).cooldown.startTime == 10 and tile(index).cooldown.duration == 1.5,
        "every tile shows the shared outfit cooldown, including Clear")
end
cooldownInfo = nil
panel.scripts.OnEvent(panel, "SPELL_UPDATE_COOLDOWN")
for index = CLEAR, THIRD do
    assert(tile(index).cooldown.duration == 0, "missing cooldown information clears stale timers")
end
inCombat = false

print("OutfitBar tests passed")
