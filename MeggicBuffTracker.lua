MeggicBuffTrackerDB = MeggicBuffTrackerDB or { buffs = {}, x = 0, y = 0 }
local trackedBuffs = {}
local buffStartTimes = {}
local configFrame -- forward declaration so cogBtn can reference it before it's built

-- Find and use an item from bags
local function UseItemFromBags(itemName)
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local link = GetContainerItemLink(bag, slot)
            if link and strfind(link, itemName) then
                UseContainerItem(bag, slot)
                return true
            end
        end
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cffff0000MeggicBuffTracker:|r " .. itemName .. " not found in bags.")
    return false
end

-- Format time as mm:ss or h:mm:ss
local function FormatTime(seconds)
    if seconds <= 0 then return "0:00" end
    local hours = floor(seconds / 3600)
    local mins = floor(mod(seconds, 3600) / 60)
    local secs = floor(mod(seconds, 60))
    if hours > 0 then
        return format("%d:%02d:%02d", hours, mins, secs)
    else
        return format("%d:%02d", mins, secs)
    end
end

-- Single <-> group buff name aliases.
-- If you track either form, the other will also satisfy the check.
local buffAliases = {
    -- Priest
    ["Power Word: Fortitude"]         = "Prayer of Fortitude",
    ["Prayer of Fortitude"]           = "Power Word: Fortitude",
    ["Divine Spirit"]                 = "Prayer of Spirit",
    ["Prayer of Spirit"]              = "Divine Spirit",
    ["Shadow Protection"]             = "Prayer of Shadow Protection",
    ["Prayer of Shadow Protection"]   = "Shadow Protection",
    -- Paladin
    ["Blessing of Kings"]             = "Greater Blessing of Kings",
    ["Greater Blessing of Kings"]     = "Blessing of Kings",
    ["Blessing of Wisdom"]            = "Greater Blessing of Wisdom",
    ["Greater Blessing of Wisdom"]    = "Blessing of Wisdom",
    ["Blessing of Might"]             = "Greater Blessing of Might",
    ["Greater Blessing of Might"]     = "Blessing of Might",
    ["Blessing of Salvation"]         = "Greater Blessing of Salvation",
    ["Greater Blessing of Salvation"] = "Blessing of Salvation",
    ["Blessing of Sanctuary"]         = "Greater Blessing of Sanctuary",
    ["Greater Blessing of Sanctuary"] = "Blessing of Sanctuary",
    ["Blessing of Light"]             = "Greater Blessing of Light",
    ["Greater Blessing of Light"]     = "Blessing of Light",
    -- Mage
    ["Arcane Intellect"]              = "Arcane Brilliance",
    ["Arcane Brilliance"]             = "Arcane Intellect",
    -- Druid
    ["Mark of the Wild"]              = "Gift of the Wild",
    ["Gift of the Wild"]              = "Mark of the Wild",
}

-- Buff detection: weapon enchants use GetWeaponEnchantInfo(),
-- everything else uses SuperMacro's global buffed() function.
-- Also checks the single<->group alias so either form satisfies the tracker.
local function IsBuffActive(buff)
    if buff.actionType == "weapon" then
        return GetWeaponEnchantInfo() and true or false
    end
    if buffed(buff.name) then return true end
    local alias = buffAliases[buff.name]
    if alias and buffed(alias) then return true end
    return false
end

-- Check if a buff name is already in the tracker (checks both name and its alias)
local function IsAlreadyTracked(name)
    local alias = buffAliases[name]
    for i = 1, table.getn(trackedBuffs) do
        local n = trackedBuffs[i].name
        if n == name then return true, n end
        if alias and n == alias then return true, n end
    end
    return false, nil
end

