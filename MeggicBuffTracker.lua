MeggicBuffTrackerDB = MeggicBuffTrackerDB or { buffs = {}, x = 0, y = 0, width = 250, showInRaidOnly = false, solidMissingBar = false }
local trackedBuffs = {}
local configFrame

local _, playerClass = UnitClass("player")

-----------------------------
-- UTILITY
-----------------------------
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

local function GetItemCountInBags(itemName)
    local total = 0
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local link = GetContainerItemLink(bag, slot)
            if link and strfind(link, itemName) then
                local _, count = GetContainerItemInfo(bag, slot)
                total = total + (count or 1)
            end
        end
    end
    return total
end

local function FormatTime(seconds)
    if seconds <= 0 then return "0:00" end
    local hours = floor(seconds / 3600)
    local mins  = floor(mod(seconds, 3600) / 60)
    local secs  = floor(mod(seconds, 60))
    if hours > 0 then
        return format("%d:%02d:%02d", hours, mins, secs)
    else
        return format("%d:%02d", mins, secs)
    end
end

-----------------------------
-- ALIASES & REAGENTS
-----------------------------
local buffAliases = {
    ["Power Word: Fortitude"]         = "Prayer of Fortitude",
    ["Prayer of Fortitude"]           = "Power Word: Fortitude",
    ["Divine Spirit"]                 = "Prayer of Spirit",
    ["Prayer of Spirit"]              = "Divine Spirit",
    ["Shadow Protection"]             = "Prayer of Shadow Protection",
    ["Prayer of Shadow Protection"]   = "Shadow Protection",
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
    ["Arcane Intellect"]              = "Arcane Brilliance",
    ["Arcane Brilliance"]             = "Arcane Intellect",
    ["Mark of the Wild"]              = "Gift of the Wild",
    ["Gift of the Wild"]              = "Mark of the Wild",
}

local buffReagents = {
    ["Power Word: Fortitude"]       = { item = "Sacred Candle",  class = "PRIEST"  },
    ["Prayer of Fortitude"]         = { item = "Sacred Candle",  class = "PRIEST"  },
    ["Divine Spirit"]               = { item = "Sacred Candle",  class = "PRIEST"  },
    ["Prayer of Spirit"]            = { item = "Sacred Candle",  class = "PRIEST"  },
    ["Shadow Protection"]           = { item = "Sacred Candle",  class = "PRIEST"  },
    ["Prayer of Shadow Protection"] = { item = "Sacred Candle",  class = "PRIEST"  },
    ["Blessing of Kings"]              = { item = "Symbol of Kings", class = "PALADIN" },
    ["Greater Blessing of Kings"]      = { item = "Symbol of Kings", class = "PALADIN" },
    ["Blessing of Wisdom"]             = { item = "Symbol of Kings", class = "PALADIN" },
    ["Greater Blessing of Wisdom"]     = { item = "Symbol of Kings", class = "PALADIN" },
    ["Blessing of Might"]              = { item = "Symbol of Kings", class = "PALADIN" },
    ["Greater Blessing of Might"]      = { item = "Symbol of Kings", class = "PALADIN" },
    ["Blessing of Salvation"]          = { item = "Symbol of Kings", class = "PALADIN" },
    ["Greater Blessing of Salvation"]  = { item = "Symbol of Kings", class = "PALADIN" },
    ["Blessing of Sanctuary"]          = { item = "Symbol of Kings", class = "PALADIN" },
    ["Greater Blessing of Sanctuary"]  = { item = "Symbol of Kings", class = "PALADIN" },
    ["Blessing of Light"]              = { item = "Symbol of Kings", class = "PALADIN" },
    ["Greater Blessing of Light"]      = { item = "Symbol of Kings", class = "PALADIN" },
    ["Arcane Intellect"]  = { item = "Arcane Powder", class = "MAGE"  },
    ["Arcane Brilliance"] = { item = "Arcane Powder", class = "MAGE"  },
    ["Mark of the Wild"]  = { item = "Wild Berries",  class = "DRUID" },
    ["Gift of the Wild"]  = { item = "Wild Berries",  class = "DRUID" },
}

-----------------------------
-- BUFF DETECTION
-----------------------------
local function IsBuffActive(buff)
    if buff.actionType == "weapon" then
        return GetWeaponEnchantInfo() and true or false
    end
    if buffed(buff.name) then return true end
    local alias = buffAliases[buff.name]
    if alias and buffed(alias) then return true end
    return false
end

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
-- ACCURATE TIMER
-----------------------------
local scanTip = CreateFrame("GameTooltip", "MeggicScanTooltip", UIParent, "GameTooltipTemplate")
scanTip:SetOwner(UIParent, "ANCHOR_NONE")

local function BuildBuffTimeMap()
    local iconToTime = {}
    for i = 0, 31 do
        local buffId = GetPlayerBuff(i, "HELPFUL|HARMFUL|PASSIVE")
        if buffId and buffId > -1 then
            local timeLeft = GetPlayerBuffTimeLeft(buffId)
            local icon = GetPlayerBuffTexture(buffId)
            if icon then
                iconToTime[strlower(icon)] = timeLeft
            end
        end
    end
    local map = {}
    for i = 1, 40 do
        local icon = UnitBuff("player", i)
        if not icon then break end
        scanTip:ClearLines()
        scanTip:SetUnitBuff("player", i)
        local line1 = getglobal("MeggicScanTooltipTextLeft1")
        local name  = line1 and line1:GetText() or ""
        if name ~= "" then
            local timeLeft = iconToTime[strlower(icon)]
            if timeLeft ~= nil then
                map[strlower(name)] = timeLeft
            end
        end
    end
    return map
end

local function GetBuffTimeLeft(buffMap, buffName)
    local t = buffMap[strlower(buffName)]
    if t ~= nil then return t end
    local alias = buffAliases[buffName]
    if alias then
        t = buffMap[strlower(alias)]
        if t ~= nil then return t end
    end
    return nil
