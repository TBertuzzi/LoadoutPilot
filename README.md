# Loadout Pilot

Loadout Pilot is a lightweight World of Warcraft Retail addon that automatically maps your existing Blizzard talent loadouts and equipment sets to the content you are currently playing.

**Configure once. Let your loadout follow what you are doing.**

## Features

- Works with every Retail class and specialization.
- Uses the talent loadouts you already saved in Blizzard's UI.
- Uses the equipment sets you already saved in Blizzard Equipment Manager.
- Stores independent mappings per character, specialization, and content context.
- Detects **World**, **Delve**, **Dungeon**, **Mythic+**, **Raid**, and **PvP**.
- Detects Mythic+ separately from ordinary dungeons, including a slotted keystone before the timer starts.
- Automatically requests the mapped talent loadout when WoW permits talent changes.
- Automatically equips the mapped equipment set outside combat.
- Queues and retries changes that are temporarily blocked during combat or content transitions.
- Includes recovery logic for PvP -> World transitions for both talents and equipment.
- Compact adaptive HUD showing talent loadout, equipment set, and current readiness.
- Hover tooltip shows class, specialization, detected context, talents, gear, and status.
- Custom minimap button with saved rim position.
- Explicit **Apply mapped loadout now** fallback.
- Optional routine chat notifications.
- **Automatic (WoW)**, **Portuguese (Brazil)**, and **English** language selection.
- Marks talents or gear as **MANUAL** when their automation is disabled.
- Restores both HUD and minimap-button positions from settings or slash command.

Loadout Pilot never creates, edits, or deletes your Blizzard talent loadouts or equipment sets.

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

## Configure

1. Open the addon with `/lpilot`.
2. Choose a content context.
3. Choose one of your already saved Blizzard talent loadouts.
4. Choose one of your already saved equipment sets.
5. Repeat for the contexts and specializations you care about.
6. Leave **Talents AUTO** and **Gear AUTO** enabled.

Mappings are stored per character and specialization.

## Commands

- `/lpilot` - open/close settings
- `/lpilot apply` - apply the mapped loadout for the detected context
- `/lpilot status` - print current mapping status
- `/lpilot chat on|off` - enable or disable routine automatic switch messages
- `/lpilot language auto|ptbr|en` - choose addon language (use `/reload` after changing)
- `/lpilot resetpos` - restore both HUD and minimap-button positions
- `/lpilot debug` - toggle debug messages

## Blizzard restrictions

Loadout Pilot does not cast abilities and does not automate combat. Talent and equipment changes are attempted only through Blizzard-supported player configuration APIs. Equipment changes cannot be performed during combat. Talent changes may also be temporarily denied by the client depending on the current activity or transition state; Loadout Pilot queues/retries supported changes and keeps the current status visible.

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
