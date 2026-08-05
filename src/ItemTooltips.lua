-- Lucky's Wardrobe: What an item is worth to a collection, said on the item's own
-- tooltip. Whether the look is already yours, and how far along the set it belongs
-- to is, are otherwise questions you answer by putting the item down and going
-- through the wardrobe looking for it.
LuckysWardrobe = LuckysWardrobe or {}
LuckysWardrobe.ItemTooltips = {}

local ItemTooltips = LuckysWardrobe.ItemTooltips

-- The colours the set tracker answers these same two questions in, so a piece
-- reads the same on a tooltip as it does in the list.
local COLLECTED_COLOUR = { 0.41, 0.86, 0.49 }
local MISSING_COLOUR = { 1, 0.42, 0.42 }
local SET_COLOUR = { 0.91, 0.86, 0.78 }

local db

-- Which set a piece belongs to is fixed for the life of the client, so it is asked
-- once per piece. What is collected changes all session, so those answers are
-- thrown away whenever the collection says something moved.
local setBySource = {}
local knownLooks, setProgress = {}, {}

local function forgetCollection()
    knownLooks, setProgress = {}, {}
end

local function anySourceCollected(sourceIDs)
    for _, sourceID in ipairs(sourceIDs or {}) do
        if C_TransmogCollection.PlayerHasTransmogItemModifiedAppearance(sourceID) then
            return true
        end
    end
    return false
end

-- A look is yours once any item teaching it is, which is what the wardrobe counts
-- and what someone holding an item means by having it already. So an item's own
-- source settles it where the player has that one, and every other item wearing
-- the same look is asked where they do not.
local function knowsLook(visualID, sourceID)
    local known = knownLooks[sourceID]
    if known == nil then
        known = C_TransmogCollection.PlayerHasTransmogItemModifiedAppearance(sourceID) == true
        if not known and visualID then
            known = anySourceCollected(C_TransmogCollection.GetAllAppearanceSources(visualID))
        end
        knownLooks[sourceID] = known
    end
    return known
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

--- What this addon has to say about an item, as lines ready for a tooltip.
-- Handed back rather than drawn, so what an item would say can be read without a
-- tooltip to hang it on. Nil for anything carrying no appearance, which is most of
-- what passes through a bag.
function ItemTooltips:Lines(itemInfo)
    if itemInfo == nil then return nil end
    if not db.tooltipAppearanceCollected and not db.tooltipSetProgress then return nil end

    local visualID, sourceID = C_TransmogCollection.GetItemInfo(itemInfo)
    if not sourceID then return nil end

    local lines = {}

    if db.tooltipAppearanceCollected then
        local known = knowsLook(visualID, sourceID)
        lines[#lines + 1] = {
            text = known and TRANSMOGRIFY_TOOLTIP_APPEARANCE_KNOWN or TRANSMOGRIFY_TOOLTIP_APPEARANCE_UNKNOWN,
            colour = known and COLLECTED_COLOUR or MISSING_COLOUR,
        }
    end

    if db.tooltipSetProgress then
        local set = setFor(sourceID)
        local progress = set and progressOf(set.setID)
        -- A set this client lists no pieces for has no progress to report, and
        -- "0/0" is a worse answer than saying nothing.
        if progress and progress.total > 0 then
            lines[#lines + 1] = {
                text = LuckysWardrobe.Strings.tooltips.setProgress:format(set.name,
                    progress.collected, progress.total),
                colour = progress.collected == progress.total and COLLECTED_COLOUR or SET_COLOUR,
            }
        end
    end

    return #lines > 0 and lines or nil
end

local function addLines(tooltip, data)
    -- The tooltips someone reads an item on. The shopping tooltips alongside them
    -- are there to be compared against what is worn, and the same two lines
    -- repeated down each of those is noise rather than an answer.
    if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end

    -- The link carries the bonus IDs that say which version of a piece this is, so
    -- a raid item resolves to its own difficulty's appearance. An item ID alone
    -- resolves to whichever difficulty came first, and is only fallen back on where
    -- the tooltip has no link to offer.
    local _, itemLink = TooltipUtil.GetDisplayedItem(tooltip)
    for _, line in ipairs(ItemTooltips:Lines(itemLink or (data and data.id)) or {}) do
        tooltip:AddLine(line.text, line.colour[1], line.colour[2], line.colour[3])
    end
end

function ItemTooltips:Init(database)
    db = database
    forgetCollection()

    local events = CreateFrame("Frame")
    events:RegisterEvent("TRANSMOG_COLLECTION_UPDATED")
    events:SetScript("OnEvent", forgetCollection)

    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, addLines)
end
