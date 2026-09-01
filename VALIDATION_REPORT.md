# Loadout Pilot 2.0.2 - Validation Report

Validation date: 2026-09-01  
Target: World of Warcraft Retail - Midnight 12.1.0 / Interface 120100  
SavedVariables schema: 5

## Result

**PASS for static validation and automated regression coverage.**

Live-client verification is still required because the test harness cannot reproduce every Blizzard instance/API transition.

## 2.0.2 hotfix validated

- `C_DelvesUI.IsInLair()` is checked before any Delve signal.
- A simulated Midnight Lair with `IsInLair() == true` and overlapping `HasActiveDelve() == true` resolves to **Raid**.
- The configured Raid rule is applied to the Lair fixture.
- Leaving the Lair resolves to **World** and restores the World rule.
- Normal Delve detection remains unchanged.
- The 2.0.1 completed-Delve reward/chest retention regression remains covered.

## Regression checks

- Lua syntax validation: PASS
- Static source validation: PASS
- Full smoke/regression suite: PASS
- Lair dedicated-location precedence over Delve signal: PASS
- Lair -> Raid mapping: PASS
- Lair -> World restore on exit: PASS
- Active Delve detection: PASS
- Completed Delve reward-phase retention: PASS
- No World specialization retry while looting a completed Delve: PASS
- Unified Dungeon/M0/Mythic+ regression: PASS
- AUTO / NOTIFY / OFF regression: PASS
- NOTIFY Apply/retry regression: PASS
- Raid Boss Loot Spec regression: PASS
- PvP -> World recovery: PASS
- Grouped/solo role-safety regression: PASS
- Import/export and event-history regression: PASS

## Required live-client test

1. Configure visibly different Raid, Delve, and World rules.
2. Enter **The Tidebound Grotto Lair**.
3. Confirm Loadout Pilot reports **Raid** and uses the Raid rule.
4. Leave the Lair and confirm **World** is restored.
5. Enter a normal Delve and confirm it still reports **Delve**.
6. Complete that Delve, remain for the reward chests, and confirm it stays **Delve** until you actually leave.

## Package expectations

- Interface: 120100
- Version: 2.0.2
- SavedVariables schema: 5
- CurseForge/Test ZIP: exactly one top-level `LoadoutPilot/` directory
- GitHub ZIP: source repository package with the 2.0.2 release artifact included
- Slash commands remain English regardless of UI language
