local addonName, addon = ...

-- Pure matching logic. NO WoW globals here — this file is unit-tested with
-- busted by requiring it directly. (In-client it is loaded via the .toc and
-- attaches to `addon`; the trailing `return` is only for require().)

local Match = {}
if addon then addon.Match = Match end

-- Pick the single winner among zone-matched candidates.
-- Lower override priority wins; ties break by original scan order.
-- Isolated so a proximity strategy can replace it later (Questie soft-dep).
local function pickBest(survivors, overrides)
    local best, bestPri, bestOrder
    for _, s in ipairs(survivors) do
        local pri = (overrides[s.questID] and overrides[s.questID].priority) or math.huge
        if not best or pri < bestPri or (pri == bestPri and s.order < bestOrder) then
            best, bestPri, bestOrder = s.candidate, pri, s.order
        end
    end
    return best
end
Match.pickBest = pickBest

-- candidates: list of { questID, itemID, itemName, headerZone, questIndex }
-- currentZone: GetRealZoneText() string
-- overrides: Data.overrides ({ [questID] = { zone, disabled, priority } })
-- log: optional function(category, fmt, ...) for tracing gate decisions
--      (kept as a param so Match has zero WoW deps and stays unit-testable).
-- pickFn: optional (survivors, overrides) -> candidate; defaults to pickBest.
--         The proximity strategy is injected here from the shell (Questie soft-dep).
-- gateFn: optional (questID) -> bool; a zone-passing candidate survives only if
--         it returns true. Defaults to always-true. The distance gate is injected
--         here from the shell (Questie soft-dep), keeping Match WoW-free.
-- currentSubZone: optional GetSubZoneText() string. Some quests are logged under a
--         subzone header (e.g. "Skettis") whose parent zone GetRealZoneText() reports
--         instead ("Terokkar Forest"); the gate passes on either match.
-- returns: winner candidate (or nil), in-range survivor count, in-zone count.
function Match.resolve(candidates, currentZone, overrides, log, pickFn, gateFn, currentSubZone)
    overrides = overrides or {}
    log = log or function() end
    pickFn = pickFn or pickBest
    gateFn = gateFn or function() return true end
    local survivors = {}
    local inZone = 0  -- zone-passing count before the distance gate
    for i, c in ipairs(candidates) do
        local o = overrides[c.questID]
        if o and o.disabled then
            log("quest", "  drop %s (q%s): disabled", c.itemName, tostring(c.questID))
        else
            local gateZone = (o and o.zone) or c.headerZone
            if gateZone and (gateZone == currentZone or gateZone == currentSubZone) then
                inZone = inZone + 1
                if gateFn(c.questID) then
                    log("quest", "  pass %s (q%s): zone '%s' matches", c.itemName, tostring(c.questID), tostring(gateZone))
                    survivors[#survivors + 1] = { candidate = c, questID = c.questID, order = i }
                else
                    log("quest", "  drop %s (q%s): out of range", c.itemName, tostring(c.questID))
                end
            else
                log("quest", "  drop %s (q%s): zone '%s' != '%s'/'%s'",
                    c.itemName, tostring(c.questID), tostring(gateZone),
                    tostring(currentZone), tostring(currentSubZone))
            end
        end
    end
    local best = pickFn(survivors, overrides)
    log("quest", "resolve: %d candidate(s), %d in-zone, %d in-range -> %s",
        #candidates, inZone, #survivors, best and best.itemName or "NONE")
    return best, #survivors, inZone
end

return Match