-----------------------------
-- BUFF TEMPLATES
-----------------------------
local buffTemplates = {
    {
        label = "Caster DPS",
        buffs = {
            { name = "Arcane Intellect",               duration = 30*60,  actionType = "spell", action = "Arcane Intellect" },
            { name = "Mage Armor",                     duration = 30*60,  actionType = "spell", action = "Mage Armor" },
            { name = "Dampen Magic",                   duration = 10*60,  actionType = "spell", action = "Dampen Magic" },
            { name = "Danonzo's Tel'Abim Medley",      duration = 15*60,  actionType = "item",  action = "Danonzo's Tel'Abim Medley" },
            { name = "Danonzo's Tel'Abim Delight",     duration = 15*60,  actionType = "item",  action = "Danonzo's Tel'Abim Delight" },
            { name = "Flask of Supreme Power",         duration = 120*60, actionType = "item",  action = "Flask of Supreme Power" },
            { name = "Spirit of Zanza",                duration = 120*60, actionType = "item",  action = "Spirit of Zanza" },
            { name = "Greater Arcane Elixir",          duration = 60*60,  actionType = "item",  action = "Greater Arcane Elixir" },
            { name = "Mageblood Potion",               duration = 60*60,  actionType = "item",  action = "Mageblood Potion" },
            { name = "Dreamshard Elixir",              duration = 60*60,  actionType = "item",  action = "Dreamshard Elixir" },
            { name = "Dreamtonic",                     duration = 60*60,  actionType = "item",  action = "Dreamtonic" },
            { name = "Cerebral Cortex Compound",       duration = 60*60,  actionType = "item",  action = "Cerebral Cortex Compound" },
            { name = "Elixir of Greater Arcane Power", duration = 60*60,  actionType = "item",  action = "Elixir of Greater Arcane Power" },
            { name = "Brilliant Wizard Oil",           duration = 30*60,  actionType = "weapon",action = "Brilliant Wizard Oil" },
            { name = "Arcane Brilliance",              duration = 120*60, actionType = "spell", action = "Arcane Brilliance" },
            { name = "Prayer of Fortitude",            duration = 120*60, actionType = "spell", action = "Prayer of Fortitude" },
            { name = "Prayer of Spirit",               duration = 120*60, actionType = "spell", action = "Prayer of Spirit" },
            { name = "Gift of the Wild",               duration = 60*60,  actionType = "spell", action = "Gift of the Wild" },
            { name = "Greater Blessing of Wisdom",     duration = 30*60,  actionType = "spell", action = "Greater Blessing of Wisdom" },
            { name = "Greater Blessing of Kings",      duration = 30*60,  actionType = "spell", action = "Greater Blessing of Kings" },
            { name = "Greater Blessing of Salvation",  duration = 30*60,  actionType = "spell", action = "Greater Blessing of Salvation" },
            { name = "Prayer of Shadow Protection",    duration = 120*60, actionType = "spell", action = "Prayer of Shadow Protection" },
        },
    },
    {
        label = "Tank",
        buffs = {
            { name = "Flask of the Titans",            duration = 120*60, actionType = "item",  action = "Flask of the Titans" },
            { name = "Greater Stoneshield Potion",     duration = 120*60, actionType = "item",  action = "Greater Stoneshield Potion" },
            { name = "Spirit of Zanza",                duration = 120*60, actionType = "item",  action = "Spirit of Zanza" },
            { name = "Elixir of the Mongoose",         duration = 60*60,  actionType = "item",  action = "Elixir of the Mongoose" },
            { name = "Elixir of Giants",               duration = 60*60,  actionType = "item",  action = "Elixir of Giants" },
            { name = "Juju Power",                     duration = 30*60,  actionType = "item",  action = "Juju Power" },
            { name = "Juju Might",                     duration = 30*60,  actionType = "item",  action = "Juju Might" },
            { name = "Winterfall Firewater",           duration = 30*60,  actionType = "item",  action = "Winterfall Firewater" },
            { name = "Gift of Arthas",                 duration = 30*60,  actionType = "item",  action = "Gift of Arthas" },
            { name = "R.O.I.D.S.",                     duration = 60*60,  actionType = "item",  action = "R.O.I.D.S." },
            { name = "Scroll of Protection IV",        duration = 30*60,  actionType = "item",  action = "Scroll of Protection IV" },
            { name = "Hardened Mushroom",              duration = 15*60,  actionType = "item",  action = "Hardened Mushroom" },
            { name = "Ground Scorpok Assay",           duration = 60*60,  actionType = "item",  action = "Ground Scorpok Assay" },
            { name = "Elemental Sharpening Stone",     duration = 30*60,  actionType = "weapon",action = "Elemental Sharpening Stone" },
            { name = "Arcane Brilliance",              duration = 120*60, actionType = "spell", action = "Arcane Brilliance" },
            { name = "Prayer of Fortitude",            duration = 120*60, actionType = "spell", action = "Prayer of Fortitude" },
            { name = "Prayer of Spirit",               duration = 120*60, actionType = "spell", action = "Prayer of Spirit" },
            { name = "Gift of the Wild",               duration = 60*60,  actionType = "spell", action = "Gift of the Wild" },
            { name = "Greater Blessing of Wisdom",     duration = 30*60,  actionType = "spell", action = "Greater Blessing of Wisdom" },
            { name = "Greater Blessing of Might",      duration = 30*60,  actionType = "spell", action = "Greater Blessing of Might" },
            { name = "Greater Blessing of Kings",      duration = 30*60,  actionType = "spell", action = "Greater Blessing of Kings" },
            { name = "Prayer of Shadow Protection",    duration = 120*60, actionType = "spell", action = "Prayer of Shadow Protection" },
        },
    },
    {
        label = "Phys DPS",
        buffs = {
            { name = "Flask of the Titans",            duration = 120*60, actionType = "item",  action = "Flask of the Titans" },
            { name = "Spirit of Zanza",                duration = 120*60, actionType = "item",  action = "Spirit of Zanza" },
            { name = "Elixir of the Mongoose",         duration = 60*60,  actionType = "item",  action = "Elixir of the Mongoose" },
            { name = "Elixir of Giants",               duration = 60*60,  actionType = "item",  action = "Elixir of Giants" },
            { name = "Juju Power",                     duration = 30*60,  actionType = "item",  action = "Juju Power" },
            { name = "Juju Might",                     duration = 30*60,  actionType = "item",  action = "Juju Might" },
            { name = "Winterfall Firewater",           duration = 30*60,  actionType = "item",  action = "Winterfall Firewater" },
            { name = "R.O.I.D.S.",                     duration = 60*60,  actionType = "item",  action = "R.O.I.D.S." },
            { name = "Grilled Squid",                  duration = 10*60,  actionType = "item",  action = "Grilled Squid" },
            { name = "Danonzo's Tel'Abim Surprise",    duration = 15*60,  actionType = "item",  action = "Danonzo's Tel'Abim Surprise" },
            { name = "Ground Scorpok Assay",           duration = 60*60,  actionType = "item",  action = "Ground Scorpok Assay" },
            { name = "Elemental Sharpening Stone",     duration = 30*60,  actionType = "weapon",action = "Elemental Sharpening Stone" },
            { name = "Arcane Brilliance",              duration = 120*60, actionType = "spell", action = "Arcane Brilliance" },
            { name = "Prayer of Fortitude",            duration = 120*60, actionType = "spell", action = "Prayer of Fortitude" },
            { name = "Prayer of Spirit",               duration = 120*60, actionType = "spell", action = "Prayer of Spirit" },
            { name = "Gift of the Wild",               duration = 60*60,  actionType = "spell", action = "Gift of the Wild" },
            { name = "Greater Blessing of Wisdom",     duration = 30*60,  actionType = "spell", action = "Greater Blessing of Wisdom" },
            { name = "Greater Blessing of Might",      duration = 30*60,  actionType = "spell", action = "Greater Blessing of Might" },
            { name = "Greater Blessing of Kings",      duration = 30*60,  actionType = "spell", action = "Greater Blessing of Kings" },
            { name = "Greater Blessing of Salvation",  duration = 30*60,  actionType = "spell", action = "Greater Blessing of Salvation" },
            { name = "Prayer of Shadow Protection",    duration = 120*60, actionType = "spell", action = "Prayer of Shadow Protection" },
        },
    },
    {
        label = "Healer",
        buffs = {
            { name = "Flask of Distilled Wisdom",      duration = 120*60, actionType = "item",  action = "Flask of Distilled Wisdom" },
            { name = "Nightfin Soup",                  duration = 10*60,  actionType = "item",  action = "Nightfin Soup" },
            { name = "Sagefish Delight",               duration = 15*60,  actionType = "item",  action = "Sagefish Delight" },
            { name = "Danonzo's Tel'Abim Delight",     duration = 15*60,  actionType = "item",  action = "Danonzo's Tel'Abim Delight" },
            { name = "Cerebral Cortex Compound",       duration = 60*60,  actionType = "item",  action = "Cerebral Cortex Compound" },
            { name = "Mageblood Potion",               duration = 60*60,  actionType = "item",  action = "Mageblood Potion" },
            { name = "Dreamshard Elixir",              duration = 60*60,  actionType = "item",  action = "Dreamshard Elixir" },
            { name = "Spirit of Zanza",                duration = 120*60, actionType = "item",  action = "Spirit of Zanza" },
            { name = "Brilliant Mana Oil",             duration = 30*60,  actionType = "weapon",action = "Brilliant Mana Oil" },
            { name = "Arcane Brilliance",              duration = 120*60, actionType = "spell", action = "Arcane Brilliance" },
            { name = "Prayer of Fortitude",            duration = 120*60, actionType = "spell", action = "Prayer of Fortitude" },
            { name = "Prayer of Spirit",               duration = 120*60, actionType = "spell", action = "Prayer of Spirit" },
            { name = "Gift of the Wild",               duration = 60*60,  actionType = "spell", action = "Gift of the Wild" },
            { name = "Greater Blessing of Wisdom",     duration = 30*60,  actionType = "spell", action = "Greater Blessing of Wisdom" },
            { name = "Greater Blessing of Kings",      duration = 30*60,  actionType = "spell", action = "Greater Blessing of Kings" },
            { name = "Greater Blessing of Salvation",  duration = 30*60,  actionType = "spell", action = "Greater Blessing of Salvation" },
            { name = "Prayer of Shadow Protection",    duration = 120*60, actionType = "spell", action = "Prayer of Shadow Protection" },
        },
    },
}

