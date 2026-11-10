-- PlateIntel module CastAdvisor: the settings tab. Written for PlateIntel. Copyright (c) 2026 Rogerio Camorim.
-- GPL-3.0-or-later, see LICENSE.
local _, BIT = ...
local ns = BIT.Module("CastAdvisor")

local function settings() return ns.Settings() end

local function build(parent)
    local UI = BIT.UI
    local y = 8
    local function place(frame, height, x)
        frame:SetPoint("TOPLEFT", x or 8, -y)
        y = y + height
        return frame
    end
    local function check(label, key, tooltip)
        place(UI.Check(parent, label, function() return settings()[key] end, function(value)
            settings()[key] = value and true or false
            ns.Apply()
        end, tooltip), 28)
    end
    local function slider(label, key, min, max, step, tooltip, format)
        place(UI.Slider(parent, label, min, max, step, function() return settings()[key] end, function(value)
            settings()[key] = value
            ns.Apply()
        end, format, tooltip), 46)
    end

    place(UI.Header(parent, "WINDOW"), 24)
    check("Show the recommendation window", "showWindow",
        "Shows the next spells to cast for your DoTs, mana and health, and a gauge of how much of the target's health "
        .. "your DoTs will still take.")
    check("Lock window and list", "locked", "Stops the window and the mob list from being dragged. /upt advisor lock|unlock")
    slider("Window and list scale", "scale", 0.6, 1.6, 0.1, nil, function(v) return string.format("%.1f", v) end)

    place(UI.Header(parent, "MOB LIST"), 24)
    check("Show the mob list", "showList",
        "A grid with one cell per mob: health, name, a square per DoT (green up, yellow due, red missing). Left-click "
        .. "targets the mob; right-click casts Corruption on it, Shift-right Bane of Agony, Ctrl-right Immolate, "
        .. "middle Siphon Life, without changing your target. Needs enemy nameplates on. Cells are fixed in combat.")
    slider("Columns", "columns", 1, 4, 1)
    slider("Cell width", "cellWidth", 80, 200, 2)
    slider("Cell height", "cellHeight", 18, 40, 1)
    slider("Nameplate cells", "poolSize", 4, 16, 1,
        "How many nameplate slots get a cell, besides the cell for your target. More cells can only be added out of "
        .. "combat.")
    slider("Keep dead mobs for (seconds)", "deadSeconds", 0, 120, 5,
        "A mob that died or left keeps its greyed cell with its last DoT squares for this long.")

    place(UI.Header(parent, "RECOMMENDATION"), 24)
    slider("Mana low (%)", "manaLow", 5, 60, 5, "Below this Life Tap, or the wand, is recommended.")
    slider("Use the wand below (% mana)", "wandMana", 10, 80, 5,
        "When filler is needed and mana is below this, the wand is recommended instead of Shadow Bolt.")
    slider("Life Tap above (% health)", "lifeTapHealth", 20, 90, 5)
    slider("Drain Life below (% health)", "drainLifeHealth", 10, 70, 5)
    check("Recommend Drain Soul for shards", "drainSoul", "Adds Drain Soul when you carry fewer Soul Shards than the minimum.")
    slider("Minimum Soul Shards", "shardMin", 1, 20, 1)

    place(UI.Note(parent, "Warlock only for now. In dungeons the game may hide nameplate units, then the list shows "
        .. "your target only.", 380), 40)
    parent:SetHeight(y + 20)
end

BIT.RegisterTab("CastAdvisor", {
    title = "Cast advisor",
    summary = "Recommends the next spell for a warlock and lists the mobs you have DoTs on, with click-to-cast.",
    plain = true,
    height = 760,
    build = build,
})
