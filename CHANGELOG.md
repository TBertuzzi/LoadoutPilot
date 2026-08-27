# Changelog

## 2.0.0 - 2026-08-27
- Polished Raid Bosses rows: boss and raid now use separate lines, with the Loot Spec badge isolated on the right so long localized names stay inside the button.
- Standardized all **HUD & Interface** action buttons to the same width, using the widest localized control as the baseline for a cleaner aligned column.
- Fixed PT-BR Raid Boss filter controls overlapping by giving Current Raid and Configured Only dedicated full-width rows.

- Added Raid Boss Loot Spec Overrides using Blizzard's Encounter Journal and stable `DungeonEncounterID` identities.
- Reworked Raid Boss Overrides into a scalable **Raid -> Boss -> Loot Spec** browser with automatic current-raid selection.
- Added **All raids**, raid picker pagination, boss search, **Configured only**, configured/total counters, and visible Loot Spec badges in the boss list.
- Saved raid/boss rules remain available after leaving a raid, and the selected raid can have all of its overrides cleared with an explicit confirmation without deleting the catalog.
- Boss rules activate from `ENCOUNTER_START`, avoiding Midnight's secret hostile-unit name/GUID/ID restrictions inside instances.
- Added legacy-raid Encounter Journal fallback that matches the public InstanceID across journal tiers when the current UiMapID cannot resolve the raid directly.
- Migrates matching NPC/name-keyed overrides from early 2.0 test builds onto stable encounter IDs.
- Boss targeting no longer drives automation; target changes alone never alter Loot Spec, playing spec, talents, or gear.
- Raid boss discovery now lists real journal encounters instead of raid adds/helpers.
- Fixed Raid Bosses pagination so Previous/Next no longer snap back to the page containing the selected boss.
- Added independent AUTO / NOTIFY / OFF modes for Specialization, Talents, Gear, and Loot Spec.
- Added a compact Apply / Ignore notification flow for NOTIFY mode.
- Fixed NOTIFY Apply for specialization and preserved confirmations across temporary retry states.
- Reorganized the main UI into General, Contexts, Dungeons, Raid Bosses, Automation, HUD & Interface, and Advanced sections.
- Added rule-source tracking and `/lpilot explain`.
- Added same-class Loadout Pilot configuration import/export.
- Added rolling event history and `/lpilot log`.
- Refined event history to keep meaningful state changes, compact duplicate events, and exclude routine reevaluation noise.
- Debug traces are stored only while **Chat debug** is enabled; the useful event history remains available independently.
- Event History now uses a clipped, scrollable text viewport and opens on recent entries without auto-selecting the entire log.
- Added confirmed Spec/Talent/Gear/Loot Spec changes, queued combat actions, role blocks, and failures as focused diagnostic events.
- Expanded HUD/status details with rule sources and raid boss information.
- Preserved unified dungeon overrides across Normal, Heroic, Mythic 0, and Mythic+.
- Preserved role-safe specialization switching, PvP recovery, and combat-safe retries.
- Fixed role protection so solo players in Dungeon/Mythic+/Raid contexts can switch across roles (for example Retribution DPS -> Protection Tank); protection remains active only when a group role actually needs to be preserved.
- Added GROUP_ROSTER_UPDATE reevaluation so joining/leaving a group immediately refreshes role safety.
- Migrated existing v1.x automation ON/OFF settings into the new automation-mode model.
- Improved PT-BR terminology by using **chefe/chefes** consistently in the raid-boss UI while slash commands remain English.
- Replaced unsupported arrow/bullet/checkmark glyphs in the in-game UI with WoW-font-safe ASCII separators.

## 1.1.2 - 2026-08-24

Dungeon override UX, loot specialization, and unified dungeon identity update.

