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
    -- show the explanation as a dimmed subline under the label, not just on hover
    local label = desc and ("%s\n|cff9d9d9d%s|r"):format(name, desc) or name
    return {
        type = "toggle", order = order, name = label, desc = desc, width = "full",
        get = function() return Config.get(key) end,
        set = function(_, val)
            Config.set(key, val)
            if onSet then onSet(val) end
        end,
    }
end

-- one-line visible blurb at the top of a group (shown, not just on hover)
local function blurb(text)
    return { type = "description", order = 0, name = text .. "\n", fontSize = "medium" }
end

-- Re-apply what we can after a profile switch; a /reload guarantees the rest.
local function applyProfile()
    refresh()
    if Button.updateStyle then Button.updateStyle() end
    if Button.applyKeybind then Button.applyKeybind() end
end

-- profile names other than the active one, as an AceConfig select `values` map
local function otherProfiles()
    local t, current = {}, Config.currentProfile()
    for _, n in ipairs(Config.profileNames()) do
        if n ~= current then t[n] = n end
    end
    return t
end

-- Build the per-quest enable list from whatever usable quest items are in the
-- log right now (checked = shown).
local function questArgs()
    local args = {}
    args.intro = blurb("Uncheck a quest to stop its item from ever showing. List reflects your current log.")
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
            intro = blurb(
                "Shows a Retail-style extra action button when you carry a usable quest item " ..
                "AND are in the zone where it's meant to be used. Options below control when it " ..
                "appears, how it looks, and which quests it tracks.\n" ..
                "|cff9d9d9dHover any option to read more details.|r"),
            display = {
                type = "group", inline = true, order = 1, name = "Display",
                args = {
                    intro = blurb("How the button looks and where it sits on screen."),
                    hideStyle = cfgToggle(1, "Minimal (hide button ring)", "hideStyle",
                        "Hide the action-slot ring for a bare icon.",
                        function() Button.updateStyle() end),
                    locked = cfgToggle(2, "Lock button position", "locked",
                        "Prevent dragging the button."),
                    keybind = {
                        type = "keybinding", order = 2.5, width = "full",
                        name = "Trigger key",
                        desc = "Bind a key to fire the quest item. Clear to unbind. Applies out of combat.",
                        get = function() return Config.get("keybind") end,
                        set = function(_, val)
                            Config.set("keybind", val)
                            Button.applyKeybind()
                        end,
                    },
                    resetpos = {
                        type = "execute", order = 3, name = "Reset position",
                        desc = "Move the button back to the default location.",
                        func = function() Button.resetPosition() end,
                    },
                    minimap = {
                        type = "toggle", order = 4, width = "full",
                        name = "Show minimap button\n|cff9d9d9dToggle the minimap button (right-click it to hide).|r",
                        desc = "Toggle the minimap button (right-click it to hide).",
                        hidden = function() return not addon.MinimapButton end,
                        get = function() return addon.MinimapButton.isShown() end,
                        set = function(_, val) addon.MinimapButton.setShown(val) end,
                    },
                    alertGlow = cfgToggle(5, "Glow when button appears", "alertGlow",
                        "Briefly glow the button when a new quest item becomes usable."),
                    alertSound = cfgToggle(6, "Play a sound when button appears", "alertSound",
                        "Also play a short sound when a new quest item becomes usable."),
                },
            },
            behavior = {
                type = "group", inline = true, order = 2, name = "Behavior",
                args = {
                    intro = blurb("Which item shows when several are eligible, and integrations."),
                    proximity = cfgToggle(1, "Proximity: show nearest item", "proximity",
                        "When several usable items are in-zone, show the one whose quest objective is closest (needs Questie; falls back to super-tracked quest).",
                        function() refresh() end),
                    questie = cfgToggle(2, "Questie integration", "questie",
                        "Use Questie for nearest-item picking. Off: proximity falls back to the super-tracked quest, then scan order.",
                        function() refresh() end),
                    distanceGate = {
                        type = "toggle", order = 3, width = "full",
                        name = "Only show near the objective\n|cff9d9d9dHide until you are within the yards below of the quest objective. Requires Questie.|r",
                        desc = "Show the button only when you are within the distance below of the quest objective. Needs Questie for distance data; unavailable otherwise.",
                        disabled = function() return not (Config.get("questie") and addon.Proximity.available()) end,
                        get = function() return Config.get("distanceGate") end,
                        set = function(_, val) Config.set("distanceGate", val); refresh() end,
                    },
                    distanceYards = {
                        type = "range", order = 4, width = "full",
                        name = "Distance (yards)",
                        desc = "How close to the objective before the button appears.",
                        min = 10, max = 300, step = 10,
                        disabled = function()
                            return not (Config.get("questie") and addon.Proximity.available() and Config.get("distanceGate"))
                        end,
                        get = function() return Config.get("distanceYards") end,
                        set = function(_, val) Config.set("distanceYards", val); refresh() end,
                    },
                    bundledData = cfgToggle(5, "Use bundled quest data", "bundledData",
                        "Use the addon's shipped quest→zone table for edge cases the game gets wrong. Off: only your own learned/manual data is used.",
                        function() refresh() end),
                    hideComplete = cfgToggle(6, "Hide when quest complete", "hideComplete",
                        "Once all of the quest's objectives are finished, hide the button — you don't need the item anymore.",
                        function() refresh() end),
                    waypoint = {
                        type = "toggle", order = 6.5, width = "full",
                        name = "Waypoint to the objective\n|cff9d9d9dDrop a map waypoint at the quest objective while the button shows (TomTom if installed, else the native waypoint). Needs Questie for coordinates.|r",
                        desc = "Drop a map waypoint at the objective while the button shows. Uses TomTom if installed, else the native user waypoint. Needs Questie for coordinates.",
                        disabled = function() return not (addon.Waypoint.available() and addon.Proximity.available()) end,
                        get = function() return Config.get("waypoint") end,
                        set = function(_, val)
                            Config.set("waypoint", val)
                            if not val then addon.Waypoint.clear() end
                            refresh()
                        end,
                    },
                    learn = cfgToggle(7, "Learn quest-item zones", "learn",
                        "Watch where you actually use quest items and print a paste-ready override suggestion for zones the addon doesn't know. See /qib learned."),
                    debug = cfgToggle(8, "Debug logging", "debug",
                        "Print detailed debug messages to chat."),
                },
            },
            quests = {
                type = "group", order = 3, name = "Quests in log",
                desc = "Toggle which usable quest items may show.",
                args = questArgs(),  -- rebuilt each open (buildOptions is a function)
            },
            profiles = {
                type = "group", order = 4, name = "Profiles",
                args = {
                    intro = blurb("Settings are saved per profile; each character can use its own. A /reload fully applies a switch."),
                    current = {
                        type = "select", order = 1, width = "full", name = "Active profile",
                        desc = "Which profile this character uses.",
                        values = function()
                            local t = {}
                            for _, n in ipairs(Config.profileNames()) do t[n] = n end
                            return t
                        end,
                        get = function() return Config.currentProfile() end,
                        set = function(_, val) Config.setProfile(val); applyProfile() end,
                    },
                    new = {
                        type = "input", order = 2, name = "New profile",
                        desc = "Create a profile with this name and switch to it.",
                        get = function() return "" end,
                        set = function(_, val) Config.setProfile(val); applyProfile() end,
                    },
                    copy = {
                        type = "select", order = 3, name = "Copy from",
                        desc = "Copy another profile's settings into the current one.",
                        values = otherProfiles,
                        disabled = function() return not next(otherProfiles()) end,
                        get = function() end,
                        set = function(_, val) Config.copyProfile(val); applyProfile() end,
                    },
                    delete = {
                        type = "select", order = 4, name = "Delete profile",
                        desc = "Delete a profile (not the active one).",
                        values = otherProfiles,
                        disabled = function() return not next(otherProfiles()) end,
                        get = function() end,
                        set = function(_, val) Config.deleteProfile(val); applyProfile() end,
                    },
                    reset = {
                        type = "execute", order = 5, name = "Reset profile",
                        desc = "Reset the active profile to defaults.",
                        func = function() Config.resetProfile(); applyProfile() end,
                    },
                },
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
