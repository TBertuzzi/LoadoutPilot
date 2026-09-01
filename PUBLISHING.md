# Publishing Loadout Pilot 2.0.2

## Before publishing

1. Install the Test ZIP into `_retail_/Interface/AddOns/`.
2. Confirm the main 2.0 sidebar UI opens without Lua errors.
3. Verify the 2.0.2 Lair regression: enter **The Tidebound Grotto** and confirm the HUD/context uses **Raid**, not Delve. Leave the Lair and confirm World is restored.
4. Recheck the 2.0.1 Delve regression: complete a Delve, remain inside for the reward chests, and confirm the context stays Delve until you leave.
5. Verify at least one context mapping in World and one Dungeon/M0/Mythic+ rule.
6. Verify AUTO / NOTIFY / OFF in the live client.
7. In a raid, configure a boss from the Encounter Journal list, start its encounter, and verify the boss rule changes **Loot Spec only**.
8. Confirm the requested Loot Spec survives encounter end long enough for the post-kill bonus-roll flow.
9. Confirm moving to another configured/unconfigured boss does not carry the previous boss rule incorrectly.
10. Run `/lpilot explain` and confirm sources match the UI.
11. Export configuration, import it back, and confirm mappings survive.
12. Check `/lpilot log` after the test sequence.

## Automated checks

From the project root:

```bash
python scripts/validate.py
```

Run `tests/smoke.lua` with a Lua 5.4-compatible interpreter/test harness.

## CurseForge

Upload `LoadoutPilot-v2.0.2-CurseForge.zip`.

Recommended first 2.0 upload: **Beta** until the new UI and raid boss flow have been tested in the live WoW client. Once validated, the exact same tested build can be promoted/re-uploaded as **Release**.

## GitHub

Tag: `v2.0.2`

Suggested release title:

`Loadout Pilot 2.0.2 - Lair context hotfix`

Suggested commit:

`Fix Lair context detection`
