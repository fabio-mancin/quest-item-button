local addonName, addon = ...
local Debug = addon.Debug
local Config = addon.Config
local Alert = addon.Alert
local Keybind = addon.Keybind

-- WoW shell: our own secure action button styled like the Retail
-- QuestItemButton. Fires the bag quest item via type="item".
--
-- Combat rule: this is a PROTECTED frame, so in combat we can neither
-- SetAttribute nor Show/Hide it. apply() stashes the desired state and no-ops;
-- main flushes it on PLAYER_REGEN_ENABLED.

local Button = {}
addon.Button = Button

local RANGE_THROTTLE = 0.2  -- ~TOOLTIP_UPDATE_TIME
-- Classic action-slot border. (The Retail QuestItemButton "SpellPush-Frame"
-- art is a "PH" placeholder in this client build, so we use the standard
-- quickslot ring, which is the authentic Classic look and always present.)
local RING = "Interface\\Buttons\\UI-Quickslot2"

-- Bag API moved to C_Container in later builds; support both.
local NumSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
local ItemID   = (C_Container and C_Container.GetContainerItemID) or GetContainerItemID

-- Find the bag,slot currently holding itemID (nil if not carried).
local function findBagSlot(itemID)
    if not itemID or not NumSlots or not ItemID then return end
    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, (NumSlots(bag) or 0) do
            if ItemID(bag, slot) == itemID then
                return bag, slot
            end
        end
    end
end

local button              -- the secure frame
local currentState        -- candidate currently bound & shown, or nil
local pendingState        -- desired state deferred while in combat
local hasPending = false
local lastInRange         -- range state cache so we only log on change

-- ---- construction -------------------------------------------------------

local function savePosition(self)
    local point, _, _, x, y = self:GetPoint()
    Config.set("pos", { point = point, x = x, y = y })
end

local function restorePosition(self)
    local pos = Config.get("pos")
    self:ClearAllPoints()
    if pos then
        self:SetPoint(pos.point or "CENTER", UIParent, pos.point or "CENTER", pos.x or 0, pos.y or 0)
    else
        self:SetPoint("CENTER", UIParent, "CENTER", 0, -140)
    end
end

-- Hover tooltip: the item's own tooltip (game API), then the quest title +
-- objective lines below it.
local function showTooltip(self)
    if not currentState then return end
    local idx = currentState.questIndex
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetQuestLogSpecialItem(idx)

    GameTooltip:AddLine(" ")
    local title = GetQuestLogTitle(idx)
    GameTooltip:AddLine(title or currentState.itemName, 1, 0.82, 0)  -- quest header, gold
    for i = 1, GetNumQuestLeaderBoards(idx) do
        local text, _, finished = GetQuestLogLeaderBoard(i, idx)
        if text then
            if finished then
                GameTooltip:AddLine(" - " .. text, 0.2, 1, 0.2)   -- done, green
            else
                GameTooltip:AddLine(" - " .. text, 1, 0.5, 0.5)   -- todo, red
            end
        end
    end
    GameTooltip:Show()
end

