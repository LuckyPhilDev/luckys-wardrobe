-- luacheck: globals GetBuildInfo GetNumClasses GetClassInfo

-- Lucky's Wardrobe: the Extra Sets catalogue, built from the set data bundled
-- in src/Data. The client holds all of these sets in its own tables but lists
-- only a fraction of them through C_TransmogSets.GetAllSets, so the snapshot
-- supplies which items belong together and the client supplies everything the
-- collection knows about them.
--
-- Two listings feed it. The armour lists number their sets the way Wowhead
-- does, which is a numbering of its own. The ensemble list numbers its sets the
-- way the client does, because an ensemble item names the set it teaches in the
-- client's own data, which is why far more of what it says can be believed.
-- Neither is taken on trust: the ensembles carry the numbering of the build
-- their snapshot was taken from, not of the build being played, and a set that
-- moved between the two would be renamed and refiled without complaint.
--
-- Building a record means turning each item ID into the appearance source the
-- collection actually tracks. A piece this client cannot answer for is counted,
-- never guessed at, and a set with no resolvable piece at all is left out with
-- its reason kept in the session report. Nothing built here is persisted.
LuckysWardrobe = LuckysWardrobe or {}
LuckysWardrobe.ExtraSetsCatalog = {}

local Catalog = LuckysWardrobe.ExtraSetsCatalog

-- Each set asks the client about every one of its items, so the work is paced
-- to keep a frame's share of it small: the whole catalogue lands in a couple of
-- seconds, which is faster than a player can open Collections and reach the tab.
--
-- The pacing counts pieces rather than sets because sets are nothing like the
-- same size: a tier is nine pieces and an ensemble can teach over a hundred, so
-- a fixed number of sets would make one frame twenty times the work of another.
-- A set is never split across frames, so a step can overrun by one large set.
local PIECES_PER_STEP = 400
local MAX_VERBOSE_LINES = 40

local ARMOUR_SLOTS = {
    INVTYPE_HEAD = "HEAD",
    INVTYPE_SHOULDER = "SHOULDER",
    INVTYPE_CLOAK = "BACK",
    INVTYPE_CHEST = "CHEST",
    INVTYPE_ROBE = "CHEST",
    INVTYPE_BODY = "BODY",
    INVTYPE_TABARD = "TABARD",
    INVTYPE_WRIST = "WRIST",
    INVTYPE_HAND = "HANDS",
    INVTYPE_WAIST = "WAIST",
    INVTYPE_LEGS = "LEGS",
    INVTYPE_FEET = "FEET",
}

-- Records leave here already ordered, so nothing downstream has to know what a
-- slot means.
local SLOT_ORDER = LuckysWardrobe.Utils.ARMOUR_SLOTS

-- The armour a class wears, as the client's own armour subclass IDs. The rest
-- of that enum is armour nobody wears as an armour type: tabards and shirts
-- under miscellaneous, and the cosmetic pieces that go with anything.
local WEARABLE_ARMOUR = { [1] = true, [2] = true, [3] = true, [4] = true }

local REJECT = {
    unresolvable = "no piece this client can resolve",
}

local stepFrame = CreateFrame("Frame")
local state
local records
local report
local readyCallbacks = {}

