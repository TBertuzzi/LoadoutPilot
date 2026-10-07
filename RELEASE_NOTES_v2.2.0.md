# Loadout Pilot 2.2.0

Version 2.2.0 focuses on explaining and protecting your existing loadout rules.

## What changed

- **Effective rule:** the General page continues to show the configured Spec, Loot Spec, Talents, Gear and their source. The Explain / why button and `/lpilot why` also report automation modes, active waits, combat queues, group-role protection and recent failures.
- **Configuration Health:** missing talent loadouts and equipment sets now include the affected context or dungeon and where to repair it. The page has shortcuts to Contexts and Dungeon Overrides. Broken Raid Boss Loot Spec references are flagged.
- **Import preview:** paste the existing LP2 format, select Preview import, review added/changed/removed counts by rule type, then confirm. Editing the text or changing the existing configuration resets confirmation. Invalid or cross-class data is rejected before import.
- **Backup and restore:** importing saves a per-character snapshot of the prior configuration. Advanced offers Save backup and a two-click Restore backup; `/lpilot backup` and `/lpilot restore` are available. Export remains the portable backup between characters of the same class.
- **Event history:** backup, restore, import and resolved-rule changes appear alongside existing switch, wait and failure events. The rolling log remains available via `/lpilot log`.

## Compatibility and testing

- SavedVariables schema stays at 5; LP2 export format stays at version 1.
- Blizzard-native talent loadouts only. No Talent Loadout Manager integration.
- World, Delve, Dungeon, Mythic+, Raid and PvP application rules are preserved; Lair remains Raid.
- Approved for release after user testing in the live client on October 7, 2026. The runtime Lua is identical to the tested build.

Support development: https://buymeacoffee.com/bertuzzi
