-- Lucky's Wardrobe: Saved-variable defaults.
LuckysWardrobe = LuckysWardrobe or {}

LuckysWardrobe.DB_DEFAULTS = {
    devMode = false,
    welcomeShown = false,
    keepTransmogTab = false,
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
