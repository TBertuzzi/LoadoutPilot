# Loadout Pilot 2.0.2

## Lair context hotfix

Loadout Pilot 2.0.2 fixes context detection for the new **Lairs** introduced in Midnight 12.1.

World Boss Lairs such as **The Tidebound Grotto** are exposed through the same `C_DelvesUI` API family used by Delves. In some states the overlapping Delve signal could make Loadout Pilot classify a Lair as **Delve**.

### Fixed

- Lairs now use the **Raid** context in Loadout Pilot.
- `C_DelvesUI.IsInLair()` is evaluated before Delve detection.
- An overlapping `HasActiveDelve()` state no longer causes Tidebound Grotto Lair to use the Delve loadout.
- Leaving the Lair restores the normal **World** rule.
- The 2.0.1 completed-Delve reward/chest behavior remains unchanged.
- Added automated regression coverage for Lair -> Raid and Lair -> World transitions.

No SavedVariables migration is required; schema remains 5.

## Support

https://buymeacoffee.com/bertuzzi
