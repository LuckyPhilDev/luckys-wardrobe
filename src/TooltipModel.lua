-- luacheck: globals C_Item C_PlayerInfo C_Timer C_TransmogCollection CreateFrame Enum GameTooltip GetScreenWidth GetUICameraInfo IsUnitModelReadyForUI ItemRefTooltip Model_ApplyUICamera TooltipDataProcessor TooltipUtil UIParent UnitRace UnitSex

-- Lucky's Wardrobe: What a piece actually looks like, shown beside its tooltip.
-- An icon says almost nothing about the appearance an item carries, and the only
-- way to see the piece itself was to open the dressing room and put it on. The
-- preview shows the piece the way the wardrobe shows an appearance: the item
-- alone, close up, with nothing else on and nothing else in frame.
--
-- The framing is one camera per slot rather than one per appearance, placed
-- against the bare figure before the piece goes on. See SLOT_CATEGORIES for the
-- first and show for the second.
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

-- Which slot a piece is framed as. A robe is a chest piece as far as a camera
-- is concerned, and the slot is what the framing is chosen by, not the item.
local SLOT_OF = {
    INVTYPE_HEAD = "HEADSLOT",
    INVTYPE_SHOULDER = "SHOULDERSLOT",
    INVTYPE_CLOAK = "BACKSLOT",
    INVTYPE_CHEST = "CHESTSLOT",
    INVTYPE_ROBE = "CHESTSLOT",
    INVTYPE_BODY = "SHIRTSLOT",
    INVTYPE_TABARD = "TABARDSLOT",
    INVTYPE_WRIST = "WRISTSLOT",
    INVTYPE_HAND = "HANDSSLOT",
    INVTYPE_WAIST = "WAISTSLOT",
    INVTYPE_LEGS = "LEGSSLOT",
    INVTYPE_FEET = "FEETSLOT",
}

-- Which of the game's own appearance categories a slot's pieces are listed in.
--
-- The game carries a camera for every appearance, and asking for the hovered
-- piece's own is the obvious thing to do, but those cameras are authored for the
-- wardrobe's grid and most pieces have none at all. What comes back is a
-- different shot for every helm, and no shot whatsoever for a great many of
-- them. Taking one camera from the slot's category and framing everything in the
-- slot by it gives the ankle for boots, the back of the figure for a cloak, the
-- head filling the frame for a helm, and the same shot for every piece that
-- goes there.
--
-- The one thing this cannot answer for is which of two shapes a worgen or a
-- dracthyr is currently in. See FORM_CAMERAS.
local SLOT_CATEGORIES = {
    HEADSLOT = Enum.TransmogCollectionType.Head,
    SHOULDERSLOT = Enum.TransmogCollectionType.Shoulder,
    BACKSLOT = Enum.TransmogCollectionType.Back,
    CHESTSLOT = Enum.TransmogCollectionType.Chest,
    SHIRTSLOT = Enum.TransmogCollectionType.Shirt,
    TABARDSLOT = Enum.TransmogCollectionType.Tabard,
    WRISTSLOT = Enum.TransmogCollectionType.Wrist,
    HANDSSLOT = Enum.TransmogCollectionType.Hands,
    WAISTSLOT = Enum.TransmogCollectionType.Waist,
    LEGSSLOT = Enum.TransmogCollectionType.Legs,
    FEETSLOT = Enum.TransmogCollectionType.Feet,
}

-- What frames the things that are models in their own right. There is no figure
-- to hang these on and no slot to borrow a camera from, so the camera comes from
-- what kind of thing it is: a dagger is shot from closer in than a polearm, and
-- a bow lies across the frame rather than down it.
--
-- These are the client's own Transmog-Weapon-<Kind> cameras, of which there are
-- seventeen and no more. A kind the game keeps no camera for is left out rather
-- than pointed at whichever camera is nearest in the list, since a shot through
-- the wrong one is worse than the model's own.
local FIST_WEAPON = 248

