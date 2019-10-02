local GetSpellBonusHealing, UnitPower, UnitHealthMax, UnitHealth, CreateFrame, C_Timer, InCombatLockdown, GetTime = GetSpellBonusHealing, UnitPower, UnitHealthMax, UnitHealth, CreateFrame, C_Timer, InCombatLockdown, GetTime
local GetUnitFrame = LibStub("LibGetFrame-1.0").GetUnitFrame
if select(2, UnitClass("player")) ~= "PRIEST" then return end
local debug = false

local print_debug = function(...)
    if debug then
        print(...)
    end
end

local spells = {
    { name = "H1", min = 337, max = 389, cost = 132, spellId = 2054, baseCastTime = 3 },
    { name = "H2", min = 489, max = 558, cost = 174, spellId = 2055, baseCastTime = 3 },
    { name = "H3", min = 644, max = 729, cost = 217, spellId = 6063, baseCastTime = 3 },
    { name = "H4", min = 807, max = 910, cost = 259, spellId = 6064, baseCastTime = 3 },
    { name = "GH1", min = 1016, max = 1143, cost = 314, spellId = 2060, baseCastTime = 3 },
    { name = "GH2", min = 1295, max = 1450, cost = 387, spellId = 10963, baseCastTime = 3 },
    { name = "GH3", min = 1617, max = 1807, cost = 463, spellId = 10964, baseCastTime = 3 },
    { name = "GH4", min = 1994, max = 2224, cost = 557, spellId = 10965, baseCastTime = 3 },
}

local shiftSpells = {
    { name = "F1", min = 222, max = 272, cost = 125, spellId = 2061, baseCastTime = 1.5 },
    { name = "F2", min = 295, max = 358, cost = 155, spellId = 9472, baseCastTime = 1.5 },
    { name = "F3", min = 373, max = 447, cost = 185, spellId = 9473, baseCastTime = 1.5 },
    { name = "F4", min = 455, max = 542, cost = 215, spellId = 9474, baseCastTime = 1.5 },
    { name = "F5", min = 587, max = 696, cost = 265, spellId = 10915, baseCastTime = 1.5 },
    { name = "F6", min = 728, max = 861, cost = 315, spellId = 10916, baseCastTime = 1.5 },
    { name = "F7", min = 911, max = 1073, cost = 380, spellId = 10917, baseCastTime = 1.5 },
}

local buttons = {}
local shift = false
local healingPower, mana

local f = CreateFrame("Frame")

local IterateGroupMembers = function(reversed, forceParty)
    local unit = (not forceParty and IsInRaid()) and 'raid' or 'party'
    local numGroupMembers = unit == 'party' and GetNumSubgroupMembers() or GetNumGroupMembers()
    local i = reversed and numGroupMembers or (unit == 'party' and 0 or 1)
    return function()
      local ret
      if i == 0 and unit == 'party' then
        ret = 'player'
      elseif i <= numGroupMembers and i > 0 then
        ret = unit .. i
      end
      i = i + (reversed and -1 or 1)
      return ret
    end
end

local groupUnit = { ["player"] = true }
for i = 1, 4 do
    groupUnit["party"..i] = true
end
for i = 1, 40 do
    groupUnit["raid"..i] = true
end

local last
local function updateStats()
    print_debug("updateStats")
    local now = GetTime()
    if now ~= last then
        healingPower = GetSpellBonusHealing()
        mana = UnitPower("player", 0)
        last = now
    end
end

local buttonHide = function(button)
    print_debug("buttonHide")
    button:Hide()
    button:SetAttribute("unit", nil)
    button:SetAttribute("type1", nil)
    button:SetAttribute("spell1", nil)
    button:SetAttribute("shift-type1", nil)
    button:SetAttribute("shift-spell1", nil)
end

local space = 5

