# Validation Report — Loadout Pilot 0.1.10

Date: 2026-08-24

## Completed checks

- Confirmed Retail 12.1.0 / Interface 120100 metadata in `LoadoutPilot.toc`.
- Confirmed matching version `0.1.10` in `LoadoutPilot.toc` and `Data.lua`.
- Static validation passed for required implementation markers.
- Executed the Lua smoke test successfully with `texlua`.
- Confirmed PvP-exit equipment retry remains implemented.
- Added equivalent out-of-combat retry behavior for pending talent loadouts.
- Added `StartPendingTalentWatch` to verify saved-loadout selection after a switch request.
- Added guarded `LoadConfig` fallback when `SwitchToLoadoutByIndex` does not confirm during transition.
- Added completion handling for `TRAIT_CONFIG_UPDATED` plus additional talent-related events.
- Changed selected-loadout detection to prefer `GetLastSelectedSavedConfigID`, matching the proven DK Mentor approach.
- Smoke test simulated a transient PvP-exit talent-edit rejection, a saved-loadout delegate that fails to confirm on the first attempt, and a transient equipment rejection; both mappings recovered and the HUD left `Applying...`.

## Important limitation

The automated smoke test uses a mocked WoW API environment. The PvP transition still needs one live-client verification because Blizzard can expose brief protected/transitional states that mocks cannot reproduce exactly.
