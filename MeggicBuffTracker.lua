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

-----------------------------
-- MAIN TRACKER FRAME
-----------------------------
local frame = CreateFrame("Frame", "MeggicBuffTrackerFrame", UIParent)
frame:SetWidth(220)
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

-- Title
local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
title:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -6)
title:SetText("Meggic Buff Tracker")

-- Config [C] button
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
    if configFrame:IsShown() then
        configFrame:Hide()
    else
        configFrame:Show()
    end
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

-- Rows container
local rows = {}
local function RefreshTrackerRows()
    for i = 1, table.getn(rows) do
        rows[i]:Hide()
    end
    local numBuffs = table.getn(trackedBuffs)
    if numBuffs == 0 then
        frame:SetHeight(50)
    else
        frame:SetHeight(30 + (numBuffs * 18))
    end
    for i = 1, numBuffs do
        local buff = trackedBuffs[i]
        local row = rows[i]
        if not row then
            row = CreateFrame("Button", "MeggicBuffTrackerRow" .. i, frame)
            row:SetWidth(210)
            row:SetHeight(16)
            row.glow = row:CreateTexture(nil, "BACKGROUND")
            row.glow:SetAllPoints(row)
            row.glow:SetTexture(1, 0, 0, 0)
            row.glowAlpha = 0
            row.glowDir = 1
            row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
            row.highlight:SetAllPoints(row)
            row.highlight:SetTexture(1, 1, 1, 0.2)
            row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.label:SetPoint("LEFT", row, "LEFT", 0, 0)
            row.label:SetWidth(130)
            row.label:SetJustifyH("LEFT")
            row.status = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.status:SetPoint("RIGHT", row, "RIGHT", 0, 0)
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
                    -- Clear the start time so the next OnUpdate tick stamps a fresh one,
                    -- resetting the countdown to full duration after the recast lands.
                    buffStartTimes[b.name] = nil
                    if b.actionType == "spell" and b.action and b.action ~= "" then
                        CastSpellByName(b.action)
                    elseif b.actionType == "item" and b.action and b.action ~= "" then
                        UseItemFromBags(b.action)
                    elseif b.actionType == "weapon" and b.action and b.action ~= "" then
                        if UseItemFromBags(b.action) then
                            PickupInventoryItem(16)
                        end
                    else
                        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000MeggicBuffTracker:|r No action defined for " .. b.name)
                    end
                end
            end)
            rows[i] = row
        end
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -8 - (i * 18))
        row.label:SetText(buff.name)
        row.status:SetText("---")
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
configFrame:SetWidth(300)
configFrame:SetHeight(400)
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
configTitle:SetText("Add Buff to Track")

local closeBtn = CreateFrame("Button", nil, configFrame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", configFrame, "TOPRIGHT", -2, -2)

local instructions = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
instructions:SetPoint("TOP", configFrame, "TOP", 0, -35)
instructions:SetText("Click a buff below to select it:")
instructions:SetTextColor(1, 1, 0)

local buffContainer = CreateFrame("Frame", nil, configFrame)
buffContainer:SetWidth(280)
buffContainer:SetHeight(80)
buffContainer:SetPoint("TOP", configFrame, "TOP", 0, -55)

local buffButtons = {}
local selectedIcon = nil
local selectedIconTexture = nil

local function IconToName(iconPath)
    local stripped = gsub(iconPath, "Interface\\Icons\\", "")
    stripped = gsub(stripped, "^%a+_", "")  -- remove first prefix  (e.g. "Spell_")
    stripped = gsub(stripped, "^%a+_", "")  -- remove second prefix (e.g. "Holy_")
    stripped = gsub(stripped, "_", " ")     -- replace any leftover underscores with spaces

    local result = ""
    for i = 1, strlen(stripped) do
        local c = strsub(stripped, i, i)
        local b = strbyte(c)
        if i > 1 and b >= 65 and b <= 90 then
            local prev = strbyte(strsub(stripped, i - 1, i - 1))
            if prev ~= 32 then
                result = result .. " " .. c
            else
                result = result .. c
            end
        else
            result = result .. c
        end
    end
    return result
end
local function RefreshCurrentBuffs()
    for i = 1, table.getn(buffButtons) do
        buffButtons[i]:Hide()
    end
    local col = 0
    local rowNum = 0
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
                    if buffButtons[j] then
                        buffButtons[j].border:SetTexture(1, 1, 0, 0)
                    end
                end
                this.border:SetTexture(1, 1, 0, 0.8)
                selectedIcon = this.icon
                selectedIconTexture = gsub(this.icon, "Interface\\Icons\\", "")
                local autoName = IconToName(this.icon)
                nameActionInput:SetText(autoName)
            end)
            buffButtons[i] = btn
        end
        btn.tex:SetTexture(icon)
        btn.icon = icon
        btn.border:SetTexture(1, 1, 0, 0)
        btn:SetPoint("TOPLEFT", buffContainer, "TOPLEFT", col * 36, -rowNum * 36)
        btn:Show()
        col = col + 1
        if col >= 7 then
            col = 0
            rowNum = rowNum + 1
        end
    end
