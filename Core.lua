local ADDON_NAME, LP = ...
local Data = LP.Data
local L = LP.L

local addon = CreateFrame("Frame")
LP.addon = addon

local DB
local mainFrame
local statusWidget
local minimapButton
local talentPicker
local gearPicker
local languagePicker
local specPicker
local dungeonOverrideFrame
local contextButtons = {}
local pollElapsed = 0
local lastContext
local lastDungeonKey
local updateScheduled = false
local pendingTalentKey
local pendingTalentTargetID
local pendingTalentSpecID
local pendingTalentInProgress = false
local pendingTalentWatchToken = 0
local pendingGearKey
local lastTalentError
local lastGearError
local talentRetryElapsed = 0
local gearRetryElapsed = 0
local pendingSpecID
local pendingSpecIndex
local pendingSpecRuleKey
local pendingSpecInProgress = false
local pendingSpecWatchToken = 0
local specRetryElapsed = 0
local lastSpecError
local lastRoleMismatchKey

local HUD_LAYOUT = {
    paddingLeft = 8,
    paddingRight = 10,
    paddingTop = 7,
    paddingBottom = 7,
    iconSize = 20,
    iconGap = 8,
    segmentGap = 12,
    minFrameWidth = 220,
    maxFrameWidth = 620,
    minFrameHeight = 34,
    lineGap = 4,
}

local DEFAULTS = {
    schema = 2,
    firstRun = true,
    selectedContext = "world",
    autoSpec = true,
    autoTalents = true,
    autoGear = true,
    chatMessages = true,
    debug = false,
    languageOverride = "auto",
    specBindings = {},
    talentBindings = {},
    equipmentBindings = {},
    dungeonOverrides = {},
    knownDungeons = {},
    selectedDungeonKey = nil,
    hud = {
        enabled = true,
        locked = false,
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = 170,
    },
    minimap = {
        hide = false,
        angle = 225,
    },
}

local function CopyDefaults(src, dst)
    if type(dst) ~= "table" then dst = {} end
    for key, value in pairs(src) do
        if type(value) == "table" then
            dst[key] = CopyDefaults(value, type(dst[key]) == "table" and dst[key] or {})
        elseif dst[key] == nil then
            dst[key] = value
        end
    end
    return dst
end

local function T(key, ...)
    return LP:T(key, ...)
end

local function NormalizeAddonLanguage(value)
    value = string.lower(tostring(value or "auto"))
    if value == "ptbr" or value == "pt" or value == "portuguese" or value == "portugues" then
        return "ptBR"
    end
    if value == "enus" or value == "engb" or value == "en" or value == "english" then
        return "enUS"
    end
    return "auto"
end

local function GetAddonLanguageLabel(value)
    value = NormalizeAddonLanguage(value)
    if value == "ptBR" then return T("LANGUAGE_PTBR") end
    if value == "enUS" then return T("LANGUAGE_EN") end
    return T("LANGUAGE_AUTO")
end

local function Print(message, force)
    if not force and DB and DB.chatMessages == false then return end
    DEFAULT_CHAT_FRAME:AddMessage("|cff52d1ffLoadout Pilot:|r " .. tostring(message))
end

local function Debug(message)
    if DB and DB.debug then
        Print("|cff999999[debug]|r " .. tostring(message), true)
    end
end

local function IsSecret(value)
    if not issecretvalue then return false end
    local ok, secret = pcall(issecretvalue, value)
    return ok and secret == true
end

local function AccessibleBoolean(value)
    if IsSecret(value) then return nil end
    if type(value) == "boolean" then return value end
    return nil
end

local function SafeBooleanCall(func, ...)
    if type(func) ~= "function" then return nil end
    local ok, value = pcall(func, ...)
    if not ok then return nil end
    return AccessibleBoolean(value)
end

local function Atan2(y, x)
    if math.atan2 then return math.atan2(y, x) end
    if x > 0 then return math.atan(y / x) end
    if x < 0 and y >= 0 then return math.atan(y / x) + math.pi end
    if x < 0 and y < 0 then return math.atan(y / x) - math.pi end
    if x == 0 and y > 0 then return math.pi / 2 end
    if x == 0 and y < 0 then return -math.pi / 2 end
    return 0
end

local function ApplyBackdrop(frame, alpha)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.025, 0.04, 0.055, alpha or 0.95)
    frame:SetBackdropBorderColor(0.18, 0.55, 0.68, 0.95)
end

local function CreateButton(parent, text, width, height)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width or 150, height or 24)
    ApplyBackdrop(button, 0.92)
    button:SetBackdropColor(0.04, 0.10, 0.13, 0.95)
    button:SetBackdropBorderColor(0.16, 0.45, 0.56, 1)
    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.text:SetPoint("CENTER")
    button.text:SetText(text or "")
    button:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.06, 0.18, 0.23, 0.98)
        self:SetBackdropBorderColor(0.30, 0.72, 0.88, 1)
    end)
    button:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.04, 0.10, 0.13, 0.95)
        self:SetBackdropBorderColor(0.16, 0.45, 0.56, 1)
    end)
    return button
end

local function ContextName(context)
    local key = Data.contextLabelKeys[context]
    return key and T(key) or tostring(context or T("UNKNOWN"))
end

local function BindingKey(specID, context)
    return tostring(specID or 0) .. ":" .. tostring(context or "world")
end

local function GetCurrentSpecIndex()
    if C_SpecializationInfo and C_SpecializationInfo.GetSpecialization then
        local ok, index = pcall(C_SpecializationInfo.GetSpecialization)
        if ok and type(index) == "number" and index > 0 then return index end
    end
    if GetSpecialization then
        local ok, index = pcall(GetSpecialization)
        if ok and type(index) == "number" and index > 0 then return index end
    end
    return nil
end

local function GetSpecInfoByIndex(index)
    if not index then return nil end
    if C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo then
        local ok, specID, specName, _, specIcon, role = pcall(C_SpecializationInfo.GetSpecializationInfo, index)
        if ok and type(specID) == "number" and specID > 0 then
            return specID, specName, specIcon, role
        end
    end
    if GetSpecializationInfo then
        local ok, specID, specName, _, specIcon, role = pcall(GetSpecializationInfo, index)
        if ok and type(specID) == "number" and specID > 0 then
            return specID, specName, specIcon, role
        end
    end
    return nil
end

function addon:GetSpecInfo()
    local specIndex = GetCurrentSpecIndex()
    if not specIndex then
        return nil, T("UNKNOWN"), nil, nil
    end
    local specID, specName, specIcon = GetSpecInfoByIndex(specIndex)
    return specID, specName or T("UNKNOWN"), specIcon, specIndex
end

function addon:GetPlayerClassInfo()
    local className, classFile, classID = UnitClass("player")
    return className or T("UNKNOWN"), classFile, classID
end

function addon:GetSpecList()
    local result = {}
    local _, _, classID = self:GetPlayerClassInfo()
    local count
    if C_SpecializationInfo and C_SpecializationInfo.GetNumSpecializationsForClassID and classID then
        local ok, value = pcall(C_SpecializationInfo.GetNumSpecializationsForClassID, classID)
        if ok then count = tonumber(value) end
    end
    if not count and GetNumSpecializations then
        local ok, value = pcall(GetNumSpecializations)
        if ok then count = tonumber(value) end
    end
    count = count or 0

    local currentIndex = GetCurrentSpecIndex()
    for index = 1, count do
        local specID, name, icon, role = GetSpecInfoByIndex(index)
        if specID then
            table.insert(result, {
                index = index,
                specID = specID,
                name = name or (T("SPEC_LABEL") .. " " .. tostring(index)),
                icon = icon,
                role = role,
                selected = currentIndex == index,
            })
        end
    end
    return result
end

function addon:GetSpecIndexByID(targetSpecID)
    targetSpecID = tonumber(targetSpecID)
    if not targetSpecID then return nil end
    for _, info in ipairs(self:GetSpecList()) do
        if info.specID == targetSpecID then return info.index, info end
    end
    return nil
end

function addon:GetSpecNameByID(targetSpecID)
    local _, info = self:GetSpecIndexByID(targetSpecID)
    return info and info.name or nil
end

local function NormalizeRoleToken(role)
    if role == nil or IsSecret(role) then return nil end
    if role == "DAMAGER" or role == "TANK" or role == "HEALER" then return role end
    return nil
end

function addon:GetRoleLabel(role)
    role = NormalizeRoleToken(role)
    if role == "DAMAGER" then return T("ROLE_DAMAGER") end
    if role == "TANK" then return T("ROLE_TANK") end
    if role == "HEALER" then return T("ROLE_HEALER") end
    return T("ROLE_UNKNOWN")
end

function addon:GetSpecRoleByID(targetSpecID)
    targetSpecID = tonumber(targetSpecID)
    if not targetSpecID then return nil end

    if GetSpecializationRoleByID then
        local ok, role = pcall(GetSpecializationRoleByID, targetSpecID)
        if ok then
            role = NormalizeRoleToken(role)
            if role then return role end
        end
    end

    local _, info = self:GetSpecIndexByID(targetSpecID)
    return info and NormalizeRoleToken(info.role) or nil
end

function addon:GetSpecDisplayName(targetSpecID)
    local name = self:GetSpecNameByID(targetSpecID) or T("UNKNOWN")
    local role = self:GetSpecRoleByID(targetSpecID)
    if role then
        return string.format("%s (%s)", tostring(name), self:GetRoleLabel(role))
    end
    return tostring(name)
end

function addon:GetAssignedGroupRole()
    if not UnitGroupRolesAssigned then return nil end
    local ok, role = pcall(UnitGroupRolesAssigned, "player")
    if not ok or IsSecret(role) then return nil end
    return NormalizeRoleToken(role)
end

function addon:IsRoleProtectionContext(context)
    return context == "dungeon" or context == "mythicplus" or context == "raid" or context == "pvp"
end

function addon:GetRoleProtectionState(targetSpecID, context, currentSpecID)
    currentSpecID = tonumber(currentSpecID) or select(1, self:GetSpecInfo())
    targetSpecID = tonumber(targetSpecID)

    local currentRole = self:GetSpecRoleByID(currentSpecID)
    local targetRole = self:GetSpecRoleByID(targetSpecID)
    local assignedRole = self:GetAssignedGroupRole()
    local protected = self:IsRoleProtectionContext(context)
    local expectedRole = assignedRole or currentRole
    local mismatch = protected and expectedRole and targetRole and expectedRole ~= targetRole or false

    return {
        protected = protected,
        assignedRole = assignedRole,
        currentRole = currentRole,
        targetRole = targetRole,
        expectedRole = expectedRole,
        mismatch = mismatch == true,
    }
end

function addon:ResolveSpecBinding(context)
    if not DB or type(DB.specBindings) ~= "table" then return nil end
    local binding = DB.specBindings[context]
    if type(binding) ~= "table" or not binding.specID then return nil end
    local index, info = self:GetSpecIndexByID(binding.specID)
    if not index then return binding end
    binding.name = info.name
    binding.index = index
    return binding
end

function addon:GetConfiguredSpecID(context)
    local binding = self:ResolveSpecBinding(context)
    if binding and binding.specID then return binding.specID end
    return select(1, self:GetSpecInfo())
end

function addon:DetectContext()
    if C_PartyInfo and C_PartyInfo.IsDelveInProgress then
        local inDelve = SafeBooleanCall(C_PartyInfo.IsDelveInProgress)
        if inDelve == true then
            return "delve"
        end
    end

    local inInstance, instanceType = IsInInstance()
    if inInstance then
        if instanceType == "arena" or instanceType == "pvp" then
            return "pvp"
        end
        if instanceType == "raid" then
            return "raid"
        end
        if instanceType == "party" then
            local challengeActive
            if C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive then
                challengeActive = SafeBooleanCall(C_ChallengeMode.IsChallengeModeActive)
            elseif C_PartyInfo and C_PartyInfo.IsChallengeModeActive then
                -- Compatibility fallback for clients exposing the older helper here.
                challengeActive = SafeBooleanCall(C_PartyInfo.IsChallengeModeActive)
            end

            local keystoneSlotted
            if C_ChallengeMode and C_ChallengeMode.HasSlottedKeystone then
                keystoneSlotted = SafeBooleanCall(C_ChallengeMode.HasSlottedKeystone)
            end

            -- A slotted keystone is treated as Mythic+ before the timer starts so
            -- the mapped loadout can be applied while the player can still edit it.
            if challengeActive == true or keystoneSlotted == true then
                return "mythicplus"
            end
            return "dungeon"
        end
    end

    return "world"
end

function addon:GetMythicPlusMapID()
    if not C_ChallengeMode then return nil end

    if C_ChallengeMode.GetActiveChallengeMapID then
        local ok, mapID = pcall(C_ChallengeMode.GetActiveChallengeMapID)
        if ok and type(mapID) == "number" and mapID > 0 then return mapID end
    end

    if C_ChallengeMode.GetSlottedKeystoneInfo then
        local ok, mapID = pcall(C_ChallengeMode.GetSlottedKeystoneInfo)
        if ok and type(mapID) == "number" and mapID > 0 then return mapID end
    end

    return nil
end

function addon:FindChallengeMapIDByName(instanceName)
    if not instanceName or not C_ChallengeMode or not C_ChallengeMode.GetMapTable or not C_ChallengeMode.GetMapUIInfo then
        return nil
    end
    local ok, ids = pcall(C_ChallengeMode.GetMapTable)
    if not ok or type(ids) ~= "table" then return nil end
    for _, challengeMapID in ipairs(ids) do
        local okInfo, name = pcall(C_ChallengeMode.GetMapUIInfo, challengeMapID)
        if okInfo and name == instanceName then return challengeMapID end
    end
    return nil
end

function addon:GetCurrentDungeonInfo()
    local context = self:DetectContext()
    if context ~= "dungeon" and context ~= "mythicplus" then return nil end
    if not GetInstanceInfo then return nil end

    local ok, name, instanceType, difficultyID, difficultyName, _, _, _, instanceID = pcall(GetInstanceInfo)
    if not ok or instanceType ~= "party" then return nil end

    if context == "mythicplus" then
        local challengeMapID = self:GetMythicPlusMapID() or self:FindChallengeMapIDByName(name)
        if challengeMapID then
            local displayName = name
            if C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
                local okInfo, mapName = pcall(C_ChallengeMode.GetMapUIInfo, challengeMapID)
                if okInfo and mapName then displayName = mapName end
            end
            return {
                key = "mplus:" .. tostring(challengeMapID),
                name = displayName or T("UNKNOWN"),
                context = "mythicplus",
                challengeMapID = challengeMapID,
                instanceID = tonumber(instanceID),
                difficultyID = tonumber(difficultyID),
                difficultyName = difficultyName,
            }
        end
    end

    instanceID = tonumber(instanceID)
    if not instanceID or instanceID <= 0 then return nil end
    if DB and type(DB.knownDungeons) == "table" then
        DB.knownDungeons[tostring(instanceID)] = name or T("UNKNOWN")
    end
    return {
        key = "dungeon:" .. tostring(instanceID),
        name = name or T("UNKNOWN"),
        context = "dungeon",
        instanceID = instanceID,
        difficultyID = tonumber(difficultyID),
        difficultyName = difficultyName,
    }
