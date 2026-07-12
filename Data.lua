local addonName, addon = ...

-- Override table for quest→zone edge cases the auto-detection gets wrong.
-- Plain data, no WoW globals, so Match stays unit-testable.
--
-- Auto-detection already handles the common case (game-flagged usable quest
-- item + the quest's log-header zone). Only add entries here when:
--   * the item is used in a different zone than its quest header, or
--   * you want to force disable / re-prioritise, or
--   * the game doesn't flag an item as usable (use byItem to attach it).
--
-- Shape:
--   overrides[questID] = {
--     zone     = "Netherstorm",  -- exact GetRealZoneText() string; beats header
--     subzone  = "Manaforge Ultris", -- optional, reserved (zone-level gating in v1)
--     priority = 1,              -- lower wins in pickBest; default = math.huge
--     disabled = true,           -- never show this quest's item
--   }
--   byItem[itemID] = questID     -- escape hatch: map an item to a quest manually

-- addon is nil when required outside the client (validator spec); guard it so
-- Data.lua stays require()-able like Match.lua / Proximity.lua.
local Data = {}
if addon then addon.Data = Data end

Data.overrides = {
    -- [11162] = { zone = "Netherstorm" },  -- example: Conjurer Luminrath
    -- Fires over Skettis: logged under subzone "Skettis", but used while flying
    -- all over Terokkar (Skettis / Blackwind Lake / Veil Ar'ak) — gate on the
    -- whole real zone so it stays available as the subzone flips.
    [11008] = { zone = "Terokkar Forest" },
}

Data.byItem = {
    -- [32449] = 11162,  -- example: Luminrath's Mantle → quest
    [28786] = 10256,     -- Apex's Crystal Focus → "Finding the Keymaster" (Netherstorm)
}

return Data
