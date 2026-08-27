# Loadout Pilot 2.0.0

**Set your rules. Play your content. Loadout Pilot handles the rest.**

Loadout Pilot 2.0 is the biggest update to the addon so far. What started as a lightweight context-based talent and equipment switcher has grown into a complete, explainable loadout rules system for World of Warcraft Retail.

You still make every important decision yourself: which specialization you want to play, which Loot Specialization you want, which Blizzard talent loadout should be active, and which equipment set should be equipped. Loadout Pilot simply remembers those decisions and applies them when the matching content is detected.

Version 2.0 focuses on five goals:

- More control over what is automatic.
- Better dungeon and raid-specific rules.
- Reliable boss-specific Loot Spec automation.
- Clear visibility into why a rule was selected.
- Better tools for backup, troubleshooting, and long-term configuration management.

---

## Major feature: Raid Boss Loot Spec Overrides

Loadout Pilot 2.0 introduces **per-boss Loot Specialization rules for raids**.

You can now configure a Loot Spec for an individual raid boss before the encounter starts. When Blizzard fires `ENCOUNTER_START`, Loadout Pilot resolves the public encounter ID and applies the Loot Spec you configured for that boss.

Example:

- Raid default: Frost DK setup
- Boss A: Frost Loot Spec
- Boss B: Unholy Loot Spec
- Boss C: Blood Loot Spec

Your **playing specialization, talents, and equipment do not change because of a boss rule**. Boss-specific rules intentionally control **Loot Spec only**. Your normal Raid context remains responsible for the actual build and gear you are playing.

### Raid-first boss manager

The Raid Bosses interface has been redesigned around a scalable:

**Raid -> Boss -> Loot Spec**

workflow.

The manager now includes:

- Automatic selection of the current raid when opened inside a known raid.
- An **All raids** view.
- Persistent previously discovered raids.
- Boss-name search.
- **Configured only** filtering.
- Configured/total boss counters for each raid.
- A paged raid selector for large long-term catalogs.
- A visible Loot Spec indicator for configured bosses.
- A confirmation-protected **Clear this raid's overrides** action.
- Separate boss and raid text lines for better readability.
- A dedicated right-aligned Loot Spec badge so long localized boss names stay inside the row.

Clearing a raid removes only that raid's saved Loot Spec rules. It does **not** delete the discovered boss catalog.

### Built around Blizzard Encounter Journal IDs

Midnight can hide hostile-unit identity from addon code inside instances. Names, GUIDs, and creature IDs that are visible in the normal WoW UI may be secret to addons.

Because of that, Loadout Pilot does **not** depend on targeting a boss.

Instead, 2.0 uses:

- Blizzard's Encounter Journal to discover real raid encounters.
- The stable public `DungeonEncounterID` for saved boss rules.
- `ENCOUNTER_START` to activate the correct rule.
- UiMapID-based journal resolution for modern raids.
- A public InstanceID fallback for legacy raids when needed.

This avoids accidental matches against raid adds or helpers and means simply targeting a boss never triggers automation.

### Boss transition safety

Raid boss automation also includes several lifecycle protections:

- The requested Loot Spec remains active immediately after encounter end so post-kill/bonus-roll interactions do not instantly lose the requested setting.
- A boss override is not allowed to leak into the next encounter when that next boss has no configured rule.
- Leaving the boss-override session restores the Loot Spec that was active before Loadout Pilot changed it.
- Early 2.0 test-build boss rules that used older NPC/name-based identities are migrated to stable encounter IDs when a matching boss can be resolved.

Loadout Pilot does not ship loot tables, calculate BiS, or decide the best Loot Spec for a boss. **You choose the strategy; the addon remembers it.**

---

## Major feature: AUTO / NOTIFY / OFF

Specialization, Talents, Gear, and Loot Spec now have **independent automation modes**.

### AUTO

The addon applies the resolved rule automatically whenever Blizzard allows the change.

### NOTIFY

The addon does not immediately perform the change. Instead, it displays a compact recommendation with:

- **Apply**
- **Ignore**

This is useful when you want Loadout Pilot to detect the correct setup but still want final confirmation before changing it.

### OFF

Loadout Pilot leaves that category alone and does not prompt you about it.

You can mix modes however you want. For example:

- Specialization -> AUTO
- Talents -> NOTIFY
- Gear -> AUTO
- Loot Spec -> AUTO

Existing 1.x ON/OFF automation settings are migrated into the new mode model so upgrading characters do not lose their previous intent.

NOTIFY confirmations were also hardened so specialization changes and temporary Blizzard retry states do not incorrectly discard an Apply request.

