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
        middleClick = "Middle-click: Toggle dev mode",
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
            whatsNew = "What's New",
            appearances = "Appearances",
            tooltips = "Tooltips",
            transmog = "Transmog",
            setTracker = "Set Tracker",
        },
        sections = {
            whatToTrack = "What Counts as Close",
            inInstances = "The List in Dungeons and Raids",
            whenYouLoot = "When You Loot",
        },
        catalystMissing = "The catalyst options below are turned off because Transmog Upgrade Master is not installed. It is the only way to know what the catalyst would turn an item into.",
        maxMissing = {
            label = "A Set Counts as Close When Missing",
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
            label = "Shrink Into the Corner After",
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
        alertSound = {
            label = "Alert With a Sound",
            desc = "Alerts play a sound, which carries even when chat is scrolling past.",
        },
        alertChat = {
            label = "Alert in Chat",
            desc = "Alerts print a chat line naming the piece. A long clear puts a lot of lines in chat, and the sound alone carries just as well.",
        },
        devMode = {
            label = "Dev Mode",
            desc = "Shows detailed diagnostics in chat while features are developed.",
            enabled = "Dev mode enabled.",
            disabled = "Dev mode disabled.",
        },
        minimapButton = {
            label = "Minimap Button",
            desc = "Shows the Lucky's Wardrobe button on the minimap. Drag the button to move it around the edge.",
        },
        trackSets = {
            label = "Track on Shift-Click",
            desc = "Shift-click a set to track every appearance you are still missing from it, or shift-click one of its pieces to track just that one and shift-click it again to stop. Works in Blizzard's Sets tab, in the Extra Sets tab, and in the Custom tab.",
        },
        markTracked = {
            label = "Mark Tracked Pieces",
            desc = "Puts a crosshair on the corner of the pieces you are tracking when you open a set, in the Sets tab and the Extra Sets tab, so a set says which of its pieces you are out hunting for. Hover a marked piece and its tooltip says so too.",
        },
        wowheadLink = {
            label = "Wowhead Address on Alt-Click",
            desc = "Alt-click an item anywhere in your appearance collection to bring up its Wowhead address, ready to copy.",
        },
        tooltipSetProgress = {
            label = "Show Set Information",
            desc = "Adds a line to an item's tooltip naming the set it belongs to and how much of that set you have, so a drop says what it is worth at a glance. Example: \"From set: Glyphed Garb 7/8\"",
        },
        tooltipModel = {
            label = "Show a Preview Model",
            desc = "Shows the piece itself beside its tooltip, close up and with nothing else in the frame. Weapons, shields and off-hands are models in their own right and are shown on their own. Armour is not something the game has a model of, only a character wearing one, so those are shown close up on the bare figure the transmogrifier previews on, framed on the slot the piece sits in.",
        },
        tooltipModelWornAndBags = {
            label = "Include Worn and in Bags",
            desc = "Previews gear you already have as well, hovered on your character or in your bags and bank. Left off, the preview is kept for pieces you have yet to get: a drop, a quest reward, a vendor's stock, an auction, a link in chat.",
        },
        keepTransmogTab = {
            label = "Keep Your Tab Between Outfits",
            desc = "Switching outfits at the transmog NPC keeps you on whichever tab you are on, instead of jumping back to Items. Clicking a slot still opens Items.",
        },
        undoOnSecondClick = {
            label = "Click an Appearance Again to Undo",
            desc = "On the Items tab at the transmog NPC, clicking an appearance you have already picked for the slot puts the slot back to what it was wearing, so a piece can be clicked on and off to judge it. The list stays on the page you are reading either way.",
        },
        undoHidesSlot = {
            label = "Undo by Hiding the Slot",
            desc = "The second click empties the slot instead of putting back what you are wearing, for judging a piece against a bare slot. Clicking the appearance that hides the slot still puts the slot back, there being nothing left to empty.",
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
        showSituationPresetNames = {
            label = "Name Outfits After Saved Situations",
            desc = "An outfit whose situations match one you have saved shows that saved situation's name on its line, so you can see at a glance which outfits are set up the way you meant. Outfits matching nothing show their situation detail as before.",
        },
        showSituationPresetExtras = {
            label = "Name Near Matches Too",
            desc = "An outfit that has everything a saved situation asks for, plus a value or two of its own, is named after that saved situation with the extra values listed after it. Turn this off to name only the outfits that match exactly.",
        },
        situationPresetExtraLimit = {
            label = "Extra Values Allowed",
            desc = "How far past a saved situation an outfit can go and still be named after it. Where several saved situations fit, the outfit is named after the closest.",
        },
        showSituationTooltips = {
            label = "Show Situation Tooltips",
            desc = "Shows an outfit's full situation list, with the values selected in each category, in a tooltip when you hover it.",
        },
    },
    randomiser = {
        tooltipTitle = "Roll a Random Outfit",
        tooltipText = "Hold to spin every armour slot through appearances you own, then let go and watch it slow to a stop. A slot you set a piece on locks itself and sits out the spin, and the padlock beside a slot locks or unlocks it. Weapons are left alone, and nothing is bought until you press Apply.",
        poolsClosed = "The transmogrifier is not open, so there is nothing to roll.",
        poolsHeader = "Randomiser: %d slots in play.",
        poolsSkipped = "  %s (category %s): skipped, %s",
        poolsNoCategory = "the client files it under no appearance category",
        poolsSecondary = "it is a secondary slot",
        poolsNotAppearance = "it is not an appearance slot",
        poolsWeapon = "it is a weapon slot",
        poolsNothingCollected = "nothing in it is collected and usable",
        poolsSlot = "  %s (category %s): %d listed, %d collected and usable, "
            .. "can transmogrify %s, can hide %s",
        poolsColour = "      in the lit colour: %d to draw from, "
            .. "plus %d not collected and %d collected but not wearable",
        poolsPiece = "      visual %d: collected %s, wearable %s, %s",
        poolsDetailEnd = "      (every piece the client lists for category %s in that colour)",
        stuckSlot = "Roll left %s in an error: visual %s, source %s, error %s %s (%s), "
            .. "can transmogrify %s, has pending %s, locked %s",
        stuckBefore = "the slot was already in this error before the spin",
        stuckFromRoll = "the slot was clear before the spin",
        slotsHeader = "Randomiser: what %d slots are holding.",
        slotsSlot = "  %s: source %s, error %s %s, display type %s",
        slotsRolled = "      rolled by us %s (visual %s, source %s)",
        slotsSource = "      source: %s, collected %s, useErrorType %s, useError %s, "
            .. "valid for player %s",
        colourTitle = "Roll a %s Outfit",
        otherTitle = "Roll an Outfit of Other Colours",
        colourText = "Hold to spin every slot you have not locked through the pieces you own in the colour lit on the Items tab. A slot with nothing in that colour is hidden instead, since wearing nothing is the only other way to keep to it. Nothing is bought until you press Apply.",
        lockTitle = "Lock This Slot",
        lockHint = "Click to leave this slot as it is when you roll a random outfit.",
        unlockTitle = "Unlock This Slot",
        unlockHint = "Click to let a random outfit roll this slot again.",
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
        renameTooltip = "Rename Saved Situation",
        renameDialog = "Rename saved situation \"%s\"",
    },
    wowheadLink = {
        dialog = "Press Ctrl+C to copy this address, then paste it into your browser.",
    },
    tooltipModel = {
        nothingHovered = "Nothing has been hovered yet, so there is nothing to say about a piece.",
        lastPiece = "Last piece hovered: item %d, slot %s, appearance %s, source %s, camera %s.",
        cameraSources = {
            carried = "  Framed by the game's own camera for this kind of weapon.",
            form = "  Framed by the camera for the shape your character is in.",
            slot = "  Framed by the camera the game frames every piece in this slot with.",
        },
        cameraUnframed = "  Nothing frames this slot, so the piece is shown from wherever the model opens.",
        cameraReads = "  The client describes that camera, so the piece is framed from where the camera puts it.",
        cameraMissing = "  The client gave no camera it will describe, so the piece is framed from where the model opens.",
        aloneModel = "  Shown as a model of its own, and the client loaded file %s for it.",
        framingHeader = "How the tooltip preview frames each slot:",
        framingLine = "  %s: facing %.2f, zoom %.2f, height %.2f, side %.2f",
        framingSet = "Framing %s at facing %.2f, zoom %.2f, height %.2f, side %.2f. Hover a piece in that slot to see it.",
        framingUsage = "Use /wardrobe preview <slot> <facing> <zoom> <height> <side> to try another. Facing is a fraction of a full turn, zoom is how far the camera sits back so under 1 is closer, height lifts the figure to bring what is below into shot, and side slides it across.",
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
        stopped = "Stopped tracking %d appearance(s) from %s.",
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
    -- Shared by both set lists, the Sets tab's and the Extra Sets tab's, so a
    -- row reads the same on either. They are one set on purpose: a row that
    -- counts colourways in the corner is a row whose line underneath counts
    -- every look across them and whose tooltip names each colourway with its
    -- own progress, and none of them must drift apart.
    setRow = {
        counts = "%d/%d collected",
        -- The badge in the corner. Short because it shares the row with the
        -- set's name, which gives up the width it takes.
        variantCount = "x%d",
        colourways = "%d Colourways",
        variantOption = "%s (%d/%d)",
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
        -- The box for sets the client will not date. Only the Extra Sets lists
        -- offer it: Blizzard dates every set it lists itself.
        unknownExpansion = "Unknown",
        -- The box for pieces the client files under no expansion at all, which
        -- it answers for by calling them Classic. Only the Items tab offers it,
        -- and only because a piece carries an item to read a source off.
        noExpansion = "No Expansion",
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
    previewSlots = {
        -- The slot names themselves come from the game, so only the sentence
        -- around them is ours to say.
        tooltipTitle = "Hide slots",
        buttonTooltip = "Choose which slots are shown in the preview. Uncheck a slot to hide that slot. The sets themselves are untouched.",
        menuTitle = "Displayed Slots",
        showAll = "Check All",
    },
    customSets = {
        -- Short, because the tab strip has four names to fit and Blizzard's own
        -- "Custom Sets" is one word too many for the room left.
        tab = "Custom",
        empty = "You have not saved any custom sets yet. Save one at a transmogrifier and it appears here.",
        noResults = "No custom sets match the current search.",
        select = "Select a custom set to preview it.",
        counts = "%d/%d collected",
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
    transmogItems = {
        noCategory = "Open the Items tab at a transmogrifier first.",
        datesHeader = "%s: %d of %d appearances dated to %s.",
        datesSource = "  %s: %d",
        datesExample = "  %s (item %s, %s)",
    },
    -- The swatches on the Items tab, keyed to match Colours.PRESETS.
    colours = {
        red = "Red",
        orange = "Orange",
        yellow = "Yellow",
        green = "Green",
        teal = "Teal",
        blue = "Blue",
        purple = "Purple",
        pink = "Pink",
        brown = "Brown",
        white = "White",
        grey = "Grey",
        black = "Black",
        other = "Other Colours",
        pickHint = "Click to show only pieces with this colour on them.",
        otherHint = "Click to show only pieces no other swatch on the strip finds.",
        clearHint = "Click again to show every colour.",
        roll = "Roll a Random Piece",
        rollHint = "Click to put a random piece from this page on the slot, which keeps a roll to the colour you picked. Nothing is bought until you press Apply.",
    },
}
