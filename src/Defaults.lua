-- Lucky's Wardrobe: Saved-variable defaults.
LuckysWardrobe = LuckysWardrobe or {}

-- Settings panel: any setting flagged with a `since` version at or above this
-- gets a "NEW" badge and appears in the What's New group. Bump this each
-- release cycle so only recent features are highlighted.
LuckysWardrobe.WHATS_NEW_MIN_VERSION = "1.7.0"

LuckysWardrobe.DB_DEFAULTS = {
    devMode = false,
    welcomeShown = false,
    keepTransmogTab = false,
    undoOnSecondClick = true,
    undoHidesSlot = false,
    hideUnwearableSets = true,
    showSetNames = true,
    trackSetsOnShiftClick = true,
    markTrackedAppearances = true,
    wowheadLinkOnAltClick = true,
    tooltipSetProgress = true,
    tooltipModel = true,
    tooltipModelWornAndBags = false,
    -- Only the slots the set previews leave off are stored, so a slot never
    -- touched is one they still dress.
    hiddenSetSlots = {},
    situationPresets = {},
    showSituationValues = true,
    showSituationPresetNames = true,
    showSituationPresetExtras = false,
    situationPresetExtraLimit = 1,
    showSituationTooltips = true,
    situationLabels = {},
    showInstanceSets = true,
    instanceSetsMaxMissing = 3,
    includeCurrentTier = false,
    includeOtherClassSets = false,
    -- Only the classes left out are stored, so a class never touched is one the
    -- player still wants to hear about.
    hiddenSetClasses = {},
    instanceSetsPosition = {},
    instanceSetsDwellSeconds = 4,
    markCatalysablePieces = true,
    alertSetPieceLoot = true,
    alertCatalystLoot = true,
    alertWithSound = true,
    alertWithChat = true,
}
