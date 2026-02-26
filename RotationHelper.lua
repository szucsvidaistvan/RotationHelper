-- Configuration
local ICON_SIZE = 45
local SMALL_ICON_SIZE = 25
local updateTimer = 0
local isLocked = true
local visibilityMode = "ALWAYS"
local predictionCount = 1 -- Default value set to 1 as requested

-- 1. Settings Panel Setup
local SettingsPanel = CreateFrame("Frame", "HunterHelperSettings", UIParent)
SettingsPanel.name = "HunterHelper"

local title = SettingsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("HunterHelper Settings")

-- Lock Checkbox
local HH_LockCheck = CreateFrame("CheckButton", "HH_LockCheck_Global", SettingsPanel, "InterfaceOptionsCheckButtonTemplate")
HH_LockCheck:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -20)
_G[HH_LockCheck:GetName() .. "Text"]:SetText("Lock Addon (Disable Movement)")

-- Visibility Dropdown
local dropdownLabel = SettingsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
dropdownLabel:SetPoint("TOPLEFT", HH_LockCheck, "BOTTOMLEFT", 0, -20)
dropdownLabel:SetText("Visibility Mode:")

local visDropdown = CreateFrame("Frame", "HH_VisibilityDropdown", SettingsPanel, "UIDropDownMenuTemplate")
visDropdown:SetPoint("TOPLEFT", dropdownLabel, "BOTTOMLEFT", -15, -5)

local function OnVisClick(self)
    visibilityMode = self.value
    UIDropDownMenu_SetSelectedValue(visDropdown, self.value)
    _G[visDropdown:GetName().."Text"]:SetText(self:GetText())
end

UIDropDownMenu_Initialize(visDropdown, function(self, level)
    local info = UIDropDownMenu_CreateInfo()
    local modes = { 
        {text="Always On", val="ALWAYS"}, 
        {text="Combat or Target", val="COMBAT"}, 
        {text="Hidden", val="HIDDEN"} 
    }
    for _, m in ipairs(modes) do
        info.text, info.value, info.func = m.text, m.val, OnVisClick
        info.checked = (visibilityMode == m.val)
        UIDropDownMenu_AddButton(info, level)
    end
end)
UIDropDownMenu_SetSelectedValue(visDropdown, "ALWAYS")
UIDropDownMenu_SetWidth(visDropdown, 120)

-- Prediction Count Slider
local slider = CreateFrame("Slider", "HH_PredictionSlider", SettingsPanel, "OptionsSliderTemplate")
slider:SetPoint("TOPLEFT", visDropdown, "BOTTOMLEFT", 20, -40)
slider:SetMinMaxValues(1, 4)
slider:SetValueStep(1)
slider:SetValue(1) -- Set default slider position to 1
_G[slider:GetName() .. 'Low']:SetText('1')
_G[slider:GetName() .. 'High']:SetText('4')
_G[slider:GetName() .. 'Text']:SetText("Spell Prediction Count: " .. predictionCount)

slider:SetScript("OnValueChanged", function(self, value)
    predictionCount = math.floor(value)
    _G[self:GetName() .. 'Text']:SetText("Spell Prediction Count: " .. predictionCount)
end)

-- Main Frame Setup
local HunterFrame = CreateFrame("Frame", "HunterHelperFrame", UIParent)
HunterFrame:SetSize(ICON_SIZE, ICON_SIZE)
HunterFrame:SetPoint("CENTER", 0, -150)
HunterFrame:SetMovable(true)
HunterFrame:EnableMouse(false)

HH_LockCheck:SetScript("OnClick", function(self)
    isLocked = self:GetChecked()
    HunterFrame:EnableMouse(not isLocked)
end)
InterfaceOptions_AddCategory(SettingsPanel)

-- Prediction Icons Table
HunterFrame.PredictionIcons = {}
for i = 1, 4 do
    local icon = HunterFrame:CreateTexture(nil, "ARTWORK")
    local size = ICON_SIZE - ((i-1) * 7)
    icon:SetSize(size, size)
    
    if i == 1 then
        icon:SetPoint("CENTER", HunterFrame)
    else
        icon:SetPoint("LEFT", HunterFrame.PredictionIcons[i-1], "RIGHT", 8, 0)
    end
    HunterFrame.PredictionIcons[i] = icon
end

-- Side Frames (Aspect & Mark)
local AspectFrame = CreateFrame("Frame", nil, HunterFrame)
AspectFrame:SetSize(SMALL_ICON_SIZE, SMALL_ICON_SIZE)
AspectFrame:SetPoint("RIGHT", HunterFrame, "LEFT", -15, 12)
AspectFrame.Icon = AspectFrame:CreateTexture(nil, "OVERLAY")
AspectFrame.Icon:SetAllPoints(AspectFrame)
AspectFrame.Glow = AspectFrame:CreateTexture(nil, "BACKGROUND")
AspectFrame.Glow:SetPoint("CENTER", AspectFrame)
AspectFrame.Glow:SetSize(SMALL_ICON_SIZE + 10, SMALL_ICON_SIZE + 10)
AspectFrame.Glow:SetTexture("Interface\\Buttons\\CheckButtonHilight")
AspectFrame.Glow:SetBlendMode("ADD")

local MarkFrame = CreateFrame("Frame", nil, HunterFrame)
MarkFrame:SetSize(SMALL_ICON_SIZE, SMALL_ICON_SIZE)
MarkFrame:SetPoint("TOP", AspectFrame, "BOTTOM", 0, -8)
MarkFrame.Icon = MarkFrame:CreateTexture(nil, "OVERLAY")
MarkFrame.Icon:SetAllPoints(MarkFrame)

