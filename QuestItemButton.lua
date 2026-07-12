local addonName, addon = ...
local Debug = addon.Debug
local Config = addon.Config
local Scanner = addon.Scanner
local Match = addon.Match
local Data = addon.Data
local Button = addon.Button
local Proximity = addon.Proximity
local Complete = addon.Complete
local Learn = addon.Learn

-- Entry point: drive re-evaluation off the relevant events, coalesced into a
-- single delayed tick, and hand off scan → match → button.

local RE_EVAL_EVENTS = {
    "BAG_UPDATE_DELAYED",
    "QUEST_LOG_UPDATE",
    "ZONE_CHANGED",
    "ZONE_CHANGED_NEW_AREA",
    "ZONE_CHANGED_INDOORS",
    "PLAYER_ENTERING_WORLD",
}

local evalPending = false

-- Overlay the user's per-quest disables (Config) onto the static Data table so
-- Match stays pure (it only knows about `overrides[q].disabled`).
local function effectiveOverrides()
    local base = Config.get("bundledData") and Data.overrides or {}
    local disabled = Config.get("disabledQuests")
    if not next(disabled) then
        return base
    end
    local merged = {}
    for q, o in pairs(base) do
        merged[q] = o
    end
    for q in pairs(disabled) do
        local o = merged[q]
        merged[q] = o and { zone = o.zone, subzone = o.subzone, priority = o.priority, disabled = true }
                      or { disabled = true }
    end
    return merged
end

-- Live-proximity ticker: only runs while 2+ items are in-zone AND proximity is
-- on, so there is zero idle cost when there is no tie to break.
-- ponytail: 2s full quest-log rescan while 2+ in-zone; fine at BCC log sizes.
local proximityTicker
local evaluate  -- forward declaration (ticker + manageTicker reference it)

local function manageTicker(inRange, inZone)
    -- Poll while a tie needs breaking (2+ in-range) OR the distance gate is on
    -- and there is anything in-zone to walk toward (even if none in-range yet).
    local want = (Config.get("proximity") and inRange > 1)
              or (Config.get("distanceGate") and (inZone or 0) >= 1)
    if want and not proximityTicker then
        Debug.log("event", "proximity ticker START (%d in-range, %d in-zone)", inRange, inZone or 0)
        proximityTicker = C_Timer.NewTicker(2, function() evaluate() end)
    elseif not want and proximityTicker then
        Debug.log("event", "proximity ticker STOP")
        proximityTicker:Cancel()
        proximityTicker = nil
    end
end

