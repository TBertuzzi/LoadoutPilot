#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
VERSION = "1.0.0"
INTERFACE = "120100"
REQUIRED = [
    "LoadoutPilot.toc", "Localization.lua", "Data.lua", "Core.lua",
    "README.md", "CHANGELOG.md", "LICENSE", "TESTING.md",
    "CURSEFORGE_DESCRIPTION.md", "CURSEFORGE_SUBMISSION.md", "PUBLISHING.md",
    "SUPPORT.md", "RELEASE_NOTES_v1.0.0.md",
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

core = (ROOT / "Core.lua").read_text(encoding="utf-8")
for snippet in (
    "C_PartyInfo.IsDelveInProgress",
    "C_ChallengeMode.IsChallengeModeActive",
    "C_ChallengeMode.HasSlottedKeystone",
    "C_ClassTalents.SwitchToLoadoutByIndex",
    "C_ClassTalents.LoadConfig",
    "C_EquipmentSet.UseEquipmentSet",
    "CreateMinimapButton",
    "LoadoutPilotMinimapButton",
    "LoadoutPilotLanguagePicker",
    "languageOverride",
    "ToggleLanguagePicker",
    "SetLanguageOverride",
    "RESET_POSITIONS",
    "ResetPositions",
    "CHAT_MESSAGES_ON",
    "chatMessages",
    'command == "language"',
    'command == "chat"',
    "GetMinimapButtonOrbitRadii",
    "MINIMAP_BUTTON_OUTER_OFFSET",
    "OnSizeChanged",
    "Interface\\\\AddOns\\\\LoadoutPilot\\\\Media\\\\MinimapIcon",
    "LayoutStatusWidget",
    "pending-retry",
    "ACTIVE_TALENT_GROUP_CHANGED",
    "PLAYER_PVP_TALENT_UPDATE",
    "CompletePendingTalentSwitch",
    "pending-talent-retry",
    "StartPendingTalentWatch",
    "PVP_MATCH_COMPLETE",
    "UPDATE_BATTLEFIELD_STATUS",
    'return "mythicplus"',
    'return "pvp"',
    'PLAYER_REGEN_ENABLED',
):
    if snippet not in core:
        errors.append(f"Expected implementation marker missing: {snippet}")


for rel in ("README.md", "CURSEFORGE_DESCRIPTION.md", "SUPPORT.md", "RELEASE_NOTES_v1.0.0.md"):
    if "buymeacoffee.com/bertuzzi" not in (ROOT / rel).read_text(encoding="utf-8"):
        errors.append(f"Support link missing from {rel}")

localization = (ROOT / "Localization.lua").read_text(encoding="utf-8")
for snippet in (
    "LANGUAGE_AUTO",
    "LANGUAGE_PTBR",
    "LANGUAGE_EN",
    "SetLocaleOverride",
    "GetLocaleOverride",
    "LoadoutPilotDB.languageOverride",
):
    if snippet not in localization:
        errors.append(f"Expected localization marker missing: {snippet}")

for forbidden in (
    "CastSpellByName", "CastSpellByID", "RunMacroText", "UseAction",
    "PickupSpell", "TargetUnit", "AttackTarget",
):
    if forbidden in core:
        errors.append(f"Combat automation API must not be used: {forbidden}")

if f"## {VERSION}" not in (ROOT / "CHANGELOG.md").read_text(encoding="utf-8"):
    errors.append(f"CHANGELOG missing {VERSION}")

if errors:
    print("\n".join(errors), file=sys.stderr)
    sys.exit(1)

print("Static validation passed.")
