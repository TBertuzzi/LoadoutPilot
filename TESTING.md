# Live testing checklist - 1.1.1

Test on World of Warcraft Retail 12.1.0 with Lua errors enabled.

## Regression from 1.0

- `/lpilot` opens and closes settings.
- Existing World, Delve, Dungeon, Mythic+, Raid, and PvP talent/equipment mappings survive the update.
- PvP -> World restores both talents and equipment and the HUD does not remain on `Applying...`.
- Language selection, optional chat messages, HUD movement, minimap movement, and Restore Positions still work.
- No combat abilities are cast and no talent/equipment set is created or deleted by the addon.

## General specialization mappings

For a class with at least two specializations:

1. Configure one specialization for World and another for Dungeon or Mythic+.
2. Leave **Spec AUTO** enabled.
3. Change contexts while out of combat.
4. Confirm specialization changes first, followed by the configured talent loadout and equipment set.
5. Disable **Spec AUTO** and confirm the addon reports the specialization change as manual instead of changing it automatically.
6. Re-enable Spec AUTO and confirm the pending rule can be applied.

## Dungeon Overrides UI

- `/lpilot overrides` opens/closes the Dungeon Overrides window.
- Mythic+ dungeons appear in the list.
- Enter a normal dungeon and confirm it becomes available in the remembered dungeon list.
- Select the current dungeon with **Select current dungeon**.
- Configure and clear specialization, talent, and equipment override fields independently.
- Verify **Inherit** correctly shows/uses the normal Dungeon or Mythic+ default.
- Change an override's specialization and confirm an incompatible old talent override is cleared.
- Remove the entire override and confirm the default context rule returns.

## Recommended real scenario

Configure:

- Mythic+ default -> Frost + M+ Default + PvE Default
- Dungeon A -> alternate specialization + dungeon-specific talent + inherited PvE gear
- Dungeon B -> default specialization + different talent + inherited PvE gear
- Dungeon C -> no override

Then verify:

1. Enter/prep Dungeon A: alternate specialization -> dungeon talent -> gear -> Ready.
2. Move to Dungeon B: default specialization is restored -> Dungeon B talent -> inherited gear -> Ready.
3. Move to Dungeon C: full Mythic+ default is restored.

## Mythic+ timing

- With a keystone slotted before the timer starts, confirm the addon identifies that dungeon and prepares its override.
- Start the key and confirm the rule does not loop or spam if WoW no longer permits specialization/talent changes.
- If a requested change is blocked, confirm status remains understandable and the addon retries only when appropriate.

## Combat queue

- Trigger a context/dungeon rule requiring a specialization change while in combat.
- Confirm the specialization does not change during combat.
- Leave combat and confirm the sequence completes: specialization -> talents -> equipment.

## Minimap button

- Confirm the button stays on the outer minimap rim.
- Resize the minimap in Edit Mode and confirm the button follows the rim.
- Drag it, `/reload`, and verify the saved angle remains.
- Left-click opens settings; right-click applies the current mapped rule.


## 1.1.1 role-safety checks

- As DPS in a grouped Dungeon/M+/Raid/PvP context, verify a DPS -> DPS dungeon override still switches automatically.
- As DPS, configure a target Tank spec and verify Loadout Pilot reports a role mismatch instead of switching automatically.
- Change the assigned group role to Tank and verify the rule is reevaluated.
- Verify World and Delve rules can still change between roles.
- Verify spec pickers and the HUD tooltip show Tank/Healer/DPS labels.