end

local weaponEnchantBtn = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
weaponEnchantBtn:SetWidth(270)
weaponEnchantBtn:SetHeight(20)
weaponEnchantBtn:SetPoint("TOP", configFrame, "TOP", 0, -140)
weaponEnchantBtn:SetText("Select Current Weapon Enchant (Oil/Stone)")
weaponEnchantBtn:SetScript("OnClick", function()
    for j = 1, table.getn(buffButtons) do
        if buffButtons[j] then
            buffButtons[j].border:SetTexture(1, 1, 0, 0)
        end
    end
    selectedIcon = "WEAPON"
    selectedIconTexture = "WEAPON"
    nameActionInput:SetText("Weapon Enchant")
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00MeggicBuffTracker:|r Weapon enchant selected. Set type to 'Weapon', edit the name/item field, then click Add Buff!")
end)

local sep1 = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
sep1:SetPoint("TOP", configFrame, "TOP", 0, -170)
sep1:SetText("--- Configuration ---")
sep1:SetTextColor(0.5, 0.5, 0.5)

local nameActionLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
nameActionLabel:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 15, -190)
nameActionLabel:SetText("Buff / Spell / Item:")

nameActionInput = CreateFrame("EditBox", "MeggicBuffTrackerNameActionInput", configFrame, "InputBoxTemplate")
nameActionInput:SetWidth(155)
nameActionInput:SetHeight(20)
nameActionInput:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 125, -187)
nameActionInput:SetAutoFocus(false)

local nameActionHelp = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
nameActionHelp:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 15, -212)
nameActionHelp:SetText("^^ Must match the spell/item EXACTLY.")
nameActionHelp:SetTextColor(0.6, 0.6, 0.6)

local typeLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
typeLabel:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 15, -230)
typeLabel:SetText("Action Type:")

local selectedType = "spell"

local spellBtn = CreateFrame("Button", "MeggicTypeSpell", configFrame)
spellBtn:SetWidth(60)
spellBtn:SetHeight(20)
spellBtn:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 95, -227)
spellBtn.bg = spellBtn:CreateTexture(nil, "BACKGROUND")
spellBtn.bg:SetAllPoints(spellBtn)
spellBtn.bg:SetTexture(0.2, 0.6, 0.2, 0.8)
spellBtn.text = spellBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
spellBtn.text:SetPoint("CENTER", spellBtn, "CENTER")
spellBtn.text:SetText("Spell")

local itemBtn = CreateFrame("Button", "MeggicTypeItem", configFrame)
itemBtn:SetWidth(60)
itemBtn:SetHeight(20)
itemBtn:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 160, -227)
itemBtn.bg = itemBtn:CreateTexture(nil, "BACKGROUND")
itemBtn.bg:SetAllPoints(itemBtn)
itemBtn.bg:SetTexture(0.2, 0.2, 0.2, 0.8)
itemBtn.text = itemBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
itemBtn.text:SetPoint("CENTER", itemBtn, "CENTER")
itemBtn.text:SetText("Item")

