-- luacheck: globals PLAYER_DIFFICULTY1

-- Lucky's Wardrobe: Which of the classes a raid tier token serves still miss
-- the piece it makes.
LuckysWardrobe = LuckysWardrobe or {}
LuckysWardrobe.TierTokens = {}

local TierTokens = LuckysWardrobe.TierTokens

local ANY_SLOT = 0
local CHEST, ROBE = Enum.InventoryType.IndexChestType, Enum.InventoryType.IndexRobeType

local function fitsSlot(tokenSlot, piece)
    if tokenSlot == ANY_SLOT then return piece.token end
    if tokenSlot == CHEST then return piece.invType == CHEST or piece.invType == ROBE end
    return piece.invType == tokenSlot
end

-- One token item serves every difficulty of a modern raid, and says which on its
-- own tooltip, except on Normal, which goes unnamed. A raid whose sets come in
-- one difficulty, or whose names match none of these, is checked across all.
-- A line names a difficulty when it ends in it, whatever colour code leads it in:
-- the game wraps the name in one, and not always in the same form.
local function namesDifficulty(text, difficulty)
    local plain = text:gsub("|r", ""):match("^(.-)%s*$")
    if plain:sub(-#difficulty) ~= difficulty then return false end
    local before = plain:sub(1, -#difficulty - 1)
    return before == "" or not before:sub(-1):match("%a") or before:match("|c%S*$") ~= nil
end

local function tokenDifficulty(raid, lineTexts)
    for _, difficulty in ipairs(raid.difficulties) do
        for _, text in ipairs(lineTexts) do
            if namesDifficulty(text, difficulty) then return difficulty end
        end
    end
    local normal = PLAYER_DIFFICULTY1 or "Normal"
    for _, difficulty in ipairs(raid.difficulties) do
        if difficulty == normal then return normal end
    end
end

local function missesPiece(token, setID)
    for _, piece in ipairs(LuckysWardrobe.RaidSets:Pieces(setID)) do
        if fitsSlot(token.slot, piece) and not piece.collected then return true end
    end
    return false
end

--- The tokens a raid drops that make this class's piece: { itemID, encounters }.
function TierTokens:Making(classID, raidName, piece)
    local found = {}
    for itemID, token in pairs(LuckysWardrobe.TierTokensData) do
        if LuckysWardrobe.Classes:MaskHas(token.classMask, classID) and fitsSlot(token.slot, piece) then
            for _, instanceID in ipairs(token.instances) do
                if EJ_GetInstanceInfo(instanceID) == raidName then
                    found[#found + 1] = { itemID = itemID, encounters = token.encounters }
                    break
                end
            end
        end
    end
    table.sort(found, function(a, b) return a.itemID < b.itemID end)
    return found
end

--- What ClassesNeeding looked at for this token, line by line, for /lw token.
function TierTokens:Explain(itemID, lineTexts)
    local token = LuckysWardrobe.TierTokensData[itemID]
    if not token then return { ("Item %d is not a tier token."):format(itemID) } end

    local out = { ("Item %d: slot %d, classes %d, tooltip lines: %s"):format(
        itemID, token.slot, token.classMask, (table.concat(lineTexts, " / "):gsub("|", "||"))) }
    for _, class in ipairs(LuckysWardrobe.Classes:FromMask(token.classMask)) do
        for _, instanceID in ipairs(token.instances) do
            local raidName = EJ_GetInstanceInfo(instanceID)
            local raid = LuckysWardrobe.RaidSets:ForInstance(raidName)
            local sets = raid and raid.classes[class.classID]
            if not sets then
                out[#out + 1] = ("%s, %s (%s): no sets"):format(class.name, tostring(raidName), instanceID)
            else
                local difficulty = tokenDifficulty(raid, lineTexts)
                out[#out + 1] = ("%s, %s: checking %s"):format(class.name, raidName, tostring(difficulty or "every difficulty"))
                local found = {}
                for setDifficulty, setID in pairs(sets) do found[#found + 1] = ("[%s] %d"):format(setDifficulty, setID) end
                out[#out + 1] = "  sets found: " .. table.concat(found, ", ")
                for _, variant in ipairs(C_TransmogSets.GetVariantSets(sets[raid.difficulties[1]] or 0) or {}) do
                    out[#out + 1] = ("  variant %d description %s label %s"):format(
                        variant.setID, tostring(variant.description), tostring(variant.label))
                end
                for setDifficulty, setID in pairs(sets) do
                    if not difficulty or setDifficulty == difficulty then
                        local info = C_TransmogSets.GetSetInfo(setID)
                        out[#out + 1] = ("  set %d %s [%s], also labelled so: %s"):format(setID,
                            info and info.name or "?", setDifficulty,
                            table.concat(LuckysWardrobe.RaidSets:ShadowedBy(setID), ", "))
                        for _, piece in ipairs(LuckysWardrobe.RaidSets:Pieces(setID)) do
                            out[#out + 1] = ("    source %d item %d invType %s fits %s set says %s, counted %s"):format(
                                piece.sourceID, piece.itemID, tostring(piece.invType),
                                tostring(fitsSlot(token.slot, piece)), tostring(piece.setSaysCollected),
                                tostring(piece.collected))
                        end
                    end
                end
            end
        end
    end
    return out
end

--- The classes the token serves that still miss what it makes, or nil where
--- this is no token or no set it makes can be found to check against.
--- lineTexts are the token's tooltip lines, which name its difficulty.
function TierTokens:ClassesNeeding(itemID, lineTexts)
    local token = LuckysWardrobe.TierTokensData[itemID]
    if not token then return nil end

    local needing, checked = {}, false
    for _, class in ipairs(LuckysWardrobe.Classes:FromMask(token.classMask)) do
        local needs = false
        for _, instanceID in ipairs(token.instances) do
            local raid = LuckysWardrobe.RaidSets:ForInstance(EJ_GetInstanceInfo(instanceID))
            local sets = raid and raid.classes[class.classID]
            if sets then
                local difficulty = tokenDifficulty(raid, lineTexts)
                for setDifficulty, setID in pairs(sets) do
                    if not difficulty or setDifficulty == difficulty then
                        checked = true
                        needs = needs or missesPiece(token, setID)
                    end
                end
            end
        end
        if needs then needing[#needing + 1] = class end
    end

    return checked and needing or nil
end