local function reject(setID, name, category)
    report.rejections[#report.rejections + 1] = { setID = setID, name = name, category = category }
end

-- The class filter narrows GetAllSets, so the official snapshot has to union
-- every class. The mutation is save, loop, restore inside one call, which the
-- UI never observes between frames. Names are kept so a set Blizzard already
-- lists can be told apart from one only the bundled data names, and the classes
-- it turned up under are kept as a mask: the Sets tab shows a set only under
-- those, which is the only place it can be a duplicate.
local function snapshotOfficialSets()
    local Classes = LuckysWardrobe.Classes
    local names, classMasks = {}, {}
    local savedFilter = C_TransmogSets.GetTransmogSetsClassFilter()
    for classID = 1, GetNumClasses() do
        C_TransmogSets.SetTransmogSetsClassFilter(classID)
        for _, set in ipairs(C_TransmogSets.GetAllSets() or {}) do
            names[set.setID] = set.name or ""
            local mask = classMasks[set.setID] or 0
            if not Classes:MaskHas(mask, classID) then
                classMasks[set.setID] = mask + 2 ^ (classID - 1)
            end
        end
    end
    C_TransmogSets.SetTransmogSetsClassFilter(savedFilter)
    return names, classMasks
end

-- The collection tracks appearance sources, not items, so an item ID is only
-- useful once the client has named the source behind it. A piece the client
-- answers for but the page never shows, a weapon or a ring, comes back empty; a
-- piece this client holds no data for at all comes back empty and flagged, so a
-- set can say how much of itself this build is missing.
local function resolveItem(itemID)
    local equipLoc, _, classID, subclassID = select(4, C_Item.GetItemInfoInstant(itemID))
    if not equipLoc then return nil, true end

    local slot = ARMOUR_SLOTS[equipLoc]
    if not slot then return nil end

    local _, sourceID = C_TransmogCollection.GetItemInfo(itemID)
    if not sourceID then return nil, true end

    local piece = { slot = slot, sourceID = sourceID, itemID = itemID }
    -- Which armour this piece is, for the listing that does not say. Only the
    -- four kinds a class wears can answer that: a cloak is cloth whoever wears
    -- it, and a tabard, shirt, or cosmetic piece is nobody's armour at all, so
    -- neither says who the set around it is for.
    if slot ~= "BACK" and classID == Enum.ItemClass.Armor and WEARABLE_ARMOUR[subclassID] then
        piece.armour = subclassID
    end
    return piece
end

-- The armour a set is, read off the pieces for the listing that does not say
-- it: whichever kind most of them are. A tie goes to the lower ID so the answer
-- is the same on every client. A set of nothing but cloaks, tabards, shirts,
-- and cosmetics is nobody's armour in particular, which zero says.
local function dominantArmour(counts)
    local kind, most
    for armour, count in pairs(counts) do
        if not most or count > most or (count == most and armour < kind) then
            kind, most = armour, count
        end
    end
    return kind or 0
end

-- Pieces come out in slot order, keeping the snapshot's order within a slot so
-- a set carrying both a chest and a robe shows them the way Wowhead lists them.
local function buildPieces(itemIDs)
    local bySlot, unresolved, seenSources, armourCounts = {}, 0, {}, {}
    for _, itemID in ipairs(itemIDs) do
        local piece, unknown = resolveItem(itemID)
        if unknown then
            unresolved = unresolved + 1
        elseif piece and not seenSources[piece.sourceID] then
            seenSources[piece.sourceID] = true
            bySlot[piece.slot] = bySlot[piece.slot] or {}
            table.insert(bySlot[piece.slot], piece)
            if piece.armour then
                armourCounts[piece.armour] = (armourCounts[piece.armour] or 0) + 1
            end
        end
    end

    local pieces = {}
    for _, slot in ipairs(SLOT_ORDER) do
        for _, piece in ipairs(bySlot[slot] or {}) do
            pieces[#pieces + 1] = piece
        end
    end
    return pieces, unresolved, dominantArmour(armourCounts)
end

-- Whether the set the client holds under an ID is the set the snapshot holds
-- under it. The snapshot numbers its sets the way Wowhead does and the client
-- numbers its own, and the two do not agree: a set the snapshot calls 513 can
-- be an entirely different set on the client. Believing the client about a set
-- that is not the same one renames it, refiles it under another class, and
-- dates it to another expansion, all without a word of complaint.
--
-- Sources settle it, and settle it without language in the comparison, so a
-- localised client answers the same as an English one. The client lists only
-- the pieces it counts towards the set while the snapshot carries the off-set
-- pieces too, so its list is expected to be the smaller: agreement on most of
-- what the client does list is what identity looks like.
function Catalog.SameSet(pieces, clientSourceIDs)
    if not clientSourceIDs or #clientSourceIDs == 0 then return false end

    local held = {}
    for _, piece in ipairs(pieces) do held[piece.sourceID] = true end

    local matched = 0
    for _, sourceID in ipairs(clientSourceIDs) do
        if held[sourceID] then matched = matched + 1 end
    end
    return matched * 2 >= #clientSourceIDs
end

-- armorType is what the listing says the set is, and nil for the one that does
-- not say: an ensemble record takes the armour its own pieces are.
local function buildRecord(setID, set, armorType)
    local pieces, unresolved, pieceArmour = buildPieces(set.pieces)
    if #pieces == 0 then
        return reject(setID, set.name, REJECT.unresolvable)
    end

    report.unresolvedPieces = report.unresolvedPieces + unresolved
    -- Where the client knows the same set it is the authority: it names it in
    -- the player's own language and says who may wear it and which expansion it
    -- belongs to. The snapshot only fills the gaps. None of this changes while
    -- a session runs, so it is read here rather than every time the page does.
    local info = C_TransmogSets.GetSetInfo(setID)
    -- Every listing is checked, the ensembles included. Their numbering is the
    -- client's own rather than Wowhead's, which is why they can be believed
    -- about far more than the armour lists, but it is the numbering of the
    -- build the snapshot was taken from and not of the build being played. A
    -- set that has moved between the two is a set the client would rename,
    -- refile, and redate without a word of complaint.
    if info and not Catalog.SameSet(pieces, C_TransmogSets.GetAllSourceIDs(setID)) then
        report.identityMismatches = report.identityMismatches + 1
        LuckysWardrobe.DevLog("Extra Sets: client set " .. setID .. " (" .. tostring(info.name)
            .. ") is not the snapshot's " .. tostring(set.name) .. "; keeping the snapshot's own.")
        info = nil
    end
    -- Sharing a number with a set the Sets tab lists is not appearing in the
    -- Sets tab, so only a set the client agrees is this one can be a duplicate.
    -- That settles both what the page drops and how much of the bundled list a
    -- player can already see without it.
    local officialClassMask = info and report.officialClasses[setID]
    if officialClassMask then
        report.alsoOfficial = report.alsoOfficial + 1
    end
    if set.ensembles then
        report.fromEnsembles = report.fromEnsembles + 1
    end
    records[#records + 1] = {
        setID = setID,
        name = (info and info.name ~= "" and info.name) or set.name,
        armorType = armorType or pieceArmour,
        classMask = info and info.classMask or set.classMask,
        expansionID = info and info.expansionID,
        label = info and info.label,
        pieces = pieces,
        unresolvedPieces = unresolved,
        -- Which classes' Sets tab already lists this set, so the page can drop
        -- the ones it would otherwise show a second time.
        officialClassMask = officialClassMask,
        -- The ensembles that teach this set, as item IDs. The client names each
        -- of them in the player's own language, so only the numbers are bundled.
        ensembles = set.ensembles,
    }
end

-- Sharing a number with a listed set is one way to duplicate the Sets tab;
-- wearing its looks under another name is the other. Wowhead lists "Recolor"
-- and "Lookalike" sets for the off-set items that share a tier's appearances,
-- and those appearances are already on the Sets tab under the tier itself, so
-- the page folds such sets away by looks. These are the looks it folds
-- against: every set the tab lists the class, difficulty variants included,
-- as the appearances the client counts towards each.
--
-- Built the first time a class is asked about and kept for the session: which
-- sets the tab lists, and which looks they hold, do not change while a client
-- runs. Collected state changes, but it plays no part here.
local officialLooks

function Catalog:OfficialLooks(classID)
    if not report then return {} end

    officialLooks = officialLooks or {}
    local classKey = classID or 0
    if officialLooks[classKey] then return officialLooks[classKey] end

    local looks, seen = {}, {}
    local function add(setID, name)
        if seen[setID] then return end
        seen[setID] = true
        local appearances = {}
        for _, appearance in ipairs(C_TransmogSets.GetSetPrimaryAppearances(setID) or {}) do
            if appearance.appearanceID then appearances[appearance.appearanceID] = true end
        end
        -- A set the client answers no looks for cannot fold anything.
        if next(appearances) then
            looks[#looks + 1] = { setID = setID, name = name or "", appearances = appearances }
        end
    end

    -- The mask keys come out of a hash table, so they are walked in a fixed
    -- order and the result is the same list every time it is built.
    local setIDs = {}
    for setID in pairs(report.officialClasses) do setIDs[#setIDs + 1] = setID end
    table.sort(setIDs)

    for _, setID in ipairs(setIDs) do
        if not classID or LuckysWardrobe.Classes:MaskHas(report.officialClasses[setID], classID) then
            add(setID, report.official[setID])
            -- The tab offers a set's difficulties through a dropdown rather
            -- than as rows of their own, so a variant is as listed as its set.
            -- A variant's own name is often blank; the set's stands in.
            for _, variant in ipairs(C_TransmogSets.GetVariantSets(setID) or {}) do
                local name = variant.name
                add(variant.setID, (name and name ~= "" and name) or report.official[setID])
            end
        end
    end

    officialLooks[classKey] = looks
    return looks
end

-- Set IDs are the keys of a hash table, so a group fixes an order once and the
-- stepper walks it across frames from there.
local function workGroup(sets, armorType)
    local setIDs = {}
    for setID in pairs(sets or {}) do setIDs[#setIDs + 1] = setID end
    table.sort(setIDs)
    return { sets = sets or {}, armorType = armorType, setIDs = setIDs }
end

-- The ensembles are walked last, so where an ensemble teaches a look one of the
-- armour lists already carries, the armour list keeps the row and the ensemble
-- joins it as another name for the same set rather than displacing it.
local function workList()
    local work = {}
    for _, armour in ipairs(LuckysWardrobe.ExtraSetsData.armorTypes) do
        work[#work + 1] = workGroup(LuckysWardrobe.ExtraSetsData.sets[armour.key], armour.armorType)
    end
    work[#work + 1] = workGroup(LuckysWardrobe.ExtraSetsData.ensembles)
    return work
end

local function finalize()
    state = nil
    stepFrame:SetScript("OnUpdate", nil)

    LuckysWardrobe.DevLog("Extra Sets catalogue built: " .. #records .. " set(s), "
        .. #report.rejections .. " left out.")
    for _, callback in ipairs(readyCallbacks) do callback() end
    readyCallbacks = {}
end

local function stepWork()
    local budget = PIECES_PER_STEP
    while budget > 0 do
        local group = state.work[state.groupIndex]
        if not group then return finalize() end

        state.cursor = state.cursor + 1
        local setID = group.setIDs[state.cursor]
        if not setID then
            state.groupIndex = state.groupIndex + 1
            state.cursor = 0
        else
            local set = group.sets[setID]
            budget = budget - #set.pieces
            buildRecord(setID, set, group.armorType)
        end
    end
end

-- The build is the one thing here that runs on every frame for a while, so how
-- much of a frame a step takes is worth knowing on any client, not just a fast one.
local function step()
    LuckysWardrobe.Perf:Begin("catalogue step")
    stepWork()
    LuckysWardrobe.Perf:End("catalogue step")
end

function Catalog:StartBuild()
    if records or state then return end

    local version, buildNumber = GetBuildInfo()
    records = {}
    officialLooks = nil
    report = {
        snapshot = LuckysWardrobe.ExtraSetsData.snapshot,
        build = version .. "." .. buildNumber,
        alsoOfficial = 0,
        fromEnsembles = 0,
        identityMismatches = 0,
        unresolvedPieces = 0,
        rejections = {},
    }
    report.official, report.officialClasses = snapshotOfficialSets()
    state = { work = workList(), groupIndex = 1, cursor = 0 }
    stepFrame:SetScript("OnUpdate", step)
end

-- The catalogue is no longer only the Extra Sets tab's: item tooltips ask it which
-- set a piece belongs to wherever the player is standing, and waiting for someone
-- to open Collections would leave them silent for a whole session's play. Built at
-- the first entry into the world rather than at load, so the client has its item
-- data to answer with.
function Catalog:Init()
    local entering = CreateFrame("Frame")
    entering:RegisterEvent("PLAYER_ENTERING_WORLD")
    entering:SetScript("OnEvent", function()
        entering:UnregisterEvent("PLAYER_ENTERING_WORLD")
        Catalog:StartBuild()
    end)
end

-- Discards the session catalogue and builds it again. Dev and test hook.
function Catalog:Rebuild()
    records = nil
    if state then
        state = nil
        stepFrame:SetScript("OnUpdate", nil)
    end
    self:StartBuild()
end

function Catalog:IsReady()
    return records ~= nil and state == nil
end

function Catalog:GetRecords()
    if not self:IsReady() then return {} end
    return records
end

function Catalog:GetReport()
    return report
end

-- Groups this session's left-out sets by reason, most common first, with a
-- stable order for equal counts.
function Catalog:SummarizeRejections()
    local counts, categories = {}, {}
    for _, rejection in ipairs(report and report.rejections or {}) do
        if counts[rejection.category] == nil then
            counts[rejection.category] = 0
            categories[#categories + 1] = rejection.category
        end
        counts[rejection.category] = counts[rejection.category] + 1
    end

    table.sort(categories, function(left, right)
        if counts[left] ~= counts[right] then return counts[left] > counts[right] end
        return left < right
    end)

    local summary = {}
    for index, category in ipairs(categories) do
        summary[index] = { category = category, count = counts[category] }
    end
    return summary
end

function Catalog:PrintReport(verbose)
    local S = LuckysWardrobe.Strings.extraSets.report
    local say = LuckysWardrobe.Utils.Say

    if not report then
        say(S.notStarted)
        return
    end
    if not self:IsReady() then
        say(S.building)
        return
    end

    local total = #records + #report.rejections
    say(S.header:format(report.snapshot, report.build, #records, total))

    -- The catalogue spans every class, while the tab shows one class at a time.
    -- Counting the page's own entries keeps the report and the page from ever
    -- disagreeing about how much of it this character sees.
    local shown = LuckysWardrobe.ExtraSets.Entries()
    say(S.shownLine:format(#shown))
    say(S.foldedLine:format(LuckysWardrobe.ExtraSets.FoldedCount(shown)))
    say(S.nativeFoldedLine:format(#LuckysWardrobe.ExtraSets.NativeFolds()))
    say(S.officialLine:format(report.alsoOfficial))
    say(S.ensembleLine:format(report.fromEnsembles))
    if report.identityMismatches > 0 then
        say(S.mismatchLine:format(report.identityMismatches))
    end
    if report.unresolvedPieces > 0 then
        say(S.unresolvedLine:format(report.unresolvedPieces))
    end
    for _, group in ipairs(self:SummarizeRejections()) do
        say(S.groupLine:format(group.category, group.count))
    end

    if not verbose then
        say(S.hint)
        return
    end

    say(S.includedHeader:format(#records))
    for index, record in ipairs(records) do
        if index > MAX_VERBOSE_LINES then
            say(S.andMore:format(#records - MAX_VERBOSE_LINES))
            break
        end
        say(S.recordLine:format(record.setID, record.name, #record.pieces))
    end
    say(S.rejectedHeader:format(#report.rejections))
    for index, rejection in ipairs(report.rejections) do
        if index > MAX_VERBOSE_LINES then
            say(S.andMore:format(#report.rejections - MAX_VERBOSE_LINES))
            break
        end
        say(S.rejectionLine:format(rejection.setID, rejection.name, rejection.category))
    end
end

-- Every set whose name contains the query: listed, folded behind a look the
-- Sets tab already shows, left out by a rule, or one Blizzard lists natively.
-- A set Blizzard lists is never also reported as listed here, because the page
-- drops it for the class it duplicates. The folds are the page's, so they
-- speak for the class it last built its list for.
function Catalog:FindCandidates(query)
    local normalized = (query or ""):lower()
    local foldsBySetID = {}
    for _, fold in ipairs(LuckysWardrobe.ExtraSets.NativeFolds()) do
        foldsBySetID[fold.setID] = fold
    end
    local listed, dropped, native, folded = {}, {}, {}, {}
    for _, record in ipairs(records or {}) do
        if not record.officialClassMask and record.name:lower():find(normalized, 1, true) then
            local fold = foldsBySetID[record.setID]
            if fold then
                folded[#folded + 1] = fold
            else
                listed[#listed + 1] = record
            end
        end
    end
    for _, rejection in ipairs(report and report.rejections or {}) do
        if rejection.name and rejection.name:lower():find(normalized, 1, true) then
            dropped[#dropped + 1] = rejection
        end
    end
    for setID, name in pairs(report and report.official or {}) do
        if name ~= "" and name:lower():find(normalized, 1, true) then
            native[#native + 1] = { setID = setID, name = name }
        end
    end
    table.sort(native, function(left, right) return left.setID < right.setID end)
    return listed, dropped, native, folded
end

function Catalog:PrintMatches(query)
    local S = LuckysWardrobe.Strings.extraSets.report
    local say = LuckysWardrobe.Utils.Say

    if not report then
        say(S.notStarted)
        return
    end
    if not self:IsReady() then
        say(S.building)
        return
    end

    -- The folds belong to the page's last build, so the page reads its
    -- entries first and the answer is about the class it is showing now.
    LuckysWardrobe.ExtraSets.Entries()
    local listed, dropped, native, folded = self:FindCandidates(query)
    if #listed == 0 and #dropped == 0 and #native == 0 and #folded == 0 then
        say(S.findNone:format(query))
        return
    end

    say(S.findHeader:format(query))
    for _, record in ipairs(listed) do
        say(S.foundListed:format(record.setID, record.name, #record.pieces))
    end
    for _, fold in ipairs(folded) do
        say(S.foundFolded:format(fold.nativeName, fold.setID, fold.name))
    end
    for _, rejection in ipairs(dropped) do
        say(S.foundDropped:format(rejection.setID, rejection.name, rejection.category))
    end
    -- The Sets tab filters to one class at a time and opens on the player's own,
    -- so saying a set is listed there is misleading on a character that cannot
    -- see it. Name the class filter it sits behind instead.
    for _, set in ipairs(native) do
        local classID = C_TransmogSets.GetValidClassForSet(set.setID)
        local className = classID and GetClassInfo(classID)
        if className then
            say(S.foundNativeClass:format(className, set.setID, set.name))
        else
            say(S.foundNative:format(set.setID, set.name))
        end
    end
end

-- Runs the callback once the catalogue exists, immediately when it already does.
function Catalog:OnReady(callback)
    if self:IsReady() then
        callback()
    else
        readyCallbacks[#readyCallbacks + 1] = callback
    end
end
