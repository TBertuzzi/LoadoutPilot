#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
VERSION = "2.0.2"
INTERFACE = "120100"
SCHEMA = 5
REQUIRED = [
    "LoadoutPilot.toc", "Localization.lua", "Data.lua", "Core.lua",
    "README.md", "CHANGELOG.md", "LICENSE", "TESTING.md",
    "CURSEFORGE_DESCRIPTION.md", "CURSEFORGE_SUBMISSION.md", "PUBLISHING.md",
    "SUPPORT.md", "RELEASE_NOTES_v2.0.2.md",
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
    f"Data.schema = {SCHEMA}",
):
    if expected not in data:
        errors.append(f"Data.lua missing: {expected}")

core = (ROOT / "Core.lua").read_text(encoding="utf-8")
for snippet in (
    # Context detection and existing switching behavior.
    "C_DelvesUI.IsInLair",
    "C_DelvesUI.HasActiveDelve",
    "C_PartyInfo.IsDelveInProgress",
    "C_PartyInfo.IsDelveComplete",
    "C_ChallengeMode.IsChallengeModeActive",
    "C_ChallengeMode.HasSlottedKeystone",
    "C_ClassTalents.SwitchToLoadoutByIndex",
    "C_ClassTalents.LoadConfig",
    "C_EquipmentSet.UseEquipmentSet",
    "StartPendingTalentWatch",
    "pending-talent-retry",
    "PVP_MATCH_COMPLETE",
    "UPDATE_BATTLEFIELD_STATUS",
    # Specialization / role safety.
    "C_SpecializationInfo.SetSpecialization",
    "UnitGroupRolesAssigned",
    "GetSpecializationRoleByID",
    "GetRoleProtectionState",
    "GetPlayerGroupedState",
    "PLAYER_ROLES_ASSIGNED",
    "GROUP_ROSTER_UPDATE",
    "ROLE_MISMATCH_STATUS",
    # Loot specialization and unified dungeon overrides.
    "GetLootSpecialization",
    "SetLootSpecialization",
    "PLAYER_LOOT_SPEC_UPDATED",
    "SetDungeonOverrideLootSpec",
    "SyncLootSpecializationRule",
    "MigrateUnifiedDungeonOverrides",
    "GetCurrentDungeonInfo",
    "GetDungeonCatalog",
    "GetChallengeDungeonIdentity",
    "dungeonOverrides",
    "knownDungeons",
    # 2.0 raid boss loot-spec rules.
    "GetCurrentRaidJournalInstanceID",
    "DiscoverCurrentRaidBossesFromJournal",
    "EJ_GetInstanceForMap",
    "EJ_GetEncounterInfoByIndex",
    "EJ_GetInstanceByIndex",
    "SetRaidBossLootSpec",
    "HandleEncounterStart",
    "HandleEncounterEnd",
    "CleanupKnownRaidBosses",
    "ensureSelectedVisible",
    "raidBossOverrides",
    "knownRaidBosses",
    '"ENCOUNTER_START"',
    '"ENCOUNTER_END"',
    # 2.0 automation modes and notify UI.
    "automationModes",
    "SetAutomationMode",
    "CycleAutomationMode",
    "GetNotificationRecommendation",
    "CreateNotifyFrame",
    "LoadoutPilotNotifyFrame",
    "identityKey",
    "IsExplicitApplyKind",
    '"notify"',
    # 2.0 explainability, transfer, event history, and UI.
    "GetRuleExplanationLines",
    "PrintExplain",
    "AppendEventLog",
    "CompactEventLog",
    "LogResolvedRuleEvent",
    "GetRecentEventLogText",
    "ExportConfiguration",
    "ImportConfiguration",
    "CreateTransferFrame",
    "LoadoutPilotTransferScrollFrame",
    "SetScrollChild",
    "RefreshTransferScroll",
    "CreateRaidBossOverrideFrame",
    "GetRaidCatalog",
    "GetFilteredRaidBossCatalog",
    "GetRaidBossConfigurationCounts",
    "ClearRaidBossOverridesForRaid",
    "LoadoutPilotRaidPicker",
    "LoadoutPilotRaidBossSearchEditBox",
    "selectedRaidBossRaidKey",
    "raidBossConfiguredOnly",
    "SetMainPage",
    "local hudButtonWidth = 220",
    'command == "explain"',
    'command == "mode"',
    'command == "bosses"',
    'command == "export"',
    'command == "import"',
    'command == "log"',
    # Existing UI/QoL.
    "CreateMinimapButton",
    "LoadoutPilotMinimapButton",
    "LoadoutPilotLanguagePicker",
    "languageOverride",
    "ResetPositions",
    "chatMessages",
    "LayoutStatusWidget",
    r"Interface\\AddOns\\LoadoutPilot\\Media\\MinimapIcon",
):
    if snippet not in core:
        errors.append(f"Expected implementation marker missing: {snippet}")