end

-----------------------------
-- BUFF TEMPLATES
-----------------------------
local buffTemplates = {
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
        label = "Healer",
        buffs = {
            { name = "Flask of Distilled Wisdom",      duration = 120*60, actionType = "item",  action = "Flask of Distilled Wisdom" },
            { name = "Nightfin Soup",                  duration = 10*60,  actionType = "item",  action = "Nightfin Soup" },
            { name = "Sagefish Delight",               duration = 15*60,  actionType = "item",  action = "Sagefish Delight" },
            { name = "Danonzo's Tel'Abim Delight",     duration = 15*60,  actionType = "item",  action = "Danonzo's Tel'Abim Delight" },
            { name = "Cerebral Cortex Compound",       duration = 60*60,  actionType = "item",  action = "Cerebral Cortex Compound" },
            { name = "Medivh's Merlot Blue Label",     duration = 15*60,  actionType = "item",  action = "Medivh's Merlot Blue Label" },
            { name = "Emerald Blessing",               duration = 60*60,  actionType = "spell", action = "Emerald Blessing" },
            { name = "Mageblood Potion",               duration = 60*60,  actionType = "item",  action = "Mageblood Potion" },
            { name = "Elixir of the Sages",            duration = 60*60,  actionType = "item",  action = "Elixir of the Sages" },
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
        label = "Add ALL Buffs!",
        buffs = {
            { name = "Flask of the Titans",                duration = 120*60, actionType = "item",  action = "Flask of the Titans" },
            { name = "Greater Stoneshield Potion",         duration = 120*60, actionType = "item",  action = "Greater Stoneshield Potion" },
            { name = "Spirit of Zanza",                    duration = 120*60, actionType = "item",  action = "Spirit of Zanza" },
            { name = "Flask of Distilled Wisdom",          duration = 120*60, actionType = "item",  action = "Flask of Distilled Wisdom" },
            { name = "Flask of Supreme Power",             duration = 120*60, actionType = "item",  action = "Flask of Supreme Power" },
            { name = "Arcane Brilliance",                  duration = 120*60, actionType = "spell", action = "Arcane Brilliance" },
            { name = "Prayer of Fortitude",                duration = 120*60, actionType = "spell", action = "Prayer of Fortitude" },
            { name = "Prayer of Spirit",                   duration = 120*60, actionType = "spell", action = "Prayer of Spirit" },
            { name = "Prayer of Shadow Protection",        duration = 120*60, actionType = "spell", action = "Prayer of Shadow Protection" },
            { name = "Elixir of the Mongoose",             duration = 60*60,  actionType = "item",  action = "Elixir of the Mongoose" },
            { name = "Elixir of Giants",                   duration = 60*60,  actionType = "item",  action = "Elixir of Giants" },
            { name = "Concoction of the Arcane Giant",     duration = 60*60,  actionType = "item",  action = "Concoction of the Arcane Giant" },
            { name = "Concoction of the Emerald Mongoose", duration = 60*60,  actionType = "item",  action = "Concoction of the Emerald Mongoose" },
            { name = "R.O.I.D.S.",                         duration = 60*60,  actionType = "item",  action = "R.O.I.D.S." },
            { name = "Ground Scorpok Assay",               duration = 60*60,  actionType = "item",  action = "Ground Scorpok Assay" },
            { name = "Cerebral Cortex Compound",           duration = 60*60,  actionType = "item",  action = "Cerebral Cortex Compound" },
            { name = "Mageblood Potion",                   duration = 60*60,  actionType = "item",  action = "Mageblood Potion" },
            { name = "Elixir of the Sages",                duration = 60*60,  actionType = "item",  action = "Elixir of the Sages" },
            { name = "Dreamshard Elixir",                  duration = 60*60,  actionType = "item",  action = "Dreamshard Elixir" },
            { name = "Dreamtonic",                         duration = 60*60,  actionType = "item",  action = "Dreamtonic" },
            { name = "Greater Arcane Elixir",              duration = 60*60,  actionType = "item",  action = "Greater Arcane Elixir" },
            { name = "Elixir of Greater Arcane Power",     duration = 60*60,  actionType = "item",  action = "Elixir of Greater Arcane Power" },
            { name = "Gift of the Wild",                   duration = 60*60,  actionType = "spell", action = "Gift of the Wild" },
            { name = "Emerald Blessing",                   duration = 60*60,  actionType = "spell", action = "Emerald Blessing" },
            { name = "Juju Power",                         duration = 30*60,  actionType = "item",  action = "Juju Power" },
            { name = "Juju Might",                         duration = 30*60,  actionType = "item",  action = "Juju Might" },
            { name = "Winterfall Firewater",               duration = 30*60,  actionType = "item",  action = "Winterfall Firewater" },
            { name = "Gift of Arthas",                     duration = 30*60,  actionType = "item",  action = "Gift of Arthas" },
            { name = "Elemental Sharpening Stone",         duration = 30*60,  actionType = "weapon",action = "Elemental Sharpening Stone" },
            { name = "Brilliant Mana Oil",                 duration = 30*60,  actionType = "weapon",action = "Brilliant Mana Oil" },
            { name = "Brilliant Wizard Oil",               duration = 30*60,  actionType = "weapon",action = "Brilliant Wizard Oil" },
            { name = "Greater Blessing of Wisdom",         duration = 30*60,  actionType = "spell", action = "Greater Blessing of Wisdom" },
            { name = "Greater Blessing of Might",          duration = 30*60,  actionType = "spell", action = "Greater Blessing of Might" },
            { name = "Greater Blessing of Kings",          duration = 30*60,  actionType = "spell", action = "Greater Blessing of Kings" },
            { name = "Greater Blessing of Salvation",      duration = 30*60,  actionType = "spell", action = "Greater Blessing of Salvation" },
            { name = "Arcane Intellect",                   duration = 30*60,  actionType = "spell", action = "Arcane Intellect" },
            { name = "Mage Armor",                         duration = 30*60,  actionType = "spell", action = "Mage Armor" },
            { name = "Concoction of the Dreamwater",       duration = 20*60,  actionType = "item",  action = "Concoction of the Dreamwater" },
            { name = "Hardened Mushroom",                  duration = 15*60,  actionType = "item",  action = "Hardened Mushroom" },
            { name = "Sagefish Delight",                   duration = 15*60,  actionType = "item",  action = "Sagefish Delight" },
            { name = "Danonzo's Tel'Abim Delight",         duration = 15*60,  actionType = "item",  action = "Danonzo's Tel'Abim Delight" },
            { name = "Medivh's Merlot Blue Label",         duration = 15*60,  actionType = "item",  action = "Medivh's Merlot Blue Label" },
            { name = "Danonzo's Tel'Abim Medley",          duration = 15*60,  actionType = "item",  action = "Danonzo's Tel'Abim Medley" },
            { name = "Danonzo's Tel'Abim Surprise",        duration = 15*60,  actionType = "item",  action = "Danonzo's Tel'Abim Surprise" },
            { name = "Nightfin Soup",                      duration = 10*60,  actionType = "item",  action = "Nightfin Soup" },
            { name = "Grilled Squid",                      duration = 10*60,  actionType = "item",  action = "Grilled Squid" },
            { name = "Dampen Magic",                       duration = 10*60,  actionType = "spell", action = "Dampen Magic" },
        },
    },
}

