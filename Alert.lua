local addonName, addon = ...

-- Pure decision for the appear-alert: should we flash/ping now? NO WoW globals
-- — the shell owns the glow/sound; this just decides on the state transition.

local Alert = {}
if addon then addon.Alert = Alert end

-- Fire when a (different) item is now showing: nil -> item, or item -> other
-- item. Re-showing the SAME item (prevID == nextID) does not re-alert, and
-- hiding (nextID == nil) never alerts.
function Alert.shouldAlert(prevID, nextID)
    return nextID ~= nil and nextID ~= prevID
end

return Alert
