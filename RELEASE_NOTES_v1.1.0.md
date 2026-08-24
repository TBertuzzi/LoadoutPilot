# Loadout Pilot 1.1.0 - Dungeon Rules

Loadout Pilot 1.1.0 expands the original context-based automation with dungeon-specific rules and optional specialization switching.

## What's new

- Map an optional specialization to each general context: World, Delve, Dungeon, Mythic+, Raid, and PvP.
- Create overrides for individual Mythic+ dungeons and normal dungeons you have encountered.
- The first dungeon spec override can automatically capture your current spec as the context default when no default specialization has been configured yet.
- Override specialization, talent loadout, and equipment independently.
- Leave fields on **Inherit** to fall back to the normal Dungeon/Mythic+ setup.
- Specialization changes are applied first; Loadout Pilot waits for the new spec before applying its talent loadout and equipment.
- Specialization requests use the same combat-safe pending/retry philosophy as talents and gear.
- Mythic+ dungeon identity can be detected from the active or slotted keystone map.
- Added `/lpilot overrides` and `/lpilot spec on|off`.

## Example

- Mythic+ default -> Frost + M+ Default + PvE Default
- Voidscar -> Unholy + Voidscar Build + inherited PvE gear
- Ruby Life Pools -> Frost + RLP Build + inherited PvE gear
- Any other M+ -> Mythic+ default

## Compatibility and migration

Version 1.1.0 uses saved-variable schema 2. Existing 1.0 talent/equipment mappings are preserved; the new specialization and dungeon-override tables are added with safe defaults.

## Important note

WoW decides when specialization and talent changes are allowed. Loadout Pilot never bypasses those restrictions. It queues/retries supported operations and is designed to prepare Mythic+ dungeon rules before the timer starts when possible.

## Support development

https://buymeacoffee.com/bertuzzi