-----------------------------
-- MAIN TRACKER FRAME
-----------------------------
local frame = CreateFrame("Frame", "MeggicBuffTrackerFrame", UIParent)
frame:SetWidth(250)
frame:SetHeight(50)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
frame:SetBackdrop({
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
frame:SetBackdropColor(0, 0, 0, 0.8)
frame:EnableMouse(true)
frame:SetMovable(true)
frame:SetResizable(true)
frame:SetMinResize(160, 50)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", function() this:StartMoving() end)
frame:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
    local _, _, _, x, y = this:GetPoint()
    MeggicBuffTrackerDB.x     = x
    MeggicBuffTrackerDB.y     = y
    MeggicBuffTrackerDB.width = this:GetWidth()
end)

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
title:SetPoint("TOPLEFT",  frame, "TOPLEFT",   8, -6)
title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -76, -6)
title:SetJustifyH("LEFT")
title:SetText("Meggic Buff Tracker")

local closeTrackerBtn = CreateFrame("Button", "MeggicBuffTrackerCloseBtn", frame)
closeTrackerBtn:SetWidth(20)
closeTrackerBtn:SetHeight(14)
closeTrackerBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
local closeHL = closeTrackerBtn:CreateTexture(nil, "HIGHLIGHT")
closeHL:SetAllPoints(closeTrackerBtn)
closeHL:SetTexture(1, 1, 1, 0.2)
local closeLabel = closeTrackerBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
closeLabel:SetAllPoints(closeTrackerBtn)
closeLabel:SetJustifyH("CENTER")
closeLabel:SetJustifyV("MIDDLE")
closeLabel:SetText("|cffaaaaaa[X]|r")
closeTrackerBtn:SetScript("OnClick", function() frame:Hide() end)
closeTrackerBtn:SetScript("OnEnter", function()
    closeLabel:SetText("|cffff4444[X]|r")
    GameTooltip:SetOwner(this, "ANCHOR_BOTTOMLEFT")
    GameTooltip:SetText("Close Tracker", 1, 1, 1)
    GameTooltip:Show()
end)
closeTrackerBtn:SetScript("OnLeave", function()
    closeLabel:SetText("|cffaaaaaa[X]|r")
    GameTooltip:Hide()
end)

local cogBtn = CreateFrame("Button", "MeggicBuffTrackerCogBtn", frame)
cogBtn:SetWidth(20)
cogBtn:SetHeight(14)
cogBtn:SetPoint("TOPRIGHT", closeTrackerBtn, "TOPLEFT", -2, 0)
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

local isCollapsed   = false
local COLLAPSE_ROWS = 10

local collapseBtn = CreateFrame("Button", "MeggicBuffTrackerCollapseBtn", frame)
collapseBtn:SetWidth(20)
collapseBtn:SetHeight(14)
collapseBtn:SetPoint("TOPRIGHT", cogBtn, "TOPLEFT", -2, 0)
local collapseHL = collapseBtn:CreateTexture(nil, "HIGHLIGHT")
collapseHL:SetAllPoints(collapseBtn)
collapseHL:SetTexture(1, 1, 1, 0.2)
local collapseLabel = collapseBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
collapseLabel:SetAllPoints(collapseBtn)
collapseLabel:SetJustifyH("CENTER")
collapseLabel:SetJustifyV("MIDDLE")
collapseLabel:SetText("|cffaaaaaa[-]|r")

local resizeGrip = CreateFrame("Frame", nil, frame)
resizeGrip:SetWidth(6)
resizeGrip:SetPoint("TOPRIGHT",    frame, "TOPRIGHT",    0, 0)
resizeGrip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
resizeGrip:EnableMouse(true)
local resizeTex = resizeGrip:CreateTexture(nil, "OVERLAY")
resizeTex:SetAllPoints(resizeGrip)
resizeTex:SetTexture(0.4, 0.4, 0.4, 0.3)
resizeGrip:SetScript("OnEnter", function()
    resizeTex:SetTexture(0.8, 0.8, 0.8, 0.5)
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    GameTooltip:SetText("Drag to resize", 1, 1, 1)
    GameTooltip:Show()
end)
resizeGrip:SetScript("OnLeave", function()
    resizeTex:SetTexture(0.4, 0.4, 0.4, 0.3)
    GameTooltip:Hide()
end)
resizeGrip:SetScript("OnMouseDown", function() frame:StartSizing("RIGHT") end)
resizeGrip:SetScript("OnMouseUp", function()
    frame:StopMovingOrSizing()
    local numBuffs = table.getn(trackedBuffs)
    frame:SetHeight(numBuffs == 0 and 50 or 30 + (numBuffs * 18))
    MeggicBuffTrackerDB.width = frame:GetWidth()
end)

