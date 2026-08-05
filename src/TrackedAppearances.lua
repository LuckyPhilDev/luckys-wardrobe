-- luacheck: globals EventUtil WardrobeCollectionFrame hooksecurefunc

-- Lucky's Wardrobe: A crosshair on the appearances you are tracking, so the
-- Items tab shows what you are hunting for without hovering a thing.
LuckysWardrobe = LuckysWardrobe or {}
LuckysWardrobe.TrackedAppearances = {}

local TrackedAppearances = LuckysWardrobe.TrackedAppearances

local CROSSHAIR = "Interface\\AddOns\\Luckys_Wardrobe\\Images\\icons\\tracked-appearance"
local CROSSHAIR_SIZE = 24
-- The panel's accentLight, so the mark reads as this addon's rather than the
-- game's own collection art.
local CROSSHAIR_COLOUR = { r = 0.910, g = 0.690, b = 0.251 }

local db
local models = {}

local function crosshairFor(model)
    if not model.luckysTrackedCrosshair then
        local crosshair = model:CreateTexture(nil, "OVERLAY", nil, 2)
        crosshair:SetTexture(CROSSHAIR)
        crosshair:SetSize(CROSSHAIR_SIZE, CROSSHAIR_SIZE)
        crosshair:SetVertexColor(CROSSHAIR_COLOUR.r, CROSSHAIR_COLOUR.g, CROSSHAIR_COLOUR.b)
        crosshair:SetPoint("BOTTOMRIGHT", model, "BOTTOMRIGHT", -2, 2)
        model.luckysTrackedCrosshair = crosshair
    end
    return model.luckysTrackedCrosshair
end

-- Rides the game's own tracking tick, which is refreshed on every page turn,
-- every click that starts or stops tracking, and every tracking update from
-- elsewhere. That is the whole set of moments the mark has to answer to.
local function markModel(model, isTracked)
    local crosshair = model.luckysTrackedCrosshair

    if not db.markTrackedAppearances then
        if crosshair then crosshair:Hide() end
        return
    end

    -- A tick reads as something already collected, which is the opposite of what
    -- a tracked appearance is, so the crosshair stands in its place.
    if model.ContentTrackingCheckmark then model.ContentTrackingCheckmark:Hide() end

    if isTracked then
        crosshairFor(model):Show()
    elseif crosshair then
        crosshair:Hide()
    end
end

-- Every model reports its own tracking again, which puts the tick back when the
-- setting is turned off and the crosshair back when it is turned on.
function TrackedAppearances:Refresh()
    for _, model in ipairs(models) do
        model:UpdateTrackingCheckmark()
    end
end

function TrackedAppearances:Init(database)
    db = database

    EventUtil.ContinueOnAddOnLoaded("Blizzard_Collections", function()
        models = WardrobeCollectionFrame.ItemsCollectionFrame.Models
        for _, model in ipairs(models) do
            hooksecurefunc(model, "SetTrackingCheckmarkShown", markModel)
        end
    end)
end