end

function addon:GetDungeonCatalog()
    local result, seen = {}, {}
    local function add(entry)
        if not entry or not entry.key or seen[entry.key] then return end
        seen[entry.key] = true
        table.insert(result, entry)
    end

    if C_ChallengeMode and C_ChallengeMode.GetMapTable and C_ChallengeMode.GetMapUIInfo then
        local ok, ids = pcall(C_ChallengeMode.GetMapTable)
        if ok and type(ids) == "table" then
            for _, challengeMapID in ipairs(ids) do
                local okInfo, name, returnedID = pcall(C_ChallengeMode.GetMapUIInfo, challengeMapID)
                if okInfo and name then
                    local id = tonumber(returnedID) or tonumber(challengeMapID)
                    add({
                        key = "mplus:" .. tostring(id),
                        name = name,
                        context = "mythicplus",
                        challengeMapID = id,
                    })
                end
            end
        end
    end

    if DB and type(DB.knownDungeons) == "table" then
        for rawID, name in pairs(DB.knownDungeons) do
            local instanceID = tonumber(rawID)
            if instanceID and instanceID > 0 then
                add({
                    key = "dungeon:" .. tostring(instanceID),
                    name = name or (T("CONTEXT_DUNGEON") .. " " .. tostring(instanceID)),
                    context = "dungeon",
                    instanceID = instanceID,
                })
            end
        end
    end

    local current = self:GetCurrentDungeonInfo()
    if current then add(current) end

    table.sort(result, function(a, b)
        if a.context ~= b.context then return a.context == "mythicplus" end
        return string.lower(tostring(a.name)) < string.lower(tostring(b.name))
    end)
    return result
end

function addon:GetDungeonCatalogEntry(key)
    if not key then return nil end
    for _, entry in ipairs(self:GetDungeonCatalog()) do
        if entry.key == key then return entry end
    end
    return nil
end

function addon:GetDungeonOverride(key)
    if not DB or type(DB.dungeonOverrides) ~= "table" or not key then return nil end
    local value = DB.dungeonOverrides[key]
    return type(value) == "table" and value or nil
end

function addon:EnsureDungeonOverride(entry)
    if not DB or not entry or not entry.key then return nil end
    DB.dungeonOverrides = type(DB.dungeonOverrides) == "table" and DB.dungeonOverrides or {}
    local override = DB.dungeonOverrides[entry.key]
    if type(override) ~= "table" then
        override = {}
        DB.dungeonOverrides[entry.key] = override
    end
    override.name = entry.name
    override.context = entry.context
    override.challengeMapID = entry.challengeMapID
    override.instanceID = entry.instanceID
    return override
end

function addon:GetTalentList(specID)
    local result = {}
    if not specID or not C_ClassTalents or not C_ClassTalents.GetConfigIDsBySpecID then
        return result
    end
    if not C_Traits or not C_Traits.GetConfigInfo then
        return result
    end

    local ok, ids = pcall(C_ClassTalents.GetConfigIDsBySpecID, specID)
    if not ok or type(ids) ~= "table" then return result end

    local selectedID = self:GetSelectedTalentConfigID(specID)
    for _, configID in ipairs(ids) do
        local okInfo, info = pcall(C_Traits.GetConfigInfo, configID)
        if okInfo and type(info) == "table" then
            table.insert(result, {
                configID = configID,
                name = info.name or ("Loadout " .. tostring(configID)),
                selected = selectedID == configID,
            })
        end
    end

    table.sort(result, function(a, b)
        return string.lower(tostring(a.name)) < string.lower(tostring(b.name))
    end)
    return result
end

function addon:GetSelectedTalentConfigID(specID)
    specID = specID or select(1, self:GetSpecInfo())

    -- Saved loadout IDs are different from the live working ActiveConfig ID.
    -- Prefer Blizzard's saved-loadout selection so we compare like-for-like IDs.
    if C_ClassTalents and C_ClassTalents.GetLastSelectedSavedConfigID and specID then
        local ok, selectedID = pcall(C_ClassTalents.GetLastSelectedSavedConfigID, specID)
        if ok and type(selectedID) == "number" and selectedID > 0 then
            return selectedID
        end
    end

    -- Best-effort fallback when the Blizzard Talent UI is already loaded.
    local talentsFrame = PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame
    local loadSystem = talentsFrame and talentsFrame.LoadSystem
    if loadSystem and type(loadSystem.GetSelectionID) == "function" then
        local ok, selectedID = pcall(loadSystem.GetSelectionID, loadSystem)
        if ok and type(selectedID) == "number" and selectedID > 0 then
            return selectedID
        end
    end

    return nil
end

function addon:GetTalentName(configID)
    if not configID or not C_Traits or not C_Traits.GetConfigInfo then return nil end
    local ok, info = pcall(C_Traits.GetConfigInfo, configID)
    if ok and type(info) == "table" then return info.name end
    return nil
end

function addon:FindTalentByName(specID, name)
    if not name then return nil end
    for _, entry in ipairs(self:GetTalentList(specID)) do
        if entry.name == name then return entry.configID, entry.name end
    end
    return nil
end

function addon:ResolveTalentBinding(specID, context)
    local key = BindingKey(specID, context)
    local binding = DB.talentBindings[key]
    if type(binding) ~= "table" then return nil end

    local name = self:GetTalentName(binding.configID)
    if name then
        binding.name = name
        return binding
    end

    if binding.name then
        local repairedID, repairedName = self:FindTalentByName(specID, binding.name)
        if repairedID then
            binding.configID = repairedID
            binding.name = repairedName
            return binding
        end
    end
    return binding
end

function addon:GetEquipmentSetInfo(setID)
    if not setID or not C_EquipmentSet or not C_EquipmentSet.GetEquipmentSetInfo then return nil end
    local ok, name, iconFileID, returnedID, isEquipped, numItems, numEquipped, numInInventory, numLost, numIgnored = pcall(C_EquipmentSet.GetEquipmentSetInfo, setID)
    if not ok or not name then return nil end
    return {
        setID = returnedID or setID,
        name = name,
        icon = iconFileID,
        isEquipped = AccessibleBoolean(isEquipped) == true,
        numItems = tonumber(numItems) or 0,
        numEquipped = tonumber(numEquipped) or 0,
        numInInventory = tonumber(numInInventory) or 0,
        numLost = tonumber(numLost) or 0,
        numIgnored = tonumber(numIgnored) or 0,
    }
end

function addon:GetEquipmentList()
    local result = {}
    if not C_EquipmentSet or not C_EquipmentSet.GetEquipmentSetIDs then return result end
    local ok, ids = pcall(C_EquipmentSet.GetEquipmentSetIDs)
    if not ok or type(ids) ~= "table" then return result end
    for _, setID in ipairs(ids) do
        local info = self:GetEquipmentSetInfo(setID)
        if info then table.insert(result, info) end
    end
    table.sort(result, function(a, b)
        return string.lower(tostring(a.name)) < string.lower(tostring(b.name))
    end)
    return result
end

function addon:FindEquipmentByName(name)
    if not name then return nil end
    if C_EquipmentSet and C_EquipmentSet.GetEquipmentSetID then
        local ok, setID = pcall(C_EquipmentSet.GetEquipmentSetID, name)
        if ok and type(setID) == "number" then return setID end
    end
    for _, info in ipairs(self:GetEquipmentList()) do
        if info.name == name then return info.setID end
    end
    return nil
end

function addon:ResolveEquipmentBinding(specID, context)
    local key = BindingKey(specID, context)
    local binding = DB.equipmentBindings[key]
    if type(binding) ~= "table" then return nil, nil end

    local info = self:GetEquipmentSetInfo(binding.setID)
    if not info and binding.name then
        local repairedID = self:FindEquipmentByName(binding.name)
        if repairedID then
            binding.setID = repairedID
            info = self:GetEquipmentSetInfo(repairedID)
        end
    end
    if info then binding.name = info.name end
    return binding, info
end

function addon:ResolveTalentRecord(specID, record)
    if type(record) ~= "table" or not record.configID then return nil end
    if record.specID and tonumber(record.specID) ~= tonumber(specID) then return nil end

    local name = self:GetTalentName(record.configID)
    if name then
        record.name = name
        record.specID = specID
        return record
    end

    if record.name then
        local repairedID, repairedName = self:FindTalentByName(specID, record.name)
        if repairedID then
            record.configID = repairedID
            record.name = repairedName
            record.specID = specID
            return record
        end
    end
    return record
end

function addon:ResolveEquipmentRecord(record)
    if type(record) ~= "table" or not record.setID then return nil, nil end
    local info = self:GetEquipmentSetInfo(record.setID)
    if not info and record.name then
        local repairedID = self:FindEquipmentByName(record.name)
        if repairedID then
            record.setID = repairedID
            info = self:GetEquipmentSetInfo(repairedID)
        end
    end
    if info then record.name = info.name end
    return record, info
end

function addon:ResolveRuntimeRule(userInitiated)
    local currentSpecID, currentSpecName = self:GetSpecInfo()
    local context = self:DetectContext()
    local dungeonInfo = self:GetCurrentDungeonInfo()
    local override = dungeonInfo and self:GetDungeonOverride(dungeonInfo.key) or nil
    local baseSpecBinding = self:ResolveSpecBinding(context)

    local baseConfiguredSpecID = currentSpecID
    if baseSpecBinding and baseSpecBinding.specID then baseConfiguredSpecID = baseSpecBinding.specID end

    local configuredSpecID = baseConfiguredSpecID
    if override and override.specID then configuredSpecID = override.specID end

    local shouldAutomateSpec = DB and (DB.autoSpec or userInitiated == true)
    local runtimeSpecID = configuredSpecID
    if configuredSpecID ~= currentSpecID and not shouldAutomateSpec then
        runtimeSpecID = currentSpecID
    end

    local talentBinding
    if override and override.talent then
        talentBinding = self:ResolveTalentRecord(runtimeSpecID, override.talent)
    end
    if not talentBinding then
        talentBinding = self:ResolveTalentBinding(runtimeSpecID, context)
    end

    local gearBinding, gearInfo
    if override and override.equipment then
        gearBinding, gearInfo = self:ResolveEquipmentRecord(override.equipment)
    end
    if not gearBinding then
        gearBinding, gearInfo = self:ResolveEquipmentBinding(runtimeSpecID, context)
    end
    -- Equipment sets are not specialization-specific. If a dungeon override
    -- changes specialization but leaves Equipment on Inherit, allow the base
    -- context's equipment mapping to remain the inherited default.
    if not gearBinding and baseConfiguredSpecID and baseConfiguredSpecID ~= runtimeSpecID then
        gearBinding, gearInfo = self:ResolveEquipmentBinding(baseConfiguredSpecID, context)
    end

    local sourceKey = dungeonInfo and override and dungeonInfo.key or ("context:" .. tostring(context))
    return {
        currentSpecID = currentSpecID,
        currentSpecName = currentSpecName,
        context = context,
        dungeonInfo = dungeonInfo,
        override = override,
        configuredSpecID = configuredSpecID,
        runtimeSpecID = runtimeSpecID,
        shouldAutomateSpec = shouldAutomateSpec == true,
        talentBinding = talentBinding,
        gearBinding = gearBinding,
        gearInfo = gearInfo,
        roleState = self:GetRoleProtectionState(configuredSpecID, context, currentSpecID),
        ruleKey = sourceKey .. ":" .. tostring(runtimeSpecID or 0),
    }
end

function addon:GetDungeonOverrideEffectiveSpecID(entry)
    if not entry then return select(1, self:GetSpecInfo()) end
    local override = self:GetDungeonOverride(entry.key)
    if override and override.specID then return override.specID end
    local base = self:ResolveSpecBinding(entry.context)
    if base and base.specID then return base.specID end
    return select(1, self:GetSpecInfo())
end

function addon:GetLoadoutIndexByConfigID(specID, targetID)
    if not C_ClassTalents or not C_ClassTalents.GetConfigIDsBySpecID then return nil end
    local ok, ids = pcall(C_ClassTalents.GetConfigIDsBySpecID, specID)
    if not ok or type(ids) ~= "table" then return nil end
    for index, configID in ipairs(ids) do
        if configID == targetID then return index end
    end
    return nil
end

function addon:RememberTalentSelection(specID, configID)
    if not C_ClassTalents or not C_ClassTalents.UpdateLastSelectedSavedConfigID then return end
    pcall(C_ClassTalents.UpdateLastSelectedSavedConfigID, specID, configID)
end

function addon:ClearPendingSpecSwitch()
    pendingSpecID = nil
    pendingSpecIndex = nil
    pendingSpecRuleKey = nil
    pendingSpecInProgress = false
    pendingSpecWatchToken = pendingSpecWatchToken + 1
    specRetryElapsed = 0
    lastSpecError = nil
end

function addon:StartPendingSpecWatch(expectedSpecID, attemptsRemaining)
    if not expectedSpecID or not C_Timer or not C_Timer.After then return end
    attemptsRemaining = attemptsRemaining or 12
    local token = pendingSpecWatchToken
    C_Timer.After(0.75, function()
        if not DB or token ~= pendingSpecWatchToken or not pendingSpecID then return end
        local currentSpecID = select(1, addon:GetSpecInfo())
        if currentSpecID == expectedSpecID then
            local name = addon:GetSpecNameByID(expectedSpecID) or T("UNKNOWN")
            addon:ClearPendingSpecSwitch()
            Print(T("SPEC_SWITCHED", name))
            addon:ApplyCurrentRules("spec-watch-complete", false)
            return
        end
        if attemptsRemaining > 1 then
            addon:StartPendingSpecWatch(expectedSpecID, attemptsRemaining - 1)
            return
        end
        pendingSpecInProgress = false
        specRetryElapsed = 2.0
        lastSpecError = T("SPEC_FAILED")
        addon:ScheduleUpdate()
    end)
end

