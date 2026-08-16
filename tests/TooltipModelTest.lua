-- luacheck: globals C_Item C_PlayerInfo C_Timer C_TransmogCollection CreateFrame Enum GameTooltip GetScreenWidth IsUnitModelReadyForUI ItemRefTooltip LuckysWardrobe Model_ApplyUICamera TooltipDataProcessor TooltipUtil UIParent UnitRace UnitSex

-- Covers the preview shown beside an item's tooltip: what goes in the frame for
-- a piece the game holds a model of, what goes in it for the armour it only has
-- as a skin on a character, what each of those is framed by, which tooltips get
-- a preview at all, which side of the tooltip it opens on, and everything that
-- takes it away again.

LuckysWardrobe = {}

_G.Enum = {
    TooltipDataType = { Item = 10 },
    ItemClass = { Weapon = 2, Armor = 4 },
    ItemWeaponSubclass = {
        Axe1H = 0, Axe2H = 1, Bows = 2, Guns = 3, Mace1H = 4, Mace2H = 5,
        Polearm = 6, Sword1H = 7, Sword2H = 8, Warglaive = 9, Staff = 10,
        Bearclaw = 11, Catclaw = 12, Unarmed = 13, Generic = 14, Dagger = 15,
        Thrown = 16, Crossbow = 18, Wand = 19, Fishingpole = 20,
    },
    ItemArmorSubclass = { Generic = 0, Shield = 6, Plate = 4 },
    TransmogCollectionType = {
        Head = 0, Shoulder = 1, Back = 2, Chest = 3, Shirt = 4, Tabard = 5,
        Wrist = 6, Hands = 7, Waist = 8, Legs = 9, Feet = 10,
    },
}
_G.UIParent = "UIParent"

-- A sword and a shield, which are models in their own right; a helm, a chest
-- piece and a pair of boots, which the game only has as a character wearing
-- them; and a potion nobody can dress in, which is most of what passes through
-- a bag.
local ITEMS = {
    ["|Hitem:100|h[Breastplate]|h"] = {
        id = 100, equipSlot = "INVTYPE_CHEST", dressable = true, appearanceID = 501, sourceID = 1,
    },
    ["|Hitem:200|h[Sword]|h"] = {
        id = 200, equipSlot = "INVTYPE_WEAPON", dressable = true, appearanceID = 502, sourceID = 2,
        classID = 2, subclassID = 7,
    },
    ["|Hitem:250|h[Shield]|h"] = {
        id = 250, equipSlot = "INVTYPE_SHIELD", dressable = true, appearanceID = 504, sourceID = 4,
        classID = 4, subclassID = 6,
    },
    -- A fist weapon, which the game files under Unarmed, and a thrown weapon,
    -- which is a kind the game keeps no transmog camera for at all.
    ["|Hitem:260|h[Knuckles]|h"] = {
        id = 260, equipSlot = "INVTYPE_WEAPON", dressable = true, appearanceID = 511, sourceID = 11,
        classID = 2, subclassID = 13,
    },
    ["|Hitem:270|h[Javelin]|h"] = {
        id = 270, equipSlot = "INVTYPE_WEAPON", dressable = true, appearanceID = 512, sourceID = 12,
        classID = 2, subclassID = 16,
    },
    ["|Hitem:300|h[Helm]|h"] = {
        id = 300, equipSlot = "INVTYPE_HEAD", dressable = true, appearanceID = 503, sourceID = 3,
    },
    ["|Hitem:500|h[Shirt]|h"] = { id = 500, equipSlot = "INVTYPE_BODY", dressable = true },
    ["|Hitem:600|h[Boots]|h"] = {
        id = 600, equipSlot = "INVTYPE_FEET", dressable = true, appearanceID = 506, sourceID = 6,
    },
    ["|Hitem:700|h[Cape]|h"] = {
        id = 700, equipSlot = "INVTYPE_CLOAK", dressable = true, appearanceID = 507, sourceID = 7,
    },
    -- A robe, which is a chest piece as far as a camera is concerned, and a
    -- girdle in a slot whose reference piece the client answers nothing for.
    ["|Hitem:750|h[Robe]|h"] = {
        id = 750, equipSlot = "INVTYPE_ROBE", dressable = true, appearanceID = 505, sourceID = 5,
    },
    ["|Hitem:850|h[Girdle]|h"] = {
        id = 850, equipSlot = "INVTYPE_WAIST", dressable = true, appearanceID = 509, sourceID = 9,
    },
    ["|Hitem:860|h[Trousers]|h"] = {
        id = 860, equipSlot = "INVTYPE_LEGS", dressable = true, appearanceID = 513, sourceID = 13,
    },
    ["|Hitem:875|h[Bracers]|h"] = {
        id = 875, equipSlot = "INVTYPE_WRIST", dressable = true, appearanceID = 510, sourceID = 10,
    },
    ["|Hitem:900|h[Potion]|h"] = { id = 900, equipSlot = "", dressable = false },
    [900] = { id = 900, equipSlot = "", dressable = false },
}