smoke = (ROOT / "tests/smoke.lua").read_text(encoding="utf-8")
for snippet in (
    "Lair was misdetected as Delve",
    "Lair did not participate in Raid-context instance handling",
    "Lair did not apply the configured Raid specialization",
    "leaving a Lair did not restore World context",
    "completed Delve was misdetected as World during reward phase",
    "completed Delve queued/retried an incorrect World specialization switch",
    "stale Delve completion flag leaked into World context",
):
    if snippet not in smoke:
        errors.append(f"Context regression marker missing from smoke test: {snippet}")

localization = (ROOT / "Localization.lua").read_text(encoding="utf-8")
for snippet in (
    "SLOGAN_V2",
    "MODE_AUTO", "MODE_NOTIFY", "MODE_OFF",
    "AUTOMATION_LOOTSPEC",
    "NOTIFY_TITLE", "NOTIFY_APPLY", "NOTIFY_IGNORE",
    "SOURCE_RAID_BOSS_OVERRIDE",
    "EXPLAIN_TITLE",
    "RAID_BOSS_OVERRIDES",
    "RAID_BOSS_TARGET_BEHAVIOR",
    "ALL_RAIDS", "CURRENT_RAID_BUTTON", "SEARCH_BOSS",
    "CONFIGURED_ONLY_ON", "RAID_BOSS_CONFIGURED_COUNT",
    "CLEAR_RAID_OVERRIDES",
    "EXPORT_CONFIGURATION", "IMPORT_CONFIGURATION",
    "EVENT_LOG",
    "PAGE_GENERAL", "PAGE_CONTEXTS", "PAGE_DUNGEONS", "PAGE_RAID_BOSSES",
    "PAGE_AUTOMATION", "PAGE_HUD", "PAGE_ADVANCED",
    "ROLE_MISMATCH_STATUS",
    "LOOT_SPEC_OVERRIDE",
):
    if snippet not in localization:
        errors.append(f"Expected localization marker missing: {snippet}")

for forbidden in (
    "CastSpellByName", "CastSpellByID", "RunMacroText", "UseAction",
    "PickupSpell", "TargetUnit", "AttackTarget",
):
    if forbidden in core:
        errors.append(f"Combat automation API must not be used: {forbidden}")

for rel in ("README.md", "CURSEFORGE_DESCRIPTION.md", "SUPPORT.md", "RELEASE_NOTES_v2.0.2.md"):
    path = ROOT / rel
    if path.is_file() and "buymeacoffee.com/bertuzzi" not in path.read_text(encoding="utf-8"):
        errors.append(f"Support link missing from {rel}")

changelog = (ROOT / "CHANGELOG.md").read_text(encoding="utf-8")
if f"## {VERSION}" not in changelog:
    errors.append(f"CHANGELOG missing {VERSION}")

if errors:
    print("\n".join(errors), file=sys.stderr)
    sys.exit(1)

print("Static validation passed for Loadout Pilot 2.0.2.")
