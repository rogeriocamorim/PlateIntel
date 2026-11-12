# Upstream

PlateIntel is a fork of [Ironship/UsefulPlatesAndTooltips](https://github.com/Ironship/UsefulPlatesAndTooltips)
(GPL-3.0-or-later). The addon is renamed, so Git cannot merge upstream directly; `tools/sync_upstream.py` renames
upstream's files the same way and does a 3-way merge per file.

Last synced upstream commit: `65f40b84b9178ce64f25a7e2c0037525fa2ef9a1` (upstream Forever 0.9.124)

## Syncing a new upstream release

```bash
python tools/sync_upstream.py https://github.com/Ironship/UsefulPlatesAndTooltips          # report only
python tools/sync_upstream.py https://github.com/Ironship/UsefulPlatesAndTooltips --apply  # write the result
```

Then resolve any `<<<<<<<` conflicts, set the commit above to the new upstream commit, add a CHANGELOG entry,
make sure `PlateIntel.toc` lists every new file, and test with `/reload` in game.

## Where PlateIntel differs from upstream (keeps merges small)

New files, never touched by upstream:
- `Core/Integrations/ElvUI.lua`: ElvUI unit frames and nameplates.
- `Modules/DoTInfo/KillCheck.lua`: kill margin, weapon-hit check, absorb flag for the kill icon.
- `Modules/CastPrediction/ManaCost.lua`: mana cost of the cast in progress, on the player's mana bar.
- `Modules/CastAdvisor/`: next-spell window and the HealBot-style mob list (Core, Warlock, Window, MobList, Options).

Small hooks in upstream files:
- `Core/PlateLayout.lua`: `Plate.RegisterUnitFrameSource`, `Plate.RegisterPlateBarSource`, `Plate.Read`,
  `Plate.VisibleHealthBar`.
- `Core/Init.lua`: `DEFAULT_OFF` (modules that start switched off on a new profile).
- `Modules/DoTInfo/Core.lua`: `killMargin` / `swingKill` defaults, the absorb stamp in `onUnitCombat`, Blessing of
  Protection only for physical DoTs in `ns.shielded`, dropping DoTs that stop ticking in `housekeep`, a cheaper
  trace log and nameplate lookup.
- `Modules/DoTInfo/Options.lua`, `Nameplates.lua`: the options and the kill-check call.
- `Modules/CastPrediction/Options.lua`: the `showManaCost` checkbox.
- `Modules/SpellDamageInfo/Core.lua`: `ns.SwingAverage`.
- `Core/Settings.lua`: the `CastAdvisor` tab label and the window title.
- `PlateIntel.toc`: metadata and the new files.

Saved-variable names still start with `UsefulPlatesAndTooltips` so settings carry over from upstream installs.
