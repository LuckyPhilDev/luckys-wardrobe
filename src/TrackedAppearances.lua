-- luacheck: globals CreateFrame EventUtil WardrobeCollectionFrame hooksecurefunc

-- Lucky's Wardrobe: A crosshair over the set pieces you are tracking, so an
-- open set says which of its pieces you are out hunting for.
LuckysWardrobe = LuckysWardrobe or {}
LuckysWardrobe.TrackedAppearances = {}

local TrackedAppearances = LuckysWardrobe.TrackedAppearances

local CROSSHAIR = "Interface\\AddOns\\Luckys_Wardrobe\\Images\\icons\\tracked-appearance"
-- Sized to ring the 28px icon inside a piece's 32px frame, so the mark reads
-- over the icon without hiding it.
local CROSSHAIR_SIZE = 26
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
        crosshair:SetPoint("CENTER")
        itemFrame.luckysTrackedCrosshair = crosshair
    end
    return itemFrame.luckysTrackedCrosshair
end

local function refreshFrame(itemFrame)
    local sourceID = itemFrame.luckysTrackedSourceID
    local hunted = db.markTrackedAppearances
        and sourceID ~= nil
        and LuckysWardrobe.SetTracking:IsTracking(sourceID)

    -- A piece nobody is hunting is left as the page drew it, so the mark costs
    -- nothing until there is something to mark.
    if not hunted and not itemFrame.luckysTrackedCrosshair then return end

    crosshairFor(itemFrame):SetShown(hunted)
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
        hooksecurefunc(WardrobeCollectionFrame.SetsCollectionFrame, "DisplaySet", function(self)
            for itemFrame in self.DetailsFrame.itemFramesPool:EnumerateActive() do
                TrackedAppearances:Mark(itemFrame, itemFrame.sourceID)
            end
        end)
    end)
end
