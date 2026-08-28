local ROOT = (arg and arg[1]) or "."

local specs = {
    [1] = { id = 64, name = "Frost", icon = 135846, role = "DAMAGER" },
    [2] = { id = 62, name = "Arcane", icon = 135932, role = "DAMAGER" },
    -- Synthetic third specialization used only to exercise cross-role safety.
    [3] = { id = 999, name = "Bulwark", icon = 134400, role = "TANK" },
}

local talentIDsBySpec = {
    [64] = {101, 202, 203},
    [62] = {301, 302},
    [999] = {},
}
local talentNames = {
    [101] = "Frost World",
    [202] = "Frost Dungeon",
    [203] = "Frost M+ Default",
    [301] = "Arcane Default",
    [302] = "Arcane Voidscar",
}
local gearNames = {
    [1] = "World Gear",
    [2] = "PvE Default",
    [3] = "Voidscar Gear",
}
local challengeMaps = {
    [500] = "Voidscar",
    [501] = "Ruby Life Pools",
    [502] = "Other Mythic Dungeon",
    [503] = "No Journal Dungeon",
}
local challengeDungeonIDs = {
    [500] = { uiMapID = 20500, journalID = 30500, instanceID = 10500 },
    [501] = { uiMapID = 20501, journalID = 30501, instanceID = 10501 },
    [502] = { uiMapID = 20502, journalID = 30502, instanceID = 10502 },
}

local raidJournal = {
    [9000] = {
        uiMapID = 29000,
        journalInstanceID = 39000,
        bosses = {
            { name = "Ula'tek", journalEncounterID = 40001, dungeonEncounterID = 30001 },
            { name = "Coiled Altar", journalEncounterID = 40002, dungeonEncounterID = 30002 },
        },
    },
}

local state = {
    locale = "ptBR",
    specIndex = 1,
    specID = 64,
    specName = "Frost",
    selectedTalentBySpec = { [64] = 101, [62] = 301 },
    inDelve = false,
    delveComplete = false,
    activeDelve = false,
    inInstance = false,
    instanceType = "none",
    instanceName = "Open World",
    instanceID = 0,
    difficultyID = 0,
    challenge = false,
    slottedKeystone = false,
    activeChallengeMapID = nil,
    slottedChallengeMapID = nil,
    combat = false,
    equippedSet = 1,
    equipmentUseFailures = 0,
    talentEditFailures = 0,
    talentSwitchFailures = 0,
    specSwitchFailures = 0,
    assignedRole = "DAMAGER",
    grouped = true,
    lootSpecID = 0,
    lootSpecSetFailures = 0,
    targetNPCID = nil,
    targetName = nil,
    targetClassification = "normal",
    targetLevel = 90,
    boss1NPCID = nil,
    boss1Name = nil,
    uiMapID = nil,
    selectedJournalInstanceID = nil,
    selectedJournalTier = 1,
}

local function syncSpec()
    local info = specs[state.specIndex]
    state.specID = info.id
    state.specName = info.name
end

local function widget()
    local o = { shown = false, point = {"CENTER", nil, "CENTER", 0, 0}, scripts = {} }
    local methods = {}
    function methods:SetSize(w, h) self.width = w; self.height = h end
    function methods:SetWidth(w) self.width = w end
    function methods:SetHeight(h) self.height = h end
    function methods:SetFrameStrata(v) self.frameStrata = v end
    function methods:SetFrameLevel(v) self.frameLevel = v end
    function methods:GetFrameLevel() return self.frameLevel or 0 end
    function methods:SetToplevel(v) self.toplevel = v end
    function methods:Raise() self.raised = true end
    function methods:SetClampedToScreen() end
    function methods:SetMovable() end
    function methods:EnableMouse() end
    function methods:RegisterForDrag() end
    function methods:RegisterForClicks() end
    function methods:SetBackdrop() end
    function methods:SetBackdropColor() end
    function methods:SetBackdropBorderColor() end
    function methods:SetTexCoord() end
    function methods:SetBlendMode() end
    function methods:SetAllPoints() end
    function methods:SetTexture(v) self.texture = v end
    function methods:SetText(v) self.text = v end
    function methods:GetText() return self.text or "" end
    function methods:SetTextColor() end
    function methods:SetJustifyH() end
    function methods:SetJustifyV() end
    function methods:GetStringWidth() return #(tostring(self.text or "")) * 7 end
    function methods:GetStringHeight() return 12 end
    function methods:SetPoint(a,b,c,d,e)
        if b == nil then
            self.point = {a, nil, a, 0, 0}
        else
            self.point = {a,b,c,d or 0,e or 0}
        end
    end
    function methods:GetWidth() return self.width or 140 end
    function methods:GetHeight() return self.height or 140 end
    function methods:SetScrollChild(child) self.scrollChild = child end
    function methods:UpdateScrollChildRect() end
    function methods:SetVerticalScroll(v) self.verticalScroll = v or 0 end
    function methods:GetVerticalScroll() return self.verticalScroll or 0 end
    function methods:GetVerticalScrollRange()
        local childHeight = self.scrollChild and self.scrollChild.height or 0
        return math.max(0, childHeight - (self.height or 140))
    end
    function methods:EnableMouseWheel() end
    function methods:ClearFocus() self.focused = false end
    function methods:SetFocus() self.focused = true end
    function methods:HighlightText() self.highlighted = true end
    function methods:GetCenter() return self.centerX or 500, self.centerY or 500 end
    function methods:GetEffectiveScale() return 1 end
    function methods:HookScript(name, fn) self.hooks = self.hooks or {}; self.hooks[name] = fn end
    function methods:ClearAllPoints() end
    function methods:GetPoint() return self.point[1], self.point[2], self.point[3], self.point[4], self.point[5] end
    function methods:StartMoving() end
    function methods:StopMovingOrSizing() end
    function methods:SetScript(name, fn) self.scripts[name] = fn end
    function methods:RegisterEvent(name) self.events = self.events or {}; self.events[name] = true end
    function methods:UnregisterEvent(name) if self.events then self.events[name] = nil end end
    function methods:Show() self.shown = true end
    function methods:Hide() self.shown = false end
    function methods:IsShown() return self.shown end
    function methods:SetShown(v) self.shown = v == true end
    function methods:CreateFontString() return widget() end
    function methods:CreateTexture() return widget() end
    setmetatable(o, {__index = methods})
    return o
end

UIParent = widget()
Minimap = widget()
Minimap.width = 300
Minimap.height = 260
Minimap.centerX = 500
Minimap.centerY = 500
DEFAULT_CHAT_FRAME = { messages = {}, AddMessage = function(self, text) table.insert(self.messages, text) end }
GameTooltip = {
    SetOwner=function() end, AddLine=function() end, AddDoubleLine=function() end,
    Show=function() end, Hide=function() end,
}
RAID_CLASS_COLORS = { MAGE = {r=0.25,g=0.78,b=0.92} }
SlashCmdList = {}
Enum = { LoadConfigResult = { Error=0, NoChangesNecessary=1, LoadInProgress=2, Ready=3 } }

function CreateFrame(_, name)
    local o = widget()
    if name then _G[name] = o end
    return o
end
function GetLocale() return state.locale end
function GetSpecialization() return state.specIndex end
function GetSpecializationInfo(index)
    local info = specs[index or state.specIndex]
    if not info then return nil end
    return info.id, info.name, "", info.icon, info.role