local weaponBtn = CreateFrame("Button", "MeggicTypeWeapon", configFrame)
weaponBtn:SetWidth(60)
weaponBtn:SetHeight(20)
weaponBtn:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 225, -227)
weaponBtn.bg = weaponBtn:CreateTexture(nil, "BACKGROUND")
weaponBtn.bg:SetAllPoints(weaponBtn)
weaponBtn.bg:SetTexture(0.2, 0.2, 0.2, 0.8)
weaponBtn.text = weaponBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
weaponBtn.text:SetPoint("CENTER", weaponBtn, "CENTER")
weaponBtn.text:SetText("Weapon")

local function SelectType(newType)
    selectedType = newType
    spellBtn.bg:SetTexture(0.2, 0.2, 0.2, 0.8)
    itemBtn.bg:SetTexture(0.2, 0.2, 0.2, 0.8)
    weaponBtn.bg:SetTexture(0.2, 0.2, 0.2, 0.8)
    if newType == "spell" then
        spellBtn.bg:SetTexture(0.2, 0.6, 0.2, 0.8)
    elseif newType == "item" then
        itemBtn.bg:SetTexture(0.2, 0.6, 0.2, 0.8)
    elseif newType == "weapon" then
        weaponBtn.bg:SetTexture(0.2, 0.6, 0.2, 0.8)
    end
end

spellBtn:SetScript("OnClick", function() SelectType("spell") end)
itemBtn:SetScript("OnClick", function() SelectType("item") end)
weaponBtn:SetScript("OnClick", function() SelectType("weapon") end)

local durationLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
durationLabel:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 15, -260)
durationLabel:SetText("Duration (min):")

local durationInput = CreateFrame("EditBox", "MeggicBuffTrackerDurationInput", configFrame, "InputBoxTemplate")
durationInput:SetWidth(80)
durationInput:SetHeight(20)
durationInput:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 110, -257)
durationInput:SetAutoFocus(false)
durationInput:SetText("30")  -- user enters minutes; stored internally as seconds

local addBtn = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
addBtn:SetWidth(120)
addBtn:SetHeight(25)
addBtn:SetPoint("TOP", configFrame, "TOP", 0, -295)
addBtn:SetText("Add Buff")
addBtn:SetScript("OnClick", function()
    if not selectedIconTexture then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000MeggicBuffTracker:|r Please select a buff icon or weapon enchant first.")
        return
    end
    local nameAction = nameActionInput:GetText()
    if not nameAction or nameAction == "" then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000MeggicBuffTracker:|r Please enter a buff/spell/item name.")
        return
    end
    local durationMins = tonumber(durationInput:GetText()) or 30
    local duration = durationMins * 60  -- convert to seconds for internal use
    local newBuff = {
        name       = nameAction,
        icon       = selectedIconTexture,
        duration   = duration,
        actionType = selectedType,
        action     = nameAction,
    }
    table.insert(trackedBuffs, newBuff)
    MeggicBuffTrackerDB.buffs = trackedBuffs
    RefreshTrackerRows()
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00MeggicBuffTracker:|r Added " .. nameAction)
    nameActionInput:SetText("")
    durationInput:SetText("30")
    selectedIcon = nil
    selectedIconTexture = nil
    for j = 1, table.getn(buffButtons) do
        if buffButtons[j] then
            buffButtons[j].border:SetTexture(1, 1, 0, 0)
        end
    end
end)

local helpText = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
helpText:SetPoint("BOTTOM", configFrame, "BOTTOM", 0, 40)
helpText:SetText("Shift+Click a tracked buff to remove it")
helpText:SetTextColor(0.7, 0.7, 0.7)

