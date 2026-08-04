-- luacheck: globals C_ClassColor C_CreatureInfo GetNumClasses

-- Lucky's Ensemble: The classes a set belongs to, and their colours.
LuckysEnsemble = LuckysEnsemble or {}
LuckysEnsemble.Classes = {}

local Classes = LuckysEnsemble.Classes

-- A set names its classes as a bitmask, one bit per class ID. Read with plain
-- arithmetic rather than the bit library so the same code runs under the tests,
-- which have no such library to stub.
local function maskHasClass(classMask, classID)
    local flag = 2 ^ (classID - 1)
    return classMask % (flag + flag) >= flag
end

-- The playable classes do not change while the client is running, and every row of
-- the instance list asks for them.
local playable

--- Every playable class, in the order a list of them should read.
function Classes:All()
    if not playable then
        playable = {}
        for classID = 1, GetNumClasses() do
            local info = C_CreatureInfo.GetClassInfo(classID)
            if info then
                playable[#playable + 1] = {
                    classID = classID,
                    file = info.classFile,
                    name = info.className,
                }
            end
        end
        table.sort(playable, function(a, b) return a.name < b.name end)
    end
    return playable
end

--- The classes a set belongs to, empty for one that belongs to all of them.
function Classes:FromMask(classMask)
    -- A mask of zero is every class at once, which the game uses for the sets that
    -- are nobody's in particular: the cosmetic and outfit collections.
    if not classMask or classMask == 0 then return {} end

    local classes = {}
    for _, class in ipairs(self:All()) do
        if maskHasClass(classMask, class.classID) then
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