function addon:TrySwitchSpecialization(reason, userInitiated)
    local rule = self:ResolveRuntimeRule(userInitiated)
    local targetSpecID = rule and rule.configuredSpecID
    local currentSpecID = rule and rule.currentSpecID

    if not targetSpecID or not currentSpecID or targetSpecID == currentSpecID then
        self:ClearPendingSpecSwitch()
        return true
    end

    if not DB.autoSpec and not userInitiated then
        self:ClearPendingSpecSwitch()
        return true
    end

    local roleState = rule.roleState or self:GetRoleProtectionState(targetSpecID, rule.context, currentSpecID)
    if roleState and roleState.mismatch then
        self:ClearPendingSpecSwitch()
        local expectedLabel = self:GetRoleLabel(roleState.expectedRole)
        local targetLabel = self:GetRoleLabel(roleState.targetRole)
        local targetName = self:GetSpecNameByID(targetSpecID) or T("UNKNOWN")
        local mismatchKey = tostring(rule.ruleKey) .. ":" .. tostring(roleState.expectedRole) .. ":" .. tostring(roleState.targetRole)
        if userInitiated or lastRoleMismatchKey ~= mismatchKey then
            Print(T("ROLE_MISMATCH_BLOCKED", expectedLabel, targetName, targetLabel), userInitiated == true)
            lastRoleMismatchKey = mismatchKey
        end
        return false
    end
    lastRoleMismatchKey = nil

    local specIndex, specInfo = self:GetSpecIndexByID(targetSpecID)
    if not specIndex then
        pendingSpecID = targetSpecID
        pendingSpecIndex = nil
        pendingSpecRuleKey = rule.ruleKey
        pendingSpecInProgress = false
        lastSpecError = T("MISSING_SPEC")
        return false
    end

    pendingSpecID = targetSpecID
    pendingSpecIndex = specIndex
    pendingSpecRuleKey = rule.ruleKey

    if InCombatLockdown and InCombatLockdown() then
        pendingSpecInProgress = false
        lastSpecError = T("QUEUED_COMBAT")
        return false
    end

    local ok, success
    if C_SpecializationInfo and C_SpecializationInfo.SetSpecialization then
        ok, success = pcall(C_SpecializationInfo.SetSpecialization, specIndex)
    elseif SetSpecialization then
        ok, success = pcall(SetSpecialization, specIndex)
        if ok and success == nil then success = true end
    end

    if ok and AccessibleBoolean(success) ~= false and success ~= false then
        pendingSpecInProgress = true
        pendingSpecWatchToken = pendingSpecWatchToken + 1
        specRetryElapsed = 0
        lastSpecError = nil
        Debug("Specialization switch requested to " .. tostring(specInfo and specInfo.name or targetSpecID) .. " by " .. tostring(reason))
        self:StartPendingSpecWatch(targetSpecID, 12)
        return false
    end

    pendingSpecInProgress = false
    lastSpecError = T("SPEC_FAILED")
    Debug("Specialization switch failed for reason " .. tostring(reason))
    return false
end

function addon:ClearPendingTalentSwitch()
    pendingTalentKey = nil
    pendingTalentTargetID = nil
    pendingTalentSpecID = nil
    pendingTalentInProgress = false
    pendingTalentWatchToken = pendingTalentWatchToken + 1
    talentRetryElapsed = 0
    lastTalentError = nil
end

function addon:CompletePendingTalentSwitch(updateSavedSelection)
    local specID = pendingTalentSpecID or select(1, self:GetSpecInfo())
    local targetID = pendingTalentTargetID
    local rule = self:ResolveRuntimeRule(false)
    local context = rule and rule.context or self:DetectContext()
    local binding = rule and rule.talentBinding or (specID and self:ResolveTalentBinding(specID, context) or nil)

    if updateSavedSelection and specID and targetID then
        self:RememberTalentSelection(specID, targetID)
    end

    self:ClearPendingTalentSwitch()
    if binding and binding.name then
        Print(T("TALENT_SWITCHED", binding.name, ContextName(context)))
    end
end

function addon:StartPendingTalentWatch(expectedConfigID, attemptsRemaining, forceLoadConfigOnTimeout)
    if not expectedConfigID or not C_Timer or not C_Timer.After then return end

    attemptsRemaining = attemptsRemaining or 10
    local token = pendingTalentWatchToken
    C_Timer.After(0.75, function()
        if not DB or token ~= pendingTalentWatchToken or not pendingTalentKey then return end

        local specID = pendingTalentSpecID or select(1, addon:GetSpecInfo())
        if specID and addon:GetSelectedTalentConfigID(specID) == expectedConfigID then
            addon:CompletePendingTalentSwitch(false)
            addon:ScheduleUpdate()
            return
        end

        if attemptsRemaining > 1 then
            addon:StartPendingTalentWatch(expectedConfigID, attemptsRemaining - 1, forceLoadConfigOnTimeout)
            return
        end

        -- The secure loadout delegate can accept a request during a PvP/world
        -- transition before the client is actually ready to apply it. If it never
        -- confirms, fall back once to LoadConfig; otherwise leave it pending so
        -- the normal out-of-combat retry loop can try again.
        pendingTalentInProgress = false
        talentRetryElapsed = 1.0
        if forceLoadConfigOnTimeout and (not InCombatLockdown or not InCombatLockdown()) then
            addon:TrySwitchTalents("talent-watch-fallback", false, true)
        else
            addon:ScheduleUpdate()
        end
    end)
end

function addon:TrySwitchTalents(reason, userInitiated, forceLoadConfig)
    if not DB.autoTalents and not userInitiated then return true end
    local rule = self:ResolveRuntimeRule(userInitiated)
    local specID = rule and rule.runtimeSpecID
    if not specID then return false end

    -- When specialization automation is active, talents must wait until the
    -- target specialization has actually become active.
    if rule.shouldAutomateSpec and rule.configuredSpecID ~= rule.currentSpecID then
        pendingTalentInProgress = false
        lastTalentError = T("WAITING_SPEC")
        return false
    end

    local context = rule.context
    local key = (rule.ruleKey or BindingKey(specID, context)) .. ":talent"
    local binding = rule.talentBinding
    if type(binding) ~= "table" or not binding.configID then
        self:ClearPendingTalentSwitch()
        return true
    end

    if self:GetSelectedTalentConfigID(specID) == binding.configID then
        self:ClearPendingTalentSwitch()
        return true
    end

    if pendingTalentKey ~= key or pendingTalentTargetID ~= binding.configID then
        pendingTalentWatchToken = pendingTalentWatchToken + 1
        pendingTalentInProgress = false
        talentRetryElapsed = 0
    end
    pendingTalentKey = key
    pendingTalentTargetID = binding.configID
    pendingTalentSpecID = specID

    if InCombatLockdown and InCombatLockdown() then
        pendingTalentInProgress = false
        lastTalentError = T("QUEUED_COMBAT")
        return false
    end

    if C_ClassTalents and C_ClassTalents.CanEditTalents then
        local okCan, canEdit, changeError = pcall(C_ClassTalents.CanEditTalents)
        canEdit = okCan and AccessibleBoolean(canEdit) or nil
        if canEdit == false then
            pendingTalentInProgress = false
            lastTalentError = (not IsSecret(changeError) and tostring(changeError or "")) or T("WAITING_TALENTS")
            if lastTalentError == "" then lastTalentError = T("WAITING_TALENTS") end
            return false
        end
    end

    if not forceLoadConfig and C_ClassTalents and C_ClassTalents.SwitchToLoadoutByIndex then
        local index = self:GetLoadoutIndexByConfigID(specID, binding.configID)
        if index then
            local okSwitch = pcall(C_ClassTalents.SwitchToLoadoutByIndex, index)
            if okSwitch then
                pendingTalentInProgress = true
                pendingTalentWatchToken = pendingTalentWatchToken + 1
                talentRetryElapsed = 0
                lastTalentError = nil
                Debug("SwitchToLoadoutByIndex requested by " .. tostring(reason))
                self:StartPendingTalentWatch(binding.configID, 10, true)
                return true
            end
        end
    end

    if C_ClassTalents and C_ClassTalents.LoadConfig then
        local ok, result, changeError = pcall(C_ClassTalents.LoadConfig, binding.configID, true)
        if ok then
            local errorValue = Enum and Enum.LoadConfigResult and Enum.LoadConfigResult.Error or 0
            local noChangesValue = Enum and Enum.LoadConfigResult and Enum.LoadConfigResult.NoChangesNecessary or 1
            local inProgressValue = Enum and Enum.LoadConfigResult and Enum.LoadConfigResult.LoadInProgress or 2
            local readyValue = Enum and Enum.LoadConfigResult and Enum.LoadConfigResult.Ready or 3

            if result == noChangesValue or result == readyValue then
                self:RememberTalentSelection(specID, binding.configID)
                self:CompletePendingTalentSwitch(false)
                return true
            elseif result == inProgressValue then
                pendingTalentInProgress = true
                pendingTalentWatchToken = pendingTalentWatchToken + 1
                talentRetryElapsed = 0
                lastTalentError = nil
                self:StartPendingTalentWatch(binding.configID, 10, false)
                return true
            elseif result == errorValue then
                pendingTalentInProgress = false
                if not IsSecret(changeError) and changeError then
                    lastTalentError = tostring(changeError)
                else
                    lastTalentError = T("TALENT_FAILED")
                end
                return false
            end
        end
    end

    pendingTalentInProgress = false
    lastTalentError = T("TALENT_FAILED")
    return false
end

function addon:TrySwitchEquipment(reason, userInitiated)
    if not DB.autoGear and not userInitiated then return true end
    local rule = self:ResolveRuntimeRule(userInitiated)
    local specID = rule and rule.runtimeSpecID
    if not specID then return false end

    if rule.shouldAutomateSpec and rule.configuredSpecID ~= rule.currentSpecID then
        lastGearError = T("WAITING_SPEC")
        return false
    end

    local key = (rule.ruleKey or BindingKey(specID, rule.context)) .. ":gear"
    local binding, info = rule.gearBinding, rule.gearInfo
    if type(binding) ~= "table" or not binding.setID then
        pendingGearKey = nil
        lastGearError = nil
        gearRetryElapsed = 0
        return true
    end

    if info and info.isEquipped then
        pendingGearKey = nil
        lastGearError = nil
        gearRetryElapsed = 0
        return true
    end

    pendingGearKey = key
    if InCombatLockdown and InCombatLockdown() then
        lastGearError = T("QUEUED_COMBAT")
        return false
    end

    if C_EquipmentSet and C_EquipmentSet.CanUseEquipmentSets then
        local canUse = SafeBooleanCall(C_EquipmentSet.CanUseEquipmentSets)
        if canUse == false then
            lastGearError = T("GEAR_FAILED")
            return false
        end
    end

    if C_EquipmentSet and C_EquipmentSet.UseEquipmentSet then
        local ok, equipped = pcall(C_EquipmentSet.UseEquipmentSet, binding.setID)
        if ok and AccessibleBoolean(equipped) == true then
            lastGearError = nil
            gearRetryElapsed = 0
            return true
        end
    end

    lastGearError = T("GEAR_FAILED")
    Debug("Equipment switch failed for reason " .. tostring(reason))
    return false
end

function addon:ApplyCurrentRules(reason, userInitiated)
    local specReady = self:TrySwitchSpecialization(reason or "apply", userInitiated == true)
    if not specReady then
        self:ScheduleUpdate()
        return
    end
    self:TrySwitchTalents(reason or "apply", userInitiated == true)
    self:TrySwitchEquipment(reason or "apply", userInitiated == true)
    self:ScheduleUpdate()
end

function addon:BindSpec(specID)
    local context = DB.selectedContext
    local index, info = self:GetSpecIndexByID(specID)
    if not index or not info then return end
    DB.specBindings[context] = { specID = specID, name = info.name }
    self:ClearPendingSpecSwitch()
    self:ClearPendingTalentSwitch()
    pendingGearKey = nil
    Print(T("SPEC_MAPPED", info.name, ContextName(context)), true)
    self:UpdateAll()
    if DB.autoSpec and context == self:DetectContext() then self:ApplyCurrentRules("spec-mapping", false) end
end

function addon:ClearSpecBinding()
    local context = DB.selectedContext
    DB.specBindings[context] = nil
    self:ClearPendingSpecSwitch()
    self:ClearPendingTalentSwitch()
    pendingGearKey = nil
    Print(T("SPEC_CLEARED", ContextName(context)), true)
    self:UpdateAll()
end

function addon:BindTalent(configID)
    local context = DB.selectedContext
    local specID = self:GetConfiguredSpecID(context)
    local specName = self:GetSpecNameByID(specID) or select(2, self:GetSpecInfo())
    if not specID then return end
    local name = self:GetTalentName(configID)
    if not name then return end
    DB.talentBindings[BindingKey(specID, context)] = { configID = configID, name = name }
    self:ClearPendingTalentSwitch()
    Print(T("TALENT_MAPPED", name, specName, ContextName(context)), true)
    self:UpdateAll()
    if DB.autoTalents and context == self:DetectContext() then self:ApplyCurrentRules("mapping", false) end
end

function addon:BindEquipment(setID)
    local context = DB.selectedContext
    local specID = self:GetConfiguredSpecID(context)
    local specName = self:GetSpecNameByID(specID) or select(2, self:GetSpecInfo())
    if not specID then return end
    local info = self:GetEquipmentSetInfo(setID)
    if not info then return end
    DB.equipmentBindings[BindingKey(specID, context)] = { setID = info.setID, name = info.name }
    pendingGearKey = nil
    gearRetryElapsed = 0
    Print(T("GEAR_MAPPED", info.name, specName, ContextName(context)), true)
    self:UpdateAll()
    if DB.autoGear and context == self:DetectContext() then self:ApplyCurrentRules("mapping", false) end
end

function addon:ClearTalentBinding()
    local context = DB.selectedContext
    local specID = self:GetConfiguredSpecID(context)
    local specName = self:GetSpecNameByID(specID) or select(2, self:GetSpecInfo())
    if not specID then return end
    DB.talentBindings[BindingKey(specID, context)] = nil
    self:ClearPendingTalentSwitch()
    Print(T("TALENT_CLEARED", specName, ContextName(context)), true)
    self:UpdateAll()
end

function addon:ClearEquipmentBinding()
    local context = DB.selectedContext
    local specID = self:GetConfiguredSpecID(context)
    local specName = self:GetSpecNameByID(specID) or select(2, self:GetSpecInfo())
    if not specID then return end
    DB.equipmentBindings[BindingKey(specID, context)] = nil
    pendingGearKey = nil
    gearRetryElapsed = 0
    lastGearError = nil
    Print(T("GEAR_CLEARED", specName, ContextName(context)), true)
    self:UpdateAll()
end

local function HidePickers()
    if talentPicker then talentPicker:Hide() end
    if gearPicker then gearPicker:Hide() end
    if specPicker then specPicker:Hide() end
    if languagePicker then languagePicker:Hide() end
end

local function CreatePicker(name, parent, width)
    local frame = CreateFrame("Frame", name, parent, "BackdropTemplate")
    frame:SetSize(width or 300, 260)
    frame:SetFrameStrata("DIALOG")
    ApplyBackdrop(frame, 0.99)
    frame.rows = {}
    frame:Hide()
    return frame
