-- luacheck: globals EventUtil InCombatLockdown WARDROBE_CYCLE_KEY WARDROBE_DOWN_VISUAL_KEY WARDROBE_UP_VISUAL_KEY WardrobeCollectionFrame

-- Lucky's Wardrobe: keeps movement keys alive over the journal.
--
-- The wardrobe answers "hand this key back" by returning true from its key
-- handler, and a tainted execution's return value is ignored, so the moment
-- any addon's data reaches the fields that handler reads, every key over the
-- journal is swallowed whenever an appearance tooltip is up. The propagation
-- flag is widget state, honoured however tainted the execution, so the
-- wardrobe's own answer is mirrored onto the flag on every keypress. The
-- flag cannot be set by an addon in combat, but there the return value is
-- usually still being honoured anyway.
LuckysWardrobe = LuckysWardrobe or {}
LuckysWardrobe.WardrobeKeys = {}

local WardrobeKeys = LuckysWardrobe.WardrobeKeys

--- Whether the wardrobe's own handler would hand this key back, which is the
--- answer its return value gives; kept in step with its OnKeyDown.
function WardrobeKeys.Propagates(wardrobe, key)
    if wardrobe.tooltipCycle and key == WARDROBE_CYCLE_KEY then return false end
    if (key == WARDROBE_UP_VISUAL_KEY or key == WARDROBE_DOWN_VISUAL_KEY)
        and wardrobe.activeFrame == wardrobe.SetsCollectionFrame then
        return false
    end
    return true
end

function WardrobeKeys:Init()
    EventUtil.ContinueOnAddOnLoaded("Blizzard_Collections", function()
        WardrobeCollectionFrame:HookScript("OnKeyDown", function(wardrobe, key)
            if not InCombatLockdown() then
                wardrobe:SetPropagateKeyboardInput(WardrobeKeys.Propagates(wardrobe, key))
            end
        end)
    end)
end
