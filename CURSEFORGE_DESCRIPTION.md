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

Version 1.1 adds optional per-dungeon overrides. Starting with 1.1.2, each dungeon has **one shared override** that applies in Normal, Heroic, Mythic 0, and Mythic+.

Example:

- **Dungeon default** -> Frost + Dungeon Build + PvE Default
- **Mythic+ default** -> Frost + M+ Default + PvE Default
- **Voidscar override** -> Unholy + Voidscar Build + inherited PvE gear

The Voidscar override is reused at every dungeon difficulty. Fields left on **Inherit** use the correct default for the current activity: Dungeon outside a keystone run, Mythic+ during a keystone run.

Specialization, loot specialization, talent loadout, and equipment can each be overridden independently.

## Highlights

- Any Retail class and specialization
- Optional specialization mapping for every general content context
- Automatic **Specialization -> Loot Spec -> Talents -> Equipment** sequencing
- One shared per-dungeon override across Normal, Heroic, Mythic 0, and Mythic+, including independent loot-spec selection
- Automatic talent-loadout switching when allowed by WoW
- Automatic equipment-set switching outside combat
- Combat-safe queue and transition retry logic
- Reliable PvP -> World recovery for talents and equipment
- Mythic+ detection before the timer starts when a keystone is slotted
- Compact adaptive HUD showing talents, equipment, and current status
- Hover details for current/target spec, loot spec, context, active dungeon override, talents, gear, and status
- Custom minimap button
- Manual Apply fallback when the client temporarily blocks a change
- English and Brazilian Portuguese with an in-addon language selector
- Optional routine chat notifications
- Manual-state indication when automation is disabled
- One-click reset for HUD and minimap-button positions

Loadout Pilot does **not** cast abilities and does not automate combat. It respects Blizzard restrictions and only requests supported player configuration changes.

### Per-dungeon loot specialization

A dungeon override can select a loot specialization independently from the specialization used to play. For example, stay Frost DPS while using Blood loot for one dungeon. Choosing **Current specialization** uses WoW's current-spec loot mode, and leaving the field on **No override** leaves the player's loot setting untouched. When a temporary dungeon loot override ends, Loadout Pilot restores the loot specialization that was active before it.

### Role-safe specialization switching

For Dungeon, Mythic+, Raid, and PvP content, Loadout Pilot compares the player's protected group role with the target specialization role. Same-role switches remain automatic, while incompatible Tank/Healer/DPS changes are blocked instead of silently changing the player's group role. World and Delve rules remain unrestricted.

## Support development

If you enjoy Loadout Pilot and would like to support continued development:

[Buy Me a Coffee - bertuzzi](https://buymeacoffee.com/bertuzzi)
