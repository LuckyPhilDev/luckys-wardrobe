-- luacheck: globals LuckysWardrobe CreateFrame UnitClass GetNumClasses C_ClassColor C_CreatureInfo C_Item C_TransmogCollection EXPANSION_NAME0 EXPANSION_NAME1 EXPANSION_NAME2 EXPANSION_NAME3 EXPANSION_NAME4 EXPANSION_NAME5 EXPANSION_NAME6 EXPANSION_NAME7 EXPANSION_NAME8 EXPANSION_NAME9 EXPANSION_NAME10 EXPANSION_NAME11
-- luacheck: ignore 121

LuckysWardrobe = {}

local devLogs = {}
LuckysWardrobe.DevLog = function(message) devLogs[#devLogs + 1] = message end

for index = 0, 11 do _G["EXPANSION_NAME" .. index] = "Expansion " .. index end

-- The paced build hands itself to an OnUpdate, so the frame is stubbed to hand
-- the handler back and the test drives the frames itself.
local stepHandler
function CreateFrame()
    return {
        SetScript = function(_, script, handler)
            assert(script == "OnUpdate", "the build paces itself with OnUpdate")
            stepHandler = handler
        end,
    }
end

GetNumClasses = function() return 13 end
C_CreatureInfo = {
    GetClassInfo = function(classID)
        return { classFile = "CLASS" .. classID, className = "Class " .. classID }
    end,
}
C_ClassColor = {
    GetClassColor = function() return { WrapTextInColorCode = function(_, text) return text end } end,
}

dofile("src/Strings.lua")
dofile("src/Utils.lua")
dofile("src/Classes.lua")
dofile("src/Perf.lua")
local clock = 0
LuckysWardrobe.Perf.Clock = function()
    clock = clock + 1
    return clock
end
dofile("src/ExtraSets.lua")
dofile("src/TransmogExtraSets.lua")

local ExtraSets = LuckysWardrobe.ExtraSets
local TransmogExtraSets = LuckysWardrobe.TransmogExtraSets
local CLOTH = 1

-- Where the tab sits in the strip.

-- Blizzard's own numbering, Sets second: the seat is between Sets and Custom
-- Sets, and nothing else is asked to move.
assert(TransmogExtraSets.LayoutIndexAfter(2, { 1, 2, 3, 4 }) == 2.5,
    "took the seat directly after Sets")

-- W2 Transmog Studio renumbers the strip to Items, Studio, Sets, Custom Sets,
-- Situations. Reading the strip as it stands is what keeps this tab behind Sets
-- rather than in front of it, which a number worked out before the renumber did.
assert(TransmogExtraSets.LayoutIndexAfter(3, { 1, 2, 3, 4, 5 }) == 3.5,
    "followed Sets to its new number rather than keeping the old seat")

-- Asking again once seated gives the same answer: this runs on every layout, so
-- an answer that drifted would walk the tab across the strip.
assert(TransmogExtraSets.LayoutIndexAfter(3, { 1, 2, 3, 4, 5 })
    == TransmogExtraSets.LayoutIndexAfter(3, { 1, 2, 3, 4, 5 }),
    "asking twice against the same strip seats the tab in the same place")

-- Gaps in the numbering are somebody else's arrangement, so the seat is taken
-- against the tab that actually follows Sets rather than against Sets plus one.
assert(TransmogExtraSets.LayoutIndexAfter(10, { 1, 10, 20 }) == 15,
    "seated between Sets and whatever follows it, however far apart they are")

-- Sets last in the strip: there is no tab to sit in front of.
assert(TransmogExtraSets.LayoutIndexAfter(5, { 1, 2, 5 }) == 6,
    "with nothing after Sets, the seat is simply the next one along")

-- The seat lands strictly between Sets and the next tab, so it can never be the
-- number another tab is already holding.
local occupied = { 1, 2, 3, 4, 5 }
local seat = TransmogExtraSets.LayoutIndexAfter(3, occupied)
for _, index in ipairs(occupied) do
    assert(seat ~= index, "the seat is never one another tab already holds")
end
assert(seat > 3 and seat < 4, "the seat sits between Sets and the tab after it")

-- Entries are built through the real entry builder so the fixtures carry
-- everything the page reads: states, counts, and the look behind each piece.

local sourceStates = {
    [2001] = { appearanceID = 9001, collected = true },
    [2002] = { appearanceID = 9002, collected = true },
    [2003] = { appearanceID = 9003, collected = false },
    [3001] = { appearanceID = 9101, collected = false },
    [3002] = { appearanceID = 9102, collected = false },
}

local resolver = {
    sourceState = function(sourceID) return sourceStates[sourceID] end,
    playerClassID = function() return 1 end,
}

local function pieces(...)
    local list = {}
    for index, piece in ipairs({ ... }) do
        list[index] = { slot = piece[1], sourceID = piece[2] }
    end
    return list
end

local function entry(name, setID, pieceList)
    return ExtraSets.BuildEntry({
        setID = setID,
        name = name,
        armorType = CLOTH,
        classMask = 0,
        pieces = pieceList,
    }, resolver)
end

local completeSet = entry("Full Regalia", 10, pieces({ "HEAD", 2001 }, { "CHEST", 2002 }))
local partialSet = entry("Half Garb", 11, pieces({ "HEAD", 2001 }, { "CHEST", 2003 }))
local emptySet = entry("Bare Vestments", 12, pieces({ "HEAD", 3001 }, { "CHEST", 3002 }))
local unresolvableSet = entry("Ghost Raiment", 13, pieces({ "HEAD", 9999 }))

assert(completeSet.collected == 2 and ExtraSets.IsComplete(completeSet), "fixture: complete set is complete")
assert(partialSet.collected == 1 and not ExtraSets.IsComplete(partialSet), "fixture: partial set is not")
assert(emptySet.collected == 0, "fixture: empty set has nothing collected")

-- The filter button's two checkboxes.

local narrowed = TransmogExtraSets.FilterByCollected({ completeSet, partialSet, emptySet }, true, false)
assert(#narrowed == 1 and narrowed[1] == completeSet, "collected alone keeps only finished sets")

narrowed = TransmogExtraSets.FilterByCollected({ completeSet, partialSet, emptySet }, false, true)
assert(#narrowed == 2 and narrowed[1] == partialSet and narrowed[2] == emptySet,
    "not collected keeps everything short of finished, half done or untouched")

narrowed = TransmogExtraSets.FilterByCollected({ completeSet, partialSet, emptySet }, true, true)
assert(#narrowed == 3, "both boxes keep everything")

assert(#TransmogExtraSets.FilterByCollected({ unresolvableSet }, true, false) == 0,
    "a set with nothing resolvable is never called collected")

-- The page order: nearest to finished first, and search narrows by name.

local visible = TransmogExtraSets.VisibleEntries(
    { emptySet, partialSet, completeSet }, { collected = true, uncollected = true }, "")
assert(visible[1] == completeSet and visible[2] == partialSet and visible[3] == emptySet,
    "cards run from finished to untouched")

visible = TransmogExtraSets.VisibleEntries(
    { emptySet, partialSet, completeSet }, { collected = true, uncollected = true }, "half")
assert(#visible == 1 and visible[1] == partialSet, "search narrows the cards by name")

visible = TransmogExtraSets.VisibleEntries(
    { emptySet, partialSet, completeSet }, { collected = false, uncollected = true }, "")
assert(#visible == 2 and visible[1] == partialSet, "filters narrow before the sort orders")

-- What the page has drawn, so a pass that would draw the same thing again is
-- left alone rather than reloading every model on screen.

local everything = { completeSet, partialSet, emptySet }

assert(TransmogExtraSets.PageSignature(everything) == TransmogExtraSets.PageSignature(everything),
    "the same cards in the same order are the same page")

assert(TransmogExtraSets.PageSignature({ completeSet, partialSet })
    ~= TransmogExtraSets.PageSignature({ partialSet, completeSet }),
    "the same cards in another order are another page")

assert(TransmogExtraSets.PageSignature(everything)
    ~= TransmogExtraSets.PageSignature({ completeSet, partialSet }),
    "a card dropped from the page is another page")

-- Rebuilding the entries makes new tables holding the same answers, and the
-- cards on screen are already showing those answers. Comparing what they say
-- rather than which table said it is what keeps the page from being redrawn
-- every time it is reopened.
local rebuiltComplete = entry("Full Regalia", 10, pieces({ "HEAD", 2001 }, { "CHEST", 2002 }))
assert(rebuiltComplete ~= completeSet, "fixture: a rebuild really is another table")
assert(TransmogExtraSets.PageSignature({ rebuiltComplete })
    == TransmogExtraSets.PageSignature({ completeSet }),
    "a rebuilt entry saying the same thing draws the same card")

-- Collecting a piece changes what the card prints on itself, so the page has to
-- be drawn again even though the same sets are on it in the same order.
sourceStates[2003] = { appearanceID = 9003, collected = true }
local collectedMore = entry("Half Garb", 11, pieces({ "HEAD", 2001 }, { "CHEST", 2003 }))
sourceStates[2003] = { appearanceID = 9003, collected = false }
assert(collectedMore.collected == 2, "fixture: the set gained a piece")
assert(TransmogExtraSets.PageSignature({ collectedMore }) ~= TransmogExtraSets.PageSignature({ partialSet }),
    "a set that gained a piece draws a different card")

-- Whether the outfit on show is wearing a set.

local wornComplete = {
    HEAD = { appearanceID = 9001, hasPending = false },
    CHEST = { appearanceID = 9002, hasPending = false },
}

assert(TransmogExtraSets.MatchesViewedOutfit(completeSet, wornComplete),
    "an outfit wearing every look of the set is wearing the set")

local matched, hasPending = TransmogExtraSets.MatchesViewedOutfit(completeSet, {
    HEAD = { appearanceID = 9001, hasPending = true },
    CHEST = { appearanceID = 9002, hasPending = false },
})
assert(matched and hasPending, "one pending slot makes the whole set pending")

assert(not TransmogExtraSets.MatchesViewedOutfit(completeSet, {
    HEAD = { appearanceID = 9001, hasPending = false },
    CHEST = { appearanceID = 9999, hasPending = false },
}), "another look in a covered slot is another outfit")

assert(not TransmogExtraSets.MatchesViewedOutfit(completeSet, {
    HEAD = { appearanceID = 9001, hasPending = false },
}), "a covered slot wearing nothing is not wearing the set")

local wornWithExtras = {
    HEAD = { appearanceID = 9001, hasPending = false },
    CHEST = { appearanceID = 9002, hasPending = false },
    LEGS = { appearanceID = 7777, hasPending = false },
}
assert(TransmogExtraSets.MatchesViewedOutfit(completeSet, wornWithExtras),
    "slots the set says nothing about say nothing back")

-- A slot carrying a chest and its robe twin answers for either look.
local robeSet = entry("Twin Robes", 14, pieces({ "CHEST", 2002 }, { "CHEST", 2003 }, { "HEAD", 2001 }))
assert(TransmogExtraSets.MatchesViewedOutfit(robeSet, {
    HEAD = { appearanceID = 9001, hasPending = false },
    CHEST = { appearanceID = 9003, hasPending = false },
}), "a slot with two pieces matches whichever of them is worn")

assert(not TransmogExtraSets.MatchesViewedOutfit(unresolvableSet, wornComplete),
    "a set with no resolvable look can never be what an outfit wears")

-- Which card lights up as applied.

local applied = TransmogExtraSets.AppliedEntry({ partialSet, completeSet }, wornComplete)
assert(applied == completeSet, "the set the outfit wears is the applied card")

assert(TransmogExtraSets.AppliedEntry({ partialSet }, wornComplete) == nil,
    "no card lights up when the outfit is wearing none of them")

-- An untouched set is never asked, even about looks that would match.
local wornEmpty = {
    HEAD = { appearanceID = 9101, hasPending = false },
    CHEST = { appearanceID = 9102, hasPending = false },
}
assert(TransmogExtraSets.MatchesViewedOutfit(emptySet, wornEmpty),
    "fixture: the looks themselves would match")
assert(TransmogExtraSets.AppliedEntry({ emptySet }, wornEmpty) == nil,
    "a set with nothing collected cannot be the one applied")

-- What one click applies.

local resolved = { [2001] = 5001, [2002] = 5002 }
local function resolveSource(sourceID) return resolved[sourceID] end

local applications = TransmogExtraSets.ApplyList(partialSet, resolveSource)
assert(#applications == 1 and applications[1].slot == "HEAD" and applications[1].sourceID == 5001,
    "collected pieces are applied and uncollected slots are left alone")

-- The first piece decides its slot, since it is the one the card's model
-- wears: the robe twin behind it is not applied in its place.
applications = TransmogExtraSets.ApplyList(robeSet, function(sourceID)
    return sourceID == 2003 and 5003 or nil
end)
assert(#applications == 0, "a slot shows its first piece, so only that piece's look is applied")

-- An unavailable piece never claims its slot, so the piece behind it can.
local ghostFirst = entry("Ghost Chest", 15, pieces({ "CHEST", 9999 }, { "CHEST", 2002 }))
applications = TransmogExtraSets.ApplyList(ghostFirst, resolveSource)
assert(#applications == 1 and applications[1].sourceID == 5002,
    "a piece this client cannot resolve hands its slot to the next piece")

assert(#TransmogExtraSets.ApplyList(emptySet, function() return nil end) == 0,
    "a set with nothing applicable applies nothing")

-- Sets this character cannot wear. The transmogrifier dresses one character, so
-- a set the client refuses is one nothing here could ever put on.

local refusedSources = {}
local function validity(sourceID)
    if not sourceStates[sourceID] then return nil end
    if refusedSources[sourceID] then return false, "faction", "Requires Alliance" end
    return true
end

local everySet = { completeSet, partialSet, emptySet }
assert(#TransmogExtraSets.WearableEntries(everySet, 1, validity) == 3,
    "sets the client accepts are all offered")

refusedSources[2002] = true
local wearable = TransmogExtraSets.WearableEntries(everySet, 1, validity)
assert(#wearable == 2 and wearable[1] == partialSet and wearable[2] == emptySet,
    "the set holding a refused piece is kept off the page")

-- The client works its verdict out from item data it loads only once asked, and
-- a set it has not judged has to stay: hiding on a cold cache would empty the
-- page every time it opened.
assert(#TransmogExtraSets.WearableEntries(everySet, 1, function() return nil end) == 3,
    "sets the client has said nothing about are still offered")

-- Judged a slice at a time, which is how the page spreads the work across
-- frames. The verdicts have to gather into the same list, in the same order, as
-- judging the lot in one go.
refusedSources[2002] = true
local wholeVerdict = TransmogExtraSets.WearableEntries(everySet, 1, validity)
local slicedVerdict = {}
for _, set in ipairs(everySet) do
    TransmogExtraSets.WearableEntries({ set }, 1, validity, slicedVerdict)
end
assert(#slicedVerdict == #wholeVerdict, "slicing the rows keeps the same sets")
for index, judged in ipairs(wholeVerdict) do
    assert(slicedVerdict[index] == judged, "and keeps them in the same order")
end
refusedSources = {}

-- The build paced across frames. Spending a fifth of a second in one frame is a
-- hitch a player sees, so ahead of a visit the rows are built a slice at a time.
-- What matters is that the slow way and the paced way answer alike: a page built
-- over forty frames has to be the page one call would have built.

do
    -- A client with enough sets to need several slices, and a duplicate look so
    -- the folding has something to fold across a slice boundary.
    local slots = LuckysWardrobe.Utils.ARMOUR_SLOTS
    local sources, records = {}, {}
    for setID = 1, 200 do
        local setPieces = {}
        for slot = 1, 6 do
            local sourceID = setID * 100 + slot
            -- Every tenth set wears the first set's looks, which is the shape
            -- that makes a row fold into an earlier one, and it folds across a
            -- slice boundary as readily as inside one.
            local appearanceID = (setID % 10 == 0) and (100 + slot) or sourceID
            sources[sourceID] = {
                appearanceID = appearanceID,
                collected = setID % 3 == 0,
                -- The last sets are ones the client refuses, so the judging
                -- stage has rows to drop as well as rows to keep.
                valid = setID < 195,
            }
            setPieces[slot] = { slot = slots[slot], sourceID = sourceID, itemID = sourceID }
        end
        records[setID] = {
            setID = setID,
            name = "Paced Set " .. setID,
            armorType = CLOTH,
            classMask = 0,
            pieces = setPieces,
        }
    end

    UnitClass = function() return "Class 5", "CLASS5", 5 end
    C_Item = { GetItemInfo = function(itemID) return "Item " .. itemID end }
    C_TransmogCollection = {
        GetAppearanceInfoBySource = function(sourceID)
            local source = sources[sourceID]
            if not source then return nil end
            return { appearanceID = source.appearanceID, appearanceIsCollected = source.collected }
        end,
        GetSourceInfo = function(sourceID)
            local source = sources[sourceID]
            if not source then return nil end
            return {
                visualID = source.appearanceID,
                isCollected = source.collected,
                itemID = sourceID,
                isValidSourceForPlayer = source.valid,
                useErrorType = nil,
                useError = "no",
            }
        end,
    }
    LuckysWardrobe.ExtraSetsCatalog = {
        IsReady = function() return true end,
        GetRecords = function() return records end,
        OfficialLooks = function() return {} end,
    }

    TransmogExtraSets.InvalidateEntries()
    local atOnce = TransmogExtraSets.Entries()
    assert(#atOnce > 0 and #atOnce < 200,
        "fixture: sets fold into one another and the client refuses others")

    TransmogExtraSets.InvalidateEntries()
    TransmogExtraSets.BuildAhead()
    assert(stepHandler, "building ahead paces itself across frames")

    -- The build clears its own handler when it runs out of slices, so this ends
    -- on its own. The count guards against a stage that never advances hanging
    -- the suite instead of failing it.
    local frames = 0
    while stepHandler do
        stepHandler()
        frames = frames + 1
        assert(frames < 500, "the paced build runs out of slices rather than forever")
    end

    local paced = TransmogExtraSets.Entries()
    assert(#paced == #atOnce, "the paced build lists the same sets as the one-shot build")
    for index, row in ipairs(atOnce) do
        assert(paced[index].key == row.key, "in the same order")
        assert(paced[index].collected == row.collected and paced[index].total == row.total,
            "with the same counts")
    end
    assert(TransmogExtraSets.PageSignature(paced) == TransmogExtraSets.PageSignature(atOnce),
        "so the page cannot tell which way it was built")
    assert(frames > 1, "and it really did take more than one frame")

    -- A player who reaches the tab mid-build wants a page, not a progress bar:
    -- asking finishes the build there and then and stops the slices.
    TransmogExtraSets.InvalidateEntries()
    TransmogExtraSets.BuildAhead()
    stepHandler()
    local interrupted = TransmogExtraSets.Entries()
    assert(TransmogExtraSets.PageSignature(interrupted) == TransmogExtraSets.PageSignature(atOnce),
        "a build cut short still hands over the whole page")
end

print("Lucky's Wardrobe transmog extra sets tests passed")
