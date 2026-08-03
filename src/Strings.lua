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
        version = {
            section = "Version Info",
            addon = "Lucky's Ensemble",
            utils = "Lucky's Utils",
        },
    },
    tracking = {
        tracked = "Tracking %d missing appearance(s) from %s.",
        failed = "%d could not be tracked.",
        nothing = "Nothing new to track from %s.",
    },
}