local WEAPON_CAMERAS = {
    [Enum.ItemClass.Weapon] = {
        [Enum.ItemWeaponSubclass.Axe1H] = 242,
        [Enum.ItemWeaponSubclass.Axe2H] = 243,
        [Enum.ItemWeaponSubclass.Bows] = 251,
        [Enum.ItemWeaponSubclass.Guns] = 252,
        [Enum.ItemWeaponSubclass.Mace1H] = 244,
        [Enum.ItemWeaponSubclass.Mace2H] = 245,
        [Enum.ItemWeaponSubclass.Polearm] = 247,
        [Enum.ItemWeaponSubclass.Sword1H] = 238,
        [Enum.ItemWeaponSubclass.Sword2H] = 239,
        [Enum.ItemWeaponSubclass.Warglaive] = 624,
        [Enum.ItemWeaponSubclass.Staff] = 246,
        [Enum.ItemWeaponSubclass.Dagger] = 241,
        [Enum.ItemWeaponSubclass.Crossbow] = 253,
        [Enum.ItemWeaponSubclass.Wand] = 240,
        -- What the game files fist weapons under, along with the two claws a
        -- druid's artifact came as, which are fists in all but name.
        [Enum.ItemWeaponSubclass.Unarmed] = FIST_WEAPON,
        [Enum.ItemWeaponSubclass.Bearclaw] = FIST_WEAPON,
        [Enum.ItemWeaponSubclass.Catclaw] = FIST_WEAPON,
        -- No transmog camera was ever made for a fishing pole. The one the
        -- fishing artifact is shown on is built for the shape and will do.
        [Enum.ItemWeaponSubclass.Fishingpole] = 818,
    },
    [Enum.ItemClass.Armor] = {
        [Enum.ItemArmorSubclass.Generic] = 250,
        [Enum.ItemArmorSubclass.Shield] = 249,
    },
}

-- The camera for each slot on the two races that can be a second shape.
--
-- The game keeps one of these per race, gender and slot, and the slot camera
-- above is the one it hands out for whoever you happen to be. What it has no
-- way to account for is which of two shapes you are in: a worgen walking around
-- as a human, and a dracthyr in their visage, are both still framed as the beast
-- the game knows them as, and the shot lands well above their heads.
--
-- Read out of the client's own UiCamera table, whose rows are named
-- Transmog-<Race>-<Gender>-<Slot>, so every number here can be checked against
-- the name it came from. Chest takes the Robe camera, which is the one the game
-- actually keeps for that slot.
local WORGEN = {
    Male = {
        HEADSLOT = 309, SHOULDERSLOT = 310, BACKSLOT = 311, CHESTSLOT = 312,
        SHIRTSLOT = 313, TABARDSLOT = 314, WRISTSLOT = 315, HANDSSLOT = 316,
        WAISTSLOT = 317, LEGSSLOT = 318, FEETSLOT = 319,
    },
    Female = {
        HEADSLOT = 320, SHOULDERSLOT = 321, BACKSLOT = 322, CHESTSLOT = 323,
        SHIRTSLOT = 324, TABARDSLOT = 325, WRISTSLOT = 326, HANDSSLOT = 327,
        WAISTSLOT = 328, LEGSSLOT = 329, FEETSLOT = 330,
    },
}

-- The human, who is what a worgen out of her worgen shape is, and what the game
-- draws a dracthyr's female visage as.
local HUMAN = {
    Male = {
        HEADSLOT = 236, SHOULDERSLOT = 221, BACKSLOT = 235, CHESTSLOT = 225,
        SHIRTSLOT = 229, TABARDSLOT = 230, WRISTSLOT = 237, HANDSSLOT = 226,
        WAISTSLOT = 234, LEGSSLOT = 228, FEETSLOT = 227,
    },
    Female = {
        HEADSLOT = 274, SHOULDERSLOT = 275, BACKSLOT = 276, CHESTSLOT = 277,
        SHIRTSLOT = 278, TABARDSLOT = 279, WRISTSLOT = 280, HANDSSLOT = 281,
        WAISTSLOT = 282, LEGSSLOT = 283, FEETSLOT = 284,
    },
}

