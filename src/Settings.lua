-- Lucky's Wardrobe: Settings panel.
LuckysWardrobe = LuckysWardrobe or {}
LuckysWardrobe.Settings = {}

local settingsPanel

-- Named in each class's own colour, matching the instance list so the two read as
-- the same thing said twice.
local function classOptions()
    local options = {}
    for index, class in ipairs(LuckysWardrobe.Classes:All()) do
        options[index] = {
            key = class.file,
            label = LuckysWardrobe.Classes:Colour(class, class.name),
        }
    end
    return options
end

function LuckysWardrobe.Settings:Init(db)
    local S = LuckysWardrobe.Strings
    local addonVersion = C_AddOns.GetAddOnMetadata("Luckys_Wardrobe", "Version") or "?"
    local utilsVersion = C_AddOns.GetAddOnMetadata("Luckys_Utils", "Version") or "?"
    local panel = LuckySettings:NewRichPanel(S.addon.title, {
        addonFolder = "Luckys_Wardrobe",
        imagesRoot = "Images",
    })
    settingsPanel = panel

    local general = panel:Group(S.settings.groups.general)
    general:Toggle({
        label = S.settings.devMode.label,
        desc = S.settings.devMode.desc,
        checked = db.devMode,
        onToggle = function(checked)
            db.devMode = checked
            LuckysWardrobe.DevLog(S.settings.devMode.enabled)
        end,
    })

    general:BottomSection(S.settings.version.section)
    general:BottomLabel({ label = S.settings.version.addon, value = "v" .. addonVersion })
    general:BottomLabel({ label = S.settings.version.utils, value = "v" .. utilsVersion })

    local appearances = panel:Group(S.settings.groups.appearances)
    appearances:Toggle({
        label = S.settings.trackSets.label,
        desc = S.settings.trackSets.desc,
        checked = db.trackSetsOnShiftClick,
        onToggle = function(checked)
            db.trackSetsOnShiftClick = checked
        end,
    })
    appearances:Toggle({
        label = S.settings.markTracked.label,
        desc = S.settings.markTracked.desc,
        checked = db.markTrackedAppearances,
        onToggle = function(checked)
            db.markTrackedAppearances = checked
            LuckysWardrobe.TrackedAppearances:Refresh()
        end,
    })
    appearances:Toggle({
        label = S.settings.wowheadLink.label,
        desc = S.settings.wowheadLink.desc,
        checked = db.wowheadLinkOnCtrlClick,
        onToggle = function(checked)
            db.wowheadLinkOnCtrlClick = checked
        end,
    })

    local tooltips = panel:Group(S.settings.groups.tooltips)
    tooltips:Toggle({
        label = S.settings.tooltipSetProgress.label,
        desc = S.settings.tooltipSetProgress.desc,
        checked = db.tooltipSetProgress,
        onToggle = function(checked)
            db.tooltipSetProgress = checked
        end,
    })

    local transmog = panel:Group(S.settings.groups.transmog)
    transmog:Toggle({
        label = S.settings.hideUnwearableSets.label,
        desc = S.settings.hideUnwearableSets.desc,
        -- The same switch sits in the Sets tab's own filter menu, so the panel
        -- reads it afresh rather than showing what it was last time.
        checked = function() return db.hideUnwearableSets end,
        onToggle = function(checked)
            db.hideUnwearableSets = checked
            LuckysWardrobe.TransmogSets:Refresh()
        end,
    })
    transmog:Toggle({
        label = S.settings.keepTransmogTab.label,
        desc = S.settings.keepTransmogTab.desc,
        checked = db.keepTransmogTab,
        onToggle = function(checked)
            db.keepTransmogTab = checked
        end,
    })
    transmog:Toggle({
        label = S.settings.showSetNames.label,
        desc = S.settings.showSetNames.desc,
        checked = db.showSetNames,
        onToggle = function(checked)
            db.showSetNames = checked
            LuckysWardrobe.TransmogSetNames:Refresh()
        end,
    })
    transmog:Toggle({
        label = S.settings.showSituationValues.label,
        desc = S.settings.showSituationValues.desc,
        image = "transmog/show-situation-values",
        imageSize = { 571, 222 },
        checked = db.showSituationValues,
        onToggle = function(checked)
            db.showSituationValues = checked
            LuckysWardrobe.SituationLabels:Refresh()
        end,
    })
    transmog:Toggle({
        label = S.settings.showSituationTooltips.label,
        desc = S.settings.showSituationTooltips.desc,
        image = "transmog/show-situation-tooltips",
        imageSize = { 558, 140 },
        checked = db.showSituationTooltips,
        onToggle = function(checked)
            db.showSituationTooltips = checked
            LuckysWardrobe.SituationLabels:Refresh()
        end,
    })

    -- The instance list and the loot alerts are two sides of one feature and share
    -- the threshold that decides what counts as close to finishing, so the threshold
    -- leads and neither side owns it.
    local setTracker = panel:Group(S.settings.groups.setTracker)
    local catalystAvailable = LuckysWardrobe.Catalyst:IsAvailable()
    -- Two settings in two different sections grey out together, and a greyed row
    -- says nothing about why until you hover it, so the group says it once up top.
    if not catalystAvailable then
        setTracker:Notice({ text = S.settings.catalystMissing })
    end

    setTracker:Section(S.settings.sections.whatToTrack)
    setTracker:Slider({
        label = S.settings.maxMissing.label,
        desc = S.settings.maxMissing.desc,
        min = 1,
        -- A raid set runs to nine pieces once the recoloured cloak, belt and boots
        -- are counted, so nine is what it takes to reach a set you own none of. A
        -- ceiling of eight put that set out of reach at every setting.
        max = 9,
        value = db.instanceSetsMaxMissing,
        onChanged = function(value)
            db.instanceSetsMaxMissing = value
            LuckysWardrobe.SetCompletion:Refresh()
        end,
    })
    setTracker:Toggle({
        label = S.settings.includeCurrentTier.label,
        desc = S.settings.includeCurrentTier.desc,
        checked = db.includeCurrentTier,
        onToggle = function(checked)
            db.includeCurrentTier = checked
            LuckysWardrobe.SetCompletion:Refresh()
        end,
    })
    setTracker:Toggle({
        label = S.settings.includeOtherClassSets.label,
        desc = S.settings.includeOtherClassSets.desc,
        checked = db.includeOtherClassSets,
        onToggle = function(checked)
            db.includeOtherClassSets = checked
            LuckysWardrobe.SetCompletion:Refresh()
        end,
    })
    setTracker:MultiSelect({
        label = S.settings.setClasses.label,
        desc = S.settings.setClasses.desc,
        parent = S.settings.includeOtherClassSets.label,
        options = classOptions(),
        isChecked = function(classFile) return not db.hiddenSetClasses[classFile] end,
        onToggle = function(classFile, checked)
            if checked then
                db.hiddenSetClasses[classFile] = nil
            else
                db.hiddenSetClasses[classFile] = true
            end
            LuckysWardrobe.SetCompletion:Refresh()
        end,
    })
    setTracker:Toggle({
        label = S.settings.markCatalysable.label,
        desc = S.settings.markCatalysable.desc,
        requires = { addon = "TransmogUpgradeMaster" },
        disabled = not catalystAvailable,
        checked = db.markCatalysablePieces,
        onToggle = function(checked)
            db.markCatalysablePieces = checked
            LuckysWardrobe.SetCompletion:Refresh()
        end,
    })

    setTracker:Section(S.settings.sections.inInstances)
    setTracker:Toggle({
        label = S.settings.showInstanceSets.label,
        desc = S.settings.showInstanceSets.desc,
        checked = db.showInstanceSets,
        onToggle = function(checked)
            db.showInstanceSets = checked
        end,
    })
    setTracker:Slider({
        label = S.settings.dwellSeconds.label,
        desc = S.settings.dwellSeconds.desc,
        parent = S.settings.showInstanceSets.label,
        min = 0,
        max = 15,
        suffix = "s",
        value = db.instanceSetsDwellSeconds,
        onChanged = function(value)
            db.instanceSetsDwellSeconds = value
        end,
    })
    setTracker:Button({
        label = S.settings.resetPosition.label,
        desc = S.settings.resetPosition.desc,
        onClick = function()
            LuckysWardrobe.SetCompletion:ResetPosition()
        end,
    })

    setTracker:Section(S.settings.sections.whenYouLoot)
    setTracker:Toggle({
        label = S.settings.alertSetPiece.label,
        desc = S.settings.alertSetPiece.desc,
        checked = db.alertSetPieceLoot,
        onToggle = function(checked)
            db.alertSetPieceLoot = checked
        end,
    })
    setTracker:Toggle({
        label = S.settings.alertCatalyst.label,
        desc = S.settings.alertCatalyst.desc,
        requires = { addon = "TransmogUpgradeMaster" },
        disabled = not catalystAvailable,
        checked = db.alertCatalystLoot,
        onToggle = function(checked)
            db.alertCatalystLoot = checked
        end,
    })
    setTracker:MultiSelect({
        label = S.settings.alertWith.label,
        desc = S.settings.alertWith.desc,
        options = {
            { key = "alertWithSound", label = S.settings.alertWith.sound },
            { key = "alertWithChat", label = S.settings.alertWith.chat },
        },
        isChecked = function(key) return db[key] and true or false end,
        onToggle = function(key, checked) db[key] = checked end,
    })

    panel:Finalize()
end

function LuckysWardrobe.Settings:Open()
    if settingsPanel then settingsPanel:Open() end
end
