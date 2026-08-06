-- luacheck: globals C_Item C_TransmogCollection CreateFrame Enum GameTooltip GetScreenWidth GetUICameraInfo IsUnitModelReadyForUI ItemRefTooltip Model_ApplyUICamera TooltipDataProcessor TooltipUtil UIParent

-- Lucky's Wardrobe: What a piece actually looks like, shown beside its tooltip.
-- An icon says almost nothing about the appearance an item carries, and the only
-- way to see the piece itself was to open the dressing room and put it on. The
-- preview shows the piece the way the wardrobe shows an appearance: the item
-- alone, close up, with nothing else on and nothing else in frame.
LuckysWardrobe = LuckysWardrobe or {}
LuckysWardrobe.TooltipModel = {}

local TooltipModel = LuckysWardrobe.TooltipModel

-- The shape the wardrobe frames an appearance in, which is the shape its cameras
-- are built for, at a size that can be read beside a tooltip.
local WIDTH, HEIGHT = 210, 280
local INSET = 8

-- The slots the game holds a model for on its own, which is everything carried.
-- Those are shown alone, with no character behind them at all.
--
-- Armour is not. A chestpiece is a texture painted onto a character and geometry
-- belonging to that character, so there is no chestpiece to put in a frame, only
-- somebody wearing one. Helms and shoulders looked like exceptions, being models
-- rather than skin, but asking the client for one on its own draws nothing at
-- all, so they go on the figure with the rest of a suit.
local ALONE = {
    INVTYPE_WEAPON = true,
    INVTYPE_2HWEAPON = true,
    INVTYPE_WEAPONMAINHAND = true,
    INVTYPE_WEAPONOFFHAND = true,
    INVTYPE_RANGED = true,
    INVTYPE_RANGEDRIGHT = true,
    INVTYPE_SHIELD = true,
    INVTYPE_HOLDABLE = true,
}

-- How each slot is framed. The wardrobe's own camera is asked for first, but the
-- client answers for almost nothing, so the framing here does the work.
--
-- Facing is a fraction of a full turn. Zoom is how far the camera sits back, so
-- under 1 is closer and over 1 is further. Height lifts the figure, bringing what
-- is below it into the middle of the shot, and side slides it across.
--
-- Height and zoom pull against each other: how far up the figure a shot lands is
-- the height divided by the zoom, so the same height frames the knees at one zoom
-- and empty sky above the head at another. Overshoot the head or the feet and the
-- frame comes out black, there being nothing there to draw.
--
-- Only the two slots that have been looked at in game are framed. Feet is the
-- ankle and cloak is the figure turned around, both arrived at by trying them.
-- Every other slot is left at the whole figure, which is a plain shot rather than
-- a wrong one, until it has been seen and settled the same way. The rest are here
-- rather than absent so /wardrobe preview lists them to work through.
local FRAMING = {
    INVTYPE_FEET = { facing = 0, zoom = 0.35, height = 0.8, side = 0 },
    INVTYPE_CLOAK = { facing = 0.5, zoom = 0.6, height = -0.2, side = 0 },
    INVTYPE_HEAD = { facing = 0, zoom = 1, height = 0, side = 0 },
    INVTYPE_SHOULDER = { facing = 0, zoom = 1, height = 0, side = 0 },
    INVTYPE_CHEST = { facing = 0, zoom = 1, height = 0, side = 0 },
    INVTYPE_ROBE = { facing = 0, zoom = 1, height = 0, side = 0 },
    INVTYPE_BODY = { facing = 0, zoom = 1, height = 0, side = 0 },
    INVTYPE_TABARD = { facing = 0, zoom = 1, height = 0, side = 0 },
    INVTYPE_WRIST = { facing = 0, zoom = 1, height = 0, side = 0 },
    INVTYPE_HAND = { facing = 0, zoom = 1, height = 0, side = 0 },
    INVTYPE_WAIST = { facing = 0, zoom = 1, height = 0, side = 0 },
    INVTYPE_LEGS = { facing = 0, zoom = 1, height = 0, side = 0 },
}

-- What the slots are called when asked for by hand, for the ones a person would
-- not guess the game's own name for.
local SLOT_ALIASES = {
    hands = "INVTYPE_HAND",
    shirt = "INVTYPE_BODY",
    twohand = "INVTYPE_2HWEAPON",
    offhand = "INVTYPE_WEAPONOFFHAND",
}

