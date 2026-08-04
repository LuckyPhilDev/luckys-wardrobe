-- luacheck: globals LuckysWardrobe C_TransmogCollection
-- luacheck: ignore 121

LuckysWardrobe = {}

local warmScripts, warmEvents = {}, {}
local clock = 1000
function GetTime() return clock end
function CreateFrame()
    return {
        SetScript = function(_, script, handler) warmScripts[script] = handler end,
        RegisterEvent = function(_, event) warmEvents[event] = true end,
        UnregisterEvent = function(_, event) warmEvents[event] = nil end,
    }
end

dofile("src/RecolorGroups.lua")
local RecolorGroups = LuckysWardrobe.RecolorGroups

-- Category IDs mirror Enum.TransmogCollectionType: 1 head, 2 shoulder, 4 chest,
-- 10 legs, 11 feet, 12 wand (not armour).
local function appearance(name, categoryID, visualID, uiOrder)
    return {
        name = name,
        categoryID = categoryID,
        visualID = visualID,
        sourceID = visualID * 10,
        uiOrder = uiOrder,
        collected = false,
    }
end

local function familyNames(families)
    local names = {}
    for index, family in ipairs(families) do names[index] = family.name end
    return table.concat(names, ", ")
end

local function rejectionFor(key, rejections)
    for _, rejection in ipairs(rejections) do
        if rejection.key == key then return rejection.reason end
    end
end

-- A family forms from the leading words its members share.

