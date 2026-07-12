local addonName, addon = ...
local Config = addon.Config

-- Minimap button via LibDataBroker launcher + LibDBIcon. The lib owns dragging,
-- edge-snapping and the hide toggle; it persists into Config's `minimap` table.

local APP = "QuestItemButton"
local LDB = LibStub("LibDataBroker-1.1", true)
local DBIcon = LibStub("LibDBIcon-1.0", true)
if not (LDB and DBIcon) then return end  -- libs missing -> no minimap button, addon still works

local launcher = LDB:NewDataObject(APP, {
    type = "launcher",
    icon = "Interface\\Icons\\INV_Misc_Note_01",
    OnClick = function(_, button)
        if button == "RightButton" then
            Config.get("minimap").hide = true
            DBIcon:Hide(APP)
        else
            addon.Options.open()
        end
    end,
    OnTooltipShow = function(tt)
        tt:AddLine(APP)
        tt:AddLine("|cffffffffLeft-click|r open options", 0.8, 0.8, 0.8)
        tt:AddLine("|cffffffffRight-click|r hide this button", 0.8, 0.8, 0.8)
    end,
})

DBIcon:Register(APP, launcher, Config.get("minimap"))

local MinimapButton = {}
addon.MinimapButton = MinimapButton

-- Options toggle uses these; `hidden` is stored in the lib's minimap table.
function MinimapButton.isShown()
    return not Config.get("minimap").hide
end

function MinimapButton.setShown(shown)
    Config.get("minimap").hide = not shown
    if shown then DBIcon:Show(APP) else DBIcon:Hide(APP) end
end
