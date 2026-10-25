-- luacheck: globals ItemRefTooltip

-- Lucky's Wardrobe: On a raid tier token, the classes it serves that still miss
-- the piece it makes, and your alts of each, so it goes to the one who needs it.
LuckysWardrobe = LuckysWardrobe or {}
LuckysWardrobe.TokenTooltips = {}

local TokenTooltips = LuckysWardrobe.TokenTooltips

local MAX_ALTS = 3
local LABEL_COLOUR = { 0.91, 0.86, 0.78 }

local db
local lastToken

local function S() return LuckysWardrobe.Strings.tokenTooltips end

local function lineTexts(data)
    local texts = {}
    for _, line in ipairs(data.lines or {}) do
        if line.leftText then texts[#texts + 1] = line.leftText end
    end
    return texts
end

local function altNames(class)
    local alts = LuckysWardrobe.Classes:Alts(class.file)
    local names = {}
    for index = 1, math.min(#alts, MAX_ALTS) do
        names[index] = LuckyRoster:FormatName(alts[index].key)
    end
    local text = table.concat(names, ", ")
    if #alts > MAX_ALTS then
        text = text .. " " .. LuckysWardrobe.Strings.raidSets.moreAlts:format(#alts - MAX_ALTS)
    end
    return text
end

local function addLines(tooltip, data)
    if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end
    if not db.tooltipTokenNeeds or not data or not data.id then return end
    if not LuckysWardrobe.TierTokensData[data.id] then return end
    if C_AddOns.IsAddOnLoaded("AllTheThings") and not db.tooltipTokenNeedsWithATT then return end

    lastToken = { itemID = data.id, lineTexts = lineTexts(data) }
    local needing = LuckysWardrobe.TierTokens:ClassesNeeding(data.id, lastToken.lineTexts)
    if not needing then return end

    if #needing == 0 then
        tooltip:AddLine(S().allCollected, 0.3, 0.9, 0.3)
        return
    end
    tooltip:AddLine(S().neededBy, LABEL_COLOUR[1], LABEL_COLOUR[2], LABEL_COLOUR[3])
    for _, class in ipairs(needing) do
        tooltip:AddDoubleLine(LuckysWardrobe.Classes:Colour(class, class.name), altNames(class))
    end
end

function TokenTooltips:PrintLast()
    local say = LuckysWardrobe.Utils.Say
    if not lastToken then return say(S().nothingHovered) end
    for _, line in ipairs(LuckysWardrobe.TierTokens:Explain(lastToken.itemID, lastToken.lineTexts)) do
        say(line)
    end
end

function TokenTooltips:Init(database)
    db = database
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, addLines)
end
