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
    settings = {
        groups = {
            general = "General",
            appearances = "Appearances",
            transmog = "Transmog",
            setTracker = "Set Tracker",
        },
        sections = {
            whatToTrack = "What to Track",
            inInstances = "In Dungeons and Raids",
            whenYouLoot = "When You Loot",
        },
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
            label = "Track Sets on Shift-Click",
            desc = "Shift-click a set in Blizzard's Sets collection to track every appearance you are still missing from it.",
        },
        keepTransmogTab = {
            label = "Keep Active Transmog Tab",
            desc = "Keeps whichever tab you're on when switching outfits at the transmog NPC, instead of jumping back to Items. Clicking a slot still opens Items.",
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
    tracking = {
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
    extraSets = {
        tab = "Extra Sets",
        building = "Reading Blizzard-defined additional sets from this client...",
        empty = "This client's data exposes no additional Blizzard-defined sets.",
        noResults = "No extra sets match the current search or filters.",
        select = "Select a set to preview it.",
        loading = "Loading appearance data...",
        counts = "%d/%d collected",
        progress = "%d / %d",
        pieceUnavailable = "This piece is not available on this client build.",
        pieceUnavailableShort = "Pieces unavailable",
        unavailableNotice = "%d piece(s) in this set are not available on this client build.",
        notUsable = "This set is not usable by your class.",
        trackHint = "Shift-click to track this appearance.",
    },
}
