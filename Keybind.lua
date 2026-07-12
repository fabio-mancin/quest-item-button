local addonName, addon = ...

-- Optional keybind that fires the quest item. The secure binding is WoW-only
-- (guarded, not unit-testable); only normalize() is pure and tested.

local Keybind = {}
if addon then addon.Keybind = Keybind end

-- Trim + uppercase a user key string; empty/non-string -> nil. Pure/testable.
function Keybind.normalize(key)
    if type(key) ~= "string" then return nil end
    key = key:gsub("%s+", ""):upper()
    if key == "" then return nil end
    return key
end

-- (Re)apply the override binding on `owner`, or clear it when key is nil.
-- Secure: refuses in combat (returns false) so the caller retries out of combat.
-- WoW-only — guarded so loading this file without the client is harmless.
function Keybind.apply(owner, key)
    if not (owner and ClearOverrideBindings and SetOverrideBindingClick) then return end
    if InCombatLockdown and InCombatLockdown() then return false end
    ClearOverrideBindings(owner)
    key = Keybind.normalize(key)
    if key then
        SetOverrideBindingClick(owner, true, key, "QuestItemButtonFrame", "LeftButton")
    end
    return true
end

return Keybind
