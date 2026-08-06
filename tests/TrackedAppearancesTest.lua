-- luacheck: globals CreateFrame CreateTextureMarkup EventUtil GameTooltip LuckysWardrobe WardrobeCollectionFrame hooksecurefunc

-- The mark answers a set being opened, tracking starting or stopping while it is
-- open, and the setting being turned off, so these go through all three. Hovering
-- a marked piece has to say in words what the mark on it means.

function CreateTextureMarkup(path) return "[" .. path .. "]" end

GameTooltip = {
    lines = {},
    AddLine = function(self, text) self.lines[#self.lines + 1] = text end,
    Show = function(self) self.shown = true end,
}

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
local hintedSource
local missingBySet = {}
LuckysWardrobe = {
    Strings = { tracking = { hovered = "You are tracking this appearance." } },
    SetTracking = {
        IsTracking = function(_, sourceID) return tracked[sourceID] == true end,
        IsTrackingAll = function(_, sourceIDs)
            if #sourceIDs == 0 then return false end
            for _, sourceID in ipairs(sourceIDs) do
                if not tracked[sourceID] then return false end
            end
            return true
        end,
        MissingSourcesForSet = function(_, setID) return missingBySet[setID] or {} end,
        AddTrackHint = function(_, _, sourceID)
            hintedSource = sourceID
            return false
        end,
    },
}

local function Texture()
    local texture = { shown = false }
    function texture:SetTexture(path) self.path = path end
    function texture:SetSize(width, height) self.width, self.height = width, height end
    function texture:SetVertexColor(...) self.colour = { ... } end
    function texture:SetPoint(...) self.point = { ... } end
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
    RefreshAppearanceTooltip = function() end,
    GetDefaultSetIDForBaseSet = function(_, setID) return setID end,
}

-- The list's own rows, one per set. ForEachFrame stands in for the ScrollBox
-- walking whatever is currently visible.
local setRow = ItemFrame()
setRow.setID = 10
local listScrollBox = {
    Update = function() end,
    ForEachFrame = function(_, callback) callback(setRow) end,
}
setsCollection.ListContainer = { ScrollBox = listScrollBox }

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

-- A badge in the corner of the icon, not a mark across the item art.
assert(crosshair(setPieces[2]).point[1] == "BOTTOMRIGHT", "sat the mark in the corner of the icon")

-- Hovering a piece in the Sets tab says in words what the mark means, and
-- hovering an unmarked one says nothing.
setsCollection.tooltipPrimarySourceID = 102
setsCollection:RefreshAppearanceTooltip()
assert(GameTooltip.lines[#GameTooltip.lines]:find(LuckysWardrobe.Strings.tracking.hovered, 1, true),
    "told the hovered piece's tooltip it is being tracked")

-- A piece nobody is hunting yet is handed on to be offered the shift-click that
-- would start, rather than told it is being tracked.
local said = #GameTooltip.lines
setsCollection.tooltipPrimarySourceID = 101
setsCollection:RefreshAppearanceTooltip()
assert(#GameTooltip.lines == said, "said nothing itself over a piece nobody is hunting")
assert(hintedSource == 101, "handed that piece on to be offered the shift-click")

-- The same texture answers every update rather than a fresh one stacking up.
local texture = crosshair(setPieces[2])
events.handler()
assert(crosshair(setPieces[2]) == texture, "reused the mark it had already built")

tracked[102] = nil
events.handler()
assert(not marked(setPieces[2]), "cleared the mark when tracking stopped")

-- The list's own rows mark by set rather than by piece: every last piece the
-- set is missing has to be tracked before the row earns the crosshair.
missingBySet[10] = { 201, 202 }
tracked[201] = true
listScrollBox:Update()
assert(not marked(setRow), "left a set's row alone until every last piece is tracked")

tracked[202] = true
listScrollBox:Update()
assert(marked(setRow), "marked a set's row once every missing piece was tracked")

-- A set's mark sits in its own row's corner the same way a piece's sits in its
-- icon's, just bigger since there is no icon to share the corner with.
assert(crosshair(setRow).point[1] == "BOTTOMRIGHT", "sat the mark in the corner of the row")
assert(crosshair(setRow).width > crosshair(setPieces[2]).width, "made the set's mark bigger than a piece's")

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
assert(not marked(setPieces[1]) and not marked(extraPiece) and not marked(setRow),
    "cleared every mark when the setting was turned off")

db.markTrackedAppearances = true
TrackedAppearances:Refresh()
assert(marked(setPieces[1]) and marked(extraPiece) and marked(setRow),
    "marked them again when the setting came back on")

-- The tooltip line goes quiet with the setting, so the two never disagree.
db.markTrackedAppearances = false
said = #GameTooltip.lines
setsCollection.tooltipPrimarySourceID = 101
setsCollection:RefreshAppearanceTooltip()
assert(#GameTooltip.lines == said, "said nothing over a piece while the setting is off")

print("Lucky's Wardrobe tracked appearances test passed")