-- One drake, which is what the game keeps whichever gender it was made as.
local DRAKE = {
    HEADSLOT = 1702, SHOULDERSLOT = 1704, BACKSLOT = 1706, CHESTSLOT = 1698,
    SHIRTSLOT = 1709, TABARDSLOT = 1707, WRISTSLOT = 1711, HANDSSLOT = 1708,
    WAISTSLOT = 1700, LEGSSLOT = 1701, FEETSLOT = 1705,
}

-- A visage is not a shape of its own, it is a model the game already had. The
-- male is a blood elf male, and takes his cameras but for the head, the back and
-- the tabard, which are the three the game keeps a visage camera for and the
-- three a pair of horns would spoil. The female is the human female outright,
-- which is why the game keeps no visage camera for her at all.
local DRACTHYR_VISAGE = {
    Male = {
        HEADSLOT = 1713, SHOULDERSLOT = 455, BACKSLOT = 1714, CHESTSLOT = 457,
        SHIRTSLOT = 458, TABARDSLOT = 1715, WRISTSLOT = 460, HANDSSLOT = 461,
        WAISTSLOT = 462, LEGSSLOT = 463, FEETSLOT = 464,
    },
    Female = HUMAN.Female,
}

local FORM_CAMERAS = {
    Worgen = WORGEN,
    WorgenHuman = HUMAN,
    Dracthyr = { Male = DRAKE, Female = DRAKE },
    DracthyrVisage = DRACTHYR_VISAGE,
}

-- The shape those two are in when they are not in their own. Nobody else has a
-- second one to be in.
local OTHER_FORM = { Worgen = "WorgenHuman", Dracthyr = "DracthyrVisage" }

local GENDERS = { [2] = "Male", [3] = "Female" }