---

## Dungeon rules remain unified across difficulties

The dungeon-specific rule system remains one of Loadout Pilot's core features and is fully integrated into the 2.0 rule resolver.

Each dungeon has **one shared dungeon override** across:

- Normal
- Heroic
- Mythic 0
- Mythic+

A dungeon-specific rule can independently override:

- Playing specialization
- Loot Specialization
- Blizzard talent loadout
- Equipment set

Fields left on **Inherit** continue to use the appropriate general Dungeon or Mythic+ context rule.

This means one dungeon can have a special build without forcing you to duplicate the entire configuration for every difficulty.

Mythic+ detection also distinguishes a real keystone run from regular Mythic 0. A slotted keystone or active Challenge Mode can resolve the Mythic+ context before the timer starts when Blizzard exposes that state.

---

## Role-safe specialization switching

Playing-specialization automation continues to respect the role you are actually assigned while grouped.

Examples while grouped:

- Frost DPS -> Unholy DPS: allowed.
- Retribution DPS -> Protection Tank while assigned DPS: blocked.
- Protection Tank -> Retribution DPS while assigned Tank: blocked.

Version 2.0 refines this behavior so **solo players are not unnecessarily role-blocked**. If you enter a dungeon or raid alone, a configured cross-role rule such as DPS -> Tank is allowed because there is no group role that needs to be preserved.

`GROUP_ROSTER_UPDATE` now triggers reevaluation so role protection reacts immediately when you join or leave a group.

Loot Specialization is independent from the role/spec you are playing and is not blocked by playing-spec role protection.

---

## Completely reorganized settings UI

The main configuration window is now divided into focused sections:

- **General** - current context, resolved rule, quick Apply, Explain, and event history access.
- **Contexts** - World, Delve, Dungeon, Mythic+, Raid, and PvP defaults.
- **Dungeons** - dungeon-specific overrides.
- **Raid Bosses** - per-boss Loot Spec rules.
- **Automation** - AUTO / NOTIFY / OFF controls.
- **HUD & Interface** - HUD, minimap, chat notifications, locking, and position reset.
- **Advanced** - language, debug tools, import/export, and event history.

### Final 2.0 interface polish

The final 2.0 publication build also includes several layout refinements:

- Raid boss rows use separate boss and raid lines.
- Loot Spec badges are isolated on the right side of the row.
- Long localized boss/raid names stay contained inside the list item.
- PT-BR **Current Raid** and **Configured Only** controls use separate full-width rows so labels cannot overlap.
- All HUD & Interface action buttons use the same width for a cleaner aligned column.
- In-game separators use WoW-font-safe characters to avoid missing-glyph squares.
- PT-BR raid terminology consistently uses **chefe/chefes**.

Slash commands remain in English regardless of the selected UI language.

---

## Rule Source and `/lpilot explain`

Version 2.0 tracks **where every resolved value came from**.

A field can come from sources such as:

- Context default
- Dungeon override
- Raid boss override
- Current player state

For example:

```text
Context: Mythic+ - Mythic Keystone
Dungeon: Altar of Fangs
Specialization: Unholy <- Dungeon override
Loot spec: Blood <- Dungeon override
Talents: M+ Default <- Context default
Gear: PvE Default <- Context default
```

Use:

`/lpilot explain`

This makes inheritance much easier to understand and gives bug reports a much more useful diagnostic starting point.

---

## Import / Export

Loadout Pilot 2.0 adds configuration backup and transfer tools.

The exported configuration includes:

- Context specialization mappings
- Talent mappings
- Equipment mappings
- Dungeon overrides
- Raid boss Loot Spec overrides
- AUTO / NOTIFY / OFF modes

Imports are restricted to characters of the **same WoW class** to avoid loading incompatible specialization and talent mappings onto another class.

The transfer format is a Loadout Pilot configuration format; it is not a Blizzard talent import string.

Commands:

- `/lpilot export`
- `/lpilot import`

---

## Event History and diagnostics

2.0 adds a short rolling event history for meaningful Loadout Pilot decisions.

It can record events such as:

- Context changes
- Resolved-rule changes
- Raid boss encounter activation
- Confirmed Spec/Talent/Gear/Loot Spec changes
- Queued combat-safe actions
- Role-safety blocks
- Failed configuration actions
- Automation-mode changes
- Import/export activity

Routine internal reevaluations are filtered out so the history stays readable. Consecutive duplicate events are compacted rather than filling the log.

Verbose debug traces are added only while **Chat debug** is enabled, while the normal useful event history remains available independently.

