local addonName, addon = ...
local Config = addon.Config
local Scanner = addon.Scanner
local Button = addon.Button

-- Ace3 options panel. Everything user-facing lives here; the getters/setters
-- funnel through addon.Config (our SavedVariable accessor), so no AceDB needed.
-- Registered as a function so the dynamic "Quests" list is rebuilt each open.

local Options = {}
addon.Options = Options

local APP = "QuestItemButton"
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

-- refresh hook set by the main file (re-scan + re-apply button)
local function refresh()
    if addon.refresh then addon.refresh() end
end

local function cfgToggle(order, name, key, desc, onSet)
    return {
        type = "toggle", order = order, name = name, desc = desc, width = "full",
        get = function() return Config.get(key) end,
        set = function(_, val)
            Config.set(key, val)
            if onSet then onSet(val) end
        end,
    }
end

-- Build the per-quest enable list from whatever usable quest items are in the
-- log right now (checked = shown).
local function questArgs()
    local args = {}
    local seen = false
    for _, c in ipairs(Scanner.scan()) do
        seen = true
        args["q" .. c.questID] = {
            type = "toggle", width = "full",
            name = ("%s |cff808080(quest %d)|r"):format(c.itemName, c.questID),
            get = function() return not Config.isQuestDisabled(c.questID) end,
            set = function(_, val)
                Config.setQuestDisabled(c.questID, not val)
                refresh()
            end,
        }
    end
    if not seen then
        args.none = { type = "description", name = "No usable quest items in your log right now.", order = 1 }
    end
    return args
end

local function buildOptions()
    return {
        type = "group",
        name = APP,
        args = {
            display = {
                type = "group", inline = true, order = 1, name = "Display",
                args = {
                    hideStyle = cfgToggle(1, "Minimal (hide button ring)", "hideStyle",
                        "Hide the action-slot ring for a bare icon.",
                        function() Button.updateStyle() end),
                    locked = cfgToggle(2, "Lock button position", "locked",
                        "Prevent dragging the button."),
                    resetpos = {
                        type = "execute", order = 3, name = "Reset position",
                        desc = "Move the button back to the default location.",
                        func = function() Button.resetPosition() end,
                    },
                },
            },
            behavior = {
                type = "group", inline = true, order = 2, name = "Behavior",
                args = {
                    proximity = cfgToggle(1, "Proximity: show nearest item", "proximity",
                        "When several usable items are in-zone, show the one whose quest objective is closest (needs Questie; falls back to super-tracked quest).",
                        function() refresh() end),
                    debug = cfgToggle(2, "Debug logging", "debug",
                        "Print detailed debug messages to chat."),
                },
            },
            quests = {
                type = "group", order = 3, name = "Quests in log",
                desc = "Toggle which usable quest items may show.",
                args = questArgs(),  -- rebuilt each open (buildOptions is a function)
            },
        },
    }
end

-- AceConfig calls buildOptions() each time the panel opens -> fresh quest list.
AceConfig:RegisterOptionsTable(APP, buildOptions)
Options.blizPanel = AceConfigDialog:AddToBlizOptions(APP, APP)

function Options.open()
    AceConfigDialog:Open(APP)
end
