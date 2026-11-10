-- luacheck config for a WoW addon; run `luacheck .` if you have it installed.
std = "lua51"
max_line_length = false
unused_args = false
ignore = { "211", "212", "213", "311", "431", "432" }
globals = {
  "UsefulPlatesAndTooltipsDB", "UsefulPlatesAndTooltips_SpellDamageInfoDB",
  "UsefulPlatesAndTooltips_DoTInfoDB", "UsefulPlatesAndTooltips_ResourceDingDB", "SlashCmdList",
}
read_globals = { "C_NamePlate", "C_Spell", "C_UnitAuras", "C_SpellBook", "C_CVar", "CreateFrame", "GetTime",
  "UnitHealth", "UnitHealthMax", "UnitExists", "UnitGUID", "UnitIsUnit", "UnitAttackSpeed", "UnitDamage",
  "UnitRangedDamage", "UnitAttackPower", "ElvUI", "issecretvalue" }
