# Live testing checklist - 1.0.0

Test on World of Warcraft Retail 12.1.0 with Lua errors enabled.

## Basic

- `/lpilot` opens and closes settings.
- First run opens settings automatically.
- Compact HUD shows mapped talents, equipment, and current status; class/spec/context remain available in the hover tooltip.
- HUD can be moved when unlocked and persists after `/reload`.

## Every specialization tested

- Talent picker lists that spec's saved Blizzard loadouts.
- Equipment picker lists Blizzard Equipment Manager sets.
- Mapping survives `/reload`.
- Switching spec displays that spec's independent mappings.

## Contexts

- Open World -> World
- Delve -> Delve
- Normal/Heroic/Mythic dungeon without active keystone -> Dungeon
- Active keystone -> Mythic+
- Raid -> Raid
- Battleground/Arena -> PvP

## Automation

- Entering a configured context switches to the mapped talent loadout when allowed.
- Entering a configured context equips the mapped gear outside combat.
- Entering/changing context during combat queues changes.
- Leaving combat retries queued changes.
- PvP -> World: verify talents and equipment both return to the World mappings and the HUD does not remain on `Applying...`.
- Repeat PvP -> World after a loading screen/teleport to exercise transient transition retries.
- `Apply mapped loadout now` retries both talent and gear mappings.
- Missing/deleted loadouts are reported without Lua errors.
- Delete/recreate a loadout or equipment set with the same name and verify name-based repair.

## Regression

- No combat abilities are cast.
- No equipment set or talent loadout is created/deleted by the addon.
- No `ADDON_ACTION_BLOCKED` spam while simply entering combat.

## Minimap button

1. Verify the Loadout Pilot button sits on the **outer rim** of the minimap, not over the map contents.
2. Resize the minimap in Edit Mode and confirm the button follows the new rim automatically.
3. Drag the button around the minimap and confirm it remains on the outer edge.
4. Reload the UI and confirm the saved angle is preserved.
5. Confirm the button uses the standard Blizzard-style circular border size, matching the DK Mentor implementation.
6. Left-click should open/close Loadout Pilot; right-click should apply the mapped loadout.
