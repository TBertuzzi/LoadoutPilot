# Validation report — Loadout Pilot 2.2.0 Release

Date: 2026-10-07
Source: user-provided `LoadoutPilot-main.zip` (2.1.0 baseline). No repository was modified.
Target: WoW Retail / Interface 120100. SavedVariables schema 5.

## Completed locally

| Check | Result |
| --- | --- |
| Lua syntax (`texluac -p` for Localization, Data, Core and smoke harness) | PASS |
| Repository static validation (`python3 scripts/validate.py`) | PASS |
| Mocked WoW API regression suite (`texlua tests/smoke.lua .`) | PASS |
| Existing Delve reward-phase and Lair-to-Raid transitions | PASS in mock |
| Dungeon and boss overrides, role protection, AUTO/NOTIFY/OFF, combat queues, PvP recovery | PASS in mock |
| Read-only preview, cross-class/invalid rejection, changed-rule diff, confirmation reset | PASS in mock |
| Automatic pre-import backup and restoration | PASS in mock |
| Forbidden combat automation API checks | PASS |

## Packaging

- The release ZIP contains one `LoadoutPilot/` root with TOC, Lua files, media, changelog and license.
- Source contains tests, scripts, documentation and the release notes, without repository history or transient build files.
- Version metadata is 2.2.0 in TOC, Data and validator; schema is unchanged.

## Live-client approval

The user reported extensive in-game testing and approved release on October 7, 2026. The captured Delve test recorded the detected context at 20:51:00 and talent completion at 20:51:06; the user confirmed the talent-switch bar appeared immediately. The subsequent World restoration was recorded at 20:51:27 after context detection at 20:51:22. The longer earlier Delve interval involved combat according to the user.

No runtime timing changes were introduced during release packaging. The Core, Data, Localization and media bytes match Test r1. Automated tests are mocked; user approval does not constitute exhaustive certification of every game state. These files are packaged for distribution and have not been uploaded to CurseForge or a repository by this session.
