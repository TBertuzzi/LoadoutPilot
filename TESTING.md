# Loadout Pilot 2.0.2 Test Plan

## Automated coverage

The smoke test exercises:

- v1.x -> schema 5 migration.
- Unified Dungeon/M0/Mythic+ override identity.
- Specialization -> Loot Spec -> Talents -> Gear sequencing.
- Loot Spec restore/retry behavior.
- Role-safe playing specialization switching, including solo cross-role rules.
- Combat queue/retry behavior.
- PvP -> World regression behavior.
- Lair -> Raid context detection even when the overlapping active-Delve signal is true.
- Delve active -> completed reward phase -> World exit regression behavior.
- Raid boss discovery from the Encounter Journal.
- Stable DungeonEncounterID rules and migration from early NPC-keyed test rules.
- Raid-boss catalog cleanup/deduplication and Previous/Next pagination.
- ENCOUNTER_START Loot Spec activation without hostile target identity.
- Boss-to-boss Loot Spec changes without playing-spec/talent/gear changes.
- Legacy-map journal resolution by public InstanceID across tiers.
- Encounter-end bonus-roll preservation.
- AUTO / NOTIFY / OFF behavior.
- NOTIFY Apply flow.
- Rule Source / Explain output.
- Configuration export/import round trip.
- Event history and new slash commands.

## Required live-client validation for 2.0.2

### Lair context regression (2.0.2)

1. Configure visibly different **Raid**, **Delve**, and **World** specializations/loadouts.
2. Enter **The Tidebound Grotto Lair**.
3. Confirm the HUD/context reports **Raid**, not Delve.
4. Confirm the configured Raid specialization/talents/gear are used whenever WoW permits the change.
5. Leave the Lair.
6. Confirm the context changes to **World** and the World rule is restored.
7. Re-enter a normal Delve and confirm normal Delves still resolve as **Delve**.

### Delve completion regression (2.0.1)

1. Configure different **World** and **Delve** specializations/loadouts.
2. Enter a Delve and confirm the Delve rule is active.
3. Complete the Delve, but **do not leave**.
4. Walk between the reward chests and stop several times while looting.
5. Confirm the HUD/context remains **Delve** and Loadout Pilot does not attempt to restore the World specialization, talents, gear, or Loot Spec.
6. Leave the Delve.
7. Confirm the context changes to **World** only after leaving and the World rule is then restored.


Automated mocks cannot prove Blizzard's live protected-state behavior or visual layering. Test these in Retail before marking 2.0 as a stable Release.

### 1. Upgrade migration

- Install 2.0 over an existing 1.1.2 SavedVariables profile.
- Confirm existing context mappings and dungeon overrides remain present.
- Confirm categories previously enabled remain AUTO and previously disabled categories become OFF.

### 2. New UI

Open `/lpilot` and visit every sidebar page:

- General
- Contexts
- Dungeons
- Raid Bosses
- Automation
- HUD & Interface
- Advanced

Check text wrapping, button overlap, frame size, pickers, and both PT-BR/English.

### 3. AUTO / NOTIFY / OFF

Specialization NOTIFY regression check:

- Map the current context to a different same-role specialization.
- Set Specialization to **NOTIFY**.
- Confirm the popup uses readable ASCII separators (no square/missing-glyph characters).
- Click **Apply** and verify the popup closes immediately.
- If WoW temporarily blocks the spec change (for example while moving), stop moving and verify the confirmed change retries instead of being forgotten.
- Confirm **Ignore** dismisses the current recommendation without changing specialization.


For Talents (and preferably each category):

- AUTO -> rule applies automatically.
- NOTIFY -> no automatic change; popup appears.
- Ignore -> no change and popup does not immediately reappear for the same recommendation.
- Change context/rule -> a new recommendation can appear.
- Apply -> requested mapped change is performed when WoW permits it.
- OFF -> no automatic change and no popup.

### 4. Unified dungeon regression

Configure one dungeon-specific rule and enter the same dungeon as:

- Mythic 0
- Mythic+ with a keystone slotted

Confirm the same dungeon override is used in both, while inherited fields follow Dungeon vs Mythic+ defaults.

### 5. Raid Boss Loot Spec Overrides

Inside a raid:

1. Open Raid Bosses -> Raid Boss Loot Overrides.
2. Confirm the current raid's real bosses are loaded from the Encounter Journal and the **current raid is selected automatically**.
3. Open the raid picker and confirm **All raids** plus previously discovered raids are available, with the current raid shown first.
4. Test boss-name search and **Configured only** filtering.
5. Configure a Loot Spec different from the playing spec for one boss.
6. Leave the raid, return later, and confirm the saved raid/boss rule still exists.
7. Pull/start that encounter.

Confirm:

- The boss list contains actual encounters and not raid adds/helpers.
- The configured counter reflects the selected raid.
- In PT-BR, confirm **Raide atual** and **Somente configurados** are on separate full-width rows and no label overlaps another control.
- In **All raids**, boss rows include their raid name and configured Loot Spec when present.
- With more than one page of bosses, **Previous** and **Next** move between pages without snapping back to the selected boss.
- **Clear this raid's overrides** asks for confirmation and clears only the selected raid while keeping its bosses in the catalog.
- Loot Spec changes according to AUTO/NOTIFY/OFF at encounter start.
- Playing specialization does not change because of a boss rule.
- Talents do not change because of a boss rule.
- Equipment does not change because of a boss rule.
- Targeting or changing target before the pull does not trigger the rule.

### 6. Raid progression safety

- Kill a configured boss and verify its Loot Spec is not restored immediately before the bonus-roll interaction.
- Move to another configured boss and verify its own Loot Spec takes over.
- Move to a recognized boss with no override and verify the prior boss override does not leak into the new encounter.
- Leave the raid and verify the pre-boss Loot Spec is restored.

### 7. Explain

Use `/lpilot explain` in:

- World with context defaults.
- A dungeon with a specific override.
- A raid during a configured boss encounter.

Confirm Spec, Loot Spec, Talents and Gear show the expected source.

### 8. Import / Export

- Export the configuration from Advanced or `/lpilot export`.
- Save the string externally.
- Import it on another character of the same class or after deliberately modifying the test profile.
- Confirm context rules, dungeon overrides, boss overrides, and automation modes are restored.
- Confirm a different class rejects the import.

### 9. Event history

After changing contexts and starting configured raid encounters:

- Open Advanced -> Event history or `/lpilot log`.
- Confirm recent context/rule events and confirmed Spec/Talent/Gear/Loot Spec actions are readable.
- Leave **Chat debug** OFF and confirm no `[debug]` rows are added.
- Trigger/repeat role assignment or remain idle for a while and confirm the history is not filled with repetitive `role-assigned`/`apply` rows.
- If an identical queued/warning event repeats, confirm it is compacted rather than consuming many lines.
- Turn Chat debug ON only when verbose traces are desired.
- Test `/lpilot log clear`.

### 10. Role protection: solo vs grouped

Using a multi-role class such as Paladin:

- While **solo**, map Dungeon to a different-role spec (for example Retribution DPS -> Protection Tank) and enter the dungeon manually. Confirm the switch is allowed.
- Confirm the HUD does not show a role mismatch while solo.
- While actually **grouped** and assigned DPS, repeat a rule targeting a Tank spec and confirm it is blocked.
- Leave the group and confirm `GROUP_ROSTER_UPDATE` causes the previously blocked solo-compatible rule to be reevaluated.
- Rejoin/set the matching Tank role and confirm the Tank rule is allowed.

### 11. Regression

Recheck:

- Open **HUD & Interface** in PT-BR and English and confirm all five controls use the same width with no text clipping.
- HUD move/lock/reset.
- Minimap position/reset.
- Language change.
- Chat notification toggle.
- PvP -> World transition.
- Combat queue behavior.


### Event History window

- Open `/lpilot log` with a long history and verify the text remains clipped inside the dialog.
- Scroll using the mouse wheel and scrollbar.
- Verify opening the history does not auto-highlight all text.
- Verify import/export still use the same transfer dialog correctly.

## Raid boss Encounter Journal regression

1. Enter a raid, including a legacy raid when available.
2. Open Raid Bosses -> Boss Overrides before combat.
3. Confirm the boss list can be loaded without targeting or fighting anything.
4. Configure a Loot Spec for a boss.
5. Target that boss and verify targeting alone does not change the Loot Spec.
6. Start the encounter and verify the configured Loot Spec is applied from `ENCOUNTER_START`.
7. Verify only Loot Spec changes; spec, talents, and gear remain controlled by the normal Raid rule.
8. For a raid map where UiMapID resolution is unavailable, verify the InstanceID/Encounter Journal tier fallback still loads the boss list.