- Fixed Dungeon Overrides popup menus rendering behind the override panel by placing picker frames above the panel's frame strata/level.
- Added a per-dungeon **Loot Specialization** override.
- Loot Spec supports every specialization for the current class plus **Current specialization** (WoW loot spec ID `0`).
- Loot specialization is independent from playing-spec role protection, so a DPS player can intentionally select Tank/Healer loot without changing the role they are playing.
- The addon remembers the loot specialization that was active before a dungeon loot override and restores it when the override is no longer active.
- Added retry/verification using `GetLootSpecialization`, `SetLootSpecialization`, and `PLAYER_LOOT_SPEC_UPDATED`.
- Unified Dungeon and Mythic+ overrides into **one override per dungeon**. The same dungeon-specific rule now applies in Normal, Heroic, Mythic 0, and Mythic+.
- Kept the general **Dungeon** and **Mythic+** mappings separate as fallbacks, so unconfigured fields still inherit the correct default for the current content.
- Mythic+ catalog entries are resolved to the same InstanceID used by regular dungeon instances, preventing duplicate `[M+]` and `[Dungeon]` records for the same place.
- Added automatic migration from the previous `mplus:<challengeID>` override keys to the unified dungeon key. If both old Dungeon and Mythic+ overrides existed, the old Mythic+ values win on conflicting explicitly configured fields.
- Added loot-specialization details to the HUD tooltip and `/lpilot status` output.
- Extended PT-BR and English localization, tests, and documentation.

## 1.1.1 - 2026-08-24

Role-safety update for specialization automation.

- Added group-role detection using the player's assigned Tank, Healer, or DPS role.
- Added specialization-role detection and role labels throughout the configuration UI.
- Dungeon, Mythic+, Raid, and PvP rules now block automatic cross-role specialization changes when they conflict with the player's assigned role.
- If the group role is unavailable, cross-role automatic switches are conservatively blocked by comparing the target role with the current specialization role.
- Same-role switches such as Frost -> Unholy remain automatic.
- World and Delve specialization changes remain unrestricted.
- Added role details to the HUD tooltip and role-mismatch status messaging.
- Added PLAYER_ROLES_ASSIGNED handling so compatible pending rules can be reevaluated when the player's role changes.

## 1.1.0 - 2026-08-24

Dungeon Rules update.

- Added optional automatic specialization mapping for each general content context.
- When the first dungeon specialization override is created for a context with no default spec, the current spec is captured as that context default so the addon can restore it afterward.
- Added dungeon-specific overrides for Mythic+ and encountered normal dungeons.
- Dungeon overrides can independently override specialization, talent loadout, and equipment set.
- Unconfigured override fields inherit the normal Dungeon or Mythic+ defaults.
- Equipment inheritance can fall back to the base context mapping even when a dungeon override changes specialization.
- Added ordered specialization -> talents -> equipment application so spec-specific talent loadouts are only applied after the target specialization is active.
- Added combat-safe pending/retry logic for specialization changes.
- Added Mythic+ dungeon identity using active/slotted challenge map information.
- Added remembered normal-dungeon identities after the player encounters them.
- Added the Dungeon Overrides configuration window and `/lpilot overrides`.
- Added `/lpilot spec on|off` and a Spec AUTO control in the main window.
- Preserved all 1.0 PvP-exit talent/equipment recovery, language, HUD, minimap, chat, and position-reset behavior.

## 1.0.0 - 2026-08-24

First stable public release.

- Promoted the tested 0.1.10 feature set to stable 1.0.0.
- Finalized public README, CurseForge description, release notes, and publishing instructions.
- Added a project support page and Buy Me a Coffee link: `https://buymeacoffee.com/bertuzzi`.
- Preserved robust PvP -> World recovery for talents and equipment.
- Preserved adaptive HUD, custom minimap button, language selector, optional chat notifications, and manual automation indicators.

## 0.1.10 - 2026-08-24

PvP exit talent-switch reliability fix.

- Fixed talent loadouts getting stuck on `Applying...` after leaving PvP.
- Added automatic out-of-combat retries for pending talent changes, matching the equipment retry behavior.
- Added a guarded talent-switch watcher with a `LoadConfig` fallback when Blizzard's saved-loadout delegate does not confirm the change.
- Synced pending talent completion from Blizzard talent update events.
- Corrected saved-loadout detection to compare saved loadout IDs instead of the live working ActiveConfig ID.

## 0.1.9 - 2026-08-24

Pre-release quality-of-life update.

