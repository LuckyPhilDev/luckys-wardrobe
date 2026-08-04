-- luacheck: globals C_Texture ITEM_CLASSES_ALLOWED PixelUtil PLAYER_DIFFICULTY1 PLAYER_DIFFICULTY2 PLAYER_DIFFICULTY3 PLAYER_DIFFICULTY6 WARDROBE_TAB_SETS

-- Lucky's Ensemble: Sets you are close to completing whose missing pieces drop in
-- the instance you're standing in.
LuckysEnsemble = LuckysEnsemble or {}
LuckysEnsemble.SetCompletion = {}

local SetCompletion = LuckysEnsemble.SetCompletion

local APPEARANCES_TAB = 5
local INSTANCE_TYPES = { party = true, raid = true }

local db

local function say(text)
    print(("%s %s"):format(LuckysEnsemble.Strings.addon.prefix, text))
end

--- Whether a set belongs to the tier the game is currently on.
-- A set's patchID and the client's interface number are the same kind of number,
-- so dropping the build digits off both leaves the content patch: a 12.0.7 client
-- and a set from 12.0.0 are both 1200. Sets carrying no patchID at all are never
-- current.
local function contentPatch(version)
    version = tonumber(version)
    return version and math.floor(version / 100) or nil
end

local currentPatch
local function isCurrentTier(setInfo)
    if not currentPatch then
        currentPatch = contentPatch(select(4, GetBuildInfo()))
    end
    return currentPatch ~= nil and contentPatch(setInfo.patchID) == currentPatch
end

-- Drop lookups are the expensive half of a scan and an appearance never moves
-- between bosses, so results last the session.
local dropCache = {}

local function getDrops(sourceID)
    local drops = dropCache[sourceID]
    if not drops then
        drops = C_TransmogCollection.GetAppearanceSourceDrops(sourceID) or {}
        dropCache[sourceID] = drops
    end
    return drops
end

--- The instance the player is in, or nil anywhere else.
-- Drop data names instances the way the Encounter Journal does, which is not
-- always what the map is called, so both names are carried and either may match.
function SetCompletion:GetCurrentInstance()
    local inInstance, instanceType = IsInInstance()
    if not inInstance or not INSTANCE_TYPES[instanceType] then return nil end

    local name, _, _, difficultyName = GetInstanceInfo()
    local journalName
    local uiMapID = C_Map.GetBestMapForUnit("player")
    local journalInstanceID = uiMapID and EJ_GetInstanceForMap(uiMapID)
    if journalInstanceID and journalInstanceID > 0 then
        journalName = EJ_GetInstanceInfo(journalInstanceID)
    end

    return {
        name = name,
        journalName = journalName,
        difficulty = difficultyName,
    }
end

local function isThisInstance(instance, dropInstanceName)
    if not dropInstanceName then return false end
    return dropInstanceName == instance.name or dropInstanceName == instance.journalName
end

-- The two sides name a difficulty differently often enough that equality alone
-- reports a piece as out of reach when it isn't: the journal says "Mythic" where
-- the group is on a "Mythic Keystone", and "Heroic" where the raid is "25 Player
-- (Heroic)". Either name containing the other is the same difficulty.
local function sameDifficulty(a, b)
    if not a or not b then return false end
    if a == b then return true end
    return string.find(a, b, 1, true) ~= nil or string.find(b, a, 1, true) ~= nil
end

-- The difficulties a raid set's description can name, taken from the game's own
-- labels so this reads whatever the client is playing in.
local raidDifficulties
local function isRaidDifficulty(description)
    if description == nil then return false end

    if not raidDifficulties then
        raidDifficulties = {}
        for _, difficulty in ipairs({ PLAYER_DIFFICULTY1, PLAYER_DIFFICULTY2,
            PLAYER_DIFFICULTY3, PLAYER_DIFFICULTY6 }) do
            if difficulty then raidDifficulties[difficulty] = true end
        end
    end

    if raidDifficulties[description] then return true end

    -- Wrath era tier puts the difficulty inside the raid size, as in "10 Player
    -- (Normal)", so the bracketed form counts as naming one too.
    for difficulty in pairs(raidDifficulties) do
        if string.find(description, "(" .. difficulty .. ")", 1, true) then return true end
    end

    return false
end

-- A drop with no difficulties listed is available on all of them. Anything else is
-- reported, so a piece that is here but out of reach on this difficulty says so.
local function difficultyNote(instance, difficulties)
    if not difficulties or #difficulties == 0 then return nil end

    for _, difficulty in ipairs(difficulties) do
        if sameDifficulty(difficulty, instance.difficulty) then return nil end
    end

    return table.concat(difficulties, ", ")
end

-- A raid set names its difficulty where other sets put a colour or an event, so
-- the difficulty of a set matched by its source is the difficulty it describes.
-- Only a description that actually names one counts: anything else says nothing
-- about difficulty and must not be reported as though it did.
local function variantDifficultyNote(instance, variant)
    if not variant or not isRaidDifficulty(variant) then return nil end
    if sameDifficulty(variant, instance.difficulty) then return nil end

    return variant
end

--- Where a missing piece comes from in this instance, or nil if it drops elsewhere.
local function findDropHere(instance, sourceID)
    for _, drop in ipairs(getDrops(sourceID)) do
        if isThisInstance(instance, drop.instance) then
            return {
                encounter = drop.encounter,
                difficultyNote = difficultyNote(instance, drop.difficulties),
            }
        end
    end
end

local function pieceName(sourceID)
    local sourceInfo = C_TransmogCollection.GetSourceInfo(sourceID)
    return sourceInfo and sourceInfo.name
end

