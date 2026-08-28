# Loadout Pilot 2.0.1 - Validation Report

Validation date: 2026-08-28  
Target: World of Warcraft Retail - Midnight 12.1.0 / Interface 120100  
SavedVariables schema: 5

## Result

**PASS for static validation and automated regression coverage.**

Live-client verification is still required because the test harness cannot reproduce every Blizzard protected-state and movement transition.

## 2.0.1 hotfix validated

- `C_DelvesUI.HasActiveDelve()` is used as the primary Midnight 12.x Delve-location signal.
- Existing `C_PartyInfo.IsDelveInProgress()` behavior remains as a compatibility signal.
- `C_PartyInfo.IsDelveComplete()` keeps the Delve context during the post-completion reward/chest phase.
- The completion fallback is accepted only while physically inside a `scenario` instance, preventing a stale completion flag from pinning the player to Delve after leaving.
- The context remains **Delve** across repeated retry/poll cycles after completion.
- World specialization is not requested while the player remains inside the completed Delve.
- Leaving the Delve changes the context to **World** and restores the configured World rule.
- A simulated stale `IsDelveComplete() == true` outside an instance still resolves to **World**.

## Regression checks

- Lua syntax validation: PASS
- Static source validation: PASS
- Full smoke/regression suite: PASS
- Active Delve detection: PASS
- Completed Delve reward-phase retention: PASS
- No World specialization retry while looting: PASS
- `IsDelveComplete()` guarded fallback: PASS
- Stale completed-Delve flag outside instance: PASS
- Delve -> World restore on actual exit: PASS
- Unified Dungeon/M0/Mythic+ regression: PASS
- AUTO / NOTIFY / OFF regression: PASS
- NOTIFY Apply/retry regression: PASS
- Raid Boss Loot Spec regression: PASS
- PvP -> World recovery: PASS
- Grouped/solo role-safety regression: PASS
- Import/export and event-history regression: PASS

## Required live-client test

1. Configure visibly different World and Delve specializations/loadouts.
2. Enter and complete a Delve.
3. Stay inside after completion and walk between the reward chests.
4. Stop moving several times while looting.
5. Confirm the HUD remains **Delve** and there are no attempts to restore the World specialization/loadout.
6. Leave the Delve.
7. Confirm the context changes to **World** only after the exit and the World rule is restored.

## Package expectations

- Interface: 120100
- Version: 2.0.1
- SavedVariables schema: 5
- CurseForge/Test ZIP: exactly one top-level `LoadoutPilot/` directory
- GitHub ZIP: source repository package with the 2.0.1 release artifact included
- Slash commands remain English regardless of UI language