- Added configurable chat notifications, enabled by default.
- Disabling chat notifications suppresses routine automatic talent/gear switch messages while preserving explicit command output and configuration confirmations.
- Added a Restore Positions button that resets both the status HUD and minimap-button position.
- `/lpilot resetpos` now restores both positions as well.
- The status HUD now marks talents and/or equipment as `(MANUAL)` when the corresponding automatic switch option is disabled.
- Preserved all language, adaptive HUD, minimap, and PvP transition fixes from 0.1.8.

## 0.1.8 - 2026-08-24

Language selector update.

- Added the same language-selection model used by DK Mentor.
- Added **Automatic (WoW)**, **Portuguese (Brazil)**, and **English** options.
- Automatic mode follows the WoW client language and falls back to English for unsupported locales.
- Added a language button to the main Loadout Pilot window.
- Added a modal language picker with the current selection highlighted.
- Added `/lpilot language auto|ptbr|en` plus `lang` and `idioma` aliases.
- Language preference is stored per character and is applied after `/reload`.

## 0.1.7 - 2026-08-24

Minimap rim positioning fix.

- Reworked the minimap-button geometry using the proven DK Mentor implementation.
- Removed the fixed 78px orbit radius; the orbit now follows the actual minimap width and height.
- Added an outer offset so the button center stays just beyond the minimap edge.
- Removed screen clamping that could push the button back into the minimap.
- Matched Blizzard/LibDBIcon-style border, background, icon, and highlight geometry.
- Added automatic repositioning when Edit Mode resizes the minimap.
- Minimap dragging now matches DK Mentor: drag directly around the rim.
- Updated manual packaging scripts to include the custom Media icon.

## 0.1.6 - 2026-08-24

Custom minimap icon update.

- Replaced the generic minimap button texture with a custom Loadout Pilot icon.
- Added the new icon asset under `Media/MinimapIcon.tga`.
- Kept the current minimap behavior: left-click to open, right-click to apply, and Shift + drag to move around the minimap.

## 0.1.5 - 2026-08-24

Inline inspired HUD update.

- Restyled the HUD to a slimmer single-row presentation inspired by the reference layout.
- Added a more transparent background treatment.
- The HUD now presents: specialization icon, talents, equipment, and current status inline.
- The HUD automatically expands to the right and falls back to a second line when text becomes too long.
- Context, class, and specialization remain available in the hover tooltip.

## 0.1.4 - 2026-08-24

Adaptive HUD sizing update.

- Removed the large unused empty space on the status HUD.
- The HUD now resizes dynamically to fit the current text content.
- Short text keeps the HUD compact.
- Longer text can expand the HUD to the right up to a safe maximum width.
- Very long text wraps and expands the HUD downward when needed.

## 0.1.3 - 2026-08-24

PvP exit equipment recovery fix.

- Fixed an issue where equipment could remain on the PvP set after returning to World content.
- Added automatic retry for pending equipment swaps outside combat when WoW temporarily rejects the first request during a loading/context transition.
- Equipment swaps are now considered complete only after the currently mapped set is confirmed equipped; a stale `EQUIPMENT_SWAP_FINISHED` event from the previous context can no longer clear the new target.
- Added PvP completion/battlefield status events as extra context refresh signals.
- Reset the retry cadence whenever the target equipment set is confirmed or the mapping changes.

## 0.1.2 - 2026-08-24

Minimap button update.

- Added a minimap button for quick access to Loadout Pilot.
- Left-click toggles the main window.
- Right-click applies the currently mapped loadout immediately.
- Shift + drag moves the button around the minimap.
- Added a settings toggle to show or hide the minimap icon.

## 0.1.1 - 2026-08-24

HUD refinement update.

- Reduced the status HUD footprint for a less intrusive presentation.
- Reduced the specialization icon from 46x46 to 24x24.
- Simplified the HUD title to show only the current context.
- Added hover tooltip details for class, specialization, context, talents, gear, and status.

## 0.1.0 - 2026-08-24

Initial beta.

- Added generic support for every Retail class and specialization.
- Added automatic context detection for World, Delve, Dungeon, Mythic+, Raid, and PvP.
- Added per-spec/per-context mapping of saved Blizzard talent loadouts.
- Added per-spec/per-context mapping of saved Blizzard equipment sets.
- Added automatic talent and gear switching with combat-safe queuing.
- Added manual Apply fallback.
- Added movable class/spec/context status HUD.
- Added English and Brazilian Portuguese localization.