end
function GetNumSpecializations() return 3 end
function UnitClass() return "Mage", "MAGE", 8 end
function UnitGroupRolesAssigned(unit) return unit == "player" and state.assignedRole or "NONE" end
function IsInGroup() return state.grouped == true end
function IsInRaid() return state.grouped == true and state.instanceType == "raid" end
function GetNumGroupMembers() return state.grouped == true and 5 or 0 end
function GetSpecializationRoleByID(specID)
    for _, info in pairs(specs) do if info.id == specID then return info.role end end
    return nil
end
function UnitExists(unit)
    if unit == "target" then return state.targetNPCID ~= nil end
    if unit == "boss1" then return state.boss1NPCID ~= nil end
    return unit == "player"
end
function UnitCreatureID(unit)
    if unit == "target" then return state.targetNPCID end
    if unit == "boss1" then return state.boss1NPCID end
    return nil
end
function UnitGUID(unit)
    local id
    if unit == "target" then id = state.targetNPCID elseif unit == "boss1" then id = state.boss1NPCID end
    if not id then return nil end
    return "Creature-0-0-0-0-" .. tostring(id) .. "-0000000000"
end
function UnitName(unit)
    if unit == "target" then return state.targetName end
    if unit == "boss1" then return state.boss1Name end
    if unit == "player" then return "Tester" end
    return nil
end
function UnitClassification(unit)
    if unit == "target" and state.targetNPCID then return state.targetClassification or "normal" end
    if unit == "boss1" and state.boss1NPCID then return "worldboss" end
    return "normal"
end
function UnitLevel(unit)
    if unit == "target" and state.targetNPCID then return state.targetLevel or -1 end
    if unit == "boss1" and state.boss1NPCID then return -1 end
    return 90
end
function time() return os.time() end
function date(fmt, stamp) return os.date(fmt, stamp) end
function GetLootSpecialization() return state.lootSpecID end
function SetLootSpecialization(specID)
    specID = tonumber(specID)
    if specID == nil then return end
    if state.lootSpecSetFailures > 0 then
        state.lootSpecSetFailures = state.lootSpecSetFailures - 1
        return
    end
    if specID ~= 0 then
        local valid = false
        for _, info in pairs(specs) do if info.id == specID then valid = true break end end
        if not valid then return end
    end
    state.lootSpecID = specID
end
function IsInInstance() return state.inInstance, state.instanceType end
function GetInstanceInfo()
    return state.instanceName, state.instanceType, state.difficultyID, "Mock Difficulty", 5, 0, false, state.instanceID
end
function InCombatLockdown() return state.combat end
function issecretvalue() return false end
function GetCursorPosition() return 350, 350 end

C_Timer = { After = function(_, fn) fn() end }
C_SpecializationInfo = {
    GetSpecialization = function() return state.specIndex end,
    GetNumSpecializationsForClassID = function(classID) return classID == 8 and 3 or 0 end,
    GetSpecializationInfo = function(index)
        local info = specs[index]
        if not info then return nil end
        return info.id, info.name, "", info.icon, info.role
    end,
    SetSpecialization = function(index)
        if state.combat then return false end
        if state.specSwitchFailures > 0 then
            state.specSwitchFailures = state.specSwitchFailures - 1
            return false
        end
        if not specs[index] then return false end
        state.specIndex = index
        syncSpec()
        return true
    end,
}
C_PartyInfo = {
    IsDelveInProgress = function() return state.inDelve end,
    IsDelveComplete = function() return state.delveComplete end,
    IsChallengeModeActive = function() return state.challenge end,
}
C_DelvesUI = {
    HasActiveDelve = function() return state.activeDelve end,
}
C_ChallengeMode = {
    IsChallengeModeActive = function() return state.challenge end,
    HasSlottedKeystone = function() return state.slottedKeystone end,
    GetActiveChallengeMapID = function() return state.activeChallengeMapID end,
    GetSlottedKeystoneInfo = function() return state.slottedChallengeMapID end,
    GetMapTable = function() return {500, 501, 502, 503} end,
    GetMapUIInfo = function(id)
        local ids = challengeDungeonIDs[id]
        return challengeMaps[id], id, 1800, nil, nil, ids and ids.uiMapID or nil
    end,
}
C_Map = {
    GetBestMapForUnit = function(unit)
        if unit ~= "player" then return nil end
        return state.uiMapID
    end,
}
function EJ_GetInstanceForMap(uiMapID)
    for _, ids in pairs(challengeDungeonIDs) do
        if ids.uiMapID == uiMapID then return ids.journalID end
    end
    for _, raid in pairs(raidJournal) do
        if raid.uiMapID == uiMapID then return raid.journalInstanceID end
    end
    return nil
end
function EJ_SelectInstance(journalInstanceID)
    state.selectedJournalInstanceID = journalInstanceID
end
function EJ_GetNumTiers() return 2 end
function EJ_GetCurrentTier() return state.selectedJournalTier end
function EJ_SelectTier(index) state.selectedJournalTier = index end
function EJ_GetInstanceByIndex(index, isRaid)
    if isRaid ~= true then return nil end
    -- Put the synthetic raid on tier 2 so the fallback must scan tiers.
    if state.selectedJournalTier ~= 2 or index ~= 1 then return nil end
    local raid = raidJournal[9000]
    return raid.journalInstanceID, "Coiled Citadel", "", 0, 0, 0, 0, raid.uiMapID, "", true, 9000, 0, true
end
function EJ_GetEncounterInfoByIndex(index, journalInstanceID)
    journalInstanceID = journalInstanceID or state.selectedJournalInstanceID
    for instanceID, raid in pairs(raidJournal) do
        if raid.journalInstanceID == journalInstanceID then
            local boss = raid.bosses[index]
            if not boss then return nil end
            return boss.name, "", boss.journalEncounterID, 0, "", raid.journalInstanceID, boss.dungeonEncounterID, instanceID
        end
    end
    return nil
end
function EJ_GetInstanceInfo(journalID)
    for challengeID, ids in pairs(challengeDungeonIDs) do
        if ids.journalID == journalID then
            return challengeMaps[challengeID], "", 0, 0, 0, 0, 0, "", true, ids.instanceID, 0, false
        end
    end
    return nil
end
C_Traits = {
    GetConfigInfo = function(id)
        if not talentNames[id] then return nil end
        return { ID=id, name=talentNames[id] }
    end,
}
C_ClassTalents = {
    GetConfigIDsBySpecID = function(specID) return talentIDsBySpec[specID] or {} end,
    GetLastSelectedSavedConfigID = function(specID) return state.selectedTalentBySpec[specID] end,
    GetActiveConfigID = function() return state.selectedTalentBySpec[state.specID] end,
    UpdateLastSelectedSavedConfigID = function(specID, id) state.selectedTalentBySpec[specID] = id end,
    CanEditTalents = function()
        if state.combat then return false, "combat" end
        if state.talentEditFailures > 0 then
            state.talentEditFailures = state.talentEditFailures - 1
            return false, "transition"
        end
        return true, nil
    end,
    SwitchToLoadoutByIndex = function(index)
        if state.talentSwitchFailures > 0 then
            state.talentSwitchFailures = state.talentSwitchFailures - 1
            return
        end
        local ids = talentIDsBySpec[state.specID] or {}
        if ids[index] then state.selectedTalentBySpec[state.specID] = ids[index] end
    end,
    LoadConfig = function(id)
        local found = false
        for _, configID in ipairs(talentIDsBySpec[state.specID] or {}) do
            if configID == id then found = true break end
        end
        if not found then return Enum.LoadConfigResult.Error, "missing" end
        state.selectedTalentBySpec[state.specID] = id
        return Enum.LoadConfigResult.Ready
    end,
}
C_EquipmentSet = {
    GetEquipmentSetIDs = function() return {1,2,3} end,
    GetEquipmentSetID = function(name)
        for id,n in pairs(gearNames) do if n == name then return id end end
        return nil
    end,
    GetEquipmentSetInfo = function(id)
        local name = gearNames[id]
        if not name then return nil end
        return name, 134400, id, state.equippedSet == id, 10, state.equippedSet == id and 10 or 0, 10, 0, 0
    end,
    CanUseEquipmentSets = function() return true end,
    UseEquipmentSet = function(id)
        if state.combat or not gearNames[id] then return nil end
        if state.equipmentUseFailures > 0 then
            state.equipmentUseFailures = state.equipmentUseFailures - 1
            return false
        end
        state.equippedSet = id
        return true
    end,
}

