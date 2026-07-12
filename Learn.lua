local addonName, addon = ...

-- Pure core for the "learn where quest items get used" feature. NO WoW globals
-- — the shell observes item use + current zone and calls note(); this file just
-- maintains the suggestion store and decides what's new. Unit-testable.

local Learn = {}
if addon then addon.Learn = Learn end

-- Record that questID's item was used in `zone`.
--   store   : table mutated in place (questID -> zone), persisted by the shell
--   knownFn : optional (questID) -> bool; true = already covered by shipped data,
--             so it's not worth suggesting.
-- Returns true only when this is a NEW or CHANGED suggestion worth surfacing
-- (so the shell prints the paste-ready line exactly once per discovery).
function Learn.note(store, questID, zone, knownFn)
    if not questID or not zone or zone == "" then
        return false
    end
    if knownFn and knownFn(questID) then
        return false
    end
    if store[questID] == zone then
        return false          -- already learned this exact zone
    end
    store[questID] = zone
    return true
end

return Learn