local families, rejections = RecolorGroups.Group({
    appearance("Shimmerbough Cowl", 1, 101, 5),
    appearance("Shimmerbough Mantle", 2, 102, 7),
    appearance("Shimmerbough Robes", 4, 103, 3),
    appearance("Shimmerbough Leggings", 10, 104, 9),
})
assert(#families == 1, "one family formed, got " .. #families)
assert(families[1].name == "Shimmerbough", "named the family from the shared leading word")
assert(#families[1].members == 4, "kept every member")
assert(families[1].members[1].slot == "HEAD" and families[1].members[4].slot == "LEGS",
    "members run in slot order, not input order")
assert(#rejections == 0, "nothing was left out")

-- Two words shared means both words name the family.

local twoWord = RecolorGroups.Group({
    appearance("Pained Absolution Cowl", 1, 201, 1),
    appearance("Pained Absolution Robes", 4, 202, 2),
    appearance("Pained Absolution Boots", 11, 203, 3),
})
assert(twoWord[1].name == "Pained Absolution", "the shared name runs as far as the members agree")

-- Members that diverge after the first word keep only what they share.

local diverging = RecolorGroups.Group({
    appearance("Frostwoven Cowl", 1, 301, 1),
    appearance("Frostwoven Robes", 4, 302, 2),
    appearance("Frostwoven Sandals", 11, 303, 3),
    appearance("Frostwoven Belt", 9, 304, 4),
})
assert(diverging[1].name == "Frostwoven", "diverging members share only the leading word")

-- Rules that keep inference honest.

local _, tooFew = RecolorGroups.Group({
    appearance("Duskthorn Cowl", 1, 401, 1),
    appearance("Duskthorn Robes", 4, 402, 2),
})
assert(rejectionFor("duskthorn", tooFew):find("fewer than 3"), "a two-slot cluster is not a set")

-- A name covers every colourway of a model. Tier sets ship identical piece
-- names at several difficulties, so a repeated slot separates colourways.

local colourways = RecolorGroups.Group({
    appearance("Battlelord's Helm", 1, 501, 1000),
    appearance("Battlelord's Chestplate", 4, 502, 1100),
    appearance("Battlelord's Greaves", 11, 503, 1200),
    appearance("Battlelord's Helm", 1, 504, 1300),
    appearance("Battlelord's Chestplate", 4, 505, 1400),
    appearance("Battlelord's Greaves", 11, 506, 1500),
})
assert(#colourways == 2, "each colourway is its own family, got " .. #colourways)
assert(colourways[1].members[1].sourceID == 5010 and colourways[2].members[1].sourceID == 5040,
    "colourways split in wardrobe order, earliest first")
assert(colourways[1].key == "battlelord's#1" and colourways[2].key == "battlelord's#2",
    "each colourway is separately identifiable in the report")

-- A repeat that leaves too little behind is dropped, not padded out.

local _, leftover = RecolorGroups.Group({
    appearance("Emberweave Cowl", 1, 601, 1),
    appearance("Emberweave Helm", 1, 602, 2),
    appearance("Emberweave Robes", 4, 603, 3),
    appearance("Emberweave Boots", 11, 604, 4),
})
assert(rejectionFor("emberweave#1", leftover):find("fewer than 3"),
    "the stranded first run is reported rather than merged into the next")

local _, short = RecolorGroups.Group({
    appearance("The Cowl", 1, 601, 1),
    appearance("The Robes", 4, 602, 2),
    appearance("The Boots", 11, 603, 3),
})
assert(rejectionFor("the", short):find("too short"), "a short leading word cannot seed a family")

-- Wardrobe ordering corroborates the name. Blizzard gives one set's pieces
-- near-consecutive order values across slots, so a wide spread means the shared
-- name has swept up unrelated items.

local tight = RecolorGroups.Group({
    appearance("Shimmerbough Hood", 1, 1201, 4197500),
    appearance("Shimmerbough Robe", 4, 1202, 4197000),
    appearance("Shimmerbough Cord", 9, 1203, 4197800),
})
assert(#tight == 1 and tight[1].span == 800, "a tightly ordered family survives, span " ..
    (tight[1] and tight[1].span or -1))

local _, spread = RecolorGroups.Group({
    appearance("Gloomvine Hood", 1, 1301, 400000),
    appearance("Gloomvine Robe", 4, 1302, 9200000),
    appearance("Gloomvine Boots", 11, 1303, 15000000),
})
assert(rejectionFor("gloomvine", spread):find("too far apart"),
    "a shared name spanning the whole wardrobe is not one set")

-- Non-armour categories never join a family.

local withWand = RecolorGroups.Group({
    appearance("Starcaller Cowl", 1, 701, 1),
    appearance("Starcaller Robes", 4, 702, 2),
    appearance("Starcaller Wand", 12, 703, 3),
    appearance("Starcaller Boots", 11, 704, 4),
})
assert(#withWand[1].members == 3, "the wand did not count toward the family")

-- Determinism: families come back in a fixed order for a fixed input.

local unordered = {
    appearance("Zephyr Robes", 4, 802, 2),
    appearance("Alder Cowl", 1, 901, 1),
    appearance("Zephyr Cowl", 1, 801, 1),
    appearance("Alder Robes", 4, 902, 2),
    appearance("Zephyr Boots", 11, 803, 3),
    appearance("Alder Boots", 11, 903, 3),
}
assert(familyNames(RecolorGroups.Group(unordered)) == "Alder, Zephyr",
    "families run in a fixed order regardless of input order")

-- Locales without spaced words fall back to no grouping rather than wrong ones.

local unspaced = RecolorGroups.Group({
    appearance("霜織のフード", 1, 1001, 1),
    appearance("霜織のローブ", 4, 1002, 2),
    appearance("霜織のブーツ", 11, 1003, 3),
})
assert(#unspaced == 0, "names with no word breaks form no families")

-- Live collection reads names through a representative source per appearance.

local categoryAppearances = {
    [1] = { { visualID = 1101, uiOrder = 4, isCollected = true } },
    [4] = { { visualID = 1104, uiOrder = 2, isCollected = false } },
}
local shown = { collected = false, uncollected = false }
C_TransmogCollection = {
    GetCategoryAppearances = function(categoryID)
        shown.openWhenRead = shown.collected and shown.uncollected
        return categoryAppearances[categoryID]
    end,
    -- The head appearance offers two sources: the first has no name and no item
    -- to resolve one from, so only the second answers.
    GetAllAppearanceSources = function(visualID)
        if visualID == 1101 then return { 9998, 11010 } end
        return { visualID * 10 }
    end,
    GetSourceInfo = function(sourceID)
        if sourceID == 9998 then return { itemID = 777 } end
        if sourceID == 11010 then return { itemID = 555 } end
        return { name = "Gloomvine Piece " .. sourceID, itemID = sourceID }
    end,
    GetCollectedShown = function() return shown.collected end,
    GetUncollectedShown = function() return shown.uncollected end,
    SetCollectedShown = function(value) shown.collected = value end,
    SetUncollectedShown = function(value) shown.uncollected = value end,
    GetCategoryTotal = function(categoryID) return categoryID == 1 and 50 or 30 end,
    GetFilteredCategoryTotal = function(categoryID) return categoryID == 1 and 10 or 5 end,
}

local requested = {}
C_Item = {
    -- The first appearance has no name on its source, so it has to come from
    -- item data, which is exactly the cold-cache case warming exists for.
    GetItemInfo = function(itemID) return itemID == 555 and "Cached Cowl" or nil end,
    RequestLoadItemDataByID = function(itemID) requested[#requested + 1] = itemID end,
}

local live, coverage = RecolorGroups.LiveAppearances()
assert(#live == 2, "collected one appearance per category entry, got " .. #live)
assert(live[1].name == "Cached Cowl" and live[1].sourceID == 11010,
    "a nameless first source does not stop a later source answering")
assert(live[2].name == "Gloomvine Piece 11040", "a source that carries a name is used directly")
assert(live[1].uiOrder == 4 and live[1].collected == true, "carried ordering and collected state through")
assert(shown.openWhenRead, "filters were open while enumerating")
assert(shown.collected == false and shown.uncollected == false, "restored the filters afterwards")
assert(coverage.enumerated == 2 and coverage.total == 50 + 30 * 10 and coverage.filtered == 10 + 5 * 10,
    "reported what the enumeration covered against the client's own totals")
assert(#coverage.items == 3, "every source's item is offered up for warming, not just the one that named it")

-- The funnel counts each step separately, so a shortfall points at one call.

local funnel = RecolorGroups.ResolutionFunnel(1)
assert(funnel.appearances == 1 and funnel.sources == 1, "counted appearances and those with sources")
assert(funnel.items == 1, "the first source does carry an item")
assert(funnel.sourceNames == 0 and funnel.itemNames == 0,
    "but neither the source nor its item names it, which is what a shortfall looks like")

local named = RecolorGroups.ResolutionFunnel(4)
assert(named.sourceNames == 1, "a source carrying its own name is counted there")

-- Warming waits for the client to answer, not merely for the asking to finish.

local warmed = false
RecolorGroups:WarmItemNames(coverage.items, function() warmed = true end)
warmScripts.OnUpdate()
assert(#requested == 3, "requested item data for every item seen")
assert(not warmed, "placing the requests is not finishing")

warmScripts.OnEvent()
clock = clock + 1
warmScripts.OnUpdate()
assert(not warmed, "a recent reply keeps the wait open")

clock = clock + 10
warmScripts.OnUpdate()
assert(warmed, "finished once the client went quiet")
assert(warmEvents["GET_ITEM_INFO_RECEIVED"] == nil, "stopped listening once finished")

print("Lucky's Wardrobe recolor grouping tests passed")