-- Simulate a character upgrading from 1.1.2. Existing mappings must survive
-- and legacy mplus:<challengeID> overrides must migrate to the unified
-- dungeon:<InstanceID> identity.
LoadoutPilotDB = {
    schema = 3,
    firstRun = false,
    selectedContext = "world",
    selectedDungeonKey = "mplus:500",
    autoTalents = true,
    autoGear = true,
    languageOverride = "auto",
    chatMessages = true,
    talentBindings = { ["64:world"] = {configID=101, name="Frost World"} },
    equipmentBindings = { ["64:world"] = {setID=1, name="World Gear"} },
    dungeonOverrides = {
        ["mplus:500"] = { name="Voidscar", context="mythicplus", challengeMapID=500, lootSpecID=62 },
    },
    hud = { enabled=true, locked=false, point="CENTER", relativePoint="CENTER", x=0, y=170 },
    minimap = { hide=false, angle=225 },
}

local LP = {}
assert(loadfile(ROOT .. "/Localization.lua"))("LoadoutPilot", LP)
assert(loadfile(ROOT .. "/Data.lua"))("LoadoutPilot", LP)
assert(loadfile(ROOT .. "/Core.lua"))("LoadoutPilot", LP)
local addon = LP.addon

local function event(name, ...)
    assert(addon.scripts.OnEvent, "OnEvent missing")
    addon.scripts.OnEvent(addon, name, ...)
end
local function tick(seconds)
    assert(addon.scripts.OnUpdate, "OnUpdate missing")
    addon.scripts.OnUpdate(addon, seconds)
end
local function setWorld()
    state.inDelve = false
    state.delveComplete = false
    state.activeDelve = false
    state.inInstance = false
    state.instanceType = "none"
    state.instanceName = "Open World"
    state.instanceID = 0
    state.challenge = false
    state.slottedKeystone = false
    state.activeChallengeMapID = nil
    state.slottedChallengeMapID = nil
    state.uiMapID = nil
end
local function setDelve(inProgress, complete, hasActiveDelve)
    state.inDelve = inProgress == true
    state.delveComplete = complete == true
    state.activeDelve = hasActiveDelve ~= false
    state.inInstance = true
    state.instanceType = "scenario"
    state.instanceName = "Test Delve"
    state.instanceID = 12001
    state.difficultyID = 0
    state.challenge = false
    state.slottedKeystone = false
    state.activeChallengeMapID = nil
    state.slottedChallengeMapID = nil
    state.uiMapID = 22001
end

local function setDungeon(name, instanceID)
    state.inDelve = false
    state.delveComplete = false
    state.activeDelve = false
    state.inInstance = true
    state.instanceType = "party"
    state.instanceName = name
    state.instanceID = instanceID
    state.challenge = false
    state.slottedKeystone = false
    state.activeChallengeMapID = nil
    state.slottedChallengeMapID = nil
    state.uiMapID = nil
end
local function setMythicPlus(mapID, active)
    state.inDelve = false
    state.delveComplete = false
    state.activeDelve = false
    state.inInstance = true
    state.instanceType = "party"
    state.instanceName = challengeMaps[mapID]
    state.instanceID = 10000 + mapID
    state.challenge = active == true
    state.slottedKeystone = active ~= true
    state.activeChallengeMapID = active == true and mapID or nil
    state.slottedChallengeMapID = active ~= true and mapID or nil
    state.uiMapID = challengeDungeonIDs[mapID] and challengeDungeonIDs[mapID].uiMapID or nil
end
local function setRaid(name, instanceID)
    state.inDelve = false
    state.delveComplete = false
    state.activeDelve = false
    state.inInstance = true
    state.instanceType = "raid"
    state.instanceName = name or "Test Raid"
    state.instanceID = instanceID or 9000
    state.difficultyID = 16
    state.challenge = false
    state.slottedKeystone = false
    state.activeChallengeMapID = nil
    state.slottedChallengeMapID = nil
    state.uiMapID = raidJournal[state.instanceID] and raidJournal[state.instanceID].uiMapID or nil
end
local function targetBoss(npcID, name)
    state.targetNPCID = npcID
    state.targetName = name
    state.targetClassification = "worldboss"
    state.targetLevel = -1
end
local function clearTarget()
    state.targetNPCID = nil
    state.targetName = nil
    state.targetClassification = "normal"
    state.targetLevel = 90
end

