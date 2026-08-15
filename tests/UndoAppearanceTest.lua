-- luacheck: globals C_TransmogOutfitInfo Enum EventUtil IsModifiedClick LuckysWardrobe PlaySound SOUNDKIT TransmogItemModelMixin

LuckysWardrobe = {}

Enum = {
    TransmogType = { Appearance = 0, Illusion = 1 },
    TransmogOutfitSlotOption = { None = 0, MainHand = 1 },
    TransmogOutfitDisplayType = { Unassigned = 0, Assigned = 1, Equipped = 2, Hidden = 3 },
}

SOUNDKIT = { UI_TRANSMOG_REVERTING_GEAR_SLOT = "revert" }

local soundsPlayed = {}
function PlaySound(sound) table.insert(soundsPlayed, sound) end

EventUtil = {
    ContinueOnAddOnLoaded = function(_, callback) callback() end,
}

local modifiers = {}
function IsModifiedClick(action) return modifiers[action] == true end

local HEAD, MAINHAND = 0, 12
local HELM_VISUAL, HELM_SOURCE = 100, 1000
local OTHER_VISUAL, OTHER_SOURCE = 200, 2000
local ILLUSION_SOURCE = 3000

local sourceOfVisual = {
    [HELM_VISUAL] = HELM_SOURCE,
    [OTHER_VISUAL] = OTHER_SOURCE,
}

local function makeLocation(slot, transmogType)
    return {
        GetSlot = function() return slot end,
        GetType = function() return transmogType end,
        IsAppearance = function() return transmogType == Enum.TransmogType.Appearance end,
    }
end

local headLocation = makeLocation(HEAD, Enum.TransmogType.Appearance)
local illusionLocation = makeLocation(MAINHAND, Enum.TransmogType.Illusion)

local slotInfos = {}
local reverts = {}

C_TransmogOutfitInfo = {
    GetViewedOutfitSlotInfo = function(slot, transmogType, option)
        local info = slotInfos[slot]
        if not info then return nil end
        return {
            transmogID = info.transmogID,
            displayType = info.displayType,
            hasPending = info.hasPending,
            askedType = transmogType,
            askedOption = option,
        }
    end,
    RevertPendingTransmog = function(slot, transmogType, option)
        table.insert(reverts, { slot = slot, transmogType = transmogType, option = option })
    end,
}

-- The grid stamps its cards from this mixin after we have wrapped it, so the
-- cards below are built the way the grid builds one.
local stockClicks = {}
TransmogItemModelMixin = {
    OnMouseDown = function(_, button) table.insert(stockClicks, button) end,
    CanCheckDressUpClick = function() return false end,
}

local selectedSlot

local collection = {
    GetSelectedSlotCallback = function() return selectedSlot end,
    GetAnAppearanceSourceFromVisual = function(_, visualID) return sourceOfVisual[visualID] end,
}

local function card(appearanceInfo)
    local model = {
        GetAppearanceInfo = function() return appearanceInfo end,
        GetCollectionFrame = function() return collection end,
    }
    model.CanCheckDressUpClick = TransmogItemModelMixin.CanCheckDressUpClick
    return model
end

local helmCard = card({ visualID = HELM_VISUAL })
local otherCard = card({ visualID = OTHER_VISUAL })
local illusionCard = card({ visualID = 0, sourceID = ILLUSION_SOURCE })

dofile("src/Strings.lua")
dofile("src/UndoAppearance.lua")

local db = { undoOnSecondClick = true }
LuckysWardrobe.UndoAppearance:Init(db)

local function click(model, button)
    stockClicks, reverts, soundsPlayed = {}, {}, {}
    TransmogItemModelMixin.OnMouseDown(model, button or "LeftButton")
end

-- The helm is queued on the head slot, which is the slot being dressed.
selectedSlot = { transmogLocation = headLocation, currentWeaponOptionInfo = nil }
slotInfos[HEAD] = {
    transmogID = HELM_SOURCE,
    displayType = Enum.TransmogOutfitDisplayType.Assigned,
    hasPending = true,
}