local db

-- The last piece asked about, kept so the report can say what the client
-- answered for it. Every complaint about a preview is a complaint about one of
-- these numbers.
local lastLook

--- What the preview should show for a hovered item, or nil for an item there is
--- nothing to show.
-- Handed back rather than drawn, so what an item would put in the frame can be
-- read without a tooltip to hang it beside. Most of what passes through a bag is
-- nothing anybody could wear.
function TooltipModel:Preview(itemInfo)
    if itemInfo == nil or not db.tooltipModel then return nil end

    local itemID, _, _, equipSlot = C_Item.GetItemInfoInstant(itemInfo)
    if not itemID or not C_Item.IsDressableItemByID(itemID) then return nil end

    -- The appearance is what the wardrobe knows a piece by, and it carries the
    -- camera that frames this slot on this character. An item with no appearance
    -- at all can still be worn, and is shown from wherever the model opens.
    local appearanceID, sourceID = C_TransmogCollection.GetItemInfo(itemInfo)
    local look = {
        item = itemInfo,
        itemID = itemID,
        appearanceID = appearanceID,
        sourceID = sourceID,
        equipSlot = equipSlot,
        alone = ALONE[equipSlot] or false,
        cameraID = sourceID and C_TransmogCollection.GetAppearanceCameraIDBySource(sourceID) or nil,
    }
    lastLook = look
    return look
end

local function isFurther(edge, than, towardLeft)
    if towardLeft then return edge < than end
    return edge > than
end

-- Comparison tooltips open beside the tooltip they belong to, so the preview
-- hangs off whichever of them reaches furthest in the direction it is opening,
-- rather than off the tooltip itself, which they would then cover.
local function outermostShown(tooltip, towardLeft)
    local furthest = tooltip
    for _, comparison in ipairs(tooltip.shoppingTooltips or {}) do
        local edge = comparison:IsShown()
            and (towardLeft and comparison:GetLeft() or comparison:GetRight())
        local furthestEdge = towardLeft and furthest:GetLeft() or furthest:GetRight()
        if edge and furthestEdge and isFurther(edge, furthestEdge, towardLeft) then
            furthest = comparison
        end
    end
    return furthest
end

--- Which side of a tooltip the preview opens on, and what it hangs off.
-- Whichever side of the tooltip has more screen left on it, so a tooltip against
-- the right edge, which is where the bags are, opens its preview to the left.
function TooltipModel.Anchor(tooltip)
    local towardLeft = (GetScreenWidth() - (tooltip:GetRight() or 0)) < (tooltip:GetLeft() or 0)
    local against = outermostShown(tooltip, towardLeft)
    if towardLeft then return "TOPRIGHT", against, "TOPLEFT" end
    return "TOPLEFT", against, "TOPRIGHT"
end

-- Two frames, because the two kinds of preview are two different things: a model
-- standing on its own, and a bare figure wearing what the game has no model for.
local panel, alone, figure
-- The tooltip the preview belongs to, the piece it is meant to be showing, and
-- what the models actually have in them. The last outlives a hide: a tooltip
-- that closes and reopens on the same item, as the auction house does with every
-- refresh, should not cost a reload.
local shownFor, shownLook, showing, showingAlone
local figureReady = false
local anchor = {}

local TURN = math.pi * 2

-- The camera frames the slot the piece sits in, and the slot's own framing takes
-- it the rest of the way. Both have to be applied again every time the model
-- underneath them is loaded, which is why each model keeps the look it was given.
local function frameOn(model, look)
    model.look = look
    -- Back to where a model opens before either of them is applied. The camera
    -- puts the model where it wants it, but a piece whose appearance the client
    -- has no camera for would otherwise keep the last piece's framing and take
    -- another slot's turn and lift on top of it.
    model:SetFacing(0)
    model:SetPosition(0, 0, 0)
    model:SetCamDistanceScale(1)

    if look.cameraID then
        model:RefreshCamera()
        Model_ApplyUICamera(model, look.cameraID)
    end

    local framing = FRAMING[look.equipSlot]
    if not framing then return end

    if framing.facing ~= 0 then model:SetFacing(model:GetFacing() + framing.facing * TURN) end
    if framing.zoom ~= 1 then model:SetCamDistanceScale(framing.zoom) end
    if framing.height ~= 0 or framing.side ~= 0 then
        local x, y, z = model:GetPosition()
        model:SetPosition(x, y + framing.side, z + framing.height)
    end
