-- luacheck: globals EventUtil InCombatLockdown LuckysWardrobe WARDROBE_CYCLE_KEY WARDROBE_DOWN_VISUAL_KEY WARDROBE_UP_VISUAL_KEY WardrobeCollectionFrame

-- The journal eats movement keys when its key handler's return value is
-- discarded for taint, so the module mirrors that answer onto the propagation
-- flag, which taint cannot touch. These drive the mirror against a stubbed
-- wardrobe: the answer itself, and the flag landing on every keypress.

LuckysWardrobe = {}

WARDROBE_CYCLE_KEY = "TAB"
WARDROBE_UP_VISUAL_KEY = "UP"
WARDROBE_DOWN_VISUAL_KEY = "DOWN"

local inCombat = false
function InCombatLockdown() return inCombat end

local addonLoadedCallback
EventUtil = {
    ContinueOnAddOnLoaded = function(_, callback) addonLoadedCallback = callback end,
}

local wardrobe = {
    SetsCollectionFrame = { name = "sets" },
    ItemsCollectionFrame = { name = "items" },
}
wardrobe.activeFrame = wardrobe.ItemsCollectionFrame

local hooked = {}
function wardrobe:HookScript(script, handler) hooked[script] = handler end
function wardrobe:SetPropagateKeyboardInput(propagate) self.propagateKeys = propagate end

WardrobeCollectionFrame = wardrobe

dofile("src/features/journal/WardrobeKeys.lua")

local WardrobeKeys = LuckysWardrobe.WardrobeKeys

-- The answer mirrors the wardrobe's own handler: Tab is kept while a tooltip
-- offers items to cycle, the arrows are kept while the Sets tab can walk its
-- list, and everything else is handed back.

assert(WardrobeKeys.Propagates(wardrobe, "W"), "movement keys are handed back")
assert(WardrobeKeys.Propagates(wardrobe, "TAB"), "Tab passes with no tooltip up")

wardrobe.tooltipCycle = true
assert(not WardrobeKeys.Propagates(wardrobe, "TAB"), "Tab is kept while a tooltip cycles")
assert(WardrobeKeys.Propagates(wardrobe, "W"), "movement still passes while a tooltip cycles")
wardrobe.tooltipCycle = nil

assert(WardrobeKeys.Propagates(wardrobe, "UP"), "arrows pass on the Items tab")
wardrobe.activeFrame = wardrobe.SetsCollectionFrame
assert(not WardrobeKeys.Propagates(wardrobe, "UP"), "arrows are kept on the Sets tab")
assert(not WardrobeKeys.Propagates(wardrobe, "DOWN"), "both directions")
assert(WardrobeKeys.Propagates(wardrobe, "W"), "movement still passes on the Sets tab")
wardrobe.activeFrame = wardrobe.ItemsCollectionFrame

-- Init hooks the wardrobe once the collections addon loads, and every
-- keypress lands the answer on the propagation flag.

WardrobeKeys:Init()
assert(addonLoadedCallback, "deferred the hook until the collections addon loads")
addonLoadedCallback()
assert(hooked.OnKeyDown, "hooked the wardrobe's key handler")

hooked.OnKeyDown(wardrobe, "W")
assert(wardrobe.propagateKeys == true, "movement keys set the flag to hand back")

wardrobe.tooltipCycle = true
hooked.OnKeyDown(wardrobe, "TAB")
assert(wardrobe.propagateKeys == false, "a cycling Tab sets the flag to keep")
wardrobe.tooltipCycle = nil

-- In combat the flag cannot be set by an addon, so it is left alone.
wardrobe.propagateKeys = nil
inCombat = true
hooked.OnKeyDown(wardrobe, "W")
assert(wardrobe.propagateKeys == nil, "the flag is left alone in combat")
inCombat = false

print("Lucky's Wardrobe wardrobe keys tests passed")