local FlashFrame = CreateFrame("Frame", nil, HunterFrame)
FlashFrame:SetSize(SMALL_ICON_SIZE - 5, SMALL_ICON_SIZE - 5)
FlashFrame:SetPoint("BOTTOM", HunterFrame.PredictionIcons[1], "TOP", 0, 8)
FlashFrame.Icon = FlashFrame:CreateTexture(nil, "OVERLAY")
FlashFrame.Icon:SetAllPoints(FlashFrame)

-- Prediction Helper
local function IsReadySim(spell, offset, usedSpells)
    if usedSpells[spell] then return false end -- Already "cast" in this prediction chain
    
    local name = GetSpellInfo(spell)
    if not name then return false end
    local start, duration = GetSpellCooldown(name)
    if not start then return false end
    
    local remaining = (start == 0) and 0 or (start + duration - GetTime())
    return (remaining - offset) <= 0.1
end

-- Rotation logic with simulated state
function HunterFrame:GetPredictedSpell(offset, usedSpells)
    local hp = (UnitHealthMax("target") > 0) and (UnitHealth("target") / UnitHealthMax("target") * 100) or 100
    
    -- 1. Kill Shot
    if hp < 20 and IsReadySim("Kill Shot", offset, usedSpells) then return "Kill Shot" end
    
    -- 2. Serpent Sting (Only for the first icon, as we can't easily sim debuff duration)
    local stingName = GetSpellInfo(1978)
    if offset == 0 and stingName and not UnitDebuff("target", stingName, nil, "PLAYER") and IsReadySim(stingName, 0, usedSpells) then
        return "Serpent Sting"
    end

    -- 3. Core Abilities
    if IsReadySim("Chimera Shot", offset, usedSpells) then return "Chimera Shot" end
    if IsReadySim("Aimed Shot", offset, usedSpells) then return "Aimed Shot" end
    if IsReadySim("Arcane Shot", offset, usedSpells) then return "Arcane Shot" end
    
    return "Steady Shot"
end

-- Update Loop
HunterFrame:SetScript("OnUpdate", function(self, elapsed)
    updateTimer = updateTimer + elapsed
    if updateTimer < 0.1 then return end 
    updateTimer = 0

    local inCombat = UnitAffectingCombat("player")
    local hasTarget = UnitCanAttack("player", "target") and not UnitIsDead("target")
    
    if visibilityMode == "HIDDEN" or (visibilityMode == "COMBAT" and not inCombat and not hasTarget) or UnitIsDeadOrGhost("player") then
        self:SetAlpha(0)
        return
    else
        self:SetAlpha(1)
    end

    if UnitCastingInfo("player") or UnitChannelInfo("player") then return end

    -- Aspect Logic
    local hasAspect = false
    for i = 1, 40 do
        local name, _, icon = UnitBuff("player", i)
        if name and name:find("Aspect of the") then
            AspectFrame.Icon:SetTexture(icon)
            hasAspect = true
            break
        end
    end
    if hasAspect then
        AspectFrame.Glow:SetVertexColor(1, 1, 0)
        AspectFrame.Glow:Show()
    else
        AspectFrame.Icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        AspectFrame.Glow:SetVertexColor(1, 0, 0)
        AspectFrame.Glow:Show()
    end

    -- Target & Prediction Logic
    if hasTarget then
        local simOffset = 0
        local usedSpells = {}
        
        for i = 1, 4 do
            if i <= predictionCount then
                local spellName = self:GetPredictedSpell(simOffset, usedSpells)
                self.PredictionIcons[i]:SetTexture(GetSpellTexture(spellName))
                self.PredictionIcons[i]:Show()
                
                -- Mark spell as used so it doesn't show up in the next icon
                if spellName ~= "Steady Shot" then
                    usedSpells[spellName] = true
                end
                simOffset = simOffset + 1.5 -- Increment simulated time (GCD)
            else
                self.PredictionIcons[i]:Hide()
            end
        end
        
        -- Hunter's Mark
        MarkFrame:SetAlpha(1)
        MarkFrame.Icon:SetTexture(GetSpellTexture(1130) or "Interface\\Icons\\Ability_Hunter_Snipershot")
        local markName = GetSpellInfo(1130)
        if markName and not UnitDebuff("target", markName) then
            MarkFrame.Icon:SetDesaturated(false)
        else
            MarkFrame.Icon:SetDesaturated(true)
            MarkFrame:SetAlpha(0.3)
        end

        -- Off-GCD
        local kcStart = GetSpellCooldown("Kill Command")
        if kcStart == 0 then
            FlashFrame:Show()
            FlashFrame.Icon:SetTexture(GetSpellTexture("Kill Command"))
        else
            FlashFrame:Hide()
        end

        -- Range Check
        local inRange = IsSpellInRange(GetSpellInfo(56641), "target")
        self.PredictionIcons[1]:SetVertexColor(1, (inRange == 0 and 0.3 or 1), (inRange == 0 and 0.3 or 1))
    else
        for i = 1, 4 do self.PredictionIcons[i]:Hide() end
        MarkFrame:SetAlpha(0)
        FlashFrame:Hide()
    end
end)

-- Slash Command
SLASH_HUNTERHELPER1 = "/hh"
SlashCmdList["HUNTERHELPER"] = function()
    isLocked = not isLocked
    HH_LockCheck_Global:SetChecked(isLocked) 
    HunterFrame:EnableMouse(not isLocked)
end

HunterFrame:RegisterEvent("PLAYER_LOGIN")
HunterFrame:SetScript("OnEvent", function(self)
    local _, class = UnitClass("player")
    if class ~= "HUNTER" then self:Hide() else HH_LockCheck_Global:SetChecked(true) end
end)