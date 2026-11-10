-- PlateIntel module CastAdvisor: the recommendation window. Written for PlateIntel. Copyright (c) 2026 Rogerio Camorim.
-- GPL-3.0-or-later, see LICENSE.
--
-- A big icon and name for the best next spell with the reason, two smaller icons for what follows, the mana now, and
-- a gauge of how much of the target's health your DoTs will still take. The gauge is a StatusBar: the target's health
-- is hidden in combat, so only the widget can compare it with the damage; a full bar means the DoTs are enough, and
-- the wand or a rest is all you need.
-- Plain Frame (never protected), so it can be changed in combat.
local _, BIT = ...
local ns = BIT.Module("CastAdvisor")

local Window = {}
ns.Window = Window

local WHITE = "Interface\\Buttons\\WHITE8X8"
local frame

local function save()
    local settings = ns.Settings()
    if not frame or not settings then return end
    local cx, cy = frame:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if not cx or not ux then return end
    local scale = frame:GetScale() or 1
    settings.x, settings.y = math.floor((cx * scale - ux) + 0.5), math.floor((cy * scale - uy) + 0.5)
end

local function build()
    frame = CreateFrame("Frame", "PlateIntelAdvisorWindow", UIParent, "BackdropTemplate")
    frame:SetSize(214, 86)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        local settings = ns.Settings()
        if settings and not settings.locked then self:StartMoving() end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        save()
    end)
    BIT.UI.Backdrop(frame, 0.06, 0.85)

    frame.big = CreateFrame("Frame", nil, frame)
    frame.big:SetSize(40, 40)
    frame.big:SetPoint("TOPLEFT", 8, -8)
    frame.big.icon = frame.big:CreateTexture(nil, "ARTWORK")
    frame.big.icon:SetAllPoints()
    frame.big.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    frame.name = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.name:SetPoint("TOPLEFT", frame.big, "TOPRIGHT", 8, -2)
    frame.name:SetPoint("RIGHT", -8, 0)
    frame.name:SetJustifyH("LEFT")
    frame.reason = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.reason:SetPoint("TOPLEFT", frame.name, "BOTTOMLEFT", 0, -3)
    frame.reason:SetPoint("RIGHT", -8, 0)
    frame.reason:SetJustifyH("LEFT")

    frame.next = {}
    for i = 1, 2 do
        local small = CreateFrame("Frame", nil, frame)
        small:SetSize(22, 22)
        small:SetPoint("TOPLEFT", frame.big, "BOTTOMLEFT", (i - 1) * 26, -6)
        small.icon = small:CreateTexture(nil, "ARTWORK")
        small.icon:SetAllPoints()
        small.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        small:SetAlpha(0.8)
        frame.next[i] = small
    end

    frame.mana = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.mana:SetPoint("BOTTOMRIGHT", -8, 20)

    -- DoT damage against the target's health (full = enough to kill).
    frame.gauge = CreateFrame("StatusBar", nil, frame)
    frame.gauge:SetPoint("BOTTOMLEFT", 8, 8)
    frame.gauge:SetPoint("BOTTOMRIGHT", -8, 8)
    frame.gauge:SetHeight(8)
    frame.gauge:SetStatusBarTexture(WHITE)
    frame.gauge:SetStatusBarColor(0.7, 0.25, 0.85, 0.9)
    frame.gauge:SetMinMaxValues(0, 1)
    frame.gauge:SetValue(0)
    frame.gauge.bg = frame.gauge:CreateTexture(nil, "BACKGROUND")
    frame.gauge.bg:SetAllPoints()
    frame.gauge.bg:SetColorTexture(0, 0, 0, 0.6)
    frame.gaugeLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.gaugeLabel:SetPoint("BOTTOMLEFT", frame.gauge, "TOPLEFT", 0, 2)
    frame.gaugeLabel:SetText(BIT.L("DoT damage vs health"))
end

function Window.Apply()
    local settings = ns.Settings()
    if not settings then return end
    if not frame then build() end
    frame:SetScale(settings.scale or 1)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", settings.x, settings.y)
    frame:EnableMouse(not settings.locked)
    frame:SetShown(settings.showWindow ~= false)
end

local function setIcon(holder, spell)
    holder.icon:SetTexture(spell and spell.icon or nil)
    holder:SetShown(spell ~= nil)
end

local function updateGauge(s)
    local gauge = frame.gauge
    local DoT = BIT.modules.DoTInfo
    local ok = false
    if s.hasTarget and DoT and DoT.lethalDamage and DoT.dotBreakdownForUnit then
        ok = pcall(function()
            local entries = DoT.dotBreakdownForUnit("target")
            gauge:SetMinMaxValues(0, UnitHealth("target"))
            gauge:SetValue(DoT.lethalDamage(entries))
        end)
    end
    if not ok then
        gauge:SetMinMaxValues(0, 1)
        gauge:SetValue(0)
    end
end

-- picks: { { key, reason }, ... }; hint: text when there is no pick; s: the snapshot.
function Window.Update(picks, hint, s)
    if not frame or not frame:IsShown() then return end
    local first = picks[1]
    if first then
        local spell = ns.Spell(first.key)
        setIcon(frame.big, spell)
        frame.name:SetText(spell.name or "")
        frame.reason:SetText(first.reason or "")
    else
        setIcon(frame.big, nil)
        frame.name:SetText(hint and BIT.L(hint) or "")
        frame.reason:SetText("")
    end
    for i, small in ipairs(frame.next) do
        local pick = picks[i + 1]
        setIcon(small, pick and ns.Spell(pick.key) or nil)
    end
    frame.mana:SetText(s.mana and string.format("%s %d%%", BIT.L("Mana"), math.floor(s.mana + 0.5)) or "")
    updateGauge(s)
end