-- Right-click menu: list every usable quest item in bags; picking one pins it
-- (Config.pinned) so it beats all pickers while carried. Re-picking the pinned
-- item, or "Auto", clears the pin. Insecure UI — safe to open anytime.
local menuFrame
local function openMenu(anchor)
    local Scanner = addon.Scanner
    local pinned = Config.get("pinned")
    local menu = { { text = "Show quest item", isTitle = true, notCheckable = true } }
    for _, c in ipairs(Scanner.scan()) do
        local qid = c.questID
        menu[#menu + 1] = {
            text = c.itemName,
            checked = (pinned == qid),
            func = function()
                Config.set("pinned", (pinned == qid) and nil or qid)
                if addon.refresh then addon.refresh() end
            end,
        }
    end
    if #menu == 1 then
        menu[#menu + 1] = { text = "No usable quest items in bags", notCheckable = true, disabled = true }
    elseif pinned then
        menu[#menu + 1] = { text = "Auto (clear pin)", notCheckable = true,
            func = function() Config.set("pinned", nil); if addon.refresh then addon.refresh() end end }
    end
    menuFrame = menuFrame or CreateFrame("Frame", "QuestItemButtonMenu", UIParent, "UIDropDownMenuTemplate")
    EasyMenu(menu, menuFrame, anchor, 0, 0, "MENU")
end

local function create()
    button = CreateFrame("Button", "QuestItemButtonFrame", UIParent, "SecureActionButtonTemplate")
    button:SetSize(52, 52)
    -- type1 only: left-click fires the item; right-click stays free for our menu.
    button:SetAttribute("type1", "item")
    -- Register both up AND down: SecureActionButton_OnClick fires the action on
    -- whichever edge the ActionButtonUseKeyDown CVar selects. Registering only
    -- "AnyUp" silently no-ops when that CVar is on. Both = fires exactly once.
    button:RegisterForClicks("AnyUp", "AnyDown")
    button:Hide()

    button.icon = button:CreateTexture(nil, "BACKGROUND")
    button.icon:SetPoint("TOPLEFT", 2, -2)
    button.icon:SetPoint("BOTTOMRIGHT", -2, 2)

    button.cooldown = CreateFrame("Cooldown", "QuestItemButtonFrameCooldown", button, "CooldownFrameTemplate")
    button.cooldown:SetAllPoints(button.icon)

    -- Action-slot ring overlay. UI-Quickslot2 is a 64x64 border framing the
    -- 52x52 icon; drawn slightly larger and centered, not stretched.
    button.style = button:CreateTexture(nil, "OVERLAY")
    button.style:SetTexture(RING)
    button.style:SetSize(66, 66)
    button.style:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.style:SetShown(not Config.get("hideStyle"))

    button.count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    button.count:SetPoint("BOTTOMRIGHT", -6, 6)

    -- click feedback so it reads as a real, interactable button
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")

    -- diagnostic: confirms the secure click reaches the button (insecure, safe)
    button:SetScript("PreClick", function()
        Debug.log("button", "click -> item attr '%s'", tostring(button:GetAttribute("item")))
    end)

    -- Right-click opens the pick menu (fires no secure action: no type2 set).
    -- Gate on the up edge: RegisterForClicks(AnyUp, AnyDown) fires PostClick on
    -- BOTH edges, so without this the menu opens on press then toggles shut on
    -- release -> looks broken.
    button:SetScript("PostClick", function(self, mouseButton, down)
        if mouseButton == "RightButton" and not down then
            openMenu(self)
        end
    end)

    -- tooltip: item (via the game's own special-item tooltip) + quest details
    button:SetScript("OnEnter", showTooltip)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- dragging (out of combat only; guarded)
    button:SetMovable(true)
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnDragStart", function(self)
        if not Config.get("locked") and not InCombatLockdown() then
            self:StartMoving()
        end
    end)
    button:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        savePosition(self)
        local pos = Config.get("pos")
        Debug.log("button", "moved -> %s %.0f,%.0f", pos.point, pos.x, pos.y)
    end)

    button:RegisterEvent("BAG_UPDATE_COOLDOWN")
    button:RegisterEvent("PLAYER_TARGET_CHANGED")
    button:SetScript("OnEvent", function(self, event)
        if event == "BAG_UPDATE_COOLDOWN" then
            Button.updateCooldown()
        elseif event == "PLAYER_TARGET_CHANGED" then
            self.rangeTimer = 0
        end
    end)

    button.rangeTimer = 0
    button:SetScript("OnUpdate", function(self, elapsed)
        if not currentState then return end
        self.rangeTimer = self.rangeTimer - elapsed
        if self.rangeTimer <= 0 then
            self.rangeTimer = RANGE_THROTTLE
            Button.updateRange()
        end
    end)

    restorePosition(button)
    Button.applyKeybind()
end

-- ---- visuals (allowed in combat: own regions, not protected ops) --------

-- (Re)apply the configured trigger keybind. Returns false if deferred by combat
-- (main retries on PLAYER_REGEN_ENABLED). Safe to call before/after create().
function Button.applyKeybind()
    if not button then return end
    return Keybind.apply(button, Config.get("keybind"))
end

-- Reset to default anchor and persist (used by the options "Reset position").
function Button.resetPosition()
    Config.set("pos", nil)
    restorePosition(button)
    Debug.log("button", "position reset to default")
end

-- Show/hide the Blizzard ring overlay (minimal-UI toggle).
function Button.updateStyle()
    if button and button.style then
        button.style:SetShown(not Config.get("hideStyle"))
        Debug.log("button", "style %s", Config.get("hideStyle") and "hidden" or "shown")
    end
