local addonName, addon = ...
local Debug = addon.Debug
local Config = addon.Config
local Scanner = addon.Scanner
local Match = addon.Match
local Data = addon.Data
local Button = addon.Button
local Proximity = addon.Proximity

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
    local disabled = Config.get("disabledQuests")
    if not next(disabled) then
        return Data.overrides
    end
    local merged = {}
    for q, o in pairs(Data.overrides) do
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

local function manageTicker(count)
    local want = Config.get("proximity") and count > 1
    if want and not proximityTicker then
        Debug.log("event", "proximity ticker START (%d in-zone)", count)
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
    Debug.log("zone", "evaluate: zone='%s' subzone='%s'", tostring(zone), tostring(GetSubZoneText()))
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
    local best, count = Match.resolve(candidates, zone, effectiveOverrides(), Debug.log, pickFn)
    Button.apply(best)
    manageTicker(count)
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

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
for _, e in ipairs(RE_EVAL_EVENTS) do
    frame:RegisterEvent(e)
end

frame:SetScript("OnEvent", function(self, event, ...)
    Debug.log("event", "%s(%s)", event, strjoin(", ", tostringall(...)))
    if event == "PLAYER_LOGIN" then
        print("QuestItemButton initialized.")
        scheduleEval()
    elseif event == "PLAYER_REGEN_ENABLED" then
        Debug.log("event", "combat ended -> flushing deferred button state")
        Button.flushPending()  -- apply anything deferred during combat
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
        print("|cffffd452QIB|r /qib (or /qib config) opens options. Also: debug on|off | lock | unlock | style on|off | proximity on|off | disable <questID>")
    end
end
