# Loadout Pilot

Loadout Pilot is a World of Warcraft Retail addon that automatically switches your specialization, loot specialization, saved Blizzard talent loadouts, and equipment sets based on the content you are playing.

**Configure once. Let your loadout follow what you are doing.**

World, Delves, Dungeons, Mythic+, Raids and PvP — with per-dungeon overrides for spec, loot spec, talents and gear.

## Download

The recommended way to install Loadout Pilot is through CurseForge:

[**Download Loadout Pilot on CurseForge**](https://www.curseforge.com/wow/addons/loadout-pilot)

You can also:

- [Download releases from GitHub](../../releases)
- [Report bugs or request features](../../issues)

## Features

- Works with every Retail class and specialization.
- Detects **World**, **Delve**, **Dungeon**, **Mythic+**, **Raid**, and **PvP**.
- Maps an optional **specialization**, saved Blizzard talent loadout, and equipment set to each general content context.
- Automatically switches specialization when configured and when WoW allows the change.
- Automatically applies the mapped talent loadout after the target specialization is active.
- Automatically equips the mapped equipment set outside combat.
- Adds **one dungeon-specific override per dungeon**, shared across Normal, Heroic, Mythic 0, and Mythic+.
- Dungeon overrides can independently override:
  - Specialization
  - Loot specialization
  - Talent loadout
  - Equipment set
- Specialization, talents, and equipment left on **Inherit** fall back to the current Dungeon or Mythic+ default rule.
- Loot specialization can be left on **No override** when Loadout Pilot should not modify it.
- General **Dungeon** and **Mythic+** mappings remain separate as fallback rules, while the dungeon-specific override itself is shared across difficulties.
- Mythic+ identity is detected before the timer starts when a keystone is slotted, allowing the requested setup to be prepared before the run whenever WoW permits it.
- Seasonal Mythic+ dungeons are discovered automatically.
- Other dungeons are remembered after you encounter them.
- Uses a safe order for advanced rules: **Specialization -> Loot Spec -> Talents -> Equipment**.
- Queues and retries supported changes temporarily blocked by combat or content transitions.
- Includes recovery logic for PvP -> World transitions for both talents and equipment.
- Compact adaptive HUD showing talent loadout, equipment set, and current readiness.
- Hover tooltip shows class, current/target specialization, loot specialization, detected context, dungeon rule, talents, gear, role information, and status.
- Custom minimap button with saved rim position.
- Explicit **Apply mapped loadout now** fallback.
- Optional routine chat notifications.
- **Automatic (WoW)**, **Portuguese (Brazil)**, and **English** language selection.
- Marks automation as manual when Spec, Talents, or Gear AUTO is disabled.
- Restores both HUD and minimap-button positions from settings or slash command.

Loadout Pilot never creates, edits, or deletes your Blizzard talent loadouts or equipment sets.

## Example: dungeon-specific rules

You can keep separate Dungeon and Mythic+ defaults, then add one shared override only for the dungeons that need something different.

Example:

- **Dungeon default** -> Frost + Dungeon Build + PvE Default
- **Mythic+ default** -> Frost + M+ Default + PvE Default
- **Altar of Fangs override** -> Unholy + Blood loot spec + Altar Build + inherit PvE Default

The **Altar of Fangs override applies whether you enter it as Normal, Heroic, Mythic 0, or Mythic+**.

If a field is not overridden, Loadout Pilot inherits the appropriate default for the context you are actually playing:

- Regular dungeon content -> **Dungeon default**
- Keystone slotted or active Mythic+ run -> **Mythic+ default**

This means a dungeon-specific override does not need to duplicate your entire setup.

For example, you can override only the specialization and talent loadout for one dungeon while continuing to inherit your normal equipment set.

Each override field is optional.

If you create your first dungeon specialization override without having chosen a default specialization, Loadout Pilot captures missing Dungeon/Mythic+ defaults where applicable so it has a stable specialization to restore afterward.

You can change those defaults at any time in the main window.

## Loot specialization overrides

Dungeon-specific rules can also change your **Loot Specialization** independently from the specialization you are actually playing.

For example:

- Playing specialization -> Frost
- Loot specialization -> Blood

You remain Frost DPS, but WoW uses the Blood loot table for that dungeon.

Loot specialization does not participate in role-protection checks because changing loot specialization does not change the role or specialization you are playing.

Available choices include:

- **No override** — Loadout Pilot does not modify loot specialization.
- **Current specialization** — use the specialization currently being played.
- Any available specialization for your class.

When you leave a dungeon loot-spec override, Loadout Pilot restores the loot specialization that was active before the override session.

## Unified dungeon overrides

A dungeon appears only once in the Dungeon Overrides window.

You do not need separate entries such as:

- `[Dungeon] Altar of Fangs`
- `[M+] Altar of Fangs`

Instead, there is one:

- **Altar of Fangs**

That override is reused across:

- Normal
- Heroic
- Mythic 0
- Mythic+

The general **Dungeon** and **Mythic+** rules remain separate and are used only as fallback configurations when the dungeon-specific override leaves a field on **Inherit** or when no specific override exists.

This allows you to maintain different general setups for casual dungeon content and Mythic+ without having to configure the same individual dungeon twice.

## Role-safe specialization automation

When specialization automation is used in grouped content, Loadout Pilot checks the player's assigned group role against the role of the requested specialization.

Role protection applies to:

- Dungeon
- Mythic+
- Raid
- PvP

For example:

- Frost DPS -> Unholy DPS: allowed
- Frost DPS -> Blood Tank while assigned as DPS: blocked
- Blood Tank -> Frost DPS while assigned as Tank: blocked

This prevents Loadout Pilot from automatically changing you into a specialization that conflicts with the role assigned to you by the group.

Same-role specialization changes continue normally.

World and Delve rules remain unrestricted.

Specialization selectors display role labels, and the HUD tooltip shows the current specialization role, assigned group role, and target specialization role when applicable.

## Supported contexts

- World
- Delve
- Dungeon
- Mythic+
- Raid
- PvP
  - Battlegrounds
  - Arenas

## Install

Extract the release ZIP into:

`World of Warcraft/_retail_/Interface/AddOns/`

The final folder must be:

`Interface/AddOns/LoadoutPilot/`

You should end up with something similar to:

```text
World of Warcraft
└── _retail_
    └── Interface
        └── AddOns
            └── LoadoutPilot
                ├── LoadoutPilot.toc
                ├── Core.lua
                └── ...
```

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

1. Open `/lpilot`.
2. Click **Dungeon overrides** or use `/lpilot overrides`.
3. Select a dungeon from the list.
4. Override any combination of:
   - Specialization used to play the dungeon
   - Loot specialization
   - Talent loadout
   - Equipment set
5. Leave specialization, talents, or equipment on **Inherit** when you want to use the current Dungeon/Mythic+ default.
6. Leave loot specialization on **No override** when Loadout Pilot should not modify it.

Seasonal Mythic+ dungeons are discovered automatically.

Other dungeons become available after Loadout Pilot encounters them.

The same dungeon-specific override is reused across Normal, Heroic, Mythic 0, and Mythic+.

If an override changes the playing specialization, Loadout Pilot waits for WoW to confirm the specialization change before applying the matching talent loadout and equipment set.

## Rule priority

When you enter a dungeon, Loadout Pilot resolves the configuration using this priority:

```text
Dungeon-specific override
        ↓
Dungeon or Mythic+ default
        ↓
Current player configuration
```

Individual override fields are resolved independently.

For example:

```text
Altar of Fangs

Spec:       Unholy
Loot Spec:  Blood
Talents:    Altar Build
Gear:       Inherit
```

If you enter as Mythic 0:

```text
Spec       -> Unholy
Loot Spec  -> Blood
Talents    -> Altar Build
Gear       -> Dungeon default gear
```

If you enter the same dungeon with a keystone:

```text
Spec       -> Unholy
Loot Spec  -> Blood
Talents    -> Altar Build
Gear       -> Mythic+ default gear
```

The dungeon-specific choices stay the same while inherited fields automatically follow the appropriate general context.

## Mythic+ detection

Loadout Pilot distinguishes regular dungeon content from Mythic+.

Selecting **Mythic** difficulty alone is considered a regular Mythic 0 dungeon.

Mythic+ context is detected when:

- A Mythic Keystone is slotted, or
- The Mythic+ challenge is active.

This allows Loadout Pilot to prepare the requested Mythic+ configuration before the timer starts whenever WoW permits the change.

Once a dungeon-specific override exists, however, that override applies to the dungeon regardless of whether it is entered as Normal, Heroic, Mythic 0, or Mythic+.

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

Loadout Pilot does not cast abilities and does not automate combat.

Specialization, loot-specialization, talent, and equipment changes are requested only through Blizzard-supported player configuration APIs.

Some changes are restricted during combat or certain activity states.

Loadout Pilot does not bypass those restrictions.

Instead, it queues or retries supported changes and shows the pending state until the client allows the operation.

In an active Mythic+ run, specialization or talent changes may no longer be available.

Loadout Pilot is therefore designed to identify the dungeon and prepare the requested rule before the timer starts whenever possible.

## HUD

The compact HUD provides quick feedback about what Loadout Pilot is currently managing.

It can display information such as:

```text
Talents: M+ Default    Gear: PvE Default    Ready
```

Hovering the HUD provides additional details including:

- Current context
- Current dungeon
- Current specialization
- Target specialization
- Specialization role
- Assigned group role
- Loot specialization
- Talent loadout
- Equipment set
- Dungeon override status
- Pending or blocked changes

The HUD automatically adapts its width to the displayed information.

## Language support

Loadout Pilot currently includes:

- Automatic language detection using the WoW client language
- English
- Portuguese (Brazil)

Use:

`/lpilot language auto`

`/lpilot language en`

`/lpilot language ptbr`

Use `/reload` after changing the language.

## Saved configuration

Loadout Pilot stores configuration per character.

This includes:

- General context mappings
- Dungeon-specific overrides
- Automation settings
- Language preference
- Chat notification preference
- HUD position
- Minimap-button position

Your Blizzard talent loadouts and equipment sets remain managed by World of Warcraft itself.

## Compatibility

- World of Warcraft Retail
- Midnight 12.1.0
- TOC Interface 120100

## Feedback and bug reports

Feedback is very welcome, especially for:

- Dungeon detection
- Mythic+ transitions
- Specialization switching
- Role protection
- Loot specialization
- Talent loadout switching
- Equipment set switching
- UI behavior

When reporting a problem, please include:

- Class and specialization
- Content type
- Dungeon name if applicable
- Expected behavior
- Actual behavior
- Whether you were in combat
- Whether a Mythic Keystone was already slotted
- Any error message shown by WoW

You can report issues through:

[**GitHub Issues**](../../issues)

## Support the project

If Loadout Pilot is useful to you and you would like to support continued development:

[**Buy Me a Coffee - bertuzzi**](https://buymeacoffee.com/bertuzzi)

Bug reports, reproducible issues, suggestions, and testing feedback are also very welcome.

See [SUPPORT.md](SUPPORT.md) for additional information.

## License

Loadout Pilot is released under the **MIT License**.

## Author

Developed and maintained by **Thiago Bertuzzi**.
