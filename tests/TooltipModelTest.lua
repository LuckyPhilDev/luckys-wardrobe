-- luacheck: globals C_Item C_Timer C_TransmogCollection CreateFrame Enum GameTooltip GetScreenWidth IsUnitModelReadyForUI ItemRefTooltip LuckysWardrobe Model_ApplyUICamera TooltipDataProcessor TooltipUtil UIParent

-- Covers the preview shown beside an item's tooltip: what goes in the frame for
-- a piece the game holds a model of, what goes in it for the armour it only has
-- as a skin on a character, which tooltips get a preview at all, which side of
-- the tooltip it opens on, and everything that takes it away again.

LuckysWardrobe = {}

_G.Enum = { TooltipDataType = { Item = 10 } }
_G.UIParent = "UIParent"

-- A sword, which is a model in its own right; a helm, a chest piece and a pair of
-- boots, which the game only has as a character wearing them; and a potion nobody
-- can dress in, which is most of what passes through a bag.
local ITEMS = {
    ["|Hitem:100|h[Breastplate]|h"] = {
        id = 100, equipSlot = "INVTYPE_CHEST", dressable = true, appearanceID = 501, sourceID = 1,
    },
    ["|Hitem:200|h[Sword]|h"] = {
        id = 200, equipSlot = "INVTYPE_WEAPON", dressable = true, appearanceID = 502, sourceID = 2,
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
    ["|Hitem:900|h[Potion]|h"] = { id = 900, equipSlot = "", dressable = false },
    [900] = { id = 900, equipSlot = "", dressable = false },
}

-- What the client actually holds a model file for, keyed by what it was asked
-- to show. The crown is missing from it on purpose.
local MODEL_FILES = { [502] = 9002, [503] = 9003 }

_G.C_Item = {
    GetItemInfoInstant = function(itemInfo)
        local entry = ITEMS[itemInfo]
        if not entry then return nil end
        return entry.id, "Armor", "Plate", entry.equipSlot
    end,
    IsDressableItemByID = function(itemID)
        for _, entry in pairs(ITEMS) do
            if entry.id == itemID then return entry.dressable end
        end
        return false
    end,
}

-- The camera the wardrobe frames this appearance with, which is what turns a
-- whole character into a shot of one slot.
local CAMERAS = { [1] = 71, [2] = 72, [3] = 73, [4] = 74, [6] = 76, [7] = 77 }

_G.C_TransmogCollection = {
    GetItemInfo = function(itemInfo)
        local entry = ITEMS[itemInfo] or {}
        return entry.appearanceID, entry.sourceID
    end,
    GetAppearanceCameraIDBySource = function(sourceID) return CAMERAS[sourceID] end,
}

-- The real one puts the model where the camera says, which is what any framing
-- on top of it is measured from.
local appliedCameras = {}
_G.Model_ApplyUICamera = function(model, cameraID)
    appliedCameras[#appliedCameras + 1] = { model = model, cameraID = cameraID }
    model:SetFacing(0)
    model:SetPosition(0, 0, 0)
end

-- The client does not describe every camera it hands out, and one it will not
-- describe frames nothing.
local uiCameras = { [71] = true, [72] = true, [73] = true, [76] = true, [77] = true }
_G.GetUICameraInfo = function(cameraID) return uiCameras[cameraID] and 0 or nil end

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
    function frame:RefreshCamera() end
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
    function frame:SetUnit(unit) self.unit = unit end
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

dofile("src/TooltipModel.lua")

local TooltipModel = LuckysWardrobe.TooltipModel
local settings = { tooltipModel = true }
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

-- What is carried is a model in its own right, and comes with the camera the
-- wardrobe frames it with.
local sword = TooltipModel:Preview("|Hitem:200|h[Sword]|h")
assert(sword.alone, "a sword was hung on a character")
assert(sword.appearanceID == 502 and sword.cameraID == 72, "the sword's appearance was not read")

-- Armour is not, whatever slot it is in. Asking the client for a helm on its own
-- draws nothing at all, so a helm goes on the figure with the rest of a suit.
assert(TooltipModel:Preview("|Hitem:300|h[Helm]|h").alone == false,
    "the client was asked for a helm on its own")

-- The game has no chestpiece to show, only somebody wearing one, so that is what
-- it takes to show one.
local breastplate = TooltipModel:Preview("|Hitem:100|h[Breastplate]|h")
assert(breastplate.item == "|Hitem:100|h[Breastplate]|h", "the link is what gets tried on")
assert(breastplate.alone == false, "the game was asked for a chestpiece it does not have")
assert(breastplate.cameraID == 71, "the appearance's own camera was not read")

-- An item the client knows no appearance for can still be worn, and is shown
-- from wherever the model opens.
assert(TooltipModel:Preview("|Hitem:500|h[Shirt]|h").cameraID == nil,
    "a camera was invented for an item with no appearance")

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
assert(appliedCameras[#appliedCameras].cameraID == 72, "the sword was never framed")
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
assert(figure.showing == displayedLink, "the piece was never tried on")
assert(figure.shown and not alone.shown, "the wrong model was left in the frame")
assert(appliedCameras[#appliedCameras].cameraID == 71, "the slot was never framed")

-- A camera frames a slot for the wardrobe's own grid where the client answers
-- for one at all, and neither is the shot a piece is best judged by. A boot sits
-- at the bottom of a figure, so it is lifted into frame and the camera brought
-- in, which is a zoom below 1: the number is how far the camera sits back.
displayedLink = "|Hitem:600|h[Boots]|h"
onItemTooltip(GameTooltip)
assert(figure.zoom < 1, "the camera was pushed away from a boot rather than brought in")
assert(figure.height > 0, "a boot was left at the bottom of the frame")
assert(figure.facing == 0, "a boot was turned away from the camera")

-- A cloak hangs down the back of a figure the camera is looking at the front of.
displayedLink = "|Hitem:700|h[Cape]|h"
onItemTooltip(GameTooltip)
assert(math.abs(figure.facing - math.pi) < 0.01, "a cloak was shown from the front")

-- The framing can be arrived at in game rather than guessed, sideways as well,
-- and the numbers read back out to be kept.
LuckysWardrobe.TooltipModel:SetFraming("feet", 0.25, 2, 1, -0.3)
displayedLink = "|Hitem:600|h[Boots]|h"
onItemTooltip(GameTooltip)
assert(figure.zoom == 2 and figure.height == 1 and figure.side == -0.3,
    "framing a slot by hand changed nothing")

said = {}
LuckysWardrobe.TooltipModel:PrintFraming()
local report = table.concat(said, "\n")
assert(report:find("feet: facing 0.25, zoom 2.00, height 1.00, side %-0.30"),
    "the framing was never read back out: " .. report)

-- The report says what the client answered for the last piece hovered, since a
-- preview that looks wrong is one of those answers being missing.
assert(report:find("item 600", 1, true) and report:find("camera 76", 1, true),
    "the report said nothing about the piece: " .. report)
LuckysWardrobe.TooltipModel:SetFraming("feet", 0, 0.35, 0.8, 0)

-- A camera the client will not describe frames nothing, and says so, since from
-- the outside it looks exactly like no camera at all.
said = {}
uiCameras[76] = nil
LuckysWardrobe.TooltipModel:PrintFraming()
assert(table.concat(said, "\n"):find("will not describe", 1, true),
    "a camera that frames nothing passed for one that works")
uiCameras[76] = true

-- Every piece is framed from where a model opens, not on top of the turn and
-- lift the piece before it was given.
displayedLink = "|Hitem:600|h[Boots]|h"
onItemTooltip(GameTooltip)
assert(figure.facing == 0 and figure.zoom == 0.35 and figure.height == 0.8 and figure.side == 0,
    "framing piled up on the last piece's")

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

-- A shapeshift or a barber visit leaves a figure wearing nothing this addon put
-- on it, so it is set up again and the piece goes back on.
onItemTooltip(GameTooltip)
local loadsBeforeChange = figure.loads
eventFrame.scripts.OnEvent()
assert(not panel.shown, "the preview stayed up on a figure that had changed")
onItemTooltip(GameTooltip)
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
figure.scripts.OnModelLoaded()
assert(figure.loads == loadsBeforeArrival + 1, "a figure that arrived late was left bare")

-- Something shown on its own has only its framing to put back.
local camerasBefore = #appliedCameras
displayedLink = "|Hitem:200|h[Sword]|h"
onItemTooltip(GameTooltip)
alone.scripts.OnModelLoaded(alone)
assert(#appliedCameras > camerasBefore + 1, "a model that arrived late was left unframed")

-- A model landing with nothing hovered has nothing to put in the frame.
GameTooltip:Clear()
loadsBeforeArrival = figure.loads
figure.scripts.OnModelLoaded()
assert(figure.loads == loadsBeforeArrival, "a figure dressed itself with no tooltip to stand beside")

-- Where a shot lands on the figure is the height divided by the zoom, and the two
-- slots settled in game are the ends of what is known to land: the ankle at one
-- end and the upper back at the other. A slot aimed past either is aimed off the
-- figure, at ground below the feet or sky above the head, and comes out black.
said = {}
TooltipModel:PrintFraming()
local landing = {}
for _, line in ipairs(said) do
    local slot, zoom, height = line:match("^%s*(%a+): facing %-?[%d.]+, zoom (%-?[%d.]+), height (%-?[%d.]+)")
    if slot then landing[slot] = tonumber(height) / tonumber(zoom) end
end

assert(landing.feet and landing.cloak, "the two slots settled in game were never framed")
for slot, lands in pairs(landing) do
    assert(lands >= landing.cloak and lands <= landing.feet,
        ("%s is framed off the end of the figure, at %.2f"):format(slot, lands))
end

print("Lucky's Wardrobe tooltip model test passed")