end

local function show(look)
    local model = look.alone and alone or figure
    alone:SetShown(look.alone)
    figure:SetShown(not look.alone)
    if showing == look.item and showingAlone == look.alone then return end

    if look.alone then
        if look.appearanceID then
            alone:SetItemAppearance(look.appearanceID)
        else
            alone:SetItem(look.itemID)
        end
    else
        -- Stripped rather than dressed: the piece is the whole of what the
        -- preview is for, and a tabard or a robe over it answers nothing.
        figure:Undress()
        figure:TryOn(look.item)
    end

    frameOn(model, look)
    showing, showingAlone = look.item, look.alone
end

local function reanchor()
    local point, against, relativePoint = TooltipModel.Anchor(shownFor)
    if anchor.point == point and anchor.against == against
        and anchor.relativePoint == relativePoint then
        return
    end

    panel:ClearAllPoints()
    panel:SetPoint(point, against, relativePoint)
    anchor.point, anchor.against, anchor.relativePoint = point, against, relativePoint
end

local function createModel()
    local model = CreateFrame("DressUpModel", nil, panel)
    model:SetPoint("TOPLEFT", INSET, -INSET)
    model:SetPoint("BOTTOMRIGHT", -INSET, INSET)
    -- Hidden between hovers rather than thrown away, so the client is not asked
    -- to load the same thing again for every item passed over.
    model:SetKeepModelOnHide(true)
    model:Hide()
    return model
end

local function build()
    panel = CreateFrame("Frame", "LuckysWardrobeTooltipModel", UIParent, "TooltipBorderedFrameTemplate")
    panel:SetSize(WIDTH, HEIGHT)
    panel:SetFrameStrata("TOOLTIP")
    panel:SetClampedToScreen(true)
    panel:Hide()

    -- A model draws nothing where there is nothing to draw, and the frame's own
    -- border is drawn around an empty middle, so without this the world carries
    -- on behind the piece and there is nothing to read it against.
    local backdrop = panel:CreateTexture(nil, "BACKGROUND")
    backdrop:SetAllPoints()
    backdrop:SetColorTexture(0.04, 0.03, 0.02, 0.95)

    alone = createModel()
    figure = createModel()

    -- A model takes a moment to arrive, and anything put on one still on its way
    -- is dropped, camera included. What it should be showing is asked for again
    -- once it lands, or the first hover of a session shows an empty frame.
    figure:SetScript("OnModelLoaded", function()
        showing = nil
        if shownFor and shownLook and not shownLook.alone then show(shownLook) end
    end)
    alone:SetScript("OnModelLoaded", function(self)
        if self.look then frameOn(self, self.look) end
    end)

    -- A tooltip follows the cursor, and its comparisons open and close as shift
    -- is held, so which side has the room for a preview is worked out again as
    -- it moves rather than once when the item was first hovered.
    panel:SetScript("OnUpdate", function()
        if shownFor then reanchor() end
    end)
end

-- The figure armour hangs on is set up once and kept. It is only set up again
-- when the client says the character's model changed, which is a shapeshift, a
-- barber visit or a fresh login, and none of those can be answered before the
-- client says the model is there to read.
local function showFigure()
    if figureReady then return true end
    if not IsUnitModelReadyForUI("player") then return false end

    figure:SetUnit("player")
    -- The transmogrifier's own bare figure, so a piece is judged on its own
    -- rather than through whatever your character happens to be wearing.
    figure:SetUseTransmogSkin(true)
    figureReady = true
    showing = nil
    return true
end

local function hide()
    shownFor = nil
    if panel then panel:Hide() end
end

local function showFor(tooltip, look)
    if not panel then build() end
    -- A model of its own needs no character behind it, so it is shown whatever
    -- the client can say about the player's own model.
    if not look.alone and not showFigure() then return hide() end

    shownLook = look
    show(look)
    shownFor = tooltip
    reanchor()
    panel:Show()
end

