-- Lucky's Wardrobe: Saved-variable defaults.
LuckysWardrobe = LuckysWardrobe or {}

LuckysWardrobe.DB_DEFAULTS = {
    devMode = false,
    keepTransmogTab = false,
    hideUnwearableSets = true,
    trackSetsOnShiftClick = true,
    markTrackedAppearances = true,
    wowheadLinkOnCtrlClick = true,
    tooltipAppearanceCollected = true,
    tooltipSetProgress = true,
    situationPresets = {},
    showSituationValues = true,
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
