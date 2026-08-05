-- Lucky's Wardrobe: What an item is worth to a collection, said on the item's own
-- tooltip. How far along the set a piece belongs to is is otherwise a question you
-- answer by putting the item down and going through the wardrobe looking for it.
LuckysWardrobe = LuckysWardrobe or {}
LuckysWardrobe.ItemTooltips = {}

local ItemTooltips = LuckysWardrobe.ItemTooltips

-- The label is the quiet part and the set is the answer, so the label takes the
-- muted colour the rest of the addon labels in and the name takes the white that
-- reads as an item's own. The count is the set tracker's green once a set is done.
local LABEL_COLOUR = { 0.54, 0.49, 0.42 }
local NAME_COLOUR = { 1, 1, 1 }
local COUNT_COLOUR = { 0.91, 0.69, 0.25 }
local COMPLETE_COLOUR = { 0.41, 0.86, 0.49 }

local db

-- Which set a piece belongs to is fixed for the life of the client, so it is asked
-- once per piece. What is collected changes all session, so those counts are thrown
-- away whenever the collection says something moved.
local setBySource = {}
local setProgress = {}

local function forgetProgress()
    setProgress = {}
end

local function coloured(rgb, text)
    return CreateColor(rgb[1], rgb[2], rgb[3]):WrapTextInColorCode(text)
end

--- The set a piece belongs to, or nil for a piece in none.
-- A piece can be listed under more than one set, a raid difficulty and the
-- cosmetic recolour of it among them. The one this character could wear is the one
-- worth naming.
local function setFor(sourceID)
    local found = setBySource[sourceID]
    if found == nil then
        for _, setID in ipairs(C_TransmogSets.GetSetsContainingSourceID(sourceID) or {}) do
            local info = C_TransmogSets.GetSetInfo(setID)
            if info and (not found or (info.validForCharacter and not found.validForCharacter)) then
                found = info
            end
        end
        setBySource[sourceID] = found or false
    end
    return found or nil
end

local function progressOf(setID)
    local progress = setProgress[setID]
    if not progress then
        progress = { collected = 0, total = 0 }
        for _, appearance in ipairs(C_TransmogSets.GetSetPrimaryAppearances(setID) or {}) do
            progress.total = progress.total + 1
            if appearance.collected then progress.collected = progress.collected + 1 end
        end
        setProgress[setID] = progress
    end
    return progress
end

--- The line this addon has to add to an item's tooltip, ready to be drawn.
-- Handed back rather than drawn, so what an item would say can be read without a
-- tooltip to hang it on. Nil for anything in no set, which is most of what passes
-- through a bag.
function ItemTooltips:Line(itemInfo)
    if itemInfo == nil or not db.tooltipSetProgress then return nil end

    local _, sourceID = C_TransmogCollection.GetItemInfo(itemInfo)
    local set = sourceID and setFor(sourceID)
    if not set then return nil end

    -- A set this client lists no pieces for has no progress to report, and "0/0" is
    -- a worse answer than saying nothing.
    local progress = progressOf(set.setID)
    if progress.total == 0 then return nil end

    local S = LuckysWardrobe.Strings.tooltips
    local count = S.setProgress:format(progress.collected, progress.total)
    return {
        text = S.setLine:format(coloured(NAME_COLOUR, set.name),
            coloured(progress.collected == progress.total and COMPLETE_COLOUR or COUNT_COLOUR, count)),
        colour = LABEL_COLOUR,
    }
end

local function addLine(tooltip, data)
    -- The tooltips someone reads an item on. The shopping tooltips alongside them
    -- are there to be compared against what is worn, and the same line repeated
    -- down each of those is noise rather than an answer.
    if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end

    -- The link carries the bonus IDs that say which version of a piece this is, so
    -- a raid item resolves to its own difficulty's appearance. An item ID alone
    -- resolves to whichever difficulty came first, and is only fallen back on where
    -- the tooltip has no link to offer.
    local _, itemLink = TooltipUtil.GetDisplayedItem(tooltip)
    local line = ItemTooltips:Line(itemLink or (data and data.id))
    if line then
        tooltip:AddLine(line.text, line.colour[1], line.colour[2], line.colour[3])
    end
end

function ItemTooltips:Init(database)
    db = database
    forgetProgress()

    local events = CreateFrame("Frame")
    events:RegisterEvent("TRANSMOG_COLLECTION_UPDATED")
    events:SetScript("OnEvent", forgetProgress)

    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, addLine)
end
