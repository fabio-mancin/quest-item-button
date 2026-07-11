local addonName, addon = ...

-- Colorful debug logging. Toggle with /qib debug on|off (persists in DB).
-- addon.Debug.log(category, "msg %d", 42) → colored chat line, only when enabled.

local COLORS = {
    event  = "ff7fd4ff", -- blue-ish: game events
    bag    = "ffffd452", -- gold: bag/item scans
    quest  = "ff7fff7f", -- green: quest log
    zone   = "ffff9f52", -- orange: zone changes
    button = "ffff7f7f", -- red: secure button show/hide
    info   = "ffffffff", -- white: generic
}

local Debug = {}
addon.Debug = Debug

function Debug.isEnabled()
    return QuestItemButtonDB and QuestItemButtonDB.debug
end

function Debug.setEnabled(on)
    QuestItemButtonDB = QuestItemButtonDB or {}
    QuestItemButtonDB.debug = not not on
    print("|cffffd452QIB|r debug " .. (on and "ON" or "OFF"))
end

function Debug.log(category, fmt, ...)
    if not Debug.isEnabled() then return end
    local color = COLORS[category] or COLORS.info
    local msg = select("#", ...) > 0 and fmt:format(...) or fmt
    print(("|c%s[QIB:%s]|r %s"):format(color, category, msg))
end