end

function addon:PopulateTalentPicker(specID, onSelect)
    if not talentPicker then return end
    specID = specID or select(1, self:GetSpecInfo())
    local list = self:GetTalentList(specID)
    for _, row in ipairs(talentPicker.rows) do row:Hide() end

    if #list == 0 then
        local row = talentPicker.rows[1] or CreateButton(talentPicker, T("NO_TALENTS"), 286, 28)
        talentPicker.rows[1] = row
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", talentPicker, "TOPLEFT", 7, -7)
        row.text:SetText(T("NO_TALENTS"))
        row:SetScript("OnClick", function() talentPicker:Hide() end)
        row:Show()
        talentPicker:SetHeight(42)
        return
    end

    local y = -7
    for index, entry in ipairs(list) do
        local row = talentPicker.rows[index] or CreateButton(talentPicker, "", 286, 26)
        talentPicker.rows[index] = row
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", talentPicker, "TOPLEFT", 7, y)
        row.text:SetText((entry.selected and "|cff66ff99* |r" or "") .. entry.name .. " (" .. addon:GetRoleLabel(entry.role) .. ")")
        row:SetScript("OnClick", function()
            talentPicker:Hide()
            if onSelect then onSelect(entry.configID, specID) else addon:BindTalent(entry.configID) end
        end)
        row:Show()
        y = y - 28
    end
    talentPicker:SetHeight(math.min(260, 14 + (#list * 28)))
end

function addon:PopulateGearPicker(onSelect)
    if not gearPicker then return end
    local list = self:GetEquipmentList()
    for _, row in ipairs(gearPicker.rows) do row:Hide() end

    if #list == 0 then
        local row = gearPicker.rows[1] or CreateButton(gearPicker, T("NO_GEAR"), 286, 28)
        gearPicker.rows[1] = row
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", gearPicker, "TOPLEFT", 7, -7)
        row.text:SetText(T("NO_GEAR"))
        row:SetScript("OnClick", function() gearPicker:Hide() end)
        row:Show()
        gearPicker:SetHeight(42)
        return
    end

    local y = -7
    for index, entry in ipairs(list) do
        local row = gearPicker.rows[index] or CreateButton(gearPicker, "", 286, 26)
        gearPicker.rows[index] = row
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", gearPicker, "TOPLEFT", 7, y)
        row.text:SetText((entry.isEquipped and "|cff66ff99* |r" or "") .. entry.name)
        row:SetScript("OnClick", function()
            gearPicker:Hide()
            if onSelect then onSelect(entry.setID) else addon:BindEquipment(entry.setID) end
        end)
        row:Show()
        y = y - 28
    end
    gearPicker:SetHeight(math.min(260, 14 + (#list * 28)))
end

function addon:PopulateSpecPicker(onSelect, includeInherit)
    if not specPicker then return end
    local list = self:GetSpecList()
    for _, row in ipairs(specPicker.rows) do row:Hide() end

    local rowIndex = 0
    local y = -7
    if includeInherit then
        rowIndex = rowIndex + 1
        local row = specPicker.rows[rowIndex] or CreateButton(specPicker, "", 286, 26)
        specPicker.rows[rowIndex] = row
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", specPicker, "TOPLEFT", 7, y)
        row.text:SetText(T("INHERIT_DEFAULT"))
        row:SetScript("OnClick", function()
            specPicker:Hide()
            if onSelect then onSelect(nil) end
        end)
        row:Show()
        y = y - 28
    end

    for _, entry in ipairs(list) do
        rowIndex = rowIndex + 1
        local row = specPicker.rows[rowIndex] or CreateButton(specPicker, "", 286, 26)
        specPicker.rows[rowIndex] = row
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", specPicker, "TOPLEFT", 7, y)
        row.text:SetText((entry.selected and "|cff66ff99* |r" or "") .. entry.name)
        row:SetScript("OnClick", function()
            specPicker:Hide()
            if onSelect then onSelect(entry.specID) else addon:BindSpec(entry.specID) end
        end)
        row:Show()
        y = y - 28
    end
    specPicker:SetHeight(math.min(260, 14 + (rowIndex * 28)))
end

function addon:ShowTalentPicker(anchor, specID, onSelect)
    if gearPicker then gearPicker:Hide() end
    if specPicker then specPicker:Hide() end
    self:PopulateTalentPicker(specID, onSelect)
    talentPicker:ClearAllPoints()
    talentPicker:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
    talentPicker:SetShown(not talentPicker:IsShown())
end

function addon:ShowGearPicker(anchor, onSelect)
    if talentPicker then talentPicker:Hide() end
    if specPicker then specPicker:Hide() end
    self:PopulateGearPicker(onSelect)
    gearPicker:ClearAllPoints()
    gearPicker:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
    gearPicker:SetShown(not gearPicker:IsShown())
end

function addon:ShowSpecPicker(anchor, onSelect, includeInherit)
    if talentPicker then talentPicker:Hide() end
    if gearPicker then gearPicker:Hide() end
    self:PopulateSpecPicker(onSelect, includeInherit)
    specPicker:ClearAllPoints()
    specPicker:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
    specPicker:SetShown(not specPicker:IsShown())
end

local function CreateLanguagePicker()
    local frame = CreateFrame("Frame", "LoadoutPilotLanguagePicker", UIParent, "BackdropTemplate")
    frame:SetSize(390, 230)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(1000)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    if frame.SetToplevel then frame:SetToplevel(true) end
    ApplyBackdrop(frame, 0.98)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -16)
    frame.title:SetText(T("ADDON_LANGUAGE"))
    frame.title:SetTextColor(0.55, 0.86, 1)

    frame.description = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.description:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -10)
    frame.description:SetWidth(350)
    frame.description:SetJustifyH("LEFT")
    frame.description:SetJustifyV("TOP")
    frame.description:SetText(T("LANGUAGE_DESCRIPTION"))

    frame.current = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.current:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -92)
    frame.current:SetWidth(350)
    frame.current:SetJustifyH("LEFT")

    local choices = {
        { value = "auto", labelKey = "LANGUAGE_AUTO" },
        { value = "ptBR", labelKey = "LANGUAGE_PTBR" },
        { value = "enUS", labelKey = "LANGUAGE_EN" },
    }
    frame.choiceButtons = {}
    for index, choice in ipairs(choices) do
        local button = CreateButton(frame, T(choice.labelKey), 110, 30)
        button:SetPoint("TOPLEFT", frame, "TOPLEFT", 16 + ((index - 1) * 118), -120)
        button.languageValue = choice.value
        button.languageLabelKey = choice.labelKey
        button:SetScript("OnClick", function(self)
            addon:SetLanguageOverride(self.languageValue)
        end)
        frame.choiceButtons[index] = button
    end

    frame.cancel = CreateButton(frame, T("CANCEL"), 120, 28)
    frame.cancel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 16)
    frame.cancel:SetScript("OnClick", function() frame:Hide() end)

    frame:SetScript("OnShow", function()
        addon:UpdateLanguagePicker()
    end)
    frame:Hide()
    return frame
end

local function CreateMainFrame()
    local frame = CreateFrame("Frame", "LoadoutPilotMainFrame", UIParent, "BackdropTemplate")
    frame:SetSize(650, 590)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    ApplyBackdrop(frame, 0.97)
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOPLEFT", 18, -16)
    frame.title:SetText(T("ADDON_TITLE"))
    frame.title:SetTextColor(0.45, 0.88, 1)

    frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.subtitle:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -3)
    frame.subtitle:SetText(T("ADDON_SUBTITLE"))

    frame.close = CreateButton(frame, "X", 28, 24)
    frame.close:SetPoint("TOPRIGHT", -12, -12)
    frame.close:SetScript("OnClick", function() HidePickers(); if dungeonOverrideFrame then dungeonOverrideFrame:Hide() end; frame:Hide() end)

    frame.languageButton = CreateButton(frame, "", 180, 24)
    frame.languageButton:SetPoint("TOPRIGHT", frame.close, "TOPLEFT", -8, 0)
    frame.languageButton:SetScript("OnClick", function() addon:ToggleLanguagePicker() end)

    frame.currentIcon = frame:CreateTexture(nil, "ARTWORK")
    frame.currentIcon:SetSize(42, 42)
    frame.currentIcon:SetPoint("TOPLEFT", 18, -62)
    frame.currentIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    frame.currentTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.currentTitle:SetPoint("TOPLEFT", frame.currentIcon, "TOPRIGHT", 10, -1)
    frame.currentTitle:SetWidth(520)
    frame.currentTitle:SetJustifyH("LEFT")

    frame.currentContext = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.currentContext:SetPoint("TOPLEFT", frame.currentTitle, "BOTTOMLEFT", 0, -5)
    frame.currentContext:SetWidth(520)
    frame.currentContext:SetJustifyH("LEFT")

    frame.configureLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.configureLabel:SetPoint("TOPLEFT", 18, -122)
    frame.configureLabel:SetText(T("CONFIGURE_FOR"))

    local x = 18
    for _, context in ipairs(Data.contextOrder) do
        local button = CreateButton(frame, ContextName(context), 96, 26)
        button:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -146)
        button.context = context
        button:SetScript("OnClick", function(self)
            DB.selectedContext = self.context
            HidePickers()
            addon:UpdateAll()
        end)
        contextButtons[context] = button
        x = x + 101
    end

    frame.specLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.specLabel:SetPoint("TOPLEFT", 18, -196)
    frame.specLabel:SetText(T("SPECIALIZATION"))

    frame.specValue = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.specValue:SetPoint("TOPLEFT", 18, -219)
    frame.specValue:SetWidth(600)
    frame.specValue:SetJustifyH("LEFT")

    frame.specChoose = CreateButton(frame, T("CHOOSE_SPEC"), 250, 26)
    frame.specChoose:SetPoint("TOPLEFT", 18, -244)
    frame.specChoose:SetScript("OnClick", function()
        addon:ShowSpecPicker(frame.specChoose, function(specID) addon:BindSpec(specID) end, false)
    end)

    frame.specClear = CreateButton(frame, T("CLEAR"), 84, 26)
    frame.specClear:SetPoint("LEFT", frame.specChoose, "RIGHT", 8, 0)
    frame.specClear:SetScript("OnClick", function() addon:ClearSpecBinding() end)

    frame.autoSpec = CreateButton(frame, "", 145, 26)
    frame.autoSpec:SetPoint("TOPLEFT", 373, -244)
    frame.autoSpec:SetScript("OnClick", function()
        DB.autoSpec = not DB.autoSpec
        addon:UpdateAll()
        if DB.autoSpec then addon:ApplyCurrentRules("toggle-spec", false) end
    end)

    frame.talentLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.talentLabel:SetPoint("TOPLEFT", 18, -286)
    frame.talentLabel:SetText(T("TALENT_LOADOUT"))

    frame.talentValue = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.talentValue:SetPoint("TOPLEFT", 18, -309)
    frame.talentValue:SetWidth(600)
    frame.talentValue:SetJustifyH("LEFT")

    frame.talentChoose = CreateButton(frame, T("CHOOSE_TALENT"), 250, 26)
    frame.talentChoose:SetPoint("TOPLEFT", 18, -334)
    frame.talentChoose:SetScript("OnClick", function()
        local specID = addon:GetConfiguredSpecID(DB.selectedContext)
        addon:ShowTalentPicker(frame.talentChoose, specID, function(configID) addon:BindTalent(configID) end)
    end)

    frame.talentClear = CreateButton(frame, T("CLEAR"), 84, 26)
    frame.talentClear:SetPoint("LEFT", frame.talentChoose, "RIGHT", 8, 0)
    frame.talentClear:SetScript("OnClick", function() addon:ClearTalentBinding() end)

    frame.autoTalents = CreateButton(frame, "", 145, 26)
    frame.autoTalents:SetPoint("TOPLEFT", 373, -334)
    frame.autoTalents:SetScript("OnClick", function()
        DB.autoTalents = not DB.autoTalents
        addon:UpdateAll()
        if DB.autoTalents then addon:ApplyCurrentRules("toggle", false) end
    end)

    frame.gearLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.gearLabel:SetPoint("TOPLEFT", 18, -376)
    frame.gearLabel:SetText(T("EQUIPMENT_SET"))

    frame.gearValue = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.gearValue:SetPoint("TOPLEFT", 18, -399)
    frame.gearValue:SetWidth(600)
    frame.gearValue:SetJustifyH("LEFT")

    frame.gearChoose = CreateButton(frame, T("CHOOSE_GEAR"), 250, 26)
    frame.gearChoose:SetPoint("TOPLEFT", 18, -424)
    frame.gearChoose:SetScript("OnClick", function()
        addon:ShowGearPicker(frame.gearChoose, function(setID) addon:BindEquipment(setID) end)
    end)

    frame.gearClear = CreateButton(frame, T("CLEAR"), 84, 26)
    frame.gearClear:SetPoint("LEFT", frame.gearChoose, "RIGHT", 8, 0)
    frame.gearClear:SetScript("OnClick", function() addon:ClearEquipmentBinding() end)

    frame.autoGear = CreateButton(frame, "", 145, 26)
    frame.autoGear:SetPoint("TOPLEFT", 373, -424)
    frame.autoGear:SetScript("OnClick", function()
        DB.autoGear = not DB.autoGear
        addon:UpdateAll()
        if DB.autoGear then addon:ApplyCurrentRules("toggle", false) end
    end)

    frame.hudToggle = CreateButton(frame, "", 145, 26)
    frame.hudToggle:SetPoint("TOPLEFT", 18, -468)
    frame.hudToggle:SetScript("OnClick", function()
        DB.hud.enabled = not DB.hud.enabled
        addon:UpdateAll()
    end)

    frame.hudLock = CreateButton(frame, "", 145, 26)
    frame.hudLock:SetPoint("LEFT", frame.hudToggle, "RIGHT", 8, 0)
    frame.hudLock:SetScript("OnClick", function()
        DB.hud.locked = not DB.hud.locked
        addon:UpdateAll()
    end)

    frame.minimapToggle = CreateButton(frame, "", 145, 26)
    frame.minimapToggle:SetPoint("LEFT", frame.hudLock, "RIGHT", 8, 0)
    frame.minimapToggle:SetScript("OnClick", function()
        DB.minimap.hide = not DB.minimap.hide
        addon:UpdateAll()
    end)

    frame.apply = CreateButton(frame, T("APPLY_NOW"), 160, 26)
    frame.apply:SetPoint("LEFT", frame.minimapToggle, "RIGHT", 8, 0)
    frame.apply:SetScript("OnClick", function() addon:ApplyCurrentRules("manual", true) end)

    frame.chatToggle = CreateButton(frame, "", 190, 26)
    frame.chatToggle:SetPoint("TOPLEFT", 18, -502)
    frame.chatToggle:SetScript("OnClick", function()
        DB.chatMessages = not DB.chatMessages
        addon:UpdateAll()
        Print(DB.chatMessages and T("CHAT_MESSAGES_ON_CONFIRM") or T("CHAT_MESSAGES_OFF_CONFIRM"), true)
    end)

    frame.dungeonOverrides = CreateButton(frame, T("DUNGEON_OVERRIDES"), 210, 26)
    frame.dungeonOverrides:SetPoint("LEFT", frame.chatToggle, "RIGHT", 8, 0)
    frame.dungeonOverrides:SetScript("OnClick", function() addon:ToggleDungeonOverrides() end)

    frame.resetPositions = CreateButton(frame, T("RESET_POSITIONS"), 190, 26)
    frame.resetPositions:SetPoint("LEFT", frame.dungeonOverrides, "RIGHT", 8, 0)
    frame.resetPositions:SetScript("OnClick", function() addon:ResetPositions() end)

    frame.version = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.version:SetPoint("BOTTOMRIGHT", -14, 10)
    frame.version:SetText(T("VERSION", Data.version))

    talentPicker = CreatePicker("LoadoutPilotTalentPicker", UIParent, 300)
    gearPicker = CreatePicker("LoadoutPilotGearPicker", UIParent, 300)
    specPicker = CreatePicker("LoadoutPilotSpecPicker", UIParent, 300)

    frame:Hide()
    return frame
