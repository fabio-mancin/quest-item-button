local addonName, addon = ...

-- Pure predicate: is a quest's objective set fully finished? NO WoW globals —
-- the shell reads the leaderboards from the client and passes them in, so this
-- stays unit-testable (like Match.lua / Proximity.lua).

local Complete = {}
if addon then addon.Complete = Complete end

-- leaderboards: list of { finished = bool }.
-- Returns true only when there is at least one objective and ALL are finished.
-- Empty list -> false, so quests with no trackable objectives are never
-- auto-hidden (we can't tell they're done, so we leave the item available).
function Complete.isComplete(leaderboards)
    if not leaderboards or #leaderboards == 0 then
        return false
    end
    for _, lb in ipairs(leaderboards) do
        if not lb.finished then
            return false
        end
    end
    return true
end

return Complete
