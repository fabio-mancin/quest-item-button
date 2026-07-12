local addonName, addon = ...

-- Optional map waypoint at the quest objective. The backend pick (provider) is
-- pure and unit-tested; set/clear are WoW-only and guarded (verified in-game).

local Waypoint = {}
if addon then addon.Waypoint = Waypoint end

-- Choose the backend: TomTom preferred (arrow + crazy-taxi), else the native
-- user waypoint, else nothing. Pure/testable.
function Waypoint.provider(hasTomTom, hasNative)
    if hasTomTom then return "tomtom" end
    if hasNative then return "native" end
    return nil
end

-- ---- WoW-only below (guarded; not unit-tested) --------------------------

function Waypoint.hasTomTom()
    return TomTom ~= nil and type(TomTom.AddWaypoint) == "function"
end

function Waypoint.hasNative()
    return C_Map ~= nil and type(C_Map.SetUserWaypoint) == "function"
        and UiMapPoint ~= nil
end

function Waypoint.available()
    return Waypoint.hasTomTom() or Waypoint.hasNative()
end

local activeTomTom  -- handle for RemoveWaypoint

-- Set a waypoint. mapID = UI map id, x/y = 0-1 fractions.
function Waypoint.set(mapID, x, y, title)
    if not (mapID and x and y) then return end
    local p = Waypoint.provider(Waypoint.hasTomTom(), Waypoint.hasNative())
    if p == "tomtom" then
        activeTomTom = TomTom:AddWaypoint(mapID, x, y, { title = title, from = "QuestItemButton" })
    elseif p == "native" then
        local pos = UiMapPoint.CreateFromCoordinates(mapID, x, y)
        C_Map.SetUserWaypoint(pos)
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
            C_SuperTrack.SetSuperTrackedUserWaypoint(true)
        end
    end
end

function Waypoint.clear()
    if activeTomTom and TomTom and TomTom.RemoveWaypoint then
        pcall(TomTom.RemoveWaypoint, TomTom, activeTomTom)
        activeTomTom = nil
    end
    if C_Map and C_Map.ClearUserWaypoint then
        C_Map.ClearUserWaypoint()
    end
end

return Waypoint