-----------------------------
-- MAIN TRACKER FRAME
-----------------------------
local frame = CreateFrame("Frame", "MeggicBuffTrackerFrame", UIParent)
frame:SetWidth(240)
frame:SetHeight(50)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
frame:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
frame:SetBackdropColor(0, 0, 0, 0.8)
frame:EnableMouse(true)
frame:SetMovable(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", function() this:StartMoving() end)
frame:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
    local _, _, _, x, y = this:GetPoint()
    MeggicBuffTrackerDB.x = x
    MeggicBuffTrackerDB.y = y
end)

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
title:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -6)
title:SetText("Meggic Buff Tracker")

local cogBtn = CreateFrame("Button", "MeggicBuffTrackerCogBtn", frame)
cogBtn:SetWidth(20)
cogBtn:SetHeight(14)
cogBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
local cogHL = cogBtn:CreateTexture(nil, "HIGHLIGHT")
cogHL:SetAllPoints(cogBtn)
cogHL:SetTexture(1, 1, 1, 0.2)
local cogLabel = cogBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
cogLabel:SetAllPoints(cogBtn)
cogLabel:SetJustifyH("CENTER")
cogLabel:SetJustifyV("MIDDLE")
cogLabel:SetText("|cffaaaaaa[C]|r")
cogBtn:SetScript("OnClick", function()
    if configFrame:IsShown() then configFrame:Hide() else configFrame:Show() end
end)
cogBtn:SetScript("OnEnter", function()
    cogLabel:SetText("|cffffff00[C]|r")
    GameTooltip:SetOwner(this, "ANCHOR_BOTTOMLEFT")
    GameTooltip:SetText("Open Config", 1, 1, 1)
    GameTooltip:Show()
end)
cogBtn:SetScript("OnLeave", function()
    cogLabel:SetText("|cffaaaaaa[C]|r")
    GameTooltip:Hide()
end)

