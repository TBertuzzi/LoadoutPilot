# Validation Report — Loadout Pilot 1.1.1

Date: 2026-08-24

## Completed checks

- Confirmed Retail 12.1.0 / Interface 120100 metadata.
- Confirmed version 1.1.1 and schema 2.
- Confirmed v1.0/v1.1 mappings and dungeon overrides remain compatible.
- Confirmed assigned group-role detection through `UnitGroupRolesAssigned("player")`.
- Confirmed specialization role detection through `GetSpecializationRoleByID` with spec-list fallback.
- Confirmed same-role specialization changes remain automatic.
- Confirmed cross-role specialization changes are blocked in Dungeon, Mythic+, Raid, and PvP when they conflict with the protected role.
- Confirmed World and Delve cross-role changes remain unrestricted.
- Confirmed role labels are exposed in specialization pickers, main UI, and HUD tooltip.
- Confirmed `PLAYER_ROLES_ASSIGNED` triggers rule reevaluation.
- Confirmed existing specialization -> talents -> equipment sequencing remains intact.
- Confirmed existing PvP -> World restoration coverage remains present.

## Live-client note

The mocked Lua tests validate the rule logic, but live-client verification is still recommended because Blizzard can restrict specialization changes based on current game state.
