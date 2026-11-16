# Upstream

PlateIntel is a fork of [Ironship/UsefulPlatesAndTooltips](https://github.com/Ironship/UsefulPlatesAndTooltips)
(GPL-3.0-or-later). The addon is renamed, so Git cannot merge upstream directly; `tools/sync_upstream.py` renames
upstream's files the same way and does a 3-way merge per file.

Last synced upstream commit: `7a3a3e70e0382d2ba870ff00d5461921c25a4ddf` (upstream Forever 0.9.131)

## Syncing a new upstream release

```bash
python tools/sync_upstream.py https://github.com/Ironship/UsefulPlatesAndTooltips          # report only
python tools/sync_upstream.py https://github.com/Ironship/UsefulPlatesAndTooltips --apply  # write the result
```

Then resolve any `<<<<<<<` conflicts, set the commit above to the new upstream commit, add a CHANGELOG entry,
make sure `PlateIntel.toc` lists every new file, and test with `/reload` in game.

## Where PlateIntel differs from upstream (keeps merges small)

Merged into upstream (pull requests 59 to 62, so the files are upstream's now): the ElvUI integration, `KillCheck.lua`
(kill margin, absorb flag, weapon hit), `ManaCost.lua`, the `Plate.Register*Source` hooks and the DoTInfo/CastPrediction
options. Keep them identical to upstream; send changes there.

Only in PlateIntel:
- `Modules/CastAdvisor/`: the HealBot-style mob list (Core, Warlock, MobList, Options).
- `Core/Init.lua`: `DEFAULT_OFF` (modules that start switched off on a new profile).
- `Modules/DoTInfo/Core.lua`: a cheaper trace log, nameplate lookup and `dotBreakdown` early return.
- `Core/Settings.lua`: the `CastAdvisor` tab label and the window title.
- `PlateIntel.toc`: metadata, `Media/Icon.tga` and the CastAdvisor files.

Saved-variable names still start with `UsefulPlatesAndTooltips` so settings carry over from upstream installs.
