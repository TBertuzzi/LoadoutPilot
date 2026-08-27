# Publishing Loadout Pilot 2.0.0

## Before publishing

1. Install the Test ZIP into `_retail_/Interface/AddOns/`.
2. Confirm the main 2.0 sidebar UI opens without Lua errors.
3. Verify at least one context mapping in World and one Dungeon/M0/Mythic+ rule.
4. Verify AUTO / NOTIFY / OFF in the live client.
5. In a raid, configure a boss from the Encounter Journal list, start its encounter, and verify the boss rule changes **Loot Spec only**.
6. Confirm the requested Loot Spec survives encounter end long enough for the post-kill bonus-roll flow.
7. Confirm moving to another configured/unconfigured boss does not carry the previous boss rule incorrectly.
8. Run `/lpilot explain` and confirm sources match the UI.
9. Export configuration, import it back, and confirm mappings survive.
10. Check `/lpilot log` after the test sequence.

## Automated checks

From the project root:

```bash
python scripts/validate.py
```

Run `tests/smoke.lua` with a Lua 5.4-compatible interpreter/test harness.

## CurseForge

Upload `LoadoutPilot-v2.0.0-CurseForge.zip`.

Recommended first 2.0 upload: **Beta** until the new UI and raid boss flow have been tested in the live WoW client. Once validated, the exact same tested build can be promoted/re-uploaded as **Release**.

## GitHub

Tag: `v2.0.0`

Suggested release title:

`Loadout Pilot 2.0.0 - Set your rules. Play your content.`

Suggested commit:

`Build Loadout Pilot 2.0 rules and raid automation`