-----------------------------
-- TRACKER ROWS (with drag-to-reorder)
-----------------------------
local rows = {}

-- Drag state
local dragIndex = nil
local dragRow = nil  -- the visual ghost row that follows the cursor

local function GetRowAtCursor()
    -- Returns which slot index the cursor is hovering over
    local numBuffs = table.getn(trackedBuffs)
    for i = 1, numBuffs do
        local r = rows[i]
        if r and r:IsShown() then
            local left = r:GetLeft()
            local right = r:GetRight()
            local top = r:GetTop()
            local bottom = r:GetBottom()
            local cx, cy = GetCursorPosition()
            local scale = r:GetEffectiveScale()
            cx = cx / scale
            cy = cy / scale
            if cx >= left and cx <= right and cy >= bottom and cy <= top then
                return i
            end
        end
    end
    return nil
end

local function RefreshTrackerRows()
    for i = 1, table.getn(rows) do
        rows[i]:Hide()
    end
    local numBuffs = table.getn(trackedBuffs)
    frame:SetHeight(numBuffs == 0 and 50 or 30 + (numBuffs * 18))
    for i = 1, numBuffs do
        local buff = trackedBuffs[i]
        local row = rows[i]
        if not row then
            row = CreateFrame("Button", "MeggicBuffTrackerRow" .. i, frame)
            row:SetWidth(230)
            row:SetHeight(16)
            row.glow = row:CreateTexture(nil, "BACKGROUND")
            row.glow:SetAllPoints(row)
            row.glow:SetTexture(1, 0, 0, 0)
            row.glowAlpha = 0
            row.glowDir = 1
            row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
            row.highlight:SetAllPoints(row)
            row.highlight:SetTexture(1, 1, 1, 0.15)
            -- Drag handle label on the left
            row.handle = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.handle:SetPoint("LEFT", row, "LEFT", 0, 0)
            row.handle:SetText("|cff555555:::|r")
            row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.label:SetPoint("LEFT", row, "LEFT", 18, 0)
            row.label:SetWidth(150)
            row.label:SetJustifyH("LEFT")
            row.status = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.status:SetPoint("RIGHT", row, "RIGHT", 0, 0)

            row:RegisterForDrag("LeftButton")
            row:SetScript("OnDragStart", function()
                dragIndex = this.buffIndex
                -- Dim the dragged row
                this.label:SetTextColor(0.5, 0.5, 0.5)
                this.status:SetTextColor(0.5, 0.5, 0.5)
            end)
            row:SetScript("OnDragStop", function()
                if dragIndex then
                    local targetIndex = GetRowAtCursor()
                    if targetIndex and targetIndex ~= dragIndex then
                        -- Swap the two entries
                        local tmp = trackedBuffs[dragIndex]
                        trackedBuffs[dragIndex] = trackedBuffs[targetIndex]
                        trackedBuffs[targetIndex] = tmp
                        MeggicBuffTrackerDB.buffs = trackedBuffs
                    end
                    dragIndex = nil
                    RefreshTrackerRows()
                end
            end)

            row:SetScript("OnClick", function()
                local idx = this.buffIndex
                local b = this.buff
                if IsShiftKeyDown() then
                    local removedName = b.name
                    table.remove(trackedBuffs, idx)
                    MeggicBuffTrackerDB.buffs = trackedBuffs
                    RefreshTrackerRows()
                    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00MeggicBuffTracker:|r Removed " .. removedName)
                elseif this.missing or (this.remaining and this.remaining < 120) then
                    buffStartTimes[b.name] = nil
                    if b.actionType == "spell" and b.action ~= "" then
                        CastSpellByName(b.action)
                    elseif b.actionType == "item" and b.action ~= "" then
                        UseItemFromBags(b.action)
                    elseif b.actionType == "weapon" and b.action ~= "" then
                        if UseItemFromBags(b.action) then
                            PickupInventoryItem(16)
                        end
                    else
                        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000MeggicBuffTracker:|r No action defined for " .. b.name)
                    end
                end
            end)

            row:SetScript("OnEnter", function()
                GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
                GameTooltip:SetText(this.buff and this.buff.name or "", 1, 1, 1)
                GameTooltip:AddLine("Left-click to cast/use", 0.7, 0.7, 0.7)
                GameTooltip:AddLine("Shift-click to remove", 0.7, 0.7, 0.7)
                GameTooltip:AddLine("Drag to reorder", 0.7, 0.7, 0.7)
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)

            rows[i] = row
        end
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -8 - (i * 18))
        row.label:SetText(buff.name)
        row.label:SetTextColor(1, 1, 1)
        row.status:SetText("---")
        row.status:SetTextColor(1, 1, 1)
        row.buff = buff
        row.buffIndex = i
        row.missing = false
        row.remaining = buff.duration
        row.glow:SetTexture(1, 0, 0, 0)
        row.glowAlpha = 0
        row:Show()
    end
