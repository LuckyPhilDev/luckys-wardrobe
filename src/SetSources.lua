-- luacheck: globals BATTLE_PET_SOURCE_10 BATTLE_PET_SOURCE_12
-- luacheck: ignore 122

-- Lucky's Wardrobe: Source categories for Blizzard's official transmog sets.
-- The game exposes no source field on a set, so the category is read from what
-- the set data does carry: its ID, name, label, description, and class mask.
LuckysWardrobe = LuckysWardrobe or {}
LuckysWardrobe.SetSources = {}

local SetSources = LuckysWardrobe.SetSources

SetSources.RAID = 1
SetSources.PVP = 2
SetSources.COVENANT = 3
SetSources.HERITAGE = 4
SetSources.COSMETIC = 5
SetSources.TRADING_POST = 6
SetSources.MISC = 7

-- Menu order for the Sources submenu. Every category the classifier can return
-- has an entry here, so each set on screen has a checkbox that can hide it and
-- Uncheck All really does empty the list.
local S = LuckysWardrobe.Strings.setSources

SetSources.Categories = {
    { id = SetSources.RAID, label = S.raid },
    { id = SetSources.PVP, label = S.pvp },
    { id = SetSources.COVENANT, label = S.covenants },
    { id = SetSources.HERITAGE, label = S.heritage },
    { id = SetSources.COSMETIC, label = S.cosmetic },
    { id = SetSources.TRADING_POST, label = S.tradingPost },
    { id = SetSources.MISC, label = S.miscellaneous },
}

-- Covenant armour sets sit in one contiguous set ID range.
local COVENANT_SETID_FIRST, COVENANT_SETID_LAST = 2015, 2221

-- Descriptions Blizzard gives modern PvP sets. Older PvP sets carry rank or
-- season text instead; the native PvE/PvP filter above the Sources submenu
-- remains the reliable switch for those.
local pvpDescriptions = {
    ["Honor"] = true,
    ["Combatant"] = true,
    ["Combatant I"] = true,
    ["Warfront"] = true,
    ["Aspirant"] = true,
    ["Gladiator"] = true,
    ["Elite"] = true,
}

-- Raid tier sets describe themselves by difficulty, and nothing else does:
-- every other kind of set puts its colour, its content type, or its event in
-- that field. Blizzard's globals keep this working outside English, with the
-- English values kept as a fallback in case a global is ever renamed.
local raidDifficulties = {
    ["Normal"] = true,
    ["Heroic"] = true,
    ["Mythic"] = true,
    ["Raid Finder"] = true,
}

for _, difficultyGlobal in ipairs({ "PLAYER_DIFFICULTY1", "PLAYER_DIFFICULTY2", "PLAYER_DIFFICULTY3", "PLAYER_DIFFICULTY6" }) do
    local difficulty = _G[difficultyGlobal]
    if difficulty then
        raidDifficulties[difficulty] = true
    end
end

-- Sets that give a raid difficulty as their description without being raid
-- sets: Blizzard reuses "Normal" for a handful of event and scenario rewards,
-- and nothing else in the set data tells them apart from real tier.
-- Keyed by label rather than set ID because each of these families exists once
-- per armour type, so the IDs differ per class while the label is shared.
-- The labels are localised, so this only takes effect on an English client.
local nonRaidLabels = {
    ["Darkmoon Faire"] = true,
    ["Time's Keeper"] = true,
    ["Legion: Assaults"] = true,
}

--- Whether a set's description names a raid difficulty, which is what marks it
--- as tier. Wrath era tier puts the difficulty inside the raid size, as in
--- "10 Player (Normal)", so the difficulty is matched within the description as
--- well as against the whole of it. Only the bracketed form counts, so a
--- description that merely contains the word is not mistaken for a difficulty.
---
--- The set tracker asks this too, so the answer is the same one that put the
--- set in the Raid category.
function SetSources:IsRaidDifficulty(description)
    if description == nil then return false end
    if raidDifficulties[description] then return true end

    for difficulty in pairs(raidDifficulties) do
        if string.find(description, "(" .. difficulty .. ")", 1, true) then return true end
    end

    return false
end

-- Plain find: the hyphen in "In-Game Shop" is a pattern quantifier, so a
-- pattern search never matches the labels being looked for.
local function isShopText(text)
    if text == nil then return false end
    return string.find(text, BATTLE_PET_SOURCE_12 or "Trading Post", 1, true) ~= nil
        or string.find(text, BATTLE_PET_SOURCE_10 or "In-Game Shop", 1, true) ~= nil
end

-- Heritage armour is named "Heritage of ..." and carries its race, not a
-- source, in its description. The name is localised, so like the label
-- exceptions above this only takes effect on an English client.
local function isHeritageName(name)
    return name ~= nil and string.find(name, "Heritage", 1, true) ~= nil
end

-- Source category for a set from Blizzard's official list. Order matters: the
-- covenant ID range overlaps modern PvP set IDs, so the PvP test runs first.
-- Everything unrecognised lands in Miscellaneous rather than being guessed at.
function SetSources:Classify(set)
    if set.description and pvpDescriptions[set.description] then
        return SetSources.PVP
    elseif set.setID >= COVENANT_SETID_FIRST and set.setID <= COVENANT_SETID_LAST then
        return SetSources.COVENANT
    elseif isShopText(set.label) or isShopText(set.description) then
        return SetSources.TRADING_POST
    elseif isHeritageName(set.name) then
        return SetSources.HERITAGE
    elseif self:IsRaidDifficulty(set.description) and not (set.label and nonRaidLabels[set.label]) then
        return SetSources.RAID
    elseif set.classMask == 0 then
        -- Wearable by every class, which is what the outfit collections are.
        -- Content rewards keep the class or armour type they drop for, so this
        -- separates the cosmetic sets from them without reading any text.
        return SetSources.COSMETIC
    end

    return SetSources.MISC
end