evaluate = function()
    evalPending = false
    local zone = GetRealZoneText()
    local subzone = GetSubZoneText()
    Debug.log("zone", "evaluate: zone='%s' subzone='%s'", tostring(zone), tostring(subzone))
    local candidates = Scanner.scan()

    -- User pin (right-click menu) beats every picker while its item is carried.
    -- A candidate exists only for a usable quest item in bags (see Scanner), so
    -- pin presence in the list == "in bags"; ignores zone/proximity entirely.
    local pinned = Config.get("pinned")
    if pinned then
        for _, c in ipairs(candidates) do
            if c.questID == pinned then
                Debug.log("quest", "pinned q%s -> %s (overrides pickers)", tostring(pinned), c.itemName)
                Button.apply(c)
                manageTicker(0)
                return
            end
        end
        Debug.log("quest", "pinned q%s not in bags -> normal resolve", tostring(pinned))
    end

    Proximity.useQuestie = Config.get("questie")
    local pickFn = Config.get("proximity") and Proximity.pick or nil

    -- questID -> questIndex, for gates that need the quest-log index.
    local indexOf = {}
    for _, c in ipairs(candidates) do indexOf[c.questID] = c.questIndex end

    -- Build the survival gates. A candidate survives only if EVERY gate passes.
    local gates = {}

    -- Distance gate: keep only items within distanceYards of their objective.
    -- Unknown distance (Questie can't answer) -> not gated out.
    if Config.get("distanceGate") then
        local yards = Config.get("distanceYards")
        gates[#gates + 1] = function(questID)
            local d = Proximity.questieDistance(questID)
            return d == nil or d <= yards
        end
    end

    -- Completion gate: drop the item once all the quest's objectives are done.
    if Config.get("hideComplete") then
        gates[#gates + 1] = function(questID)
            local idx = indexOf[questID]
            if not idx then return true end
            local lb = {}
            for i = 1, GetNumQuestLeaderBoards(idx) do
                local _, _, finished = GetQuestLogLeaderBoard(i, idx)
                lb[i] = { finished = finished }
            end
            return not Complete.isComplete(lb)
        end
    end

    local gateFn
    if #gates > 0 then
        gateFn = function(questID)
            for _, g in ipairs(gates) do
                if not g(questID) then return false end
            end
            return true
        end
    end

    local best, inRange, inZone = Match.resolve(candidates, zone, effectiveOverrides(), Debug.log, pickFn, gateFn, subzone)
    Button.apply(best)
    manageTicker(inRange, inZone)
end

-- coalesce bursts of events into one scan
local function scheduleEval()
    if evalPending then
        Debug.log("event", "eval already pending -> coalesced")
        return
    end
    evalPending = true
    Debug.log("event", "scheduling eval in 0.1s")
    C_Timer.After(0.1, evaluate)
end

-- Let the options panel trigger a re-evaluation after a setting changes.
addon.refresh = scheduleEval

-- Auto-learn: when the player uses a usable quest item, note the current zone
-- and print a paste-ready override line the user can drop into Data.lua. Matches
-- the fired spell against the quest items currently in the log.
-- ponytail: rescans the (small) quest log on each player cast while learn is on;
-- fine at BCC log sizes — cache an itemSpell->quest map if it ever shows up hot.
local function observeCast(spellID)
    if not Config.get("learn") or not spellID then return end
    local store = Config.get("learned")
    local knownFn = function(q) return Data.overrides[q] ~= nil end
    for _, c in ipairs(Scanner.scan()) do
        local _, itemSpellID = GetItemSpell(c.itemID)
        if itemSpellID == spellID then
            local zone = GetRealZoneText()
            if Learn.note(store, c.questID, zone, knownFn) then
                print(("|cffffd452QIB|r learned: [%d] = { zone = \"%s\" }  -- %s")
                    :format(c.questID, tostring(zone), c.itemName))
            end
            return
        end
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
for _, e in ipairs(RE_EVAL_EVENTS) do
    frame:RegisterEvent(e)
end

frame:SetScript("OnEvent", function(self, event, ...)
    Debug.log("event", "%s(%s)", event, strjoin(", ", tostringall(...)))
    if event == "PLAYER_LOGIN" then
        print("QuestItemButton initialized.")
        Button.applyKeybind()  -- SavedVariables now loaded
        scheduleEval()
    elseif event == "PLAYER_REGEN_ENABLED" then
        Debug.log("event", "combat ended -> flushing deferred button state")
        Button.flushPending()  -- apply anything deferred during combat
        Button.applyKeybind()  -- reapply any keybind change deferred by combat
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...
        if unit == "player" then observeCast(spellID) end
    else
        scheduleEval()
    end
end)

-- Slash: /qib debug on|off | lock | unlock | disable <questID>
SLASH_QIB1 = "/qib"
SlashCmdList.QIB = function(msg)
    local cmd, arg = msg:match("^(%S*)%s*(.-)$")
    if cmd == "" or cmd == "config" then
        addon.Options.open()
    elseif cmd == "debug" then
        Debug.setEnabled(arg ~= "off")
    elseif cmd == "lock" then
        Config.set("locked", true)
        print("|cffffd452QIB|r button locked")
    elseif cmd == "unlock" then
        Config.set("locked", false)
        print("|cffffd452QIB|r button unlocked (drag to move)")
    elseif cmd == "proximity" then
        Config.set("proximity", arg ~= "off")
        scheduleEval()
        print("|cffffd452QIB|r proximity " .. (arg ~= "off" and "ON (nearest item)" or "OFF (scan order)"))
    elseif cmd == "style" then
        Config.set("hideStyle", arg == "off")
        Button.updateStyle()
        print("|cffffd452QIB|r style " .. (arg == "off" and "hidden (minimal)" or "shown"))
    elseif cmd == "learned" then
        local store = Config.get("learned")
        local any = false
        for questID, zone in pairs(store) do
            any = true
            print(("|cffffd452QIB|r [%d] = { zone = \"%s\" },"):format(questID, tostring(zone)))
        end
        if not any then print("|cffffd452QIB|r no learned suggestions yet") end
    elseif cmd == "disable" then
        local questID = tonumber(arg)
        if questID then
            Config.setQuestDisabled(questID, true)
            print("|cffffd452QIB|r disabled quest " .. questID)
            scheduleEval()
        else
            print("|cffffd452QIB|r usage: /qib disable <questID>")
        end
    else
        print("|cffffd452QIB|r /qib (or /qib config) opens options. Also: debug on|off | lock | unlock | style on|off | proximity on|off | disable <questID> | learned")
    end
end