-- What each slot is nudged by after the game has framed it.
--
-- Applying the slot's camera is the whole of the framing. The numbers here sit
-- on top of it, for the slots the game's own answer does not suit. Every slot is
-- at nothing for now, which is the game's framing untouched. They are listed
-- rather than absent so /wardrobe preview names the slots to work through.
--
-- Facing is a fraction of a full turn. Zoom is how far the camera sits back, so
-- under 1 is closer and over 1 is further. Height lifts the figure, bringing what
-- is below it into the middle of the shot, and side slides it across.
local FRAMING = {
    INVTYPE_FEET = { facing = 0, zoom = 1, height = 0, side = 0 },
    INVTYPE_CLOAK = { facing = 0, zoom = 1, height = 0, side = 0 },
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

--- Whether the figure is drawn as the race's own form rather than the other one
--- it can take. What the camera is chosen by has to be what the figure is drawn
--- as, or a worgen is shot through a human's framing.
local function inOwnForm()
    local _, inOtherForm = C_PlayerInfo.GetAlternateFormInfo()
    return not inOtherForm
end

-- A camera the client will not describe frames nothing, and looks exactly like a
-- working one from the outside, so it is passed over rather than applied.
local function described(cameraID)
    if cameraID and GetUICameraInfo(cameraID) then return cameraID end
    return nil
end

-- The camera for the shape the figure is actually drawn as, for the two races
-- that have more than one.
local function formCamera(slot)
    local _, race = UnitRace("player")
    if not inOwnForm() then race = OTHER_FORM[race] end
    local byGender = race and FORM_CAMERAS[race]
    local cameras = byGender and byGender[GENDERS[UnitSex("player")]]
    return cameras and cameras[slot]
end

-- A slot's camera, asked for once and kept. A miss is not kept: the category
-- list is not there until the client has the collection, so a slot left
-- unanswered is worth asking about again rather than framing every piece in it
-- from nowhere for the rest of the session.
local slotCameras = {}

-- Whichever appearance in the slot's category the client will describe a camera
-- for. Any of them will do, and that is the point: one camera for the slot is
-- what makes every piece that goes there come out the same way.
local function slotCamera(slot)
    if slotCameras[slot] then return slotCameras[slot] end

    local listed = C_TransmogCollection.GetCategoryAppearances(SLOT_CATEGORIES[slot]) or {}
    for _, appearance in ipairs(listed) do
        -- The entry standing for wearing nothing in the slot is not a piece and
        -- is not what the slot should be framed by.
        if not appearance.isHideVisual then
            local cameraID = described(C_TransmogCollection.GetAppearanceCameraID(appearance.visualID))
            if cameraID then
                slotCameras[slot] = cameraID
                return cameraID
            end
        end
    end
end

--- Which camera frames a piece, and where that camera came from.
-- Something carried is framed by what kind of thing it is, and something worn by
-- the slot it goes in, on whichever shape the figure is drawn as.
local function cameraFor(equipSlot, classID, subclassID)
    if ALONE[equipSlot] then
        local byClass = WEAPON_CAMERAS[classID]
        local carried = described(byClass and byClass[subclassID])
        if carried then return carried, "carried" end
        -- A kind the game keeps no camera for is shown on the model's own,
        -- which the report should say rather than claiming a camera it has not.
        return nil, nil
    end

    local slot = SLOT_OF[equipSlot]
    if not slot then return nil, nil end

    local byForm = described(formCamera(slot))
    if byForm then return byForm, "form" end
    return slotCamera(slot), "slot"
end

--- What the preview should show for a hovered item, or nil for an item there is
--- nothing to show.
-- Handed back rather than drawn, so what an item would put in the frame can be
-- read without a tooltip to hang it beside. Most of what passes through a bag is
-- nothing anybody could wear.
function TooltipModel:Preview(itemInfo)
    if itemInfo == nil or not db.tooltipModel then return nil end

    local itemID, _, _, equipSlot, _, classID, subclassID = C_Item.GetItemInfoInstant(itemInfo)
    if not itemID or not C_Item.IsDressableItemByID(itemID) then return nil end

    -- The appearance is what the wardrobe knows a piece by, and what a weapon is
    -- put in the frame as. An item with no appearance at all can still be worn.
    local appearanceID, sourceID = C_TransmogCollection.GetItemInfo(itemInfo)
    local cameraID, cameraFrom = cameraFor(equipSlot, classID, subclassID)
    local look = {
        item = itemInfo,
        itemID = itemID,
        appearanceID = appearanceID,
        sourceID = sourceID,
        equipSlot = equipSlot,
        alone = ALONE[equipSlot] or false,
        cameraID = cameraID,
        -- Where the camera came from, so the report can say what a preview that
        -- comes out wrong was framed by.
        cameraFrom = cameraFrom,
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
local figureReady, figureLoading = false, false
-- Which dressing of the figure is the current one. A piece goes on a frame after
-- the camera is placed, so a second piece hovered inside that frame would
-- otherwise land on the model after the first and be the one left showing.
local dressing = 0
local anchor = {}

local TURN = math.pi * 2

-- The camera frames the slot the piece sits in, and the slot's own framing takes
-- it the rest of the way. The model keeps the look it was framed for, since a
-- model that is the piece itself has to be framed again once its geometry lands.
local function frameOn(model, look)
    model.look = look
    -- Back to where a model opens before either of them is applied. A camera
    -- takes the model over entirely: it turns and tilts the model as well as
    -- moving the camera itself, so a piece the client has no camera for would
    -- otherwise be shot through the last piece's, at the last piece's tilt, and
    -- come out at a different angle depending on what was hovered before it.
    model:RefreshCamera()
    model:SetFacing(0)
    model:SetPitch(0)
    model:SetRoll(0)
    model:SetPosition(0, 0, 0)
    model:SetCamDistanceScale(1)

    if look.cameraID then
        Model_ApplyUICamera(model, look.cameraID)
    elseif model:HasCustomCamera() then
        -- Turning the model back is not enough on its own, the camera the last
        -- piece left is still pointed where that piece was. Nothing puts a model
        -- back on its own camera but asking for it by number.
        model:SetCamera(0)
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
    alone:SetShown(look.alone)
    figure:SetShown(not look.alone)
    if showing == look.item and showingAlone == look.alone then return end
    showing, showingAlone = look.item, look.alone

    if look.alone then
        if look.appearanceID then
            alone:SetItemAppearance(look.appearanceID)
        else
            alone:SetItem(look.itemID)
        end
        frameOn(alone, look)
        return
    end

    -- Stripped rather than dressed: the piece is the whole of what the preview
    -- is for, and a tabard or a robe over it answers nothing.
    figure:Undress()
    -- Framed bare, before the piece goes on. A camera is placed against the
    -- model as it stands, not against the world: the numbers the client hands
    -- out are turned into a camera position by pushing two points through the
    -- model's own transform, and that transform follows the geometry loaded. A
    -- bare figure is the same shape for every piece, so shooting it before the
    -- piece arrives is what makes one slot's camera frame every piece in it the
    -- same way. Framing after would take the shot through whichever piece
    -- happened to have finished loading.
    frameOn(figure, look)
    -- Which leaves the piece to go on afterwards, a frame later, so nothing put
    -- on the model can move the camera that was just placed.
    dressing = dressing + 1
    local thisDressing = dressing
    C_Timer.After(0, function()
        -- Not if something else has been hovered in the meantime, and not if the
        -- figure itself has been taken away and set up again underneath it.
        if thisDressing ~= dressing or showing ~= look.item then return end
        figure:TryOn(look.item)
    end)
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

    -- The figure takes a moment to arrive, and anything put on one still on its
    -- way is dropped, camera included. What it should be showing is asked for
    -- again once it lands, or the first hover of a session shows an empty frame.
    -- The loads that come of dressing it are left alone: the camera is placed
    -- before a piece goes on, and putting it back afterwards would be the very
    -- thing that moves it.
    figure:SetScript("OnModelLoaded", function()
        if not figureLoading then return end
        figureLoading = false
        showing = nil
        if shownFor and shownLook and not shownLook.alone then show(shownLook) end
    end)
    -- Something shown on its own is the model the camera is placed against, so
    -- that one does have to be placed again once its geometry is there.
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

    -- Whichever of the two forms your character is in, since that is what a
    -- worgen or a dracthyr is looking at everywhere else in the game.
    figure:SetUnit("player", false, inOwnForm())
    -- The transmogrifier's own bare figure, so a piece is judged on its own
    -- rather than through whatever your character happens to be wearing.
    figure:SetUseTransmogSkin(true)
    figureReady = true
    figureLoading = true
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

-- Whether the piece is one you already have on you. A tooltip is filled through
-- a call named after where its item was read from, which is the only thing that
-- tells a chestpiece sat in your bags from the same chestpiece dropping off a
-- boss. Bank tabs are read as bags, being containers like any other.
local function alreadyOwned(tooltip)
    local info = tooltip:GetProcessingTooltipInfo()
    local getter = info and info.getterName
    if getter == "GetBagItem" then return true end
    -- Inspecting somebody reads their gear through the same call the character
    -- sheet does, and theirs is exactly what a preview is for.
    return getter == "GetInventoryItem" and info.getterArgs and info.getterArgs[1] == "player"
end

local function onItemTooltip(tooltip, data)
    if not previewedOn[tooltip] then return end
    -- A frame can wave the preview off the tooltips it owns by carrying this
    -- flag. The loot browser in Lucky's Loot Wishlist sets it, behind a
    -- setting of its own, for lists a model would keep opening beside.
    local owner = tooltip.GetOwner and tooltip:GetOwner()
    if owner and owner.luckysWardrobeNoPreview then return forget(tooltip) end
    -- What you are wearing and what you are carrying is a look you can already
    -- see, so it is passed over until it is asked for.
    if not db.tooltipModelWornAndBags and alreadyOwned(tooltip) then return forget(tooltip) end

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
        -- Where that camera came from, since a preview that comes out as the
        -- whole figure was framed by the wrong one of the three or by none.
        say(S.cameraSources[lastLook.cameraFrom] or S.cameraUnframed)
        say(lastLook.cameraID and S.cameraReads or S.cameraMissing)
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
