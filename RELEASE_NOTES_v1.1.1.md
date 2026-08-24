# Loadout Pilot 1.1.1

## Role-safe specialization switching

This update adds role awareness to the specialization automation introduced in 1.1.0.

- Loadout Pilot now reads the player's assigned group role: Tank, Healer, or DPS.
- Specialization selectors show each spec's intended role.
- The main window and HUD tooltip expose current/group/target role information.
- In Dungeon, Mythic+, Raid, and PvP contexts, automatic specialization changes are blocked when the target specialization conflicts with the protected group role.
- If WoW does not expose an assigned group role, cross-role switches are conservatively blocked using the current specialization role as the fallback.
- Same-role switches remain automatic.
- World and Delve contexts remain unrestricted.
- Role changes are reevaluated automatically through PLAYER_ROLES_ASSIGNED.

Example: a player assigned as DPS can automatically switch Frost -> Unholy, but Loadout Pilot will not automatically switch that player Frost -> Blood while the DPS role is protected.

## Support

https://buymeacoffee.com/bertuzzi