end

-----------------------------
-- CONFIG WINDOW
-----------------------------
configFrame = CreateFrame("Frame", "MeggicBuffTrackerConfig", UIParent)
configFrame:SetWidth(330)
configFrame:SetHeight(460)
configFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
configFrame:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
configFrame:SetBackdropColor(0, 0, 0, 0.9)
configFrame:EnableMouse(true)
configFrame:SetMovable(true)
configFrame:RegisterForDrag("LeftButton")
configFrame:SetScript("OnDragStart", function() this:StartMoving() end)
configFrame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
configFrame:Hide()

local configTitle = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
configTitle:SetPoint("TOP", configFrame, "TOP", 0, -10)
configTitle:SetText("Add Buff(s) to Track")

local closeBtn = CreateFrame("Button", nil, configFrame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", configFrame, "TOPRIGHT", -2, -2)

local instructions = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
instructions:SetPoint("TOP", configFrame, "TOP", 0, -35)
instructions:SetText("Click a buff icon to fill the name field:")
instructions:SetTextColor(1, 1, 0)

local buffContainer = CreateFrame("Frame", nil, configFrame)
buffContainer:SetWidth(310)
buffContainer:SetHeight(80)
buffContainer:SetPoint("TOP", configFrame, "TOP", 0, -55)

local buffButtons = {}

local function RefreshCurrentBuffs()
    for i = 1, table.getn(buffButtons) do
        buffButtons[i]:Hide()
    end
    local col, rowNum = 0, 0
    for i = 1, 40 do
        local icon = UnitBuff("player", i)
        if not icon then break end
        local btn = buffButtons[i]
        if not btn then
            btn = CreateFrame("Button", "MeggicBuffBtn" .. i, buffContainer)
            btn:SetWidth(32)
            btn:SetHeight(32)
            btn.tex = btn:CreateTexture(nil, "ARTWORK")
            btn.tex:SetAllPoints(btn)
            btn.border = btn:CreateTexture(nil, "OVERLAY")
            btn.border:SetPoint("TOPLEFT", btn, "TOPLEFT", -2, 2)
            btn.border:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 2, -2)
            btn.border:SetTexture(1, 1, 0, 0)
            btn:SetScript("OnClick", function()
                for j = 1, table.getn(buffButtons) do
                    if buffButtons[j] then buffButtons[j].border:SetTexture(1, 1, 0, 0) end
                end
                this.border:SetTexture(1, 1, 0, 0.8)
                nameInput:SetText(this.buffName or "")
            end)
            btn:SetScript("OnEnter", function()
                GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
                GameTooltip:SetText(this.buffName or "", 1, 1, 1)
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            buffButtons[i] = btn
        end
        btn.tex:SetTexture(icon)
        btn.buffName = ""
        btn.border:SetTexture(1, 1, 0, 0)
        btn:SetPoint("TOPLEFT", buffContainer, "TOPLEFT", col * 36, -rowNum * 36)
        btn:Show()
        col = col + 1
        if col >= 8 then col = 0; rowNum = rowNum + 1 end
    end
end

-- Weapon enchant one-click add
local weaponEnchantBtn = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
weaponEnchantBtn:SetWidth(270)
weaponEnchantBtn:SetHeight(20)
weaponEnchantBtn:SetPoint("TOP", configFrame, "TOP", 0, -140)
weaponEnchantBtn:SetText("Add Current Weapon Enchant")
weaponEnchantBtn:SetScript("OnClick", function()
    local hasEnchant = GetWeaponEnchantInfo()
    if not hasEnchant then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000MeggicBuffTracker:|r No weapon enchant detected on your main hand.")
        return
    end
    for i = 1, table.getn(trackedBuffs) do
        if trackedBuffs[i].actionType == "weapon" then
            DEFAULT_CHAT_FRAME:AddMessage("|cffffff00MeggicBuffTracker:|r Already tracking a weapon enchant (" .. trackedBuffs[i].name .. "). Shift+Click it to remove first.")
            return
        end
    end
    table.insert(trackedBuffs, {
        name       = "Weapon Enchant",
        duration   = 30 * 60,
        actionType = "weapon",
        action     = "",
    })
    MeggicBuffTrackerDB.buffs = trackedBuffs
    RefreshTrackerRows()
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00MeggicBuffTracker:|r Weapon enchant added to tracker.")
end)

local sep1 = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
sep1:SetPoint("TOP", configFrame, "TOP", 0, -170)
sep1:SetText("--- Add Custom Buff ---")
sep1:SetTextColor(0.5, 0.5, 0.5)

local nameLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
nameLabel:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 15, -190)
nameLabel:SetText("Buff / Spell / Item:")

