-- PlateIntel module CastAdvisor: the mob list, a HealBot-style grid of cells, one per mob you may have DoTs on.
-- Written for PlateIntel. Copyright (c) 2026 Rogerio Camorim. GPL-3.0-or-later, see LICENSE.
--
-- How it works (the same idea as HealBot's unit buttons, which run on this client with SecureUnitButtonTemplate):
--   * Each cell is a secure unit button created at login (never in combat) and bound to one unit token: cell 0 to
--     "target", cell N to "nameplateN". RegisterUnitWatch makes the game show a cell while its unit exists and hide
--     it when the mob is gone or dead, in combat too. A mob you pull or target mid-fight therefore gets its cell by
--     itself, as long as it has a nameplate (or is the target).
--   * Clicks run secure actions on the cell's unit: left targets the mob; the spell clicks (Warlock.lua) cast a DoT on
--     that mob without changing your target. Attributes only change out of combat, so the bindings are set then.
--   * Addons cannot create, move or re-bind protected frames in combat. The grid is fixed (cell N is always in slot N),
--     and everything that changes in combat is an ordinary child widget: health bar, name, DoT squares, colours.
--   * When a mob dies or its plate goes away its cell disappears; a plain "ghost" frame in the same slot keeps its name
--     and last DoT squares for a while (setting: deadSeconds), greyed, not clickable.
-- Health and names are secret values: they only go into a StatusBar and a FontString, never into Lua logic.
local _, BIT = ...
local ns = BIT.Module("CastAdvisor")

local MobList = {}
ns.MobList = MobList

local WHITE = "Interface\\Buttons\\WHITE8X8"
local GAP = 3
local DUE_SECONDS = 4 -- a DoT with less than this left (plus its cast time) is due for a refresh

local COLOR = {
    ok = { 0.25, 0.8, 0.3 }, due = { 0.95, 0.8, 0.2 }, missing = { 0.85, 0.2, 0.2 }, none = { 0.45, 0.45, 0.45 },
    hostile = { 0.55, 0.14, 0.14 }, friendly = { 0.2, 0.45, 0.2 }, dead = { 0.25, 0.25, 0.25 },
}
local RANK = { ok = 1, due = 2, missing = 3 }

local container, handle
local cells, ghosts = {}, {} -- [index] -> frame; index 0 is the target, N is nameplateN
local lastBindings

local function unitFor(index) return index == 0 and "target" or ("nameplate" .. index) end

local function plainBool(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok and not ns.isSecret(value) and type(value) == "boolean" then return value end
end

local function paint(texture, c, a) texture:SetColorTexture(c[1], c[2], c[3], a or 1) end

---------------------------------------------------------------------------------------------
-- Building a cell
---------------------------------------------------------------------------------------------

-- The look shared by a live cell and its ghost.
local function decorate(f)
    f.edge = f:CreateTexture(nil, "BACKGROUND", nil, -2)
    f.edge:SetPoint("TOPLEFT", -1, 1)
    f.edge:SetPoint("BOTTOMRIGHT", 1, -1)
    paint(f.edge, COLOR.none)
    f.bg = f:CreateTexture(nil, "BACKGROUND", nil, -1)
    f.bg:SetAllPoints()
    f.bg:SetColorTexture(0, 0, 0, 0.75)
    f.hp = CreateFrame("StatusBar", nil, f)
    f.hp:SetAllPoints()
    f.hp:SetStatusBarTexture(WHITE)
    f.hp:SetStatusBarColor(COLOR.hostile[1], COLOR.hostile[2], COLOR.hostile[3], 0.9)
    f.hp:SetMinMaxValues(0, 1)
    f.hp:SetValue(1)
    f.name = f.hp:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.name:SetPoint("TOPLEFT", 4, -3)
    f.name:SetPoint("RIGHT", -4, 0)
    f.name:SetJustifyH("LEFT")
    f.name:SetWordWrap(false)
    f.tag = f.hp:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.tag:SetPoint("BOTTOMRIGHT", -4, 3)
    f.sq = {}
    for i = 1, 4 do
        local square = f.hp:CreateTexture(nil, "OVERLAY")
        square:SetSize(9, 5)
        square:SetPoint("BOTTOMLEFT", 4 + (i - 1) * 11, 3)
        paint(square, COLOR.none)
        f.sq[i] = square
    end
end

local function showTip(self)
    local class = ns.class
    if not class or not self.lefts then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(BIT.L("DoTs on this mob"), 1, 0.82, 0)
    for _, key in ipairs(class.dots) do
        local spell = ns.Spell(key)
        if spell.known then
            local left = self.lefts[key]
            if left then
                GameTooltip:AddDoubleLine(spell.name, string.format("%.0fs", left), 1, 1, 1, 0.7, 1, 0.7)
            else
                GameTooltip:AddDoubleLine(spell.name, BIT.L("missing"), 1, 1, 1, 1, 0.4, 0.4)
            end
        end
    end
    GameTooltip:Show()
end

local function newCell(index)
    local unit = unitFor(index)
    local cell = CreateFrame("Button", "PlateIntelAdvisorCell" .. index, container, "SecureUnitButtonTemplate")
    cell.unit, cell.index = unit, index
    cell:SetAttribute("unit", unit)
    cell:SetAttribute("*type1", "target")
    cell:RegisterForClicks("AnyUp")
    decorate(cell)
    cell:HookScript("OnEnter", showTip)
    cell:HookScript("OnLeave", function() GameTooltip:Hide() end)
    cells[index] = cell
    RegisterUnitWatch(cell) -- the game shows the cell while the unit exists and hides it when it does not

    local ghost = CreateFrame("Frame", nil, container)
    decorate(ghost)
    ghost.name:SetTextColor(0.6, 0.6, 0.6)
    ghost:Hide()
    ghosts[index] = ghost
end

---------------------------------------------------------------------------------------------
-- Layout, bindings, position (out of combat only)
---------------------------------------------------------------------------------------------

local function savePosition()
    local settings = ns.Settings()
    if not container or not settings then return end
    local cx, cy = container:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if not cx or not ux then return end
    local scale = container:GetScale() or 1
    settings.listX, settings.listY = math.floor(cx * scale - ux + 0.5), math.floor(cy * scale - uy + 0.5)
end

local function ensureContainer()
    if container then return end
    container = CreateFrame("Frame", "PlateIntelAdvisorList", UIParent)
    container:SetMovable(true)
    container:SetClampedToScreen(true)
    handle = CreateFrame("Frame", nil, UIParent)
    handle:SetSize(110, 14)
    handle:SetPoint("BOTTOMLEFT", container, "TOPLEFT", 0, 3)
    handle.bg = handle:CreateTexture(nil, "BACKGROUND")
    handle.bg:SetAllPoints()
    handle.bg:SetColorTexture(0, 0, 0, 0.6)
    handle.text = handle:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    handle.text:SetPoint("CENTER")
    handle.text:SetText(BIT.L("Drag to move"))
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    handle:SetScript("OnDragStart", function()
        if InCombatLockdown() then return end -- protected cells cannot move in combat
        container:StartMoving()
    end)
    handle:SetScript("OnDragStop", function()
        container:StopMovingOrSizing()
        savePosition()
    end)
end

local function layout(settings)
    local w, h = settings.cellWidth, settings.cellHeight
    local cols = math.max(1, math.floor(settings.columns))
    local count = 0
    for index, cell in pairs(cells) do
        count = count + 1
        local col, row = index % cols, math.floor(index / cols)
        for _, f in ipairs({ cell, ghosts[index] }) do
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", container, "TOPLEFT", col * (w + GAP), -row * (h + GAP))
            f:SetSize(w, h)
        end
    end
    local rows = math.ceil(count / cols)
    container:SetSize(math.max(1, cols * (w + GAP) - GAP), math.max(1, rows * (h + GAP) - GAP))
end

local function applyBindings()
    local class = ns.class
    if not class then return end
    for _, cell in pairs(cells) do
        for _, click in ipairs(class.clicks) do
            local prefix = click.mod ~= "" and (click.mod .. "-") or ""
            local spell = ns.Spell(click.key)
            if spell.name then
                cell:SetAttribute(prefix .. "type" .. click.button, "spell")
                cell:SetAttribute(prefix .. "spell" .. click.button, spell.name)
            end
        end
    end
end

function MobList.Apply()
    local settings = ns.Settings()
    if not settings or not ns.class then return end
    if InCombatLockdown() then return end -- Core re-applies when combat ends
    ensureContainer()
    for index = 0, math.max(1, math.min(16, math.floor(settings.poolSize))) do
        if not cells[index] then newCell(index) end
    end
    layout(settings)
    applyBindings()
    container:SetScale(settings.scale or 1)
    container:ClearAllPoints()
    container:SetPoint("CENTER", UIParent, "CENTER", settings.listX, settings.listY)
    container:SetShown(settings.showList ~= false)
    handle:SetShown(settings.showList ~= false and not settings.locked)
end

---------------------------------------------------------------------------------------------
-- Updating a cell (plain widgets: allowed in combat)
---------------------------------------------------------------------------------------------

local function updateCell(c, now)
    local class, unit = ns.class, c.unit
    local dead = plainBool(UnitIsDeadOrGhost, unit) == true
    local hostile = plainBool(UnitCanAttack, "player", unit)
    pcall(function()
        c.hp:SetMinMaxValues(0, UnitHealthMax(unit))
        c.hp:SetValue(dead and 0 or UnitHealth(unit))
        local name = UnitName(unit)
        c.name:SetText(name)
        c.snapName = name -- may be secret: only ever handed back to SetText
    end)
    local tint = dead and COLOR.dead or (hostile == false and COLOR.friendly or COLOR.hostile)
    c.hp:SetStatusBarColor(tint[1], tint[2], tint[3], 0.9)
    c.name:SetTextColor(dead and 0.6 or 1, dead and 0.6 or 1, dead and 0.6 or 1)

    local left = ns.DotsLeft(unit, now)
    c.lefts = left
    local worst, anyDot = "ok", false
    local states = {}
    for i, key in ipairs(class.dots) do
        local spell = ns.Spell(key)
        local square = c.sq[i]
        if spell.known then
            local remaining = left[key]
            local state = (not remaining and "missing") or (remaining < spell.cast + DUE_SECONDS and "due") or "ok"
            if remaining then anyDot = true end
            if RANK[state] > RANK[worst] then worst = state end
            states[i] = state
            paint(square, COLOR[state])
            square:Show()
        else
            states[i] = false
            square:Hide()
        end
    end
    if not anyDot then worst = "none" end
    local isTarget = unit == "target" or plainBool(UnitIsUnit, unit, "target") == true
    if isTarget then c.edge:SetColorTexture(1, 1, 1, 1) else paint(c.edge, dead and COLOR.none or COLOR[worst]) end
    c.tag:SetText(dead and BIT.L("dead") or "")

    local snap = c.snap
    if not snap then snap = {}; c.snap = snap end
    snap.states, snap.dead, snap.goneAt = states, dead, nil
    snap.hadDots = snap.hadDots or anyDot
end

local function updateGhost(c, ghost, now, settings)
    local snap = c.snap
    -- The cell hid before (or without) a NAME_PLATE_UNIT_REMOVED we could use: the mob is gone as of now.
    if snap and snap.hadDots and not snap.goneAt then snap.goneAt = now end
    if c.index == 0 or not snap or not snap.hadDots or not snap.goneAt
        or now - snap.goneAt > settings.deadSeconds then
        ghost:Hide()
        if snap and snap.goneAt and now - snap.goneAt > settings.deadSeconds then c.snap = nil end
        return
    end
    pcall(ghost.name.SetText, ghost.name, c.snapName)
    ghost.hp:SetValue(0)
    ghost.tag:SetText(snap.dead and BIT.L("dead") or BIT.L("gone"))
    paint(ghost.edge, COLOR.none)
    for i, square in ipairs(ghost.sq) do
        local state = snap.states and snap.states[i]
        if state then
            local color = COLOR[state] or COLOR.none
            square:SetColorTexture(color[1] * 0.5, color[2] * 0.5, color[3] * 0.5, 1)
            square:Show()
        else
            square:Hide()
        end
    end
    ghost:Show()
end

function MobList.Update(now)
    local settings = ns.Settings()
    if not container or not settings or not ns.class or not container:IsVisible() then return end
    for index, cell in pairs(cells) do
        local ghost = ghosts[index]
        if cell:IsVisible() then
            ghost:Hide()
            updateCell(cell, now)
        else
            updateGhost(cell, ghost, now, settings)
        end
    end
end

---------------------------------------------------------------------------------------------
-- Nameplates coming and going decide when a cell's mob is a new one or a ghost
---------------------------------------------------------------------------------------------

local events = CreateFrame("Frame")
events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
events:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
events:SetScript("OnEvent", function(_, event, unit)
    if type(unit) ~= "string" or ns.isSecret(unit) then return end
    local index = tonumber(unit:match("^nameplate(%d+)$"))
    local cell = index and cells[index]
    if not cell then return end
    if event == "NAME_PLATE_UNIT_ADDED" then
        cell.snap = nil -- a new mob on this plate
    elseif cell.snap then
        cell.snap.goneAt = GetTime() -- the mob left or died: the ghost starts now
    end
end)
