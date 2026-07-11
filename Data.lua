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

local Data = {}
addon.Data = Data

Data.overrides = {
    -- [11162] = { zone = "Netherstorm" },  -- example: Conjurer Luminrath
}

Data.byItem = {
    -- [32449] = 11162,  -- example: Luminrath's Mantle → quest
    [28786] = 10256,     -- Apex's Crystal Focus → "Finding the Keymaster" (Netherstorm)
}