-- The tooltips someone reads an item on: the one that follows the cursor, the
-- one embedded in a quest's rewards, and the one a link in chat opens.
local previewedOn = {}

local function forget(tooltip)
    if shownFor == tooltip then hide() end
end

local function onItemTooltip(tooltip, data)
    if not previewedOn[tooltip] then return end

    -- The link carries the bonus IDs that say which version of a piece this is,
    -- so a raid item is previewed in its own difficulty's appearance.
    local _, itemLink = TooltipUtil.GetDisplayedItem(tooltip)
    local look = TooltipModel:Preview(itemLink or (data and data.id))
    if look then
        showFor(tooltip, look)
    else
        forget(tooltip)
    end
end

--- Takes the preview off the screen the moment it is turned off, rather than
--- leaving the one already up until the next thing is hovered.
function TooltipModel:Refresh()
    if not db.tooltipModel then hide() end
end

local function slotName(slot)
    return (slot:gsub("^INVTYPE_", ""):lower())
end

--- How every slot is framed, in the order the command takes the numbers, so a
--- set arrived at in game can be read back out. What the client said about the
--- last piece hovered comes with it: a preview that looks wrong is one of these
--- answers being missing, and the camera is the one that goes missing.
function TooltipModel:PrintFraming()
    local S = LuckysWardrobe.Strings.tooltipModel
    local say = LuckysWardrobe.Utils.Say

    if not lastLook then
        say(S.nothingHovered)
    else
        say(S.lastPiece:format(lastLook.itemID, slotName(lastLook.equipSlot),
            tostring(lastLook.appearanceID), tostring(lastLook.sourceID),
            tostring(lastLook.cameraID)))
        -- A camera the client will not describe frames nothing, and looks exactly
        -- like no camera at all from the outside.
        if lastLook.cameraID then
            local position = GetUICameraInfo(lastLook.cameraID)
            say(position and S.cameraReads or S.cameraSilent)
        else
            say(S.cameraMissing)
        end
        if lastLook.alone then
            say(S.aloneModel:format(tostring(alone and alone:GetModelFileID())))
        end
    end

    say(S.framingHeader)
    local named = {}
    for slot in pairs(FRAMING) do named[#named + 1] = slot end
    table.sort(named)
    for _, slot in ipairs(named) do
        local framing = FRAMING[slot]
        say(S.framingLine:format(slotName(slot),
            framing.facing, framing.zoom, framing.height, framing.side))
    end
    say(S.framingUsage)
end

--- Frames one slot by hand, for arriving at the numbers baked in above without
--- a reload between each try. Hover a piece in that slot to see it.
function TooltipModel:SetFraming(name, facing, zoom, height, side)
    local S = LuckysWardrobe.Strings.tooltipModel
    local say = LuckysWardrobe.Utils.Say

    local slot = SLOT_ALIASES[name:lower()] or ("INVTYPE_" .. name:upper())
    local framing = FRAMING[slot] or { facing = 0, zoom = 1, height = 0, side = 0 }
    framing.facing = facing or framing.facing
    framing.zoom = zoom or framing.zoom
    framing.height = height or framing.height
    framing.side = side or framing.side
    FRAMING[slot] = framing

    -- The models keep what they were last told to show, so the piece has to be
    -- counted as unshown or hovering it again would change nothing.
    showing = nil
    say(S.framingSet:format(slotName(slot),
        framing.facing, framing.zoom, framing.height, framing.side))
end

function TooltipModel:Init(database)
    db = database

    local events = CreateFrame("Frame")
    events:RegisterUnitEvent("UNIT_MODEL_CHANGED", "player")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:SetScript("OnEvent", function()
        -- A figure that has changed is wearing nothing this addon put on it.
        figureReady = false
        showing = nil
        hide()
    end)

    for _, tooltip in ipairs({ GameTooltip, GameTooltip.ItemTooltip.Tooltip, ItemRefTooltip }) do
        previewedOn[tooltip] = true
        -- A tooltip is cleared before it is filled with whatever is hovered
        -- next, and hidden when nothing is hovered at all. Either way what it
        -- was showing is gone, and a preview left beside it belongs to nothing.
        tooltip:HookScript("OnTooltipCleared", forget)
        tooltip:HookScript("OnHide", forget)
    end

    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, onItemTooltip)
end