end

local DUNGEON_PAGE_SIZE = 9

function addon:CleanupDungeonOverride(key)
    local override = self:GetDungeonOverride(key)
    if not override then return end
    if not override.specID and not override.talent and not override.equipment then
        DB.dungeonOverrides[key] = nil
    end
end

function addon:SetDungeonOverrideSpec(entry, specID)
    if not entry then return end

    -- A dungeon-specific specialization needs a stable context default to
    -- return to afterward. Existing 1.0 users do not have specialization
    -- mappings yet, so capture the current specialization the first time a
    -- dungeon spec override is configured for that context.
    if not self:ResolveSpecBinding(entry.context) then
        local currentSpecID, currentSpecName = self:GetSpecInfo()
        if currentSpecID then
            DB.specBindings[entry.context] = { specID = currentSpecID, name = currentSpecName }
            Print(T("BASE_SPEC_CAPTURED", currentSpecName, ContextName(entry.context)), true)
        end
    end

    local override = self:EnsureDungeonOverride(entry)
    local oldSpecID = override.specID
    override.specID = tonumber(specID)
    if oldSpecID ~= override.specID and override.talent then
        -- Talent loadouts belong to a specialization. Clearing this prevents a
        -- stale Frost loadout from being applied after changing an override to Unholy, etc.
        override.talent = nil
        Print(T("DUNGEON_TALENT_RESET_FOR_SPEC"), true)
    end
    self:CleanupDungeonOverride(entry.key)
    self:ClearPendingSpecSwitch()
    self:ClearPendingTalentSwitch()
    pendingGearKey = nil
    self:UpdateAll()
    self:UpdateDungeonOverrideFrame()
    local current = self:GetCurrentDungeonInfo()
    if current and current.key == entry.key then self:ApplyCurrentRules("dungeon-spec-override", false) end
end

function addon:SetDungeonOverrideTalent(entry, configID, specID)
    if not entry or not configID or not specID then return end
    local name = self:GetTalentName(configID)
    if not name then return end
    local override = self:EnsureDungeonOverride(entry)
    override.talent = { specID = specID, configID = configID, name = name }
    self:ClearPendingTalentSwitch()
    self:UpdateAll()
    self:UpdateDungeonOverrideFrame()
    local current = self:GetCurrentDungeonInfo()
    if current and current.key == entry.key then self:ApplyCurrentRules("dungeon-talent-override", false) end
end

function addon:SetDungeonOverrideEquipment(entry, setID)
    if not entry or not setID then return end
    local info = self:GetEquipmentSetInfo(setID)
    if not info then return end
    local override = self:EnsureDungeonOverride(entry)
    override.equipment = { setID = info.setID, name = info.name }
    pendingGearKey = nil
    self:UpdateAll()
    self:UpdateDungeonOverrideFrame()
    local current = self:GetCurrentDungeonInfo()
    if current and current.key == entry.key then self:ApplyCurrentRules("dungeon-gear-override", false) end
end

function addon:ClearDungeonOverrideField(entry, field)
    if not entry then return end
    local override = self:GetDungeonOverride(entry.key)
    if not override then return end
    override[field] = nil
    self:CleanupDungeonOverride(entry.key)
    if field == "specID" then self:ClearPendingSpecSwitch() end
    if field == "talent" or field == "specID" then self:ClearPendingTalentSwitch() end
    if field == "equipment" or field == "specID" then pendingGearKey = nil end
    self:UpdateAll()
    self:UpdateDungeonOverrideFrame()
    local current = self:GetCurrentDungeonInfo()
    if current and current.key == entry.key then self:ApplyCurrentRules("dungeon-override-cleared", false) end
end

function addon:RemoveDungeonOverride(entry)
    if not entry then return end
    DB.dungeonOverrides[entry.key] = nil
    self:ClearPendingSpecSwitch()
    self:ClearPendingTalentSwitch()
    pendingGearKey = nil
    self:UpdateAll()
    self:UpdateDungeonOverrideFrame()
    local current = self:GetCurrentDungeonInfo()
    if current and current.key == entry.key then self:ApplyCurrentRules("dungeon-override-removed", false) end
end

local function CreateDungeonOverrideFrame()
    local frame = CreateFrame("Frame", "LoadoutPilotDungeonOverrideFrame", UIParent, "BackdropTemplate")
    frame:SetSize(700, 500)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(900)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    ApplyBackdrop(frame, 0.985)
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOPLEFT", 18, -16)
    frame.title:SetText(T("DUNGEON_OVERRIDES"))
    frame.title:SetTextColor(0.45, 0.88, 1)

    frame.description = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.description:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -6)
    frame.description:SetWidth(650)
    frame.description:SetJustifyH("LEFT")
    frame.description:SetText(T("DUNGEON_OVERRIDES_DESCRIPTION"))

    frame.close = CreateButton(frame, "X", 28, 24)
    frame.close:SetPoint("TOPRIGHT", -12, -12)
    frame.close:SetScript("OnClick", function() HidePickers(); frame:Hide() end)

    frame.listLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.listLabel:SetPoint("TOPLEFT", 18, -82)
    frame.listLabel:SetText(T("DUNGEON_LIST"))

    frame.rows = {}
    for index = 1, DUNGEON_PAGE_SIZE do
        local row = CreateButton(frame, "", 250, 28)
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -106 - ((index - 1) * 31))
        row:SetScript("OnClick", function(self)
            if not self.dungeonKey then return end
            DB.selectedDungeonKey = self.dungeonKey
            HidePickers()
            addon:UpdateDungeonOverrideFrame()
        end)
        frame.rows[index] = row
    end

    frame.prev = CreateButton(frame, T("PREVIOUS"), 76, 26)
    frame.prev:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -392)
    frame.prev:SetScript("OnClick", function()
        frame.page = math.max(1, (frame.page or 1) - 1)
        addon:UpdateDungeonOverrideFrame()
    end)

    frame.pageText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.pageText:SetPoint("LEFT", frame.prev, "RIGHT", 8, 0)
    frame.pageText:SetWidth(72)
    frame.pageText:SetJustifyH("CENTER")

    frame.next = CreateButton(frame, T("NEXT"), 76, 26)
    frame.next:SetPoint("LEFT", frame.pageText, "RIGHT", 8, 0)
    frame.next:SetScript("OnClick", function()
        frame.page = (frame.page or 1) + 1
        addon:UpdateDungeonOverrideFrame()
    end)

    frame.currentDungeon = CreateButton(frame, T("USE_CURRENT_DUNGEON"), 250, 28)
    frame.currentDungeon:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -430)
    frame.currentDungeon:SetScript("OnClick", function()
        local current = addon:GetCurrentDungeonInfo()
        if current then
            DB.selectedDungeonKey = current.key
            frame.page = 1
            addon:UpdateDungeonOverrideFrame()
        else
            Print(T("NOT_IN_DUNGEON"), true)
        end
    end)

    local rightX = 294
    frame.selectedLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.selectedLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", rightX, -82)
    frame.selectedLabel:SetWidth(380)
    frame.selectedLabel:SetJustifyH("LEFT")

    frame.fallback = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.fallback:SetPoint("TOPLEFT", frame.selectedLabel, "BOTTOMLEFT", 0, -6)
    frame.fallback:SetWidth(380)
    frame.fallback:SetJustifyH("LEFT")

    frame.specLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.specLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", rightX, -142)
    frame.specLabel:SetText(T("SPECIALIZATION_OVERRIDE"))

    frame.specValue = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.specValue:SetPoint("TOPLEFT", frame, "TOPLEFT", rightX, -165)
    frame.specValue:SetWidth(380)
    frame.specValue:SetJustifyH("LEFT")

    frame.specChoose = CreateButton(frame, T("CHOOSE_SPEC_OVERRIDE"), 220, 26)
    frame.specChoose:SetPoint("TOPLEFT", frame, "TOPLEFT", rightX, -190)
    frame.specChoose:SetScript("OnClick", function()
        local entry = addon:GetDungeonCatalogEntry(DB.selectedDungeonKey)
        if not entry then return end
        addon:ShowSpecPicker(frame.specChoose, function(specID) addon:SetDungeonOverrideSpec(entry, specID) end, true)
    end)

    frame.specInherit = CreateButton(frame, T("INHERIT"), 100, 26)
    frame.specInherit:SetPoint("LEFT", frame.specChoose, "RIGHT", 8, 0)
    frame.specInherit:SetScript("OnClick", function()
        local entry = addon:GetDungeonCatalogEntry(DB.selectedDungeonKey)
        if entry then addon:ClearDungeonOverrideField(entry, "specID") end
    end)

    frame.talentLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.talentLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", rightX, -238)
    frame.talentLabel:SetText(T("TALENT_OVERRIDE"))

    frame.talentValue = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.talentValue:SetPoint("TOPLEFT", frame, "TOPLEFT", rightX, -261)
    frame.talentValue:SetWidth(380)
    frame.talentValue:SetJustifyH("LEFT")

    frame.talentChoose = CreateButton(frame, T("CHOOSE_TALENT_OVERRIDE"), 220, 26)
    frame.talentChoose:SetPoint("TOPLEFT", frame, "TOPLEFT", rightX, -286)
    frame.talentChoose:SetScript("OnClick", function()
        local entry = addon:GetDungeonCatalogEntry(DB.selectedDungeonKey)
        if not entry then return end
        local specID = addon:GetDungeonOverrideEffectiveSpecID(entry)
        addon:ShowTalentPicker(frame.talentChoose, specID, function(configID, selectedSpecID)
            addon:SetDungeonOverrideTalent(entry, configID, selectedSpecID)
        end)
    end)

    frame.talentInherit = CreateButton(frame, T("INHERIT"), 100, 26)
    frame.talentInherit:SetPoint("LEFT", frame.talentChoose, "RIGHT", 8, 0)
    frame.talentInherit:SetScript("OnClick", function()
        local entry = addon:GetDungeonCatalogEntry(DB.selectedDungeonKey)
        if entry then addon:ClearDungeonOverrideField(entry, "talent") end
    end)

    frame.gearLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.gearLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", rightX, -334)
    frame.gearLabel:SetText(T("EQUIPMENT_OVERRIDE"))

    frame.gearValue = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.gearValue:SetPoint("TOPLEFT", frame, "TOPLEFT", rightX, -357)
    frame.gearValue:SetWidth(380)
    frame.gearValue:SetJustifyH("LEFT")

    frame.gearChoose = CreateButton(frame, T("CHOOSE_GEAR_OVERRIDE"), 220, 26)
    frame.gearChoose:SetPoint("TOPLEFT", frame, "TOPLEFT", rightX, -382)
    frame.gearChoose:SetScript("OnClick", function()
        local entry = addon:GetDungeonCatalogEntry(DB.selectedDungeonKey)
        if not entry then return end
        addon:ShowGearPicker(frame.gearChoose, function(setID) addon:SetDungeonOverrideEquipment(entry, setID) end)
    end)

    frame.gearInherit = CreateButton(frame, T("INHERIT"), 100, 26)
    frame.gearInherit:SetPoint("LEFT", frame.gearChoose, "RIGHT", 8, 0)
    frame.gearInherit:SetScript("OnClick", function()
        local entry = addon:GetDungeonCatalogEntry(DB.selectedDungeonKey)
        if entry then addon:ClearDungeonOverrideField(entry, "equipment") end
    end)

    frame.remove = CreateButton(frame, T("REMOVE_DUNGEON_OVERRIDE"), 220, 28)
    frame.remove:SetPoint("TOPLEFT", frame, "TOPLEFT", rightX, -430)
    frame.remove:SetScript("OnClick", function()
        local entry = addon:GetDungeonCatalogEntry(DB.selectedDungeonKey)
        if entry then addon:RemoveDungeonOverride(entry) end
    end)

    frame.page = 1
    frame:Hide()
    return frame
end

