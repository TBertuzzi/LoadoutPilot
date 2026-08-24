# Loadout Pilot 1.1.2

Version 1.1.2 focuses on community feedback around dungeon overrides.

## New

- Added per-dungeon **Loot Specialization** overrides, including Current specialization mode.
- Loot Spec is independent from the specialization/role used to play the dungeon.
- One dungeon-specific override now applies across **Normal, Heroic, Mythic 0, and Mythic+**.
- General Dungeon and Mythic+ mappings remain separate and are used as context-aware fallbacks for fields left on Inherit.
- Seasonal Mythic+ catalog entries now resolve to the same stable dungeon InstanceID used by regular dungeon runs, preventing duplicate entries for the same dungeon.
- Existing pre-final-1.1.2 `mplus:<challengeID>` overrides are migrated automatically to the unified dungeon identity.

## Fixed

- Fixed Dungeon Overrides dropdowns appearing behind the override panel.
- Fixed the confusing behavior where entering a seasonal dungeon as Mythic 0 could ignore an override that had been configured from the Mythic+ catalog entry.

## Preserved

- Role-safe playing-spec switching.
- Specialization -> Loot Spec -> Talents -> Equipment sequencing.
- Combat-safe queue/retry behavior.
- PvP -> World recovery.
- Dynamic Mythic+ seasonal dungeon discovery.

## Support

https://buymeacoffee.com/bertuzzi
