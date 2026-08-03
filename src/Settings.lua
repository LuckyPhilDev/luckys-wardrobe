-- Lucky's Ensemble: Settings panel.
LuckysEnsemble = LuckysEnsemble or {}
LuckysEnsemble.Settings = {}

local settingsPanel

function LuckysEnsemble.Settings:Init(db)
    local S = LuckysEnsemble.Strings
    local addonVersion = C_AddOns.GetAddOnMetadata("Luckys_Ensemble", "Version") or "?"
    local utilsVersion = C_AddOns.GetAddOnMetadata("Luckys_Utils", "Version") or "?"
    local panel = LuckySettings:NewRichPanel(S.addon.title, {
        addonFolder = "Luckys_Ensemble",
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
            LuckysEnsemble.DevLog(S.settings.devMode.enabled)
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

    local transmog = panel:Group(S.settings.groups.transmog)
    transmog:Toggle({
        label = S.settings.keepTransmogTab.label,
        desc = S.settings.keepTransmogTab.desc,
        checked = db.keepTransmogTab,
        onToggle = function(checked)
            db.keepTransmogTab = checked
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
            LuckysEnsemble.SituationLabels:Refresh()
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
            LuckysEnsemble.SituationLabels:Refresh()
        end,
    })

    panel:Finalize()
end

function LuckysEnsemble.Settings:Open()
    if settingsPanel then settingsPanel:Open() end
end
