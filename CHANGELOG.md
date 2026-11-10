# Changelog

## 1.0.0
First PlateIntel release. Based on UsefulPlatesAndTooltips 0.9.120 (Forever).

- Renamed to PlateIntel (folder, `.toc`, code names). Saved-variable names are unchanged, so settings carry over.
- ElvUI: target, focus and player frames and ElvUI nameplates get the marker and kill icon automatically.
- Kill icon: new "Kill margin" setting (default 90%); casts still in progress no longer light it; an absorbed tick
  hides it for a few seconds; Blessing of Protection only hides it for physical DoTs.
- New option "Count one weapon hit": the kill icon also counts one average swing, wand or ranged shot.
- DoTs that tick and then stop (dispelled, pushed off by the debuff cap) are dropped after three missed ticks.
- Cheaper trace log and mob lookup when GUIDs are secret; fewer allocations on empty nameplates.
- Kill-prediction focus: StatsInfo, ResourceDing, HunterRangeFinder, Range and HealPrediction start switched off on
  a new profile (switch them on in /upt). A choice you already made is kept.
- Mana cost preview: while you cast a spell with a cast time, a segment on your own mana bar (ElvUI, EllesmereUI or
  Blizzard) shows how much mana it will take. Option "Show mana cost on your mana bar" in the CastPrediction tab.
- Cast advisor (warlock): a window with the next spells to cast (DoTs to apply or refresh, Shadow Trance proc,
  Shadowburn, Life Tap / wand when mana is low, Drain Life when health is low, Wrack or Shadow Bolt as filler) and a
  gauge of how much target health your DoTs will take; and a HealBot-style mob list, one cell per mob with health,
  name and a square per DoT. Click a cell to target it, or cast Corruption / Bane of Agony / Immolate / Siphon Life on
  it without changing target. `/upt advisor`.
- Upstream 0.9.120 changes included: Debug tab in settings, drink mana on action buttons, percentage food and drink
  amounts in item tooltips.
