-- luacheck: globals CreateFrame EventUtil LuckysWardrobe WardrobeCollectionFrame hooksecurefunc

-- The mark answers a set being opened, tracking starting or stopping while it is
-- open, and the setting being turned off, so these go through all three.

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

local events = {}
function CreateFrame()
    return {
        RegisterEvent = function(_, event) events[event] = true end,
        SetScript = function(_, _, handler) events.handler = handler end,
    }
end

local tracked = {}
LuckysWardrobe = { SetTracking = {
    IsTracking = function(_, sourceID) return tracked[sourceID] == true end,
} }

local function Texture()
    local texture = { shown = false }
    function texture:SetTexture(path) self.path = path end
    function texture:SetSize(width, height) self.width, self.height = width, height end
    function texture:SetVertexColor(...) self.colour = { ... } end
    function texture:SetPoint() end
    function texture:SetShown(shown) self.shown = shown end
    return texture
end

local function ItemFrame(sourceID)
    local itemFrame = { sourceID = sourceID }
    function itemFrame:CreateTexture() return Texture() end
    return itemFrame
end

-- Blizzard's Sets tab pools its piece frames and lays them out afresh for each
-- set it opens, so the pool is what says which pieces are on show.
local setPieces = { ItemFrame(101), ItemFrame(102) }
local setsCollection = {
    DetailsFrame = {
        itemFramesPool = {
            EnumerateActive = function(self)
                local index = 0
                return function()
                    index = index + 1
                    return self.active[index]
                end
            end,
            active = setPieces,
        },
    },
    DisplaySet = function() end,
}

WardrobeCollectionFrame = { SetsCollectionFrame = setsCollection }

dofile("src/TrackedAppearances.lua")

local TrackedAppearances = LuckysWardrobe.TrackedAppearances
local db = { markTrackedAppearances = true }
TrackedAppearances:Init(db)

assert(events.CONTENT_TRACKING_UPDATE, "listened for tracking changes")

local function crosshair(itemFrame)
    return itemFrame.luckysTrackedCrosshair
end

local function marked(itemFrame)
    return crosshair(itemFrame) ~= nil and crosshair(itemFrame).shown
end

-- A set nobody is hunting is left as the tab drew it, down to building no
-- texture for it.
setsCollection:DisplaySet(1)
assert(not crosshair(setPieces[1]), "built nothing for a set nobody is hunting")

-- Tracking one of its pieces while the set is open marks that piece alone.
tracked[102] = true
events.handler()
assert(marked(setPieces[2]), "marked the piece being hunted")
assert(not marked(setPieces[1]), "left the rest of the set alone")

-- The same texture answers every update rather than a fresh one stacking up.
local texture = crosshair(setPieces[2])
events.handler()
assert(crosshair(setPieces[2]) == texture, "reused the mark it had already built")

tracked[102] = nil
events.handler()
assert(not marked(setPieces[2]), "cleared the mark when tracking stopped")

-- The Extra Sets tab hands its own pieces over as it draws them, and a piece
-- this client cannot resolve hands over nothing.
local extraPiece = ItemFrame()
local unresolvedPiece = ItemFrame()
tracked[201] = true
TrackedAppearances:Mark(extraPiece, 201)
TrackedAppearances:Mark(unresolvedPiece, nil)
assert(marked(extraPiece), "marked a tracked piece on the Extra Sets tab")
assert(not crosshair(unresolvedPiece), "left a piece with no source unmarked")

-- Pieces marked before are still answering, whichever tab they came from.
tracked[101] = true
setsCollection:DisplaySet(1)
db.markTrackedAppearances = false
TrackedAppearances:Refresh()
assert(not marked(setPieces[1]) and not marked(extraPiece), "cleared every mark when the setting was turned off")

db.markTrackedAppearances = true
TrackedAppearances:Refresh()
assert(marked(setPieces[1]) and marked(extraPiece), "marked them again when the setting came back on")

print("Lucky's Wardrobe tracked appearances test passed")