nameInput = CreateFrame("EditBox", "MeggicBuffTrackerNameInput", configFrame, "InputBoxTemplate")
nameInput:SetWidth(170)
nameInput:SetHeight(20)
nameInput:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 125, -187)
nameInput:SetAutoFocus(false)

local nameHelp = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
nameHelp:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 15, -210)
nameHelp:SetText("Must match the spell/item name EXACTLY.")
nameHelp:SetTextColor(0.6, 0.6, 0.6)

local typeLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
typeLabel:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 15, -228)
typeLabel:SetText("Action Type:")

local selectedType = "spell"

local spellBtn = CreateFrame("Button", "MeggicTypeSpell", configFrame)
spellBtn:SetWidth(60)
spellBtn:SetHeight(20)
spellBtn:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 95, -225)
spellBtn.bg = spellBtn:CreateTexture(nil, "BACKGROUND")
spellBtn.bg:SetAllPoints(spellBtn)
spellBtn.bg:SetTexture(0.2, 0.6, 0.2, 0.8)
spellBtn.text = spellBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
spellBtn.text:SetPoint("CENTER", spellBtn, "CENTER")
spellBtn.text:SetText("Spell")

local itemBtn = CreateFrame("Button", "MeggicTypeItem", configFrame)
itemBtn:SetWidth(60)
itemBtn:SetHeight(20)
itemBtn:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 160, -225)
itemBtn.bg = itemBtn:CreateTexture(nil, "BACKGROUND")
itemBtn.bg:SetAllPoints(itemBtn)
itemBtn.bg:SetTexture(0.2, 0.2, 0.2, 0.8)
itemBtn.text = itemBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
itemBtn.text:SetPoint("CENTER", itemBtn, "CENTER")
itemBtn.text:SetText("Item")

local function SelectType(newType)
    selectedType = newType
    spellBtn.bg:SetTexture(0.2, newType == "spell" and 0.6 or 0.2, 0.2, 0.8)
    itemBtn.bg:SetTexture(0.2, newType == "item" and 0.6 or 0.2, 0.2, 0.8)
end
spellBtn.bg:SetTexture(0.2, 0.6, 0.2, 0.8)
itemBtn.bg:SetTexture(0.2, 0.2, 0.2, 0.8)

spellBtn:SetScript("OnClick", function() SelectType("spell") end)
itemBtn:SetScript("OnClick", function() SelectType("item") end)

local durationLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
durationLabel:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 15, -257)
durationLabel:SetText("Duration (min):")

local durationInput = CreateFrame("EditBox", "MeggicBuffTrackerDurationInput", configFrame, "InputBoxTemplate")
durationInput:SetWidth(80)
durationInput:SetHeight(20)
durationInput:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 110, -254)
durationInput:SetAutoFocus(false)
durationInput:SetText("30")

local addBtn = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
addBtn:SetWidth(130)
addBtn:SetHeight(25)
addBtn:SetPoint("TOP", configFrame, "TOP", 0, -290)
addBtn:SetText("Add Custom Buff")
addBtn:SetScript("OnClick", function()
    local name = nameInput:GetText()
    if not name or name == "" then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000MeggicBuffTracker:|r Please enter a buff/spell/item name.")
        return
    end
    -- Duplicate check (also catches alias matches)
    local exists, existingName = IsAlreadyTracked(name)
    if exists then
        if existingName == name then
            DEFAULT_CHAT_FRAME:AddMessage("|cffffff00MeggicBuffTracker:|r '" .. name .. "' is already being tracked.")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffffff00MeggicBuffTracker:|r '" .. name .. "' is already covered by '" .. existingName .. "' (alias match).")
        end
        return
    end
    local durationMins = tonumber(durationInput:GetText()) or 30
    table.insert(trackedBuffs, {
        name       = name,
        duration   = durationMins * 60,
        actionType = selectedType,
        action     = name,
    })
    MeggicBuffTrackerDB.buffs = trackedBuffs
    RefreshTrackerRows()
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00MeggicBuffTracker:|r Added " .. name)
    nameInput:SetText("")
    durationInput:SetText("30")
    for j = 1, table.getn(buffButtons) do
        if buffButtons[j] then buffButtons[j].border:SetTexture(1, 1, 0, 0) end
    end
end)

