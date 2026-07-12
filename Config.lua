local addonName, addon = ...
-- addon is nil when required outside the client (config spec); stub Debug so the
-- funnel stays WoW-free and unit-testable.
local Debug = (addon and addon.Debug) or { log = function() end }

-- Funnel over the QuestItemButtonDB SavedVariable, now with named profiles.
-- Layout:
--   QuestItemButtonDB = {
--     profiles    = { ["Default"] = {settings...}, ["Alt"] = {...} },
--     profileKeys = { ["Char - Realm"] = "Default" },  -- which profile a char uses
--     minimap     = { ... },  -- account-wide (LibDBIcon owns it; see below)
--   }
-- Everything routes through get/set so call sites never see the layout, and the
-- profile logic stays pure (WoW-free) so it's unit-tested in spec/config_spec.lua.

-- Per-profile settings.
local DEFAULTS = {
    pos = nil,               -- {point, x, y}; nil = default center-ish anchor
    locked = false,          -- button drag locked
    keybind = nil,           -- optional key that fires the quest item (override binding)
    hideStyle = false,       -- hide the Blizzard QuestItemButton ring (minimal look)
    alertGlow = true,        -- glow the button briefly when it first appears
    alertSound = false,      -- play a sound when the button first appears
    pinned = nil,            -- questID pinned via right-click menu; beats all pickers while carried
    bundledData = true,      -- use the shipped Data.overrides/byItem table (off = user data only)
    proximity = true,        -- pick nearest item (Questie) when several are in-zone
    questie = true,          -- allow Questie integration for proximity (else super-track/scan-order)
    distanceGate = false,    -- only show when within distanceYards of the objective (needs Questie)
    distanceYards = 100,     -- gate radius in yards
    hideComplete = true,     -- hide the button once all the quest's objectives are finished
    waypoint = false,        -- drop a map waypoint at the objective while shown (TomTom/native)
    disabledQuests = {},     -- [questID] = true
    learn = true,            -- watch quest-item use and suggest override entries
    learned = {},            -- [questID] = zone; suggestions gathered from actual use
    debug = false,
}

-- Account-wide keys (shared across profiles). minimap is here because LibDBIcon
-- captures its table by reference at load and shouldn't swap under it.
local ACCOUNT = {
    minimap = {},            -- LibDBIcon position/hide state (lib owns the contents)
}

local DEFAULT_PROFILE = "Default"

local Config = {}
if addon then addon.Config = Config end

-- Identifies which profile the current character uses. Overridable so the spec
-- can pin a deterministic key without WoW globals.
function Config.charKey()
    if UnitName and GetRealmName then
        return (UnitName("player") or "?") .. " - " .. (GetRealmName() or "?")
    end
    return DEFAULT_PROFILE
end

-- Root of the SavedVariable, with a one-time migration from the old flat layout
-- (settings sat directly at the root) into profiles.Default.
local function root()
    QuestItemButtonDB = QuestItemButtonDB or {}
    local db = QuestItemButtonDB
    if not db.profiles then
        local flat = {}
        for k in pairs(DEFAULTS) do          -- lift any old flat settings
            flat[k] = db[k]
            db[k] = nil
        end
        db.profiles = { [DEFAULT_PROFILE] = flat }
    end
    db.profileKeys = db.profileKeys or {}
    return db
end

local function currentProfileName()
    local db = root()
    return db.profileKeys[Config.charKey()] or DEFAULT_PROFILE
end

-- The active profile table, defaults filled in.
local function profile()
    local db = root()
    local name = currentProfileName()
    local p = db.profiles[name]
    if not p then p = {}; db.profiles[name] = p end
    for k, v in pairs(DEFAULTS) do
        if p[k] == nil then p[k] = (type(v) == "table") and {} or v end
    end
    return p
end

-- Account-wide table for a key, default filled in.
local function account(key)
    local db = root()
    if db[key] == nil then db[key] = (type(ACCOUNT[key]) == "table") and {} or ACCOUNT[key] end
    return db
end

-- ---- settings API (unchanged signatures) --------------------------------

function Config.get(key)
    if ACCOUNT[key] ~= nil then return account(key)[key] end
    return profile()[key]
end

function Config.set(key, val)
    if ACCOUNT[key] ~= nil then
        account(key)[key] = val
    else
        profile()[key] = val
    end
    Debug.log("info", "config set %s = %s", key, tostring(val))
end

function Config.isQuestDisabled(questID)
    return profile().disabledQuests[questID] == true
end

function Config.setQuestDisabled(questID, disabled)
    profile().disabledQuests[questID] = disabled or nil
    Debug.log("info", "config quest %s disabled = %s", tostring(questID), tostring(disabled and true or false))
end

-- ---- profile management -------------------------------------------------

-- Shallow table copy; local so it works outside the client too (no _G pollution).
local function copyShallow(t)
    local c = {}
    for k, v in pairs(t) do c[k] = v end
    return c
end

-- Sorted list of existing profile names.
function Config.profileNames()
    local db = root()
    local names = {}
    for name in pairs(db.profiles) do names[#names + 1] = name end
    table.sort(names)
    return names
end

function Config.currentProfile()
    return currentProfileName()
end

-- Switch the current character to `name`, creating the profile if new.
function Config.setProfile(name)
    if not name or name == "" then return end
    local db = root()
    db.profileKeys[Config.charKey()] = name
    if not db.profiles[name] then db.profiles[name] = {} end
    Debug.log("info", "profile -> %s", name)
end

-- Copy all settings from `fromName` into the current profile (no-op if missing/self).
function Config.copyProfile(fromName)
    local db = root()
    local src = db.profiles[fromName]
    if not src or fromName == currentProfileName() then return end
    local dst = profile()
    for k in pairs(DEFAULTS) do dst[k] = nil end          -- clear to source's shape
    for k, v in pairs(src) do
        dst[k] = (type(v) == "table") and copyShallow(v) or v
    end
    Debug.log("info", "profile copied from %s", fromName)
end

-- Reset the current profile to defaults.
function Config.resetProfile()
    local db = root()
    db.profiles[currentProfileName()] = {}
    profile()  -- refill defaults
    Debug.log("info", "profile reset")
end

-- Delete a profile. Refuses to delete the current one or the last remaining one.
function Config.deleteProfile(name)
    local db = root()
    if name == currentProfileName() or not db.profiles[name] then return end
    if #Config.profileNames() <= 1 then return end
    db.profiles[name] = nil
    for charKey, pname in pairs(db.profileKeys) do
        if pname == name then db.profileKeys[charKey] = nil end  -- fall back to Default
    end
    Debug.log("info", "profile deleted: %s", name)
end

return Config
