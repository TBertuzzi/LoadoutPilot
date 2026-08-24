# Loadout Pilot

Loadout Pilot is a World of Warcraft Retail addon that automatically follows the content you are playing with your saved specialization, loot specialization, Blizzard talent loadouts, and equipment sets.

**Configure once. Let your loadout follow what you are doing.**

## Features

- Works with every Retail class and specialization.
- Detects **World**, **Delve**, **Dungeon**, **Mythic+**, **Raid**, and **PvP**.
- Maps an optional **specialization**, saved Blizzard talent loadout, and equipment set to each general content context.
- Automatically switches specialization when configured and when WoW allows the change.
- Automatically applies the mapped talent loadout after the target specialization is active.
- Automatically equips the mapped equipment set outside combat.
- Adds **one dungeon-specific override per dungeon**, shared across Normal, Heroic, Mythic 0, and Mythic+.
- Dungeon overrides can independently override specialization, **loot specialization**, talents, and equipment.
- Specialization, talents, and equipment left on **Inherit** fall back to the current Dungeon or Mythic+ default rule. Loot specialization can be left on **No override**.
- General **Dungeon** and **Mythic+** mappings remain separate as fallbacks, while the dungeon-specific rule itself is shared.
- Mythic+ identity is detected before the timer starts when a keystone is slotted, allowing the requested setup to be prepared before the run whenever WoW permits it.
- Seasonal Mythic+ dungeons are discovered automatically; other dungeons are remembered after you encounter them.
- Uses a safe order for advanced rules: **Specialization -> Loot Spec -> Talents -> Equipment**.
- Queues and retries changes temporarily blocked by combat or content transitions.
- Includes recovery logic for PvP -> World transitions for both talents and equipment.
- Compact adaptive HUD showing talent loadout, equipment set, and current readiness.
- Hover tooltip shows class, current/target specialization, loot specialization, detected context, dungeon rule, talents, gear, and status.
- Custom minimap button with saved rim position.
- Explicit **Apply mapped loadout now** fallback.
- Optional routine chat notifications.
- **Automatic (WoW)**, **Portuguese (Brazil)**, and **English** language selection.
- Marks automation as manual when Spec, Talents, or Gear AUTO is disabled.
- Restores both HUD and minimap-button positions from settings or slash command.

Loadout Pilot never creates, edits, or deletes your Blizzard talent loadouts or equipment sets.

## Example: dungeon-specific rules

You can keep separate Dungeon and Mythic+ defaults, then add one shared override only for the dungeons that need something different:

- **Dungeon default** -> Frost + Dungeon Build + PvE Default
- **Mythic+ default** -> Frost + M+ Default + PvE Default
- **Voidscar override** -> Unholy + Blood loot spec + Voidscar Build + inherit PvE Default

The **Voidscar override applies whether you enter it as Normal, Heroic, Mythic 0, or Mythic+**. If a field is not overridden, Loadout Pilot inherits the default for the context you are actually playing: Dungeon outside a keystone run, Mythic+ during a keystone run.

Each override field is optional. Changing only the specialization does not force you to create a separate equipment override. If you create your first dungeon specialization override without having chosen a default specialization, Loadout Pilot captures missing Dungeon/Mythic+ defaults where applicable so it has a stable spec to restore afterward. You can change those defaults at any time in the main window.

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
2. Select a dungeon from the list. Seasonal Mythic+ dungeons are discovered automatically, while other dungeons appear after you visit them.
3. Override any combination of:
   - Specialization used to play the dungeon
   - Loot specialization (including **Current specialization**)
   - Talent loadout
   - Equipment set
4. Leave specialization/talents/equipment on **Inherit** to use the default for the current context: Dungeon for Normal/Heroic/Mythic 0, or Mythic+ for a keystone run. Leave loot specialization on **No override** if Loadout Pilot should not touch it.

A dungeon appears only once in the override list. The same override is reused across all dungeon difficulties, so you do not need separate `[Dungeon]` and `[M+]` entries.

Loot specialization is independent from the role/spec used to play the dungeon. For example, you can remain Frost DPS while asking WoW to use Blood loot for that dungeon. When you leave the loot-spec override, Loadout Pilot restores the loot specialization that was active before the override session.

If an override changes playing specialization, Loadout Pilot waits for WoW to confirm the specialization before applying the matching talent loadout and equipment.

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

Loadout Pilot does not cast abilities and does not automate combat. Specialization, loot-specialization, talent, and equipment changes are requested only through Blizzard-supported player configuration APIs.

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
