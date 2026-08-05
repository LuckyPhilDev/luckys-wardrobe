-- luacheck: globals BINDING_HEADER_LUCKYSWARDROBE BINDING_NAME_LUCKYSWARDROBE_TOGGLE_SET_LIST

-- Lucky's Wardrobe: User-facing strings.
LuckysWardrobe = LuckysWardrobe or {}

-- The keybinding UI reads these out of the global namespace by name, so they have
-- to be globals rather than entries in the table below.
BINDING_HEADER_LUCKYSWARDROBE = "Lucky's Wardrobe"
BINDING_NAME_LUCKYSWARDROBE_TOGGLE_SET_LIST = "Sets You Can Finish Here"

LuckysWardrobe.Strings = {
    addon = {
        title = "Lucky's Wardrobe",
        prefix = "|cffc8902aLucky's Wardrobe:|r",
        initialized = "Initialized.",
    },
    minimap = {
        shiftClick = "Shift-click: Sets you can finish here",
        rightClick = "Right-click: Open settings",
        drag = "Drag: Move button",
    },
    addonConflicts = {
        title = "Addon Conflict",
        betterWardrobe = "Better Wardrobe",
        luckysBetterWardrobe = "Lucky's Better Wardrobe",
        oneEnabled = "%s is also enabled.",
        bothEnabled = "%s and %s are also enabled.",
        explain = "They change the same collection and transmog windows Lucky's Wardrobe does, so running them together causes errors. Which would you like to disable?",
        oldFolder = "Lucky's Wardrobe replaced Lucky's Better Wardrobe, and the update left the old folder behind. Delete Interface\\AddOns\\LuckysBetterWardrobe to be rid of it for good.",
        reloadHint = "(Disabling reloads your interface)",
        disableOne = "Disable %s",
        disableBoth = "Disable Both",
        disableSelf = "Disable Lucky's Wardrobe",
    },
    welcome = {
        title = "Welcome to Lucky's Wardrobe",
        headline = "Lucky's Wardrobe is a brand new addon, written from the ground up.",
        body = "It is early days, so new features are still being added and bugs are still being found.",
        ask = "If something is broken, or there is a feature you want, come and say Hi on the Discord. It is the easiest way to reach me, and it is where we keep track of what to build next.",
        linkLabel = "Discord",
        discordURL = "https://discord.gg/ptTtYyAjdZ",
        copyHint = "Click the address, then press Ctrl+C to copy it.",
        signoff = "And most of all, enjoy!",
        close = "Close",
        reset = "The welcome note is owed again. It arrives a moment after your next login.",
    },
    settings = {
        groups = {
            general = "General",
            appearances = "Appearances",
            tooltips = "Tooltips",
            transmog = "Transmog",
            setTracker = "Set Tracker",
        },
        sections = {
            whatToTrack = "What to Track",
            inInstances = "In Dungeons and Raids",
            whenYouLoot = "When You Loot",
        },
        catalystMissing = "The catalyst options below are turned off because Transmog Upgrade Master is not installed. It is the only way to know what the catalyst would turn an item into.",
        maxMissing = {
            label = "Pieces Missing At Most",
            desc = "How incomplete a set can be and still count as one you are close to finishing. At 3, a set you are missing four or more pieces of is left out of the instance list and never alerts.",
        },
        includeCurrentTier = {
            label = "Include the Current Tier",
            desc = "Sets from the tier you are raiding now are left out, on the grounds that you will finish those by turning up. Turn this on to hear about them anyway. Older sets you have gone back for are never affected.",
        },
        includeOtherClassSets = {
            label = "Include Other Classes' Sets",
            desc = "Sets this character cannot wear are left out, since you cannot finish one here on this character. Turn this on to see them anyway, which tells you whether a raid is worth a trip on an alt. A raid holds a set for every class, so this makes the list a good deal longer.",
        },
        setClasses = {
            label = "Classes to Include",
            desc = "Which other classes' sets to list. Leave them all on to see every class, or pick out the alts you actually collect for.",
        },
        markCatalysable = {
            label = "Mark Pieces You Could Catalyse",
            desc = "Stamps a catalyst mark on a piece you are missing when you are already carrying something the catalyst would turn into it. Hover the piece to see which item.",
        },
        showInstanceSets = {
            label = "Open the List Automatically",
            desc = "Opens a list when you enter a dungeon or raid of the sets you are close to completing whose missing pieces drop there. Type /wardrobe sets or use a keybinding to open it any time, whether this is on or off.",
        },
        dwellSeconds = {
            label = "Move Aside After",
            desc = "How long the list holds the middle of the screen before it shrinks into the corner. At 0 it opens in the corner and never takes the middle.",
        },
        resetPosition = {
            label = "Reset Window Position",
            desc = "Puts the list back in the top-left corner, for a drag that left it somewhere you cannot reach.",
        },
        alertSetPiece = {
            label = "Alert on Set Pieces",
            desc = "Speaks up when you loot a piece of a set you are close to finishing, wherever you are.",
        },
        alertCatalyst = {
            label = "Alert on Catalyst Upgrades",
            desc = "Speaks up, more quietly, when you loot something the catalyst could turn into an appearance you are missing.",
        },
        alertWith = {
            label = "Alert With",
            desc = "How an alert reaches you. A long clear puts a lot of lines in chat, and the sound alone carries just as well.",
            sound = "Sound",
            chat = "Chat message",
        },
        devMode = {
            label = "Dev Mode",
            desc = "Shows detailed diagnostics in chat while features are developed.",
            enabled = "Dev mode enabled.",
        },
        trackSets = {
            label = "Track on Shift-Click",
            desc = "Shift-click a set to track every appearance you are still missing from it, or shift-click one of its pieces to track just that one and shift-click it again to stop. Works in Blizzard's Sets tab, in the Extra Sets tab, and on the Extra Sets cards at the transmogrifier.",
        },
        markTracked = {
            label = "Mark Tracked Pieces",
            desc = "Puts a crosshair on the corner of the pieces you are tracking when you open a set, in the Sets tab and the Extra Sets tab, so a set says which of its pieces you are out hunting for. Hover a marked piece and its tooltip says so too.",
        },
        wowheadLink = {
            label = "Wowhead Address on Ctrl-Click",
            desc = "Ctrl-click an item anywhere in your appearance collection to bring up its Wowhead address, ready to copy. This takes ctrl-click off the dressing room preview.",
        },
        tooltipSetProgress = {
            label = "Show Set Information",
            desc = "Adds a line to an item's tooltip naming the set it belongs to and how much of that set you have, so a drop says what it is worth at a glance. Example: \"From set: Glyphed Garb 7/8\"",
        },
        keepTransmogTab = {
            label = "Keep Active Transmog Tab",
            desc = "Keeps whichever tab you're on when switching outfits at the transmog NPC, instead of jumping back to Items. Clicking a slot still opens Items.",
        },
        hideUnwearableSets = {
            label = "Hide Sets You Cannot Wear",
            desc = "The Sets tab at the transmog NPC lists a set the moment one piece of it would fit, and a cloak fits anybody, so it fills up with armour this character cannot wear. Sets in your own armour type are kept whichever class they were built for. Turn this off to browse the lot again.",
        },
        showSetNames = {
            label = "Show Set Names",
            desc = "Names every set card at the transmogrifier, on the Sets, Custom Sets and Extra Sets tabs, so you can tell one little model from another without hovering each in turn.",
        },
        showSituationValues = {
            label = "Show Situation Values",
            desc = "Shows the selected situation values on outfit entries instead of just the category names.",
        },
        showSituationTooltips = {
            label = "Show Situation Tooltips",
            desc = "Shows an outfit's full situation list, with the values selected in each category, in a tooltip when you hover it.",
        },
        version = {
            section = "Version Info",
            addon = "Lucky's Wardrobe",
            utils = "Lucky's Utils",
        },
    },
    randomiser = {
        tooltipTitle = "Roll a Random Outfit",
        tooltipText = "Hold to spin every armour slot through appearances you own, then let go and watch it slow to a stop. Weapons are left alone, and nothing is bought until you press Apply.",
    },
    situationLabels = {
        scanTitle = "Reading Outfit Situations",
        scanMessage = "Each outfit is being opened to read its situation values. Please wait, using the wardrobe now will interrupt the scan.",
        scanCount = "%d of %d outfits",
    },
    situationPresets = {
        save = "Save Current Situation",
        saveDialog = "Save Situation",
        load = "Load Situation",
        replaceDialog = "A saved situation named \"%s\" already exists. Replace it?",
        deleteTooltip = "Delete Saved Situation",
        deleteDialog = "Delete saved situation \"%s\"? This cannot be undone.",
    },
    wowheadLink = {
        dialog = "Press Ctrl+C to copy this address, then paste it into your browser.",
    },
    tooltips = {
        -- The set's name and its count, each coloured in its own right, so the
        -- label stays quiet and the answer stands out.
        setLine = "From set: %s %s",
        setProgress = "%d/%d",
    },
    tracking = {
        hovered = "You are tracking this appearance.",
        hint = "Shift-click to track this appearance.",
        stopHint = "Shift-click to stop tracking it.",
        stopped = "Stopped tracking an appearance from %s.",
        tracked = "Tracking %d missing appearance(s) from %s.",
        failed = "%d could not be tracked.",
        nothing = "Nothing new to track from %s.",
    },
    setTracker = {
        title = "Finish a Set Here",
        nothingHere = "Nothing here finishes a set.",
        notInInstance = "You are not in a dungeon or raid.",
        replayed = "Opened the list as if you had just walked in.",
        replayedNothing = "Nothing here finishes a set, so walking in would open nothing.",
        replayedWhileOff = "Open the List Automatically is off, so walking in would open nothing.",
        expand = "Expand the window",
        shrink = "Shrink the window",
        andMore = "and %d more",
        dropsFrom = "Drops from",
        dropsOn = "Drops on %s",
        comesFromHere = "Comes from this instance",
        catalystWouldMake = "The catalyst would make this from",
        collectedOf = "Collected: %d of %d",
        stillMissing = "Still missing %d pieces from elsewhere",
        couldCatalyse = "%d you could catalyse from what you are carrying",
        clickToShow = "Click: Show this set in your appearances",
        lootFinishes = "%s finishes %s",
        lootPieceOf = "%s is a piece of %s, %d still missing",
        lootCatalysable = "%s can be catalysed into an appearance you are missing",
    },
    setNames = {
        filter = "Show Set Names",
    },
    -- Shared by both filter menus, the Sets tab's and the Extra Sets tab's, so
    -- the same choice reads the same on either. The game supplies the rest of
    -- what these menus say, Collected and Default among them.
    filterMenu = {
        sortBy = "Sort By",
        sortDirection = "Sort Direction",
        ascending = "Ascending",
        descending = "Descending",
        expansion = "Expansion",
        source = "Source",
        byName = "Name",
        byCompletion = "Completion",
        byPieces = "Pieces",
        byVariants = "Variants",
    },
    -- Where the bundled snapshot says a set comes from. These are the Extra Sets
    -- page's own, and separate from setSources below, which reads a category off
    -- the sets Blizzard lists natively.
    snapshotSources = {
        crafted = "Crafted",
        drop = "Drop",
        pvp = "PvP",
        quest = "Quest",
        vendor = "Vendor",
    },
    setSources = {
        raid = "Raid",
        pvp = "PvP",
        covenants = "Covenants",
        heritage = "Heritage",
        cosmetic = "Cosmetic",
        tradingPost = "Trading Post",
        miscellaneous = "Miscellaneous",
    },
    extraSets = {
        tab = "Extra Sets",
        building = "Reading the extra sets from this client...",
        empty = "No extra sets could be read from this client.",
        noResults = "No extra sets match the current search or filters.",
        select = "Select a set to preview it.",
        loading = "Loading appearance data...",
        counts = "%d/%d collected",
        colours = "%d colours",
        variantOption = "%s (%d/%d)",
        alsoListed = "Also listed as %s",
        -- The client names the ensemble item itself, and every one of them is
        -- called "Ensemble: <the set>", so the line reads as a sentence.
        ensembleSource = "From %s",
        -- What a player types to list everything there is an ensemble for.
        ensembleTerm = "Ensemble",
        piecesNotShown = "...and %d more piece(s)",
        progress = "%d / %d",
        pieceUnavailable = "This piece is not available on this client build.",
        pieceUnavailableShort = "Pieces unavailable",
        unavailableNotice = "%d piece(s) in this set are not available on this client build.",
        nothingToApply = "You have not collected any of this set's pieces yet.",
        nothingApplied = "None of this set's pieces could be applied to what you are wearing.",
        wowheadMenu = "Link on Wowhead",
        notUsable = "This set is not one your character can wear.",
        notUsableClass = "This set is not one your character can wear. It belongs to %s.",
        notUsableArmour = "This set is not one your character can wear. It is a %s set, and your character wears %s.",
        notUsableFaction = "This set is not one your character can wear. It belongs to the %s.",
        notUsableRace = "This set is not one your character can wear. It belongs to another race.",
        -- The client's own sentence for a refusal it does not otherwise explain,
        -- which is more than the page could say for itself.
        notUsableReason = "This set is not one your character can wear. %s",
        -- Indexed by the client's own armour subclass ID, as the sets themselves
        -- are, and written to read inside a sentence rather than as a heading.
        armourTypes = { "cloth", "leather", "mail", "plate" },
        report = {
            notStarted = "The Extra Sets catalogue has not been built yet. Open Collections, Appearances first.",
            building = "The Extra Sets catalogue is still building. Try again in a moment.",
            header = "Extra Sets from the %s set list on client %s: %d of %d set(s) listed.",
            shownLine = "  shown for this character's class: %d",
            foldedLine = "  folded into another row as the same look: %d",
            nativeFoldedLine = "  hidden as looks the Sets tab already shows this class: %d",
            officialLine = "  hidden as Blizzard's own Sets tab lists them: %d",
            ensembleLine = "  set(s) an ensemble teaches: %d",
            mismatchLine = "  set(s) this client numbers differently, kept as the bundled list has them: %d",
            unresolvedLine = "  piece(s) this client has no appearance for: %d",
            groupLine = "  %s: %d",
            hint = "Use /wardrobe extrasets full to list everything, /wardrobe extrasets find <name> to look one up, /wardrobe extrasets looks <name> to compare a set's appearance IDs with the Sets tab's, /wardrobe extrasets variants <name> to ask the client which sets it already calls colourways of one another, /wardrobe extrasets colours to read every family grouped as one garment in several colours, or /wardrobe extrasets pieces to read the selected set piece by piece.",
            piecesNoSelection = "Select a set in the Extra Sets tab first, then run this again.",
            piecesHeader = "Set %d: %s: %s",
            piecesWearable = "this character can wear it",
            pieceLine = "  %s: %s, source %d, item %s, item data %s, in wardrobe %s, usable %s",
            pieceUseErrorLine = "    the client's own reason: %s",
            pieceNoItem = "none",
            pieceYes = "yes",
            pieceNo = "no",
            pieceUnanswered = "not answered",
            findHeader = "Extra Sets matching \"%s\":",
            findNone = "No set named like \"%s\" is in the bundled list or this client's own Sets tab.",
            coloursHeader = "Sets grouped as one garment in several colours (%d family(ies)):",
            coloursLine = "  %s: %d colours of %d piece(s): %s",
            coloursTotal = "  %d set(s) folded into %d row(s).",
            coloursNone = "No sets were grouped as colours of one another.",
            variantsHeader = "What this client calls a colourway among sets matching \"%s\":",
            variantLine = "  set %d: %s: base set %s, variants %s",
            variantNoBase = "none",
            variantNone = "none",
            looksHeader = "Looks behind sets matching \"%s\":",
            lookLine = "  set %d: %s: %s",
            lookNativeLine = "  Sets tab set %d: %s: %s",
            lookUnresolved = "nothing resolved yet",
            foundListed = "  listed: set %d: %s (%d pieces)",
            foundFolded = "  hidden behind the Sets tab's %s: set %d: %s",
            foundDropped = "  left out: set %d: %s: %s",
            foundNative = "  already in the Sets tab: set %d: %s",
            foundNativeClass = "  in the Sets tab under the %s class filter: set %d: %s",
            includedHeader = "Listed sets (%d):",
            recordLine = "  set %d: %s (%d pieces)",
            rejectedHeader = "Sets left out (%d):",
            rejectionLine = "  set %d: %s: %s",
            andMore = "  ...and %d more",
        },
    },
    perf = {
        header = "Work measured this session:",
        nothing = "Nothing has been measured yet. Open the Extra Sets tab first.",
        reset = "Cleared the measurements.",
        timedLine = "%s: %d, %.0f ms total, %.1f ms each, worst %.1f, last %.1f",
        countedLine = "%s: %d",
        framesLine = "frames watched: %d, %.1f ms of measured work each, %d over %d ms",
        worstFrameLine = "worst frame: %.0f ms, %.0f ms of it measured work",
    },
    recolorGroups = {
        header = "Recolor families from %d appearance(s): %d family(ies), %d cluster(s) left out.",
        shortCoverage = "Only read %d of %d appearances this client holds (%d pass the current filters), so families are incomplete.",
        hint = "Use /wardrobe recolors dump to save the whole report, then reload and read it from saved variables.",
        dumped = "Saved %d family(ies) and %d cluster(s) left out. Reload, then read LuckysWardrobeDB.recolorDump.",
        warming = "Asking the client for %d item names, then dumping. This takes a moment.",
        funnelLine = "%s: %d appearances, %d with sources, %d with an item, %d named by source, %d named by item.",
        familyLine = "%s (%d pieces, span %d):",
        memberLine = "  %s: %s (order %d)",
        rejectedHeader = "Clusters left out (%d):",
        rejectionLine = "  %s: %s",
    },
}
