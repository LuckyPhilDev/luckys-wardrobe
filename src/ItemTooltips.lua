-- Lucky's Wardrobe: What an item is worth to a collection, said on the item's own
-- tooltip. Which set a piece belongs to, and how much of that set is already yours,
-- is otherwise a question you answer by putting the item down and going through the
-- wardrobe looking for it. Both lists of sets are asked, Blizzard's and the one
-- behind the Extra Sets tab, so the answer does not depend on which of them a set
-- happens to be in.
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
--
-- The two lists are counted apart because the two number their sets differently:
-- the bundled snapshot numbers a set the way Wowhead does and the client numbers
-- its own, so the same number means one set in one list and another set in the
-- other.
local setBySource = {}
local extraBySource
local setProgress, extraProgress = {}, {}

local function forgetProgress()
    setProgress, extraProgress = {}, {}
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

local function progressOf(set)
    local progress = setProgress[set.setID]
    if not progress then
        progress = { name = set.name, collected = 0, total = 0 }
        for _, appearance in ipairs(C_TransmogSets.GetSetPrimaryAppearances(set.setID) or {}) do
            progress.total = progress.total + 1
            if appearance.collected then progress.collected = progress.collected + 1 end
        end
        setProgress[set.setID] = progress
    end
    return progress
end

--- The set a piece belongs to among the ones only the Extra Sets tab lists, with
--- the same counts that tab puts on it, or nil for a piece in none of them.
-- Blizzard's Sets tab lists a fraction of the sets the client holds, so a piece it
-- says belongs to nothing may still belong to a set the player can see elsewhere in
-- this very addon. Nothing to say until the catalogue has been built, which it is
-- on entering the world.
local function extraSetFor(sourceID)
    if not extraBySource then
        if not LuckysWardrobe.ExtraSetsCatalog:IsReady() then return nil end

        extraBySource = {}
        for _, record in ipairs(LuckysWardrobe.ExtraSetsCatalog:GetRecords()) do
            for _, piece in ipairs(record.pieces) do
                extraBySource[piece.sourceID] = extraBySource[piece.sourceID] or record
            end
        end
    end

    local record = extraBySource[sourceID]
    if not record then return nil end

    local counted = extraProgress[record.setID]
    if not counted then
        -- Counted the way the Extra Sets tab counts, so the two can never disagree
        -- about how far along a set is. A count taken while the client is still
        -- loading the pieces is not kept, since nothing else would come back to
        -- correct it.
        counted = LuckysWardrobe.ExtraSets.BuildEntry(record, LuckysWardrobe.ExtraSets.LiveResolver())
        if not counted.loading then extraProgress[record.setID] = counted end
    end
    return counted
end

--- The line this addon has to add to an item's tooltip, ready to be drawn.
-- Handed back rather than drawn, so what an item would say can be read without a
-- tooltip to hang it on. Nil for anything in no set, which is most of what passes
-- through a bag.
function ItemTooltips:Line(itemInfo)
    if itemInfo == nil or not db.tooltipSetProgress then return nil end

    local _, sourceID = C_TransmogCollection.GetItemInfo(itemInfo)
    if not sourceID then return nil end

    local set = setFor(sourceID)
    local progress = set and progressOf(set) or extraSetFor(sourceID)
    -- A set this client lists no pieces for has no progress to report, and "0/0" is
    -- a worse answer than saying nothing.
    if not progress or progress.total == 0 then return nil end

    local S = LuckysWardrobe.Strings.tooltips
    local count = S.setProgress:format(progress.collected, progress.total)
    return {
        text = S.setLine:format(coloured(NAME_COLOUR, progress.name),
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
