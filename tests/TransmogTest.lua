-- luacheck: globals C_Timer CreateFrame LuckysEnsemble TransmogFrame hooksecurefunc

LuckysEnsemble = {}

local eventFrame
local watcher
function CreateFrame()
    local frame = {
        RegisterEvent = function() end,
        SetScript = function(self, script, handler) self[script] = handler end,
        Show = function(self) self.shown = true end,
        Hide = function(self) self.shown = false end,
    }
    if not eventFrame then eventFrame = frame else watcher = frame end
    return frame
end

C_Timer = { After = function(_, callback) callback() end }

local tabHeaders = { selectedTabID = 2 }
local wardrobeCollection = {
    TabHeaders = tabHeaders,
    SetTab = function(_, tabID) tabHeaders.selectedTabID = tabID end,
}
TransmogFrame = {
    WardrobeCollection = wardrobeCollection,
    SelectSlot = function(_, _, _) tabHeaders.selectedTabID = 1 end,
}

function hooksecurefunc(target, method, callback)
    local original = target[method]
    target[method] = function(...)
        original(...)
        callback(...)
    end
end

dofile("src/Transmog.lua")

local db = { keepTransmogTab = true }
LuckysEnsemble.Transmog:Init(db)
eventFrame.OnEvent(nil, "TRANSMOGRIFY_OPEN")
watcher.OnUpdate()

TransmogFrame:SelectSlot(nil, true)
assert(tabHeaders.selectedTabID == 2, "kept the active tab after an outfit refresh")

TransmogFrame:SelectSlot(nil, false)
assert(tabHeaders.selectedTabID == 1, "let a manual slot click open Items")

tabHeaders.selectedTabID = 2
watcher.OnUpdate()
db.keepTransmogTab = false
TransmogFrame:SelectSlot(nil, true)
assert(tabHeaders.selectedTabID == 1, "respected the disabled setting")

print("Lucky's Ensemble transmog tab test passed")
