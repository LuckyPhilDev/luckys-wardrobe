-- Lucky's Wardrobe: Addon initialization.
LuckysWardrobe = LuckysWardrobe or {}

local ADDON_NAME = "Luckys_Wardrobe"

local function initialize()
    LuckysWardrobeDB = LuckysWardrobeDB or {}
    LuckyUtils.ApplyDefaults(LuckysWardrobeDB, LuckysWardrobe.DB_DEFAULTS)
    LuckysWardrobe.DevLog = LuckyLog:New(LuckysWardrobe.Strings.addon.prefix, function()
        return LuckysWardrobeDB.devMode
    end)

    LuckysWardrobe.AddonConflicts:Init()
    LuckysWardrobe.Settings:Init(LuckysWardrobeDB)
    LuckysWardrobe.SetsBrowser:Init()
    LuckysWardrobe.ExtraSetsCatalog:Init()
    LuckysWardrobe.ExtraSets:Init()
    LuckysWardrobe.TransmogSets:Init(LuckysWardrobeDB)
    LuckysWardrobe.TransmogSetNames:Init(LuckysWardrobeDB)
    LuckysWardrobe.TransmogExtraSets:Init()
    LuckysWardrobe.SetTracking:Init(LuckysWardrobeDB)
    LuckysWardrobe.TrackedAppearances:Init(LuckysWardrobeDB)
    LuckysWardrobe.WowheadLink:Init(LuckysWardrobeDB)
    LuckysWardrobe.ItemTooltips:Init(LuckysWardrobeDB)
    LuckysWardrobe.SetCompletion:Init(LuckysWardrobeDB)
    LuckysWardrobe.LootAlerts:Init(LuckysWardrobeDB)
    LuckysWardrobe.Catalyst:Init()
    LuckysWardrobe.Transmog:Init(LuckysWardrobeDB)
    LuckysWardrobe.SituationLabels:Init(LuckysWardrobeDB)
    LuckysWardrobe.SituationPresets:Init(LuckysWardrobeDB)
    LuckyMinimap:Create({
        name = "LuckysWardrobeMinimapButton",
        icon = "Interface\\GossipFrame\\transmogrifyGossipIcon.blp",
        dbKey = "minimap",
        db = LuckysWardrobeDB,
        defaultAngle = 160,
        onClick = function(_, mouseButton)
            if mouseButton == "RightButton" then
                LuckysWardrobe.Settings:Open()
            elseif IsShiftKeyDown() then
                LuckysWardrobe.SetCompletion:Toggle()
            end
        end,
        tooltip = function(tooltip)
            local S = LuckysWardrobe.Strings.minimap
            tooltip:AddLine(LuckysWardrobe.Strings.addon.title)
            tooltip:AddLine(" ")
            tooltip:AddLine(S.shiftClick, 0.91, 0.86, 0.78)
            tooltip:AddLine(S.rightClick, 0.91, 0.86, 0.78)
            tooltip:AddLine(S.drag, 0.54, 0.49, 0.42)
        end,
    })
    LuckysWardrobe.DevLog(LuckysWardrobe.Strings.addon.initialized)

    SLASH_LUCKYSWARDROBE1 = "/wardrobe"
    SLASH_LUCKYSWARDROBE2 = "/lw"
    SlashCmdList.LUCKYSWARDROBE = function(message)
        local say = LuckysWardrobe.Utils.Say
        local command, argument = (message or ""):match("^%s*(%S*)%s*(.-)%s*$")
        command = command:lower()
        if command == "sets" then
            LuckysWardrobe.SetCompletion:Toggle()
        elseif command == "scan" then
            LuckysWardrobe.SetCompletion:Diagnose()
        elseif command == "replay" then
            LuckysWardrobe.SetCompletion:ReplayEntry()
        elseif command == "extrasets" then
            -- Set names have spaces, so the query keeps the rest of the line.
            local subcommand, query = argument:match("^(%S*)%s*(.-)$")
            subcommand = subcommand:lower()
            if subcommand == "find" and query ~= "" then
                LuckysWardrobe.ExtraSetsCatalog:PrintMatches(query)
            elseif subcommand == "looks" and query ~= "" then
                LuckysWardrobe.ExtraSets:PrintLooks(query)
            elseif subcommand == "variants" and query ~= "" then
                LuckysWardrobe.ExtraSets:PrintVariants(query)
            elseif subcommand == "colours" or subcommand == "colors" then
                LuckysWardrobe.ExtraSets:PrintColourFamilies()
            elseif subcommand == "pieces" then
                LuckysWardrobe.ExtraSets:PrintPieceReport()
            elseif subcommand == "perf" then
                if query:lower() == "reset" then
                    LuckysWardrobe.Perf:Reset()
                    say(LuckysWardrobe.Strings.perf.reset)
                else
                    LuckysWardrobe.Perf:PrintReport()
                end
            else
                LuckysWardrobe.ExtraSetsCatalog:PrintReport(subcommand == "full")
            end
        elseif command == "recolors" then
            local S = LuckysWardrobe.Strings.recolorGroups
            if argument:lower() == "probe" then
                LuckysWardrobe.RecolorGroups:PrintFunnel()
            elseif argument:lower() == "dump" then
                -- Names come from the item cache, so a cold client has to be
                -- asked for the data and given time to answer before the dump is
                -- worth reading. Waiting here beats asking a person to count
                -- seconds between two commands.
                local _, coverage = LuckysWardrobe.RecolorGroups.LiveAppearances()
                say(S.warming:format(#coverage.items))
                LuckysWardrobe.RecolorGroups:WarmItemNames(coverage.items, function()
                    local families, rejections =
                        LuckysWardrobe.RecolorGroups:DumpReport(LuckysWardrobeDB)
                    say(S.dumped:format(families, rejections))
                end)
            else
                LuckysWardrobe.RecolorGroups:PrintReport(argument:lower() == "full")
            end
        else
            LuckysWardrobe.Settings:Open()
        end
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(_, _, loadedAddon)
    if loadedAddon ~= ADDON_NAME then return end
    eventFrame:UnregisterEvent("ADDON_LOADED")
    initialize()
end)
