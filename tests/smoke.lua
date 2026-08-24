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

local state = {
    locale = "ptBR",
    specIndex = 1,
    specID = 64,
    specName = "Frost",
    selectedTalentBySpec = { [64] = 101, [62] = 301 },
    inDelve = false,
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
    lootSpecID = 0,
    lootSpecSetFailures = 0,
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
function GetSpecializationRoleByID(specID)
    for _, info in pairs(specs) do if info.id == specID then return info.role end end
    return nil
end
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
    IsChallengeModeActive = function() return state.challenge end,
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
function EJ_GetInstanceForMap(uiMapID)
    for _, ids in pairs(challengeDungeonIDs) do
        if ids.uiMapID == uiMapID then return ids.journalID end
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
    state.inInstance = false
    state.instanceType = "none"
    state.instanceName = "Open World"
    state.instanceID = 0
    state.challenge = false
    state.slottedKeystone = false
    state.activeChallengeMapID = nil
    state.slottedChallengeMapID = nil
end
local function setDungeon(name, instanceID)
    state.inDelve = false
    state.inInstance = true
    state.instanceType = "party"
    state.instanceName = name
    state.instanceID = instanceID
    state.challenge = false
    state.slottedKeystone = false
    state.activeChallengeMapID = nil
    state.slottedChallengeMapID = nil
end
local function setMythicPlus(mapID, active)
    state.inDelve = false
    state.inInstance = true
    state.instanceType = "party"
    state.instanceName = challengeMaps[mapID]
    state.instanceID = 10000 + mapID
    state.challenge = active == true
    state.slottedKeystone = active ~= true
    state.activeChallengeMapID = active == true and mapID or nil
    state.slottedChallengeMapID = active ~= true and mapID or nil
end

-- Load and initialize.
event("ADDON_LOADED", "LoadoutPilot")
event("PLAYER_LOGIN")
assert(type(LoadoutPilotDB) == "table", "DB not initialized")
assert(LoadoutPilotDB.schema == 4, "database schema was not migrated to 4")
assert(LoadoutPilotDB.dungeonOverrides["mplus:500"] == nil, "legacy Mythic+ override key was not removed")
assert(LoadoutPilotDB.dungeonOverrides["dungeon:10500"] and LoadoutPilotDB.dungeonOverrides["dungeon:10500"].lootSpecID == 62, "legacy Mythic+ override was not migrated to unified dungeon key")
assert(LoadoutPilotDB.selectedDungeonKey == "dungeon:10500", "selected legacy Mythic+ dungeon was not migrated")
assert(LoadoutPilotDB.autoSpec == true and LoadoutPilotDB.autoTalents == true and LoadoutPilotDB.autoGear == true, "auto defaults wrong")
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
LoadoutPilotDB.autoSpec = false
addon:ApplyCurrentRules("smoke-auto-spec-off", false)
assert(state.specID == 64, "autoSpec OFF still changed specialization")
local manualStatus = addon:GetStatusState()
assert(string.lower(manualStatus):find("manual", 1, true), "manual specialization requirement is not visible in status")
LoadoutPilotDB.autoSpec = true
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

-- Once the actual group role changes to Tank, the same rule becomes compatible
-- and PLAYER_ROLES_ASSIGNED must cause reevaluation.
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

print("Smoke test passed: v1.0 regression coverage plus unified Dungeon/Mythic+ overrides, legacy override migration, M0/M+ identity sharing, popup layering, loot-spec overrides/restoration/retry, role-safe playing-spec switching, inheritance, Spec -> Loot Spec -> Talents -> Gear sequencing, combat queue, and PvP exit restoration.")
