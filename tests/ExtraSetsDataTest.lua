-- luacheck: globals LuckysWardrobe

-- The bundled set data is generated, not written, so this test guards the shape
-- the catalogue relies on rather than any particular set. A regeneration that
-- drops a field or an armour type fails here instead of in the game.

LuckysWardrobe = {}

dofile("src/Data/ExtraSetsData.lua")
local Data = LuckysWardrobe.ExtraSetsData

assert(type(Data.snapshot) == "string" and Data.snapshot:match("^%d%d%d%d%-%d%d%-%d%d$"),
    "the data names the date it was taken")
assert(#Data.armorTypes == 4, "all four armour types are indexed")

local seenArmorTypes = {}
for _, armour in ipairs(Data.armorTypes) do
    assert(type(armour.key) == "string" and armour.key ~= "", "each armour type has a key")
    assert(type(armour.armorType) == "number", "each armour type has the client's own subclass ID")
    assert(not seenArmorTypes[armour.armorType], "armour type " .. armour.armorType .. " is indexed once")
    seenArmorTypes[armour.armorType] = true
    dofile("src/Data/" .. armour.key:sub(1, 1):upper() .. armour.key:sub(2) .. "Sets.lua")
end

local totalSets, totalPieces, labelled, dated = 0, 0, 0, 0
local owningArmorType = {}
for _, armour in ipairs(Data.armorTypes) do
    local sets = Data.sets[armour.key]
    assert(type(sets) == "table" and next(sets), armour.key .. " sets loaded")

    for setID, set in pairs(sets) do
        local where = armour.key .. " set " .. tostring(setID)
        assert(type(setID) == "number" and setID > 0 and setID % 1 == 0, where .. " is keyed by a set ID")
        assert(not owningArmorType[setID], where .. " is listed under one armour type only")
        owningArmorType[setID] = armour.armorType

        assert(type(set.name) == "string" and set.name ~= "", where .. " has a name")
        assert(type(set.classMask) == "number" and set.classMask >= 0, where .. " has a class mask")
        -- The snapshot answers for all three of these on every set, so a nil is
        -- a generator that dropped a field rather than a set that lacks one.
        assert(type(set.quality) == "number" and set.quality >= 0 and set.quality <= 8,
            where .. " has an item quality")
        assert(type(set.minLevel) == "number" and set.minLevel >= 0, where .. " has a minimum level")
        assert(type(set.sourceMask) == "number" and set.sourceMask >= 0, where .. " has a source mask")
        -- Dated from the expansion partition Wowhead filed the set under, in the
        -- client's own numbering. A set it filed under none carries nothing.
        assert(set.expansionID == nil or (type(set.expansionID) == "number"
            and set.expansionID >= 0 and set.expansionID % 1 == 0),
            where .. " has an expansion or none at all")
        if set.expansionID then dated = dated + 1 end
        -- Only the difficulty variants carry a label, so nil is an ordinary set.
        assert(set.label == nil or (type(set.label) == "string" and set.label ~= ""),
            where .. " has a difficulty label or none at all")
        if set.label then labelled = labelled + 1 end
        assert(type(set.pieces) == "table" and #set.pieces > 0, where .. " has at least one piece")
        for _, itemID in ipairs(set.pieces) do
            assert(type(itemID) == "number" and itemID > 0 and itemID % 1 == 0,
                where .. " lists item IDs")
            totalPieces = totalPieces + 1
        end
        totalSets = totalSets + 1
    end
end

-- A floor, not the exact count: the numbers move whenever the snapshot is
-- retaken, but an order-of-magnitude drop means a file failed to load.
assert(totalSets > 3000, "the snapshot holds the thousands of sets it should, got " .. totalSets)
assert(totalPieces > 20000, "sets carry their pieces, got " .. totalPieces)
-- A floor too. Difficulty is read off flags the snapshot sets on a small
-- minority of sets, so a decode that quietly stopped working reads as zero.
assert(labelled > 100, "the difficulty variants keep their label, got " .. labelled)
-- The expansion filter is the whole point of dating these, and a collection that
-- lost the partition would leave every set in the Unknown box instead.
assert(dated > totalSets * 0.9,
    "the snapshot dates the sets it collected, got " .. dated .. " of " .. totalSets)

-- The ensembles are the one listing keyed by the client's own set numbering, so
-- the armour lists' set IDs say nothing about which of these are the same set.

dofile("src/Data/EnsembleSets.lua")
local ensembleSets, ensembleItems = 0, 0
for setID, set in pairs(Data.ensembles) do
    local where = "ensemble set " .. tostring(setID)
    assert(type(setID) == "number" and setID > 0 and setID % 1 == 0, where .. " is keyed by a set ID")
    assert(type(set.name) == "string" and set.name ~= "", where .. " has a name")
    assert(not set.name:find("^Ensemble: "),
        where .. " is named for the set, not for the item that teaches it")
    assert(type(set.classMask) == "number" and set.classMask >= 0, where .. " has a class mask")
    assert(type(set.pieces) == "table" and #set.pieces > 0, where .. " has at least one piece")
    assert(type(set.ensembles) == "table" and #set.ensembles > 0, where .. " names an ensemble that teaches it")
    for _, itemID in ipairs(set.ensembles) do
        assert(type(itemID) == "number" and itemID > 0 and itemID % 1 == 0, where .. " lists ensemble item IDs")
        ensembleItems = ensembleItems + 1
    end
    for _, itemID in ipairs(set.pieces) do
        assert(type(itemID) == "number" and itemID > 0 and itemID % 1 == 0, where .. " lists item IDs")
        totalPieces = totalPieces + 1
    end
    ensembleSets = ensembleSets + 1
end
assert(ensembleSets > 1500, "the ensembles hold the sets they should, got " .. ensembleSets)
assert(ensembleItems >= ensembleSets, "every ensemble set is taught by at least one item")

print(("Lucky's Wardrobe extra sets data test passed (%d sets, %d ensemble sets, %d pieces)")
    :format(totalSets, ensembleSets, totalPieces))
