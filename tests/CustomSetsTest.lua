-- luacheck: globals Constants INVSLOT_BACK INVSLOT_BODY INVSLOT_CHEST INVSLOT_FEET INVSLOT_HAND INVSLOT_HEAD INVSLOT_LEGS INVSLOT_MAINHAND INVSLOT_OFFHAND INVSLOT_SHOULDER INVSLOT_TABARD INVSLOT_WAIST INVSLOT_WRIST LuckysWardrobe

-- What an outfit is worth showing is decided entirely from what the client says
-- about the looks it holds, so these drive the rules with a stubbed client: a
-- slot left bare, a slot hidden on purpose, a slot the client has yet to answer
-- for, and a slot wearing two looks at once all count differently.

LuckysWardrobe = {}

Constants = { Transmog = { NoTransmogID = 0 } }

INVSLOT_HEAD, INVSLOT_BODY, INVSLOT_CHEST = 1, 4, 5
INVSLOT_WAIST, INVSLOT_LEGS, INVSLOT_FEET = 6, 7, 8
INVSLOT_WRIST, INVSLOT_HAND, INVSLOT_SHOULDER = 9, 10, 3
INVSLOT_BACK, INVSLOT_MAINHAND, INVSLOT_OFFHAND, INVSLOT_TABARD = 15, 16, 17, 19

dofile("src/features/journal/CustomSets.lua")

local CustomSets = LuckysWardrobe.CustomSets

local HELM, SHOULDERS, OTHER_SHOULDERS = 101, 102, 103
local CHEST, SWORD, HIDDEN_CLOAK, UNKNOWN = 104, 105, 106, 107

-- Whether each look is one the character owns. Nothing at all is the client not
-- having answered yet, which is a third state and not a refusal.
local collected = {
    [HELM] = true,
    [SHOULDERS] = true,
    [OTHER_SHOULDERS] = false,
    [CHEST] = false,
    [SWORD] = true,
    [HIDDEN_CLOAK] = true,
}

local hidden = { [HIDDEN_CLOAK] = true }
local secondarySlots = { [INVSLOT_SHOULDER] = true }

local function look(appearanceID, secondaryAppearanceID)
    return { appearanceID = appearanceID, secondaryAppearanceID = secondaryAppearanceID or appearanceID }
end

local sets = {}

local resolver = {
    setInfo = function(customSetID) return sets[customSetID].name, sets[customSetID].icon end,
    setPieces = function(customSetID) return sets[customSetID].looks end,
    isCollected = function(sourceID) return collected[sourceID] end,
    isHiddenVisual = function(sourceID) return hidden[sourceID] or false end,
    canHaveSecondary = function(slotID) return secondarySlots[slotID] or false end,
}

local NONE = Constants.Transmog.NoTransmogID

do
    sets = {
        [7] = {
            name = "Raid Night",
            icon = "helm-icon",
            looks = {
                [INVSLOT_HEAD] = look(HELM),
                [INVSLOT_SHOULDER] = look(SHOULDERS, OTHER_SHOULDERS),
                [INVSLOT_CHEST] = look(CHEST),
                [INVSLOT_BACK] = look(HIDDEN_CLOAK),
                [INVSLOT_WAIST] = look(NONE),
                [INVSLOT_LEGS] = look(UNKNOWN),
                [INVSLOT_MAINHAND] = look(SWORD),
            },
        },
    }

    local entry = CustomSets.BuildEntry(7, resolver)
    assert(entry.name == "Raid Night" and entry.icon == "helm-icon", "an outfit is named and pictured as it was saved")

    local slots = {}
    for index, piece in ipairs(entry.pieces) do slots[index] = piece.slot end
    assert(table.concat(slots, ",") == "HEADSLOT,SHOULDERSLOT,SHOULDERSLOT,CHESTSLOT,MAINHANDSLOT",
        "pieces come out in the order the transmogrifier lists its slots, got " .. table.concat(slots, ","))

    assert(entry.pieces[2].isSecondary == false and entry.pieces[3].isSecondary == true,
        "a slot wearing two looks at once is two pieces, the second marked as such")
    assert(entry.pieces[4].state == "missing" and entry.pieces[1].state == "collected",
        "each piece says whether it is a look you own")
    assert(entry.collected == 3 and entry.total == 5, "and the counts follow the pieces")
    assert(entry.looks[INVSLOT_BACK], "the outfit keeps what it wears, hidden slots and all, for the model")
end

do
    -- The same outfit read by a client that has not answered for anything, which
    -- is what a cold cache looks like. Nothing is counted as missing on the
    -- strength of silence.
    local silent = {
        setInfo = resolver.setInfo,
        setPieces = resolver.setPieces,
        isCollected = function() return nil end,
        isHiddenVisual = resolver.isHiddenVisual,
        canHaveSecondary = resolver.canHaveSecondary,
    }

    local entry = CustomSets.BuildEntry(7, silent)
    assert(#entry.pieces == 0 and entry.total == 0, "a look the client says nothing about is not yet a piece")
    assert(not CustomSets.IsComplete(entry), "and an outfit with nothing to collect is not a finished one")
end

do
    sets = {
        [1] = { name = "Bank Alt", looks = { [INVSLOT_CHEST] = look(CHEST) } },
        [2] = { name = "Anniversary", looks = { [INVSLOT_HEAD] = look(HELM) } },
        [3] = { name = "Zandalar", looks = { [INVSLOT_MAINHAND] = look(SWORD) } },
        [4] = { name = "Anniversary", looks = { [INVSLOT_HEAD] = look(HELM) } },
    }

    local entries = CustomSets.BuildEntries({ 1, 2, 3, 4 }, resolver)
    local order = {}
    for index, entry in ipairs(entries) do order[index] = entry.key end
    assert(table.concat(order, ",") == "2,4,3,1",
        "outfits you own every look of lead, then by name and finally by which was saved first, got "
            .. table.concat(order, ","))

    assert(CustomSets.IsComplete(entries[1]), "an outfit whose every look you own is complete")
    assert(#CustomSets.MissingSources(entries[1]) == 0, "so it has nothing left to hunt")

    local incomplete = entries[#entries]
    assert(incomplete.name == "Bank Alt", "the outfit short of a look is last")
    local missing = CustomSets.MissingSources(incomplete)
    assert(#missing == 1 and missing[1] == CHEST, "and the look it is short of is what a shift-click goes after")
end

print("Lucky's Wardrobe custom sets tests passed")