-- The appearances the client lists in each slot's own category, in the order it
-- lists them, each carrying a camera numbered after itself so a preview can be
-- traced back to the slot it was framed as.
--
-- Three of them are awkward on purpose. The head's category opens with the entry
-- standing for wearing nothing, which is not a piece and not what a helm should
-- be framed by. The wrist's first appearance carries a camera the client will
-- not describe, so the slot has to keep looking. The waist is listed as nothing
-- at all, which is a slot that cannot be framed.
local CATEGORY_APPEARANCES = {
    [0] = { 1600, 1601 },   -- head
    [1] = { 1603 },         -- shoulder
    [2] = { 1615 },         -- back
    [3] = { 1605 },         -- chest
    [4] = { 1604 },         -- shirt
    [5] = { 1619 },         -- tabard
    [6] = { 1609, 1709 },   -- wrist
    [7] = { 1610 },         -- hands
    [8] = {},               -- waist
    [9] = { 1607 },         -- legs
    [10] = { 1608 },        -- feet
}
local HIDE_VISUALS = { [1600] = true }

-- What the client actually holds a model file for, keyed by what it was asked
-- to show. The crown is missing from it on purpose.
local MODEL_FILES = { [502] = 9002, [503] = 9003 }

_G.C_Item = {
    GetItemInfoInstant = function(itemInfo)
        local entry = ITEMS[itemInfo]
        if not entry then return nil end
        return entry.id, "Armor", "Plate", entry.equipSlot, "icon",
            entry.classID or 4, entry.subclassID or 4
    end,
    IsDressableItemByID = function(itemID)
        for _, entry in pairs(ITEMS) do
            if entry.id == itemID then return entry.dressable end
        end
        return false
    end,
}

-- The camera the wardrobe frames an appearance with. Only what a slot's category
-- lists is asked about now, but the client still answers for anything with an
-- appearance, and a test that leans on the hovered piece's own should fail.
local APPEARANCE_CAMERAS = {
    [501] = 71, [502] = 72, [503] = 73, [504] = 74, [505] = 75, [506] = 76,
    [507] = 77, [509] = 79,
}
for _, listed in pairs(CATEGORY_APPEARANCES) do
    for _, visualID in ipairs(listed) do APPEARANCE_CAMERAS[visualID] = visualID end
end

_G.C_TransmogCollection = {
    GetItemInfo = function(itemInfo)
        local entry = ITEMS[itemInfo] or {}
        return entry.appearanceID, entry.sourceID
    end,
    GetAppearanceCameraID = function(appearanceID) return APPEARANCE_CAMERAS[appearanceID] end,
    GetCategoryAppearances = function(category)
        local listed = CATEGORY_APPEARANCES[category]
        if not listed then return nil end
        local appearances = {}
        for i, visualID in ipairs(listed) do
            appearances[i] = { visualID = visualID, isHideVisual = HIDE_VISUALS[visualID] or false }
        end
        return appearances
    end,
}

-- Who the character is and which of the two shapes she is in. A human woman in
-- her only shape unless a test says otherwise.
local inOtherForm, race, sex = false, "Human", 3
_G.C_PlayerInfo = {
    GetAlternateFormInfo = function() return true, inOtherForm end,
}
_G.UnitRace = function() return race, race end
_G.UnitSex = function() return sex end

