-- luacheck: globals EventUtil LuckysWardrobe WardrobeCollectionFrame hooksecurefunc

-- The mark rides Blizzard's own tracking tick, so these go through the model the
-- way the Items tab drives it: a page turn, a click that starts or stops
-- tracking, and the setting being turned off and on again.

function hooksecurefunc(target, name, hook)
    local stock = target[name]
    target[name] = function(...)
        stock(...)
        hook(...)
    end
end

EventUtil = {
    ContinueOnAddOnLoaded = function(_, callback) callback() end,
}

local function Texture()
    local texture = { shown = false }
    function texture:SetTexture(path) self.path = path end
    function texture:SetSize(width, height) self.width, self.height = width, height end
    function texture:SetVertexColor(...) self.colour = { ... } end
    function texture:SetPoint() end
    function texture:Show() self.shown = true end
    function texture:Hide() self.shown = false end
    function texture:SetShown(shown) self.shown = shown end
    return texture
end

-- Stands in for the parts of Blizzard's appearance model this feature touches.
-- The tick is built on the first showing, as the game builds it.
local function AppearanceModel()
    local model = { isTracked = false }
    function model:CreateTexture() return Texture() end
    function model:SetTrackingCheckmarkShown(shown)
        if not self.ContentTrackingCheckmark then
            if not shown then return end
            self.ContentTrackingCheckmark = self:CreateTexture()
        end
        self.ContentTrackingCheckmark:SetShown(shown)
    end
    function model:UpdateTrackingCheckmark()
        self:SetTrackingCheckmarkShown(self.isTracked)
    end
    return model
end

local hunted = AppearanceModel()
local ignored = AppearanceModel()

WardrobeCollectionFrame = {
    ItemsCollectionFrame = { Models = { hunted, ignored } },
}

dofile("src/TrackedAppearances.lua")

local TrackedAppearances = LuckysWardrobe.TrackedAppearances

-- Someone can open the settings panel before they ever open Collections.
TrackedAppearances:Refresh()

local db = { markTrackedAppearances = true }
TrackedAppearances:Init(db)

local function crosshairShown(model)
    return model.luckysTrackedCrosshair and model.luckysTrackedCrosshair.shown or false
end

local function tickShown(model)
    return model.ContentTrackingCheckmark and model.ContentTrackingCheckmark.shown or false
end

-- A page of appearances nobody is hunting stays unmarked, and no texture is
-- built for one.
hunted:UpdateTrackingCheckmark()
ignored:UpdateTrackingCheckmark()
assert(not hunted.luckysTrackedCrosshair, "built nothing for an untracked appearance")
assert(not crosshairShown(hunted) and not crosshairShown(ignored), "marked nothing")

hunted.isTracked = true
hunted:UpdateTrackingCheckmark()
assert(crosshairShown(hunted), "marked the appearance being tracked")
assert(not tickShown(hunted), "took the tick off, so the tile carries one mark")
assert(not crosshairShown(ignored), "left the rest of the page alone")

-- The same texture answers every refresh rather than a fresh one stacking up.
local crosshair = hunted.luckysTrackedCrosshair
hunted:UpdateTrackingCheckmark()
assert(hunted.luckysTrackedCrosshair == crosshair, "reused the mark it had already built")

-- Stopping tracking is reported through the same call the game makes.
hunted.isTracked = false
hunted:UpdateTrackingCheckmark()
assert(not crosshairShown(hunted), "cleared the mark when tracking stopped")

hunted.isTracked = true
hunted:UpdateTrackingCheckmark()

db.markTrackedAppearances = false
TrackedAppearances:Refresh()
assert(not crosshairShown(hunted), "cleared the marks when the setting was turned off")
assert(tickShown(hunted), "handed the tile back to the game's own tick")

db.markTrackedAppearances = true
TrackedAppearances:Refresh()
assert(crosshairShown(hunted), "marked it again when the setting came back on")
assert(not tickShown(hunted), "took the tick back off")

print("Lucky's Wardrobe tracked appearances test passed")
