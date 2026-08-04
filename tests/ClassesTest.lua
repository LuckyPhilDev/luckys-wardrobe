-- luacheck: globals C_ClassColor C_CreatureInfo GetNumClasses LuckysEnsemble

-- Covers reading a set's class mask: which classes a mask names, and how they read
-- once coloured.

LuckysEnsemble = {}

-- Class IDs and files as the game hands them over, deliberately not in
-- alphabetical order so the sort has something to do.
local CLASSES = {
    [1] = { className = "Warrior", classFile = "WARRIOR" },
    [2] = { className = "Paladin", classFile = "PALADIN" },
    [3] = { className = "Hunter", classFile = "HUNTER" },
    [4] = { className = "Rogue", classFile = "ROGUE" },
    [11] = { className = "Druid", classFile = "DRUID" },
}

_G.GetNumClasses = function() return 13 end
_G.C_CreatureInfo = {
    GetClassInfo = function(classID)
        local class = CLASSES[classID]
        if not class then return nil end
        return { className = class.className, classFile = class.classFile, classID = classID }
    end,
}
_G.C_ClassColor = {
    GetClassColor = function(classFile)
        return {
            WrapTextInColorCode = function(_, text) return ("<%s>%s"):format(classFile, text) end,
        }
    end,
}

dofile("src/Classes.lua")

local Classes = LuckysEnsemble.Classes

-- Only the classes the client reports, alphabetically.
local all = Classes:All()
assert(#all == 5, "the unplayable IDs in the range were counted")
assert(all[1].name == "Druid" and all[#all].name == "Warrior", "classes came back unsorted")

-- One bit per class, counting from the first.
local rogue = Classes:FromMask(2 ^ (4 - 1))
assert(#rogue == 1 and rogue[1].file == "ROGUE")

local leather = Classes:FromMask(2 ^ (4 - 1) + 2 ^ (11 - 1))
assert(#leather == 2, "a mask naming two classes did not report both")
assert(leather[1].name == "Druid" and leather[2].name == "Rogue")

-- A set every class can wear names none of them in particular.
assert(#Classes:FromMask(0) == 0)
assert(#Classes:FromMask(nil) == 0, "a set with no mask at all was read as one class's")

-- Bits for IDs the client does not report are ignored rather than guessed at.
assert(#Classes:FromMask(2 ^ (12 - 1)) == 0)

-- Every name carries its own class colour.
assert(Classes:Names(leather) == "<DRUID>Druid, <ROGUE>Rogue")
assert(Classes:Colour(rogue[1], "Piece") == "<ROGUE>Piece")

print("ClassesTest passed")
