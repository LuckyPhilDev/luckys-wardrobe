-- Lucky's Ensemble: User-facing strings.
LuckysEnsemble = LuckysEnsemble or {}

LuckysEnsemble.Strings = {
    addon = {
        title = "Lucky's Ensemble",
        prefix = "|cffc8902aLucky's Ensemble:|r",
        initialized = "Initialized.",
    },
    settings = {
        groups = {
            general = "General",
            appearances = "Appearances",
            transmog = "Transmog",
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
            addon = "Lucky's Ensemble",
            utils = "Lucky's Utils",
        },
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
}