-----------------------------
-- TEMPLATE SECTION
-----------------------------
local templateSep = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
templateSep:SetPoint("TOP", configFrame, "TOP", 0, -325)
templateSep:SetText("--- OR Choose a Template ---")
templateSep:SetTextColor(0.5, 0.5, 0.5)

local selectedTemplateIndex = 1

local templateDropBtn = CreateFrame("Button", "MeggicTemplateDropBtn", configFrame, "UIPanelButtonTemplate")
templateDropBtn:SetWidth(190)
templateDropBtn:SetHeight(22)
templateDropBtn:SetPoint("TOP", configFrame, "TOP", -30, -348)
templateDropBtn:SetText(buffTemplates[1].label)

local arrowLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
arrowLabel:SetPoint("LEFT", templateDropBtn, "RIGHT", 0, 1)
arrowLabel:SetText("|cffffff00v|r")

local dropList = CreateFrame("Frame", "MeggicTemplateDropList", configFrame)
dropList:SetWidth(200)
dropList:SetFrameLevel(configFrame:GetFrameLevel() + 10)
dropList:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
dropList:SetBackdropColor(0, 0, 0, 0.95)
dropList:Hide()

local dropItems = {}
local function BuildDropList()
    for i = 1, table.getn(dropItems) do dropItems[i]:Hide() end
    local numTemplates = table.getn(buffTemplates)
    dropList:SetHeight(8 + numTemplates * 20)
    for i = 1, numTemplates do
        local item = dropItems[i]
        if not item then
            item = CreateFrame("Button", "MeggicDropItem" .. i, dropList)
            item:SetWidth(192)
            item:SetHeight(18)
            item.hl = item:CreateTexture(nil, "HIGHLIGHT")
            item.hl:SetAllPoints(item)
            item.hl:SetTexture(0.3, 0.6, 1, 0.3)
            item.lbl = item:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            item.lbl:SetPoint("LEFT", item, "LEFT", 6, 0)
            item:SetScript("OnClick", function()
                selectedTemplateIndex = this.templateIndex
                templateDropBtn:SetText(buffTemplates[selectedTemplateIndex].label)
                dropList:Hide()
            end)
            dropItems[i] = item
        end
        item.templateIndex = i
        item.lbl:SetText(buffTemplates[i].label)
        item:SetPoint("TOPLEFT", dropList, "TOPLEFT", 4, -4 - (i - 1) * 20)
        item:Show()
    end
end

templateDropBtn:SetScript("OnClick", function()
    if dropList:IsShown() then
        dropList:Hide()
    else
        BuildDropList()
        dropList:SetPoint("TOPLEFT", templateDropBtn, "BOTTOMLEFT", 0, -2)
        dropList:Show()
    end
end)

local addTemplateBtn = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
addTemplateBtn:SetWidth(80)
addTemplateBtn:SetHeight(22)
addTemplateBtn:SetPoint("LEFT", templateDropBtn, "RIGHT", 10, 0)
addTemplateBtn:SetPoint("TOP", configFrame, "TOP", 85, -348)
addTemplateBtn:SetText("Add")
addTemplateBtn:SetScript("OnClick", function()
    local template = buffTemplates[selectedTemplateIndex]
    if not template then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000MeggicBuffTracker:|r No template selected.")
        return
    end
    local added, skipped = 0, 0
    for i = 1, table.getn(template.buffs) do
        local tb = template.buffs[i]
        local exists, existingName = IsAlreadyTracked(tb.name)
        if exists then
            skipped = skipped + 1
        else
            table.insert(trackedBuffs, {
                name       = tb.name,
                duration   = tb.duration,
                actionType = tb.actionType,
                action     = tb.action,
            })
            added = added + 1
        end
    end
    MeggicBuffTrackerDB.buffs = trackedBuffs
    RefreshTrackerRows()
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00MeggicBuffTracker:|r Added " .. added .. " buff(s) from template '" .. template.label .. "'.")
    if skipped > 0 then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffff00MeggicBuffTracker:|r " .. skipped .. " buff(s) skipped (already tracked or covered by alias).")
    end
end)

-----------------------------
-- BOTTOM HELP / REFRESH
-----------------------------
local helpText = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
helpText:SetPoint("BOTTOM", configFrame, "BOTTOM", 0, 40)
helpText:SetText("Shift+Click to remove  |  Drag to reorder")
helpText:SetTextColor(0.7, 0.7, 0.7)

local refreshBtn = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
refreshBtn:SetWidth(100)
refreshBtn:SetHeight(20)
refreshBtn:SetPoint("BOTTOM", configFrame, "BOTTOM", 0, 15)
refreshBtn:SetText("Refresh Buffs")
refreshBtn:SetScript("OnClick", function() RefreshCurrentBuffs() end)

configFrame:SetScript("OnShow", function() RefreshCurrentBuffs() end)
configFrame:SetScript("OnHide", function() dropList:Hide() end)

