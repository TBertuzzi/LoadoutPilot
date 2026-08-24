# Live testing checklist - 1.1.2

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
- Seasonal Mythic+ dungeons appear in the list.
- Enter a normal dungeon and confirm it becomes available in the remembered dungeon list.
- Confirm the same dungeon appears only once even if it is both a seasonal Mythic+ dungeon and a dungeon you have visited normally.
- Select the current dungeon with **Select current dungeon**.
- Configure and clear specialization, loot specialization, talent, and equipment override fields independently.
- Verify **Inherit** correctly shows/uses the normal Dungeon or Mythic+ default for playing spec/talents/gear, and **No override** leaves loot spec unmanaged.
- Change an override's specialization and confirm an incompatible old talent override is cleared.
- Remove the entire override and confirm the default context rule returns.

## Recommended real scenario

Configure:

- Dungeon default -> Frost + Dungeon Default + PvE Default
- Mythic+ default -> Frost + M+ Default + PvE Default
- Dungeon A override -> alternate specialization + dungeon-specific talent + inherited PvE gear
- Dungeon B -> no override

Then verify:

1. Enter Dungeon A as Mythic 0: alternate specialization -> loot spec -> dungeon talent -> gear -> Ready.
2. Leave and re-enter the same Dungeon A with a keystone slotted: the **same override** is reused; no second override entry is needed.
3. Enter Dungeon B as Mythic 0 with no override: the Dungeon default is used.
4. Enter Dungeon B as Mythic+ with no override: the Mythic+ default is used.

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

## 1.1.2 dropdown layering regression

- Open **Dungeon Overrides** and open the Specialization, Loot Spec, Talent, and Equipment pickers.
- Confirm every popup row renders **above** the override panel instead of behind it.
- Pay special attention to the lower Talent/Equipment buttons, where the old bug made only the bottom of the picker visible outside the panel.

## 1.1.2 loot-specialization checks

- Start with an explicit loot specialization selected in WoW.
- Configure Dungeon A with a different Loot Spec override and verify it changes on entry/preparation.
- Move to a dungeon with **No override** and verify the previous loot specialization is restored.
- Configure **Current specialization** and verify WoW reports the current-spec loot mode.
- Verify a DPS player can select a Tank/Healer loot specialization without the playing-spec role-safety check blocking the loot choice.
- Temporarily change loot spec manually while a dungeon override is active and verify Loadout Pilot re-applies the configured override.

## 1.1.2 unified Dungeon/Mythic+ override checks

- If you previously tested 1.1.0-1.1.2 builds, confirm old `[M+]` overrides are migrated and remain configured after `/reload`.
- Pick a seasonal Mythic+ dungeon, configure a playing-spec override, and verify there is only one row for that dungeon.
- Enter that dungeon as Mythic 0 and verify the override applies.
- Slot a keystone for the same dungeon and verify the same override remains active.
- Clear one override field and verify inheritance follows the current context: Dungeon default in Mythic 0, Mythic+ default in a keystone run.