The Event History window now uses a clipped, scrollable viewport, opens at the most recent entries, and no longer auto-selects the entire log.

Commands:

- `/lpilot log`
- `/lpilot log clear`

---

## Reliability and regression fixes included in 2.0

This release carries forward and hardens the reliability work from the 1.x series:

- PvP -> World talent recovery.
- PvP -> World equipment recovery.
- Combat-safe pending and retry behavior.
- Talent retries when Blizzard temporarily refuses a loadout switch during transitions.
- Equipment confirmation before a pending swap is considered complete.
- Ordered application of configuration changes.
- Specialization changes are confirmed before specialization-specific talent/equipment rules are applied.
- Loot Spec verification through Blizzard's Loot Spec update events.
- Dungeon/M0/Mythic+ identity unification and migration of older dungeon override keys.
- Boss pagination no longer jumps back to the selected boss page when using Previous/Next.
- Raid catalog rules remain available after leaving the instance.
- Repeated role-assignment reevaluations no longer flood event history.

The resolved application order for advanced rules is:

**Playing Spec -> Loot Spec -> Talents -> Equipment**

Loadout Pilot requests changes only when Blizzard permits them and queues/retries supported actions when appropriate.

---

## Compact HUD and minimap controls

The adaptive status HUD remains available in 2.0 and shows the information you need without taking over the screen.

The HUD can expose:

- Current context
- Current/target specialization
- Talent loadout
- Equipment set
- Loot Spec
- Automation/readiness state
- Rule sources
- Pending actions
- Role information

The custom minimap button remains available for quick access and uses minimap-aware positioning that follows the actual minimap geometry.

---

## Supported contexts

Loadout Pilot supports:

- World
- Delve
- Dungeon
- Mythic+
- Raid
- PvP (Battlegrounds and Arenas)

It is designed to work with every World of Warcraft Retail class and specialization.

---

## Commands

- `/lpilot` - open/close settings
- `/lpilot apply` - apply the currently resolved rule
- `/lpilot status` - print current mapping/status information
- `/lpilot explain` - explain where the active rule came from
- `/lpilot overrides` - open Dungeon Overrides
- `/lpilot bosses` - open Raid Boss Loot Overrides
- `/lpilot mode <spec|talents|gear|loot> <auto|notify|off>` - set one automation mode
- `/lpilot spec on|notify|off` - backward-compatible specialization shortcut
- `/lpilot export` - open configuration export
- `/lpilot import` - open configuration import
- `/lpilot log` - open recent event history
- `/lpilot log clear` - clear event history
- `/lpilot chat on|off` - toggle routine chat messages
- `/lpilot language auto|ptbr|en` - select addon language
- `/lpilot resetpos` - restore HUD/minimap positions
- `/lpilot debug` - toggle verbose debug tracing

---

## Language support

- Automatic (follows supported WoW client language)
- English
- Portuguese (Brazil)

---

## Safe automation / Blizzard restrictions

Loadout Pilot does **not** cast abilities and does not automate combat.

Specialization, Loot Spec, talents, and equipment changes are requested only through Blizzard-supported configuration APIs. The addon does not bypass combat restrictions, talent editing restrictions, specialization restrictions, or equipment restrictions.

When a supported action is temporarily unavailable, Loadout Pilot can queue/retry it or expose the pending/manual state instead of trying to bypass Blizzard's rules.

Loadout Pilot also never creates, edits, or deletes your Blizzard talent loadouts or equipment sets.

---

## Upgrade notes

Upgrading from 1.x keeps existing saved configuration through `LoadoutPilotDB`.

Version 2.0 includes migrations for:

- Legacy automation ON/OFF settings -> AUTO / NOTIFY / OFF model.
- Older Mythic+ dungeon override identities -> unified dungeon identities.
- Early 2.0 test-build boss identities -> stable encounter IDs when resolvable.

As always with a major update, keeping a copy of your configuration through the new Export feature is recommended before making large rule changes.

---

## Compatibility

- **World of Warcraft Retail**
- **Midnight 12.1.0**
- **Interface 120100**

---

## Thank you

Loadout Pilot 2.0 grew substantially from real gameplay testing and community feedback. Thank you to everyone who tested the addon, reported edge cases, and suggested ways to make the automation safer and more useful.

If you find a reproducible issue, include your class/spec, content type, dungeon or raid/boss when applicable, expected behavior, actual behavior, whether you were in combat, and the relevant `/lpilot log` output when possible.

If Loadout Pilot is useful to you and you would like to support continued development:

https://buymeacoffee.com/bertuzzi
