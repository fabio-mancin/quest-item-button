local addonName, addon = ...
local Debug = addon.Debug

-- Thin accessor over the QuestItemButtonDB SavedVariable.
-- Single funnel for every persisted read/write so an Ace3/AceDB backend can
-- drop in later without touching call sites.

local DEFAULTS = {
    pos = nil,               -- {point, x, y}; nil = default center-ish anchor
    locked = false,          -- button drag locked
    hideStyle = false,       -- hide the Blizzard QuestItemButton ring (minimal look)
    pinned = nil,            -- questID pinned via right-click menu; beats all pickers while carried
    proximity = true,        -- pick nearest item (Questie) when several are in-zone
    questie = true,          -- allow Questie integration for proximity (else super-track/scan-order)
    disabledQuests = {},     -- [questID] = true
    debug = false,
}

local Config = {}
addon.Config = Config

-- ponytail: shallow default merge, DB is one flat level + two small tables
local function ensure()
    QuestItemButtonDB = QuestItemButtonDB or {}
    local db = QuestItemButtonDB
    for k, v in pairs(DEFAULTS) do
        if db[k] == nil then
            db[k] = (type(v) == "table") and {} or v
        end
    end
    return db
end

function Config.get(key)
    return ensure()[key]
end

function Config.set(key, val)
    ensure()[key] = val
    Debug.log("info", "config set %s = %s", key, tostring(val))
end

function Config.isQuestDisabled(questID)
    return ensure().disabledQuests[questID] == true
end

function Config.setQuestDisabled(questID, disabled)
    ensure().disabledQuests[questID] = disabled or nil
    Debug.log("info", "config quest %s disabled = %s", tostring(questID), tostring(disabled and true or false))
end