local refreshBtn = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
refreshBtn:SetWidth(100)
refreshBtn:SetHeight(20)
refreshBtn:SetPoint("BOTTOM", configFrame, "BOTTOM", 0, 15)
refreshBtn:SetText("Refresh Buffs")
refreshBtn:SetScript("OnClick", function() RefreshCurrentBuffs() end)

configFrame:SetScript("OnShow", function() RefreshCurrentBuffs() end)

-----------------------------
-- UPDATE LOOP
-----------------------------
local elapsed = 0
frame:SetScript("OnUpdate", function()
    elapsed = elapsed + arg1
    if elapsed >= 0.5 then
        elapsed = 0
        local hasMainHandEnchant = GetWeaponEnchantInfo()
        local currentTime = GetTime()
        for i = 1, table.getn(rows) do
            local row = rows[i]
            if row:IsShown() and row.buff then
                local found = false
                local buff = row.buff
                local buffKey = buff.name
                if buff.actionType == "weapon" or buff.icon == "WEAPON" then
                    if hasMainHandEnchant then found = true end
                else
                    for j = 1, 40 do
                        local icon = UnitBuff("player", j)
                        if not icon then break end
                        local iconName = gsub(icon, "Interface\\Icons\\", "")
                        local icon2 = ""
                        if icon == "Interface\\Icons\\Spell_Holy_MagicalSentry" then icon2 = "Interface\\Icons\\Spell_Holy_ArcaneIntellect" end
                        if icon == "Interface\\Icons\\Spell_Holy_ArcaneIntellect" then icon2 = "Interface\\Icons\\Spell_Holy_MagicalSentry" end
                        if icon == "Interface\\Icons\\Spell_Holy_WordFortitude" then icon2 = "Interface\\Icons\\Spell_Holy_PrayerOfFortitude" end
                        if icon == "Interface\\Icons\\Spell_Holy_PrayerOfFortitude" then icon2 = "Interface\\Icons\\Spell_Holy_WordFortitude" end
                        if icon == "Interface\\Icons\\Spell_Holy_DivineSpirit" then icon2 = "Interface\\Icons\\Spell_Holy_PrayerofSpirit" end
                        if icon == "Interface\\Icons\\Spell_Holy_PrayerofSpirit" then icon2 = "Interface\\Icons\\Spell_Holy_DivineSpirit" end
                        if icon == "Interface\\Icons\\Spell_Shadow_AntiShadow" then icon2 = "Interface\\Icons\\Spell_Holy_PrayerofShadowProtection" end
                        if icon == "Interface\\Icons\\Spell_Holy_PrayerofShadowProtection" then icon2 = "Interface\\Icons\\Spell_Shadow_AntiShadow" end
                        if icon == "Interface\\Icons\\Spell_Magic_MageArmor" then icon2 = "Interface\\Icons\\Spell_Magic_GreaterBlessingofKings" end
                        if icon == "Interface\\Icons\\Spell_Magic_GreaterBlessingofKings" then icon2 = "Interface\\Icons\\Spell_Magic_MageArmor" end
                        if icon == "Interface\\Icons\\Spell_Holy_FistOfJustice" then icon2 = "Interface\\Icons\\Spell_Holy_GreaterBlessingofKings" end
                        if icon == "Interface\\Icons\\Spell_Holy_GreaterBlessingofKings" then icon2 = "Interface\\Icons\\Spell_Holy_FistOfJustice" end
                        if icon == "Interface\\Icons\\Spell_Holy_SealOfWisdom" then icon2 = "Interface\\Icons\\Spell_Holy_GreaterBlessingofWisdom" end
                        if icon == "Interface\\Icons\\Spell_Holy_GreaterBlessingofWisdom" then icon2 = "Interface\\Icons\\Spell_Holy_SealOfWisdom" end
                        if icon == "Interface\\Icons\\Spell_Holy_SealOfSalvation" then icon2 = "Interface\\Icons\\Spell_Holy_GreaterBlessingofSalvation" end
                        if icon == "Interface\\Icons\\Spell_Holy_GreaterBlessingofSalvation" then icon2 = "Interface\\Icons\\Spell_Holy_SealOfSalvation" end
                        local iconName2 = gsub(icon2, "Interface\\Icons\\", "")
                        if strlower(iconName) == strlower(buff.icon) then found = true break end
                        if strlower(iconName2) == strlower(buff.icon) then found = true break end
                    end
                end
                if found then
                    -- buffStartTimes[buffKey] is nil on first application OR after a click reset.
                    -- Either way, stamp a fresh start time so the countdown begins from full duration.
                    if not buffStartTimes[buffKey] then
                        buffStartTimes[buffKey] = currentTime
                    end
                    local elapsedTime = currentTime - buffStartTimes[buffKey]
                    local remaining = buff.duration - elapsedTime
                    if remaining < 0 then remaining = 0 end
                    row.remaining = remaining
                    local timeStr = FormatTime(remaining)
                    row.status:SetText(timeStr)
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
    -- Glow animation
    for i = 1, table.getn(rows) do
        local row = rows[i]
        if row:IsShown() and row.missing then
            row.glowAlpha = row.glowAlpha + (row.glowDir * arg1 * 2)
            if row.glowAlpha >= 0.4 then
                row.glowDir = -1
                row.glowAlpha = 0.4
            elseif row.glowAlpha <= 0 then
                row.glowDir = 1
                row.glowAlpha = 0
            end
            row.glow:SetTexture(1, 0, 0, row.glowAlpha)
        end
    end
end)

