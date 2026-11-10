-- PlateIntel module CastAdvisor: the warlock priority. Written for PlateIntel. Copyright (c) 2026 Rogerio Camorim.
-- GPL-3.0-or-later, see LICENSE.
--
-- Follows the Affliction leveling rotation of the Mobalytics WoW Forever warlock guide: keep Bane of Agony, Immolate,
-- Corruption and Siphon Life up; Shadow Trance (Nightfall) makes the next Shadow Bolt instant; Shadowburn on cooldown
-- (a Soul Shard); Life Tap when mana is low and health allows; Drain Life when health is low; Wrack (level 40) or the
-- wand or Shadow Bolt as filler; Drain Soul to restock shards.
--
-- A class file is data: spells (base spell id, or a name for spells without a known id), which spells are DoTs shown
-- in the list, the click bindings of the list, and recommend(snapshot, settings, spell) -> picks, hint.
-- Each pick is { key, reason }. Other classes add a file like this one.
local _, BIT = ...
local ns = BIT.Module("CastAdvisor")

local REFRESH_PAD = 1.5 -- seconds: recast a DoT when it runs out before the cast would finish plus this

local W = {
    class = "WARLOCK",
    spells = {
        agony = 980, immolate = 348, corruption = 172, siphon = 18265,
        shadowburn = 17877, shadowbolt = 686, drainlife = 689, drainsoul = 1120, lifetap = 1454,
        shoot = 5019, wrack = "Wrack",
    },
    dots = { "agony", "immolate", "corruption", "siphon" }, -- the squares of a list cell, in this order
    cooldownKeys = { "shadowburn" },
    procAura = { id = 17941, name = "Shadow Trance" },       -- Nightfall: the next Shadow Bolt is instant
    shardItem = 6265,
    -- The list cell's clicks. Left always targets the mob. button 2 = right, 3 = middle.
    clicks = {
        { button = 2, mod = "",      key = "corruption" },
        { button = 2, mod = "shift", key = "agony" },
        { button = 2, mod = "ctrl",  key = "immolate" },
        { button = 3, mod = "",      key = "siphon" },
    },
}

function W.recommend(s, cfg, spell)
    local picks = {}
    local function add(key, reason)
        local info = spell(key)
        if not info.known then return end
        for _, pick in ipairs(picks) do if pick.key == key then return end end
        picks[#picks + 1] = { key = key, reason = reason }
    end

    if not s.hasTarget then return picks, "Target an enemy" end
    if s.inRange == false then return picks, "Out of range" end

    if s.proc then add("shadowbolt", "Shadow Trance: instant") end

    for _, key in ipairs(W.dots) do
        local info = spell(key)
        if info.known then
            local left = s.left[key]
            if not left then
                add(key, "not on target")
            elseif left < info.cast + REFRESH_PAD then
                add(key, string.format("%.0fs left: refresh", left))
            end
        end
    end

    if s.ready.shadowburn and s.shards > 0 then add("shadowburn", "off cooldown") end

    local lowMana = s.mana and s.mana < cfg.manaLow
    if lowMana then
        if s.health and s.health > cfg.lifeTapHealth then
            add("lifetap", "mana low")
        elseif s.hasWand then
            add("shoot", "mana low: wand")
        end
    end
    if s.health and s.health < cfg.drainLifeHealth then add("drainlife", "health low") end
    if cfg.drainSoul and s.shards < cfg.shardMin then add("drainsoul", "few Soul Shards") end

    -- Filler: Wrack once it is learned, else the wand when mana is short, else Shadow Bolt.
    if spell("wrack").known then
        add("wrack", "filler")
    elseif s.hasWand and s.mana and s.mana < cfg.wandMana then
        add("shoot", "save mana: wand")
    else
        add("shadowbolt", "filler")
    end
    if s.hasWand then add("shoot", "wand") end
    return picks
end

ns.classes.WARLOCK = W
