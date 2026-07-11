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
-- returns: winner candidate (or nil), number of in-zone survivors.
function Match.resolve(candidates, currentZone, overrides, log, pickFn)
    overrides = overrides or {}
    log = log or function() end
    pickFn = pickFn or pickBest
    local survivors = {}
    for i, c in ipairs(candidates) do
        local o = overrides[c.questID]
        if o and o.disabled then
            log("quest", "  drop %s (q%s): disabled", c.itemName, tostring(c.questID))
        else
            local gateZone = (o and o.zone) or c.headerZone
            if gateZone and gateZone == currentZone then
                log("quest", "  pass %s (q%s): zone '%s' matches", c.itemName, tostring(c.questID), tostring(gateZone))
                survivors[#survivors + 1] = { candidate = c, questID = c.questID, order = i }
            else
                log("quest", "  drop %s (q%s): zone '%s' != '%s'",
                    c.itemName, tostring(c.questID), tostring(gateZone), tostring(currentZone))
            end
        end
    end
    local best = pickFn(survivors, overrides)
    log("quest", "resolve: %d candidate(s), %d in-zone -> %s",
        #candidates, #survivors, best and best.itemName or "NONE")
    return best, #survivors
end

return Match
