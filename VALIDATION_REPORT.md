# Validation Report - Loadout Pilot 1.1.2

Date: 2026-08-24
Target: World of Warcraft Retail 12.1.0 / Interface 120100
SavedVariables schema: 4

## Completed checks

- Confirmed `LoadoutPilot.toc` and `Data.lua` both report version `1.1.2`.
- Confirmed `Data.schema = 4` and character-scoped `LoadoutPilotDB` migration remains enabled.
- Parsed `Localization.lua`, `Data.lua`, `Core.lua`, and `tests/smoke.lua` successfully with `texluac -p`.
- Ran `scripts/validate.py` successfully.
- Ran the Lua smoke test successfully with `texlua`.
- Confirmed one canonical `dungeon:<InstanceID>` identity is used for the same dungeon across regular Dungeon/Mythic 0 and Mythic+ contexts when the InstanceID can be resolved.
- Confirmed legacy `mplus:<challengeID>` dungeon overrides migrate to the unified dungeon identity.
- Confirmed lazy migration also works on the first regular/Mythic 0 visit when the ChallengeMode catalog cannot resolve the InstanceID in advance.
- Confirmed the same configured dungeon override applies in regular/Mythic 0 and Mythic+ while the general Dungeon and Mythic+ defaults remain separate fallbacks for inherited fields.
- Confirmed the dungeon catalog does not expose duplicate regular/M+ entries when the canonical InstanceID is available.
- Confirmed per-dungeon playing specialization, loot specialization, talent, and equipment overrides remain functional.
- Confirmed role protection continues to allow same-role specialization switches and block incompatible cross-role playing-spec switches in grouped content.
- Confirmed loot specialization remains independent from playing-spec role protection and is restored when the override ends.
- Confirmed picker frame strata/levels remain above the Dungeon Overrides panel.
- Confirmed combat-safe specialization/talent/equipment retry logic and PvP -> World restoration regression scenarios continue to pass.
- Confirmed no combat automation APIs such as spell casting, targeting, macros, or action usage were introduced.

## Package checks

- CurseForge/Test archive contains exactly one top-level `LoadoutPilot` folder.
- Required addon files and `Media/MinimapIcon.tga` are present.
- ZIP integrity check passed.

CurseForge/Test SHA-256:
`de572a6bdd2504ce31486e94ec94d495fbe12033cf8aa03668b20023807d01d1`

## Live-client limitation

This environment cannot run the World of Warcraft Retail client. Static validation and mocked API tests cannot prove every Blizzard UI/API transition in the live client. Before uploading, verify the shared override once in a real Mythic 0 dungeon and once with a keystone slotted for the same dungeon, and confirm the Dungeon Overrides popup menus render above the panel.
