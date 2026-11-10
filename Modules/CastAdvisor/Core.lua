-- PlateIntel module CastAdvisor: a small window that recommends the next spell, and a HealBot-style grid of the
-- mobs you have DoTs on. Written for PlateIntel. Copyright (c) 2026 Rogerio Camorim. GPL-3.0-or-later, see LICENSE.
--
-- Core.lua: settings, what the player knows and has (the snapshot), and the 0.2 s refresh that feeds the window
-- (Window.lua) and the mob list (MobList.lua). The priority itself is data per class (Warlock.lua).
--
-- WoW: Forever hides some values in combat (secret values): a mob's health and name, often the player's own mana.
-- Lua never compares those. Health and names are only handed to widgets (StatusBar, FontString) that accept them;
-- mana falls back to the last reading, and everything the rules compare is a plain number.
local ADDON_NAME, BIT = ...
local ns = BIT.Module("CastAdvisor")

ns.classes = {} -- class file name -> priority data (Warlock.lua)

local MANA = (Enum and Enum.PowerType and Enum.PowerType.Mana) or 0
local REFRESH = 0.2

local DEFAULTS = {
    showWindow = true,
    locked = false,
    x = -330, y = 40,            -- window centre, from the screen centre
    scale = 1,
    showList = true,
    listX = 330, listY = 40,     -- list centre
    columns = 2,
    cellWidth = 118, cellHeight = 24,
    poolSize = 10,               -- nameplate cells, plus one cell for the target
    deadSeconds = 30,            -- how long a dead or vanished mob stays on the list
    manaLow = 25,                -- % mana: Life Tap or wand
    wandMana = 45,               -- % mana: wand instead of Shadow Bolt as filler
    lifeTapHealth = 50,          -- % health: Life Tap only above this
    drainLifeHealth = 35,        -- % health: Drain Life below this
    drainSoul = false,           -- recommend Drain Soul when few Soul Shards are left
    shardMin = 3,
}

local settings
ns.snapshot = {}
local lastMana, lastHealth

local function isSecret(v)
    if type(issecretvalue) ~= "function" then return false end
    local ok, r = pcall(issecretvalue, v)
    return ok and r or false
end
ns.isSecret = isSecret

local function plainNumber(v)
    if type(v) == "number" and not isSecret(v) then return v end
end

