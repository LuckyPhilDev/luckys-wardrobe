-- luacheck: globals CreateFrame CreateTextureMarkup EventUtil GameTooltip WardrobeCollectionFrame hooksecurefunc

-- Lucky's Wardrobe: A crosshair on the set pieces you are tracking, so an open
-- set says which of its pieces you are out hunting for.
LuckysWardrobe = LuckysWardrobe or {}
LuckysWardrobe.TrackedAppearances = {}

local TrackedAppearances = LuckysWardrobe.TrackedAppearances

local CROSSHAIR = "Interface\\AddOns\\Luckys_Wardrobe\\Images\\icons\\tracked-appearance"
local CROSSHAIR_FILE_SIZE = 64
-- A badge in the corner of a piece's icon rather than a mark across it, so the
-- item art it belongs to still reads.
local CROSSHAIR_SIZE = 16
local CROSSHAIR_INSET = 2
-- The settings panel's accentLight, so the mark reads as this addon's rather
-- than part of the game's own collection art.
local CROSSHAIR_COLOUR = { r = 0.910, g = 0.690, b = 0.251 }

local db
local marked = {}

local function crosshairFor(itemFrame)
    if not itemFrame.luckysTrackedCrosshair then
        local crosshair = itemFrame:CreateTexture(nil, "OVERLAY", nil, 7)
        crosshair:SetTexture(CROSSHAIR)
        crosshair:SetSize(CROSSHAIR_SIZE, CROSSHAIR_SIZE)
        crosshair:SetVertexColor(CROSSHAIR_COLOUR.r, CROSSHAIR_COLOUR.g, CROSSHAIR_COLOUR.b)
        -- The icon is inset from the frame it sits in, so the mark is inset by
        -- the same amount to land on the icon's own corner.
        crosshair:SetPoint("BOTTOMRIGHT", -CROSSHAIR_INSET, CROSSHAIR_INSET)
        itemFrame.luckysTrackedCrosshair = crosshair
    end
    return itemFrame.luckysTrackedCrosshair
end

-- Whether a piece carries the mark, which is what the tooltip line answers to
-- as well, so both go quiet together when the setting is off.
function TrackedAppearances:IsMarked(sourceID)
    if not db.markTrackedAppearances or sourceID == nil then return false end
    return LuckysWardrobe.SetTracking:IsTracking(sourceID)
end

local function refreshFrame(itemFrame)
    local hunted = TrackedAppearances:IsMarked(itemFrame.luckysTrackedSourceID)

    -- A piece nobody is hunting is left as the page drew it, so the mark costs
    -- nothing until there is something to mark.
    if not hunted and not itemFrame.luckysTrackedCrosshair then return end

    crosshairFor(itemFrame):SetShown(hunted)
end

-- A mark on an icon is only half an answer, so hovering the piece says it in
-- words. Reports whether it had anything to say, since a page with its own
-- tracking hint has no business offering it for a piece already tracked.
function TrackedAppearances:AddTooltipLine(tooltip, sourceID)
    if not self:IsMarked(sourceID) then return false end

    local icon = CreateTextureMarkup(CROSSHAIR, CROSSHAIR_FILE_SIZE, CROSSHAIR_FILE_SIZE, 14, 14, 0, 1, 0, 1, 0, -2)
    tooltip:AddLine(icon .. " " .. LuckysWardrobe.Strings.tracking.hovered,
        CROSSHAIR_COLOUR.r, CROSSHAIR_COLOUR.g, CROSSHAIR_COLOUR.b)
    tooltip:Show()
    return true
end

-- Which piece a frame is showing, so it can be marked now and answer tracking
-- changes later. Pass no source for a piece this client cannot resolve.
function TrackedAppearances:Mark(itemFrame, sourceID)
    if not itemFrame.luckysTrackedRegistered then
        itemFrame.luckysTrackedRegistered = true
        marked[#marked + 1] = itemFrame
    end

    itemFrame.luckysTrackedSourceID = sourceID
    refreshFrame(itemFrame)
end

-- Answers tracking starting or stopping while a set is open, and the setting
-- being turned off and on again.
function TrackedAppearances:Refresh()
    for _, itemFrame in ipairs(marked) do
        refreshFrame(itemFrame)
    end
end

function TrackedAppearances:Init(database)
    db = database

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("CONTENT_TRACKING_UPDATE")
    eventFrame:SetScript("OnEvent", function()
        TrackedAppearances:Refresh()
    end)

    -- The Sets tab pools its piece frames and lays them out afresh for every set
    -- it opens, so the marks are put on at the end of the same call. The Extra
    -- Sets tab marks its own pieces as it draws them.
    EventUtil.ContinueOnAddOnLoaded("Blizzard_Collections", function()
        local setsCollection = WardrobeCollectionFrame.SetsCollectionFrame

        hooksecurefunc(setsCollection, "DisplaySet", function(self)
            for itemFrame in self.DetailsFrame.itemFramesPool:EnumerateActive() do
                TrackedAppearances:Mark(itemFrame, itemFrame.sourceID)
            end
        end)

        -- Every drawing of a piece's tooltip lands here, the first hover and
        -- each press of Tab that cycles to another item with the same look. A
        -- piece already tracked is told so; one that is not is offered the
        -- shift-click that would track it.
        hooksecurefunc(setsCollection, "RefreshAppearanceTooltip", function(self)
            local sourceID = self.tooltipPrimarySourceID
            if not TrackedAppearances:AddTooltipLine(GameTooltip, sourceID) then
                LuckysWardrobe.SetTracking:AddTrackHint(GameTooltip, sourceID)
            end
        end)
    end)
end
