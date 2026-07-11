local addonName, addon = ...
-- addon may be nil when loaded outside the client (self-check); guard it.
local Debug = addon and addon.Debug
local Match = addon and addon.Match

-- Proximity tiebreak: a drop-in for Match.pickBest that prefers the item whose
-- quest objective is nearest the player. Questie is an OPTIONAL soft-dependency
-- — reached only through pcall + nil-checks, so this file is safe to load with
-- no Questie (or no WoW at all). Ladder:
--   1. Questie nearest-objective distance
--   2. native super-tracked quest
--   3. Match.pickBest (override priority -> scan order)

local Proximity = {}
if addon then addon.Proximity = Proximity end

-- In-client Match comes from `addon`; the standalone self-check injects it here.
function Proximity.setMatch(m) Match = m end

local function log(...)
    if Debug then Debug.log(...) end
end

-- Lazily import Questie's distance engine. Returns QuestieDB, DistanceUtils or nil.
local function questie()
    if not (QuestieLoader and Questie and Questie.API and Questie.API.isReady) then
        return nil
    end
    local ok, db, dist = pcall(function()
        return QuestieLoader:ImportModule("QuestieDB"),
               QuestieLoader:ImportModule("DistanceUtils")
    end)
    if ok and db and dist then return db, dist end
    return nil
end

-- Nearest by Questie objective distance. nil if Questie can't answer for any.
local function byQuestieDistance(survivors)
    local QuestieDB, DistanceUtils = questie()
    if not QuestieDB then return nil end

    local best, bestDist
    for _, s in ipairs(survivors) do
        local ok, dist = pcall(function()
            local q = QuestieDB.GetQuest(s.questID)
            if not q then return nil end
            local _, _, _, d = DistanceUtils.GetNearestSpawnForQuest(q)
            return d
        end)
        if ok and dist then
            log("quest", "  proximity q%s dist=%.0f", tostring(s.questID), dist)
            if not bestDist or dist < bestDist then
                best, bestDist = s.candidate, dist
            end
        end
    end
    if best then
        log("button", "proximity: nearest -> %s", best.itemName)
    end
    return best
end

-- Native fallback: the quest the player is actively super-tracking.
local function bySuperTrack(survivors)
    if type(GetSuperTrackedQuestID) ~= "function" then return nil end
    local st = GetSuperTrackedQuestID()
    if not st or st == 0 then return nil end
    for _, s in ipairs(survivors) do
        if s.questID == st then
            log("button", "proximity: super-tracked -> %s", s.candidate.itemName)
            return s.candidate
        end
    end
    return nil
end

-- Drop-in replacement for Match.pickBest.
function Proximity.pick(survivors, overrides)
    return byQuestieDistance(survivors)
        or bySuperTrack(survivors)
        or Match.pickBest(survivors, overrides)
end

return Proximity