end

function Button.updateCooldown()
    if not currentState then return end
    local start, duration, enable = GetQuestLogSpecialItemCooldown(currentState.questIndex)
    if start then
        CooldownFrame_Set(button.cooldown, start, duration, enable)
        if duration and duration > 0 then
            Debug.log("button", "cooldown set: %.1fs (enable=%s)", duration, tostring(enable))
        end
    end
end

function Button.updateRange()
    if not currentState then return end
    local inRange = IsQuestLogSpecialItemInRange(currentState.questIndex)
    if inRange == 0 then
        button.icon:SetVertexColor(1, 0.3, 0.3)  -- out of range
    else
        button.icon:SetVertexColor(1, 1, 1)      -- in range or no range requirement
    end
    if inRange ~= lastInRange then
        lastInRange = inRange
        Debug.log("button", "range -> %s", inRange == 0 and "OUT" or (inRange == 1 and "IN" or "n/a"))
    end
end

-- ---- state application --------------------------------------------------

-- Brief attention pull when a (new) item starts showing. Insecure regions only.
local function fireAlert()
    if Config.get("alertGlow") and ActionButton_ShowOverlayGlow then
        ActionButton_ShowOverlayGlow(button)
        C_Timer.After(1.5, function()
            if ActionButton_HideOverlayGlow then ActionButton_HideOverlayGlow(button) end
        end)
    end
    if Config.get("alertSound") and SOUNDKIT then
        PlaySound(SOUNDKIT.MAP_PING)
    end
end

local function applyNow(state)
    local prevID = currentState and currentState.questID
    currentState = state
    lastInRange = nil
    if not state then
        if button:IsShown() then
            Debug.log("button", "hide (no match)")
        end
        button:Hide()
        if Config.get("waypoint") then addon.Waypoint.clear() end
        return
    end
    -- Bind to the concrete bag slot (exact right-click equivalent). Binding by
    -- item *name* goes through SecureCmdUseItem's name lookup, which can silently
    -- no-op when the quest-link name mismatches the bag item's real name.
    -- Fall back to name only if the item can't be located in bags.
    local bag, slot = findBagSlot(state.itemID)
    if bag then
        button:SetAttribute("item", bag .. " " .. slot)
        Debug.log("button", "bind bag %d slot %d (item %s)", bag, slot, tostring(state.itemID))
    else
        button:SetAttribute("item", state.itemName)
        Debug.log("button", "bind by name '%s' (not found in bags)", tostring(state.itemName))
    end

    -- texture + charges come straight from the game for this quest index.
    -- byItem (unflagged) candidates return no special-item texture -> fall back
    -- to the plain item icon so the button isn't blank.
    local _, texture, charges = GetQuestLogSpecialItemInfo(state.questIndex)
    texture = texture or GetItemIcon(state.itemID)
    button.icon:SetTexture(texture)
    button.icon:SetVertexColor(1, 1, 1)
    if charges and charges > 1 then
        button.count:SetText(charges)
        button.count:Show()
    else
        button.count:Hide()
    end
    Button.updateCooldown()
    button.rangeTimer = 0
    button:Show()
    -- Only act on an actual item change (not every proximity re-apply).
    if Alert.shouldAlert(prevID, state.questID) then
        fireAlert()
        if Config.get("waypoint") then
            addon.Waypoint.clear()
            local m, x, y = addon.Proximity.questieSpawn(state.questID)
            if m then
                addon.Waypoint.set(m, x, y, state.itemName)
                Debug.log("button", "waypoint set for q%s", tostring(state.questID))
            end
        end
    end
    Debug.log("button", "show %s (q%s)", state.itemName, tostring(state.questID))
end

-- Public: set desired state (winning candidate or nil). Defers in combat.
function Button.apply(state)
    if InCombatLockdown() then
        pendingState = state
        hasPending = true
        Debug.log("button", "deferred (combat)")
        return
    end
    applyNow(state)
end

-- Public: called on PLAYER_REGEN_ENABLED to flush a combat-deferred change.
function Button.flushPending()
    if hasPending then
        hasPending = false
        Debug.log("button", "flushing deferred state -> %s", pendingState and pendingState.itemName or "hide")
        applyNow(pendingState)
        pendingState = nil
    end
end

create()
