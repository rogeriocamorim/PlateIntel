# PlateIntel

Nameplate and tooltip info for WoW: Forever: DoT kill marks, cast and channel damage, incoming heals, shields, hunter range, combo points, stat comparisons and action bar numbers. Every part can be switched off. Settings: `/upt`.

Fork of [Ironship/UsefulPlatesAndTooltips](https://github.com/Ironship/UsefulPlatesAndTooltips) (GPL-3.0-or-later), itself built on Does It Die by Joe Greive (MIT, see `Modules/DoTInfo/LICENSE-DoesItDie.txt`).

## Changes in this fork
- Renamed to PlateIntel. Saved-variable names are unchanged, so existing settings keep working.
- ElvUI support: target, focus and player frames and ElvUI nameplates are found automatically.
- DoT kill icon: kill margin setting, casts in progress no longer light the icon, DoTs that stop ticking are dropped, absorbed ticks hide the icon, Blessing of Protection only hides it for physical DoTs.
- Optional "count one weapon hit" for the kill icon (melee swing, wand or ranged shot).

## Install
Copy this folder into `World of Warcraft/_forever_/Interface/AddOns/PlateIntel`.
