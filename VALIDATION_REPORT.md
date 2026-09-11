# Validation Report - Loadout Pilot 2.1.0

Date: 2026-09-11
Target: World of Warcraft Retail / Midnight 12.1.0
Interface: 120100
Version: 2.1.0
SavedVariables schema: 5

## Release validation

- Static source validation: PASS
- Lua syntax validation for Localization.lua, Data.lua, Core.lua, and tests/smoke.lua: PASS
- Full smoke/regression suite: PASS
- 2.1 UI/navigation marker validation: PASS
- Configuration Health regression coverage: PASS
- World / Delve / Dungeon / Mythic+ / Raid / PvP context regression coverage: PASS
- Lair -> Raid context regression: PASS
- Completed-Delve reward-phase retention: PASS
- Unified Dungeon/M0/Mythic+ override regression: PASS
- Raid Boss Loot Spec rule regression: PASS
- AUTO / NOTIFY / OFF regression: PASS
- Role-safety regression: PASS
- Import/export regression: PASS
- Combat-safe queue/retry regression: PASS
- Loot Spec restoration regression: PASS
- PvP -> World recovery regression: PASS

## 2.1 scope

- Refreshed main navigation with native WoW icons.
- Added context icons for World, Delve, Dungeon, Mythic+, Raid, and PvP.
- Added icons to the main Dungeon and Raid Boss actions.
- Added Configuration Health for missing saved Blizzard talent loadouts and equipment sets.
- SavedVariables schema remains 5; no migration is required.
- Blizzard-native saved talent loadouts remain the talent source.

## Live-client status

The 2.1.0 Test r1 UI was reviewed in the live client and approved for packaging. The stable 2.0.x context fixes carried into this release were previously live-tested, including Lair -> Raid -> World and completed Delve reward-phase behavior.

## Package expectations

- CurseForge/Release ZIP contains exactly one top-level `LoadoutPilot/` folder.
- GitHub source ZIP contains one top-level `LoadoutPilot-v2.1.0/` folder.
- Release metadata reports version 2.1.0 and Interface 120100.