--- Uncollected sources of a set, and how many pieces it holds in total.
local function getMissingSources(setID)
    local appearances = C_TransmogSets.GetSetPrimaryAppearances(setID)
    if not appearances then return nil, 0 end

    local missing, total = {}, 0
    for _, appearance in ipairs(appearances) do
        total = total + 1
        -- Named appearanceID, holds a sourceID. Blizzard's field, left as it comes.
        if not appearance.collected then
            missing[#missing + 1] = appearance.appearanceID
        end
    end

    return missing, total
end

--- Whether a set this character cannot wear is one to hear about anyway.
-- A set they cannot wear is not one they can finish here, and a raid holds one per
-- class, so this is most of what the game hands over. Someone collecting across an
-- account still wants to know a raid is worth an alt trip, which is the one reason
-- to ask for them back: the toggle decides whether they are considered at all, and
-- the class list narrows that to the alts actually being collected for.
-- A set naming no class is left out of that argument, since something other than
-- class is holding it back and no choice about classes should decide it.
local function wantsOtherClassSet(classMask)
    if not db.includeOtherClassSets then return false end

    local classes = LuckysEnsemble.Classes:FromMask(classMask)
    if #classes == 0 then return true end

    for _, class in ipairs(classes) do
        if not db.hiddenSetClasses[class.file] then return true end
    end
    return false
end

--- Sets close enough to completion to be worth a drop lookup.
-- Cheap: it reads only the collected state the set data already carries. Every set
-- left standing here pays for a lookup per missing piece, which is why the limit is
-- applied before that and not after.
local function collectCandidates(maxMissing, stats)
    local candidates = {}

    -- A set from the tier being raided now gets finished by playing, so being told
    -- about it every pull is nagging rather than news. Hearing about it anyway is a
    -- choice someone can make, not the starting point.
    local skipCurrentTier = not db.includeCurrentTier

    for _, setInfo in ipairs(C_TransmogSets.GetAllSets() or {}) do
        stats.sets = stats.sets + 1
        if setInfo.validForCharacter == false and not wantsOtherClassSet(setInfo.classMask) then
            stats.skippedClass = stats.skippedClass + 1
        elseif skipCurrentTier and isCurrentTier(setInfo) then
            stats.skippedCurrentTier = stats.skippedCurrentTier + 1
        else
            local missing, total = getMissingSources(setInfo.setID)
            if missing and #missing > maxMissing then
                stats.overLimit = stats.overLimit + 1
            end
            if missing and #missing > 0 and #missing <= maxMissing then
                candidates[#candidates + 1] = {
                    setID = setInfo.setID,
                    name = setInfo.name,
                    -- Where the set comes from, and which version of it this is. The
                    -- journal groups sets by the first and tells them apart by the
                    -- second, so a raid set carries its raid and its difficulty.
                    source = setInfo.label,
                    variant = setInfo.description,
                    classMask = setInfo.classMask,
                    total = total,
                    collected = total - #missing,
                    missing = missing,
                }
            end
        end
    end

    return candidates
end

-- Which pieces are currently drawing attention to themselves. Kept out here rather
-- than on the piece because the panel rebuilds its data on every redraw.
local flashUntil = {}
local FLASH_SECONDS = 10

local function isFlashing(sourceID)
    local expiry = flashUntil[sourceID]
    return expiry ~= nil and expiry > GetTime()
end

-- Everywhere a piece is known to drop, this instance's bosses first, so hovering
-- one still to find answers "where do I get this" rather than only "is it here".
local function dropLocations(instance, sourceID)
    local locations = {}
    for _, drop in ipairs(getDrops(sourceID)) do
        locations[#locations + 1] = {
            instance = drop.instance,
            encounter = drop.encounter,
            difficulties = drop.difficulties and table.concat(drop.difficulties, ", ") or nil,
            isHere = isThisInstance(instance, drop.instance),
        }
    end

    table.sort(locations, function(a, b)
        if a.isHere ~= b.isHere then return a.isHere end
        return (a.instance or "") < (b.instance or "")
    end)
    return locations
end

-- What the player is carrying that the catalyst would turn into a piece, keyed by
-- source. Read once per scan rather than per set, since the answer costs a lookup
-- per item in the bags and does not change while a scan is running.
local function catalysableSources()
    if not db.markCatalysablePieces then return {} end
    return LuckysEnsemble.Catalyst:GetHeldTargets().bySource
end

--- Every piece of the set, and how many of them the player holds the makings of.
-- Icons come from GetItemInfoInstant, which reads the client's own item database
-- rather than the cache the item's name needs, so an icon is there on the first
-- draw where a name is not.
local function buildPieceList(instance, setID, hereBySource, catalysable)
    local pieces, catalysableCount = {}, 0
    for _, appearance in ipairs(C_TransmogSets.GetSetPrimaryAppearances(setID) or {}) do
        local sourceID = appearance.appearanceID
        local sourceInfo = C_TransmogCollection.GetSourceInfo(sourceID)
        local itemID = sourceInfo and sourceInfo.itemID
        local drop = hereBySource[sourceID]
        local collected = appearance.collected and true or false
        local heldFor = not collected and catalysable[sourceID] or nil
        if heldFor then catalysableCount = catalysableCount + 1 end

        pieces[#pieces + 1] = {
            sourceID = sourceID,
            itemID = itemID,
            icon = itemID and select(5, C_Item.GetItemInfoInstant(itemID)) or nil,
            name = sourceInfo and sourceInfo.name,
            collected = collected,
            availableHere = drop ~= nil,
            flashing = isFlashing(sourceID),
            -- The item that would become this piece, for a piece the player has not
            -- collected but already holds the makings of.
            catalysable = heldFor,
            hereInstance = drop and instance.name,
            encounter = drop and drop.encounter,
            difficultyNote = drop and drop.difficultyNote,
            -- Only a piece still to find needs somewhere to come from.
            drops = not collected and dropLocations(instance, sourceID) or nil,
            sortOrder = sourceInfo and EJ_GetInvTypeSortOrder(sourceInfo.invType) or 99,
        }
    end

    table.sort(pieces, function(a, b)
        if a.sortOrder ~= b.sortOrder then return a.sortOrder < b.sortOrder end
        return (a.itemID or 0) < (b.itemID or 0)
    end)
    return pieces, catalysableCount
end

local function newStats()
    return { sets = 0, skippedClass = 0, skippedCurrentTier = 0, overLimit = 0,
        candidates = 0, lookups = 0, wrongDifficulty = 0 }
end

local function compareMatches(a, b)
    if a.remaining ~= b.remaining then return a.remaining < b.remaining end
    if #a.here ~= #b.here then return #a.here > #b.here end
    if a.total ~= b.total then return a.total > b.total end
    return (a.name or "") < (b.name or "")
end

--- Every set with a missing piece that drops in this instance, closest first.
-- The second return is what each stage of the scan saw, which is the only way to
-- tell a set that was filtered out from one whose pieces carry no drop data.
function SetCompletion:Scan(instance, maxMissing)
    local stats = newStats()
    if not instance then return {}, stats end
    maxMissing = maxMissing or db.instanceSetsMaxMissing

    local matches = {}
    local candidates = collectCandidates(maxMissing, stats)
    stats.candidates = #candidates
    local catalysable = catalysableSources()

    for _, candidate in ipairs(candidates) do
        -- Tier pieces are not drops. They are made from a token or the catalyst, so
        -- nothing in the drop data ties one to the raid it comes from. What does tie
        -- them is the set's own source, which is the raid's name. A set that names
        -- this instance therefore has every missing piece here, boss unknown.
        local wholeSetIsHere = isThisInstance(instance, candidate.source)

        -- A raid's set exists once per difficulty, and only the one matching the run
        -- is obtainable, so the others are not sets you can finish here. They are
        -- dropped rather than flagged: three near-identical rows for the same set,
        -- two of them unobtainable, is noise however well labelled.
        if wholeSetIsHere and variantDifficultyNote(instance, candidate.variant) then
            wholeSetIsHere = false
            stats.wrongDifficulty = stats.wrongDifficulty + 1
        end

        local here, hereBySource = {}, {}
        for _, sourceID in ipairs(candidate.missing) do
            stats.lookups = stats.lookups + 1

            -- Drop data is preferred wherever it exists, because it names the boss.
            local drop = findDropHere(instance, sourceID)
            if not drop and wholeSetIsHere then
                drop = {}
            end

            if drop then
                drop.name = pieceName(sourceID)
                drop.sourceID = sourceID
                here[#here + 1] = drop
                hereBySource[sourceID] = drop
            end
        end

        if #here > 0 then
            candidate.here = here
            candidate.remaining = #candidate.missing - #here
            candidate.pieces, candidate.catalysable =
                buildPieceList(instance, candidate.setID, hereBySource, catalysable)
            candidate.missing = nil
            matches[#matches + 1] = candidate
        end
    end

    table.sort(matches, compareMatches)
    return matches, stats
end

-- Scanning every set is too much to repeat for each item that drops, and the
-- answer only changes when the collection does.
local wantedCache, wantedCacheLimit

--- Every piece still missing from a set within the limit, wherever that set comes
--- from. Unlike the scan this has nothing to do with where the player is standing:
--- gear that finishes a set drops in the open world and from quests too.
function SetCompletion:GetWantedPieces(maxMissing)
    maxMissing = maxMissing or db.instanceSetsMaxMissing
    if wantedCache and wantedCacheLimit == maxMissing then return wantedCache end

    local bySource, byVisual, sourceByVisual = {}, {}, {}
    for _, candidate in ipairs(collectCandidates(maxMissing, newStats())) do
        for _, sourceID in ipairs(candidate.missing) do
            bySource[sourceID] = candidate
            -- A lookalike teaches the same appearance, so the visual matches too,
            -- and the set's own piece is remembered alongside it.
            local sourceInfo = C_TransmogCollection.GetSourceInfo(sourceID)
            if sourceInfo and sourceInfo.visualID then
                byVisual[sourceInfo.visualID] = candidate
                sourceByVisual[sourceInfo.visualID] = sourceID
            end
        end
    end

    wantedCache = { bySource = bySource, byVisual = byVisual, sourceByVisual = sourceByVisual }
    wantedCacheLimit = maxMissing
    return wantedCache
end

function SetCompletion:ForgetWantedPieces()
    wantedCache = nil
end

-- ---------------------------------------------------------------------------
-- Diagnosis
-- ---------------------------------------------------------------------------

-- An empty list has several honest causes and they are indistinguishable from
-- outside: set data that has not loaded, a character the sets aren't valid for,
-- everything sitting past the missing-piece limit, or drop data naming this
-- instance something the game does not call it. This reports each stage so the
-- one that emptied the list can be told from the ones that did not.
local DIAGNOSIS_ROWS = 8

function SetCompletion:Diagnose()
    local sets = C_TransmogSets.GetAllSets() or {}
    say(("Set data: %d sets, Blizzard_Collections %s"):format(#sets,
        C_AddOns.IsAddOnLoaded("Blizzard_Collections") and "loaded" or "NOT loaded"))

    local instance = self:GetCurrentInstance()
    if not instance then
        say("Not in a dungeon or raid, so there is nothing to match against.")
        return
    end
    say(("Instance: %s / journal %s / %s"):format(instance.name,
        instance.journalName or "none", instance.difficulty or "none"))

    -- Sets whose own source names this instance, found without a single drop
    -- lookup. A tier set reaches the list this way and no other, so an empty
    -- result here alongside a full set list is a name that does not match.
    local labelled = {}
    for _, setInfo in ipairs(sets) do
        if isThisInstance(instance, setInfo.label) then
            local missing, total = getMissingSources(setInfo.setID)
            labelled[#labelled + 1] = ("%s [%s/%s] %d of %d missing%s"):format(
                setInfo.name, setInfo.label or "no label", setInfo.description or "no description",
                missing and #missing or 0, total,
                setInfo.validForCharacter == false and ", not valid for this character" or "")
        end
    end

    say(("Sets whose label names this instance: %d"):format(#labelled))
    for index = 1, math.min(#labelled, DIAGNOSIS_ROWS) do
        say("  " .. labelled[index])
    end

    local atLimit, limitStats = self:Scan(instance)
    say(("At the current limit of %d: %d matched (%d sets, %d skipped for class, %d for current tier, %d over the limit)")
        :format(db.instanceSetsMaxMissing, #atLimit, limitStats.sets, limitStats.skippedClass,
            limitStats.skippedCurrentTier, limitStats.overLimit))

    -- Rerun with the limit effectively lifted. Anything that appears only here was
    -- excluded by the limit rather than by the matching.
    local generous = self:Scan(instance, 100)
    say(("With the limit lifted: %d matched"):format(#generous))
    for index = 1, math.min(#generous, DIAGNOSIS_ROWS) do
        local match = generous[index]
        say(("  %s [%s] %d of %d collected, %d here"):format(match.name,
            match.source or "no label", match.collected, match.total, #match.here))
    end
end


-- ---------------------------------------------------------------------------
-- Panel
-- ---------------------------------------------------------------------------

-- The panel arrives at reading size and then gets out of the way. Both states are
-- the same window at two scales rather than two layouts, so the icons and text
-- shrink together and nothing has to be measured twice.
local TUCKED_SCALE = 0.7
local GLIDE_SECONDS = 0.7

-- How long it holds the middle of the screen before tucking itself away. Zero
-- means it never takes the middle at all and opens tucked.
local function dwellSeconds()
    return db.instanceSetsDwellSeconds
end

-- The quality border stands 2px proud on each side, so the gap has to clear both
-- of them before it separates anything: at 4 the borders of two collected pieces
-- met in the middle.
local ICON_SIZE, ICON_GAP = 40, 8
-- Half the icon reads as a stamp on the piece. Much smaller and it is a smudge at
-- this size; much larger and it is the piece that looks like the decoration.
local BADGE_SIZE = ICON_SIZE * 0.5
local MAX_ICONS = 14
local PADDING = 10
local HEADER_HEIGHT, SUBTITLE_HEIGHT = 32, 22
local TITLE_HEIGHT = 18
local ROW_HEIGHT = TITLE_HEIGHT + ICON_SIZE + 12
local MIN_COLUMNS = 6

-- Past this the window would be taller than it is useful, so it stops growing and
-- the rest are reached by scrolling.
local MAX_VISIBLE_ROWS = 4

-- The scroll list keeps this much of its width clear for the scrollbar, so the
-- panel has to allow for it on top of the icons or the last column sits under it.
local SCROLLBAR_GUTTER = 14

local panel

-- Blizzard's proc glow: the effect an action button shows when a spell lights up.
-- The template behind it has been renamed more than once, so each name is tried
-- until one builds. The panel's own halo stands in if none of them does, which
-- keeps the highlight working rather than making it a bet on a template name.
local GLOW_TEMPLATES = { "ActionBarButtonSpellActivationAlert", "ActionButtonSpellAlertTemplate" }

-- The fallback haloes currently on screen, held as a set because rows are reused
-- as the list scrolls and each redraw of one speaks only for itself. Driven from
-- the panel's own OnUpdate rather than an animation object, so the pulse is one
-- arithmetic step in a loop that already runs and cannot quietly fail to start.
local glowingIcons = {}
local glowPhase = 0

local function attachProcGlow(icon)
    for _, template in ipairs(GLOW_TEMPLATES) do
        local ok, alert = pcall(CreateFrame, "Frame", nil, icon, template)
        if ok and alert then
            -- Blizzard draws the alert about a fifth wider than the button it sits on.
            local overhang = ICON_SIZE * 0.2
            alert:SetPoint("TOPLEFT", -overhang, overhang)
            alert:SetPoint("BOTTOMRIGHT", overhang, -overhang)
            alert:Hide()
            return alert
        end
    end
    return nil
end

-- The looping animation is the one worth having, since the highlight has to hold
-- attention for several seconds rather than announce itself once. Names differ by
-- template, so the best available is played and the rest ignored.
local PROC_ANIMATIONS = { "ProcLoop", "ProcStartAnim", "animIn" }

local function playProcGlow(alert)
    alert:Show()
    for _, name in ipairs(PROC_ANIMATIONS) do
        local animation = alert[name]
        if animation and animation.Play then
            pcall(animation.Play, animation)
            return
        end
    end
end

local function stopProcGlow(alert)
    for _, name in ipairs(PROC_ANIMATIONS) do
        local animation = alert[name]
        if animation and animation.Stop then
            pcall(animation.Stop, animation)
        end
    end
    alert:Hide()
end

-- Quality needs the item's data, which arrives from the server, so early on there
-- may be none. The border falls back to the panel's own gold rather than waiting.
local function qualityColor(itemID)
    local quality = itemID and (C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(itemID)
        or select(3, C_Item.GetItemInfo(itemID)))
    local color = quality and ITEM_QUALITY_COLORS[quality]
    if color then
        return color.r, color.g, color.b
    end
    return LuckyUI.C.goldAccent[1], LuckyUI.C.goldAccent[2], LuckyUI.C.goldAccent[3]
end

-- The game's own catalyst mark, so a stamped piece reads the way the catalyst's
-- own window does. Checked rather than assumed: an atlas that has been renamed
-- draws nothing at all, and a blank corner is worse than no stamp.
local CATALYST_ATLAS = "CreationCatalyst-32x32"

local hasCatalystAtlas
local function catalystAtlasExists()
    if hasCatalystAtlas == nil then
        hasCatalystAtlas = C_Texture.GetAtlasInfo(CATALYST_ATLAS) ~= nil
    end
    return hasCatalystAtlas
end

-- Colour means one thing only: a piece the player has. Those keep their art and
-- take a quality border, the way an owned appearance is framed in the journal.
-- Everything still to find is greyed out, and the two kinds of missing piece are
-- told apart by weight rather than hue, since a second colour reads as a second
-- meaning and the hover text says which is which.
-- A piece the player already holds the makings of is a third thing to say, and it
-- is said with a corner stamp for the same reason: the piece is still missing and
-- still reads as missing, with a mark on it rather than a colour of its own.
local function styleIcon(button, piece)
    button.texture:SetTexture(piece.icon or QUESTION_MARK_ICON)
    button.texture:SetDesaturated(not piece.collected)
    button.catalyst:SetShown(piece.catalysable ~= nil and catalystAtlasExists())

    -- Something that just dropped is the one thing on the panel worth looking at,
    -- so it says so loudly and briefly rather than joining the greyscale.
    if piece.flashing then
        if button.procGlow then
            playProcGlow(button.procGlow)
        else
            button.glow:SetAlpha(0.8)
            button.glow:Show()
            glowingIcons[button.glow] = true
        end
    elseif button.procGlow then
        stopProcGlow(button.procGlow)
    else
        button.glow:Hide()
        glowingIcons[button.glow] = nil
    end

    if piece.collected then
        button.texture:SetVertexColor(1, 1, 1)
        button.texture:SetAlpha(1)
        button.border:SetColorTexture(qualityColor(piece.itemID))
        button.border:Show()
    elseif piece.availableHere then
        button.texture:SetVertexColor(0.75, 0.75, 0.75)
        button.texture:SetAlpha(1)
        button.border:Hide()
    else
        button.texture:SetVertexColor(0.5, 0.5, 0.5)
        button.texture:SetAlpha(0.45)
        button.border:Hide()
    end
end

-- A long-running dungeon set can drop from a dozen bosses across as many places;
-- past a handful the list stops being an answer and becomes a wall.
local MAX_DROP_LINES = 6

local function showPieceTooltip(anchor, piece)
    local S = LuckysEnsemble.Strings.setTracker
    GameTooltip:SetOwner(anchor, "ANCHOR_RIGHT")

    GameTooltip:AddLine(piece.name or UNKNOWN, 1, 0.82, 0)
    GameTooltip:AddLine(piece.collected and TRANSMOGRIFY_TOOLTIP_APPEARANCE_KNOWN
        or TRANSMOGRIFY_TOOLTIP_APPEARANCE_UNKNOWN,
        piece.collected and 0.41 or 1, piece.collected and 0.86 or 0.42,
        piece.collected and 0.49 or 0.42)

    local drops = piece.drops or {}
    if #drops > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(S.dropsFrom, 1, 0.82, 0)
        for index, drop in ipairs(drops) do
            if index > MAX_DROP_LINES then
                GameTooltip:AddLine(S.andMore:format(#drops - MAX_DROP_LINES), 0.54, 0.49, 0.42)
                break
            end

            local text = drop.encounter or UNKNOWN
            if not drop.isHere then
                text = WARDROBE_TOOLTIP_ENCOUNTER_SOURCE:format(text, drop.instance or UNKNOWN)
            end
            if drop.difficulties then
                text = ("%s (%s)"):format(text, drop.difficulties)
            end

            if drop.isHere then
                GameTooltip:AddLine(text, 0.41, 0.86, 0.49)
            else
                GameTooltip:AddLine(text, 0.54, 0.49, 0.42)
            end
        end
    end

    -- The drop list above names every source equally, because anywhere else that is
    -- all there is to say. Standing in one of those places is the whole point here,
    -- so which of them is underfoot gets called out on the end.
    if not piece.collected and piece.availableHere then
        GameTooltip:AddLine(" ")
        local here = piece.encounter
            and WARDROBE_TOOLTIP_ENCOUNTER_SOURCE:format(piece.encounter, piece.hereInstance or UNKNOWN)
            or S.comesFromHere
        GameTooltip:AddLine(here, 0.41, 0.86, 0.49)
        if piece.difficultyNote then
            GameTooltip:AddLine(S.dropsOn:format(piece.difficultyNote), 1, 0.42, 0.42)
        end
    end

    -- The stamp says a piece is halfway yours. Only the hover can say what would
    -- finish the job, and naming the item is the difference between knowing that
    -- and going looking through the bags for it.
    if piece.catalysable then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(S.catalystWouldMake, 1, 0.82, 0)
        GameTooltip:AddLine(piece.catalysable, 0.91, 0.86, 0.78)
    end

    GameTooltip:Show()
end

local function showRowTooltip(row, match)
    local S = LuckysEnsemble.Strings.setTracker
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:AddLine(match.name or UNKNOWN, 1, 0.82, 0)
    local subtitle = match.variant or match.source
    if subtitle then
        GameTooltip:AddLine(subtitle, 0.54, 0.49, 0.42)
    end

    -- The row has room to name one class. Where a set is shared by an armour type's
    -- worth of them, this is the only place they are all named.
    local classes = LuckysEnsemble.Classes:FromMask(match.classMask)
    if #classes > 0 then
        GameTooltip:AddLine(ITEM_CLASSES_ALLOWED:format(LuckysEnsemble.Classes:Names(classes)),
            0.91, 0.86, 0.78)
    end

    GameTooltip:AddLine(S.collectedOf:format(match.collected, match.total), 0.91, 0.86, 0.78)
    GameTooltip:AddLine(" ")

    -- Item names arrive from the server, so early on there may be none to show. A
    -- row of "Unknown" says less than nothing; the count above already carries the
    -- meaning, and the names fill in on the redraw once the data lands.
    for _, piece in ipairs(match.here) do
        if piece.name then
            local text = piece.name
            if piece.encounter then
                text = WARDROBE_TOOLTIP_ENCOUNTER_SOURCE:format(text, piece.encounter)
            end
            GameTooltip:AddLine(text, 0.41, 0.86, 0.49)
            if piece.difficultyNote then
                GameTooltip:AddLine("   " .. S.dropsOn:format(piece.difficultyNote), 1, 0.42, 0.42)
            end
        end
    end

    if match.remaining > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(S.stillMissing:format(match.remaining), 0.54, 0.49, 0.42)
    end

    if match.catalysable and match.catalysable > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(S.couldCatalyse:format(match.catalysable), 1, 0.82, 0)
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(S.clickToShow, 0.54, 0.49, 0.42)
    GameTooltip:Show()
end

local function showSetInJournal(match)
    if not CollectionsJournal or not CollectionsJournal:IsShown() then
        ToggleCollectionsJournal(APPEARANCES_TAB)
    end

    local ok, err = pcall(function()
        WardrobeCollectionFrame:SetTab(WARDROBE_TAB_SETS)
        WardrobeCollectionFrame.SetsCollectionFrame:SelectSet(match.setID)
    end)

    if not ok then
        LuckysEnsemble.DevLog(("Could not open set %s in the journal. %s")
            :format(tostring(match.setID), tostring(err)))
    end
end

-- Built for the scroll list, which sizes the row, places it, and gives it its
-- hover highlight and click.
local function createRow(parent)
    local row = CreateFrame("Frame", nil, parent)

    row.count = row:CreateFontString(nil, "OVERLAY")
    row.count:SetFont(LuckyUI.BODY_FONT, 13)
    row.count:SetTextColor(LuckyUI.C.textLight[1], LuckyUI.C.textLight[2], LuckyUI.C.textLight[3])
    row.count:SetPoint("TOPRIGHT", 0, -2)

    -- Whose set it is, in that class's own colour. A raid holds one per class and
    -- their names rarely say which, so the colour is what tells them apart.
    row.class = row:CreateFontString(nil, "OVERLAY")
    row.class:SetFont(LuckyUI.BODY_FONT, 12)
    row.class:SetPoint("TOPRIGHT", row.count, "TOPLEFT", -8, 0)
    row.class:SetJustifyH("RIGHT")
    row.class:SetWordWrap(false)

    row.name = row:CreateFontString(nil, "OVERLAY")
    row.name:SetFont(LuckyUI.BODY_FONT, 13)
    row.name:SetTextColor(LuckyUI.C.textGold[1], LuckyUI.C.textGold[2], LuckyUI.C.textGold[3])
    row.name:SetPoint("TOPLEFT", 0, -2)
    row.name:SetPoint("RIGHT", row.class, "LEFT", -6, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    -- Enough icons for the biggest set, built once and shown as each row needs.
    row.icons = {}
    for iconIndex = 1, MAX_ICONS do
        local icon = CreateFrame("Frame", nil, row)
        icon:SetSize(ICON_SIZE, ICON_SIZE)
        icon:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT",
            (iconIndex - 1) * (ICON_SIZE + ICON_GAP), -4)

        -- Behind everything and wider still, so what shows is a halo around the
        -- piece rather than a wash over its art.
        icon.glow = icon:CreateTexture(nil, "BACKGROUND", nil, -1)
        icon.glow:SetPoint("TOPLEFT", -7, 7)
        icon.glow:SetPoint("BOTTOMRIGHT", 7, -7)
        icon.glow:SetColorTexture(1, 0.82, 0)
        icon.glow:SetBlendMode("ADD")
        icon.glow:Hide()

        icon.procGlow = attachProcGlow(icon)

        -- Drawn behind the art and slightly larger, so only its edge shows.
        icon.border = icon:CreateTexture(nil, "BACKGROUND")
        icon.border:SetPoint("TOPLEFT", -2, 2)
        icon.border:SetPoint("BOTTOMRIGHT", 2, -2)
        icon.border:Hide()

        icon.texture = icon:CreateTexture(nil, "ARTWORK")
        icon.texture:SetAllPoints()
        icon.texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)

        -- Over the corner of the art rather than inside it, so the stamp is legible
        -- at this size without covering the piece it is describing.
        icon.catalyst = icon:CreateTexture(nil, "OVERLAY")
        icon.catalyst:SetSize(BADGE_SIZE, BADGE_SIZE)
        icon.catalyst:SetPoint("BOTTOMRIGHT", 3, -3)
        icon.catalyst:SetAtlas(CATALYST_ATLAS)
        icon.catalyst:Hide()

        -- Each piece answers for itself on hover, which is the only place there is
        -- room to name the bosses that drop it.
        icon:EnableMouse(true)
        icon:SetScript("OnEnter", function(self)
            if self.piece then showPieceTooltip(self, self.piece) end
        end)
        icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
        icon:SetScript("OnMouseUp", function(self)
            if self.match then showSetInJournal(self.match) end
        end)

        icon:Hide()
        row.icons[iconIndex] = icon
    end

    row:SetScript("OnEnter", function(self)
        if self.match then showRowTooltip(self, self.match) end
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)

    return row
end

-- A set naming one class is that class's, and the row says so. One naming several
-- belongs to an armour type rather than to anybody, so the row stays quiet about it
-- and leaves the full list to the tooltip.
local function rowClassName(classMask)
    local classes = LuckysEnsemble.Classes:FromMask(classMask)
    if #classes ~= 1 then return "" end
    return LuckysEnsemble.Classes:Colour(classes[1], classes[1].name)
end

local function updateRow(row, match)
    row.match = match
    row.name:SetText(match.name or "")
    row.class:SetText(rowClassName(match.classMask))
    row.count:SetText(("%d/%d"):format(match.collected, match.total))

    local pieces = match.pieces or {}
    for index, icon in ipairs(row.icons) do
        local piece = pieces[index]
        if piece then
            icon.piece = piece
            icon.match = match
            styleIcon(icon, piece)
            icon:Show()
        else
            icon.piece = nil
            icon:Hide()
        end
    end
end

--- Size the window to what it is showing, so there is no empty half to it. Past a
--- few sets it stops growing and the rest are scrolled to.
local function layoutPanel(frame, matches)
    -- The rows are about to be refilled, so whatever was glowing before this is no
    -- longer what is on screen.
    wipe(glowingIcons)

    local columns = MIN_COLUMNS
    for _, match in ipairs(matches) do
        columns = math.max(columns, math.min(#(match.pieces or {}), MAX_ICONS))
    end

    local rows = math.min(#matches, MAX_VISIBLE_ROWS)
    local scrolls = #matches > MAX_VISIBLE_ROWS
    local width = PADDING * 2 + columns * (ICON_SIZE + ICON_GAP) - ICON_GAP
    local height = HEADER_HEIGHT + SUBTITLE_HEIGHT + rows * ROW_HEIGHT + PADDING
    if scrolls then
        width = width + SCROLLBAR_GUTTER
    end
    if #matches == 0 then
        height = HEADER_HEIGHT + SUBTITLE_HEIGHT + 40
    end

    frame:SetWantedSize(width, height)
    frame:ReserveScrollbar(scrolls)
    frame:SetMatches(matches)
end

-- Positions are kept in UIParent's coordinates, not the frame's, because the two
-- states are at different scales and SetPoint offsets are read in the frame's own
-- scale. Converting on the way in and out keeps one meaning for a saved position.
local function tuckedPosition()
    local saved = db.instanceSetsPosition
    if type(saved) == "table" and saved.x and saved.y then
        return saved.x, saved.y
    end
    return 16, -16
end

local function ease(t)
    return t * t * (3 - 2 * t)
end

local function buildPanel()
    local S = LuckysEnsemble.Strings.setTracker
    local frame = LuckyUI.CreatePanel("LuckysEnsembleInstanceSets", UIParent, 100, 100)
    frame:SetFrameStrata("HIGH")
    frame:Hide()

    local header = LuckyUI.CreateHeader(frame, S.title)

    -- Sits inboard of the close button the header already owns, matching its size
    -- so the two read as a pair.
    local sizeButton = CreateFrame("Button", nil, header)
    sizeButton:SetSize(20, 20)
    sizeButton:SetPoint("RIGHT", -32, 0)

    local sizeBg = sizeButton:CreateTexture(nil, "BACKGROUND")
    sizeBg:SetAllPoints()
    sizeBg:SetColorTexture(LuckyUI.C.goldMuted[1], LuckyUI.C.goldMuted[2], LuckyUI.C.goldMuted[3], 0.8)

    local sizeGlyph = sizeButton:CreateFontString(nil, "OVERLAY")
    sizeGlyph:SetFont(LuckyUI.BODY_FONT, 13, "OUTLINE")
    sizeGlyph:SetTextColor(1, 1, 1)
    sizeGlyph:SetPoint("CENTER", 0, 1)

    sizeButton:SetScript("OnEnter", function()
        sizeBg:SetColorTexture(LuckyUI.C.goldAccent[1], LuckyUI.C.goldAccent[2], LuckyUI.C.goldAccent[3], 1)
        GameTooltip:SetOwner(sizeButton, "ANCHOR_BOTTOM")
        GameTooltip:SetText(frame.expanded and S.shrink or S.expand)
        GameTooltip:Show()
    end)
    sizeButton:SetScript("OnLeave", function()
        sizeBg:SetColorTexture(LuckyUI.C.goldMuted[1], LuckyUI.C.goldMuted[2], LuckyUI.C.goldMuted[3], 0.8)
        GameTooltip:Hide()
    end)
    sizeButton:SetScript("OnClick", function() frame:ToggleSize() end)

    function frame:UpdateSizeButton(scale)
        self.expanded = scale > (1 + TUCKED_SCALE) / 2
        sizeGlyph:SetText(self.expanded and "-" or "+")
    end

    -- The window is the same frame at two scales, so a size that covers a whole
    -- number of screen pixels at one covers a fraction of one at the other. An edge
    -- landing mid-pixel is an edge the game may drop, which is the border along the
    -- bottom going missing once the window has tucked itself away. The size it wants
    -- is kept in the panel's own units and laid back onto whole pixels every time
    -- the scale moves.
    function frame:SetWantedSize(width, height)
        self.wantedWidth, self.wantedHeight = width, height
        self:SnapToPixels()
    end

    function frame:SnapToPixels()
        if not self.wantedWidth then return end
        PixelUtil.SetSize(self, self.wantedWidth, self.wantedHeight)
    end

    function frame:PlaceAt(x, y, scale)
        scale = scale or self:GetScale()
        self:SetScale(scale)
        self:SnapToPixels()
        self:ClearAllPoints()
        PixelUtil.SetPoint(self, "TOPLEFT", UIParent, "TOPLEFT", x / scale, y / scale)
        self:UpdateSizeButton(scale)

        -- Rescaling and reanchoring both change what the list has to fill, and it
        -- measures itself as they happen rather than once they have finished. A
        -- glide places the window on every frame, so what it read on the way past is
        -- only worth keeping when the window has come to rest.
        self.remeasure = true
    end

    function frame:GetPlacement()
        local scale = self:GetScale()
        return self:GetLeft() * scale, self:GetTop() * scale - UIParent:GetHeight(), scale
    end

    -- Dragging places the window deliberately, so it ends any glide still running
    -- and the spot chosen becomes where it tucks from then on.
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        self.glide = nil
        self.userPlaced = true
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local x, y = self:GetPlacement()
        db.instanceSetsPosition = { x = x, y = y }
    end)

    function frame:GlideTo(toX, toY, toScale)
        local fromX, fromY, fromScale = self:GetPlacement()
        self.glide = {
            elapsed = 0,
            fromX = fromX, fromY = fromY, fromScale = fromScale,
            toX = toX, toY = toY, toScale = toScale,
        }
    end

    function frame:GlideToTucked()
        local toX, toY = tuckedPosition()
        self:GlideTo(toX, toY, TUCKED_SCALE)
    end

    -- Grows from where it sits rather than recentring, so the window stays where
    -- the player last put it and only gets bigger.
    function frame:ToggleSize()
        local x, y, scale = self:GetPlacement()
        local expanded = scale > (1 + TUCKED_SCALE) / 2

        -- Sizing it by hand is a decision, so the automatic tuck stops second
        -- guessing it for the rest of this visit.
        self.userPlaced = true
        self:GlideTo(x, y, expanded and TUCKED_SCALE or 1)
    end

    -- A frame that is not on screen is not laid out, and the list is filled before
    -- the window is shown. Asked how much room it has, it answers none: it finds
    -- space for no rows at all and a scrollbar for a list said to overflow a window
    -- of no height. Nothing is wrong with the data, only with when it was measured,
    -- so the view is built once more on the first frame after the window is up.
    frame:SetScript("OnShow", function(self) self.remeasure = true end)

    frame:SetScript("OnUpdate", function(self, elapsed)
        if self.remeasure then
            self.remeasure = nil
            self.list:Refresh()
        end

        if next(glowingIcons) then
            glowPhase = glowPhase + elapsed
            local alpha = 0.3 + 0.55 * (0.5 + 0.5 * math.sin(glowPhase * 5))
            for glow in pairs(glowingIcons) do
                glow:SetAlpha(alpha)
            end
        end

        local glide = self.glide
        if not glide then return end

        glide.elapsed = glide.elapsed + elapsed
        local progress = math.min(glide.elapsed / GLIDE_SECONDS, 1)
        local t = ease(progress)
        self:PlaceAt(
            glide.fromX + (glide.toX - glide.fromX) * t,
            glide.fromY + (glide.toY - glide.fromY) * t,
            glide.fromScale + (glide.toScale - glide.fromScale) * t)

        if progress >= 1 then
            self.glide = nil
        end
    end)

    frame.subtitle = frame:CreateFontString(nil, "OVERLAY")
    frame.subtitle:SetFont(LuckyUI.BODY_FONT, 11)
    frame.subtitle:SetTextColor(LuckyUI.C.textMuted[1], LuckyUI.C.textMuted[2], LuckyUI.C.textMuted[3])
    frame.subtitle:SetPoint("TOPLEFT", PADDING, -(HEADER_HEIGHT + 4))
    frame.subtitle:SetPoint("TOPRIGHT", -PADDING, -(HEADER_HEIGHT + 4))
    frame.subtitle:SetJustifyH("LEFT")

    frame.empty = frame:CreateFontString(nil, "OVERLAY")
    frame.empty:SetFont(LuckyUI.BODY_FONT, 12)
    frame.empty:SetTextColor(LuckyUI.C.textMuted[1], LuckyUI.C.textMuted[2], LuckyUI.C.textMuted[3])
    frame.empty:SetPoint("TOPLEFT", PADDING, -(HEADER_HEIGHT + SUBTITLE_HEIGHT))
    frame.empty:SetText(S.nothingHere)
    frame.empty:Hide()

    frame.list = LuckyUI.CreateScrollList(frame, {
        rowHeight = ROW_HEIGHT,
        createRow = createRow,
        updateRow = updateRow,
        onClick = function(match) showSetInJournal(match) end,
    })
    frame.list:SetPoint("TOPLEFT", PADDING, -(HEADER_HEIGHT + SUBTITLE_HEIGHT))

    -- The list always holds a strip of its width clear for the scrollbar. With
    -- everything already on screen that strip is a bare margin down the side, so the
    -- list is let over the panel's right padding by exactly that much and the window
    -- closes up around the icons instead.
    function frame:ReserveScrollbar(reserved)
        self.list:SetPoint("BOTTOMRIGHT", reserved and -PADDING or SCROLLBAR_GUTTER - PADDING, PADDING)
    end
    frame:ReserveScrollbar(true)

    -- A redraw follows every piece looted, so the list is refilled where it stands
    -- rather than snapping back to the top under someone reading the bottom of it.
    function frame:SetMatches(matches)
        local scrolled = self.list.scrollBar:GetValue()
        self.list:SetData(matches)
        self.list.scrollBar:SetValue(scrolled)

        -- The window may have just changed size around this list, and a size arrived
        -- at through anchors is not final until the next frame.
        self.remeasure = true
    end

    tinsert(UISpecialFrames, frame:GetName())
    return frame
end

local function ensurePanel()
    if not panel then
        panel = buildPanel()
    end
    return panel
end

-- An item's name comes from the server, so the first draw after walking in has
-- icons but no names. Asking for the data and redrawing once it lands is what
-- turns a tooltip full of blanks into one worth reading.
local namesPending
local function requestPieceNames(matches)
    if namesPending then return end

    local waiting = false
    for _, match in ipairs(matches) do
        for _, piece in ipairs(match.pieces or {}) do
            if piece.itemID and not piece.name then
                C_Item.RequestLoadItemDataByID(piece.itemID)
                waiting = true
            end
        end
    end

    if not waiting then return end
    namesPending = true
    C_Timer.After(1, function()
        namesPending = false
        if panel and panel:IsShown() then
            SetCompletion:Draw()
        end
    end)
end

--- Rescan the current instance and fill the panel, without showing it.
-- Returns how many sets matched, and nil outside an instance.
function SetCompletion:Draw()
    local instance = self:GetCurrentInstance()
    if not instance then return nil end

    local matches = self:Scan(instance)
    local frame = ensurePanel()

    frame.subtitle:SetText(instance.difficulty
        and ("%s, %s"):format(instance.name, instance.difficulty)
        or instance.name)
    frame.empty:SetShown(#matches == 0)
    layoutPanel(frame, matches)
    requestPieceNames(matches)

    return #matches
end

--- Take account of something that changed what belongs on the list, without
--- waiting to walk into the next instance. A setting about the raid you are
--- standing in gets changed from inside it as often as anywhere else.
function SetCompletion:Refresh()
    self:ForgetWantedPieces()
    if panel and panel:IsShown() then
        self:Draw()
    end
end

--- Redraw for something that changed outside the collection, like the bags. The
--- set data is untouched by that, so only what is on screen is rebuilt.
function SetCompletion:RedrawIfShown()
    if panel and panel:IsShown() then
        self:Draw()
    end
end

--- Draw attention to a piece that has just dropped. Redraws so the panel picks it
--- up, and once more when its moment is over so it settles back down on its own.
function SetCompletion:FlashPiece(sourceID)
    if not sourceID then
        LuckysEnsemble.DevLog("FlashPiece called with no source, nothing to light up")
        return
    end

    flashUntil[sourceID] = GetTime() + FLASH_SECONDS
    if not (panel and panel:IsShown()) then
        LuckysEnsemble.DevLog(("Flagged source %d, but the panel is not open to show it")
            :format(sourceID))
        return
    end

    self:Draw()
    LuckysEnsemble.DevLog(("Flashing source %d for %ds"):format(sourceID, FLASH_SECONDS))

    C_Timer.After(FLASH_SECONDS + 0.1, function()
        if panel and panel:IsShown() then
            self:Draw()
        end
    end)
end

--- Put the window back where it starts, for a drag that left it somewhere it
--- cannot be reached from.
function SetCompletion:ResetPosition()
    db.instanceSetsPosition = {}
    if not panel then return end

    panel.userPlaced = nil
    panel.glide = nil
    local x, y = tuckedPosition()
    panel:PlaceAt(x, y, TUCKED_SCALE)
end

--- Show at reading size, then move aside on its own.
function SetCompletion:ShowExpanded()
    local frame = ensurePanel()
    -- A fresh arrival presents itself afresh, so choices made about the window last
    -- time round do not suppress this one.
    frame.userPlaced = nil

    local dwell = dwellSeconds()
    if dwell <= 0 then
        local x, y = tuckedPosition()
        frame:PlaceAt(x, y, TUCKED_SCALE)
        frame:Show()
        return
    end

    frame:PlaceAt((UIParent:GetWidth() - frame:GetWidth()) / 2,
        -(UIParent:GetHeight() - frame:GetHeight()) / 2, 1)
    frame:Show()

    C_Timer.After(dwell, function()
        -- Anything the player has done since, closing it or dragging it somewhere of
        -- their own, outranks a tidying-away decided seconds ago.
        if frame:IsShown() and not frame.glide and not frame.userPlaced then
            frame:GlideToTucked()
        end
    end)
end

--- Open the panel on demand, wherever the player is.
function SetCompletion:Toggle()
    if panel and panel:IsShown() then
        panel:Hide()
        return
    end

    if not self:Draw() then
        say(LuckysEnsemble.Strings.setTracker.notInInstance)
        return
    end

    -- Asked for by hand, so it opens where it was left rather than taking the screen
    -- and sliding away again.
    local x, y = tuckedPosition()
    panel:PlaceAt(x, y, TUCKED_SCALE)
    panel:Show()
end

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------

-- The instance the panel last opened for, so releasing and running back in doesn't
-- reopen a panel the player has closed.
local shownForInstance
local refreshPending

local function instanceKey(instance)
    return instance and ("%s|%s"):format(instance.name or "", instance.difficulty or "")
end

local function scanOnEntry()
    local instance = SetCompletion:GetCurrentInstance()
    if not instance then
        shownForInstance = nil
        if panel then panel:Hide() end
        return
    end

    if not db.showInstanceSets then
        LuckysEnsemble.DevLog("Instance scan skipped, the setting is off")
        return
    end

    local key = instanceKey(instance)
    if key == shownForInstance then return end

    -- Building the panel is the one part of this that can fail, and a failure must
    -- not be recorded as a successful showing: that would suppress every retry for
    -- as long as the player stayed in the instance.
    local ok, found = pcall(function() return SetCompletion:Draw() or 0 end)
    if not ok then
        geterrorhandler()(("Lucky's Ensemble: instance set list failed. %s"):format(tostring(found)))
        return
    end

    shownForInstance = key
    LuckysEnsemble.DevLog(("Instance scan of %s found %d sets"):format(instance.name, found))
    if found > 0 then
        SetCompletion:ShowExpanded()
    end
end

-- Collecting a piece changes the counts on screen, and clearing an instance fires
-- this many times over, so the redraw waits for the run of them to finish.
local function queueRefresh()
    if refreshPending or not (panel and panel:IsShown()) then return end

    refreshPending = true
    C_Timer.After(1, function()
        refreshPending = false
        if panel:IsShown() then
            SetCompletion:Draw()
        end
    end)
end

--- Do again exactly what walking in does, without walking back out first.
-- Everything that makes an entry a one-off is cleared: the record of having already
-- opened here, and the marks that say the player has since moved or dismissed the
-- window. What came of it is said out loud, because an entry that opens nothing is
-- the answer as often as one that does, and the two look identical from outside.
function SetCompletion:ReplayEntry()
    local S = LuckysEnsemble.Strings.setTracker
    if not self:GetCurrentInstance() then
        say(S.notInInstance)
        return false
    end

    shownForInstance = nil
    if panel then
        panel:Hide()
        panel.glide = nil
        panel.userPlaced = nil
    end

    scanOnEntry()

    local shown = panel ~= nil and panel:IsShown()
    if shown then
        say(S.replayed)
    elseif not db.showInstanceSets then
        say(S.replayedWhileOff)
    else
        say(S.replayedNothing)
    end
    return shown
end

function SetCompletion:Init(database)
    db = database

    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("TRANSMOG_COLLECTION_SOURCE_ADDED")
    events:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_ENTERING_WORLD" then
            -- Set data is rebuilt on load and the loading screen is still up, so the
            -- scan waits for both rather than reading a half-built list.
            C_Timer.After(2, scanOnEntry)
        else
            -- What is missing has changed, so anything derived from it is stale.
            SetCompletion:ForgetWantedPieces()
            queueRefresh()
        end
    end)
end
