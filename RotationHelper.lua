-- Configuration & Global Variables
local ICON_SIZE = 40 
local SMALL_ICON_SIZE = 28
local SPACING = 5
local updateTimer = 0
local isLocked = true
local visibilityMode = "ALWAYS"
local predictionCount = 2 

-- 1. Settings Panel Setup
local SettingsPanel = CreateFrame("Frame", "RotationHelperSettings", UIParent)
SettingsPanel.name = "RotationHelper"

local function SetupOptions()
    local title = SettingsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("RotationHelper Settings")

    local lockCheck = CreateFrame("CheckButton", "RH_LockCheck_Global", SettingsPanel, "InterfaceOptionsCheckButtonTemplate")
    lockCheck:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -20)
    _G[lockCheck:GetName() .. "Text"]:SetText("Lock Addon (Disable Movement)")
    lockCheck:SetScript("OnClick", function(self)
        isLocked = self:GetChecked()
        if RotationHelperDB then RotationHelperDB.isLocked = isLocked end
        -- MOVE FIX 1: Pipa esetén tiltjuk/engedjük az egeret
        RotationHelperFrame:EnableMouse(not isLocked)
    end)

    local visLabel = SettingsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    visLabel:SetPoint("TOPLEFT", lockCheck, "BOTTOMLEFT", 0, -25)
    visLabel:SetText("Display Mode:")

    local visDropdown = CreateFrame("Frame", "RH_VisDropdown", SettingsPanel, "UIDropDownMenuTemplate")
    visDropdown:SetPoint("TOPLEFT", visLabel, "BOTTOMLEFT", -15, -5)

    UIDropDownMenu_Initialize(visDropdown, function(self)
        local info = UIDropDownMenu_CreateInfo()
        local modes = { {text = "Always On", val = "ALWAYS"}, {text = "Target or Combat", val = "COMBAT"}, {text = "Hide", val = "HIDE"} }
        for _, m in ipairs(modes) do
            info.text, info.value, info.func = m.text, m.val, function(self)
                visibilityMode = self.value
                if RotationHelperDB then RotationHelperDB.visibilityMode = visibilityMode end
                UIDropDownMenu_SetSelectedValue(visDropdown, self.value)
                UIDropDownMenu_SetText(visDropdown, self.text)
            end
            info.checked = (visibilityMode == m.val)
            UIDropDownMenu_AddButton(info)
        end
    end)

    local countLabel = SettingsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    countLabel:SetPoint("TOPLEFT", visDropdown, "BOTTOMLEFT", 15, -20)
    countLabel:SetText("Number of Spells:")

    local countDropdown = CreateFrame("Frame", "RH_CountDropdown", SettingsPanel, "UIDropDownMenuTemplate")
    countDropdown:SetPoint("TOPLEFT", countLabel, "BOTTOMLEFT", -15, -5)

    UIDropDownMenu_Initialize(countDropdown, function(self)
        local info = UIDropDownMenu_CreateInfo()
        for i = 1, 4 do
            info.text, info.value, info.func = tostring(i), i, function(self)
                predictionCount = self.value
                if RotationHelperDB then RotationHelperDB.predictionCount = predictionCount end
                UIDropDownMenu_SetSelectedValue(countDropdown, self.value)
                UIDropDownMenu_SetText(countDropdown, tostring(self.value))
            end
            info.checked = (predictionCount == i)
            UIDropDownMenu_AddButton(info)
        end
    end)
end
SetupOptions()

-- 2. Main Frame Setup
local MainFrame = CreateFrame("Frame", "RotationHelperFrame", UIParent)
MainFrame:SetSize(200, ICON_SIZE) -- Eredeti méret visszaállítva
MainFrame:SetPoint("CENTER", 0, -150)
MainFrame:SetMovable(true)
MainFrame:SetClampedToScreen(true)
MainFrame:SetFrameStrata("HIGH")
-- MOVE FIX 2: Alapból kikapcsolva, hogy ne blokkoljon
MainFrame:EnableMouse(false)

