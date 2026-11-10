# PlateIntel

**Will your DoTs kill it?** PlateIntel marks the damage your damage-over-time spells still have to deal on the
target, focus and nameplate health bars, and shows a kill icon when that is enough to finish the mob. For WoW: Forever.

- **Kill prediction** from your own casts and the ticks you actually land, with a kill margin for heals and
  estimate error, an optional "one weapon hit" check (melee swing, wand or ranged shot), and shield/absorb awareness.
- **Works with your frames**: Blizzard, ElvUI (unit frames and nameplates), EllesmereUI, X-Perl, Plater,
  Platynator and others. Pick any other frame with `/upt pick`.
- **Extras, each switchable in `/upt`**: cast and channel damage and shields are on; stat comparisons, resource dots,
  hunter range, range checks and heal prediction are off by default.

## Install
Download the latest zip from [Releases](https://github.com/rogeriocamorim/PlateIntel/releases) and unpack the
`PlateIntel` folder into `World of Warcraft/_forever_/Interface/AddOns/`. Type `/upt` in game for the settings.

## Fork notice
PlateIntel is a fork of [UsefulPlatesAndTooltips](https://github.com/Ironship/UsefulPlatesAndTooltips) by Ironship,
which in turn builds on Does It Die by Joe Greive and other modules. See [CREDITS.md](CREDITS.md). Licensed
GPL-3.0-or-later like upstream (see `LICENSE` and the per-module license files).
What differs, and how upstream releases are brought in: [docs/UPSTREAM.md](docs/UPSTREAM.md).
History: [CHANGELOG.md](CHANGELOG.md).

## Development
Plain Lua, no build step: copy the folder into AddOns and `/reload`. Releases are built by a GitHub Action when a
`v*` tag is pushed, using `.pkgmeta`.
