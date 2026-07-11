local addonName, addon = ...
local Debug = addon.Debug

-- WoW shell: walk the quest log and emit candidate quest items.
-- A candidate exists only when the game flags the quest with a usable special
-- item (GetQuestLogSpecialItemInfo returns a link) — that IS our "usable quest
-- item in bags" signal. Feeds the pure Match.resolve.

local Scanner = {}
addon.Scanner = Scanner

-- returns list of { questID, itemID, itemName, headerZone, questIndex }
function Scanner.scan()
    local candidates = {}
    local headerZone
    local numEntries = GetNumQuestLogEntries()
    Debug.log("bag", "scan: %d quest-log entries", numEntries)
    for i = 1, numEntries do
        -- BCC signature: isHeader @4, questID @8
        local title, _, _, isHeader, _, _, _, questID = GetQuestLogTitle(i)
        if isHeader then
            headerZone = title
            Debug.log("bag", "  header -> zone '%s'", tostring(title))
        else
            local link = GetQuestLogSpecialItemInfo(i)
            if link then
                local itemID = tonumber(link:match("item:(%d+)"))
                local itemName = link:match("%[(.-)%]")
                if itemName then
                    candidates[#candidates + 1] = {
                        questID = questID,
                        itemID = itemID,
                        itemName = itemName,
                        headerZone = headerZone,
                        questIndex = i,
                    }
                    Debug.log("quest", "candidate %s (item %s, q%s) zone=%s",
                        itemName, tostring(itemID), tostring(questID), tostring(headerZone))
                else
                    Debug.log("quest", "  skip q%s: could not parse item name from link", tostring(questID))
                end
            end
        end
    end
    Debug.log("bag", "scan done: %d candidate(s)", #candidates)
    return candidates
end
