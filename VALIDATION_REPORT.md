# Loadout Pilot 2.0.0 - Validation Report

Validation performed after the Raid Boss Overrides UX was reorganized for long-term multi-raid use, the PT-BR/UI alignment fixes, and the solo role-protection correction discovered during Paladin cross-role testing.

## Result

**PASS for static validation and automated regression coverage. Live WoW verification is still required for the solo cross-role specialization fix and final UI checks.**

The Encounter Journal / `ENCOUNTER_START` boss identity flow remains unchanged by this UI update.

## Raid manager changes validated

- Raid-first navigation: **Raid -> Boss -> Loot Spec**.
- Current raid is promoted in the raid catalog and auto-selected when the manager opens inside a known raid.
- **All raids** view remains available.
- Previously discovered/saved raids remain in the catalog after leaving them.
- Boss-name search filters across saved raids.
- **Configured only** filters to bosses with an active Loot Spec override.
- Per-raid configured/total counts are calculated from the deduplicated boss catalog.
- Boss rows show their configured Loot Spec.
- In **All raids**, boss rows also show the raid name.
- Raid picker is paged so the raid list can grow over time.
- **Clear this raid's overrides** removes only the selected raid's boss Loot Spec rules and preserves the known boss catalog.
- The bulk-clear action requires an explicit in-addon confirmation.
- Existing boss pagination still does not snap back to the selected boss page.
- PT-BR **Current Raid** and **Configured Only** controls now use separate 300px rows so localized labels cannot overlap.
- All five **HUD & Interface** controls now share the same 220px width, based on the widest existing localized toggle.
- Role protection now applies only when the player is actually grouped (or group state cannot be determined safely). A player who is definitely solo can use cross-role rules such as DPS -> Tank in Dungeon/Mythic+/Raid contexts.
- `GROUP_ROSTER_UPDATE` now forces rule reevaluation so leaving a group immediately releases role protection and joining a group restores it.

## Automated checks

- Static source validation: PASS
- Lua runtime execution through the available TeX Lua interpreter: PASS
- Full smoke/regression suite: PASS
- Unified Dungeon/M0/Mythic+ regression: PASS
- AUTO / NOTIFY / OFF regression: PASS
- NOTIFY Apply and retry regression: PASS
- Encounter Journal raid-boss discovery: PASS
- Legacy InstanceID journal fallback: PASS
- NPC-keyed early-2.0 boss-rule migration: PASS
- ENCOUNTER_START boss Loot Spec activation: PASS
- Boss-to-boss override transition: PASS
- Encounter-end bonus-roll preservation: PASS
- Loot Spec restore on leaving raid: PASS
- Multi-raid catalog persistence: PASS
- Current-raid prioritization: PASS
- Boss search filtering: PASS
- Configured-only filtering: PASS
- Per-raid configured counters: PASS
- Per-raid bulk clear isolation: PASS
- Raid-boss pagination: PASS
- Import/export of encounter-keyed boss rules: PASS
- Event-history filtering/scroll structure: PASS
- PvP -> World recovery: PASS
- Grouped DPS -> Tank role block: PASS
- Solo DPS -> Tank cross-role switch: PASS
- Group roster reevaluation of role protection: PASS

## Required live test for this revision

0. On a multi-role class (Paladin is ideal), enter a Dungeon/Raid **solo** while mapped from a DPS spec to a Tank spec. Confirm the addon switches to Tank and does not show `Role mismatch`. Then test the same mapping while actually grouped and assigned DPS; confirm the cross-role switch is blocked.
1. Enter a raid and open **Raid Bosses -> Boss Overrides**.
2. Confirm the current raid is selected automatically.
3. Open the raid selector and confirm **All raids** plus saved raids are listed.
4. Leave the raid and open the manager again; confirm the saved raid remains available.
5. Search for a boss by name.
6. Toggle **Configured only** on and off and verify the PT-BR label stays fully inside its button without overlapping **Current Raid**.
7. Confirm the configured counter changes when boss overrides are added/removed.
8. Switch between two saved raids and verify their boss lists do not mix.
9. If the raid selector has multiple pages, test Previous/Next.
10. Test **Clear this raid's overrides**, cancel once, then confirm once. Verify only that raid is cleared and the boss catalog remains.
11. Start a configured encounter and confirm the existing Loot Spec automation still works.
12. Open **HUD & Interface** and confirm HUD status, lock, minimap, chat, and reset-position buttons are exactly the same width in PT-BR.

## Package expectations

- Interface: 120100
- Version: 2.0.0
- CurseForge/Test ZIP: one top-level `LoadoutPilot/` directory
- Slash commands remain English regardless of UI language
