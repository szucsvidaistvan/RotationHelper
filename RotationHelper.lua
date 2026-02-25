-- Configuration
local ICON_SIZE = 45
local SMALL_ICON_SIZE = 25
local updateTimer = 0
local isLocked = true

-- Main Frame Setup
local HunterFrame = CreateFrame("Frame", "HunterHelperFrame", UIParent)
HunterFrame:SetSize(ICON_SIZE, ICON_SIZE)
HunterFrame:SetPoint("CENTER", 0, -150)
HunterFrame:SetMovable(true)
HunterFrame:EnableMouse(false)

-- Main Rotation Icon
HunterFrame.Icon = HunterFrame:CreateTexture(nil, "ARTWORK")
HunterFrame.Icon:SetAllPoints(HunterFrame)
HunterFrame.Icon:SetTexture("Interface\\Icons\\Ability_Hunter_Snipershot")

-- Aspect Frame (Left Side)
local AspectFrame = CreateFrame("Frame", nil, HunterFrame)
AspectFrame:SetSize(SMALL_ICON_SIZE, SMALL_ICON_SIZE)
AspectFrame:SetPoint("TOPLEFT", HunterFrame, "TOPLEFT", -35, 0)
AspectFrame.Icon = AspectFrame:CreateTexture(nil, "OVERLAY")
AspectFrame.Icon:SetAllPoints(AspectFrame)

AspectFrame.Glow = AspectFrame:CreateTexture(nil, "BACKGROUND")
AspectFrame.Glow:SetPoint("CENTER", AspectFrame, 0, 0)
AspectFrame.Glow:SetSize(SMALL_ICON_SIZE + 10, SMALL_ICON_SIZE + 10)
AspectFrame.Glow:SetTexture("Interface\\Buttons\\CheckButtonHilight")
AspectFrame.Glow:SetVertexColor(1, 1, 0)
AspectFrame.Glow:SetBlendMode("ADD")

-- Hunter's Mark Tracker (Right Side)
local MarkFrame = CreateFrame("Frame", nil, HunterFrame)
MarkFrame:SetSize(SMALL_ICON_SIZE, SMALL_ICON_SIZE)
MarkFrame:SetPoint("TOPRIGHT", HunterFrame, "TOPRIGHT", 35, 0)
MarkFrame.Icon = MarkFrame:CreateTexture(nil, "OVERLAY")
MarkFrame.Icon:SetAllPoints(MarkFrame)
-- FIX: Explicit texture path for Hunter's Mark
MarkFrame.Icon:SetTexture("Interface\\Icons\\Ability_Hunter_Snipershot") 

MarkFrame.Glow = MarkFrame:CreateTexture(nil, "BACKGROUND")
MarkFrame.Glow:SetPoint("CENTER", MarkFrame, 0, 0)
MarkFrame.Glow:SetSize(SMALL_ICON_SIZE + 10, SMALL_ICON_SIZE + 10)
MarkFrame.Glow:SetTexture("Interface\\Buttons\\CheckButtonHilight")
MarkFrame.Glow:SetVertexColor(1, 0.8, 0)
MarkFrame.Glow:SetBlendMode("ADD")

-- Off-GCD Flash Frame (Kill Command / Silencing Shot)
local FlashFrame = CreateFrame("Frame", nil, HunterFrame)
FlashFrame:SetSize(SMALL_ICON_SIZE - 5, SMALL_ICON_SIZE - 5)
FlashFrame:SetPoint("BOTTOM", HunterFrame, "TOP", 0, 5)
FlashFrame.Icon = FlashFrame:CreateTexture(nil, "OVERLAY")
FlashFrame.Icon:SetAllPoints(FlashFrame)

-- Helper Functions
local function IsReady(spell)
    if not GetSpellInfo(spell) then return false end
    local start, duration = GetSpellCooldown(spell)
    if not start then return false end
    return (start == 0 or (start + duration - GetTime() <= 0.2))
end

