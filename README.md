# Loadout Pilot

Loadout Pilot is a World of Warcraft Retail addon that automatically follows the content you are playing with your saved specialization, Blizzard talent loadouts, and equipment sets.

**Configure once. Let your loadout follow what you are doing.**

## Features

- Works with every Retail class and specialization.
- Detects **World**, **Delve**, **Dungeon**, **Mythic+**, **Raid**, and **PvP**.
- Maps an optional **specialization**, saved Blizzard talent loadout, and equipment set to each general content context.
- Automatically switches specialization when configured and when WoW allows the change.
- Automatically applies the mapped talent loadout after the target specialization is active.
- Automatically equips the mapped equipment set outside combat.
- Adds **dungeon-specific overrides** for individual Mythic+ and normal dungeons.
- Dungeon overrides can independently override specialization, talents, and equipment.
- Any field left on **Inherit** falls back to the normal Dungeon or Mythic+ rule.
- Mythic+ identity is detected before the timer starts when a keystone is slotted, allowing the requested setup to be prepared before the run whenever WoW permits it.
- Normal dungeons are remembered after you encounter them so they can be configured later.
- Uses a safe order for advanced rules: **Specialization -> Talents -> Equipment**.
- Queues and retries changes temporarily blocked by combat or content transitions.
- Includes recovery logic for PvP -> World transitions for both talents and equipment.
- Compact adaptive HUD showing talent loadout, equipment set, and current readiness.
- Hover tooltip shows class, current/target specialization, detected context, dungeon rule, talents, gear, and status.
- Custom minimap button with saved rim position.
- Explicit **Apply mapped loadout now** fallback.
- Optional routine chat notifications.
- **Automatic (WoW)**, **Portuguese (Brazil)**, and **English** language selection.
- Marks automation as manual when Spec, Talents, or Gear AUTO is disabled.
- Restores both HUD and minimap-button positions from settings or slash command.

Loadout Pilot never creates, edits, or deletes your Blizzard talent loadouts or equipment sets.

## Example: dungeon-specific rules

You can keep a simple default Mythic+ setup and only override the dungeons that need something different:

- **Mythic+ default** -> Frost + M+ Default + PvE Default
- **Voidscar** -> Unholy + Voidscar Build + inherit PvE Default
- **Ruby Life Pools** -> Frost + RLP Build + inherit PvE Default
- **Any other M+ dungeon** -> automatically falls back to the Mythic+ default

Each override field is optional. Changing only the specialization does not force you to create a separate equipment override; Loadout Pilot can inherit the base Dungeon/Mythic+ equipment mapping.
If you create your first dungeon specialization override without having chosen a default specialization for that context, Loadout Pilot saves your current specialization as the context default so it has a stable spec to restore afterward. You can change that default at any time in the main window.

## Role-safe specialization automation

When specialization automation is used in grouped content, Loadout Pilot checks the player's assigned group role against the target specialization role. Dungeon, Mythic+, Raid, and PvP rules will not automatically cross from DPS to Tank/Healer (or the reverse) when that would conflict with the protected role. Same-role switches such as Frost to Unholy continue normally. World and Delve rules remain unrestricted.

Spec selectors display role labels, and the HUD tooltip shows the current spec role, group role, and target role when applicable.

## Supported contexts

- World
- Delve
- Dungeon
- Mythic+
- Raid
- PvP (Battlegrounds and Arenas)

## Install

Extract the release ZIP into:

`World of Warcraft/_retail_/Interface/AddOns/`

The final folder must be:

`Interface/AddOns/LoadoutPilot/`

## Configure general rules

1. Open the addon with `/lpilot`.
2. Choose a content context.
3. Optionally choose the specialization that should be active for that context.
4. Choose one of your saved Blizzard talent loadouts for that specialization.
5. Choose one of your saved equipment sets.
6. Repeat for the contexts you care about.
7. Leave **Spec AUTO**, **Talents AUTO**, and **Gear AUTO** enabled for full automation.

Mappings are stored per character.

## Configure dungeon overrides

1. Open `/lpilot` and click **Dungeon overrides**, or use `/lpilot overrides`.
2. Select a Mythic+ dungeon from the discovered list, or select a normal dungeon you have previously visited.
3. Override any combination of:
   - Specialization
   - Talent loadout
   - Equipment set
4. Leave any field on **Inherit** to use the normal Dungeon/Mythic+ rule.

If an override changes specialization, Loadout Pilot waits for WoW to confirm the specialization before applying the matching talent loadout and equipment.

## Commands

- `/lpilot` - open/close settings
- `/lpilot apply` - apply the mapped rule for the detected context/dungeon
- `/lpilot status` - print current mapping status
- `/lpilot overrides` - open/close Dungeon Overrides
- `/lpilot spec on|off` - enable or disable automatic specialization switching
- `/lpilot chat on|off` - enable or disable routine automatic switch messages
- `/lpilot language auto|ptbr|en` - choose addon language (use `/reload` after changing)
- `/lpilot resetpos` - restore both HUD and minimap-button positions
- `/lpilot debug` - toggle debug messages

## Blizzard restrictions

Loadout Pilot does not cast abilities and does not automate combat. Specialization, talent, and equipment changes are requested only through Blizzard-supported player configuration APIs.

Some changes are restricted during combat or certain activity states. Loadout Pilot does not bypass those restrictions: it queues/retries supported changes and shows the pending state until the client allows the operation. In an active Mythic+ run, specialization/talent changes may be unavailable; the addon is designed to identify the dungeon and prepare the rule before the timer starts when possible.

## Compatibility

- World of Warcraft Retail
- Midnight 12.1.0
- TOC Interface 120100

## Support the project

If Loadout Pilot is useful to you and you would like to support continued development:

[Buy Me a Coffee - bertuzzi](https://buymeacoffee.com/bertuzzi)

Bug reports and reproducible issues are also very welcome. See [SUPPORT.md](SUPPORT.md).

## License

MIT

## Author

Developed and maintained by **Thiago Bertuzzi**.
