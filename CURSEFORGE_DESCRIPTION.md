# Loadout Pilot

**Set your rules. Play your content. Loadout Pilot handles the rest.**

Loadout Pilot is a World of Warcraft Retail addon that automatically follows the content you are playing with the specialization, Loot Spec, saved Blizzard talent loadouts, and equipment sets **you already chose**.

It does not try to calculate BiS or decide the best build for you. You define the rules once; Loadout Pilot remembers when to use them.

## Loadout Pilot 2.0

### Raid Boss Loot Spec Overrides

Pre-plan a Loot Spec for individual raid bosses. Loadout Pilot loads the current raid's bosses from Blizzard's **Encounter Journal** and applies the configured Loot Spec when that encounter starts.

The boss manager is organized by raid and keeps saved rules for raids you have already configured. The current raid is selected automatically, while **All raids**, boss search, **Configured only**, per-raid progress counters, and a paged raid picker make large long-term catalogs easy to manage.

**Raid-boss automation changes Loot Spec only.** Your playing specialization, talents, and gear continue to follow the normal Raid rule.

Midnight hides hostile creature identity from addon code inside instances, so Loadout Pilot deliberately uses public Encounter Journal / `ENCOUNTER_START` IDs instead of relying on the player's target.

### AUTO / NOTIFY / OFF

Choose behavior independently for:

- Specialization
- Talents
- Gear
- Loot Spec

**AUTO** applies the rule automatically when WoW allows it.  
**NOTIFY** shows an Apply / Ignore reminder.  
**OFF** leaves that category alone.

### Explainable rules

The new General page shows the resolved rule and where every field came from. `/lpilot explain` prints the same information for troubleshooting.

### Import / Export and Event History

Back up or transfer rules between characters of the same class, and copy a short event history when reporting a reproducible issue.

## Dungeon Overrides

Each dungeon has one override shared across Normal, Heroic, Mythic 0, and Mythic+.

Dungeon-specific fields can independently set:

- Playing specialization
- Loot specialization
- Talent loadout
- Equipment set

Fields left on **Inherit** use the appropriate general Dungeon or Mythic+ fallback.

Example:

**Dungeon default:** Frost + Dungeon Build + PvE Gear  
**Mythic+ default:** Frost + M+ Build + PvE Gear  
**Altar of Fangs:** Unholy + Blood Loot Spec + Altar Build + Inherit Gear

## Other features

- World, Delve, Dungeon, Mythic+, Raid, and PvP contexts.
- Works with every Retail class and specialization.
- Role-safe playing-spec automation in grouped content, while solo players remain free to switch across DPS/Tank/Healer roles.
- Mythic+ detection when a keystone is slotted, before the timer starts when possible.
- Combat/transition queue and retry behavior.
- PvP -> World recovery for mapped talents and equipment.
- Compact adaptive HUD with detailed hover information.
- Custom minimap button.
- English and Brazilian Portuguese.
- `/lpilot apply`, `/lpilot status`, `/lpilot explain`, `/lpilot overrides`, `/lpilot bosses`, `/lpilot log`, import/export, and more.

## Safe automation

Loadout Pilot does not cast abilities or automate combat. It uses Blizzard-supported player-configuration APIs and does not bypass restrictions on specialization, talent, Loot Spec, or equipment changes.

Loadout Pilot does not include raid/dungeon loot tables, calculate BiS, or choose an optimal Loot Spec for you.

## Compatibility

- World of Warcraft Retail
- Midnight 12.1.0
- Interface 120100

## Feedback

Bug reports, real-world testing, and feature suggestions are very welcome. The addon has already evolved substantially thanks to community feedback.

Source code is available on GitHub under **TBertuzzi/LoadoutPilot**.

## Support development

If Loadout Pilot is useful to you and you would like to support continued development:

https://buymeacoffee.com/bertuzzi