local function call(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, a, b = pcall(fn, ...)
    if ok and not isSecret(a) then return a, b end
end

function ns.Settings() return settings end
function ns.Defaults() return DEFAULTS end

---------------------------------------------------------------------------------------------
-- Spells: the class file lists base spell ids; the name, icon and cast time come from the client, so the highest
-- known rank and Forever's own names (Bane of Agony) are used without a table of ranks.
---------------------------------------------------------------------------------------------

local spellCache = {}

local function spellInfo(idOrName)
    if C_Spell and C_Spell.GetSpellInfo then
        local info = call(C_Spell.GetSpellInfo, idOrName)
        if type(info) == "table" then return info.name, info.iconID, info.castTime, info.spellID end
    end
    if GetSpellInfo then
        local name, _, icon, castTime, _, _, id = call(GetSpellInfo, idOrName)
        if name then return name, icon, castTime, id end
    end
end

local function knownSpell(id, byName)
    if not id then return false end
    if byName then return true end -- looked up by name: the client only answers for spells the player has
    if IsPlayerSpell and call(IsPlayerSpell, id) then return true end
    if IsSpellKnown and call(IsSpellKnown, id) then return true end
    return false
end

-- The spell a class key stands for: { key, name, icon, cast (seconds), known }.
function ns.Spell(key)
    local cached = spellCache[key]
    if cached then return cached end
    local class = ns.class
    local ref = class and class.spells[key]
    if not ref then return { key = key, known = false, cast = 0 } end
    local byName = type(ref) == "string"
    local name, icon, castTime, id = spellInfo(ref)
    local info = { key = key, name = name, icon = icon, cast = (tonumber(castTime) or 0) / 1000,
        known = name ~= nil and knownSpell(byName and id or ref, byName), id = id or ref }
    -- Only cache an answer that found the spell: the spellbook may not be ready yet.
    if info.name then spellCache[key] = info end
    return info
end

function ns.ForgetSpells() spellCache = {} end

---------------------------------------------------------------------------------------------
-- The snapshot: plain values only.
---------------------------------------------------------------------------------------------

local function percentOf(current, maximum)
    current, maximum = plainNumber(current), plainNumber(maximum)
    if current and maximum and maximum > 0 then return current / maximum * 100 end
end

local function readMana()
    local pct = percentOf(call(UnitPower, "player", MANA), call(UnitPowerMax, "player", MANA))
    if pct then lastMana = pct end
    return lastMana -- the last reading while the client withholds it
end

local function readHealth()
    local pct = percentOf(call(UnitHealth, "player"), call(UnitHealthMax, "player"))
    if pct then lastHealth = pct end
    return lastHealth
end

local function hasAura(spellID, name)
    if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        local aura = call(C_UnitAuras.GetPlayerAuraBySpellID, spellID)
        if aura then return true end
    end
    if C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName then
        local aura = call(C_UnitAuras.GetAuraDataBySpellName, "player", name, "HELPFUL")
        if aura then return true end
    end
    return false
end

local function targetUsable()
    if call(UnitExists, "target") ~= true then return false end
    if call(UnitCanAttack, "player", "target") ~= true then return false end
    return call(UnitIsDeadOrGhost, "target") ~= true
end

local function dotApi() return _G.PlateIntel_DoTAPI end

-- Seconds left of each tracked DoT on `unit`, by class key. Missing: nil.
function ns.DotsLeft(unit, now)
    local class = ns.class
    local left = {}
    local api = dotApi()
    if not class or not api or not api.GetDoTs then return left end
    local ok, list = pcall(api.GetDoTs, unit)
    if not ok or type(list) ~= "table" then return left end
    local byName = {}
    for _, dot in ipairs(list) do
        if not dot.provisional and type(dot.expiresAt) == "number" then byName[dot.name] = dot.expiresAt - now end
    end
    for _, key in ipairs(class.dots) do
        local spell = ns.Spell(key)
        local remaining = spell.name and byName[spell.name]
        if remaining and remaining > 0 then left[key] = remaining end
    end
    return left
end

local function buildSnapshot(now)
    local class = ns.class
    local s = ns.snapshot
    s.now = now
    s.hasTarget = targetUsable()
    s.mana = readMana()
    s.health = readHealth()
    s.left = s.hasTarget and ns.DotsLeft("target", now) or {}
    s.proc = class and class.procAura and hasAura(class.procAura.id, class.procAura.name) or false
    s.shards = class and class.shardItem and (call(GetItemCount, class.shardItem) or 0) or 0
    s.hasWand = call(GetInventoryItemID, "player", 18) ~= nil
    s.casting = call(UnitCastingInfo, "player") ~= nil or call(UnitChannelInfo, "player") ~= nil
    s.inRange = nil
    local bolt = class and ns.Spell("shadowbolt")
    if bolt and bolt.name and s.hasTarget then
        local r = call(IsSpellInRange, bolt.name, "target")
        if r == 1 or r == true then s.inRange = true elseif r == 0 or r == false then s.inRange = false end
    end
    -- A spell is ready when it is not on cooldown (the global cooldown does not count). A withheld answer is "unknown".
    s.ready = {}
    if class then
        for _, key in ipairs(class.cooldownKeys or {}) do
            local spell = ns.Spell(key)
            if spell.known and C_Spell and C_Spell.GetSpellCooldown then
                local cd = call(C_Spell.GetSpellCooldown, spell.id)
                if type(cd) == "table" then
                    local duration = plainNumber(cd.duration)
                    if duration then s.ready[key] = duration <= 1.5 end
                end
            end
        end
    end
    return s
end

---------------------------------------------------------------------------------------------
-- The refresh loop
---------------------------------------------------------------------------------------------

local driver = CreateFrame("Frame")
local sinceUpdate = 0

local function refresh()
    local now = GetTime()
    local s = buildSnapshot(now)
    local picks, hint
    if ns.class and ns.class.recommend then picks, hint = ns.class.recommend(s, settings, ns.Spell) end
    if ns.Window and ns.Window.Update then ns.Window.Update(picks or {}, hint, s) end
    if ns.MobList and ns.MobList.Update then ns.MobList.Update(now) end
end
ns.Refresh = refresh

local function applyAll()
    if ns.Window and ns.Window.Apply then ns.Window.Apply() end
    if ns.MobList and ns.MobList.Apply then ns.MobList.Apply() end
end
ns.Apply = applyAll

---------------------------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------------------------

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON_NAME then return end
        self:UnregisterEvent("ADDON_LOADED")
        settings = BIT.Settings("CastAdvisor", DEFAULTS)
        if not BIT.ShouldRun("CastAdvisor") then return end
        self:RegisterEvent("PLAYER_LOGIN")
        self:RegisterEvent("SPELLS_CHANGED")
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
    elseif event == "PLAYER_LOGIN" then
        local _, classFile = UnitClass("player")
        ns.class = ns.classes[classFile]
        if not ns.class then return end -- no priority for this class yet: nothing to show
        applyAll()
        driver:SetScript("OnUpdate", function(_, elapsed)
            sinceUpdate = sinceUpdate + elapsed
            if sinceUpdate < REFRESH then return end
            sinceUpdate = 0
            local ok, err = pcall(refresh)
            if not ok and not ns.errorShown then
                ns.errorShown = true
                BIT.Say("CastAdvisor error: " .. tostring(err))
            end
        end)
    elseif event == "SPELLS_CHANGED" then
        ns.ForgetSpells()
        if ns.MobList and ns.MobList.Apply then ns.MobList.Apply() end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if ns.class then applyAll() end -- settings changed in combat are applied now
    end
end)

BIT.RegisterWaker("CastAdvisor", function() settings = BIT.Settings("CastAdvisor", DEFAULTS) end)

BIT.RegisterCommand("advisor", function(rest)
    if not settings then return end
    rest = (rest or ""):lower()
    if rest == "reset" then
        settings.x, settings.y, settings.listX, settings.listY = DEFAULTS.x, DEFAULTS.y, DEFAULTS.listX, DEFAULTS.listY
        applyAll()
    elseif rest == "lock" or rest == "unlock" then
        settings.locked = rest == "lock"
        applyAll()
    elseif rest == "list" then
        settings.showList = not settings.showList
        applyAll()
    elseif rest == "window" then
        settings.showWindow = not settings.showWindow
        applyAll()
    else
        BIT.OpenSettings("CastAdvisor")
    end
end)
BIT.tabWords.advisor = "CastAdvisor"
