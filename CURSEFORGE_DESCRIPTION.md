# Loadout Pilot

**Configure once. Let your loadout follow what you are doing.**

Loadout Pilot automatically associates the specialization, talent loadouts, and equipment sets you already use in World of Warcraft with the content you enter.

## Supported contexts

- World
- Delve
- Dungeon
- Mythic+
- Raid
- PvP (Battlegrounds and Arenas)

## Dungeon-specific rules

Version 1.1 adds optional per-dungeon overrides. Keep one normal Mythic+ default and only customize the dungeons that need something different.

Example:

- **Mythic+ default** -> Frost + M+ Default + PvE Default
- **Voidscar** -> Unholy + Voidscar Build + inherited PvE gear
- **Ruby Life Pools** -> Frost + RLP Build + inherited PvE gear
- **Other dungeons** -> fall back automatically to the default Mythic+ rule

Specialization, talent loadout, and equipment can each be overridden independently. Unconfigured fields inherit the normal Dungeon or Mythic+ mapping.

## Highlights

- Any Retail class and specialization
- Optional specialization mapping for every general content context
- Automatic **Specialization -> Talents -> Equipment** sequencing
- Per-dungeon overrides for Mythic+ and encountered normal dungeons
- Automatic talent-loadout switching when allowed by WoW
- Automatic equipment-set switching outside combat
- Combat-safe queue and transition retry logic
- Reliable PvP -> World recovery for talents and equipment
- Mythic+ detection before the timer starts when a keystone is slotted
- Compact adaptive HUD showing talents, equipment, and current status
- Hover details for current/target spec, context, active dungeon override, talents, gear, and status
- Custom minimap button
- Manual Apply fallback when the client temporarily blocks a change
- English and Brazilian Portuguese with an in-addon language selector
- Optional routine chat notifications
- Manual-state indication when automation is disabled
- One-click reset for HUD and minimap-button positions

Loadout Pilot does **not** cast abilities and does not automate combat. It respects Blizzard restrictions and only requests supported player configuration changes.

## Support development

If you enjoy Loadout Pilot and would like to support continued development:

[Buy Me a Coffee - bertuzzi](https://buymeacoffee.com/bertuzzi)

### Role-safe specialization switching

For Dungeon, Mythic+, Raid, and PvP content, Loadout Pilot compares the player's protected group role with the target specialization role. Same-role switches remain automatic, while incompatible Tank/Healer/DPS changes are blocked instead of silently changing the player's group role. World and Delve rules remain unrestricted.