-----------------------------
-- TRACKER ROWS
-----------------------------
local rows      = {}
local dragIndex = nil

local function GetRowAtCursor()
    for i = 1, table.getn(trackedBuffs) do
        local r = rows[i]
        if r and r:IsShown() then
            local cx, cy = GetCursorPosition()
            local scale  = r:GetEffectiveScale()
            cx = cx / scale; cy = cy / scale
            if cx >= r:GetLeft() and cx <= r:GetRight()
            and cy >= r:GetBottom() and cy <= r:GetTop() then
                return i
            end
        end
    end
    return nil
end

local function VisibleRowCount()
    local total = table.getn(trackedBuffs)
    if isCollapsed then return math.min(total, COLLAPSE_ROWS) end
    return total
end

local function RefreshTrackerRows()
    for i = 1, table.getn(rows) do rows[i]:Hide() end
    local numBuffs   = table.getn(trackedBuffs)
    local numVisible = VisibleRowCount()
    frame:SetHeight(numVisible == 0 and 50 or 30 + (numVisible * 18))

    for i = 1, numBuffs do
        local buff = trackedBuffs[i]
        local row  = rows[i]
        if not row then
            row = CreateFrame("Button", "MeggicBuffTrackerRow" .. i, frame)
            row:SetHeight(16)
            row.glow = row:CreateTexture(nil, "BACKGROUND")
            row.glow:SetAllPoints(row)
            row.glow:SetTexture(1, 0, 0, 0)
            row.glowAlpha = 0
            row.glowDir   = 1
            row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
            row.highlight:SetAllPoints(row)
            row.highlight:SetTexture(1, 1, 1, 0.15)
            row.handle = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.handle:SetPoint("LEFT", row, "LEFT", 0, 0)
            row.handle:SetText("|cff555555:::|r")
            row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.label:SetPoint("LEFT",  row, "LEFT",  18, 0)
            row.label:SetPoint("RIGHT", row, "RIGHT", -52, 0)
            row.label:SetJustifyH("LEFT")
            row.label:SetNonSpaceWrap(false)
            row.status = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.status:SetPoint("LEFT",  row, "RIGHT", -50, 0)
            row.status:SetPoint("RIGHT", row, "RIGHT",   0, 0)
            row.status:SetJustifyH("RIGHT")

            row:RegisterForDrag("LeftButton")
            row:SetScript("OnDragStart", function()
                dragIndex = this.buffIndex
                this.label:SetTextColor(0.5, 0.5, 0.5)
                this.status:SetTextColor(0.5, 0.5, 0.5)
            end)
            row:SetScript("OnDragStop", function()
                if dragIndex then
                    local target = GetRowAtCursor()
                    if target and target ~= dragIndex then
                        local tmp = trackedBuffs[dragIndex]
                        trackedBuffs[dragIndex] = trackedBuffs[target]
                        trackedBuffs[target]    = tmp
                        MeggicBuffTrackerDB.buffs = trackedBuffs
                    end
                    dragIndex = nil
                    RefreshTrackerRows()
                end
            end)
            row:SetScript("OnClick", function()
                local idx = this.buffIndex
                local b   = this.buff
                if IsShiftKeyDown() then
                    local removedName = b.name
                    table.remove(trackedBuffs, idx)
                    MeggicBuffTrackerDB.buffs = trackedBuffs
                    RefreshTrackerRows()
                    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00MeggicBuffTracker:|r Removed " .. removedName)
                elseif this.missing or (this.remaining and this.remaining < 120) then
                    if b.actionType == "spell" and b.action ~= "" then
                        CastSpellByName(b.action)
                    elseif b.actionType == "item" and b.action ~= "" then
                        UseItemFromBags(b.action)
                    elseif b.actionType == "weapon" and b.action ~= "" then
                        if UseItemFromBags(b.action) then PickupInventoryItem(16) end
                    else
                        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000MeggicBuffTracker:|r No action defined for " .. b.name)
                    end
                end
            end)
            row:SetScript("OnEnter", function()
                local b = this.buff
                GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
                GameTooltip:SetText(b and b.name or "", 1, 1, 1)
                if b then
                    if b.actionType == "item" or (b.actionType == "weapon" and b.action ~= "") then
                        local qty = GetItemCountInBags(b.action)
                        local c   = qty > 0 and "|cffffffff" or "|cffff4444"
                        GameTooltip:AddLine("In bags: " .. c .. qty .. "|r", 0.9, 0.9, 0.9)
                    end
                    local re = buffReagents[b.name]
                    if re and re.class == playerClass then
                        local rq = GetItemCountInBags(re.item)
                        local c  = rq > 0 and "|cffffffff" or "|cffff4444"
                        GameTooltip:AddLine(re.item .. ": " .. c .. rq .. "|r", 0.4, 0.7, 1)
                    end
                end
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Left-click to cast/use", 0.7, 0.7, 0.7)
                GameTooltip:AddLine("Shift-click to remove",  0.7, 0.7, 0.7)
                GameTooltip:AddLine("Drag to reorder",        0.7, 0.7, 0.7)
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)
            rows[i] = row
        end

        if i <= numVisible then
            row:SetPoint("TOPLEFT",  frame, "TOPLEFT",  5, -8 - (i * 18))
            row:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -8 - (i * 18))
            row.label:SetText(buff.name)
            row.label:SetTextColor(1, 1, 1)
            row.status:SetText("---")
            row.status:SetTextColor(1, 1, 1)
            row.buff      = buff
            row.buffIndex = i
            row.missing   = false
            row.remaining = buff.duration
            row.glow:SetTexture(1, 0, 0, 0)
            row.glowAlpha = 0
            row:Show()
        end
    end

    local total = table.getn(trackedBuffs)
    if total <= COLLAPSE_ROWS then
        collapseLabel:SetText("|cff444444[-]|r")
    elseif isCollapsed then
        collapseLabel:SetText("|cff00ff00[+]|r")
    else
        collapseLabel:SetText("|cffaaaaaa[-]|r")
    end