-- Load and initialize.
event("ADDON_LOADED", "LoadoutPilot")
event("PLAYER_LOGIN")
assert(type(LoadoutPilotDB) == "table", "DB not initialized")
assert(LoadoutPilotDB.schema == 5, "database schema was not migrated to 5")
assert(LoadoutPilotDB.dungeonOverrides["mplus:500"] == nil, "legacy Mythic+ override key was not removed")
assert(LoadoutPilotDB.dungeonOverrides["dungeon:10500"] and LoadoutPilotDB.dungeonOverrides["dungeon:10500"].lootSpecID == 62, "legacy Mythic+ override was not migrated to unified dungeon key")
assert(LoadoutPilotDB.selectedDungeonKey == "dungeon:10500", "selected legacy Mythic+ dungeon was not migrated")
assert(LoadoutPilotDB.autoSpec == true and LoadoutPilotDB.autoTalents == true and LoadoutPilotDB.autoGear == true, "auto defaults wrong")
assert(LoadoutPilotDB.automationModes.spec == "auto" and LoadoutPilotDB.automationModes.talents == "auto" and LoadoutPilotDB.automationModes.gear == "auto" and LoadoutPilotDB.automationModes.lootSpec == "auto", "v2 automation modes were not initialized")
assert(type(LoadoutPilotDB.raidBossOverrides) == "table" and type(LoadoutPilotDB.knownRaidBosses) == "table", "raid boss tables missing")
assert(type(LoadoutPilotDB.eventLog) == "table" and #LoadoutPilotDB.eventLog > 0, "event history was not initialized")
assert(type(LoadoutPilotDB.specBindings) == "table", "spec bindings table missing")
assert(type(LoadoutPilotDB.dungeonOverrides) == "table", "dungeon overrides table missing")
assert(type(LoadoutPilotDB.knownDungeons) == "table", "known dungeons table missing")
assert(LoadoutPilotDB.talentBindings["64:world"] and LoadoutPilotDB.talentBindings["64:world"].configID == 101, "v1.0 talent mapping was lost during migration")
assert(LoadoutPilotDB.equipmentBindings["64:world"] and LoadoutPilotDB.equipmentBindings["64:world"].setID == 1, "v1.0 equipment mapping was lost during migration")
assert(LoadoutPilotDB.languageOverride == "auto", "language override default wrong")
assert(LoadoutPilotDB.chatMessages == true, "chat messages default wrong")
assert(_G.LoadoutPilotDungeonOverrideFrame.frameStrata == "FULLSCREEN_DIALOG", "dungeon override frame strata changed unexpectedly")
for _, pickerName in ipairs({"LoadoutPilotSpecPicker", "LoadoutPilotTalentPicker", "LoadoutPilotGearPicker", "LoadoutPilotLootSpecPicker"}) do
    local picker = _G[pickerName]
    assert(picker and picker.frameStrata == "FULLSCREEN_DIALOG", pickerName .. " is not on FULLSCREEN_DIALOG strata")
    assert((picker.frameLevel or 0) > (_G.LoadoutPilotDungeonOverrideFrame.frameLevel or 0), pickerName .. " is not above the dungeon override panel")
end

-- Existing v1.0 controls continue to work.
SlashCmdList.LOADOUTPILOT("chat off")
assert(LoadoutPilotDB.chatMessages == false, "chat messages did not disable")
SlashCmdList.LOADOUTPILOT("chat on")
assert(LoadoutPilotDB.chatMessages == true, "chat messages did not enable")
SlashCmdList.LOADOUTPILOT("language en")
assert(LoadoutPilotDB.languageOverride == "enUS", "English language override was not saved")
SlashCmdList.LOADOUTPILOT("lang auto")
assert(LoadoutPilotDB.languageOverride == "auto", "automatic language override was not restored")

-- Reset restores both HUD and minimap positions.
LoadoutPilotDB.hud.x = 123
LoadoutPilotDB.hud.y = -77
LoadoutPilotDB.minimap.angle = 45
SlashCmdList.LOADOUTPILOT("resetpos")
assert(LoadoutPilotDB.hud.x == 0 and LoadoutPilotDB.hud.y == 170, "HUD reset failed")
assert(LoadoutPilotDB.minimap.angle == 225, "minimap reset failed")

-- Base World mapping works as before.
LoadoutPilotDB.talentBindings["64:world"] = {configID=101, name="Frost World"}
LoadoutPilotDB.equipmentBindings["64:world"] = {setID=1, name="World Gear"}
state.selectedTalentBySpec[64] = 202
state.equippedSet = 2
SlashCmdList.LOADOUTPILOT("apply")
assert(state.specID == 64, "world apply changed spec unexpectedly")
assert(state.selectedTalentBySpec[64] == 101, "world talent apply failed")
assert(state.equippedSet == 1, "world gear apply failed")

-- 2.0.1 Delve completion regression: completing a Delve must NOT switch to
-- World while the player is still inside collecting reward chests. The Delve
-- rule stays active until the player actually leaves the scenario.
LoadoutPilotDB.specBindings["world"] = {specID=64, name="Frost"}
LoadoutPilotDB.specBindings["delve"] = {specID=62, name="Arcane"}
LoadoutPilotDB.talentBindings["62:delve"] = {configID=301, name="Arcane Default"}
setDelve(true, false, true)
tick(0.6)
assert(addon:DetectContext() == "delve", "active Delve context detection failed")
assert(state.specID == 62, "Delve mapping did not switch to the configured specialization")

-- The normal progress flag drops at completion. HasActiveDelve must keep the
-- context on Delve through the reward phase and prevent World-spec retries.
setDelve(false, true, true)
tick(0.6)
assert(addon:DetectContext() == "delve", "completed Delve was misdetected as World during reward phase")
assert(state.specID == 62, "completed Delve incorrectly restored the World specialization")
tick(2.1)
assert(state.specID == 62, "completed Delve queued/retried an incorrect World specialization switch")

-- If HasActiveDelve is unavailable/false, IsDelveComplete remains a guarded
-- fallback while physically inside the scenario.
setDelve(false, true, false)
assert(addon:DetectContext() == "delve", "completed Delve fallback detection failed")

-- Only leaving the scenario may restore World.
setWorld()
tick(0.6)
assert(addon:DetectContext() == "world", "leaving a Delve did not restore World context")
assert(state.specID == 64, "World specialization was not restored after leaving the Delve")

-- A stale completion flag outside any instance must never pin the player to Delve.
state.delveComplete = true
state.activeDelve = false
assert(addon:DetectContext() == "world", "stale Delve completion flag leaked into World context")
state.delveComplete = false

-- General Mythic+ defaults: Frost + default M+ talent + PvE gear.
LoadoutPilotDB.talentBindings["64:mythicplus"] = {configID=203, name="Frost M+ Default"}
LoadoutPilotDB.equipmentBindings["64:mythicplus"] = {setID=2, name="PvE Default"}
-- Arcane fallback mapping is deliberately available for talent only.
LoadoutPilotDB.talentBindings["62:mythicplus"] = {configID=301, name="Arcane Default"}

-- Voidscar overrides all three fields and switches specialization first.
-- Existing 1.0 users have no base specialization mapping; configuring the first
-- dungeon spec override must capture the current Frost spec as the Mythic+ default.
local voidscarEntry = addon:GetDungeonCatalogEntry("dungeon:10500")
assert(voidscarEntry, "Voidscar catalog entry missing before configuration")
addon:SetDungeonOverrideSpec(voidscarEntry, 62)
assert(LoadoutPilotDB.specBindings["mythicplus"] and LoadoutPilotDB.specBindings["mythicplus"].specID == 64, "first dungeon spec override did not capture the current Mythic+ default spec")
assert(LoadoutPilotDB.specBindings["dungeon"] and LoadoutPilotDB.specBindings["dungeon"].specID == 64, "unified dungeon spec override did not capture the regular Dungeon default spec")
addon:SetDungeonOverrideTalent(voidscarEntry, 302, 62)
addon:SetDungeonOverrideEquipment(voidscarEntry, 3)
addon:SetDungeonOverrideLootSpec(voidscarEntry, 62)
setMythicPlus(500, false) -- pre-start slotted keystone path
state.selectedTalentBySpec[62] = 301
state.equippedSet = 1
state.lootSpecID = 64 -- explicit Frost loot spec before entering the override
tick(0.6)
assert(addon:DetectContext() == "mythicplus", "pre-start mythic+ context detection failed")
local dungeon = addon:GetCurrentDungeonInfo()
assert(dungeon and dungeon.key == "dungeon:10500", "Voidscar unified dungeon identity failed")
assert(state.specID == 62, "Voidscar did not switch Frost -> Arcane")
assert(state.selectedTalentBySpec[62] == 302, "Voidscar talent override was not applied after spec switch")
assert(state.equippedSet == 3, "Voidscar equipment override was not applied")
assert(state.lootSpecID == 62, "Voidscar loot specialization override was not applied")

-- The same override must apply when the identical dungeon is entered as a
-- regular dungeon / Mythic 0, without creating a second [Dungeon] record.
setDungeon("Voidscar", 10500)
state.specIndex = 1; syncSpec()
state.selectedTalentBySpec[62] = 301
state.equippedSet = 1
tick(0.6)
assert(addon:DetectContext() == "dungeon", "regular/Mythic 0 context detection failed")
local sameDungeon = addon:GetCurrentDungeonInfo()
assert(sameDungeon and sameDungeon.key == "dungeon:10500", "regular dungeon did not reuse the unified dungeon identity")
assert(state.specID == 62, "unified Voidscar override did not apply outside Mythic+")
assert(state.selectedTalentBySpec[62] == 302, "unified Voidscar talent override did not apply outside Mythic+")
assert(state.equippedSet == 3, "unified Voidscar equipment override did not apply outside Mythic+")
assert(state.lootSpecID == 62, "unified Voidscar loot spec override did not apply outside Mythic+")

-- Compatibility fallback: if the ChallengeMode catalog cannot resolve an
-- InstanceID up front, the first regular/M0 visit migrates the old M+ key by
-- matching the current dungeon and ChallengeMode name.
LoadoutPilotDB.dungeonOverrides["mplus:503"] = {
    name = "No Journal Dungeon", context = "mythicplus", challengeMapID = 503, specID = 62,
}
setDungeon("No Journal Dungeon", 10503)
state.specIndex = 1; syncSpec()
tick(0.6)
assert(LoadoutPilotDB.dungeonOverrides["mplus:503"] == nil, "lazy legacy override migration did not remove the old M+ key")
assert(LoadoutPilotDB.dungeonOverrides["dungeon:10503"] and LoadoutPilotDB.dungeonOverrides["dungeon:10503"].specID == 62, "lazy legacy override migration did not create the unified dungeon key")
assert(state.specID == 62, "lazily migrated unified override did not apply on the first regular/M0 visit")

-- RLP overrides only talent. Base spec Frost and default gear must be restored.
LoadoutPilotDB.dungeonOverrides["dungeon:10501"] = {
    name = "Ruby Life Pools", context = "mythicplus", challengeMapID = 501,
    talent = {specID=64, configID=202, name="Frost Dungeon"},
}
setMythicPlus(501, true)
tick(0.6)
assert(state.specID == 64, "RLP did not restore the default Mythic+ Frost spec")
assert(state.selectedTalentBySpec[64] == 202, "RLP talent override was not applied")
assert(state.equippedSet == 2, "RLP did not inherit default Mythic+ equipment")
assert(state.lootSpecID == 64, "leaving a loot-spec override did not restore the previous loot specialization")

-- Loot spec 0 explicitly means "current specialization" and is a valid override.
local rlpEntry = addon:GetDungeonCatalogEntry("dungeon:10501")
assert(rlpEntry, "RLP catalog entry missing")
addon:SetDungeonOverrideLootSpec(rlpEntry, 0)
assert(state.lootSpecID == 0, "loot specialization override did not support current-spec mode (0)")
addon:ClearDungeonOverrideField(rlpEntry, "lootSpecID")
assert(state.lootSpecID == 64, "clearing the loot specialization override did not restore the previous setting")

-- Another M+ with no override falls back completely to the Mythic+ defaults.
setMythicPlus(502, true)
tick(0.6)
assert(state.specID == 64, "unconfigured M+ did not keep default Frost spec")
assert(state.selectedTalentBySpec[64] == 203, "unconfigured M+ did not inherit default talent")
assert(state.equippedSet == 2, "unconfigured M+ did not inherit default gear")
assert(state.lootSpecID == 64, "unconfigured M+ unexpectedly changed loot specialization")

-- Dungeon-specific spec override can inherit the target spec's base talent and gear.
LoadoutPilotDB.specBindings["dungeon"] = {specID=64, name="Frost"}
LoadoutPilotDB.talentBindings["64:dungeon"] = {configID=202, name="Frost Dungeon"}
LoadoutPilotDB.equipmentBindings["64:dungeon"] = {setID=2, name="PvE Default"}
LoadoutPilotDB.talentBindings["62:dungeon"] = {configID=301, name="Arcane Default"}
LoadoutPilotDB.dungeonOverrides["dungeon:777"] = {
    name = "The Test Dungeon", context = "dungeon", instanceID = 777,
    specID = 62,
}
setDungeon("The Test Dungeon", 777)
tick(0.6)
assert(state.specID == 62, "normal dungeon spec override did not apply")
assert(state.selectedTalentBySpec[62] == 301, "normal dungeon did not inherit Arcane dungeon talent")
assert(state.equippedSet == 2, "normal dungeon spec override did not inherit the base Dungeon equipment")
assert(LoadoutPilotDB.knownDungeons["777"] == "The Test Dungeon", "encountered normal dungeon was not remembered")

-- Removing the dungeon override restores the normal Dungeon defaults.
LoadoutPilotDB.dungeonOverrides["dungeon:777"] = nil
-- Force a rule refresh while staying in the same dungeon.
addon:ApplyCurrentRules("smoke-remove-override", false)
assert(state.specID == 64, "removing dungeon override did not restore default Dungeon spec")
assert(state.selectedTalentBySpec[64] == 202, "removing dungeon override did not restore default Dungeon talent")
assert(state.equippedSet == 2, "removing dungeon override did not preserve default Dungeon gear")

-- Auto-spec OFF must never change specialization automatically; HUD/status reports manual requirement.
setWorld()
state.specIndex = 1; syncSpec()
LoadoutPilotDB.specBindings["world"] = {specID=62, name="Arcane"}
addon:SetAutomationMode("spec", "off", true)
addon:ApplyCurrentRules("smoke-auto-spec-off", false)
assert(state.specID == 64, "autoSpec OFF still changed specialization")
local manualStatus = addon:GetStatusState()
assert(string.lower(manualStatus):find("manual", 1, true), "manual specialization requirement is not visible in status")
addon:SetAutomationMode("spec", "auto", true)
LoadoutPilotDB.specBindings["world"] = {specID=64, name="Frost"}

-- Specialization changes queue in combat and complete afterwards in the required order.
setMythicPlus(500, false)
state.specIndex = 1; syncSpec()
state.selectedTalentBySpec[62] = 301
state.equippedSet = 2
state.combat = true
addon:ApplyCurrentRules("smoke-combat-spec", false)
assert(state.specID == 64, "specialization changed during combat")
state.combat = false
event("PLAYER_REGEN_ENABLED")
assert(state.specID == 62, "queued specialization did not apply after combat")
assert(state.selectedTalentBySpec[62] == 302, "talent override did not follow queued specialization")
assert(state.equippedSet == 3, "equipment override did not follow queued specialization")

-- Transient specialization failure is retried outside combat.
setMythicPlus(501, true)
state.specIndex = 2; syncSpec()
state.specSwitchFailures = 1
tick(0.6) -- first Frost request fails
assert(state.specID == 62, "spec failure mock did not preserve old spec")
tick(2.1) -- retry
assert(state.specID == 64, "pending specialization was not retried")
assert(state.selectedTalentBySpec[64] == 202, "talents were not applied after specialization retry")
assert(state.equippedSet == 2, "gear was not applied after specialization retry")

-- Role protection: same-role switches remain automatic while cross-role
-- switches are blocked in grouped content.
setMythicPlus(500, false)
state.assignedRole = "DAMAGER"
state.specIndex = 1; syncSpec()
addon:ApplyCurrentRules("smoke-same-role", false)
assert(state.specID == 62, "same-role DPS -> DPS specialization switch was incorrectly blocked")

-- Configure a synthetic Tank target for another Mythic+ dungeon. The player is
-- assigned DPS, so automatic cross-role switching must be blocked.
LoadoutPilotDB.dungeonOverrides["dungeon:10502"] = {
    name = "Other Mythic Dungeon", context = "mythicplus", challengeMapID = 502,
    specID = 999,
    lootSpecID = 999,
}
setMythicPlus(502, true)
state.specIndex = 1; syncSpec()
state.assignedRole = "DAMAGER"
tick(0.6)
assert(state.specID == 64, "role protection allowed DPS -> Tank switch while assigned DPS")
assert(state.lootSpecID == 999, "role protection incorrectly blocked a Tank loot specialization override")
local mismatchStatus = addon:GetStatusState()
assert(string.lower(mismatchStatus):find("role", 1, true) or string.lower(mismatchStatus):find("papel", 1, true), "role mismatch is not visible in status")

-- Leaving the group removes role protection even though the content context is
-- still Mythic+. This is the solo legacy/manual-entry case: DPS -> Tank must be
-- allowed because there is no group role to protect. GROUP_ROSTER_UPDATE should
-- immediately reevaluate the previously blocked rule.
state.grouped = false
state.assignedRole = "DAMAGER"
event("GROUP_ROSTER_UPDATE")
assert(state.specID == 999, "solo player was incorrectly blocked from a DPS -> Tank specialization switch")
local soloRoleState = addon:GetRoleProtectionState(999, "mythicplus", 64)
assert(soloRoleState.protected == false and soloRoleState.mismatch == false, "solo role protection state remained active")

-- Once grouped again with the actual group role set to Tank, the same rule is
-- also compatible and PLAYER_ROLES_ASSIGNED must cause reevaluation.
state.specIndex = 1; syncSpec()
state.grouped = true
state.assignedRole = "TANK"
event("PLAYER_ROLES_ASSIGNED")
assert(state.specID == 999, "compatible Tank role did not allow Tank specialization switch")

-- World is intentionally unrestricted, even when the group role token says DPS.
setWorld()
state.assignedRole = "DAMAGER"
LoadoutPilotDB.specBindings["world"] = {specID=999, name="Bulwark"}
addon:ApplyCurrentRules("smoke-world-cross-role", false)
assert(state.specID == 999, "World cross-role specialization switch was incorrectly blocked")
assert(state.lootSpecID == 64, "leaving the dungeon override did not restore the pre-override loot specialization")

-- Restore Frost before PvP regression checks.
LoadoutPilotDB.specBindings["world"] = {specID=64, name="Frost"}
addon:ApplyCurrentRules("smoke-world-restore", false)
assert(state.specID == 64, "failed to restore Frost after World role-safety test")
state.assignedRole = "DAMAGER"
state.grouped = true

-- A transient loot-spec failure is retried without blocking talents or gear.
setMythicPlus(500, false)
state.specIndex = 2; syncSpec() -- already on the dungeon's playing spec, isolate loot retry
state.lootSpecID = 64
state.lootSpecSetFailures = 1
tick(0.6)
assert(state.lootSpecID == 64, "loot spec failure mock did not preserve the old loot specialization")
tick(1.1)
assert(state.lootSpecID == 62, "pending loot specialization was not retried")
setWorld()
tick(0.6)
assert(state.lootSpecID == 64, "loot specialization was not restored after retry scenario")

-- Existing PvP -> World retry still works and does not remain stuck on Applying.
LoadoutPilotDB.specBindings["pvp"] = {specID=64, name="Frost"}
LoadoutPilotDB.talentBindings["64:pvp"] = {configID=101, name="Frost World"}
LoadoutPilotDB.equipmentBindings["64:pvp"] = {setID=1, name="World Gear"}
LoadoutPilotDB.specBindings["world"] = {specID=64, name="Frost"}
LoadoutPilotDB.talentBindings["64:world"] = {configID=203, name="Frost M+ Default"}
LoadoutPilotDB.equipmentBindings["64:world"] = {setID=2, name="PvE Default"}
state.inInstance = true
state.instanceType = "pvp"
state.instanceName = "Battleground"
state.challenge = false
state.slottedKeystone = false
state.activeChallengeMapID = nil
state.slottedChallengeMapID = nil
state.selectedTalentBySpec[64] = 101
state.equippedSet = 1
tick(0.6)
state.talentEditFailures = 1
state.talentSwitchFailures = 1
state.equipmentUseFailures = 1
setWorld()
tick(0.6)
tick(0.6)
tick(0.6)
assert(state.selectedTalentBySpec[64] == 203, "pending world talents were not retried after leaving pvp")
assert(state.equippedSet == 2, "pending world gear was not retried after leaving pvp")
addon:UpdateStatusWidget()
local hudStatus = _G.LoadoutPilotStatusWidget.gear.text or ""
assert(not hudStatus:find("Applying", 1, true) and not hudStatus:find("Aplicando", 1, true), "HUD remained stuck on Applying after PvP exit")

-- Dungeon catalog exposes one canonical record per dungeon. Seasonal Mythic+
-- dungeons and remembered regular dungeons must not duplicate the same instance.
local catalog = addon:GetDungeonCatalog()
local foundVoidscar, foundNormal, legacyMplusCount = false, false, 0
local voidscarCount = 0
for _, entry in ipairs(catalog) do
    if entry.key == "dungeon:10500" then foundVoidscar = true; voidscarCount = voidscarCount + 1 end
    if entry.key == "dungeon:777" then foundNormal = true end
    if tostring(entry.key):match("^mplus:") then legacyMplusCount = legacyMplusCount + 1 end
end
assert(foundVoidscar and voidscarCount == 1, "seasonal dungeon was not represented by one unified catalog entry")
assert(foundNormal, "remembered normal dungeon catalog entry missing")
assert(legacyMplusCount == 0, "catalog still exposes separate legacy Mythic+ dungeon entries")

-- v2 AUTO / NOTIFY / OFF behavior. NOTIFY must not change talents until Apply is confirmed.
setWorld()
state.specIndex = 1; syncSpec()
LoadoutPilotDB.specBindings["world"] = {specID=64, name="Frost"}
LoadoutPilotDB.talentBindings["64:world"] = {configID=101, name="Frost World"}
state.selectedTalentBySpec[64] = 203
state.equippedSet = 3
addon:SetAutomationMode("gear", "off", true)
addon:SetAutomationMode("talents", "notify", true)
addon:ApplyCurrentRules("smoke-notify", false)
assert(state.selectedTalentBySpec[64] == 203, "NOTIFY mode applied talents automatically")
assert(state.equippedSet == 3, "OFF gear changed while preparing a talent notification")
addon:UpdateNotification()
assert(_G.LoadoutPilotNotifyFrame:IsShown(), "NOTIFY mode did not show the reminder")
assert(_G.LoadoutPilotNotifyFrame.apply and _G.LoadoutPilotNotifyFrame.apply.scripts.OnClick, "NOTIFY Apply button missing")
_G.LoadoutPilotNotifyFrame.apply.scripts.OnClick()
assert(state.selectedTalentBySpec[64] == 101, "NOTIFY Apply did not apply the mapped talents")
assert(state.equippedSet == 3, "confirming a talent notification incorrectly applied OFF gear")
addon:SetAutomationMode("gear", "auto", true)
addon:SetAutomationMode("talents", "off", true)
state.selectedTalentBySpec[64] = 203
addon:ApplyCurrentRules("smoke-off", false)
assert(state.selectedTalentBySpec[64] == 203, "OFF mode still applied talents")
addon:SetAutomationMode("talents", "auto", true)
assert(state.selectedTalentBySpec[64] == 101, "returning talents to AUTO did not apply the rule")

-- Specialization NOTIFY must keep its confirmation when the forced rule resolves
-- against the target spec, and the confirmation must survive a temporary failed
-- switch so the normal retry loop can complete it.
setWorld()
state.specIndex = 1; syncSpec()
LoadoutPilotDB.specBindings["world"] = {specID=62, name="Arcane"}
LoadoutPilotDB.talentBindings["62:world"] = {configID=301, name="Arcane Default"}
addon:SetAutomationMode("talents", "off", true)
addon:SetAutomationMode("spec", "notify", true)
addon:ApplyCurrentRules("smoke-spec-notify", false)
assert(state.specID == 64, "Specialization NOTIFY changed spec before confirmation")
addon:UpdateNotification()
assert(_G.LoadoutPilotNotifyFrame:IsShown(), "Specialization NOTIFY did not show the reminder")
_G.LoadoutPilotNotifyFrame.apply.scripts.OnClick()
assert(state.specID == 62, "Specialization NOTIFY Apply did not switch to the mapped spec")
assert(not _G.LoadoutPilotNotifyFrame:IsShown(), "notification stayed visible after Apply was accepted")

state.specIndex = 1; syncSpec()
state.specSwitchFailures = 1
addon:ApplyCurrentRules("smoke-spec-notify-retry", false)
addon:UpdateNotification()
assert(_G.LoadoutPilotNotifyFrame:IsShown(), "Specialization NOTIFY retry scenario did not show the reminder")
_G.LoadoutPilotNotifyFrame.apply.scripts.OnClick()
assert(state.specID == 64, "specialization retry scenario unexpectedly succeeded on the forced failure")
tick(2.1)
assert(state.specID == 62, "Specialization NOTIFY confirmation was lost before pending retry")
addon:SetAutomationMode("spec", "auto", true)
addon:SetAutomationMode("talents", "auto", true)
LoadoutPilotDB.specBindings["world"] = {specID=64, name="Frost"}
state.specIndex = 1; syncSpec()

-- v2 raid-boss overrides: Midnight hides hostile unit identity inside instances,
-- so the boss catalog is loaded from Encounter Journal and the configured Loot
-- Spec activates from the public ENCOUNTER_START encounter ID.
setRaid("Coiled Citadel", 9000)
tick(0.6)
LoadoutPilotDB.specBindings["raid"] = {specID=64, name="Frost"}
LoadoutPilotDB.talentBindings["64:raid"] = {configID=101, name="Frost World"}
LoadoutPilotDB.equipmentBindings["64:raid"] = {setID=2, name="PvE Default"}
state.specIndex = 1; syncSpec()
state.selectedTalentBySpec[64] = 101
state.equippedSet = 2
state.lootSpecID = 64

-- Migrate an override created by an earlier 2.0 test build (NPC-keyed) onto
-- the stable DungeonEncounterID discovered from the Encounter Journal.
LoadoutPilotDB.raidBossOverrides["boss:20001"] = {
    npcID=20001, name="Ula'tek", raidName="Coiled Citadel", lootSpecID=999,
}
LoadoutPilotDB.knownRaidBosses["boss:20001"] = {
    npcID=20001, name="Ula'tek", raidName="Coiled Citadel", verified=true,
}
clearTarget()
local discovered = addon:DiscoverCurrentRaidBossesFromJournal()
assert(discovered == 2, "Encounter Journal did not load the current raid boss list")
local ula = addon:GetRaidBossCatalogEntry("encounter:30001")
local coiled = addon:GetRaidBossCatalogEntry("encounter:30002")
assert(ula and ula.name == "Ula'tek", "Encounter Journal boss was not keyed by encounter ID")
assert(coiled and coiled.name == "Coiled Altar", "second Encounter Journal boss was not discovered")
-- Legacy-map fallback: boss discovery still works when no useful UiMapID is
-- available by matching GetInstanceInfo() InstanceID across journal tiers.
state.uiMapID = nil
state.selectedJournalTier = 1
assert(addon:GetCurrentRaidJournalInstanceID() == 39000, "legacy raid journal fallback did not resolve by InstanceID")
assert(state.selectedJournalTier == 1, "legacy journal fallback did not restore the previous Encounter Journal tier")
state.uiMapID = raidJournal[9000].uiMapID
assert(LoadoutPilotDB.raidBossOverrides["encounter:30001"] and LoadoutPilotDB.raidBossOverrides["encounter:30001"].lootSpecID == 999, "legacy NPC-keyed boss override was not migrated")
assert(LoadoutPilotDB.raidBossOverrides["boss:20001"] == nil, "legacy NPC-keyed boss override was not removed after migration")

-- Configuring a boss before pull must not immediately change the playing setup.
addon:SetRaidBossLootSpec(coiled, 62)
assert(state.lootSpecID == 64, "configuring a future boss changed loot spec before encounter start")
assert(state.specID == 64 and state.selectedTalentBySpec[64] == 101 and state.equippedSet == 2, "configuring a boss affected the playing loadout")

-- Encounter start is the safe, public boss identity in Midnight.
event("ENCOUNTER_START", 30001, "Ula'tek", 16, 20)
assert(state.lootSpecID == 999, "ENCOUNTER_START did not apply configured boss loot spec")
assert(state.specID == 64, "boss encounter changed playing specialization")
assert(state.selectedTalentBySpec[64] == 101, "boss encounter changed talents")
assert(state.equippedSet == 2, "boss encounter changed equipment")
assert(LoadoutPilotDB.knownRaidBosses["encounter:30001"], "configured encounter boss was not remembered")

-- A second configured boss can use a different loot spec without touching the playing setup.
event("ENCOUNTER_START", 30002, "Coiled Altar", 16, 20)
assert(state.lootSpecID == 62, "second raid boss encounter did not apply its loot override")
assert(state.specID == 64 and state.selectedTalentBySpec[64] == 101 and state.equippedSet == 2, "boss-to-boss loot change affected the playing loadout")

-- Keep the boss loot spec through encounter end (bonus roll window), then restore on leaving raid.
event("ENCOUNTER_END", 30002, "Coiled Altar", 16, 20, 1)
assert(state.lootSpecID == 62, "encounter end restored loot spec too early for bonus rolls")
setWorld(); clearTarget(); tick(0.6)
assert(state.lootSpecID == 64, "leaving raid did not restore the loot spec active before boss overrides")

-- Loot-spec NOTIFY should ask at encounter start rather than apply until confirmed.
setRaid("Coiled Citadel", 9000)
tick(0.6)
state.lootSpecID = 64
addon:SetAutomationMode("lootSpec", "notify", true)
event("ENCOUNTER_START", 30002, "Coiled Altar", 16, 20)
assert(state.lootSpecID == 64, "Loot Spec NOTIFY applied automatically")
addon:UpdateNotification()
assert(_G.LoadoutPilotNotifyFrame:IsShown(), "boss Loot Spec NOTIFY did not show reminder")
_G.LoadoutPilotNotifyFrame.apply.scripts.OnClick()
assert(state.lootSpecID == 62, "boss Loot Spec NOTIFY Apply failed")
addon:SetAutomationMode("lootSpec", "auto", true)
setWorld(); clearTarget(); tick(0.6)
assert(state.lootSpecID == 64, "boss NOTIFY scenario did not restore original loot spec")

-- Explain/source output reports why each field was selected.
setMythicPlus(500, false)
local explanation = table.concat(addon:GetRuleExplanationLines(), "\n")
assert(explanation:find("Voidscar", 1, true), "explain output does not name the active dungeon")
assert(explanation:find("Dungeon override", 1, true) or explanation:find("Override da masmorra", 1, true), "explain output does not include rule source")

-- Export/import round trip carries rules, boss overrides, and automation modes.
addon:SetAutomationMode("gear", "notify", true)
local exported = addon:ExportConfiguration()
assert(exported:find("LP2|1|", 1, true) == 1, "export header missing")
assert(exported:find("BOSS|encounter:30001", 1, true), "raid boss override missing from export")
assert(exported:find("MODE|gear|notify", 1, true), "automation mode missing from export")
LoadoutPilotDB.raidBossOverrides = {}
LoadoutPilotDB.dungeonOverrides = {}
addon:SetAutomationMode("gear", "off", true)
local imported, importMessage = addon:ImportConfiguration(exported)
assert(imported == true, "configuration import failed: " .. tostring(importMessage))
assert(LoadoutPilotDB.raidBossOverrides["encounter:30001"] and LoadoutPilotDB.raidBossOverrides["encounter:30001"].lootSpecID == 999, "boss override was not restored by import")
assert(LoadoutPilotDB.dungeonOverrides["dungeon:10500"], "dungeon override was not restored by import")
assert(addon:GetAutomationMode("gear") == "notify", "automation mode was not restored by import")

-- Slash command surface for v2 features.
SlashCmdList.LOADOUTPILOT("mode gear auto")
assert(addon:GetAutomationMode("gear") == "auto", "/lpilot mode did not change automation mode")
SlashCmdList.LOADOUTPILOT("explain")
setRaid("Coiled Citadel", 9000)
tick(0.6)
SlashCmdList.LOADOUTPILOT("bosses")
assert(_G.LoadoutPilotRaidBossOverrideFrame:IsShown(), "/lpilot bosses did not open raid boss overrides")
local bossFrame = _G.LoadoutPilotRaidBossOverrideFrame
local currentRaidKey = addon:GetCurrentRaidCatalogKey()
assert(currentRaidKey and LoadoutPilotDB.selectedRaidBossRaidKey == currentRaidKey, "raid boss manager did not auto-select the current raid")
assert(_G.LoadoutPilotRaidPicker, "raid boss manager is missing the paged raid picker")
assert(_G.LoadoutPilotRaidBossSearchEditBox, "raid boss manager is missing boss search")

-- Saved raids remain browsable after leaving them, and filters scale the boss catalog.
LoadoutPilotDB.knownRaidBosses["encounter:39001"] = {
    encounterID = 39001, journalEncounterID = 49001, journalInstanceID = 39100, raidInstanceID = 9100,
    name = "Archive Keeper", raidName = "Archive Raid", verified = true,
}
LoadoutPilotDB.raidBossOverrides["encounter:39001"] = {
    encounterID = 39001, journalEncounterID = 49001, journalInstanceID = 39100, raidInstanceID = 9100,
    name = "Archive Keeper", raidName = "Archive Raid", lootSpecID = 62,
}
local raidCatalog = addon:GetRaidCatalog()
assert(#raidCatalog >= 2, "raid catalog did not retain multiple raids")
assert(raidCatalog[1].isCurrent == true, "current raid was not promoted to the top of the raid picker")
local archiveMatches = addon:GetFilteredRaidBossCatalog("all", false, "Archive Keeper")
assert(#archiveMatches == 1 and archiveMatches[1].name == "Archive Keeper", "boss-name search did not filter across saved raids")
local configuredArchive = addon:GetFilteredRaidBossCatalog("instance:9100", true, "")
assert(#configuredArchive == 1, "Configured only did not return the configured boss for the selected raid")
local configuredCount, totalCount = addon:GetRaidBossConfigurationCounts("instance:9100")
assert(configuredCount == 1 and totalCount == 1, "per-raid configured counter is incorrect")
local removedArchive = addon:ClearRaidBossOverridesForRaid("instance:9100")
assert(removedArchive == 1, "clear-this-raid did not remove the selected raid override")
assert(LoadoutPilotDB.knownRaidBosses["encounter:39001"], "clear-this-raid removed the boss catalog entry")
assert(LoadoutPilotDB.raidBossOverrides["encounter:30001"], "clear-this-raid removed an override from another raid")

-- Raid-boss pagination must not snap back to the selected boss page.
for i = 1, 20 do
    local key = "boss:" .. tostring(31000 + i)
    LoadoutPilotDB.knownRaidBosses[key] = {
        npcID = 31000 + i,
        name = string.format("Pagination Boss %02d", i),
        raidName = "Coiled Citadel",
        raidInstanceID = 9000,
        journalInstanceID = 39000,
        verified = true,
    }
end
clearTarget()
LoadoutPilotDB.selectedRaidBossRaidKey = currentRaidKey
local currentBossCatalog = addon:GetFilteredRaidBossCatalog(currentRaidKey, false, "")
assert(#currentBossCatalog >= 17, "raid boss pagination test did not create enough bosses in the selected raid")
LoadoutPilotDB.selectedRaidBossKey = currentBossCatalog[1].key
bossFrame.page = 1
bossFrame.ensureSelectedVisible = true
addon:UpdateRaidBossOverrideFrame()
assert(bossFrame.page == 1, "raid boss list did not start on selected boss page")
bossFrame.next.scripts.OnClick()
assert(bossFrame.page == 2, "raid boss Next pagination snapped back to selected boss page")
bossFrame.next.scripts.OnClick()
assert(bossFrame.page == 3, "raid boss Next pagination could not advance to third page")
bossFrame.prev.scripts.OnClick()
assert(bossFrame.page == 2, "raid boss Previous pagination did not move back one page")

SlashCmdList.LOADOUTPILOT("log")
assert(_G.LoadoutPilotTransferFrame:IsShown(), "/lpilot log did not open the event history window")
assert(_G.LoadoutPilotTransferScrollFrame, "event history window is missing its scroll frame")
assert(_G.LoadoutPilotTransferScrollFrame.scrollChild == _G.LoadoutPilotTransferEditBox, "event history edit box is not attached to the scroll frame")
assert((_G.LoadoutPilotTransferScrollFrame.verticalScroll or 0) >= 0, "event history scroll position was not initialized")
assert(#LoadoutPilotDB.eventLog > 0, "event history remained empty after runtime activity")

-- Routine reevaluation events must not flood the persistent history.
LoadoutPilotDB.eventLog = {}
for _ = 1, 12 do addon:ApplyCurrentRules("role-assigned", false) end
local applyRows = 0
local debugRows = 0
for _, row in ipairs(LoadoutPilotDB.eventLog) do
    if row.kind == "apply" then applyRows = applyRows + 1 end
    if row.kind == "debug" then debugRows = debugRows + 1 end
end
assert(applyRows == 0, "routine ApplyCurrentRules reevaluations leaked into event history")
assert(debugRows == 0, "debug rows were recorded while chat debug was disabled")
assert(#LoadoutPilotDB.eventLog <= 3, "routine role-assigned reevaluations produced noisy event history")

print("Smoke test passed: Loadout Pilot 2.0.1 regression coverage including completed-Delve reward-phase retention plus unified dungeon overrides, Encounter Journal raid-boss discovery and ENCOUNTER_START Loot Spec rules, AUTO/NOTIFY/OFF, role safety including solo cross-role switching, explainable rule sources, import/export, raid-first boss filtering/search/persistence, raid-boss catalog cleanup/pagination, compact event history, combat queues, loot restoration, and PvP exit recovery.")