-----------------------------
-- UPDATE LOOP
-----------------------------
local elapsed = 0
frame:SetScript("OnUpdate", function()
    elapsed = elapsed + arg1
    if elapsed >= 0.5 then
        elapsed = 0
        local currentTime = GetTime()
        for i = 1, table.getn(rows) do
            local row = rows[i]
            if row:IsShown() and row.buff then
                local buff = row.buff
                local buffKey = buff.name
                local found = IsBuffActive(buff)
                if found then
                    if not buffStartTimes[buffKey] then
                        buffStartTimes[buffKey] = currentTime
                    end
                    local remaining = buff.duration - (currentTime - buffStartTimes[buffKey])
                    if remaining < 0 then remaining = 0 end
                    row.remaining = remaining
                    row.status:SetText(FormatTime(remaining))
                    if remaining < 60 then
                        row.status:SetTextColor(1, 0.3, 0.3)
                    elseif remaining < 300 then
                        row.status:SetTextColor(1, 1, 0)
                    else
                        row.status:SetTextColor(0, 1, 0)
                    end
                    row.label:SetTextColor(1, 1, 1)
                    row.missing = false
                    row.glow:SetTexture(1, 0, 0, 0)
                    row.glowAlpha = 0
                else
                    buffStartTimes[buffKey] = nil
                    row.remaining = 0
                    row.status:SetText("MISSING")
                    row.status:SetTextColor(1, 0, 0)
                    row.label:SetTextColor(1, 0.3, 0.3)
                    row.missing = true
                end
            end
        end
    end
    -- Glow animation for missing buffs
    for i = 1, table.getn(rows) do
        local row = rows[i]
        if row:IsShown() and row.missing then
            row.glowAlpha = row.glowAlpha + (row.glowDir * arg1 * 2)
            if row.glowAlpha >= 0.4 then
                row.glowDir = -1; row.glowAlpha = 0.4
            elseif row.glowAlpha <= 0 then
                row.glowDir = 1; row.glowAlpha = 0
            end
            row.glow:SetTexture(1, 0, 0, row.glowAlpha)
        end
    end
end)

-----------------------------
-- SAVE / LOAD
-----------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("VARIABLES_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:SetScript("OnEvent", function()
    if event == "VARIABLES_LOADED" then
        if MeggicBuffTrackerDB then
            trackedBuffs = MeggicBuffTrackerDB.buffs or {}
            MeggicBuffTrackerDB.buffs = trackedBuffs
            if MeggicBuffTrackerDB.x and MeggicBuffTrackerDB.y then
                frame:ClearAllPoints()
                frame:SetPoint("CENTER", UIParent, "CENTER", MeggicBuffTrackerDB.x, MeggicBuffTrackerDB.y)
            end
            RefreshTrackerRows()
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00MeggicBuffTracker|r loaded " .. table.getn(trackedBuffs) .. " saved buffs.")
        end
    elseif event == "PLAYER_LOGOUT" then
        MeggicBuffTrackerDB.buffs = trackedBuffs
    end
end)

-----------------------------
-- SLASH COMMANDS
-----------------------------
SLASH_MEGGICBUFFTRACKER1 = "/mbt"
SLASH_MEGGICBUFFTRACKER2 = "/meggicbufftracker"
SlashCmdList["MEGGICBUFFTRACKER"] = function(msg)
    msg = strlower(msg or "")
    if msg == "help" then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00MeggicBuffTracker Help|r")
        DEFAULT_CHAT_FRAME:AddMessage("/mbt - toggle tracker visibility")
        DEFAULT_CHAT_FRAME:AddMessage("/mbt config - open configuration window")
        DEFAULT_CHAT_FRAME:AddMessage("/mbt reset - reset tracker position")
        DEFAULT_CHAT_FRAME:AddMessage("/mbt clear - remove all tracked buffs")
        DEFAULT_CHAT_FRAME:AddMessage(" ")
        DEFAULT_CHAT_FRAME:AddMessage("Buff names must match spell/item names exactly.")
        DEFAULT_CHAT_FRAME:AddMessage("Shift+Click a tracked buff row to remove it.")
        DEFAULT_CHAT_FRAME:AddMessage("Drag a tracked buff row to reorder it.")
        return
    elseif msg == "config" then
        if configFrame:IsShown() then configFrame:Hide() else configFrame:Show() end
    elseif msg == "reset" then
        MeggicBuffTrackerDB.x = 0
        MeggicBuffTrackerDB.y = 0
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        DEFAULT_CHAT_FRAME:AddMessage("MeggicBuffTracker position reset.")
    elseif msg == "clear" then
        trackedBuffs = {}
        MeggicBuffTrackerDB.buffs = trackedBuffs
        RefreshTrackerRows()
        DEFAULT_CHAT_FRAME:AddMessage("MeggicBuffTracker cleared all buffs.")
    elseif frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
    end
end

DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00MeggicBuffTracker|r loaded. Requires SuperMacro.")
DEFAULT_CHAT_FRAME:AddMessage(" /mbt help - commands")
DEFAULT_CHAT_FRAME:AddMessage(" /mbt config - open config")