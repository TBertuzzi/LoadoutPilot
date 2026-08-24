#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
VERSION = "1.1.1"
INTERFACE = "120100"
REQUIRED = [
    "LoadoutPilot.toc", "Localization.lua", "Data.lua", "Core.lua",
    "README.md", "CHANGELOG.md", "LICENSE", "TESTING.md",
    "CURSEFORGE_DESCRIPTION.md", "CURSEFORGE_SUBMISSION.md", "PUBLISHING.md",
    "SUPPORT.md", "RELEASE_NOTES_v1.1.1.md",
    "Media/MinimapIcon.tga",
]

errors = []
for rel in REQUIRED:
    if not (ROOT / rel).is_file():
        errors.append(f"Missing required file: {rel}")

toc = (ROOT / "LoadoutPilot.toc").read_text(encoding="utf-8")
for expected in (
    f"## Interface: {INTERFACE}",
    f"## Version: {VERSION}",
    "## SavedVariablesPerCharacter: LoadoutPilotDB",
):
    if expected not in toc:
        errors.append(f"TOC missing: {expected}")

data = (ROOT / "Data.lua").read_text(encoding="utf-8")
for expected in (
    f'Data.version = "{VERSION}"',
    "Data.schema = 2",
):
    if expected not in data:
        errors.append(f"Data.lua missing: {expected}")

core = (ROOT / "Core.lua").read_text(encoding="utf-8")
for snippet in (
    # Existing context and switching behavior.
    "C_PartyInfo.IsDelveInProgress",
    "C_ChallengeMode.IsChallengeModeActive",
    "C_ChallengeMode.HasSlottedKeystone",
    "C_ClassTalents.SwitchToLoadoutByIndex",
    "C_ClassTalents.LoadConfig",
    "C_EquipmentSet.UseEquipmentSet",
    "StartPendingTalentWatch",
    "pending-talent-retry",
    "PVP_MATCH_COMPLETE",
    "UPDATE_BATTLEFIELD_STATUS",
    # 1.1 specialization automation.
    "C_SpecializationInfo.SetSpecialization",
    "UnitGroupRolesAssigned",
    "GetSpecializationRoleByID",
    "GetRoleProtectionState",
    "PLAYER_ROLES_ASSIGNED",
    "ROLE_MISMATCH_STATUS",
    "TrySwitchSpecialization",
    "pending-spec-retry",
    "specBindings",
    "autoSpec",
    # 1.1 dungeon overrides and identity.
    "GetCurrentDungeonInfo",
    "GetDungeonCatalog",
    "GetActiveChallengeMapID",
    "GetSlottedKeystoneInfo",
    '"mplus:"',
    '"dungeon:"',
    "dungeonOverrides",
    "knownDungeons",
    "ResolveRuntimeRule",
    "CreateDungeonOverrideFrame",
    "DUNGEON_OVERRIDES",
    'command == "overrides"',
    'command == "spec"',
    # Existing UI/QoL.
    "CreateMinimapButton",
    "LoadoutPilotMinimapButton",
    "LoadoutPilotLanguagePicker",
    "languageOverride",
    "ResetPositions",
    "chatMessages",
    "LayoutStatusWidget",
    "Interface\\\\AddOns\\\\LoadoutPilot\\\\Media\\\\MinimapIcon",
):
    if snippet not in core:
        errors.append(f"Expected implementation marker missing: {snippet}")

localization = (ROOT / "Localization.lua").read_text(encoding="utf-8")
for snippet in (
    "LANGUAGE_AUTO",
    "LANGUAGE_PTBR",
    "LANGUAGE_EN",
    "SPECIALIZATION_OVERRIDE",
    "DUNGEON_OVERRIDES_DESCRIPTION",
    "INHERIT_DEFAULT",
    "SPEC_MANUAL_REQUIRED",
    "GROUP_ROLE",
    "TARGET_ROLE",
    "ROLE_MISMATCH_STATUS",
):
    if snippet not in localization:
        errors.append(f"Expected localization marker missing: {snippet}")

for forbidden in (
    "CastSpellByName", "CastSpellByID", "RunMacroText", "UseAction",
    "PickupSpell", "TargetUnit", "AttackTarget",
):
    if forbidden in core:
        errors.append(f"Combat automation API must not be used: {forbidden}")

for rel in ("README.md", "CURSEFORGE_DESCRIPTION.md", "SUPPORT.md", "RELEASE_NOTES_v1.1.1.md"):
    path = ROOT / rel
    if path.is_file() and "buymeacoffee.com/bertuzzi" not in path.read_text(encoding="utf-8"):
        errors.append(f"Support link missing from {rel}")

if f"## {VERSION}" not in (ROOT / "CHANGELOG.md").read_text(encoding="utf-8"):
    errors.append(f"CHANGELOG missing {VERSION}")

if errors:
    print("\n".join(errors), file=sys.stderr)
    sys.exit(1)

print("Static validation passed.")
