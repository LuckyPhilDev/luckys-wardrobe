-- luacheck: globals LuckysWardrobe PLAYER_DIFFICULTY6
-- luacheck: ignore 121

LuckysWardrobe = {}

-- A localised difficulty global must classify alongside the English fallbacks.
PLAYER_DIFFICULTY6 = "Mythisch"

dofile("src/Strings.lua")
dofile("src/SetSources.lua")

local SetSources = LuckysWardrobe.SetSources

-- Every category has a distinct ID and a label, so no two sources share a
-- checkbox and none renders blank.
local labelsByID = {}
for _, category in ipairs(SetSources.Categories) do
    assert(type(category.id) == "number", "category IDs are numbers")
    assert(not labelsByID[category.id],
        tostring(category.label) .. " collides with " .. tostring(labelsByID[category.id]))
    assert(type(category.label) == "string" and category.label ~= "", "every category has a label")
    labelsByID[category.id] = category.label
end

-- Each classification below must land on a category that has a checkbox in the
-- menu. One without a checkbox cannot be cleared by Uncheck All, so its sets
-- would stay on screen when the user has unticked everything.
local reached = {}
local function assertClassifies(expected, set, why)
    local actual = SetSources:Classify(set)
    assert(actual == expected, why .. " (got " .. tostring(labelsByID[actual]) .. ")")
    assert(labelsByID[actual], why .. " reached a category with no checkbox")
    reached[actual] = true
end

assertClassifies(SetSources.PVP,
    { setID = 2500, description = "Gladiator", classMask = 4 },
    "a PvP description is PvP")
assertClassifies(SetSources.PVP,
    { setID = 2100, description = "Elite", classMask = 4 },
    "PvP wins over the covenant ID range, which overlaps it")
assertClassifies(SetSources.COVENANT,
    { setID = 2015, classMask = 4 },
    "the first covenant set ID is Covenants")
assertClassifies(SetSources.COVENANT,
    { setID = 2221, classMask = 4 },
    "the last covenant set ID is Covenants")
assertClassifies(SetSources.MISC,
    { setID = 2014, classMask = 4 },
    "a set just below the covenant range is not Covenants")
assertClassifies(SetSources.TRADING_POST,
    { setID = 2400, label = "Trading Post", classMask = 0 },
    "a Trading Post label is Trading Post")
assertClassifies(SetSources.TRADING_POST,
    { setID = 2401, description = "In-Game Shop - Shadowbane", classMask = 0 },
    "an In-Game Shop description matches despite its hyphen")
assertClassifies(SetSources.HERITAGE,
    { setID = 1522, name = "Heritage of the Highmountain", description = "Highmountain", classMask = 0 },
    "a Heritage name is Heritage")
assertClassifies(SetSources.RAID,
    { setID = 2222, description = "Mythic", classMask = 4 },
    "a raid difficulty description is Raid")
assertClassifies(SetSources.RAID,
    { setID = 2223, description = "Mythisch", classMask = 4 },
    "a localised difficulty global is Raid")
assertClassifies(SetSources.RAID,
    { setID = 500, description = "10 Player (Normal)", classMask = 4 },
    "Wrath tier names its difficulty inside the raid size")
assertClassifies(SetSources.RAID,
    { setID = 2600, description = "Normal", classMask = 0 },
    "an all-class raid set is still a raid set: difficulty is checked first")
assertClassifies(SetSources.MISC,
    { setID = 2601, description = "Normally calm", classMask = 4 },
    "a description that merely contains a difficulty word is not a difficulty")
assertClassifies(SetSources.COSMETIC,
    { setID = 2602, label = "Darkmoon Faire", description = "Normal", classMask = 0 },
    "a non-raid label is excluded from Raid despite its difficulty description")
assertClassifies(SetSources.COSMETIC,
    { setID = 2603, classMask = 0 },
    "wearable by every class is an outfit collection")
assertClassifies(SetSources.MISC,
    { setID = 2604, classMask = 32 },
    "content rewards keep the class they drop for and stay Miscellaneous")
assertClassifies(SetSources.MISC,
    { setID = 2605 },
    "a missing class mask is not evidence of anything")

-- The checks above cover every category a set can come out as, so the menu
-- offers no dead checkbox.
for _, category in ipairs(SetSources.Categories) do
    assert(reached[category.id], category.label .. " is never produced by the classifier")
end

print("Lucky's Wardrobe set sources test passed")