-----------------------------
-- EVENT HANDLING FOR SAVE/LOAD
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
        DEFAULT_CHAT_FRAME:AddMessage("/mbt config - open configuration window to add buffs")
        DEFAULT_CHAT_FRAME:AddMessage("/mbt reset - reset tracker position")
        DEFAULT_CHAT_FRAME:AddMessage("/mbt clear - remove all tracked buffs")
        DEFAULT_CHAT_FRAME:AddMessage(" ")
        DEFAULT_CHAT_FRAME:AddMessage("How to add buffs:")
        DEFAULT_CHAT_FRAME:AddMessage("1. Click 'Refresh Buffs'")
        DEFAULT_CHAT_FRAME:AddMessage("2. Click a buff icon — the name field auto-fills")
        DEFAULT_CHAT_FRAME:AddMessage("3. Edit name if needed, set type, then click 'Add Buff'")
        DEFAULT_CHAT_FRAME:AddMessage(" ")
        DEFAULT_CHAT_FRAME:AddMessage("Shift+Click a tracked buff row to remove it")
        DEFAULT_CHAT_FRAME:AddMessage("Click [C] on the tracker to open config")
        DEFAULT_CHAT_FRAME:AddMessage("All settings saved between sessions")
        DEFAULT_CHAT_FRAME:AddMessage(" ")
        DEFAULT_CHAT_FRAME:AddMessage("|cffccccccField explanations:|r")
        DEFAULT_CHAT_FRAME:AddMessage("Buff / Spell / Item - display name AND action name")
        DEFAULT_CHAT_FRAME:AddMessage("Action Type - Spell, Item, or Weapon")
        DEFAULT_CHAT_FRAME:AddMessage("Duration - buff duration in minutes")
        return
    elseif msg == "config" then
        if configFrame:IsShown() then
            configFrame:Hide()
        else
            configFrame:Show()
        end
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

DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00MeggicBuffTracker|r loaded.")
DEFAULT_CHAT_FRAME:AddMessage(" /mbt - toggle tracker")
DEFAULT_CHAT_FRAME:AddMessage(" /mbt help - get commands")
DEFAULT_CHAT_FRAME:AddMessage(" /mbt config - open config window")
DEFAULT_CHAT_FRAME:AddMessage(" /mbt reset - reset position")
DEFAULT_CHAT_FRAME:AddMessage(" /mbt clear - remove all tracked buffs")