-- A piece goes on the model a frame after the camera is placed, so the tests
-- have to be able to run out that frame.
local pending = {}
_G.C_Timer = {
    After = function(_, callback) pending[#pending + 1] = callback end,
}

local function nextFrame()
    local due = pending
    pending = {}
    for _, callback in ipairs(due) do callback() end
end

-- The real one puts the model where the camera says, which is what any framing
-- on top of it is measured from.
local appliedCameras = {}
_G.Model_ApplyUICamera = function(model, cameraID)
    appliedCameras[#appliedCameras + 1] = { model = model, cameraID = cameraID }
    model.customCamera = true
    model:SetFacing(0)
    model:SetPitch(0.4)
    model:SetPosition(0, 0, 0)
end

-- The client does not describe every camera it hands out, and one it will not
-- describe frames nothing. The wrist's is one of those.
local silentCameras = { [1609] = true }
_G.GetUICameraInfo = function(cameraID)
    if not cameraID or silentCameras[cameraID] then return nil end
    return 0
end

local screenWidth = 1000
_G.GetScreenWidth = function() return screenWidth end

local modelReady = true
_G.IsUnitModelReadyForUI = function() return modelReady end

-- One stub for every frame the module builds. The models record what they were
-- asked to show, since that is the whole of what a preview does.
local frames = {}

local function Frame()
    local frame = {
        points = {},
        events = {},
        scripts = {},
        shown = false,
        loads = 0,
        undresses = 0,
        refreshes = 0,
    }
    function frame:SetSize() end
    function frame:CreateTexture()
        self.backdrop = { SetAllPoints = function() end, SetColorTexture = function() end }
        return self.backdrop
    end
    function frame:SetFrameStrata() end
    function frame:SetClampedToScreen() end
    function frame:SetKeepModelOnHide() end
    function frame:SetUseTransmogSkin(use) self.transmogSkin = use end
    function frame:RefreshCamera() self.refreshes = self.refreshes + 1 end
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    function frame:SetShown(shown) self.shown = shown end
    function frame:IsShown() return self.shown end
    function frame:SetPoint(point, relativeTo, relativePoint)
        self.points[#self.points + 1] = { point, relativeTo, relativePoint }
    end
    function frame:ClearAllPoints() self.points = {} end
    function frame:SetScript(script, handler) self.scripts[script] = handler end
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:RegisterUnitEvent(event, unit) self.events[event] = unit end
    function frame:SetUnit(unit, _, nativeForm)
        self.unit = unit
        self.nativeForm = nativeForm
    end
    function frame:Undress() self.undresses = self.undresses + 1 end
    function frame:TryOn(item)
        self.loads = self.loads + 1
        self.showing = item
    end
    function frame:SetItemAppearance(appearanceID)
        self.loads = self.loads + 1
        self.showing = appearanceID
        self.modelFile = MODEL_FILES[appearanceID]
    end
    function frame:SetItem(itemID)
        self.loads = self.loads + 1
        self.showing = itemID
        self.modelFile = MODEL_FILES[itemID]
    end
    function frame:GetModelFileID() return self.modelFile end
    function frame:SetFacing(facing) self.facing = facing end
    function frame:GetFacing() return self.facing or 0 end
    function frame:SetPitch(pitch) self.pitch = pitch end
    function frame:SetRoll(roll) self.roll = roll end
    -- A camera stays on a model until something puts it back, which is the whole
    -- of why a piece with none of its own has to be given the model's own again.
    function frame:HasCustomCamera() return self.customCamera == true end
    function frame:SetCamera(index) self.customCamera, self.camera = false, index end
    function frame:SetCamDistanceScale(zoom) self.zoom = zoom end
    function frame:GetPosition() return 0, self.side or 0, self.height or 0 end
    function frame:SetPosition(_, y, z)
        self.side, self.height = y, z
    end
    frames[#frames + 1] = frame
    return frame
end

_G.CreateFrame = function(_, name)
    local frame = Frame()
    frame.name = name
    return frame
end

local postCalls = {}
_G.TooltipDataProcessor = {
    AddTooltipPostCall = function(dataType, handler)
        postCalls[#postCalls + 1] = { dataType = dataType, handler = handler }
    end,
}

-- Comparison tooltips hang off the tooltip they belong to, so a tooltip carries
-- the list of them and each answers where its own edges are.
local function Tooltip(left, right)
    local tooltip = { scripts = {}, shoppingTooltips = {}, shown = true }
    function tooltip:GetLeft() return left end
    function tooltip:GetRight() return right end
    function tooltip:IsShown() return self.shown end
    -- What the game says a tooltip was filled through, which is where its item
    -- was read from. Nothing sets it unless a test is about that.
    function tooltip:GetProcessingTooltipInfo() return self.info end
    function tooltip:HookScript(script, handler) self.scripts[script] = handler end
    function tooltip:Clear() self.scripts.OnTooltipCleared(self) end
    function tooltip:Hide() self.scripts.OnHide(self) end
    return tooltip
end

_G.GameTooltip = Tooltip(400, 600)
_G.GameTooltip.ItemTooltip = { Tooltip = Tooltip(400, 600) }
_G.ItemRefTooltip = Tooltip(400, 600)
local ShoppingTooltip = Tooltip(200, 400)

local displayedLink
_G.TooltipUtil = {
    GetDisplayedItem = function() return "Item", displayedLink end,
}

-- What the tuning command says back, which is the only way the framing numbers
-- can be read out of a running client.
local said = {}
dofile("src/Strings.lua")
LuckysWardrobe.Utils = { Say = function(line) said[#said + 1] = line end }

-- The Items tab replaces the client's own category call with a filtered one, so
-- the camera lookup reads through the tab's accessor to get past it.
LuckysWardrobe.TransmogItems = {
    CategoryAppearances = function(category)
        return C_TransmogCollection.GetCategoryAppearances(category)
    end,
}

dofile("src/TooltipModel.lua")

local TooltipModel = LuckysWardrobe.TooltipModel
local settings = { tooltipModel = true, tooltipModelWornAndBags = false }
TooltipModel:Init(settings)

assert(#postCalls == 1 and postCalls[1].dataType == Enum.TooltipDataType.Item,
    "the item tooltip was never hooked")
local onItemTooltip = postCalls[1].handler
local eventFrame = frames[1]
assert(eventFrame.events.UNIT_MODEL_CHANGED == "player", "the player's model was never watched")
assert(eventFrame.events.PLAYER_ENTERING_WORLD, "logging in was never watched")

-- What an item puts in the frame, read without a tooltip to hang it beside.
-- Nothing anybody could dress in is nothing to show.
assert(TooltipModel:Preview(nil) == nil, "a tooltip with no item at all was answered")
assert(TooltipModel:Preview("|Hitem:900|h[Potion]|h") == nil, "a potion was previewed")

-- What is carried is a model in its own right, and is framed by what kind of
-- thing it is rather than by any slot: a one-handed sword, and a shield, which
-- the game files as armour but which nobody wears.
local sword = TooltipModel:Preview("|Hitem:200|h[Sword]|h")
assert(sword.alone, "a sword was hung on a character")
assert(sword.appearanceID == 502, "the sword's appearance was not read")
assert(sword.cameraID == 238 and sword.cameraFrom == "carried",
    "a sword was not framed as a one-handed sword")
assert(TooltipModel:Preview("|Hitem:250|h[Shield]|h").cameraID == 249,
    "a shield was not framed as a shield")

-- A fist weapon is filed under Unarmed, which is a kind apart from the crossbow
-- it sits next to in the list. The table this was checked against had the two
-- confused, and every fist weapon was shot through a crossbow's framing.
assert(TooltipModel:Preview("|Hitem:260|h[Knuckles]|h").cameraID == 248,
    "a fist weapon was not framed as one")

-- A kind the game keeps no camera for is shown on the model's own rather than
-- through whichever camera happens to be nearest.
local javelin = TooltipModel:Preview("|Hitem:270|h[Javelin]|h")
assert(javelin.cameraID == nil and javelin.cameraFrom == nil,
    "a weapon the game frames nothing for was given someone else's camera")

-- Armour is not, whatever slot it is in. Asking the client for a helm on its own
-- draws nothing at all, so a helm goes on the figure with the rest of a suit.
assert(TooltipModel:Preview("|Hitem:300|h[Helm]|h").alone == false,
    "the client was asked for a helm on its own")

-- The game has no chestpiece to show, only somebody wearing one, so that is what
-- it takes to show one. It is framed by the camera the game frames this slot's
-- reference piece with, not by anything the chestpiece itself carries: the piece
-- has an appearance camera of its own here, and taking it would be the bug.
local breastplate = TooltipModel:Preview("|Hitem:100|h[Breastplate]|h")
assert(breastplate.item == "|Hitem:100|h[Breastplate]|h", "the link is what gets tried on")
assert(breastplate.alone == false, "the game was asked for a chestpiece it does not have")
assert(breastplate.cameraID == 1605 and breastplate.cameraFrom == "slot",
    "a chestpiece was framed by its own camera rather than the chest slot's")

-- Which makes every piece in a slot come out the same way, whatever the client
-- happens to hold for the piece itself. A robe is a chest piece for this.
assert(TooltipModel:Preview("|Hitem:750|h[Robe]|h").cameraID == 1605,
    "a robe was framed as something other than a chest piece")
assert(TooltipModel:Preview("|Hitem:600|h[Boots]|h").cameraID == 1608,
    "a boot was not framed by the feet slot's camera")
assert(TooltipModel:Preview("|Hitem:700|h[Cape]|h").cameraID == 1615,
    "a cloak was not framed by the back slot's camera")

-- An item the client knows no appearance for can still be worn, and is still
-- framed: the framing belongs to the slot, not to the piece.
assert(TooltipModel:Preview("|Hitem:500|h[Shirt]|h").cameraID == 1604,
    "a piece with no appearance of its own went unframed")

-- The entry standing for wearing nothing in a slot is not a piece, so a helm is
-- framed by the appearance after it rather than by that.
assert(TooltipModel:Preview("|Hitem:300|h[Helm]|h").cameraID == 1601,
    "a helm was framed by the entry for wearing no helm at all")

-- A camera the client will not describe frames nothing, so the slot keeps
-- looking down its own category rather than settling for it.
assert(TooltipModel:Preview("|Hitem:875|h[Bracers]|h").cameraID == 1709,
    "a camera the client will not describe passed for one that works")

-- A slot the client lists nothing for leaves the piece shown from wherever the
-- model opens rather than framed from nowhere.
assert(TooltipModel:Preview("|Hitem:850|h[Girdle]|h").cameraID == nil,
    "a camera was invented for a slot the client listed nothing for")

-- Turning it off leaves the tooltip as the game drew it.
settings.tooltipModel = false
assert(TooltipModel:Preview("|Hitem:100|h[Breastplate]|h") == nil, "the preview survived being turned off")
settings.tooltipModel = true

-- Hovering a weapon builds the preview and puts the weapon in it on its own,
-- framed by the wardrobe's own camera, with no character anywhere near it.
displayedLink = "|Hitem:200|h[Sword]|h"
onItemTooltip(GameTooltip)

local panel, alone, figure = frames[2], frames[3], frames[4]
assert(panel.name == "LuckysWardrobeTooltipModel", "the preview frame was never built")
assert(panel.shown, "the preview stayed hidden on an item that has a look")
assert(alone.showing == 502, "the sword was never shown")
assert(alone.shown and not figure.shown, "a character was left standing behind the sword")
assert(appliedCameras[#appliedCameras].cameraID == 238, "the sword was never framed")
assert(figure.unit == nil, "a weapon waited on a character it does not need")

-- The preview opens on whichever side of the tooltip has the room. The tooltip
-- sits left of centre here, so it opens to the right.
assert(panel.points[1][1] == "TOPLEFT" and panel.points[1][3] == "TOPRIGHT",
    "the preview opened on the cramped side")
assert(panel.points[1][2] == GameTooltip, "the preview hung off something else")

-- The same item hovered again costs nothing: the auction house closes and
-- reopens its tooltip on every refresh, and reloading each time would flicker.
local loadsBefore = alone.loads
GameTooltip:Clear()
assert(not panel.shown, "a cleared tooltip kept its preview")
onItemTooltip(GameTooltip)
assert(panel.shown, "the preview did not come back with the tooltip")
assert(alone.loads == loadsBefore, "the same item was loaded again")

-- A chestpiece has to go on the bare figure the transmogrifier previews on,
-- stripped of everything else, framed as close as the camera goes.
displayedLink = "|Hitem:100|h[Breastplate]|h"
onItemTooltip(GameTooltip)
assert(figure.unit == "player" and figure.transmogSkin,
    "armour should hang on the transmogrifier's own bare figure")
assert(figure.undresses == 1, "the figure kept its gear on over the piece")
assert(figure.shown and not alone.shown, "the wrong model was left in the frame")
assert(appliedCameras[#appliedCameras].cameraID == 1605, "the slot was never framed")

-- And the camera goes on before the piece does. A camera is placed against the
-- model as it stands, so the shot has to be taken on the bare figure, which is
-- the same shape every time, rather than through whichever piece last finished
-- loading. Nothing is on the figure yet at this point.
assert(figure.showing ~= displayedLink, "the piece went on before the camera was placed")
nextFrame()
assert(figure.showing == displayedLink, "the piece never went on after the camera")

-- Nothing is framed by hand for now, so a piece is left exactly where its slot's
-- camera puts it. A boot is the slot that most obviously needs one, sitting at
-- the bottom of a figure the whole of which will not do.
displayedLink = "|Hitem:600|h[Boots]|h"
onItemTooltip(GameTooltip)
nextFrame()
assert(appliedCameras[#appliedCameras].cameraID == 1608, "a boot was not framed by the feet camera")
assert(figure.facing == 0 and figure.zoom == 1 and figure.height == 0 and figure.side == 0,
    "a boot was moved off where the game framed it")

-- A cloak the same, rather than the figure being turned around by hand: the
-- camera the game hands out for a cloak is already looking at the back of one.
displayedLink = "|Hitem:700|h[Cape]|h"
onItemTooltip(GameTooltip)
nextFrame()
assert(appliedCameras[#appliedCameras].cameraID == 1615, "a cloak was not framed by the back camera")
assert(figure.facing == 0, "a cloak was turned off where the game framed it")

-- A camera stays on a model until something puts it back, and it turns and tilts
-- the model as well as moving the camera. A piece in a slot the client describes
-- no camera for is given the model's own again, or it comes out at the angle of
-- whatever was hovered before it.
displayedLink = "|Hitem:600|h[Boots]|h"
onItemTooltip(GameTooltip)
nextFrame()
assert(figure.customCamera and figure.pitch == 0.4, "a boot was never framed by a camera at all")

displayedLink = "|Hitem:850|h[Girdle]|h"
onItemTooltip(GameTooltip)
nextFrame()
assert(not figure.customCamera, "a piece with no camera was left on the last piece's")
assert(figure.pitch == 0 and figure.roll == 0, "a piece with no camera kept the last piece's tilt")

-- A worgen is not the shape a slot camera was built for, so she is framed by the
-- camera the game keeps for a worgen instead.
race, inOtherForm = "Worgen", false
assert(TooltipModel:Preview("|Hitem:600|h[Boots]|h").cameraFrom == "form",
    "a worgen was framed as though she were a human")
assert(TooltipModel:Preview("|Hitem:600|h[Boots]|h").cameraID == 330,
    "a worgen was not framed by the worgen feet camera")

-- And out of that shape she is a human, framed as one. Which of the two she is
-- in is the whole of what the game cannot work out on its own.
inOtherForm = true
assert(TooltipModel:Preview("|Hitem:600|h[Boots]|h").cameraID == 284,
    "a worgen walking around as a human was still framed as a worgen")

-- A dracthyr is one drake whichever gender it was made as, and an elf in the
-- visage.
race, sex, inOtherForm = "Dracthyr", 2, false
assert(TooltipModel:Preview("|Hitem:600|h[Boots]|h").cameraID == 1705,
    "a drake was not framed as a drake")
sex = 3
assert(TooltipModel:Preview("|Hitem:600|h[Boots]|h").cameraID == 1705,
    "the game keeps one drake, so both genders take the same camera")
-- A female visage is the human female model outright, so she is framed exactly
-- as a human woman is, every slot of her.
inOtherForm = true
for item, human in pairs({
    ["|Hitem:300|h[Helm]|h"] = 274,
    ["|Hitem:850|h[Girdle]|h"] = 282,
    ["|Hitem:860|h[Trousers]|h"] = 283,
    ["|Hitem:600|h[Boots]|h"] = 284,
}) do
    assert(TooltipModel:Preview(item).cameraID == human,
        "a female visage was framed as something other than the human she is drawn as")
end

-- The male visage is a blood elf male instead, bar the head, back and tabard,
-- which the game keeps a camera of its own for.
sex = 2
assert(TooltipModel:Preview("|Hitem:600|h[Boots]|h").cameraID == 464,
    "a male visage was not framed as the blood elf he is drawn as")
assert(TooltipModel:Preview("|Hitem:300|h[Helm]|h").cameraID == 1713,
    "a male visage's head was not framed on the camera kept for it")
sex = 3

-- Chest and shirt are separate cameras. They were the same number in the table
-- this was checked against, which put a chestpiece in a shirt's framing.
race, sex, inOtherForm = "Worgen", 3, false
assert(TooltipModel:Preview("|Hitem:100|h[Breastplate]|h").cameraID == 323
    and TooltipModel:Preview("|Hitem:500|h[Shirt]|h").cameraID == 324,
    "a chestpiece and a shirt were framed by the same camera")

-- The figure is drawn as whichever shape the camera was chosen for, or the two
-- disagree and the shot lands nowhere near the piece.
inOtherForm = true
eventFrame.scripts.OnEvent()
displayedLink = "|Hitem:600|h[Boots]|h"
onItemTooltip(GameTooltip)
assert(figure.nativeForm == false, "a character in her other shape was drawn in her own")

race, sex, inOtherForm = "Human", 3, false
eventFrame.scripts.OnEvent()
displayedLink = "|Hitem:600|h[Boots]|h"
onItemTooltip(GameTooltip)
nextFrame()
assert(figure.nativeForm == true, "a character in her own shape was drawn as something else")
assert(TooltipModel:Preview("|Hitem:600|h[Boots]|h").cameraFrom == "slot",
    "a race with only one shape was given a form camera anyway")

-- And that figure lands, as it would in game, so what follows is a figure that
-- is there rather than one still on its way.
figure.scripts.OnModelLoaded(figure)
nextFrame()

-- The framing can be arrived at in game rather than guessed, sideways as well,
-- and the numbers read back out to be kept.
LuckysWardrobe.TooltipModel:SetFraming("feet", 0.25, 2, 1, -0.3)
displayedLink = "|Hitem:600|h[Boots]|h"
onItemTooltip(GameTooltip)
nextFrame()
assert(figure.zoom == 2 and figure.height == 1 and figure.side == -0.3,
    "framing a slot by hand changed nothing")

said = {}
LuckysWardrobe.TooltipModel:PrintFraming()
local report = table.concat(said, "\n")
assert(report:find("feet: facing 0.25, zoom 2.00, height 1.00, side %-0.30"),
    "the framing was never read back out: " .. report)

-- The report says what the last piece hovered was framed by, and where that
-- camera came from, since a preview that looks wrong was framed by the wrong one
-- of the three or by none.
assert(report:find("item 600", 1, true) and report:find("camera 1608", 1, true),
    "the report said nothing about the piece: " .. report)
assert(report:find("every piece in this slot", 1, true),
    "the report never said where the camera came from: " .. report)
LuckysWardrobe.TooltipModel:SetFraming("feet", 0, 1, 0, 0)

-- Every piece is framed from where a model opens, not on top of the turn and
-- lift the piece before it was given.
displayedLink = "|Hitem:600|h[Boots]|h"
onItemTooltip(GameTooltip)
nextFrame()
assert(figure.facing == 0 and figure.zoom == 1 and figure.height == 0 and figure.side == 0,
    "framing piled up on the last piece's")

-- A camera takes a model over entirely, so a piece in a slot the client hands
-- out no camera for has to be put back to the one the model opens with rather
-- than shot through the last piece's.
local refreshesBefore = figure.refreshes
displayedLink = "|Hitem:850|h[Girdle]|h"
onItemTooltip(GameTooltip)
nextFrame()
assert(figure.refreshes > refreshesBefore, "a piece with no camera kept the last piece's")

-- The loads that come of dressing the figure leave the camera where it is. It
-- was placed on the bare figure on purpose, and placing it again on a figure
-- with the piece on is the very thing that moves it.
displayedLink = "|Hitem:600|h[Boots]|h"
onItemTooltip(GameTooltip)
nextFrame()
local camerasAfterDressing = #appliedCameras
figure.scripts.OnModelLoaded(figure)
assert(#appliedCameras == camerasAfterDressing,
    "the camera was placed again through the piece that had just landed")

-- Comparison tooltips open beside the tooltip and would cover the preview, so it
-- hangs off whichever of them reaches furthest the way it is opening.
GameTooltip.shoppingTooltips = { ShoppingTooltip }
ShoppingTooltip.shown = false
onItemTooltip(GameTooltip)
assert(panel.points[1][2] == GameTooltip, "a hidden comparison tooltip was anchored to")

-- Against the right edge of the screen the preview opens left instead, and the
-- comparison tooltip on that side is what it hangs off.
screenWidth = 650
displayedLink = "|Hitem:100|h[Breastplate]|h"
ShoppingTooltip.shown = true
onItemTooltip(GameTooltip)
assert(panel.points[1][1] == "TOPRIGHT" and panel.points[1][3] == "TOPLEFT",
    "the preview opened off the edge of the screen")
assert(panel.points[1][2] == ShoppingTooltip, "the preview opened underneath the comparison tooltip")
screenWidth = 1000
GameTooltip.shoppingTooltips = {}

-- An item nobody can dress in takes the preview away rather than leaving the
-- last piece hanging beside a potion.
displayedLink = "|Hitem:900|h[Potion]|h"
onItemTooltip(GameTooltip)
assert(not panel.shown, "a potion kept the last piece on screen")

-- A tooltip that hides takes its own preview with it, and only its own: the
-- linked item tooltip stays open on screen while other tooltips come and go.
displayedLink = "|Hitem:100|h[Breastplate]|h"
onItemTooltip(ItemRefTooltip)
assert(panel.shown, "a linked item got no preview")
GameTooltip:Hide()
assert(panel.shown, "another tooltip closing took the preview with it")
ItemRefTooltip:Hide()
assert(not panel.shown, "the preview outlived the tooltip it belonged to")

-- The comparison tooltips beside an item are there to be compared against what
-- is worn, and a preview beside each of those is noise rather than an answer.
onItemTooltip(ShoppingTooltip)
assert(not panel.shown, "a comparison tooltip got a preview of its own")

-- A quest's rewards are read on the tooltip embedded in the quest's own.
onItemTooltip(GameTooltip.ItemTooltip.Tooltip)
assert(panel.shown, "an embedded item tooltip got no preview")

-- Turning the setting off takes the preview that is already up away, rather than
-- leaving it until the next thing is hovered.
settings.tooltipModel = false
TooltipModel:Refresh()
assert(not panel.shown, "turning it off left the preview on screen")
settings.tooltipModel = true

-- A preview answers what a piece you have not got looks like. What is already on
-- you answers nothing, so a tooltip read out of the bags or off the character
-- sheet is passed over, and one already up is taken away.
displayedLink = "|Hitem:100|h[Breastplate]|h"
onItemTooltip(GameTooltip)
assert(panel.shown, "a drop went unpreviewed")

GameTooltip.info = { getterName = "GetBagItem", getterArgs = { 0, 1 } }
onItemTooltip(GameTooltip)
assert(not panel.shown, "a piece sat in the bags was previewed")

GameTooltip.info = { getterName = "GetInventoryItem", getterArgs = { "player", 5 } }
onItemTooltip(GameTooltip)
assert(not panel.shown, "a piece already worn was previewed")

-- Somebody else's gear is read off the same call the character sheet uses, and
-- theirs is exactly what a preview is for.
GameTooltip.info = { getterName = "GetInventoryItem", getterArgs = { "target", 5 } }
onItemTooltip(GameTooltip)
assert(panel.shown, "another player's gear went unpreviewed")

-- Asked for, the bags are previewed like anything else.
settings.tooltipModelWornAndBags = true
GameTooltip.info = { getterName = "GetBagItem", getterArgs = { 0, 1 } }
onItemTooltip(GameTooltip)
assert(panel.shown, "the bags stayed unpreviewed with the setting on")
settings.tooltipModelWornAndBags = false
GameTooltip.info = nil

-- A frame can wave the preview off the tooltips it owns by carrying a flag,
-- which is how the loot browser in Lucky's Loot Wishlist declines it behind a
-- setting of its own. The flag lives on the tooltip's owner, so it costs
-- nothing when no addon sets it, and a tooltip that answers nothing for its
-- owner is previewed as before.
displayedLink = "|Hitem:100|h[Breastplate]|h"
onItemTooltip(GameTooltip)
assert(panel.shown, "a drop went unpreviewed before any owner declined")
local decliningOwner = { luckysWardrobeNoPreview = true }
GameTooltip.GetOwner = function() return decliningOwner end
onItemTooltip(GameTooltip)
assert(not panel.shown, "an owner that declined the preview got one anyway")
decliningOwner.luckysWardrobeNoPreview = nil
onItemTooltip(GameTooltip)
assert(panel.shown, "the preview never came back once the owner allowed it")
GameTooltip.GetOwner = nil

-- A shapeshift or a barber visit leaves a figure wearing nothing this addon put
-- on it, so it is set up again and the piece goes back on.
onItemTooltip(GameTooltip)
nextFrame()
local loadsBeforeChange = figure.loads
eventFrame.scripts.OnEvent()
assert(not panel.shown, "the preview stayed up on a figure that had changed")
onItemTooltip(GameTooltip)
nextFrame()
assert(figure.loads == loadsBeforeChange + 1, "a changed figure was left bare")

-- A client that cannot answer for the player's model yet is not made to guess,
-- though a model of its own needs no character and is shown regardless.
eventFrame.scripts.OnEvent()
modelReady = false
onItemTooltip(GameTooltip)
assert(not panel.shown, "armour was shown before the client could draw the character")

displayedLink = "|Hitem:200|h[Sword]|h"
onItemTooltip(GameTooltip)
assert(panel.shown, "a weapon waited on a character it does not need")

modelReady = true
displayedLink = "|Hitem:100|h[Breastplate]|h"
onItemTooltip(GameTooltip)
assert(panel.shown, "the preview never came back once the client was ready")

-- A model takes a moment to arrive, and a piece put on one still on its way is
-- dropped, so it goes back on the moment the figure lands.
local loadsBeforeArrival = figure.loads
figure.scripts.OnModelLoaded(figure)
nextFrame()
assert(figure.loads == loadsBeforeArrival + 1, "a figure that arrived late was left bare")

-- The loads that come of dressing that figure are left alone entirely. Dressing
-- it afresh there would strip it and start another load on top, and framing it
-- again would place the camera through the piece that had just landed.
local camerasBeforeDressing = #appliedCameras
loadsBeforeArrival = figure.loads
figure.scripts.OnModelLoaded(figure)
nextFrame()
assert(figure.loads == loadsBeforeArrival, "dressing the figure set it dressing itself again")
assert(#appliedCameras == camerasBeforeDressing, "a figure that finished dressing was framed again")

-- Something shown on its own is the model the camera is placed against, so that
-- one is placed again once its geometry has arrived.
local camerasBefore = #appliedCameras
displayedLink = "|Hitem:200|h[Sword]|h"
onItemTooltip(GameTooltip)
alone.scripts.OnModelLoaded(alone)
assert(#appliedCameras > camerasBefore + 1, "a model that arrived late was left unframed")

-- A figure landing with nothing hovered has nothing to put in the frame.
eventFrame.scripts.OnEvent()
displayedLink = "|Hitem:100|h[Breastplate]|h"
onItemTooltip(GameTooltip)
GameTooltip:Clear()
loadsBeforeArrival = figure.loads
figure.scripts.OnModelLoaded(figure)
nextFrame()
assert(figure.loads == loadsBeforeArrival, "a figure dressed itself with no tooltip to stand beside")

-- No slot is framed by hand for now, so every one of them is the game's own
-- camera untouched. The command names them all so a slot can be worked through
-- in game, and this is what it should read before anybody has.
said = {}
TooltipModel:PrintFraming()
local framed = 0
for _, line in ipairs(said) do
    local slot = line:match("^%s*(%a+): facing 0%.00, zoom 1%.00, height 0%.00, side 0%.00$")
    if slot then framed = framed + 1 end
    assert(slot or not line:find(": facing "), "a slot is framed by hand: " .. line)
end
assert(framed > 1, "the command named no slots to work through")

print("Lucky's Wardrobe tooltip model test passed")