end

collapseBtn:SetScript("OnClick", function()
    local total = table.getn(trackedBuffs)
    if total <= COLLAPSE_ROWS then return end
    isCollapsed = not isCollapsed
    RefreshTrackerRows()
end)
collapseBtn:SetScript("OnEnter", function()
    local total = table.getn(trackedBuffs)
    GameTooltip:SetOwner(this, "ANCHOR_BOTTOMLEFT")
    if total <= COLLAPSE_ROWS then
        GameTooltip:SetText("Nothing to collapse (<= " .. COLLAPSE_ROWS .. " rows)", 0.5, 0.5, 0.5)
    elseif isCollapsed then
        GameTooltip:SetText("Expand — show all " .. total .. " rows", 1, 1, 1)
    else
        GameTooltip:SetText("Collapse to " .. COLLAPSE_ROWS .. " rows", 1, 1, 1)
    end
    GameTooltip:Show()
end)
collapseBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

-----------------------------
-- CONFIG WINDOW
-----------------------------
configFrame = CreateFrame("Frame", "MeggicBuffTrackerConfig", UIParent)
configFrame:SetWidth(330)
configFrame:SetHeight(255)  -- slightly taller to fit second option row
configFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
configFrame:SetBackdrop({
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
configFrame:SetBackdropColor(0, 0, 0, 0.9)
configFrame:EnableMouse(true)
configFrame:SetMovable(true)
configFrame:RegisterForDrag("LeftButton")
configFrame:SetScript("OnDragStart", function() this:StartMoving() end)
configFrame:SetScript("OnDragStop",  function() this:StopMovingOrSizing() end)
configFrame:Hide()

local configTitle = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
configTitle:SetPoint("TOP", configFrame, "TOP", 0, -10)
configTitle:SetText("Add Buff(s) to Track")

local closeBtn = CreateFrame("Button", nil, configFrame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", configFrame, "TOPRIGHT", -2, -2)

local weaponEnchantBtn = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
weaponEnchantBtn:SetWidth(270); weaponEnchantBtn:SetHeight(22)
weaponEnchantBtn:SetPoint("TOP", configFrame, "TOP", 0, -40)
weaponEnchantBtn:SetText("Add Current Weapon Enchant")
weaponEnchantBtn:SetScript("OnClick", function()
    if not GetWeaponEnchantInfo() then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000MeggicBuffTracker:|r No weapon enchant detected on your main hand.")
        return
    end
    for i = 1, table.getn(trackedBuffs) do
        if trackedBuffs[i].actionType == "weapon" then
            DEFAULT_CHAT_FRAME:AddMessage("|cffffff00MeggicBuffTracker:|r Already tracking a weapon enchant (" .. trackedBuffs[i].name .. "). Shift+Click it to remove first.")
            return
        end
    end
    table.insert(trackedBuffs, { name = "Weapon Enchant", duration = 30*60, actionType = "weapon", action = "" })
    MeggicBuffTrackerDB.buffs = trackedBuffs
    RefreshTrackerRows()
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00MeggicBuffTracker:|r Weapon enchant added to tracker.")
end)

local addCustomBtn = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
addCustomBtn:SetWidth(160); addCustomBtn:SetHeight(22)
addCustomBtn:SetPoint("TOP", configFrame, "TOP", 0, -70)
addCustomBtn:SetText("+ Add Custom Buff...")

-----------------------------
-- CUSTOM BUFF POPUP
-----------------------------
local customPopup = CreateFrame("Frame", "MeggicCustomBuffPopup", UIParent)
customPopup:SetWidth(260)
customPopup:SetHeight(140)
customPopup:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
customPopup:SetBackdrop({
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
customPopup:SetBackdropColor(0, 0, 0, 0.95)
customPopup:EnableMouse(true)
customPopup:SetMovable(true)
customPopup:RegisterForDrag("LeftButton")
customPopup:SetScript("OnDragStart", function() this:StartMoving() end)
customPopup:SetScript("OnDragStop",  function() this:StopMovingOrSizing() end)
customPopup:SetFrameLevel(configFrame:GetFrameLevel() + 20)
customPopup:Hide()

local popupTitle = customPopup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
popupTitle:SetPoint("TOP", customPopup, "TOP", 0, -10)
popupTitle:SetText("Add Custom Buff")

local popupClose = CreateFrame("Button", nil, customPopup, "UIPanelCloseButton")
popupClose:SetPoint("TOPRIGHT", customPopup, "TOPRIGHT", -2, -2)
popupClose:SetScript("OnClick", function() customPopup:Hide() end)

local popupNameLabel = customPopup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
popupNameLabel:SetPoint("TOPLEFT", customPopup, "TOPLEFT", 15, -38)
popupNameLabel:SetText("Name:")

local popupNameInput = CreateFrame("EditBox", "MeggicPopupNameInput", customPopup, "InputBoxTemplate")
popupNameInput:SetWidth(155); popupNameInput:SetHeight(20)
popupNameInput:SetPoint("TOPLEFT", customPopup, "TOPLEFT", 75, -35)
popupNameInput:SetAutoFocus(false)

local popupNameHelp = customPopup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
popupNameHelp:SetPoint("TOPLEFT", customPopup, "TOPLEFT", 15, -60)
popupNameHelp:SetText("Must match the spell/item name EXACTLY.")
popupNameHelp:SetTextColor(0.6, 0.6, 0.6)

local popupTypeLabel = customPopup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
popupTypeLabel:SetPoint("TOPLEFT", customPopup, "TOPLEFT", 15, -80)
popupTypeLabel:SetText("Type:")

local popupSelectedType = "spell"

local popupSpellBtn = CreateFrame("Button", "MeggicPopupSpell", customPopup)
popupSpellBtn:SetWidth(60); popupSpellBtn:SetHeight(20)
popupSpellBtn:SetPoint("TOPLEFT", customPopup, "TOPLEFT", 60, -77)
popupSpellBtn.bg = popupSpellBtn:CreateTexture(nil, "BACKGROUND")
popupSpellBtn.bg:SetAllPoints(popupSpellBtn)
popupSpellBtn.bg:SetTexture(0.2, 0.6, 0.2, 0.8)
popupSpellBtn.text = popupSpellBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
popupSpellBtn.text:SetPoint("CENTER", popupSpellBtn, "CENTER")
popupSpellBtn.text:SetText("Spell")

local popupItemBtn = CreateFrame("Button", "MeggicPopupItem", customPopup)
popupItemBtn:SetWidth(60); popupItemBtn:SetHeight(20)
popupItemBtn:SetPoint("TOPLEFT", customPopup, "TOPLEFT", 125, -77)
popupItemBtn.bg = popupItemBtn:CreateTexture(nil, "BACKGROUND")
popupItemBtn.bg:SetAllPoints(popupItemBtn)
popupItemBtn.bg:SetTexture(0.2, 0.2, 0.2, 0.8)
popupItemBtn.text = popupItemBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
popupItemBtn.text:SetPoint("CENTER", popupItemBtn, "CENTER")
popupItemBtn.text:SetText("Item")

local function PopupSelectType(t)
    popupSelectedType = t
    popupSpellBtn.bg:SetTexture(0.2, t == "spell" and 0.6 or 0.2, 0.2, 0.8)
    popupItemBtn.bg:SetTexture( 0.2, t == "item"  and 0.6 or 0.2, 0.2, 0.8)
end
popupSpellBtn:SetScript("OnClick", function() PopupSelectType("spell") end)
popupItemBtn:SetScript("OnClick",  function() PopupSelectType("item")  end)

local popupAddBtn = CreateFrame("Button", nil, customPopup, "UIPanelButtonTemplate")
popupAddBtn:SetWidth(100); popupAddBtn:SetHeight(24)
popupAddBtn:SetPoint("BOTTOM", customPopup, "BOTTOM", 0, 12)
popupAddBtn:SetText("Add Buff")
popupAddBtn:SetScript("OnClick", function()
    local name = popupNameInput:GetText()
    if not name or name == "" then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000MeggicBuffTracker:|r Please enter a name.")
        return
    end
    local exists, existingName = IsAlreadyTracked(name)
    if exists then
        if existingName == name then
            DEFAULT_CHAT_FRAME:AddMessage("|cffffff00MeggicBuffTracker:|r '" .. name .. "' is already being tracked.")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffffff00MeggicBuffTracker:|r '" .. name .. "' is covered by '" .. existingName .. "' (alias).")
        end
        return
    end
    table.insert(trackedBuffs, { name = name, duration = 60*60, actionType = popupSelectedType, action = name })
    MeggicBuffTrackerDB.buffs = trackedBuffs
    RefreshTrackerRows()
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00MeggicBuffTracker:|r Added " .. name)
    popupNameInput:SetText("")
    PopupSelectType("spell")
    customPopup:Hide()
end)

addCustomBtn:SetScript("OnClick", function()
    if customPopup:IsShown() then
        customPopup:Hide()
    else
        popupNameInput:SetText("")
        PopupSelectType("spell")
        customPopup:SetPoint("CENTER", configFrame, "CENTER", 0, 0)
        customPopup:Show()
    end
end)

-----------------------------
-- TEMPLATE SECTION
-----------------------------
local templateSep = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
templateSep:SetPoint("TOP", configFrame, "TOP", 0, -105)
templateSep:SetText("--- OR Choose a Template ---")
templateSep:SetTextColor(0.5, 0.5, 0.5)

local selectedTemplateIndex = 1

local templateDropBtn = CreateFrame("Button", "MeggicTemplateDropBtn", configFrame, "UIPanelButtonTemplate")
templateDropBtn:SetWidth(190); templateDropBtn:SetHeight(22)
templateDropBtn:SetPoint("TOP", configFrame, "TOP", -30, -128)
templateDropBtn:SetText(buffTemplates[1].label)

local arrowLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
arrowLabel:SetPoint("LEFT", templateDropBtn, "RIGHT", 0, 1)
arrowLabel:SetText("|cffffff00v|r")

local dropList = CreateFrame("Frame", "MeggicTemplateDropList", configFrame)
dropList:SetWidth(200)
dropList:SetFrameLevel(configFrame:GetFrameLevel() + 10)
dropList:SetBackdrop({
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
dropList:SetBackdropColor(0, 0, 0, 0.95)
dropList:Hide()

local dropItems = {}
local function BuildDropList()
    for i = 1, table.getn(dropItems) do dropItems[i]:Hide() end
    local n = table.getn(buffTemplates)
    dropList:SetHeight(8 + n * 20)
    for i = 1, n do
        local item = dropItems[i]
        if not item then
            item = CreateFrame("Button", "MeggicDropItem" .. i, dropList)
            item:SetWidth(192); item:SetHeight(18)
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
        item:SetPoint("TOPLEFT", dropList, "TOPLEFT", 4, -4 - (i-1)*20)
        item:Show()
    end
end

templateDropBtn:SetScript("OnClick", function()
    if dropList:IsShown() then dropList:Hide()
    else BuildDropList(); dropList:SetPoint("TOPLEFT", templateDropBtn, "BOTTOMLEFT", 0, -2); dropList:Show() end
end)

local addTemplateBtn = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
addTemplateBtn:SetWidth(80); addTemplateBtn:SetHeight(22)
addTemplateBtn:SetPoint("LEFT", templateDropBtn, "RIGHT", 10, 0)
addTemplateBtn:SetPoint("TOP",  configFrame, "TOP", 85, -128)
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
        local exists = IsAlreadyTracked(tb.name)
        if exists then
            skipped = skipped + 1
        else
            table.insert(trackedBuffs, { name = tb.name, duration = tb.duration, actionType = tb.actionType, action = tb.action })
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
-- OPTIONS
-----------------------------
local raidOnlySep = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
raidOnlySep:SetPoint("TOP", configFrame, "TOP", 0, -165)
raidOnlySep:SetText("--- Options ---")
raidOnlySep:SetTextColor(0.5, 0.5, 0.5)

-- Shared helper to build the little bordered checkbox look
local function MakeCheckbox(parent, yOffset)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetWidth(14); btn:SetHeight(14)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", 15, yOffset)
    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints(btn)
    btn.bg:SetTexture(0.15, 0.15, 0.15, 1)
    -- thin red border
    local function Edge(a1, p1, a2, p2, w, h)
        local t = btn:CreateTexture(nil, "BORDER")
        t:SetPoint(a1, btn, p1, 0, 0)
        t:SetPoint(a2, btn, p2, w, h)
        t:SetTexture(0.8, 0.1, 0.1, 1)
    end
    Edge("TOPLEFT","TOPLEFT","BOTTOMRIGHT","TOPRIGHT",   0, -1)  -- top
    Edge("TOPLEFT","BOTTOMLEFT","BOTTOMRIGHT","BOTTOMRIGHT", 0, 1) -- bottom
    Edge("TOPLEFT","TOPLEFT","BOTTOMRIGHT","BOTTOMLEFT", 1,  0)  -- left
    Edge("TOPLEFT","TOPRIGHT","BOTTOMRIGHT","BOTTOMRIGHT",-1, 0) -- right
    btn.check = btn:CreateTexture(nil, "OVERLAY")
    btn.check:SetAllPoints(btn)
    btn.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    btn.check:SetAlpha(0)
    return btn
end

-- Option 1: Show only in raid
local raidOnlyBtn = MakeCheckbox(configFrame, -185)
raidOnlyBtn.check:SetAlpha(MeggicBuffTrackerDB.showInRaidOnly and 1 or 0)

local raidOnlyLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
raidOnlyLabel:SetPoint("LEFT", raidOnlyBtn, "RIGHT", 6, 0)
raidOnlyLabel:SetText("Only show tracker when in a raid group")
raidOnlyLabel:SetTextColor(0.9, 0.9, 0.9)

raidOnlyBtn:SetScript("OnClick", function()
    MeggicBuffTrackerDB.showInRaidOnly = not MeggicBuffTrackerDB.showInRaidOnly
    this.check:SetAlpha(MeggicBuffTrackerDB.showInRaidOnly and 1 or 0)
    if MeggicBuffTrackerDB.showInRaidOnly and not UnitInRaid("player") then
        frame:Hide()
    elseif not MeggicBuffTrackerDB.showInRaidOnly then
        frame:Show()
    end
end)

-- Option 2: Solid red bar instead of blinking
local solidBarBtn = MakeCheckbox(configFrame, -205)
solidBarBtn.check:SetAlpha(MeggicBuffTrackerDB.solidMissingBar and 1 or 0)

local solidBarLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
solidBarLabel:SetPoint("LEFT", solidBarBtn, "RIGHT", 6, 0)
solidBarLabel:SetText("Solid red bar for missing buffs (no blink)")
solidBarLabel:SetTextColor(0.9, 0.9, 0.9)

solidBarBtn:SetScript("OnClick", function()
    MeggicBuffTrackerDB.solidMissingBar = not MeggicBuffTrackerDB.solidMissingBar
    this.check:SetAlpha(MeggicBuffTrackerDB.solidMissingBar and 1 or 0)
    -- Immediately apply to any currently-missing rows
    for i = 1, table.getn(rows) do
        local row = rows[i]
        if row and row:IsShown() and row.missing then
            if MeggicBuffTrackerDB.solidMissingBar then
                row.glow:SetTexture(1, 0, 0, 0.35)
                row.glowAlpha = 0.35
            else
                row.glowAlpha = 0
                row.glow:SetTexture(1, 0, 0, 0)
            end
        end
    end
end)

local helpText = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
helpText:SetPoint("BOTTOM", configFrame, "BOTTOM", 0, 15)
helpText:SetText("Shift+Click a row to remove  |  Drag to reorder")
helpText:SetTextColor(0.7, 0.7, 0.7)

configFrame:SetScript("OnShow", function()
    raidOnlyBtn.check:SetAlpha(MeggicBuffTrackerDB.showInRaidOnly and 1 or 0)
    solidBarBtn.check:SetAlpha(MeggicBuffTrackerDB.solidMissingBar and 1 or 0)
end)
configFrame:SetScript("OnHide", function()
    dropList:Hide()
    customPopup:Hide()
end)

-----------------------------
-- UPDATE LOOP
-----------------------------
local elapsed = 0
frame:SetScript("OnUpdate", function()
    elapsed = elapsed + arg1
    if elapsed >= 1 then
        elapsed = 0
        local buffMap = BuildBuffTimeMap()
        for i = 1, table.getn(rows) do
            local row = rows[i]
            if row:IsShown() and row.buff then
                local buff  = row.buff
                local found = IsBuffActive(buff)
                if found then
                    local remaining
                    if buff.actionType == "weapon" then
                        local hasEnchant, enchantExpiry = GetWeaponEnchantInfo()
                        remaining = (hasEnchant and enchantExpiry) and (enchantExpiry / 1000) or buff.duration
                    else
                        local t = GetBuffTimeLeft(buffMap, buff.name)
                        if t == nil or t == 0 then
                            remaining = nil
                        else
                            remaining = t
                        end
                    end
                    row.remaining = remaining or 0
                    if remaining == nil then
                        row.status:SetText("|cffaaaaaa--:--|r")
                        row.status:SetTextColor(1, 1, 1)
                    else
                        if remaining < 0 then remaining = 0 end
                        row.status:SetText(FormatTime(remaining))
                        if remaining < 60 then
                            row.status:SetTextColor(1, 0.3, 0.3)
                        elseif remaining < 300 then
                            row.status:SetTextColor(1, 1, 0)
                        else
                            row.status:SetTextColor(0, 1, 0)
                        end
                    end
                    row.label:SetTextColor(1, 1, 1)
                    row.missing = false
                    row.glow:SetTexture(1, 0, 0, 0)
                    row.glowAlpha = 0
                else
                    row.remaining = 0
                    row.status:SetText("MISSING")
                    row.status:SetTextColor(1, 0, 0)
                    row.label:SetTextColor(1, 0.3, 0.3)
                    row.missing = true
                    -- Set initial glow state based on current mode
                    if MeggicBuffTrackerDB.solidMissingBar then
                        row.glow:SetTexture(1, 0, 0, 0.35)
                        row.glowAlpha = 0.35
                    end
                end
            end
        end
    end
    -- Glow / solid bar animation for missing buffs
    for i = 1, table.getn(rows) do
        local row = rows[i]
        if row:IsShown() and row.missing then
            if MeggicBuffTrackerDB.solidMissingBar then
                -- Solid mode: keep at fixed alpha, no animation needed
                row.glow:SetTexture(1, 0, 0, 0.35)
            else
                -- Blink mode: animate alpha
                row.glowAlpha = row.glowAlpha + (row.glowDir * arg1 * 2)
                if row.glowAlpha >= 0.4 then
                    row.glowDir  = -1
                    row.glowAlpha = 0.4
                elseif row.glowAlpha <= 0 then
                    row.glowDir  = 1
                    row.glowAlpha = 0
                end
                row.glow:SetTexture(1, 0, 0, row.glowAlpha)
            end
        end
    end
end)

-----------------------------
-- EVENT HANDLING
-----------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("VARIABLES_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("RAID_ROSTER_UPDATE")

local wasInRaid = false

eventFrame:SetScript("OnEvent", function()
    if event == "VARIABLES_LOADED" then
        MeggicBuffTrackerDB = MeggicBuffTrackerDB or { buffs = {}, x = 0, y = 0, width = 250, showInRaidOnly = false, solidMissingBar = false }
        if MeggicBuffTrackerDB.showInRaidOnly == nil then MeggicBuffTrackerDB.showInRaidOnly = false end
        if MeggicBuffTrackerDB.solidMissingBar == nil then MeggicBuffTrackerDB.solidMissingBar = false end
        if MeggicBuffTrackerDB.width          == nil then MeggicBuffTrackerDB.width = 250 end
        trackedBuffs = MeggicBuffTrackerDB.buffs or {}
        MeggicBuffTrackerDB.buffs = trackedBuffs
        if MeggicBuffTrackerDB.x and MeggicBuffTrackerDB.y then
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", UIParent, "CENTER", MeggicBuffTrackerDB.x, MeggicBuffTrackerDB.y)
        end
        frame:SetWidth(MeggicBuffTrackerDB.width)
        RefreshTrackerRows()
        wasInRaid = UnitInRaid("player") ~= nil
        if MeggicBuffTrackerDB.showInRaidOnly and not UnitInRaid("player") then
            frame:Hide()
        else
            frame:Show()
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00MeggicBuffTracker|r loaded " .. table.getn(trackedBuffs) .. " saved buffs.")

    elseif event == "PLAYER_LOGOUT" then
        MeggicBuffTrackerDB.buffs = trackedBuffs
        MeggicBuffTrackerDB.width = frame:GetWidth()

    elseif event == "PLAYER_ENTERING_WORLD" then
        wasInRaid = UnitInRaid("player") ~= nil
        if MeggicBuffTrackerDB.showInRaidOnly and UnitInRaid("player") then
            frame:Show()
        end

    elseif event == "RAID_ROSTER_UPDATE" then
        local inRaid = UnitInRaid("player") ~= nil
        if MeggicBuffTrackerDB.showInRaidOnly then
            if inRaid and not wasInRaid then
                frame:Show()
            elseif not inRaid and wasInRaid then
                frame:Hide()
            end
        end
        wasInRaid = inRaid
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
        DEFAULT_CHAT_FRAME:AddMessage("/mbt reset - reset tracker position and size")
        DEFAULT_CHAT_FRAME:AddMessage("/mbt clear - remove all tracked buffs")
        DEFAULT_CHAT_FRAME:AddMessage(" ")
        DEFAULT_CHAT_FRAME:AddMessage("Resize: drag the right edge of the tracker.")
        DEFAULT_CHAT_FRAME:AddMessage("Buff names must match spell/item names exactly.")
        DEFAULT_CHAT_FRAME:AddMessage("Shift+Click a row to remove it. Drag to reorder.")
        DEFAULT_CHAT_FRAME:AddMessage("[-]/[+] button collapses/expands the list to " .. COLLAPSE_ROWS .. " rows.")
    elseif msg == "config" then
        if configFrame:IsShown() then configFrame:Hide() else configFrame:Show() end
    elseif msg == "reset" then
        MeggicBuffTrackerDB.x = 0; MeggicBuffTrackerDB.y = 0; MeggicBuffTrackerDB.width = 250
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        frame:SetWidth(250)
        DEFAULT_CHAT_FRAME:AddMessage("MeggicBuffTracker position and size reset.")
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
DEFAULT_CHAT_FRAME:AddMessage(" /mbt help - commands | /mbt config - open config")