local function CreateHelperIcon(parent, texture)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(SMALL_ICON_SIZE, SMALL_ICON_SIZE)
    f.Icon = f:CreateTexture(nil, "BORDER")
    f.Icon:SetAllPoints(f)
    f.Icon:SetTexture(texture)
    f.Icon:SetDesaturated(true)
    f.CD = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
    f.CD:SetAllPoints(f)
    f.Glow = f:CreateTexture(nil, "BACKGROUND")
    f.Glow:SetPoint("CENTER", f); f.Glow:SetSize(SMALL_ICON_SIZE + 8, SMALL_ICON_SIZE + 8)
    f.Glow:SetTexture("Interface\\Buttons\\CheckButtonHilight"); f.Glow:SetBlendMode("ADD"); f.Glow:Hide()
    return f
end

-- Felső sor (Buffok/Debuffok)
local AspectFrame = CreateHelperIcon(MainFrame, "Interface\\Icons\\INV_Misc_QuestionMark")
local BuffFrame = CreateHelperIcon(MainFrame, "Interface\\Icons\\Ability_TrueShot")
local MarkFrame = CreateHelperIcon(MainFrame, "Interface\\Icons\\Ability_Hunter_Snipershot")
local StingFrame = CreateHelperIcon(MainFrame, "Interface\\Icons\\Ability_Hunter_Quickshot")

-- Felső sor pozíciója (Pontosan az eredeti koordináták)
local topRowWidth = (SMALL_ICON_SIZE * 4) + (SPACING * 3)
AspectFrame:SetPoint("BOTTOMLEFT", MainFrame, "TOPLEFT", (200 - topRowWidth)/2, 8)
BuffFrame:SetPoint("LEFT", AspectFrame, "RIGHT", SPACING, 0)
MarkFrame:SetPoint("LEFT", BuffFrame, "RIGHT", SPACING, 0)
StingFrame:SetPoint("LEFT", MarkFrame, "RIGHT", SPACING, 0)

-- Rotációs ikonok (Alsó sor)
MainFrame.PredictionIcons = {}
for i = 1, 4 do
    local icon = MainFrame:CreateTexture(nil, "ARTWORK")
    local size = (i == 1) and ICON_SIZE or (ICON_SIZE - 8)
    icon:SetSize(size, size)
    MainFrame.PredictionIcons[i] = icon
end

-- Függvény a rotáció középre igazításához
local function UpdateRotationLayout()
    local totalWidth = 0
    for i = 1, predictionCount do
        totalWidth = totalWidth + (i == 1 and ICON_SIZE or (ICON_SIZE - 8))
        if i < predictionCount then totalWidth = totalWidth + 5 end
    end
    
    local startX = (200 - totalWidth) / 2
    for i = 1, 4 do
        if i <= predictionCount then
            MainFrame.PredictionIcons[i]:ClearAllPoints()
            if i == 1 then
                MainFrame.PredictionIcons[i]:SetPoint("LEFT", MainFrame, "LEFT", startX, 0)
            else
                MainFrame.PredictionIcons[i]:SetPoint("LEFT", MainFrame.PredictionIcons[i-1], "RIGHT", 5, 0)
            end
            MainFrame.PredictionIcons[i]:Show()
        else
            MainFrame.PredictionIcons[i]:Hide()
        end
    end
end

-- Logic
local function IsReady(spellID, offset)
    local name = GetSpellInfo(spellID)
    if not name then return false end
    local start, duration = GetSpellCooldown(name)
    if not start then return true end
    local currentCD = (start == 0) and 0 or (start + duration - GetTime())
    return (currentCD - (offset or 0)) <= 0.2
end

function MainFrame:GetNextSpell(offset, used)
    local hasTarget = UnitCanAttack("player", "target") and not UnitIsDead("target")
    if not hasTarget then
        local defaults = {1978, 53209, 49050, 49045}
        return defaults[math.floor(offset/1.5) + 1] or 49052
    end
    local hp = (UnitHealthMax("target") > 0) and (UnitHealth("target") / UnitHealthMax("target") * 100) or 100
    if hp < 20 and IsReady(53351, offset) and not used[53351] then return 53351 end
    local ssName = GetSpellInfo(1978)
    if offset == 0 and not UnitDebuff("target", ssName, nil, "PLAYER") then return 1978 end
    if IsReady(53209, offset) and not used[53209] then return 53209 end
    if IsReady(49050, offset) and not used[49050] then return 49050 end
    if IsReady(49045, offset) and not used[49045] then return 49045 end
    return 49052
end

