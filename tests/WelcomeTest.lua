-- luacheck: globals C_Timer CreateFrame EventUtil LuckyUI LuckysWardrobe UIParent UISpecialFrames

-- The note is shown once and never again, so these go through when it appears,
-- what it says, the address it hands over, and what counts as having seen it.

local loginCallback
EventUtil = {
    ContinueOnPlayerLogin = function(callback) loginCallback = callback end,
}

-- The note is held back until the loading screen is out of the way, so the wait
-- is run by hand rather than skipped over.
local settle
C_Timer = {
    After = function(_, callback) settle = callback end,
}

UIParent = {}
UISpecialFrames = {}

-- Text is measured to size the panel, so the stub answers in proportion to the
-- text rather than with zero.
local function FontString()
    local fs = { text = "" }
    function fs:SetFont() end
    function fs:SetWidth() end
    function fs:SetJustifyH() end
    function fs:SetWordWrap() end
    function fs:SetSpacing() end
    function fs:SetPoint() end
    function fs:SetTextColor() end
    function fs:SetText(value) self.text = value or "" end
    function fs:GetText() return self.text end
    function fs:GetStringHeight() return math.ceil(#self.text * 6 / 428) * 14 end
    return fs
end

-- The link is an EditBox inside a backdrop frame, so both come from here.
function CreateFrame()
    local frame = { scripts = {}, text = "" }
    function frame:SetBackdrop() end
    function frame:SetBackdropColor() end
    function frame:SetBackdropBorderColor() end
    function frame:SetSize() end
    function frame:SetPoint() end
    function frame:SetAutoFocus() end
    function frame:SetFont() end
    function frame:SetTextColor() end
    function frame:SetText(value) self.text = value or "" end
    function frame:GetText() return self.text end
    function frame:HighlightText() self.highlighted = true end
    function frame:ClearFocus() end
    function frame:SetScript(script, handler) self.scripts[script] = handler end
    return frame
end

local panel
local panels = 0

LuckyUI = {
    BODY_FONT = "font",
    Backdrop = {},
    C = {
        bgInput = { 0.05, 0.04, 0.02, 0.95 },
        borderDark = { 0.2, 0.18, 0.1 },
        textLight = { 1, 1, 1 },
        textMuted = { 0.5, 0.5, 0.5 },
        goldAccent = { 0.8, 0.7, 0.3 },
        goldMuted = { 0.5, 0.4, 0.2 },
    },
    CreateHeader = function() end,
    CreatePanel = function(name)
        panels = panels + 1
        panel = { shown = false, height = 0, lines = {} }
        function panel:GetName() return name end
        function panel:SetPoint() end
        function panel:SetFrameStrata() end
        function panel:SetHeight(value) self.height = value end
        function panel:GetHeight() return self.height end
        function panel:Show() self.shown = true end
        function panel:Hide()
            self.shown = false
            if self.onHide then self.onHide() end
        end
        function panel:IsShown() return self.shown end
        function panel:SetScript(_, handler) self.onHide = handler end
        function panel:CreateFontString()
            local fs = FontString()
            self.lines[#self.lines + 1] = fs
            return fs
        end
        return panel
    end,
    CreateButton = function(_, text, _, _, _)
        local button = { label = FontString() }
        button.label:SetText(text)
        function button:GetText() return self.label:GetText() end
        function button:SetPoint() end
        function button:SetScript(_, handler) self.click = handler end
        return button
    end,
}

LuckysWardrobe = {}

local conflicts = {}
LuckysWardrobe.AddonConflicts = {
    Find = function() return conflicts end,
}

dofile("src/Strings.lua")
dofile("src/Welcome.lua")

local S = LuckysWardrobe.Strings.welcome
local Welcome = LuckysWardrobe.Welcome

local function said(text)
    for _, line in ipairs(panel.lines) do
        if line:GetText() == text then return true end
    end
    return false
end

local function login(db)
    settle = nil
    Welcome:Init(db)
    loginCallback()
    return db
end

-- Nothing is shown while the screen is still building.
local db = { welcomeShown = false }
Welcome:Init(db)
assert(panels == 0, "built nothing before the player is in")

-- Login lands while the loading screen is still up, where a note can be missed
-- entirely, so it waits for a screen the player is looking at.
loginCallback()
assert(panels == 0, "built nothing while the loading screen is still up")
settle()
assert(panel and panel:IsShown(), "put the note on screen once the login has settled")
assert(panel:GetHeight() > 0, "sized the panel to the text it holds")
assert(panel.close:GetText() == S.close, "offered a way to close it")
assert(said(S.headline), "said the addon is newly written")
assert(said(S.body), "said some functionality is missing")
assert(said(S.ask), "asked for bugs and feature requests")
assert(said(S.copyHint), "said how to copy the address")
assert(panel.link:GetText() == S.discordURL, "handed over the Discord address")
assert(UISpecialFrames[1] == "LuckysWardrobeWelcome", "let Escape close it")

-- Showing it is not the same as landing in front of somebody. A note still on
-- screen is one the player has yet to answer, so it is not written off until it
-- has been closed, whether by the button or by Escape.
assert(not db.welcomeShown, "left the note owed while it was still on screen")
panel:Hide()
assert(db.welcomeShown, "counted the note as seen once it was closed")

-- Only ever once. A player who has seen it gets their login back.
login({ welcomeShown = true })
assert(not settle, "did not even wait around at a later login")
assert(not panel:IsShown(), "said nothing at a later login")
assert(panels == 1, "built no second panel")

-- The address is a copy target rather than something to type in, so it survives
-- a keystroke landing in the box.
panel.link.scripts.OnTextChanged(panel.link, true)
assert(panel.link:GetText() == S.discordURL, "put the address back after it was typed over")
panel.link.scripts.OnEditFocusGained(panel.link)
assert(panel.link.highlighted, "selected the address ready to copy")

-- The conflict warning owns that login, and answering it reloads, so the note
-- waits rather than stacking up behind it.
conflicts = { { addon = "BetterWardrobe" } }
local conflicted = login({ welcomeShown = false })
assert(not settle, "held the note back while a conflict is being warned about")
assert(not conflicted.welcomeShown, "left the note owed, so it arrives at the next login")

conflicts = {}
local clear = login({ welcomeShown = false })
settle()
assert(panel:IsShown(), "showed the note once the conflict is out of the way")
panel:Hide()
assert(clear.welcomeShown, "wrote it off once that one had been closed")

-- /wardrobe welcome brings it back for someone who has already dismissed it.
local seen = login({ welcomeShown = true })
assert(not panel:IsShown(), "still said nothing at that login")
Welcome:Show()
assert(panel:IsShown(), "showed the note again when asked for by name")

panel.close.click()
assert(not panel:IsShown(), "closed the note on the button")

-- /wardrobe welcome reset puts it back on the slate, for testing the login it
-- actually arrives on.
Welcome:Reset()
assert(not seen.welcomeShown, "owed the note again after a reset")
login(seen)
settle()
assert(panel:IsShown(), "showed the note at the login after a reset")

print("Lucky's Wardrobe welcome test passed")