function addon:UpdateDungeonOverrideFrame()
    local frame = dungeonOverrideFrame
    if not frame or not DB then return end
    local catalog = self:GetDungeonCatalog()
    local current = self:GetCurrentDungeonInfo()

    if (not DB.selectedDungeonKey or not self:GetDungeonCatalogEntry(DB.selectedDungeonKey)) and current then
        DB.selectedDungeonKey = current.key
    end
    if not DB.selectedDungeonKey and catalog[1] then DB.selectedDungeonKey = catalog[1].key end

    local totalPages = math.max(1, math.ceil(#catalog / DUNGEON_PAGE_SIZE))
    frame.page = math.max(1, math.min(frame.page or 1, totalPages))
    local selectedIndex
    for i, entry in ipairs(catalog) do
        if entry.key == DB.selectedDungeonKey then selectedIndex = i break end
    end
    if selectedIndex then frame.page = math.floor((selectedIndex - 1) / DUNGEON_PAGE_SIZE) + 1 end

    local first = ((frame.page - 1) * DUNGEON_PAGE_SIZE) + 1
    for rowIndex, row in ipairs(frame.rows) do
        local entry = catalog[first + rowIndex - 1]
        if entry then
            row.dungeonKey = entry.key
            local prefix = entry.context == "mythicplus" and "[M+] " or "[" .. T("CONTEXT_DUNGEON") .. "] "
            local configured = self:GetDungeonOverride(entry.key) and " |cff66ff99*|r" or ""
            row.text:SetText(prefix .. tostring(entry.name) .. configured)
            row:Show()
            if entry.key == DB.selectedDungeonKey then
                row:SetBackdropColor(0.055, 0.20, 0.27, 0.98)
                row:SetBackdropBorderColor(0.38, 0.82, 1.0, 1)
            else
                row:SetBackdropColor(0.04, 0.10, 0.13, 0.95)
                row:SetBackdropBorderColor(0.16, 0.45, 0.56, 1)
            end
        else
            row.dungeonKey = nil
            row:Hide()
        end
    end
    frame.pageText:SetText(string.format("%d/%d", frame.page, totalPages))
    frame.prev:SetShown(totalPages > 1)
    frame.next:SetShown(totalPages > 1)

    local entry = self:GetDungeonCatalogEntry(DB.selectedDungeonKey)
    if not entry then
        frame.selectedLabel:SetText(T("NO_DUNGEON_SELECTED"))
        frame.fallback:SetText(T("DUNGEON_OVERRIDES_EMPTY"))
        frame.specValue:SetText("-")
        frame.talentValue:SetText("-")
        frame.gearValue:SetText("-")
        return
    end

    local kind = entry.context == "mythicplus" and T("CONTEXT_MYTHICPLUS") or T("CONTEXT_DUNGEON")
    frame.selectedLabel:SetText(string.format("%s - %s", kind, tostring(entry.name)))
    frame.fallback:SetText(T("DUNGEON_FALLBACK", ContextName(entry.context)))

    local override = self:GetDungeonOverride(entry.key)
    local baseSpec = self:ResolveSpecBinding(entry.context)
    local effectiveSpecID = self:GetDungeonOverrideEffectiveSpecID(entry)
    local effectiveSpecName = self:GetSpecNameByID(effectiveSpecID) or T("UNKNOWN")

    if override and override.specID then
        frame.specValue:SetText("|cff66ff99" .. tostring(self:GetSpecDisplayName(override.specID)) .. "|r")
    else
        local inheritedID = baseSpec and baseSpec.specID or effectiveSpecID
        local inherited = inheritedID and self:GetSpecDisplayName(inheritedID) or effectiveSpecName
        frame.specValue:SetText(T("INHERITS_VALUE", inherited))
    end

    if override and override.talent then
        local talent = self:ResolveTalentRecord(override.talent.specID or effectiveSpecID, override.talent)
        local value = talent and talent.name or T("MISSING_LOADOUT")
        frame.talentValue:SetText("|cff66ff99" .. tostring(value) .. "|r")
    else
        local baseTalent = self:ResolveTalentBinding(effectiveSpecID, entry.context)
        frame.talentValue:SetText(T("INHERITS_VALUE", baseTalent and baseTalent.name or T("NO_MAPPING")))
    end

    if override and override.equipment then
        local gear, info = self:ResolveEquipmentRecord(override.equipment)
        frame.gearValue:SetText("|cff66ff99" .. tostring(info and info.name or (gear and gear.name) or T("MISSING_GEAR")) .. "|r")
    else
        local baseGear, baseInfo = self:ResolveEquipmentBinding(effectiveSpecID, entry.context)
        if not baseGear and baseSpec and baseSpec.specID and baseSpec.specID ~= effectiveSpecID then
            baseGear, baseInfo = self:ResolveEquipmentBinding(baseSpec.specID, entry.context)
        end
        frame.gearValue:SetText(T("INHERITS_VALUE", baseInfo and baseInfo.name or (baseGear and baseGear.name) or T("NO_MAPPING")))
    end
end

function addon:ToggleDungeonOverrides()
    if not dungeonOverrideFrame then return end
    HidePickers()
    if dungeonOverrideFrame:IsShown() then
        dungeonOverrideFrame:Hide()
        return
    end
    local current = self:GetCurrentDungeonInfo()
    if current then DB.selectedDungeonKey = current.key end
    self:UpdateDungeonOverrideFrame()
    dungeonOverrideFrame:Show()
end

local MINIMAP_BUTTON_OUTER_OFFSET = 10

local function GetMinimapButtonOrbitRadii()
    -- Match DK Mentor: derive the orbit from the actual minimap dimensions.
    -- A fixed radius can place the button inside large Edit Mode minimaps.
    local width = (Minimap and Minimap.GetWidth and Minimap:GetWidth()) or 140
    local height = (Minimap and Minimap.GetHeight and Minimap:GetHeight()) or 140

    if type(width) ~= "number" or width <= 0 then width = 140 end
    if type(height) ~= "number" or height <= 0 then height = 140 end

    return (width * 0.5) + MINIMAP_BUTTON_OUTER_OFFSET,
           (height * 0.5) + MINIMAP_BUTTON_OUTER_OFFSET
end

function addon:UpdateMinimapButtonPosition()
    if not minimapButton or not DB then return end

    if not Minimap then
        minimapButton:ClearAllPoints()
        minimapButton:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -32, -32)
        return
    end

    local radians = math.rad(DB.minimap.angle or 225)
    local radiusX, radiusY = GetMinimapButtonOrbitRadii()
    minimapButton:ClearAllPoints()
    minimapButton:SetPoint(
        "CENTER",
        Minimap,
        "CENTER",
        math.cos(radians) * radiusX,
        math.sin(radians) * radiusY
    )
end

function addon:UpdateMinimapButtonDrag()
    if not minimapButton or not DB or not Minimap or not Minimap.GetCenter or not GetCursorPosition then return end

    local minimapX, minimapY = Minimap:GetCenter()
    local cursorX, cursorY = GetCursorPosition()
    local scale = (Minimap.GetEffectiveScale and Minimap:GetEffectiveScale()) or 1
    if not minimapX or not minimapY or not cursorX or not cursorY then return end

    cursorX = cursorX / scale
    cursorY = cursorY / scale
    DB.minimap.angle = math.deg(Atan2(cursorY - minimapY, cursorX - minimapX))
    self:UpdateMinimapButtonPosition()
end

function addon:UpdateMinimapButton()
    if not minimapButton or not DB then return end
    minimapButton:SetShown(not DB.minimap.hide)
    if not DB.minimap.hide then
        self:UpdateMinimapButtonPosition()
    end
end

local function CreateMinimapButton()
    local parent = Minimap or UIParent
    local button = CreateFrame("Button", "LoadoutPilotMinimapButton", parent)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    -- Match the DK Mentor / Blizzard / LibDBIcon button geometry.
    -- MiniMap-TrackingBorder is intentionally offset inside its texture.
    button.border = button:CreateTexture(nil, "OVERLAY")
    button.border:SetSize(53, 53)
    button.border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    button.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    button.background = button:CreateTexture(nil, "BACKGROUND")
    button.background:SetSize(20, 20)
    button.background:SetPoint("TOPLEFT", button, "TOPLEFT", 7, -5)
    button.background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(20, 20)
    button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 7, -5)
    button.icon:SetTexture("Interface\\AddOns\\LoadoutPilot\\Media\\MinimapIcon")
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    button.highlight = button:CreateTexture(nil, "HIGHLIGHT")
    button.highlight:SetAllPoints(button)
    button.highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    button.highlight:SetBlendMode("ADD")

    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            addon:ApplyCurrentRules("minimap", true)
        else
            addon:Open()
        end
    end)

    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            addon:UpdateMinimapButtonDrag()
        end)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        addon:UpdateMinimapButtonPosition()
    end)

    button:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(T("ADDON_TITLE"))
        GameTooltip:AddLine(T("MINIMAP_LEFT_CLICK"), 1, 1, 1, true)
        GameTooltip:AddLine(T("MINIMAP_RIGHT_CLICK"), 1, 1, 1, true)
        GameTooltip:AddLine(T("MINIMAP_DRAG_HINT"), 0.7, 0.82, 0.9, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    -- Edit Mode can resize the minimap after login. Recalculate the orbit so
    -- the button stays on the external rim, just like DK Mentor.
    if Minimap and Minimap.HookScript then
        Minimap:HookScript("OnSizeChanged", function()
            addon:UpdateMinimapButtonPosition()
        end)
    end

    addon:UpdateMinimapButtonPosition()
    return button
end

local function CreateStatusWidget()
    local frame = CreateFrame("Frame", "LoadoutPilotStatusWidget", UIParent, "BackdropTemplate")
    frame:SetSize(320, 34)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    ApplyBackdrop(frame, 0.68)

    frame:SetScript("OnDragStart", function(self)
        if DB and not DB.hud.locked then self:StartMoving() end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if DB and not DB.hud.locked then
            local point, _, relativePoint, x, y = self:GetPoint(1)
            DB.hud.point = point
            DB.hud.relativePoint = relativePoint
            DB.hud.x = x
            DB.hud.y = y
        end
    end)
    frame:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then
            mainFrame:SetShown(not mainFrame:IsShown())
            if mainFrame:IsShown() then addon:UpdateAll() else HidePickers() end
        end
    end)

    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetSize(HUD_LAYOUT.iconSize, HUD_LAYOUT.iconSize)
    frame.icon:SetPoint("TOPLEFT", HUD_LAYOUT.paddingLeft, -HUD_LAYOUT.paddingTop)
    frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.title:SetJustifyH("LEFT")
    frame.title:SetJustifyV("MIDDLE")

    frame.talent = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.talent:SetJustifyH("LEFT")
    frame.talent:SetJustifyV("MIDDLE")

    frame.gear = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.gear:SetJustifyH("LEFT")
    frame.gear:SetJustifyV("MIDDLE")

    frame.state = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.state:SetJustifyH("LEFT")
    frame.state:SetJustifyV("MIDDLE")

    frame:SetScript("OnEnter", function(self)
        addon:ShowStatusTooltip(self)
    end)
    frame:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    return frame
end

function addon:RestoreHUDPosition()
    if not statusWidget or not DB then return end
    statusWidget:ClearAllPoints()
    statusWidget:SetPoint(DB.hud.point or "CENTER", UIParent, DB.hud.relativePoint or "CENTER", DB.hud.x or 0, DB.hud.y or 170)
end

function addon:ResetPositions()
    if not DB then return end
    DB.hud.point = DEFAULTS.hud.point
    DB.hud.relativePoint = DEFAULTS.hud.relativePoint
    DB.hud.x = DEFAULTS.hud.x
    DB.hud.y = DEFAULTS.hud.y
    DB.minimap.angle = DEFAULTS.minimap.angle
    self:RestoreHUDPosition()
    self:UpdateMinimapButtonPosition()
    Print(T("RESET_POS"), true)
end

function addon:ResetHUDPosition()
    self:ResetPositions()
end