MainFrame:SetScript("OnUpdate", function(self, elapsed)
    updateTimer = updateTimer + elapsed
    if updateTimer < 0.1 then return end 
    updateTimer = 0

    local inCombat = UnitAffectingCombat("player")
    local hasTarget = UnitCanAttack("player", "target") and not UnitIsDead("target")
    
    if visibilityMode == "HIDE" then self:SetAlpha(0) return end
    if visibilityMode == "COMBAT" and not (inCombat or hasTarget) then self:SetAlpha(0) return end
    self:SetAlpha(1)

    -- Aspects
    local hasAspect = false
    for i = 1, 40 do
        local name, _, icon = UnitBuff("player", i)
        if name and (name:find("Aspect") or name:find("Aspektus")) then
            AspectFrame.Icon:SetTexture(icon); AspectFrame.Icon:SetDesaturated(false); AspectFrame.Glow:Hide()
            hasAspect = true break
        end
    end
    if not hasAspect then AspectFrame.Icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark"); AspectFrame.Glow:Show() end

    -- Status sor
    BuffFrame.Icon:SetDesaturated(not UnitBuff("player", GetSpellInfo(19506)))
    
    -- HUNTER'S MARK FIX: Eredeti sor helyett biztosabb lekérés
    local hmName = GetSpellInfo(1130)
    local _, _, _, _, _, hmDur, hmExp = UnitDebuff("target", hmName)
    MarkFrame.Icon:SetDesaturated(not hmExp); MarkFrame.CD:SetCooldown(hmExp and (hmExp - hmDur) or 0, hmDur or 0)
    
    local _, _, _, _, _, ssDur, ssExp = UnitDebuff("target", GetSpellInfo(1978), nil, "PLAYER")
    StingFrame.Icon:SetDesaturated(not ssExp); StingFrame.CD:SetCooldown(ssExp and (ssExp - ssDur) or 0, ssDur or 0)

    -- Rotation & Layout
    UpdateRotationLayout()
    local used, offset = {}, 0
    for i = 1, predictionCount do
        local sID = self:GetNextSpell(offset, used)
        local _, _, tex = GetSpellInfo(sID)
        self.PredictionIcons[i]:SetTexture(tex)
        if sID ~= 49052 then used[sID] = true end
        offset = offset + 1.5
    end
end)

-- Movement
MainFrame:SetScript("OnMouseDown", function(self, button) if button == "LeftButton" and not isLocked then self:StartMoving() end end)
MainFrame:SetScript("OnMouseUp", function(self) self:StopMovingOrSizing(); local p, _, rp, x, y = self:GetPoint()
    if RotationHelperDB then RotationHelperDB.pos = {p, rp, x, y} end end)

SLASH_ROTATIONHELPER1 = "/rh"
SlashCmdList["ROTATIONHELPER"] = function()
    isLocked = not isLocked
    if RotationHelperDB then RotationHelperDB.isLocked = isLocked end
    RH_LockCheck_Global:SetChecked(isLocked)
    -- MOVE FIX 3: Parancsra aktiváljuk az egeret
    MainFrame:EnableMouse(not isLocked)
    print("RotationHelper: " .. (isLocked and "|cFFFF0000Locked|r" or "|cFF00FF00Unlocked|r"))
end

MainFrame:RegisterEvent("PLAYER_LOGIN")
MainFrame:SetScript("OnEvent", function(self)
    if not RotationHelperDB then RotationHelperDB = { isLocked = true, visibilityMode = "ALWAYS", predictionCount = 2, pos = {"CENTER", "CENTER", 0, -150} } end
    isLocked, visibilityMode, predictionCount = RotationHelperDB.isLocked, RotationHelperDB.visibilityMode, RotationHelperDB.predictionCount
    self:ClearAllPoints(); self:SetPoint(RotationHelperDB.pos[1], UIParent, RotationHelperDB.pos[2], RotationHelperDB.pos[3], RotationHelperDB.pos[4])
    RH_LockCheck_Global:SetChecked(isLocked)
    -- MOVE FIX 4: Belépéskor beállítjuk
    self:EnableMouse(not isLocked)
    
    UIDropDownMenu_SetText(RH_VisDropdown, visibilityMode == "ALWAYS" and "Always On" or visibilityMode == "COMBAT" and "Target or Combat" or "Hide")
    UIDropDownMenu_SetText(RH_CountDropdown, tostring(predictionCount))
    InterfaceOptions_AddCategory(SettingsPanel)
end)