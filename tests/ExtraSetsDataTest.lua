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

local totalSets, totalPieces = 0, 0
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

print(("Lucky's Wardrobe extra sets data test passed (%d sets, %d pieces)"):format(totalSets, totalPieces))