-- Improved Debuff Check for Hunter's Mark
local function HasMark(unit)
    local markName = GetSpellInfo(1130) -- Hunter's Mark
    if not markName then return false end
    for i = 1, 40 do
        local name = UnitDebuff(unit, i)
        if name == markName then return true end
    end
    return false
end

-- MM Rotation
function HunterFrame:GetNextMove()
    local hp = (UnitHealthMax("target") > 0) and (UnitHealth("target") / UnitHealthMax("target") * 100) or 100
    if hp < 20 and IsReady("Kill Shot") then return GetSpellTexture("Kill Shot") end
    
    local stingName = GetSpellInfo(1978)
    if stingName and not UnitDebuff("target", stingName) and IsReady(stingName) then
        return GetSpellTexture(stingName)
    end

    if IsReady("Chimera Shot") then return GetSpellTexture("Chimera Shot") end
    if IsReady("Aimed Shot") then return GetSpellTexture("Aimed Shot") end
    if IsReady("Arcane Shot") then return GetSpellTexture("Arcane Shot") end
    return GetSpellTexture("Steady Shot")
end

-- Update Loop
HunterFrame:SetScript("OnUpdate", function(self, elapsed)
    updateTimer = updateTimer + elapsed
    if updateTimer < 0.15 then return end
    updateTimer = 0

    -- 1. Aspect Logic
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
        AspectFrame.Glow:Show()
        AspectFrame.Icon:SetDesaturated(false)
        AspectFrame:SetAlpha(1)
    else
        AspectFrame.Glow:Hide()
        AspectFrame.Icon:SetDesaturated(true)
        AspectFrame:SetAlpha(0.5)
    end

    -- 2. Target Logic & Hunter's Mark
    if UnitCanAttack("player", "target") and not UnitIsDead("target") then
        self.Icon:SetAlpha(1)
        self.Icon:SetTexture(self:GetNextMove())
        
        -- FIX: Set texture every frame to ensure it stays visible
        MarkFrame.Icon:SetTexture(GetSpellTexture(1130) or "Interface\\Icons\\Ability_Hunter_Snipershot")

        if not HasMark("target") then
            MarkFrame.Icon:SetDesaturated(false)
            MarkFrame.Glow:Show()
            MarkFrame:SetAlpha(1)
        else
            MarkFrame.Glow:Hide()
            MarkFrame.Icon:SetDesaturated(true)
            MarkFrame:SetAlpha(0.3)
        end

        -- Off-GCD Flash
        if IsReady("Kill Command") then
            FlashFrame:Show()
            FlashFrame.Icon:SetTexture(GetSpellTexture("Kill Command"))
        elseif IsReady("Silencing Shot") then
            FlashFrame:Show()
            FlashFrame.Icon:SetTexture(GetSpellTexture("Silencing Shot"))
        else
            FlashFrame:Hide()
        end

        -- Range Check
        if IsSpellInRange(GetSpellInfo(56641), "target") == 0 then
            self.Icon:SetVertexColor(1, 0.3, 0.3)
        else
            self.Icon:SetVertexColor(1, 1, 1)
        end
    else
        self.Icon:SetAlpha(0.3)
        MarkFrame:SetAlpha(0)
        FlashFrame:Hide()
    end
end)

-- Slash Commands
SLASH_HUNTERHELPER1 = "/hh"
SlashCmdList["HUNTERHELPER"] = function()
    isLocked = not isLocked
    HunterFrame:EnableMouse(not isLocked)
    print("|cffff7d0aHunterHelper:|r " .. (isLocked and "Locked" or "Unlocked"))
end

HunterFrame:RegisterForDrag("LeftButton")
HunterFrame:SetScript("OnDragStart", HunterFrame.StartMoving)
HunterFrame:SetScript("OnDragStop", HunterFrame.StopMovingOrSizing)

HunterFrame:RegisterEvent("PLAYER_LOGIN")
HunterFrame:SetScript("OnEvent", function()
    local _, class = UnitClass("player")
    if class == "HUNTER" then
        print("|cffff7d0aHunterHelper:|r Ready. Mark Icon fix applied.")
    else
        HunterFrame:Hide()
    end
end)