click(helmCard)
assert(#reverts == 1, "undid the queued change on a second click")
assert(#stockClicks == 0, "did not also queue the appearance again")
assert(reverts[1].slot == HEAD and reverts[1].transmogType == Enum.TransmogType.Appearance,
    "reverted the slot being dressed")
assert(reverts[1].option == Enum.TransmogOutfitSlotOption.None,
    "reverted the armour slot option where the slot names none")
assert(soundsPlayed[1] == SOUNDKIT.UI_TRANSMOG_REVERTING_GEAR_SLOT, "played the revert sound")

click(otherCard)
assert(#reverts == 0 and #stockClicks == 1, "left a click on any other appearance alone")

-- Nothing queued: the slot is already wearing the helm, so there is nothing to
-- put back and the click stays an ordinary selection.
slotInfos[HEAD].hasPending = false
click(helmCard)
assert(#reverts == 0 and #stockClicks == 1, "left the appearance the slot already wears alone")

slotInfos[HEAD].hasPending = true
for _, displayType in ipairs({
    Enum.TransmogOutfitDisplayType.Unassigned,
    Enum.TransmogOutfitDisplayType.Equipped,
}) do
    slotInfos[HEAD].displayType = displayType
    click(helmCard)
    assert(#reverts == 0 and #stockClicks == 1, "left a slot with nothing picked out alone")
end
slotInfos[HEAD].displayType = Enum.TransmogOutfitDisplayType.Hidden
click(helmCard)
assert(#reverts == 1, "undid a queued hidden slot")

slotInfos[HEAD].displayType = Enum.TransmogOutfitDisplayType.Assigned

-- Clicks that already belong to somebody else.

click(helmCard, "RightButton")
assert(#reverts == 0 and #stockClicks == 1, "left the right button to the context menu")

modifiers.CHATLINK = true
click(helmCard)
assert(#reverts == 0 and #stockClicks == 1, "left shift-click to the chat link")
modifiers.CHATLINK = false

modifiers.DRESSUP = true
click(helmCard)
assert(#reverts == 1, "took ctrl-click where the card does not offer the dressing room")
TransmogItemModelMixin.CanCheckDressUpClick = function() return true end
helmCard.CanCheckDressUpClick = TransmogItemModelMixin.CanCheckDressUpClick
click(helmCard)
assert(#reverts == 0 and #stockClicks == 1, "left ctrl-click to the dressing room where it is offered")
TransmogItemModelMixin.CanCheckDressUpClick = function() return false end
helmCard.CanCheckDressUpClick = TransmogItemModelMixin.CanCheckDressUpClick
modifiers.DRESSUP = false

-- An illusion carries its own source rather than standing for a visual.

selectedSlot = {
    transmogLocation = illusionLocation,
    currentWeaponOptionInfo = { weaponOption = Enum.TransmogOutfitSlotOption.MainHand },
}
slotInfos[MAINHAND] = {
    transmogID = ILLUSION_SOURCE,
    displayType = Enum.TransmogOutfitDisplayType.Assigned,
    hasPending = true,
}
click(illusionCard)
assert(#reverts == 1, "undid a queued illusion")
assert(reverts[1].option == Enum.TransmogOutfitSlotOption.MainHand,
    "reverted the weapon option the slot names")

-- Nothing to read the slot off.

selectedSlot = nil
click(helmCard)
assert(#reverts == 0 and #stockClicks == 1, "left the click alone with no slot selected")

selectedSlot = { transmogLocation = headLocation }
slotInfos[HEAD] = nil
click(helmCard)
assert(#reverts == 0 and #stockClicks == 1, "left the click alone with no slot info")

-- The setting hands the click back.

slotInfos[HEAD] = {
    transmogID = HELM_SOURCE,
    displayType = Enum.TransmogOutfitDisplayType.Assigned,
    hasPending = true,
}
db.undoOnSecondClick = false
click(helmCard)
assert(#reverts == 0 and #stockClicks == 1, "respected the disabled setting")

print("Lucky's Wardrobe undo appearance test passed")
