-- luacheck: globals C_ClassColor C_CreatureInfo GetNumClasses

-- Lucky's Wardrobe: The classes a set belongs to, and their colours.
LuckysWardrobe = LuckysWardrobe or {}
LuckysWardrobe.Classes = {}

local Classes = LuckysWardrobe.Classes

--- Whether a set's class bitmask names a class, one bit per class ID.
-- Read with plain arithmetic rather than the bit library so the same code runs
-- under the tests, which have no such library to stub.
function Classes:MaskHasClass(classMask, classID)
    local flag = 2 ^ (classID - 1)
    return classMask % (flag + flag) >= flag
end

-- The armour a class transmogrifies, as the client's own armour subclass IDs.
-- The client exposes no API for this and it only changes when a class is added.
local ARMOUR_TYPE_BY_CLASS = {
    [1] = 4,  -- Warrior: Plate
    [2] = 4,  -- Paladin: Plate
    [3] = 3,  -- Hunter: Mail
    [4] = 2,  -- Rogue: Leather
    [5] = 1,  -- Priest: Cloth
    [6] = 4,  -- Death Knight: Plate
    [7] = 3,  -- Shaman: Mail
    [8] = 1,  -- Mage: Cloth
    [9] = 1,  -- Warlock: Cloth
    [10] = 2, -- Monk: Leather
    [11] = 2, -- Druid: Leather
    [12] = 2, -- Demon Hunter: Leather
    [13] = 3, -- Evoker: Mail
}

-- The playable classes do not change while the client is running, and every row of
-- the instance list asks for them.
local inClientOrder
local alphabetical

local function readClasses()
    if inClientOrder then return end

    inClientOrder = {}
    for classID = 1, GetNumClasses() do
        local info = C_CreatureInfo.GetClassInfo(classID)
        if info then
            inClientOrder[#inClientOrder + 1] = {
                classID = classID,
                file = info.classFile,
                name = info.className,
            }
        end
    end

    alphabetical = {}
    for index, class in ipairs(inClientOrder) do alphabetical[index] = class end
    table.sort(alphabetical, function(a, b) return a.name < b.name end)
end

--- Every playable class, in the order a list of them should read.
function Classes:All()
    readClasses()
    return alphabetical
end

--- The armour type a class wears, or nil for a class this version has no
--- answer for, which a caller should read as "no armour restriction".
function Classes:ArmourType(classID)
    return ARMOUR_TYPE_BY_CLASS[classID]
end

--- The classes a set belongs to, empty for one that belongs to all of them.
function Classes:FromMask(classMask)
    -- A mask of zero is every class at once, which the game uses for the sets that
    -- are nobody's in particular: the cosmetic and outfit collections.
    if not classMask or classMask == 0 then return {} end

    local classes = {}
    for _, class in ipairs(self:All()) do
        if self:MaskHasClass(classMask, class.classID) then
            classes[#classes + 1] = class
        end
    end
    return classes
end

function Classes:Colour(class, text)
    return C_ClassColor.GetClassColor(class.file):WrapTextInColorCode(text)
end

--- Class names for a list of them, each in its own colour.
function Classes:Names(classes)
    local names = {}
    for index, class in ipairs(classes) do
        names[index] = self:Colour(class, class.name)
    end
    return table.concat(names, ", ")
end
