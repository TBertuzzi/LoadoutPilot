# Loadout Pilot 2.0.1

## Delve completion hotfix

Loadout Pilot 2.0.1 fixes a context transition that could occur immediately after completing a Delve.

Previously, WoW could report that the Delve was no longer **in progress** as soon as it was completed even though the player was still physically inside collecting the reward chests. Loadout Pilot could then resolve the context as **World** too early and begin restoring the World specialization/loadout. If the specialization change could not complete while the player was moving, the normal retry system could try again whenever the player stopped.

### Fixed

- Completed Delves remain in the **Delve** context during the reward/chest phase.
- World specialization, talents, gear, and Loot Spec are not restored until the player actually leaves the Delve.
- Midnight 12.x `C_DelvesUI.HasActiveDelve()` is now the primary Delve-location signal.
- `C_PartyInfo.IsDelveComplete()` is used as a guarded fallback while the player is still inside a scenario.
- Added automated regression coverage for active Delve -> completed Delve -> reward phase -> leave -> World.

No SavedVariables migration is required; schema remains 5.

## Support

https://buymeacoffee.com/bertuzzi