local updateUnitColor = function(unit)
    print_debug("updateUnitColor", unit)
    local activeSpells = shift and shiftSpells or spells
    local deficit = UnitHealthMax(unit) - UnitHealth(unit)
    local bestFound
    for i = 8, 1, -1 do
        local button = buttons[unit.."-"..i]
        if button then
            local spell = activeSpells[i]
            if spell then
                local bonus = healingPower * (spell.baseCastTime / 3.5)
                local spellMaxHealing = spell.max + bonus -- calculate max heal
                if spellMaxHealing > deficit then
                    button.texture:SetColorTexture(1, 0, 0, 0) -- invisible
                else
                    local enoughMana
                    if mana >= spell.cost then
                        enoughMana = true
                    end
                    if not bestFound then
                        if enoughMana then
                            button.texture:SetColorTexture(0, 1, 0, 0.6) -- green
                        end
                        bestFound = true
                    else
                        if enoughMana then
                            button.texture:SetColorTexture(1, 1, 0, 0.6) -- yellow
                        end
                    end
                    if not enoughMana then
                        button.texture:SetColorTexture(1, 0.5, 0, 0.6) -- orange
                    end
                end
            end
        end
    end
end

local updateAllUnitColor = function()
    print_debug("updateAllUnitColor")
    for unit in IterateGroupMembers() do
        updateUnitColor(unit)
    end
end

local InitSquares = function()
    print_debug("InitSquares")
    for _, button in pairs(buttons) do
        buttonHide(button)
    end

    updateStats()
    for unit in IterateGroupMembers() do
        local frame = GetUnitFrame(unit)
        if frame then
            local scale = frame:GetEffectiveScale()
            local size = (frame:GetWidth() * scale - (space * scale * 2)) / 4
            local x, y = space * scale, -5 - space * scale
            for i = 1, 8 do
                local buttonName = unit.."-"..i
                local button = buttons[buttonName]
                if not button then
                    button = CreateFrame("Button", "EZPRIEST_BUTTON"..buttonName, f, "SecureActionButtonTemplate")
                    button:SetFrameStrata("DIALOG")
                    buttons[buttonName] = button
                    button.texture = button:CreateTexture(nil, "DIALOG")
                    button.texture:SetAllPoints()
                end
                button:SetAttribute("unit", unit)
                button:SetAttribute("type1", "spell")
                button:SetAttribute("spell1", spells[i] and spells[i].spellId)
                button:SetAttribute("shift-type1", "spell")
                button:SetAttribute("shift-spell1", shiftSpells[i] and shiftSpells[i].spellId)
                button:SetSize(size, size)
                button.texture:SetColorTexture(1, 0, 0, 1)
                button:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
                if i == 4 then
                    x = space * scale
                    y = y - size
                else
                    x = x + size
                end
                button:Show()
            end
        end
    end
    updateAllUnitColor()
end

local function Update()
    print_debug("Update")
    if not InCombatLockdown() then
        InitSquares()
    else -- in combat, try again in 2s
        C_Timer.After(2, Update)
    end
end

local DelayedUpdate = function()
    print_debug("DelayedUpdate")
    C_Timer.After(3, Update) -- wait 3s for addons to set their frames
end

f:SetScript("OnEvent", function(self, event, ...)
    return self[event](self, event, ...)
end)

function f:GROUP_ROSTER_UPDATE(event)
    print_debug(event)
    DelayedUpdate()
end

function f:PLAYER_REGEN_DISABLED(event)
    print_debug(event)
    DelayedUpdate()
end

function f:PLAYER_ENTERING_WORLD(event)
    print_debug(event)
    DelayedUpdate()
end

function f:ADDON_LOADED(event, addonName)
    print_debug(event, addonName)
    if addonName == "EZPriest" then
        DelayedUpdate()
    end
end

function f:MODIFIER_STATE_CHANGED(event, key, state)
    if key == "LSHIFT" or key == "RSHIFT" then
        print_debug(event)
        shift = state == 1
        updateStats()
        updateAllUnitColor()
    end
end

function f:UNIT_HEALTH(event, unit)
    print_debug(event, unit)
    if groupUnit[unit] then
        updateStats()
        updateUnitColor(unit)
    end
end

function f:UNIT_POWER_UPDATE(event, unit)
    print_debug(event, unit)
    updateStats()
    updateAllUnitColor()
end

f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:RegisterEvent("GROUP_ROSTER_UPDATE")
f:RegisterEvent("UNIT_HEALTH")
f:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("MODIFIER_STATE_CHANGED")