function addon:ShowStatusTooltip(widget)
    if not GameTooltip then return end

    local currentSpecID, currentSpecName = self:GetSpecInfo()
    local className = self:GetPlayerClassInfo()
    local rule = self:ResolveRuntimeRule(false)
    local context = rule and rule.context or self:DetectContext()
    local talentBinding = rule and rule.talentBinding or nil
    local gearBinding, gearInfo = rule and rule.gearBinding or nil, rule and rule.gearInfo or nil

    local talentText = T("NO_MAPPING")
    if type(talentBinding) == "table" then
        local actualName = self:GetTalentName(talentBinding.configID)
        if actualName then talentText = actualName else talentText = T("MISSING_LOADOUT") end
    end

    local gearText = T("NO_MAPPING")
    if type(gearBinding) == "table" then
        gearText = gearInfo and gearInfo.name or T("MISSING_GEAR")
    end

    GameTooltip:SetOwner(widget, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(T("ADDON_TITLE"))
    GameTooltip:AddDoubleLine(T("CLASS_LABEL"), tostring(className), 0.85, 0.92, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine(T("SPEC_LABEL"), tostring(currentSpecName), 0.85, 0.92, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine(T("SPEC_ROLE"), self:GetRoleLabel(self:GetSpecRoleByID(currentSpecID)), 0.85, 0.92, 1, 1, 1, 1)
    if self:IsRoleProtectionContext(context) then
        GameTooltip:AddDoubleLine(T("GROUP_ROLE"), self:GetRoleLabel(self:GetAssignedGroupRole()), 0.85, 0.92, 1, 1, 1, 1)
    end
    if rule and rule.configuredSpecID and rule.configuredSpecID ~= currentSpecID then
        GameTooltip:AddDoubleLine(T("TARGET_SPEC"), tostring(self:GetSpecNameByID(rule.configuredSpecID) or T("UNKNOWN")), 0.85, 0.92, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine(T("TARGET_ROLE"), self:GetRoleLabel(self:GetSpecRoleByID(rule.configuredSpecID)), 0.85, 0.92, 1, 1, 1, 1)
    end
    GameTooltip:AddDoubleLine(T("CONTEXT_LABEL"), ContextName(context), 0.85, 0.92, 1, 1, 1, 1)
    if rule and rule.dungeonInfo then
        GameTooltip:AddDoubleLine(T("DUNGEON_LABEL"), tostring(rule.dungeonInfo.name), 0.85, 0.92, 1, 1, 1, 1)
        if rule.override then
            GameTooltip:AddDoubleLine(T("RULE_LABEL"), T("DUNGEON_OVERRIDE_ACTIVE"), 0.85, 0.92, 1, 0.4, 1, 0.6)
        end
    end
    GameTooltip:AddDoubleLine(T("TALENTS"), tostring(talentText), 0.85, 0.92, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine(T("GEAR"), tostring(gearText), 0.85, 0.92, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine(T("STATUS"), tostring(self:GetStatusState()), 0.85, 0.92, 1, 1, 1, 1)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(T("OPEN_SETTINGS"), 1, 1, 1, true)
    GameTooltip:AddLine(T("DRAG_HINT"), 0.7, 0.82, 0.9, true)
    GameTooltip:Show()
end

function addon:LayoutStatusWidget()
    if not statusWidget then return end

    local frame = statusWidget
    local textLeft = HUD_LAYOUT.paddingLeft + HUD_LAYOUT.iconSize + HUD_LAYOUT.iconGap
    local row1Left = textLeft
    local row2Left = textLeft

    local segments = { frame.title, frame.talent, frame.gear }
    local widths = {}
    local totalWidth = textLeft + HUD_LAYOUT.paddingRight

    for index, region in ipairs(segments) do
        region:SetWidth(1000)
        local width = math.ceil((tonumber(region:GetStringWidth()) or 0) + 2)
        widths[index] = width
        totalWidth = totalWidth + width
        if index < #segments then
            totalWidth = totalWidth + HUD_LAYOUT.segmentGap
        end
    end

    frame.state:SetText("")
    frame.state:Hide()

    local singleLine = totalWidth <= HUD_LAYOUT.maxFrameWidth

    if singleLine then
        frame.title:ClearAllPoints()
        frame.title:SetPoint("LEFT", frame, "LEFT", row1Left, 0)
        frame.title:SetWidth(widths[1])

        frame.talent:ClearAllPoints()
        frame.talent:SetPoint("LEFT", frame.title, "RIGHT", HUD_LAYOUT.segmentGap, 0)
        frame.talent:SetWidth(widths[2])

        frame.gear:ClearAllPoints()
        frame.gear:SetPoint("LEFT", frame.talent, "RIGHT", HUD_LAYOUT.segmentGap, 0)
        frame.gear:SetWidth(widths[3])

        local contentHeight = math.max(tonumber(frame.title:GetStringHeight()) or 0, tonumber(frame.talent:GetStringHeight()) or 0, tonumber(frame.gear:GetStringHeight()) or 0, HUD_LAYOUT.iconSize)
        local frameWidth = math.max(HUD_LAYOUT.minFrameWidth, totalWidth)
        local frameHeight = math.max(HUD_LAYOUT.minFrameHeight, HUD_LAYOUT.paddingTop + contentHeight + HUD_LAYOUT.paddingBottom)
        frame:SetSize(frameWidth, frameHeight)
        frame.icon:ClearAllPoints()
        frame.icon:SetPoint("LEFT", frame, "LEFT", HUD_LAYOUT.paddingLeft, 0)
    else
        frame.title:ClearAllPoints()
        frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", row1Left, -HUD_LAYOUT.paddingTop)
        frame.title:SetWidth(widths[1])

        frame.talent:ClearAllPoints()
        frame.talent:SetPoint("LEFT", frame.title, "RIGHT", HUD_LAYOUT.segmentGap, 0)
        frame.talent:SetWidth(widths[2])

        frame.gear:ClearAllPoints()
        frame.gear:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -HUD_LAYOUT.lineGap)
        frame.gear:SetWidth(widths[3])

        local row1Height = math.max(tonumber(frame.title:GetStringHeight()) or 0, tonumber(frame.talent:GetStringHeight()) or 0)
        local row2Height = tonumber(frame.gear:GetStringHeight()) or 0
        local row1Width = row1Left + widths[1] + HUD_LAYOUT.segmentGap + widths[2] + HUD_LAYOUT.paddingRight
        local row2Width = row2Left + widths[3] + HUD_LAYOUT.paddingRight
        local frameWidth = math.max(HUD_LAYOUT.minFrameWidth, math.min(HUD_LAYOUT.maxFrameWidth, math.max(row1Width, row2Width)))
        local textHeight = row1Height + HUD_LAYOUT.lineGap + row2Height
        local contentHeight = math.max(HUD_LAYOUT.iconSize, textHeight)
        local frameHeight = math.max(HUD_LAYOUT.minFrameHeight, HUD_LAYOUT.paddingTop + contentHeight + HUD_LAYOUT.paddingBottom)
        frame:SetSize(frameWidth, frameHeight)
        frame.icon:ClearAllPoints()
        frame.icon:SetPoint("LEFT", frame, "LEFT", HUD_LAYOUT.paddingLeft, 0)
    end
end

function addon:GetStatusState()
    local rule = self:ResolveRuntimeRule(false)
    if not rule then return "|cffffcc55" .. T("ACTION_REQUIRED") .. "|r" end

    local currentSpecID = select(1, self:GetSpecInfo())
    local configuredSpecID = rule.configuredSpecID
    local specNeedsChange = configuredSpecID and currentSpecID and configuredSpecID ~= currentSpecID
    local roleState = rule.roleState or self:GetRoleProtectionState(configuredSpecID, rule.context, currentSpecID)

    if roleState and roleState.mismatch then
        return "|cffff7777" .. T("ROLE_MISMATCH_STATUS", self:GetRoleLabel(roleState.expectedRole), self:GetRoleLabel(roleState.targetRole)) .. "|r"
    end

    if specNeedsChange and not DB.autoSpec then
        return "|cffffcc55" .. T("SPEC_MANUAL_REQUIRED") .. "|r"
    end
    if pendingSpecID or (specNeedsChange and DB.autoSpec) then
        if InCombatLockdown and InCombatLockdown() then
            return "|cffffcc55" .. T("QUEUED_COMBAT") .. "|r"
        end
        local targetName = configuredSpecID and self:GetSpecNameByID(configuredSpecID) or T("UNKNOWN")
        return "|cffffcc55" .. (lastSpecError or T("APPLYING_SPEC", targetName)) .. "|r"
    end

    local specID = rule.runtimeSpecID or currentSpecID
    local talentBinding = rule.talentBinding
    local gearBinding, gearInfo = rule.gearBinding, rule.gearInfo
    local currentTalentID = specID and self:GetSelectedTalentConfigID(specID) or nil

    local talentReady = type(talentBinding) ~= "table" or not talentBinding.configID or currentTalentID == talentBinding.configID
    local gearReady = type(gearBinding) ~= "table" or not gearBinding.setID or (gearInfo and gearInfo.isEquipped)

    if InCombatLockdown and InCombatLockdown() and ((pendingTalentKey and not talentReady) or (pendingGearKey and not gearReady)) then
        return "|cffffcc55" .. T("QUEUED_COMBAT") .. "|r"
    end
    if pendingTalentKey and not talentReady then
        return "|cffffcc55" .. (lastTalentError or T("APPLYING")) .. "|r"
    end
    if pendingGearKey and not gearReady then
        return "|cffffcc55" .. (lastGearError or T("APPLYING")) .. "|r"
    end
    if talentReady and gearReady then
        return "|cff66ff99" .. T("READY") .. "|r"
    end
    return "|cffffcc55" .. T("ACTION_REQUIRED") .. "|r"
end

function addon:UpdateStatusWidget()
    if not statusWidget or not DB then return end
    local currentSpecID, currentSpecName, specIcon = self:GetSpecInfo()
    local _, classFile = self:GetPlayerClassInfo()
    local rule = self:ResolveRuntimeRule(false)
    local talentBinding = rule and rule.talentBinding or nil
    local gearBinding, gearInfo = rule and rule.gearBinding or nil, rule and rule.gearInfo or nil
    local ruleSpecID = rule and rule.runtimeSpecID or currentSpecID

    statusWidget.icon:SetTexture(specIcon or 134400)

    local color = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if color then
        statusWidget:SetBackdropBorderColor(color.r, color.g, color.b, 0.95)
    else
        statusWidget:SetBackdropBorderColor(0.45, 0.88, 1, 0.95)
    end

    statusWidget.title:SetTextColor(1, 1, 1)
    statusWidget.talent:SetTextColor(1, 1, 1)
    statusWidget.gear:SetTextColor(1, 1, 1)

    local talentText = T("NO_MAPPING")
    if type(talentBinding) == "table" then
        local actualName = self:GetTalentName(talentBinding.configID)
        if actualName then talentText = actualName else talentText = "|cffff7777" .. T("MISSING_LOADOUT") .. "|r" end
    end
    local currentTalent = ruleSpecID == currentSpecID and self:GetSelectedTalentConfigID(ruleSpecID) or nil
    if talentBinding and currentTalent == talentBinding.configID then talentText = "|cff66ff99" .. talentText .. "|r" end
    if not DB.autoTalents then
        talentText = talentText .. " |cffffcc55(" .. T("MANUAL") .. ")|r"
    end

    local gearText = T("NO_MAPPING")
    if type(gearBinding) == "table" then
        if gearInfo then
            gearText = gearInfo.name
            if gearInfo.isEquipped then gearText = "|cff66ff99" .. gearText .. "|r" end
        else
            gearText = "|cffff7777" .. T("MISSING_GEAR") .. "|r"
        end
    end
    if not DB.autoGear then
        gearText = gearText .. " |cffffcc55(" .. T("MANUAL") .. ")|r"
    end

    statusWidget.title:SetText(T("TALENTS") .. ": " .. talentText)
    statusWidget.talent:SetText(T("GEAR") .. ": " .. gearText)
    statusWidget.gear:SetText(self:GetStatusState())
    statusWidget.state:SetText("")

    self:LayoutStatusWidget()
    statusWidget:SetShown(DB.hud.enabled == true)
end

function addon:UpdateMainFrame()
    if not mainFrame or not DB then return end
    local specID, specName, specIcon = self:GetSpecInfo()
    local className = self:GetPlayerClassInfo()
    local actualContext = self:DetectContext()
    local configContext = DB.selectedContext
    local currentDungeon = self:GetCurrentDungeonInfo()

    mainFrame.currentIcon:SetTexture(specIcon or 134400)
    mainFrame.currentTitle:SetText(string.format("%s - %s (%s)", tostring(className), tostring(specName), self:GetRoleLabel(self:GetSpecRoleByID(specID))))
    local contextText = string.format("%s: %s", T("CURRENT"), ContextName(actualContext))
    if currentDungeon then
        contextText = contextText .. " - " .. tostring(currentDungeon.name)
        if self:GetDungeonOverride(currentDungeon.key) then
            contextText = contextText .. " |cff66ff99(" .. T("OVERRIDE_ACTIVE") .. ")|r"
        end
    end
    mainFrame.currentContext:SetText(contextText)

    for context, button in pairs(contextButtons) do
        if context == configContext then
            button:SetBackdropColor(0.055, 0.20, 0.27, 0.98)
            button:SetBackdropBorderColor(0.38, 0.82, 1.0, 1)
            button.text:SetText("|cff66ddff" .. ContextName(context) .. "|r")
        else
            button:SetBackdropColor(0.04, 0.10, 0.13, 0.95)
            button:SetBackdropBorderColor(0.16, 0.45, 0.56, 1)
            button.text:SetText(ContextName(context))
        end
    end

    local specBinding = self:ResolveSpecBinding(configContext)
    local configSpecID = specBinding and specBinding.specID or specID
    if specBinding then
        mainFrame.specValue:SetText(self:GetSpecDisplayName(configSpecID))
    else
        mainFrame.specValue:SetText(T("KEEP_CURRENT_SPEC", string.format("%s (%s)", tostring(specName), self:GetRoleLabel(self:GetSpecRoleByID(specID)))))
    end

    local talentBinding = configSpecID and self:ResolveTalentBinding(configSpecID, configContext) or nil
    if talentBinding then
        local name = self:GetTalentName(talentBinding.configID)
        mainFrame.talentValue:SetText(name or ("|cffff7777" .. T("MISSING_LOADOUT") .. "|r"))
    else
        mainFrame.talentValue:SetText("|cffaaaaaa" .. T("NO_MAPPING") .. "|r")
    end

    local gearBinding, gearInfo = configSpecID and self:ResolveEquipmentBinding(configSpecID, configContext) or nil, nil
    if configSpecID then gearBinding, gearInfo = self:ResolveEquipmentBinding(configSpecID, configContext) end
    if gearBinding then
        mainFrame.gearValue:SetText(gearInfo and gearInfo.name or ("|cffff7777" .. T("MISSING_GEAR") .. "|r"))
    else
        mainFrame.gearValue:SetText("|cffaaaaaa" .. T("NO_MAPPING") .. "|r")
    end

    mainFrame.autoSpec.text:SetText(DB.autoSpec and T("AUTO_SPEC_ON") or T("AUTO_SPEC_OFF"))
    mainFrame.autoTalents.text:SetText(DB.autoTalents and T("AUTO_TALENTS_ON") or T("AUTO_TALENTS_OFF"))
    mainFrame.autoGear.text:SetText(DB.autoGear and T("AUTO_GEAR_ON") or T("AUTO_GEAR_OFF"))
    mainFrame.hudToggle.text:SetText(DB.hud.enabled and T("HUD_ON") or T("HUD_OFF"))
    mainFrame.hudLock.text:SetText(DB.hud.locked and T("HUD_LOCKED") or T("HUD_UNLOCKED"))
    mainFrame.minimapToggle.text:SetText(DB.minimap.hide and T("MINIMAP_OFF") or T("MINIMAP_ON"))
    mainFrame.chatToggle.text:SetText(DB.chatMessages and T("CHAT_MESSAGES_ON") or T("CHAT_MESSAGES_OFF"))
    mainFrame.dungeonOverrides.text:SetText(T("DUNGEON_OVERRIDES"))
    mainFrame.resetPositions.text:SetText(T("RESET_POSITIONS"))
    mainFrame.languageButton.text:SetText(T("LANGUAGE_BUTTON", self:GetLanguageOverrideLabel()))
end

function addon:GetLanguageOverrideLabel()
    return GetAddonLanguageLabel(DB and DB.languageOverride or "auto")
end

function addon:UpdateLanguagePicker()
    if not languagePicker or not DB then return end
    local selected = NormalizeAddonLanguage(DB.languageOverride)
    languagePicker.title:SetText(T("ADDON_LANGUAGE"))
    languagePicker.description:SetText(T("LANGUAGE_DESCRIPTION"))
    languagePicker.current:SetText(T("LANGUAGE_CURRENT", GetAddonLanguageLabel(selected)))
    languagePicker.cancel.text:SetText(T("CANCEL"))
    for _, button in ipairs(languagePicker.choiceButtons or {}) do
        local label = T(button.languageLabelKey or "")
        if NormalizeAddonLanguage(button.languageValue) == selected then
            button.text:SetText("|cff69d8ff✓|r " .. label)
        else
            button.text:SetText(label)
        end
    end
end

function addon:ToggleLanguagePicker()
    if not languagePicker then return end
    if languagePicker:IsShown() then
        languagePicker:Hide()
        return
    end
    if talentPicker then talentPicker:Hide() end
    if gearPicker then gearPicker:Hide() end
    languagePicker:ClearAllPoints()
    if mainFrame and mainFrame:IsShown() then
        languagePicker:SetPoint("CENTER", mainFrame, "CENTER", 0, 10)
    else
        languagePicker:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    self:UpdateLanguagePicker()
    languagePicker:SetFrameStrata("FULLSCREEN_DIALOG")
    languagePicker:SetFrameLevel(1000)
    languagePicker:Show()
    if languagePicker.Raise then languagePicker:Raise() end
end

function addon:SetLanguageOverride(value)
    if not DB then return end
    local normalized = NormalizeAddonLanguage(value)
    DB.languageOverride = normalized
    local label = GetAddonLanguageLabel(normalized)
    if languagePicker then languagePicker:Hide() end
    if mainFrame and mainFrame.languageButton then
        mainFrame.languageButton.text:SetText(T("LANGUAGE_BUTTON", label))
    end
    Print(T("LANGUAGE_SAVED", label), true)
end

function addon:UpdatePendingState()
    if pendingSpecID then
        local currentSpecID = select(1, self:GetSpecInfo())
        if currentSpecID == pendingSpecID then
            local name = self:GetSpecNameByID(pendingSpecID) or T("UNKNOWN")
            self:ClearPendingSpecSwitch()
            Print(T("SPEC_SWITCHED", name))
        end
    end

    if pendingTalentTargetID then
        local specID = pendingTalentSpecID or select(1, self:GetSpecInfo())
        if specID and self:GetSelectedTalentConfigID(specID) == pendingTalentTargetID then
            self:CompletePendingTalentSwitch(false)
        end
    end

    if pendingGearKey then
        local rule = self:ResolveRuntimeRule(false)
        local binding, info = rule and rule.gearBinding or nil, rule and rule.gearInfo or nil
        if info and info.isEquipped then
            pendingGearKey = nil
            lastGearError = nil
            gearRetryElapsed = 0
            if binding and binding.name then
                Print(T("GEAR_SWITCHED", binding.name, ContextName(rule.context)))
            end
        end
    end
end

function addon:UpdateAll()
    self:UpdatePendingState()
    self:UpdateMainFrame()
    self:UpdateStatusWidget()
    self:UpdateMinimapButton()
    if dungeonOverrideFrame and dungeonOverrideFrame:IsShown() then
        self:UpdateDungeonOverrideFrame()
    end
end

function addon:ScheduleUpdate()
    if updateScheduled then return end
    updateScheduled = true
    if C_Timer and C_Timer.After then
        C_Timer.After(0.20, function()
            updateScheduled = false
            addon:UpdateAll()
        end)
    else
        updateScheduled = false
        self:UpdateAll()
    end
end

function addon:InitializeDatabase()
    LoadoutPilotDB = CopyDefaults(DEFAULTS, type(LoadoutPilotDB) == "table" and LoadoutPilotDB or {})
    DB = LoadoutPilotDB
    DB.schema = Data.schema
    DB.specBindings = type(DB.specBindings) == "table" and DB.specBindings or {}
    DB.talentBindings = type(DB.talentBindings) == "table" and DB.talentBindings or {}
    DB.equipmentBindings = type(DB.equipmentBindings) == "table" and DB.equipmentBindings or {}
    DB.dungeonOverrides = type(DB.dungeonOverrides) == "table" and DB.dungeonOverrides or {}
    DB.knownDungeons = type(DB.knownDungeons) == "table" and DB.knownDungeons or {}
    DB.languageOverride = NormalizeAddonLanguage(DB.languageOverride)
    if LP.SetLocaleOverride then LP.SetLocaleOverride(DB.languageOverride) end
    if not Data.contextLabelKeys[DB.selectedContext] then DB.selectedContext = "world" end
end

function addon:CreateUI()
    mainFrame = CreateMainFrame()
    statusWidget = CreateStatusWidget()
    minimapButton = CreateMinimapButton()
    languagePicker = CreateLanguagePicker()
    dungeonOverrideFrame = CreateDungeonOverrideFrame()
    self:RestoreHUDPosition()
    self:UpdateMinimapButtonPosition()
end

function addon:Open()
    HidePickers()
    mainFrame:SetShown(not mainFrame:IsShown())
    if mainFrame:IsShown() then self:UpdateAll() end
end

function addon:PrintStatus()
    local currentSpecID, currentSpecName = self:GetSpecInfo()
    local className = self:GetPlayerClassInfo()
    local rule = self:ResolveRuntimeRule(false)
    local context = rule and rule.context or self:DetectContext()
    local talent = rule and rule.talentBinding or nil
    local gear = rule and rule.gearBinding or nil
    Print(string.format("%s - %s | %s", tostring(className), tostring(currentSpecName), ContextName(context)), true)
    if rule and rule.dungeonInfo then
        Print(T("DUNGEON_LABEL") .. ": " .. tostring(rule.dungeonInfo.name) .. (rule.override and (" (" .. T("OVERRIDE_ACTIVE") .. ")") or ""), true)
    end
    if rule and rule.configuredSpecID and rule.configuredSpecID ~= currentSpecID then
        Print(T("TARGET_SPEC") .. ": " .. tostring(self:GetSpecNameByID(rule.configuredSpecID) or T("UNKNOWN")), true)
    end
    Print(T("TALENTS") .. ": " .. (talent and talent.name or T("NO_MAPPING")), true)
    Print(T("GEAR") .. ": " .. (gear and gear.name or T("NO_MAPPING")), true)
    Print(T("STATUS") .. ": " .. self:GetStatusState(), true)
end

function addon:RegisterRuntimeEvents()
    local events = {
        "PLAYER_LOGIN",
        "PLAYER_ENTERING_WORLD",
        "ZONE_CHANGED_NEW_AREA",
        "PLAYER_SPECIALIZATION_CHANGED",
        "PLAYER_REGEN_ENABLED",
        "PLAYER_REGEN_DISABLED",
        "ACTIVE_TALENT_GROUP_CHANGED",
        "PLAYER_TALENT_UPDATE",
        "PLAYER_PVP_TALENT_UPDATE",
        "SPELLS_CHANGED",
        "TRAIT_CONFIG_LIST_UPDATED",
        "TRAIT_CONFIG_UPDATED",
        "SELECTED_LOADOUT_CHANGED",
        "ACTIVE_COMBAT_CONFIG_CHANGED",
        "CONFIG_COMMIT_FAILED",
        "EQUIPMENT_SETS_CHANGED",
        "EQUIPMENT_SWAP_FINISHED",
        "PLAYER_EQUIPMENT_CHANGED",
        "PLAYER_ROLES_ASSIGNED",
        "PLAYER_ENTERING_BATTLEGROUND",
        "PVP_MATCH_ACTIVE",
        "PVP_MATCH_COMPLETE",
        "UPDATE_BATTLEFIELD_STATUS",
        "CHALLENGE_MODE_KEYSTONE_SLOTTED",
        "CHALLENGE_MODE_START",
        "CHALLENGE_MODE_COMPLETED",
        "CHALLENGE_MODE_RESET",
    }
    for _, eventName in ipairs(events) do pcall(self.RegisterEvent, self, eventName) end
end

addon:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loaded = ...
        if loaded ~= ADDON_NAME then return end
        self:InitializeDatabase()
        self:CreateUI()
        self:RegisterRuntimeEvents()
        self:UnregisterEvent("ADDON_LOADED")
        return
    end

    if event == "PLAYER_LOGIN" then
        lastContext = self:DetectContext()
        local dungeon = self:GetCurrentDungeonInfo()
        lastDungeonKey = dungeon and dungeon.key or nil
        self:UpdateAll()
        if DB.firstRun then
            DB.firstRun = false
            mainFrame:Show()
            Print(T("FIRST_RUN"), true)
        end
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        pendingSpecInProgress = false
        specRetryElapsed = 2.0
        pendingTalentInProgress = false
        talentRetryElapsed = 1.0
        self:ApplyCurrentRules("combat-ended", false)
    elseif event == "CONFIG_COMMIT_FAILED" then
        pendingTalentInProgress = false
        pendingTalentWatchToken = pendingTalentWatchToken + 1
        talentRetryElapsed = 1.0
        lastTalentError = T("TALENT_FAILED")
    elseif event == "TRAIT_CONFIG_UPDATED" and pendingTalentKey and pendingTalentInProgress then
        self:CompletePendingTalentSwitch(true)
    elseif event == "ACTIVE_TALENT_GROUP_CHANGED" or event == "PLAYER_TALENT_UPDATE"
        or event == "PLAYER_PVP_TALENT_UPDATE" or event == "SELECTED_LOADOUT_CHANGED"
        or event == "ACTIVE_COMBAT_CONFIG_CHANGED" or event == "SPELLS_CHANGED" then
        self:UpdatePendingState()
    elseif event == "EQUIPMENT_SWAP_FINISHED" then
        local result = AccessibleBoolean((...))
        self:UpdatePendingState()
        if result == false and pendingGearKey then
            lastGearError = T("GEAR_FAILED")
        end
        if pendingGearKey and C_Timer and C_Timer.After then
            C_Timer.After(0.25, function()
                if pendingGearKey and (not InCombatLockdown or not InCombatLockdown()) then
                    addon:TrySwitchEquipment("equipment-swap-finished", false)
                end
            end)
        end
    elseif event == "PLAYER_ROLES_ASSIGNED" then
        lastRoleMismatchKey = nil
        self:ApplyCurrentRules("role-assigned", false)
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        local unit = ...
        if not unit or unit == "player" then
            self:UpdatePendingState()
            if C_Timer and C_Timer.After then
                C_Timer.After(0.8, function() addon:ApplyCurrentRules("specialization", false) end)
            else
                self:ApplyCurrentRules("specialization", false)
            end
        end
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA"
        or event == "PLAYER_ENTERING_BATTLEGROUND" or event == "PVP_MATCH_ACTIVE"
        or event == "PVP_MATCH_COMPLETE" or event == "UPDATE_BATTLEFIELD_STATUS"
        or event == "CHALLENGE_MODE_KEYSTONE_SLOTTED"
        or event == "CHALLENGE_MODE_START" or event == "CHALLENGE_MODE_COMPLETED"
        or event == "CHALLENGE_MODE_RESET" then
        if C_Timer and C_Timer.After then
            C_Timer.After(1.0, function()
                lastContext = addon:DetectContext()
                local dungeon = addon:GetCurrentDungeonInfo()
                lastDungeonKey = dungeon and dungeon.key or nil
                addon:ApplyCurrentRules("context-event", false)
            end)
        else
            lastContext = self:DetectContext()
            local dungeon = self:GetCurrentDungeonInfo()
            lastDungeonKey = dungeon and dungeon.key or nil
            self:ApplyCurrentRules("context-event", false)
        end
    end

    self:ScheduleUpdate()
end)

addon:SetScript("OnUpdate", function(self, elapsed)
    if not DB then return end
    pollElapsed = pollElapsed + (tonumber(elapsed) or 0)
    if pollElapsed < 0.50 then return end

    local interval = pollElapsed
    pollElapsed = 0

    local context = self:DetectContext()
    local dungeon = self:GetCurrentDungeonInfo()
    local dungeonKey = dungeon and dungeon.key or nil
    if context ~= lastContext or dungeonKey ~= lastDungeonKey then
        Debug("Rule context changed from " .. tostring(lastContext) .. "/" .. tostring(lastDungeonKey) .. " to " .. tostring(context) .. "/" .. tostring(dungeonKey))
        lastContext = context
        lastDungeonKey = dungeonKey
        self:ClearPendingSpecSwitch()
        self:ClearPendingTalentSwitch()
        pendingGearKey = nil
        lastGearError = nil
        gearRetryElapsed = 0
        lastRoleMismatchKey = nil
        self:ApplyCurrentRules("context-detected", false)
    else
        self:UpdatePendingState()

        if pendingSpecID and not pendingSpecInProgress and (not InCombatLockdown or not InCombatLockdown()) then
            specRetryElapsed = specRetryElapsed + interval
            if specRetryElapsed >= 2.0 then
                specRetryElapsed = 0
                self:TrySwitchSpecialization("pending-spec-retry", false)
            end
        elseif not pendingSpecID then
            specRetryElapsed = 0
        end

        if not pendingSpecID then
            if pendingTalentKey and not pendingTalentInProgress and (not InCombatLockdown or not InCombatLockdown()) then
                talentRetryElapsed = talentRetryElapsed + interval
                if talentRetryElapsed >= 1.0 then
                    talentRetryElapsed = 0
                    self:TrySwitchTalents("pending-talent-retry", false)
                end
            elseif not pendingTalentKey then
                talentRetryElapsed = 0
            end

            if pendingGearKey and (not InCombatLockdown or not InCombatLockdown()) then
                gearRetryElapsed = gearRetryElapsed + interval
                if gearRetryElapsed >= 1.0 then
                    gearRetryElapsed = 0
                    self:TrySwitchEquipment("pending-retry", false)
                end
            else
                gearRetryElapsed = 0
            end
        end

        self:UpdateStatusWidget()
    end
end)

addon:RegisterEvent("ADDON_LOADED")

SLASH_LOADOUTPILOT1 = "/lpilot"
SLASH_LOADOUTPILOT2 = "/loadoutpilot"
SlashCmdList.LOADOUTPILOT = function(message)
    message = (message or ""):match("^%s*(.-)%s*$") or ""
    local command, rest = message:match("^(%S*)%s*(.-)$")
    command = string.lower(command or "")
    rest = (rest or ""):match("^%s*(.-)%s*$") or ""

    if command == "" then
        addon:Open()
    elseif command == "apply" then
        addon:ApplyCurrentRules("slash", true)
    elseif command == "status" then
        addon:PrintStatus()
    elseif command == "overrides" or command == "dungeons" or command == "dungeon" then
        addon:ToggleDungeonOverrides()
    elseif command == "spec" or command == "specialization" then
        local specValue = string.lower(rest)
        if specValue == "on" or specValue == "1" or specValue == "true" or specValue == "ligado" then
            DB.autoSpec = true
        elseif specValue == "off" or specValue == "0" or specValue == "false" or specValue == "desligado" then
            DB.autoSpec = false
            addon:ClearPendingSpecSwitch()
        else
            DB.autoSpec = not DB.autoSpec
            if not DB.autoSpec then addon:ClearPendingSpecSwitch() end
        end
        addon:UpdateAll()
        Print(DB.autoSpec and T("AUTO_SPEC_ON_CONFIRM") or T("AUTO_SPEC_OFF_CONFIRM"), true)
        if DB.autoSpec then addon:ApplyCurrentRules("slash-spec", false) end
    elseif command == "chat" or command == "messages" then
        local chatValue = string.lower(rest)
        if chatValue == "on" or chatValue == "1" or chatValue == "true" or chatValue == "ligado" then
            DB.chatMessages = true
        elseif chatValue == "off" or chatValue == "0" or chatValue == "false" or chatValue == "desligado" then
            DB.chatMessages = false
        else
            DB.chatMessages = not DB.chatMessages
        end
        addon:UpdateAll()
        Print(DB.chatMessages and T("CHAT_MESSAGES_ON_CONFIRM") or T("CHAT_MESSAGES_OFF_CONFIRM"), true)
    elseif command == "language" or command == "lang" or command == "idioma" then
        local languageValue = string.lower(rest)
        if languageValue == "" then
            addon:ToggleLanguagePicker()
        elseif languageValue == "auto" or languageValue == "wow" then
            addon:SetLanguageOverride("auto")
        elseif languageValue == "pt" or languageValue == "ptbr" or languageValue == "portuguese" or languageValue == "portugues" then
            addon:SetLanguageOverride("ptBR")
        elseif languageValue == "en" or languageValue == "enus" or languageValue == "engb" or languageValue == "english" then
            addon:SetLanguageOverride("enUS")
        else
            addon:ToggleLanguagePicker()
        end
    elseif command == "resetpos" then
        addon:ResetPositions()
    elseif command == "debug" then
        DB.debug = not DB.debug
        Print(DB.debug and T("DEBUG_ON") or T("DEBUG_OFF"), true)
    else
        Print(T("HELP"), true)
    end
end
