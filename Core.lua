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
local lootSpecPicker
local dungeonOverrideFrame
local raidBossOverrideFrame
local notifyFrame
local transferFrame
local contextButtons = {}
local pageButtons = {}
local activeRaidBossKey
local lastRaidBossTargetKey
local dismissedNotifyKey
local manualApplyPending = false
local notifyApplyKinds
local notifyApplyRuleKey
local ClearNotificationApply
local IsExplicitApplyKind
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
local pendingLootSpecID
local pendingLootSpecRuleKey
local pendingLootSpecIsRestore = false
local lootSpecRetryElapsed = 0
local lastLootSpecError
local activeLootSpecOverrideKey
local lootSpecRestoreID
local lastLoggedRuleSignature
local lastLoggedNotifyKey

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
    schema = 5,
    firstRun = true,
    selectedContext = "world",
    autoSpec = true,
    autoTalents = true,
    autoGear = true,
    automationModes = {
        spec = "auto",
        talents = "auto",
        gear = "auto",
        lootSpec = "auto",
    },
    chatMessages = true,
    debug = false,
    languageOverride = "auto",
    specBindings = {},
    talentBindings = {},
    equipmentBindings = {},
    dungeonOverrides = {},
    knownDungeons = {},
    selectedDungeonKey = nil,
    raidBossOverrides = {},
    knownRaidBosses = {},
    selectedRaidBossKey = nil,
    selectedRaidBossRaidKey = "all",
    raidBossConfiguredOnly = false,
    selectedPage = "general",
    eventLog = {},
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

local EVENT_LOG_LIMIT = 80

local function AppendEventLog(kind, message)
    if not DB then return end
    DB.eventLog = type(DB.eventLog) == "table" and DB.eventLog or {}
    local stamp = time and time() or 0
    kind = tostring(kind or "info")
    message = tostring(message or "")
    if message == "" then return end

    local last = DB.eventLog[#DB.eventLog]
    if type(last) == "table" and tostring(last.kind or "info") == kind and tostring(last.message or "") == message then
        last.time = stamp
        last.count = (tonumber(last.count) or 1) + 1
        return
    end

    table.insert(DB.eventLog, { time = stamp, kind = kind, message = message, count = 1 })
    while #DB.eventLog > EVENT_LOG_LIMIT do table.remove(DB.eventLog, 1) end
end

local function CompactEventLog()
    if not DB then return end
    local source = type(DB.eventLog) == "table" and DB.eventLog or {}
    local compact = {}
    for _, row in ipairs(source) do
        if type(row) == "table" then
            local kind = tostring(row.kind or "info")
            local message = tostring(row.message or "")
            local skip = kind == "apply" or (kind == "debug" and DB.debug ~= true) or message == ""
            if not skip then
                local count = math.max(1, tonumber(row.count) or 1)
                local last = compact[#compact]
                if last and last.kind == kind and last.message == message then
                    last.time = row.time or last.time
                    last.count = (tonumber(last.count) or 1) + count
                else
                    table.insert(compact, { time = row.time or 0, kind = kind, message = message, count = count })
                end
            end
        end
    end
    while #compact > EVENT_LOG_LIMIT do table.remove(compact, 1) end
    DB.eventLog = compact
end

local function Debug(message)
    if DB and DB.debug then
        AppendEventLog("debug", message)
        Print("|cff999999[debug]|r " .. tostring(message), true)
    end
end

local AUTOMATION_MODE_ORDER = { "auto", "notify", "off" }
local function NormalizeAutomationMode(value, legacyEnabled)
    value = string.lower(tostring(value or ""))
    if value == "auto" or value == "notify" or value == "off" then return value end
    if legacyEnabled == false then return "off" end
    return "auto"
end

local function AutomationModeLabel(mode)
    mode = NormalizeAutomationMode(mode, true)
    if mode == "notify" then return T("MODE_NOTIFY") end
    if mode == "off" then return T("MODE_OFF") end
    return T("MODE_AUTO")
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

function addon:GetLootSpecializationID()
    if not GetLootSpecialization then return nil end
    local ok, specID = pcall(GetLootSpecialization)
    if not ok or IsSecret(specID) then return nil end
    specID = tonumber(specID)
    if specID == nil or specID < 0 then return nil end
    return specID
end

function addon:GetLootSpecDisplayName(specID)
    specID = tonumber(specID)
    if specID == nil then return T("NO_LOOT_OVERRIDE") end
    if specID == 0 then
        local _, currentName = self:GetSpecInfo()
        return T("CURRENT_SPECIALIZATION_LOOT", currentName or T("UNKNOWN"))
    end
    return self:GetSpecDisplayName(specID)
end

function addon:ClearPendingLootSpecChange()
    pendingLootSpecID = nil
    pendingLootSpecRuleKey = nil
    pendingLootSpecIsRestore = false
    lootSpecRetryElapsed = 0
    lastLootSpecError = nil
end

function addon:RequestLootSpecialization(targetSpecID, ruleKey, isRestore, reason)
    targetSpecID = tonumber(targetSpecID)
    if targetSpecID == nil then return true end
    if not GetLootSpecialization or not SetLootSpecialization then
        self:ClearPendingLootSpecChange()
        lastLootSpecError = T("LOOT_SPEC_UNAVAILABLE")
        return false
    end

    local current = self:GetLootSpecializationID()
    if current == targetSpecID then
        self:ClearPendingLootSpecChange()
        return true
    end

    pendingLootSpecID = targetSpecID
    pendingLootSpecRuleKey = ruleKey
    pendingLootSpecIsRestore = isRestore == true
    lootSpecRetryElapsed = 0

    local ok = pcall(SetLootSpecialization, targetSpecID)
    if not ok then
        lastLootSpecError = T("LOOT_SPEC_FAILED")
        AppendEventLog("warning", "Loot spec request failed: " .. tostring(self:GetLootSpecDisplayName(targetSpecID)))
        Debug("Loot specialization request failed for reason " .. tostring(reason))
        return false
    end

    local updated = self:GetLootSpecializationID()
    if updated == targetSpecID then
        local label = self:GetLootSpecDisplayName(targetSpecID)
        local restored = pendingLootSpecIsRestore
        self:ClearPendingLootSpecChange()
        AppendEventLog("loot", (restored and "Restored " or "Switched to ") .. tostring(label))
        Print(restored and T("LOOT_SPEC_RESTORED", label) or T("LOOT_SPEC_SWITCHED", label))
        return true
    end

    lastLootSpecError = T("LOOT_SPEC_APPLYING")
    Debug("Loot specialization request pending for reason " .. tostring(reason))
    return false
end

function addon:SyncLootSpecializationRule(rule, reason, userInitiated)
    rule = rule or self:ResolveRuntimeRule(userInitiated == true)
    local hasLootOverride = rule and rule.lootSpecID ~= nil and rule.lootOverrideKey ~= nil
    local mode = self:GetAutomationMode("lootSpec")
    local allowed = userInitiated == true or mode == "auto"

    if hasLootOverride and allowed then
        if not activeLootSpecOverrideKey then
            lootSpecRestoreID = self:GetLootSpecializationID()
        end
        activeLootSpecOverrideKey = rule.lootOverrideKey
        return self:RequestLootSpecialization(rule.lootSpecID, rule.ruleKey, false, reason)
    end

    -- If automation is disabled/notifying after Loadout Pilot previously
    -- changed loot spec, return the player to the pre-override value.
    if activeLootSpecOverrideKey and (not hasLootOverride or not allowed) then
        local restoreID = lootSpecRestoreID
        if restoreID == nil then
            activeLootSpecOverrideKey = nil
            self:ClearPendingLootSpecChange()
            return true
        end

        local restored = self:RequestLootSpecialization(restoreID, "restore:" .. tostring(activeLootSpecOverrideKey), true, reason)
        if restored then
            activeLootSpecOverrideKey = nil
            lootSpecRestoreID = nil
        end
        return restored
    end

    self:ClearPendingLootSpecChange()
    return true
end

function addon:GetAutomationMode(kind)
    if not DB then return "auto" end
    DB.automationModes = type(DB.automationModes) == "table" and DB.automationModes or {}
    local legacy = true
    if kind == "spec" then legacy = DB.autoSpec ~= false
    elseif kind == "talents" then legacy = DB.autoTalents ~= false
    elseif kind == "gear" then legacy = DB.autoGear ~= false
    end
    local mode = NormalizeAutomationMode(DB.automationModes[kind], legacy)
    DB.automationModes[kind] = mode
    return mode
end

function addon:SetAutomationMode(kind, mode, quiet, deferApply)
    if not DB then return end
    if kind ~= "spec" and kind ~= "talents" and kind ~= "gear" and kind ~= "lootSpec" then return end
    mode = NormalizeAutomationMode(mode, true)
    DB.automationModes = type(DB.automationModes) == "table" and DB.automationModes or {}
    DB.automationModes[kind] = mode
    -- Keep the old booleans synchronized for compatibility with existing code,
    -- saved variables, and older releases. NOTIFY intentionally behaves like
    -- disabled for the automatic execution path.
    if kind == "spec" then DB.autoSpec = mode == "auto" end
    if kind == "talents" then DB.autoTalents = mode == "auto" end
    if kind == "gear" then DB.autoGear = mode == "auto" end

    -- Changing a mode invalidates any previous one-click confirmation and any
    -- queued automatic work for that category. Otherwise an old pending action
    -- could still fire after the player explicitly chose NOTIFY or OFF.
    if ClearNotificationApply then ClearNotificationApply() end
    manualApplyPending = false
    if mode ~= "auto" then
        if kind == "spec" then
            self:ClearPendingSpecSwitch()
        elseif kind == "talents" then
            self:ClearPendingTalentSwitch()
        elseif kind == "gear" then
            pendingGearKey = nil
            gearRetryElapsed = 0
            lastGearError = nil
        elseif kind == "lootSpec" then
            self:ClearPendingLootSpecChange()
        end
    end

    dismissedNotifyKey = nil
    AppendEventLog("mode", tostring(kind) .. "=" .. tostring(mode))
    if not quiet then Print(T("AUTOMATION_MODE_CHANGED", T("AUTOMATION_" .. string.upper(kind)), AutomationModeLabel(mode)), true) end
    if deferApply then return end
    self:UpdateAll()
    if mode == "auto" then
        self:ApplyCurrentRules("automation-mode", false)
    elseif kind == "lootSpec" then
        -- If Loadout Pilot previously changed Loot Spec in AUTO, changing the
        -- mode must immediately restore the pre-override setting rather than
        -- leaving the old automatic choice active indefinitely.
        self:ApplyCurrentRules("automation-mode", false)
    end
end

function addon:CycleAutomationMode(kind)
    local current = self:GetAutomationMode(kind)
    local nextMode = "auto"
    for index, value in ipairs(AUTOMATION_MODE_ORDER) do
        if value == current then nextMode = AUTOMATION_MODE_ORDER[(index % #AUTOMATION_MODE_ORDER) + 1]; break end
    end
    self:SetAutomationMode(kind, nextMode)
end

function addon:IsAutomationAuto(kind)
    return self:GetAutomationMode(kind) == "auto"
end

function addon:IsAutomationNotify(kind)
    return self:GetAutomationMode(kind) == "notify"
end

function addon:GetAssignedGroupRole()
    if not UnitGroupRolesAssigned then return nil end
    local ok, role = pcall(UnitGroupRolesAssigned, "player")
    if not ok or IsSecret(role) then return nil end
    return NormalizeRoleToken(role)
end

-- Returns true when the player is definitely grouped, false when the player is
-- definitely solo, and nil only if the available group APIs cannot be read.
-- Role protection is intentionally disabled when solo: a player entering a
-- dungeon/raid alone must be free to switch from a DPS spec to Tank/Healer.
function addon:GetPlayerGroupedState()
    if IsInGroup then
        local ok, grouped = pcall(IsInGroup)
        if ok and not IsSecret(grouped) then
            return grouped == true
        end
    end

    if IsInRaid then
        local ok, grouped = pcall(IsInRaid)
        if ok and not IsSecret(grouped) and grouped == true then
            return true
        end
    end

    if GetNumGroupMembers then
        local ok, count = pcall(GetNumGroupMembers)
        if ok and not IsSecret(count) and type(count) == "number" then
            return count > 0
        end
    end

    return nil
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
    local grouped = self:GetPlayerGroupedState()
    local protectedContext = self:IsRoleProtectionContext(context)

    -- If we can positively identify the player as solo, there is no assigned
    -- group role to protect. If group state is unknown, stay conservative and
    -- preserve the previous safety behavior.
    local protected = protectedContext and grouped ~= false
    local expectedRole = protected and (assignedRole or currentRole) or nil
    local mismatch = protected and expectedRole and targetRole and expectedRole ~= targetRole or false

    return {
        protected = protected,
        grouped = grouped,
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
    local inInstance, instanceType = IsInInstance()

    -- Midnight 12.1 Lairs share the C_DelvesUI API family with Delves. A Lair
    -- can therefore also expose an active Delve-style signal. Always ask the
    -- dedicated location API first so World Boss Lairs use the Raid rule.
    if C_DelvesUI and C_DelvesUI.IsInLair then
        local inLair = SafeBooleanCall(C_DelvesUI.IsInLair)
        if inLair == true then
            return "raid"
        end
    end

    -- Midnight 12.x exposes HasActiveDelve as the primary current-location
    -- signal used by Blizzard UI. Keep the Delve context for the full visit,
    -- including the post-completion reward/chest phase.
    if C_DelvesUI and C_DelvesUI.HasActiveDelve then
        local hasActiveDelve = SafeBooleanCall(C_DelvesUI.HasActiveDelve)
        if hasActiveDelve == true then
            return "delve"
        end
    end

    -- Compatibility/fallback path. IsDelveInProgress becomes false as soon as
    -- the Delve is completed, while the player can still be inside collecting
    -- rewards. IsDelveComplete covers that state, but only trust it while the
    -- player is physically inside a scenario so a stale completion flag can
    -- never pin the context to Delve after returning to the world.
    if C_PartyInfo then
        if C_PartyInfo.IsDelveInProgress then
            local inDelve = SafeBooleanCall(C_PartyInfo.IsDelveInProgress)
            if inDelve == true then
                return "delve"
            end
        end

        if inInstance and instanceType == "scenario" and C_PartyInfo.IsDelveComplete then
            local delveComplete = SafeBooleanCall(C_PartyInfo.IsDelveComplete)
            if delveComplete == true then
                return "delve"
            end
        end
    end

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

function addon:GetChallengeDungeonIdentity(challengeMapID)
    challengeMapID = tonumber(challengeMapID)
    if not challengeMapID or not C_ChallengeMode or not C_ChallengeMode.GetMapUIInfo then return nil end

    local okInfo, name, returnedID, _, _, _, uiMapID = pcall(C_ChallengeMode.GetMapUIInfo, challengeMapID)
    if not okInfo then return nil end

    local identity = {
        name = name or T("UNKNOWN"),
        challengeMapID = tonumber(returnedID) or challengeMapID,
        uiMapID = tonumber(uiMapID),
    }

    -- Since 11.2 GetMapUIInfo exposes the dungeon UiMapID. Resolve it through
    -- the Encounter Journal so Mythic+ and Normal/Heroic/Mythic 0 share the
    -- same stable InstanceID key instead of becoming duplicate overrides.
    if identity.uiMapID and EJ_GetInstanceForMap and EJ_GetInstanceInfo then
        local okJournal, journalInstanceID = pcall(EJ_GetInstanceForMap, identity.uiMapID)
        if okJournal and journalInstanceID then
            local okJournalInfo, _, _, _, _, _, _, _, _, _, instanceMapID = pcall(EJ_GetInstanceInfo, journalInstanceID)
            if okJournalInfo then identity.instanceID = tonumber(instanceMapID) end
        end
    end

    -- Compatibility fallback: if the player has already visited the dungeon,
    -- reuse the remembered InstanceID by localized name.
    if not identity.instanceID and DB and type(DB.knownDungeons) == "table" and name then
        for rawID, knownName in pairs(DB.knownDungeons) do
            if tostring(knownName) == tostring(name) then
                local instanceID = tonumber(rawID)
                if instanceID and instanceID > 0 then
                    identity.instanceID = instanceID
                    break
                end
            end
        end
    end

    return identity
end

function addon:GetCurrentDungeonInfo()
    local context = self:DetectContext()
    if context ~= "dungeon" and context ~= "mythicplus" then return nil end
    if not GetInstanceInfo then return nil end

    local ok, name, instanceType, difficultyID, difficultyName, _, _, _, instanceID = pcall(GetInstanceInfo)
    if not ok or instanceType ~= "party" then return nil end

    instanceID = tonumber(instanceID)
    if not instanceID or instanceID <= 0 then return nil end

    if DB and type(DB.knownDungeons) == "table" then
        DB.knownDungeons[tostring(instanceID)] = name or T("UNKNOWN")
    end

    -- Find the ChallengeMode identity even while running Normal/Heroic/Mythic 0.
    -- The context still stays separate so the correct Dungeon or Mythic+ default
    -- is inherited, but the dungeon-specific override key remains the same.
    local challengeMapID = self:GetMythicPlusMapID() or self:FindChallengeMapIDByName(name)
    local displayName = name
    if challengeMapID and C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
        local okInfo, mapName = pcall(C_ChallengeMode.GetMapUIInfo, challengeMapID)
        if okInfo and mapName then displayName = mapName end
    end

    local canonicalKey = "dungeon:" .. tostring(instanceID)
    -- If the catalog could not resolve the InstanceID before the player visited
    -- this dungeon, migrate any old mplus:<challengeID> rule now. This makes
    -- the first Normal/Heroic/Mythic 0 entry immediately reuse the same rule.
    if challengeMapID and DB and self.MigrateLegacyDungeonOverride then
        self:MigrateLegacyDungeonOverride(challengeMapID, instanceID, displayName)
    end

    return {
        key = canonicalKey,
        name = displayName or T("UNKNOWN"),
        context = context,
        instanceID = instanceID,
        challengeMapID = tonumber(challengeMapID),
        supportsMythicPlus = challengeMapID ~= nil,
        difficultyID = tonumber(difficultyID),
        difficultyName = difficultyName,
    }
end

function addon:GetDungeonCatalog()
    local result, seen = {}, {}
    local function add(entry)
        if not entry or not entry.key then return end
        local existing = seen[entry.key]
        if existing then
            if (not existing.name or existing.name == T("UNKNOWN")) and entry.name then existing.name = entry.name end
            existing.instanceID = existing.instanceID or entry.instanceID
            existing.challengeMapID = existing.challengeMapID or entry.challengeMapID
            existing.uiMapID = existing.uiMapID or entry.uiMapID
            existing.supportsMythicPlus = existing.supportsMythicPlus or entry.supportsMythicPlus
            if entry.isCurrent then
                existing.isCurrent = true
                existing.context = entry.context or existing.context
            end
            return
        end
        seen[entry.key] = entry
        table.insert(result, entry)
    end

    if C_ChallengeMode and C_ChallengeMode.GetMapTable and C_ChallengeMode.GetMapUIInfo then
        local ok, ids = pcall(C_ChallengeMode.GetMapTable)
        if ok and type(ids) == "table" then
            for _, challengeMapID in ipairs(ids) do
                local identity = self:GetChallengeDungeonIdentity(challengeMapID)
                if identity and identity.name then
                    local key
                    if identity.instanceID then
                        key = "dungeon:" .. tostring(identity.instanceID)
                    else
                        -- Emergency compatibility fallback. On modern Retail the
                        -- Encounter Journal path above resolves the InstanceID.
                        key = "mplus:" .. tostring(identity.challengeMapID)
                    end
                    add({
                        key = key,
                        name = identity.name,
                        context = "mythicplus",
                        challengeMapID = identity.challengeMapID,
                        uiMapID = identity.uiMapID,
                        instanceID = identity.instanceID,
                        supportsMythicPlus = true,
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
    if current then
        current.isCurrent = true
        add(current)
    end

    table.sort(result, function(a, b)
        return string.lower(tostring(a.name)) < string.lower(tostring(b.name))
    end)
    return result
end

function addon:GetDungeonCatalogEntry(key)
    if not key then return nil end
    for _, entry in ipairs(self:GetDungeonCatalog()) do
        if entry.key == key then return entry end
    end

    -- Allow a saved 1.1.0-1.1.2 selection using mplus:<challengeID> to resolve
    -- immediately to the new unified dungeon:<instanceID> entry.
    local challengeMapID = tostring(key):match("^mplus:(%d+)$")
    if challengeMapID then
        local identity = self:GetChallengeDungeonIdentity(tonumber(challengeMapID))
        if identity and identity.instanceID then
            local canonicalKey = "dungeon:" .. tostring(identity.instanceID)
            for _, entry in ipairs(self:GetDungeonCatalog()) do
                if entry.key == canonicalKey then return entry end
            end
        end
    end
    return nil
end

function addon:GetDungeonOverride(key)
    if not DB or type(DB.dungeonOverrides) ~= "table" or not key then return nil end
    local value = DB.dungeonOverrides[key]
    return type(value) == "table" and value or nil
end

function addon:GetDungeonOverrideForInfo(dungeonInfo)
    if not dungeonInfo then return nil end
    local override = self:GetDungeonOverride(dungeonInfo.key)
    if override then return override end

    -- Compatibility fallback if a legacy Mythic+ record could not be migrated
    -- yet because the instance mapping was unavailable during login.
    if dungeonInfo.challengeMapID then
        return self:GetDungeonOverride("mplus:" .. tostring(dungeonInfo.challengeMapID))
    end
    return nil
end

function addon:GetDungeonFallbackContext(entry)
    if not entry then return "dungeon" end
    local current = self:GetCurrentDungeonInfo()
    if current and current.key == entry.key then return current.context end
    if entry.supportsMythicPlus or entry.context == "mythicplus" then return "mythicplus" end
    return "dungeon"
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
    override.challengeMapID = entry.challengeMapID or override.challengeMapID
    override.instanceID = entry.instanceID or override.instanceID
    override.context = nil
    return override
end

local function MergeDungeonOverrideRecord(target, source, sourceWins)
    if type(target) ~= "table" then target = {} end
    if type(source) ~= "table" then return target end

    local function mergeField(field)
        if source[field] ~= nil and (sourceWins or target[field] == nil) then target[field] = source[field] end
    end
    mergeField("specID")
    mergeField("lootSpecID")
    mergeField("talent")
    mergeField("equipment")
    if source.name and (sourceWins or not target.name) then target.name = source.name end
    if source.instanceID and (sourceWins or not target.instanceID) then target.instanceID = source.instanceID end
    if source.challengeMapID and (sourceWins or not target.challengeMapID) then target.challengeMapID = source.challengeMapID end
    target.context = nil
    return target
end

function addon:MigrateLegacyDungeonOverride(challengeMapID, instanceID, name)
    if not DB or type(DB.dungeonOverrides) ~= "table" then return false end
    challengeMapID = tonumber(challengeMapID)
    instanceID = tonumber(instanceID)
    if not challengeMapID or not instanceID or instanceID <= 0 then return false end

    local oldKey = "mplus:" .. tostring(challengeMapID)
    local legacy = DB.dungeonOverrides[oldKey]
    if type(legacy) ~= "table" then return false end

    local newKey = "dungeon:" .. tostring(instanceID)
    local target = MergeDungeonOverrideRecord(DB.dungeonOverrides[newKey], legacy, true)
    target.name = name or target.name
    target.instanceID = instanceID
    target.challengeMapID = challengeMapID
    target.context = nil
    DB.dungeonOverrides[newKey] = target
    DB.dungeonOverrides[oldKey] = nil
    if DB.selectedDungeonKey == oldKey then DB.selectedDungeonKey = newKey end
    if DB.knownDungeons and name then DB.knownDungeons[tostring(instanceID)] = name end
    return true
end

function addon:MigrateUnifiedDungeonOverrides()
    if not DB or type(DB.dungeonOverrides) ~= "table" then return end

    local moves = {}
    for key, override in pairs(DB.dungeonOverrides) do
        local challengeMapID = tostring(key):match("^mplus:(%d+)$")
        if challengeMapID and type(override) == "table" then
            local identity = self:GetChallengeDungeonIdentity(tonumber(challengeMapID))
            if identity and identity.instanceID then
                table.insert(moves, {
                    oldKey = key,
                    newKey = "dungeon:" .. tostring(identity.instanceID),
                    identity = identity,
                    override = override,
                })
            end
        end
    end

    for _, move in ipairs(moves) do
        -- The old Mythic+ record was the more specific rule in pre-final-1.1.2,
        -- so prefer its explicitly configured fields if both legacy entries exist.
        self:MigrateLegacyDungeonOverride(move.identity.challengeMapID, move.identity.instanceID, move.identity.name)
    end
end

local function SplitString(value, sep)
    local out = {}
    value = tostring(value or "")
    sep = tostring(sep or "|")
    local start = 1
    while true do
        local pos = string.find(value, sep, start, true)
        if not pos then
            table.insert(out, string.sub(value, start))
            break
        end
        table.insert(out, string.sub(value, start, pos - 1))
        start = pos + #sep
    end
    return out
end

local function SafeUnitGUID(unit)
    if not UnitGUID then return nil end
    local ok, value = pcall(UnitGUID, unit)
    if not ok or value == nil or IsSecret(value) then return nil end
    return value
end

local function SafeUnitName(unit)
    -- Midnight 12.1 can mark hostile unit identity as secret in restricted
    -- states. Try the available name helpers, but never require a readable
    -- name when we already have a stable creature ID.
    local function tryName(func, ...)
        if type(func) ~= "function" then return nil end
        local ok, value = pcall(func, ...)
        if not ok or value == nil or IsSecret(value) then return nil end
        value = tostring(value)
        if value == "" then return nil end
        return value
    end

    return tryName(UnitNameUnmodified, unit)
        or tryName(UnitName, unit)
        or tryName(GetUnitName, unit, false)
end

function addon:GetUnitCreatureID(unit)
    unit = unit or "target"
    if UnitCreatureID then
        local ok, creatureID = pcall(UnitCreatureID, unit)
        if ok and not IsSecret(creatureID) then
            creatureID = tonumber(creatureID)
            if creatureID and creatureID > 0 then return creatureID end
        end
    end
    local guid = SafeUnitGUID(unit)
    if not guid then return nil end
    local parts = SplitString(guid, "-")
    if parts[1] ~= "Creature" and parts[1] ~= "Vehicle" then return nil end
    local creatureID = tonumber(parts[6])
    return creatureID and creatureID > 0 and creatureID or nil
end

function addon:IsInsideRaidInstance()
    if self:DetectContext() == "raid" then return true end

    -- Legacy raids can occasionally be queried during a transition where
    -- IsInInstance/DetectContext has not settled yet. GetInstanceInfo is a
    -- useful fallback for the manual boss-selection workflow.
    if GetInstanceInfo then
        local ok, _, instanceType = pcall(GetInstanceInfo)
        if ok and instanceType == "raid" then return true end
    end

    if IsInInstance then
        local ok, inInstance, instanceType = pcall(IsInInstance)
        if ok and AccessibleBoolean(inInstance) == true and instanceType == "raid" then return true end
    end
    return false
end

function addon:GetRaidInstanceIdentity()
    local raidName = T("CONTEXT_RAID")
    local instanceID
    if GetInstanceInfo then
        local ok, name, instanceType, _, _, _, _, _, rawInstanceID = pcall(GetInstanceInfo)
        if ok and instanceType == "raid" then
            if name then raidName = tostring(name) end
            instanceID = tonumber(rawInstanceID)
        end
    end
    return raidName, instanceID
end

function addon:GetCurrentRaidJournalInstanceID()
    if not self:IsInsideRaidInstance() then return nil end

    -- Fast path for modern raids: resolve the Encounter Journal instance from
    -- the player's current UiMapID. This does not rely on hostile-unit identity.
    if EJ_GetInstanceForMap and C_Map and C_Map.GetBestMapForUnit then
        local okMap, value = pcall(C_Map.GetBestMapForUnit, "player")
        local uiMapID = okMap and not IsSecret(value) and tonumber(value) or nil
        if uiMapID then
            local okJournal, journalInstanceID = pcall(EJ_GetInstanceForMap, uiMapID)
            if okJournal and not IsSecret(journalInstanceID) then
                journalInstanceID = tonumber(journalInstanceID)
                if journalInstanceID and journalInstanceID > 0 then return journalInstanceID end
            end
        end
    end

    -- Some legacy raid maps do not have a useful dungeon-area UiMapID. Fall
    -- back to matching the public InstanceID from GetInstanceInfo() against the
    -- Encounter Journal's raid instances across tiers. Restore the player's
    -- previous journal tier afterwards so opening Loadout Pilot does not leave
    -- the Blizzard Encounter Journal in a different expansion.
    local _, raidInstanceID = self:GetRaidInstanceIdentity()
    raidInstanceID = tonumber(raidInstanceID)
    if not raidInstanceID or not EJ_GetInstanceByIndex or not EJ_GetNumTiers or not EJ_SelectTier then return nil end

    local previousTier
    if EJ_GetCurrentTier then
        local okTier, tier = pcall(EJ_GetCurrentTier)
        if okTier and not IsSecret(tier) then previousTier = tonumber(tier) end
    end

    local okCount, tierCount = pcall(EJ_GetNumTiers)
    tierCount = okCount and not IsSecret(tierCount) and tonumber(tierCount) or nil
    if not tierCount then return nil end

    local found
    for tierIndex = 1, tierCount do
        if pcall(EJ_SelectTier, tierIndex) then
            for instanceIndex = 1, 100 do
                local ok, journalInstanceID, _, _, _, _, _, _, _, _, _, mapInstanceID, _, isRaid = pcall(EJ_GetInstanceByIndex, instanceIndex, true)
                if not ok or not journalInstanceID then break end
                if not IsSecret(journalInstanceID) and not IsSecret(mapInstanceID) and not IsSecret(isRaid) then
                    journalInstanceID = tonumber(journalInstanceID)
                    mapInstanceID = tonumber(mapInstanceID)
                    if journalInstanceID and mapInstanceID == raidInstanceID and (isRaid == nil or AccessibleBoolean(isRaid) ~= false) then
                        found = journalInstanceID
                        break
                    end
                end
            end
        end
        if found then break end
    end

    if previousTier then pcall(EJ_SelectTier, previousTier) end
    return found
end

function addon:DiscoverCurrentRaidBossesFromJournal()
    if not DB or not self:IsInsideRaidInstance() then return 0 end
    if not EJ_SelectInstance or not EJ_GetEncounterInfoByIndex then return 0 end

    local journalInstanceID = self:GetCurrentRaidJournalInstanceID()
    if not journalInstanceID then return 0 end

    local okSelect = pcall(EJ_SelectInstance, journalInstanceID)
    if not okSelect then return 0 end

    local raidName, raidInstanceID = self:GetRaidInstanceIdentity()
    local count = 0
    for index = 1, 50 do
        local ok, name, _, journalEncounterID, _, _, returnedJournalInstanceID, dungeonEncounterID, encounterInstanceID = pcall(EJ_GetEncounterInfoByIndex, index, journalInstanceID)
        if not ok or not name or not journalEncounterID then break end
        if IsSecret(name) or IsSecret(journalEncounterID) or IsSecret(dungeonEncounterID) then break end

        name = tostring(name)
        journalEncounterID = tonumber(journalEncounterID)
        dungeonEncounterID = tonumber(dungeonEncounterID)
        local key
        if dungeonEncounterID and dungeonEncounterID > 0 then
            key = "encounter:" .. tostring(dungeonEncounterID)
        elseif journalEncounterID and journalEncounterID > 0 then
            key = "journal:" .. tostring(journalEncounterID)
        end

        if key then
            local info = {
                key = key,
                encounterID = dungeonEncounterID,
                journalEncounterID = journalEncounterID,
                journalInstanceID = tonumber(returnedJournalInstanceID) or journalInstanceID,
                raidInstanceID = tonumber(encounterInstanceID) or raidInstanceID,
                name = name,
                raidName = raidName,
                isLikelyBoss = true,
                fromJournal = true,
            }
            -- Migrate any old target/NPC-keyed override for the same named boss
            -- onto the stable DungeonEncounterID key used by ENCOUNTER_START.
            self:GetRaidBossOverrideForInfo(info, true)
            self:RememberRaidBoss(info, true)
            count = count + 1
        end
    end
    return count
end

function addon:IsLikelyRaidBossUnit(unit)
    if not self:IsInsideRaidInstance() then return false end
    unit = unit or "target"
    if UnitExists then
        local ok, exists = pcall(UnitExists, unit)
        if ok and AccessibleBoolean(exists) == false then return false end
    end

    local targetGUID = SafeUnitGUID(unit)
    if targetGUID then
        for index = 1, 8 do
            local bossGUID = SafeUnitGUID("boss" .. tostring(index))
            if bossGUID and bossGUID == targetGUID then return true end
        end
    end

    if UnitClassification then
        local ok, classification = pcall(UnitClassification, unit)
        if ok and not IsSecret(classification) and classification == "worldboss" then return true end
    end
    if UnitLevel then
        local ok, level = pcall(UnitLevel, unit)
        if ok and not IsSecret(level) and tonumber(level) and tonumber(level) < 0 then return true end
    end
    return false
end

function addon:GetRaidName()
    return select(1, self:GetRaidInstanceIdentity())
end

local function NormalizeRaidBossIdentity(value)
    return string.lower((tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")))
end

function addon:BuildRaidBossNameKey(name, raidName, instanceID)
    local scope = instanceID and tostring(instanceID) or NormalizeRaidBossIdentity(raidName)
    return "bossname:" .. tostring(scope or "raid") .. ":" .. NormalizeRaidBossIdentity(name)
end

function addon:FindRaidBossOverrideKeyByIdentity(name, raidName)
    if not DB or type(DB.raidBossOverrides) ~= "table" or not name then return nil end
    local wantedName = NormalizeRaidBossIdentity(name)
    local wantedRaid = NormalizeRaidBossIdentity(raidName)
    for key, row in pairs(DB.raidBossOverrides) do
        if type(row) == "table" then
            local rowName = NormalizeRaidBossIdentity(row.name)
            local rowRaid = NormalizeRaidBossIdentity(row.raidName)
            if rowName == wantedName and (wantedRaid == "" or rowRaid == "" or rowRaid == wantedRaid) then
                return key
            end
        end
    end
    return nil
end

function addon:GetRaidBossOverrideForInfo(info, migrateToStableIdentity)
    if not info or not info.key then return nil end
    local direct = self:GetRaidBossOverride(info.key)
    if direct then return direct end

    local oldKey = self:FindRaidBossOverrideKeyByIdentity(info.name, info.raidName)
    if not oldKey then return nil end
    local value = self:GetRaidBossOverride(oldKey)
    if not value then return nil end

    -- Earlier 2.0 test builds keyed boss rules by hostile-unit NPC identity.
    -- Midnight 12.1 intentionally makes creature names/GUIDs/IDs secret inside
    -- instances, so encounter IDs from the Encounter Journal/ENCOUNTER_START
    -- are now the stable identity. Migrate older matching rules by name.
    local hasStableIdentity = info.encounterID or info.journalEncounterID or info.npcID
    if migrateToStableIdentity and hasStableIdentity and oldKey ~= info.key and DB and type(DB.raidBossOverrides) == "table" then
        DB.raidBossOverrides[info.key] = value
        DB.raidBossOverrides[oldKey] = nil
        value.npcID = info.npcID or value.npcID
        value.encounterID = info.encounterID or value.encounterID
        value.journalEncounterID = info.journalEncounterID or value.journalEncounterID
        value.journalInstanceID = info.journalInstanceID or value.journalInstanceID
        value.raidInstanceID = info.raidInstanceID or value.raidInstanceID
        value.name = info.name or value.name
        value.raidName = info.raidName or value.raidName
        if DB.knownRaidBosses and DB.knownRaidBosses[oldKey] then DB.knownRaidBosses[oldKey] = nil end
        self:RememberRaidBoss(info, true)
    end
    return value
end

function addon:GetRaidBossTargetInfo(allowAnyRaidCreature)
    if not self:IsInsideRaidInstance() then return nil end

    if UnitExists then
        local ok, exists = pcall(UnitExists, "target")
        if ok and AccessibleBoolean(exists) == false then return nil end
    end
    if UnitIsPlayer then
        local ok, isPlayer = pcall(UnitIsPlayer, "target")
        if ok and AccessibleBoolean(isPlayer) == true then return nil end
    end

    local raidName, raidInstanceID = self:GetRaidInstanceIdentity()
    local creatureID = self:GetUnitCreatureID("target")
    local name = SafeUnitName("target")
    local isLikelyBoss = self:IsLikelyRaidBossUnit("target")
    local key

    if creatureID then
        key = "boss:" .. tostring(creatureID)

        -- Do not make manual pre-pull selection depend on UnitName. In
        -- Midnight 12.1 the visible target name can be secret to addons while
        -- UnitCreatureID remains usable. Prefer saved metadata and use a stable
        -- NPC placeholder until ENCOUNTER_START gives us a public boss name.
        if not name and DB then
            local known = type(DB.knownRaidBosses) == "table" and DB.knownRaidBosses[key] or nil
            local override = type(DB.raidBossOverrides) == "table" and DB.raidBossOverrides[key] or nil
            if type(known) == "table" and known.name then name = tostring(known.name) end
            if not name and type(override) == "table" and override.name then name = tostring(override.name) end
        end
        if not name then name = "NPC " .. tostring(creatureID) end
    elseif name then
        -- Pre-pull/legacy fallback: some targets do not expose a usable NPC ID
        -- until combat. Manual selection must still work without fighting first.
        key = self:FindRaidBossOverrideKeyByIdentity(name, raidName)
            or self:BuildRaidBossNameKey(name, raidName, raidInstanceID)
    else
        -- Neither a stable creature ID nor a readable name is available. There
        -- is no durable identity we can safely save for a boss rule.
        return nil
    end

    local info = {
        key = key,
        npcID = creatureID,
        name = name,
        raidName = raidName,
        raidInstanceID = raidInstanceID,
        isLikelyBoss = isLikelyBoss,
    }
    local configured = self:GetRaidBossOverrideForInfo(info, creatureID ~= nil) ~= nil
    if not configured and not allowAnyRaidCreature and not isLikelyBoss then return nil end
    return info
end

function addon:GetRaidBossOverride(key)
    if not DB or type(DB.raidBossOverrides) ~= "table" or not key then return nil end
    local value = DB.raidBossOverrides[key]
    return type(value) == "table" and value or nil
end

function addon:GetRaidBossCatalog()
    local result, seenKeys, seenIdentity = {}, {}, {}

    local function normalize(value)
        return string.lower((tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")))
    end

    local function identity(entry)
        local name = normalize(entry and entry.name)
        if name == "" then return "key:" .. tostring(entry and entry.key or "") end
        return normalize(entry and entry.raidName) .. "\31" .. name
    end

    local function score(entry)
        local value = 0
        if entry and entry.key and self:GetRaidBossOverride(entry.key) then value = value + 100 end
        if entry and entry.isCurrent then value = value + 10 end
        if entry and entry.verified then value = value + 1 end
        return value
    end

    local function add(entry)
        if not entry or not entry.key or seenKeys[entry.key] then return end
        seenKeys[entry.key] = true

        -- Some encounters expose more than one creature ID for the same named
        -- boss. Keep only one visible row per raid/name, preferring an entry
        -- that already owns an override and then the current target.
        local id = identity(entry)
        local existingIndex = seenIdentity[id]
        if existingIndex then
            if score(entry) > score(result[existingIndex]) then
                result[existingIndex] = entry
            end
            return
        end

        table.insert(result, entry)
        seenIdentity[id] = #result
    end

    if DB and type(DB.knownRaidBosses) == "table" then
        for key, info in pairs(DB.knownRaidBosses) do
            if type(info) == "table" then
                add({
                    key = key,
                    npcID = tonumber(info.npcID) or tonumber(tostring(key):match("boss:(%d+)")),
                    encounterID = tonumber(info.encounterID) or tonumber(tostring(key):match("encounter:(%d+)")),
                    journalEncounterID = tonumber(info.journalEncounterID) or tonumber(tostring(key):match("journal:(%d+)")),
                    journalInstanceID = tonumber(info.journalInstanceID),
                    raidInstanceID = tonumber(info.raidInstanceID),
                    name = info.name,
                    raidName = info.raidName,
                    verified = info.verified == true,
                })
            end
        end
    end
    if DB and type(DB.raidBossOverrides) == "table" then
        for key, override in pairs(DB.raidBossOverrides) do
            if type(override) == "table" then
                add({
                    key = key,
                    npcID = tonumber(override.npcID) or tonumber(tostring(key):match("boss:(%d+)")),
                    encounterID = tonumber(override.encounterID) or tonumber(tostring(key):match("encounter:(%d+)")),
                    journalEncounterID = tonumber(override.journalEncounterID) or tonumber(tostring(key):match("journal:(%d+)")),
                    journalInstanceID = tonumber(override.journalInstanceID),
                    raidInstanceID = tonumber(override.raidInstanceID),
                    name = override.name,
                    raidName = override.raidName,
                    verified = true,
                })
            end
        end
    end
    table.sort(result, function(a,b)
        local ar, br = string.lower(tostring(a.raidName or "")), string.lower(tostring(b.raidName or ""))
        if ar ~= br then return ar < br end
        return string.lower(tostring(a.name or a.key)) < string.lower(tostring(b.name or b.key))
    end)
    return result
end

function addon:GetRaidBossRaidKey(entry)
    if type(entry) ~= "table" then return nil end
    local raidInstanceID = tonumber(entry.raidInstanceID)
    if raidInstanceID and raidInstanceID > 0 then
        return "instance:" .. tostring(raidInstanceID)
    end
    local journalInstanceID = tonumber(entry.journalInstanceID)
    if journalInstanceID and journalInstanceID > 0 then
        return "journal:" .. tostring(journalInstanceID)
    end
    local raidName = NormalizeRaidBossIdentity(entry.raidName)
    if raidName ~= "" then return "name:" .. raidName end
    return nil
end

function addon:GetRaidCatalog()
    local raidsByKey, result = {}, {}
    local currentRaidName, currentRaidInstanceID = self:GetRaidInstanceIdentity()
    local normalizedCurrentName = NormalizeRaidBossIdentity(currentRaidName)

    for _, boss in ipairs(self:GetRaidBossCatalog()) do
        local raidKey = self:GetRaidBossRaidKey(boss)
        if raidKey then
            local row = raidsByKey[raidKey]
            if not row then
                row = {
                    key = raidKey,
                    name = boss.raidName or T("CONTEXT_RAID"),
                    raidInstanceID = tonumber(boss.raidInstanceID),
                    journalInstanceID = tonumber(boss.journalInstanceID),
                    total = 0,
                    configured = 0,
                    isCurrent = false,
                }
                raidsByKey[raidKey] = row
                table.insert(result, row)
            end
            row.total = row.total + 1
            if self:GetRaidBossOverride(boss.key) then row.configured = row.configured + 1 end
            if self:IsInsideRaidInstance() then
                local sameID = currentRaidInstanceID and row.raidInstanceID and tonumber(currentRaidInstanceID) == tonumber(row.raidInstanceID)
                local sameName = normalizedCurrentName ~= "" and NormalizeRaidBossIdentity(row.name) == normalizedCurrentName
                if sameID or sameName then row.isCurrent = true end
            end
        end
    end

    table.sort(result, function(a, b)
        if a.isCurrent ~= b.isCurrent then return a.isCurrent == true end
        return NormalizeRaidBossIdentity(a.name) < NormalizeRaidBossIdentity(b.name)
    end)
    return result
end

function addon:GetCurrentRaidCatalogKey()
    if not self:IsInsideRaidInstance() then return nil end
    local raidName, raidInstanceID = self:GetRaidInstanceIdentity()
    local normalizedName = NormalizeRaidBossIdentity(raidName)
    for _, raid in ipairs(self:GetRaidCatalog()) do
        if raidInstanceID and raid.raidInstanceID and tonumber(raidInstanceID) == tonumber(raid.raidInstanceID) then
            return raid.key
        end
        if normalizedName ~= "" and NormalizeRaidBossIdentity(raid.name) == normalizedName then
            return raid.key
        end
    end
    return raidInstanceID and ("instance:" .. tostring(raidInstanceID)) or (normalizedName ~= "" and ("name:" .. normalizedName) or nil)
end

function addon:GetRaidBossConfigurationCounts(raidKey)
    local configured, total = 0, 0
    for _, entry in ipairs(self:GetRaidBossCatalog()) do
        if raidKey == nil or raidKey == "all" or self:GetRaidBossRaidKey(entry) == raidKey then
            total = total + 1
            if self:GetRaidBossOverride(entry.key) then configured = configured + 1 end
        end
    end
    return configured, total
end

function addon:GetFilteredRaidBossCatalog(raidKey, configuredOnly, searchText)
    raidKey = raidKey or "all"
    searchText = NormalizeRaidBossIdentity(searchText)
    local result = {}
    for _, entry in ipairs(self:GetRaidBossCatalog()) do
        local matchesRaid = raidKey == "all" or self:GetRaidBossRaidKey(entry) == raidKey
        local configured = self:GetRaidBossOverride(entry.key) ~= nil
        local haystack = NormalizeRaidBossIdentity(tostring(entry.name or "") .. " " .. tostring(entry.raidName or ""))
        local matchesSearch = searchText == "" or haystack:find(searchText, 1, true) ~= nil
        if matchesRaid and matchesSearch and (not configuredOnly or configured) then
            table.insert(result, entry)
        end
    end
    return result
end

function addon:GetRaidCatalogEntry(raidKey)
    if not raidKey or raidKey == "all" then return nil end
    for _, raid in ipairs(self:GetRaidCatalog()) do
        if raid.key == raidKey then return raid end
    end
    return nil
end

function addon:ClearRaidBossOverridesForRaid(raidKey)
    if not DB or not raidKey or raidKey == "all" then return 0 end
    DB.raidBossOverrides = type(DB.raidBossOverrides) == "table" and DB.raidBossOverrides or {}
    local selectedRaid = self:GetRaidCatalogEntry(raidKey)
    local selectedRaidName = NormalizeRaidBossIdentity(selectedRaid and selectedRaid.name)
    local removed, removedActive = 0, false
    for key, override in pairs(DB.raidBossOverrides) do
        if type(override) == "table" then
            local entry = {
                key = key,
                raidName = override.raidName,
                raidInstanceID = tonumber(override.raidInstanceID),
                journalInstanceID = tonumber(override.journalInstanceID),
            }
            local sameRaid = self:GetRaidBossRaidKey(entry) == raidKey
            if not sameRaid and selectedRaidName ~= "" then
                sameRaid = NormalizeRaidBossIdentity(override.raidName) == selectedRaidName
            end
            if sameRaid then
                DB.raidBossOverrides[key] = nil
                removed = removed + 1
                if activeRaidBossKey == key then removedActive = true end
            end
        end
    end
    if removedActive then activeRaidBossKey = nil end
    if removed > 0 then
        dismissedNotifyKey = nil
        AppendEventLog("boss", "Cleared " .. tostring(removed) .. " raid boss overrides for " .. tostring(raidKey))
        self:ApplyCurrentRules("raid-overrides-cleared", false)
    end
    return removed
end

function addon:GetRaidBossCatalogEntry(key)
    if not key then return nil end
    for _, entry in ipairs(self:GetRaidBossCatalog()) do if entry.key == key then return entry end end
    return nil
end

local function IsRaidBossPlaceholderName(name)
    name = tostring(name or "")
    return name == "" or name:match("^NPC %d+$") ~= nil
end

function addon:RememberRaidBoss(info, verified)
    if not DB or not info or not info.key then return end
    DB.knownRaidBosses = type(DB.knownRaidBosses) == "table" and DB.knownRaidBosses or {}
    local previous = DB.knownRaidBosses[info.key]

    local savedName = info.name
    if IsRaidBossPlaceholderName(savedName) and type(previous) == "table" and not IsRaidBossPlaceholderName(previous.name) then
        savedName = previous.name
    end

    DB.knownRaidBosses[info.key] = {
        npcID = info.npcID or (type(previous) == "table" and previous.npcID or nil),
        encounterID = info.encounterID or (type(previous) == "table" and previous.encounterID or nil),
        journalEncounterID = info.journalEncounterID or (type(previous) == "table" and previous.journalEncounterID or nil),
        journalInstanceID = info.journalInstanceID or (type(previous) == "table" and previous.journalInstanceID or nil),
        name = savedName,
        raidName = info.raidName or (type(previous) == "table" and previous.raidName or nil),
        raidInstanceID = info.raidInstanceID or (type(previous) == "table" and previous.raidInstanceID or nil),
        verified = verified == true or info.isLikelyBoss == true or (type(previous) == "table" and previous.verified == true),
    }

    -- If the boss was first configured while its name was secret, replace the
    -- temporary "NPC 123" label as soon as a real encounter/boss name becomes
    -- available. Keep the rule itself untouched.
    local override = type(DB.raidBossOverrides) == "table" and DB.raidBossOverrides[info.key] or nil
    if type(override) == "table" then
        if info.npcID then override.npcID = info.npcID end
        if info.encounterID then override.encounterID = info.encounterID end
        if info.journalEncounterID then override.journalEncounterID = info.journalEncounterID end
        if info.journalInstanceID then override.journalInstanceID = info.journalInstanceID end
        if info.raidInstanceID then override.raidInstanceID = info.raidInstanceID end
        if not IsRaidBossPlaceholderName(savedName) then override.name = savedName end
        if info.raidName then override.raidName = info.raidName end
    end
end

function addon:CleanupKnownRaidBosses()
    if not DB then return end
    DB.knownRaidBosses = type(DB.knownRaidBosses) == "table" and DB.knownRaidBosses or {}
    DB.raidBossOverrides = type(DB.raidBossOverrides) == "table" and DB.raidBossOverrides or {}

    -- Early 2.0 test builds could remember any targeted raid creature when the
    -- boss window opened, and ENCOUNTER_END could also contribute encounter
    -- helper/add NPCs. Remove those legacy unverified rows. Configured boss
    -- overrides are always preserved.
    for key, info in pairs(DB.knownRaidBosses) do
        local configured = type(DB.raidBossOverrides[key]) == "table"
        if type(info) ~= "table" then
            DB.knownRaidBosses[key] = nil
        elseif configured then
            info.verified = true
        elseif info.verified ~= true then
            DB.knownRaidBosses[key] = nil
        end
    end
end

function addon:SetRaidBossLootSpec(entry, specID)
    if not DB or not entry or not entry.key then return end
    DB.raidBossOverrides = type(DB.raidBossOverrides) == "table" and DB.raidBossOverrides or {}
    self:RememberRaidBoss(entry, true)
    local override = DB.raidBossOverrides[entry.key]
    if type(override) ~= "table" then override = {}; DB.raidBossOverrides[entry.key] = override end
    override.npcID = entry.npcID
    override.encounterID = entry.encounterID
    override.journalEncounterID = entry.journalEncounterID
    override.journalInstanceID = entry.journalInstanceID
    override.raidInstanceID = entry.raidInstanceID
    override.name = entry.name
    override.raidName = entry.raidName
    override.lootSpecID = tonumber(specID)
    dismissedNotifyKey = nil
    AppendEventLog("boss", "Configured " .. tostring(entry.name) .. " loot=" .. tostring(specID))
    if raidBossOverrideFrame and raidBossOverrideFrame:IsShown() then self:UpdateRaidBossOverrideFrame() end
    if activeRaidBossKey == entry.key then self:ApplyCurrentRules("boss-config", false) end
end

function addon:RemoveRaidBossOverride(entry)
    if not DB or not entry or not entry.key then return end
    if type(DB.raidBossOverrides) == "table" then DB.raidBossOverrides[entry.key] = nil end
    if activeRaidBossKey == entry.key then activeRaidBossKey = nil end
    dismissedNotifyKey = nil
    AppendEventLog("boss", "Removed override " .. tostring(entry.name or entry.key))
    if raidBossOverrideFrame and raidBossOverrideFrame:IsShown() then self:UpdateRaidBossOverrideFrame() end
    self:ApplyCurrentRules("boss-override-removed", false)
end

function addon:ActivateRaidBoss(info, reason)
    if not info or not info.key then return false end
    self:RememberRaidBoss(info, true)
    local override = self:GetRaidBossOverrideForInfo(info, true)
    if not override or override.lootSpecID == nil then return false end
    if activeRaidBossKey ~= info.key then
        activeRaidBossKey = info.key
        dismissedNotifyKey = nil
        AppendEventLog("boss", "Activated " .. tostring(info.name) .. " -> loot " .. tostring(override.lootSpecID))
    end
    self:ApplyCurrentRules(reason or "raid-boss-target", false)
    return true
end

function addon:HandleRaidBossTarget(reason)
    if not DB then return end
    if not self:IsInsideRaidInstance() then
        if activeRaidBossKey then
            AppendEventLog("boss", "Left raid boss context")
            activeRaidBossKey = nil
            dismissedNotifyKey = nil
            self:ApplyCurrentRules(reason or "left-raid", false)
        end
        lastRaidBossTargetKey = nil
        return
    end

    local info = self:GetRaidBossTargetInfo(false)
    local targetKey = info and info.key or nil
    if targetKey == lastRaidBossTargetKey and targetKey == activeRaidBossKey then return end
    lastRaidBossTargetKey = targetKey
    if info then
        self:RememberRaidBoss(info, true)
        if self:ActivateRaidBoss(info, reason or "raid-boss-target") then return end
        -- If the player deliberately targets a different recognized boss that
        -- has no rule, stop carrying the previous boss's loot override.
        if info.isLikelyBoss and activeRaidBossKey then
            activeRaidBossKey = nil
            dismissedNotifyKey = nil
            self:ApplyCurrentRules("raid-boss-no-override", false)
        end
    end
end

function addon:HandleEncounterStart(encounterID, encounterName, difficultyID)
    if not self:IsInsideRaidInstance() then return end
    encounterID = tonumber(encounterID)
    if not encounterID then return end

    local raidName, raidInstanceID = self:GetRaidInstanceIdentity()
    local info = {
        key = "encounter:" .. tostring(encounterID),
        encounterID = encounterID,
        name = tostring(encounterName or ("Encounter " .. tostring(encounterID))),
        raidName = raidName,
        raidInstanceID = raidInstanceID,
        isLikelyBoss = true,
    }

    AppendEventLog("encounter", "START " .. tostring(encounterID) .. " " .. tostring(info.name) .. " diff=" .. tostring(difficultyID))
    local override = self:GetRaidBossOverrideForInfo(info, true)
    self:RememberRaidBoss(info, true)

    if override and override.lootSpecID ~= nil then
        self:ActivateRaidBoss(info, "encounter-start")
        return
    end

    -- Keep a previous boss loot spec after a kill for the bonus-roll window,
    -- but never let it leak into the next encounter. If the next boss has no
    -- override, restore the pre-boss loot spec as the encounter starts.
    if activeRaidBossKey then
        AppendEventLog("boss", "Encounter has no configured loot override; clearing previous boss rule")
        activeRaidBossKey = nil
        dismissedNotifyKey = nil
        self:ApplyCurrentRules("encounter-start-no-override", false)
    end
end

function addon:HandleEncounterEnd(encounterID, encounterName, difficultyID, groupSize, success, encounterUnitStatus)
    AppendEventLog("encounter", "END " .. tostring(encounterID) .. " " .. tostring(encounterName) .. " success=" .. tostring(success))
    -- Keep the active loot spec after the kill so a bonus-roll interaction
    -- cannot lose it. Boss identity is learned from the Encounter Journal and
    -- ENCOUNTER_START; encounterUnitStatus can contain helper/add NPCs and is
    -- intentionally not used to build the configurable boss catalog.
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
    local override = dungeonInfo and self:GetDungeonOverrideForInfo(dungeonInfo) or nil
    local baseSpecBinding = self:ResolveSpecBinding(context)

    local baseConfiguredSpecID = currentSpecID
    if baseSpecBinding and baseSpecBinding.specID then baseConfiguredSpecID = baseSpecBinding.specID end

    local configuredSpecID = baseConfiguredSpecID
    local specSource = baseSpecBinding and T("SOURCE_CONTEXT_DEFAULT", ContextName(context)) or T("SOURCE_CURRENT_PLAYER")
    if override and override.specID then
        configuredSpecID = override.specID
        specSource = T("SOURCE_DUNGEON_OVERRIDE")
    end

    local shouldAutomateSpec = self:IsAutomationAuto("spec") or userInitiated == true
    local runtimeSpecID = configuredSpecID
    if configuredSpecID ~= currentSpecID and not shouldAutomateSpec then
        runtimeSpecID = currentSpecID
    end

    local talentBinding
    local talentSource = T("SOURCE_CONTEXT_DEFAULT", ContextName(context))
    if override and override.talent then
        talentBinding = self:ResolveTalentRecord(runtimeSpecID, override.talent)
        if talentBinding then talentSource = T("SOURCE_DUNGEON_OVERRIDE") end
    end
    if not talentBinding then
        talentBinding = self:ResolveTalentBinding(runtimeSpecID, context)
        talentSource = talentBinding and T("SOURCE_CONTEXT_DEFAULT", ContextName(context)) or T("SOURCE_CURRENT_PLAYER")
    end

    local gearBinding, gearInfo
    local gearSource = T("SOURCE_CONTEXT_DEFAULT", ContextName(context))
    if override and override.equipment then
        gearBinding, gearInfo = self:ResolveEquipmentRecord(override.equipment)
        if gearBinding then gearSource = T("SOURCE_DUNGEON_OVERRIDE") end
    end
    if not gearBinding then
        gearBinding, gearInfo = self:ResolveEquipmentBinding(runtimeSpecID, context)
        gearSource = gearBinding and T("SOURCE_CONTEXT_DEFAULT", ContextName(context)) or T("SOURCE_CURRENT_PLAYER")
    end
    -- Equipment sets are not specialization-specific. If a dungeon override
    -- changes specialization but leaves Equipment on Inherit, allow the base
    -- context's equipment mapping to remain the inherited default.
    if not gearBinding and baseConfiguredSpecID and baseConfiguredSpecID ~= runtimeSpecID then
        gearBinding, gearInfo = self:ResolveEquipmentBinding(baseConfiguredSpecID, context)
        gearSource = gearBinding and T("SOURCE_CONTEXT_DEFAULT", ContextName(context)) or T("SOURCE_CURRENT_PLAYER")
    end

    local bossOverride, bossInfo
    if context == "raid" and activeRaidBossKey then
        bossOverride = self:GetRaidBossOverride(activeRaidBossKey)
        bossInfo = self:GetRaidBossCatalogEntry(activeRaidBossKey)
        if not bossInfo and bossOverride then
            bossInfo = {
                key = activeRaidBossKey,
                npcID = bossOverride.npcID,
                name = bossOverride.name,
                raidName = bossOverride.raidName,
            }
        end
    end

    local lootSpecID, lootOverrideKey, lootSource
    if bossOverride and bossOverride.lootSpecID ~= nil then
        lootSpecID = bossOverride.lootSpecID
        lootOverrideKey = activeRaidBossKey
        lootSource = T("SOURCE_RAID_BOSS_OVERRIDE")
    elseif override and override.lootSpecID ~= nil and dungeonInfo then
        lootSpecID = override.lootSpecID
        lootOverrideKey = dungeonInfo.key
        lootSource = T("SOURCE_DUNGEON_OVERRIDE")
    else
        lootSource = T("SOURCE_CURRENT_PLAYER")
    end

    local sourceKey = dungeonInfo and override and dungeonInfo.key or ("context:" .. tostring(context))
    if bossOverride and bossOverride.lootSpecID ~= nil then sourceKey = sourceKey .. ":" .. tostring(activeRaidBossKey) end

    return {
        currentSpecID = currentSpecID,
        currentSpecName = currentSpecName,
        context = context,
        dungeonInfo = dungeonInfo,
        override = override,
        raidBossInfo = bossInfo,
        raidBossOverride = bossOverride,
        configuredSpecID = configuredSpecID,
        runtimeSpecID = runtimeSpecID,
        shouldAutomateSpec = shouldAutomateSpec == true,
        talentBinding = talentBinding,
        gearBinding = gearBinding,
        gearInfo = gearInfo,
        lootSpecID = lootSpecID,
        lootOverrideKey = lootOverrideKey,
        roleState = self:GetRoleProtectionState(configuredSpecID, context, currentSpecID),
        sources = {
            spec = specSource,
            lootSpec = lootSource,
            talents = talentSource,
            gear = gearSource,
        },
        -- Stable identity for UI confirmations. ruleKey intentionally follows the
        -- runtime spec because pending talent/gear operations are spec-sensitive,
        -- while identityKey must survive a NOTIFY-confirmed spec change.
        identityKey = sourceKey .. ":" .. tostring(configuredSpecID or currentSpecID or 0),
        ruleKey = sourceKey .. ":" .. tostring(runtimeSpecID or 0),
    }
end

function addon:GetRuleEventSignature(rule)
    if not rule then return "none" end
    local dungeonKey = rule.dungeonInfo and rule.dungeonInfo.key or "-"
    local bossKey = rule.raidBossInfo and rule.raidBossInfo.key or "-"
    local talentID = rule.talentBinding and rule.talentBinding.configID or 0
    local gearID = rule.gearBinding and rule.gearBinding.setID or 0
    local lootID = rule.lootSpecID
    if lootID == nil then lootID = "-" end
    return table.concat({
        tostring(rule.context or "unknown"),
        tostring(dungeonKey),
        tostring(bossKey),
        tostring(rule.configuredSpecID or 0),
        tostring(rule.runtimeSpecID or 0),
        tostring(lootID),
        tostring(talentID),
        tostring(gearID),
    }, "|")
end

function addon:LogResolvedRuleEvent(rule)
    if not rule then return end
    local signature = self:GetRuleEventSignature(rule)
    if signature == lastLoggedRuleSignature then return end
    lastLoggedRuleSignature = signature

    local location = tostring(rule.context or "unknown")
    if rule.dungeonInfo and rule.dungeonInfo.name then
        location = location .. "/" .. tostring(rule.dungeonInfo.name)
    elseif rule.raidBossInfo and rule.raidBossInfo.name then
        location = location .. "/" .. tostring(rule.raidBossInfo.name)
    end

    local source = rule.raidBossOverride and "raid-boss" or (rule.override and "dungeon-override" or "context")
    local specName = self:GetSpecNameByID(rule.configuredSpecID) or "-"
    local lootName = rule.lootSpecID ~= nil and self:GetLootSpecDisplayName(rule.lootSpecID) or "-"
    local talentName = rule.talentBinding and (self:GetTalentName(rule.talentBinding.configID) or rule.talentBinding.name) or "-"
    local gearName = rule.gearInfo and rule.gearInfo.name or (rule.gearBinding and rule.gearBinding.name) or "-"
    AppendEventLog("rule", string.format("%s source=%s spec=%s loot=%s talents=%s gear=%s", location, source, tostring(specName), tostring(lootName), tostring(talentName), tostring(gearName)))
end

function addon:GetContextDetailLabel(rule)
    rule = rule or self:ResolveRuntimeRule(false)
    if not rule then return ContextName(self:DetectContext()) end
    local label = ContextName(rule.context)
    if rule.dungeonInfo and rule.dungeonInfo.difficultyName then
        label = label .. " - " .. tostring(rule.dungeonInfo.difficultyName)
    end
    return label
end

function addon:GetRuleExplanationLines()
    local rule = self:ResolveRuntimeRule(false)
    if not rule then return { T("EXPLAIN_NO_RULE") } end
    local lines = {}
    table.insert(lines, T("EXPLAIN_CONTEXT", self:GetContextDetailLabel(rule)))
    if rule.dungeonInfo then table.insert(lines, T("EXPLAIN_DUNGEON", tostring(rule.dungeonInfo.name))) end
    if rule.raidBossInfo then table.insert(lines, T("EXPLAIN_BOSS", tostring(rule.raidBossInfo.name or T("UNKNOWN")))) end

    local specName = self:GetSpecNameByID(rule.configuredSpecID) or T("UNKNOWN")
    table.insert(lines, T("EXPLAIN_FIELD", T("SPECIALIZATION"), specName, rule.sources and rule.sources.spec or T("UNKNOWN")))

    local lootName = rule.lootSpecID ~= nil and self:GetLootSpecDisplayName(rule.lootSpecID) or T("NO_LOOT_OVERRIDE")
    table.insert(lines, T("EXPLAIN_FIELD", T("LOOT_SPECIALIZATION"), lootName, rule.sources and rule.sources.lootSpec or T("UNKNOWN")))

    local talentName = rule.talentBinding and (self:GetTalentName(rule.talentBinding.configID) or rule.talentBinding.name) or T("NO_MAPPING")
    table.insert(lines, T("EXPLAIN_FIELD", T("TALENTS"), talentName, rule.sources and rule.sources.talents or T("UNKNOWN")))

    local gearName = rule.gearInfo and rule.gearInfo.name or (rule.gearBinding and rule.gearBinding.name) or T("NO_MAPPING")
    table.insert(lines, T("EXPLAIN_FIELD", T("GEAR"), gearName, rule.sources and rule.sources.gear or T("UNKNOWN")))
    return lines
end

function addon:PrintExplain()
    Print(T("EXPLAIN_TITLE"), true)
    for _, line in ipairs(self:GetRuleExplanationLines()) do Print(line, true) end
end

function addon:GetRecentEventLogText(limit)
    limit = tonumber(limit) or 12
    if not DB or type(DB.eventLog) ~= "table" or #DB.eventLog == 0 then return T("EVENT_LOG_EMPTY") end
    local lines = {}
    local first = math.max(1, #DB.eventLog - limit + 1)
    for index = first, #DB.eventLog do
        local row = DB.eventLog[index]
        local timeText = "--:--:--"
        if row and row.time and date then
            local ok, formatted = pcall(date, "%H:%M:%S", row.time)
            if ok and formatted then timeText = formatted end
        end
        local count = tonumber(row and row.count) or 1
        local repeatText = count > 1 and (" (x" .. tostring(count) .. ")") or ""
        table.insert(lines, string.format("%s [%s] %s%s", timeText, tostring(row and row.kind or "info"), tostring(row and row.message or ""), repeatText))
    end
    return table.concat(lines, "\n")
end

local function ConfigEscape(value)
    value = tostring(value or "")
    value = value:gsub("%%", "%%25")
    value = value:gsub("|", "%%7C")
    value = value:gsub("\r", "%%0D")
    value = value:gsub("\n", "%%0A")
    return value
end

local function ConfigUnescape(value)
    value = tostring(value or "")
    value = value:gsub("%%0A", "\n")
    value = value:gsub("%%0D", "\r")
    value = value:gsub("%%7[Cc]", "|")
    value = value:gsub("%%25", "%%")
    return value
end

function addon:ExportConfiguration()
    if not DB then return "" end
    local _, classFile, classID = UnitClass and UnitClass("player") or nil, nil, nil
    if UnitClass then _, classFile, classID = UnitClass("player") end
    local lines = { table.concat({ "LP2", "1", tostring(classID or 0), ConfigEscape(classFile or "") }, "|") }

    for _, kind in ipairs({ "spec", "talents", "gear", "lootSpec" }) do
        table.insert(lines, table.concat({ "MODE", kind, self:GetAutomationMode(kind) }, "|"))
    end
    for _, context in ipairs(Data.contextOrder) do
        local row = DB.specBindings and DB.specBindings[context]
        if type(row) == "table" and row.specID then
            table.insert(lines, table.concat({ "SPEC", context, tostring(row.specID), ConfigEscape(row.name) }, "|"))
        end
    end
    for key, row in pairs(DB.talentBindings or {}) do
        if type(row) == "table" and row.configID then
            table.insert(lines, table.concat({ "TAL", ConfigEscape(key), tostring(row.configID), ConfigEscape(row.name) }, "|"))
        end
    end
    for key, row in pairs(DB.equipmentBindings or {}) do
        if type(row) == "table" and row.setID then
            table.insert(lines, table.concat({ "GEAR", ConfigEscape(key), tostring(row.setID), ConfigEscape(row.name) }, "|"))
        end
    end
    for key, row in pairs(DB.dungeonOverrides or {}) do
        if type(row) == "table" then
            table.insert(lines, table.concat({
                "DUN", ConfigEscape(key), ConfigEscape(row.name), tostring(row.instanceID or ""), tostring(row.challengeMapID or ""),
                tostring(row.specID or ""), row.lootSpecID ~= nil and tostring(row.lootSpecID) or "",
                row.talent and tostring(row.talent.specID or "") or "", row.talent and tostring(row.talent.configID or "") or "", row.talent and ConfigEscape(row.talent.name) or "",
                row.equipment and tostring(row.equipment.setID or "") or "", row.equipment and ConfigEscape(row.equipment.name) or ""
            }, "|"))
        end
    end
    for key, row in pairs(DB.raidBossOverrides or {}) do
        if type(row) == "table" then
            table.insert(lines, table.concat({
                "BOSS", ConfigEscape(key), tostring(row.npcID or ""), ConfigEscape(row.name), ConfigEscape(row.raidName),
                row.lootSpecID ~= nil and tostring(row.lootSpecID) or "", tostring(row.encounterID or ""),
                tostring(row.journalEncounterID or ""), tostring(row.raidInstanceID or ""), tostring(row.journalInstanceID or "")
            }, "|"))
        end
    end
    AppendEventLog("export", "Configuration exported")
    return table.concat(lines, "\n")
end

function addon:ImportConfiguration(text)
    text = tostring(text or "")
    local lines = {}
    for line in text:gmatch("[^\r\n]+") do table.insert(lines, line) end
    if #lines == 0 then return false, T("IMPORT_INVALID") end
    local header = SplitString(lines[1], "|")
    if header[1] ~= "LP2" or header[2] ~= "1" then return false, T("IMPORT_INVALID") end
    local _, classFile, classID = UnitClass and UnitClass("player") or nil, nil, nil
    if UnitClass then _, classFile, classID = UnitClass("player") end
    local importedClassID = tonumber(header[3]) or 0
    if importedClassID > 0 and classID and importedClassID ~= classID then return false, T("IMPORT_CLASS_MISMATCH") end

    local newSpec, newTalents, newGear, newDungeons, newBosses = {}, {}, {}, {}, {}
    local modes = {
        spec = self:GetAutomationMode("spec"), talents = self:GetAutomationMode("talents"),
        gear = self:GetAutomationMode("gear"), lootSpec = self:GetAutomationMode("lootSpec"),
    }
    local knownDungeons, knownBosses = {}, {}

    for index = 2, #lines do
        local f = SplitString(lines[index], "|")
        if f[1] == "MODE" and modes[f[2]] then
            modes[f[2]] = NormalizeAutomationMode(f[3], true)
        elseif f[1] == "SPEC" and Data.contextLabelKeys[f[2]] and tonumber(f[3]) then
            newSpec[f[2]] = { specID = tonumber(f[3]), name = ConfigUnescape(f[4]) }
        elseif f[1] == "TAL" and f[2] and tonumber(f[3]) then
            newTalents[ConfigUnescape(f[2])] = { configID = tonumber(f[3]), name = ConfigUnescape(f[4]) }
        elseif f[1] == "GEAR" and f[2] and tonumber(f[3]) then
            newGear[ConfigUnescape(f[2])] = { setID = tonumber(f[3]), name = ConfigUnescape(f[4]) }
        elseif f[1] == "DUN" and f[2] then
            local key = ConfigUnescape(f[2])
            local row = { name = ConfigUnescape(f[3]), instanceID = tonumber(f[4]), challengeMapID = tonumber(f[5]), specID = tonumber(f[6]) }
            if f[7] ~= "" then row.lootSpecID = tonumber(f[7]) end
            if f[9] ~= "" then row.talent = { specID = tonumber(f[8]), configID = tonumber(f[9]), name = ConfigUnescape(f[10]) } end
            if f[11] ~= "" then row.equipment = { setID = tonumber(f[11]), name = ConfigUnescape(f[12]) } end
            newDungeons[key] = row
            if row.instanceID and row.name ~= "" then knownDungeons[tostring(row.instanceID)] = row.name end
        elseif f[1] == "BOSS" and f[2] then
            local key = ConfigUnescape(f[2])
            local row = {
                npcID = tonumber(f[3]), name = ConfigUnescape(f[4]), raidName = ConfigUnescape(f[5]),
                encounterID = tonumber(f[7]), journalEncounterID = tonumber(f[8]),
                raidInstanceID = tonumber(f[9]), journalInstanceID = tonumber(f[10]),
            }
            if f[6] ~= "" then row.lootSpecID = tonumber(f[6]) end
            newBosses[key] = row
            knownBosses[key] = {
                npcID = row.npcID, encounterID = row.encounterID, journalEncounterID = row.journalEncounterID,
                raidInstanceID = row.raidInstanceID, journalInstanceID = row.journalInstanceID,
                name = row.name, raidName = row.raidName, verified = true
            }
        end
    end

    DB.specBindings = newSpec
    DB.talentBindings = newTalents
    DB.equipmentBindings = newGear
    DB.dungeonOverrides = newDungeons
    DB.raidBossOverrides = newBosses
    for key, value in pairs(knownDungeons) do DB.knownDungeons[key] = value end
    for key, value in pairs(knownBosses) do DB.knownRaidBosses[key] = value end
    for kind, mode in pairs(modes) do self:SetAutomationMode(kind, mode, true, true) end
    activeRaidBossKey = nil
    dismissedNotifyKey = nil
    self:ClearPendingSpecSwitch()
    self:ClearPendingTalentSwitch()
    self:ClearPendingLootSpecChange()
    pendingGearKey = nil
    AppendEventLog("import", "Configuration imported")
    self:UpdateAll()
    self:ApplyCurrentRules("import", false)
    return true, T("IMPORT_SUCCESS")
end

function addon:GetDungeonOverrideEffectiveSpecID(entry)
    if not entry then return select(1, self:GetSpecInfo()) end
    local override = self:GetDungeonOverride(entry.key)
    if override and override.specID then return override.specID end
    local fallbackContext = self:GetDungeonFallbackContext(entry)
    local base = self:ResolveSpecBinding(fallbackContext)
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
            AppendEventLog("spec", "Switched to " .. tostring(name))
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
            AppendEventLog("blocked", "Spec " .. tostring(targetName) .. " blocked by role " .. tostring(expectedLabel) .. " -> " .. tostring(targetLabel))
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
        AppendEventLog("queued", "Spec " .. tostring(specInfo and specInfo.name or targetSpecID) .. " waiting for combat to end")
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
    AppendEventLog("warning", "Spec switch failed: " .. tostring(specInfo and specInfo.name or targetSpecID))
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
        AppendEventLog("talents", "Switched to " .. tostring(binding.name))
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
            addon:TrySwitchTalents("talent-watch-fallback", IsExplicitApplyKind("talents"), true)
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
        AppendEventLog("queued", "Talents " .. tostring(binding.name or binding.configID) .. " waiting for combat to end")
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
                AppendEventLog("warning", "Talent switch failed: " .. tostring(lastTalentError))
                return false
            end
        end
    end

    pendingTalentInProgress = false
    lastTalentError = T("TALENT_FAILED")
    AppendEventLog("warning", "Talent switch failed: " .. tostring(binding and (binding.name or binding.configID) or "unknown"))
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
        AppendEventLog("queued", "Gear " .. tostring((info and info.name) or binding.name or binding.setID) .. " waiting for combat to end")
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
    AppendEventLog("warning", "Gear switch failed: " .. tostring((info and info.name) or binding.name or binding.setID))
    Debug("Equipment switch failed for reason " .. tostring(reason))
    return false
end

function addon:ApplyCurrentRules(reason, userInitiated)
    local applyReason = reason or "apply"
    if userInitiated == true then
        manualApplyPending = true
        ClearNotificationApply()
    end
    local forceAll = userInitiated == true or manualApplyPending == true
    local forceSpec = forceAll or (notifyApplyKinds and notifyApplyKinds.spec == true)
    local forceLoot = forceAll or (notifyApplyKinds and notifyApplyKinds.lootSpec == true)
    local forceTalents = forceAll or (notifyApplyKinds and notifyApplyKinds.talents == true)
    local forceGear = forceAll or (notifyApplyKinds and notifyApplyKinds.gear == true)

    -- Validate a NOTIFY confirmation against the stable rule identity before
    -- resolving the forced runtime spec. Using ruleKey here used to cancel the
    -- confirmation immediately because ruleKey changes from the current spec to
    -- the requested spec as soon as Apply is pressed.
    local identityRule = self:ResolveRuntimeRule(false)
    local identityKey = identityRule and (identityRule.identityKey or identityRule.ruleKey) or nil
    if notifyApplyKinds and notifyApplyRuleKey and identityKey ~= notifyApplyRuleKey and not pendingSpecID then
        -- A confirmation belongs to the rule the player saw. Do not carry it
        -- into a different context/boss after a transition.
        ClearNotificationApply()
        forceSpec, forceLoot, forceTalents, forceGear = forceAll, forceAll, forceAll, forceAll
    end
    local preRule = self:ResolveRuntimeRule(forceSpec)
    self:LogResolvedRuleEvent(preRule)
    if userInitiated == true then
        AppendEventLog("manual", "Apply mapped loadout requested")
    end

    local specReady = self:TrySwitchSpecialization(applyReason, forceSpec)
    local rule = self:ResolveRuntimeRule(forceSpec)

    -- Loot specialization is independent from the specialization used to play
    -- the content. Raid-boss encounter rules intentionally affect only loot spec.
    self:SyncLootSpecializationRule(rule, applyReason, forceLoot)

    if not specReady then
        self:ScheduleUpdate()
        return
    end
    self:TrySwitchTalents(applyReason, forceTalents)
    self:TrySwitchEquipment(applyReason, forceGear)

    if not pendingSpecID and not pendingTalentKey and not pendingGearKey and pendingLootSpecID == nil then
        manualApplyPending = false
        ClearNotificationApply()
    end
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
    if lootSpecPicker then lootSpecPicker:Hide() end
    if languagePicker then languagePicker:Hide() end
end

local PICKER_FRAME_LEVEL = 1200

local function CreatePicker(name, parent, width)
    local frame = CreateFrame("Frame", name, parent, "BackdropTemplate")
    frame:SetSize(width or 300, 260)
    -- Dungeon Overrides uses FULLSCREEN_DIALOG at level 900. Popups must be
    -- above that panel or their rows render behind it and only peek out below.
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(PICKER_FRAME_LEVEL)
    frame:SetClampedToScreen(true)
    if frame.SetToplevel then frame:SetToplevel(true) end
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

function addon:PopulateLootSpecPicker(onSelect)
    if not lootSpecPicker then return end
    local list = self:GetSpecList()
    local currentLootSpecID = self:GetLootSpecializationID()
    for _, row in ipairs(lootSpecPicker.rows) do row:Hide() end

    local rowIndex = 1
    local y = -7
    local currentRow = lootSpecPicker.rows[rowIndex] or CreateButton(lootSpecPicker, "", 286, 26)
    lootSpecPicker.rows[rowIndex] = currentRow
    currentRow:ClearAllPoints()
    currentRow:SetPoint("TOPLEFT", lootSpecPicker, "TOPLEFT", 7, y)
    currentRow.text:SetText((currentLootSpecID == 0 and "|cff66ff99* |r" or "") .. T("CURRENT_SPECIALIZATION_LOOT_SHORT"))
    currentRow:SetScript("OnClick", function()
        lootSpecPicker:Hide()
        if onSelect then onSelect(0) end
    end)
    currentRow:Show()
    y = y - 28

    for _, entry in ipairs(list) do
        rowIndex = rowIndex + 1
        local row = lootSpecPicker.rows[rowIndex] or CreateButton(lootSpecPicker, "", 286, 26)
        lootSpecPicker.rows[rowIndex] = row
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", lootSpecPicker, "TOPLEFT", 7, y)
        local selected = currentLootSpecID == entry.specID
        row.text:SetText((selected and "|cff66ff99* |r" or "") .. addon:GetSpecDisplayName(entry.specID))
        row:SetScript("OnClick", function()
            lootSpecPicker:Hide()
            if onSelect then onSelect(entry.specID) end
        end)
        row:Show()
        y = y - 28
    end
    lootSpecPicker:SetHeight(math.min(260, 14 + (rowIndex * 28)))
end

function addon:ShowTalentPicker(anchor, specID, onSelect)
    if gearPicker then gearPicker:Hide() end
    if specPicker then specPicker:Hide() end
    if lootSpecPicker then lootSpecPicker:Hide() end
    self:PopulateTalentPicker(specID, onSelect)
    talentPicker:ClearAllPoints()
    talentPicker:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
    talentPicker:SetShown(not talentPicker:IsShown())
end

function addon:ShowGearPicker(anchor, onSelect)
    if talentPicker then talentPicker:Hide() end
    if specPicker then specPicker:Hide() end
    if lootSpecPicker then lootSpecPicker:Hide() end
    self:PopulateGearPicker(onSelect)
    gearPicker:ClearAllPoints()
    gearPicker:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
    gearPicker:SetShown(not gearPicker:IsShown())
end

function addon:ShowSpecPicker(anchor, onSelect, includeInherit)
    if talentPicker then talentPicker:Hide() end
    if gearPicker then gearPicker:Hide() end
    if lootSpecPicker then lootSpecPicker:Hide() end
    self:PopulateSpecPicker(onSelect, includeInherit)
    specPicker:ClearAllPoints()
    specPicker:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
    specPicker:SetShown(not specPicker:IsShown())
end

function addon:ShowLootSpecPicker(anchor, onSelect)
    if talentPicker then talentPicker:Hide() end
    if gearPicker then gearPicker:Hide() end
    if specPicker then specPicker:Hide() end
    self:PopulateLootSpecPicker(onSelect)
    lootSpecPicker:ClearAllPoints()
    lootSpecPicker:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
    lootSpecPicker:SetShown(not lootSpecPicker:IsShown())
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

function addon:GetNotificationRecommendation()
    if not DB then return nil end
    local rule = self:ResolveRuntimeRule(false)
    if not rule then return nil end
    local items = {}
    local kinds = {}
    local keyParts = { tostring(rule.identityKey or rule.ruleKey) }
    local currentSpecID = select(1, self:GetSpecInfo())

    if self:IsAutomationNotify("spec") and rule.configuredSpecID and currentSpecID ~= rule.configuredSpecID then
        local roleState = rule.roleState
        if not (roleState and roleState.mismatch) then
            local value = self:GetSpecNameByID(rule.configuredSpecID) or T("UNKNOWN")
            table.insert(items, T("NOTIFY_SPEC", value))
            kinds.spec = true
            table.insert(keyParts, "s=" .. tostring(rule.configuredSpecID))
        end
    end

    local currentLoot = self:GetLootSpecializationID()
    if self:IsAutomationNotify("lootSpec") and rule.lootSpecID ~= nil and currentLoot ~= rule.lootSpecID then
        local value = self:GetLootSpecDisplayName(rule.lootSpecID)
        table.insert(items, T("NOTIFY_LOOT_SPEC", value))
        kinds.lootSpec = true
        table.insert(keyParts, "l=" .. tostring(rule.lootSpecID))
    end

    if self:IsAutomationNotify("talents") and rule.talentBinding and rule.talentBinding.configID then
        local runtimeSpecID = rule.runtimeSpecID or currentSpecID
        if runtimeSpecID == currentSpecID then
            local currentTalent = self:GetSelectedTalentConfigID(runtimeSpecID)
            if currentTalent ~= rule.talentBinding.configID then
                local value = self:GetTalentName(rule.talentBinding.configID) or rule.talentBinding.name or T("UNKNOWN")
                table.insert(items, T("NOTIFY_TALENTS", value))
                kinds.talents = true
                table.insert(keyParts, "t=" .. tostring(rule.talentBinding.configID))
            end
        end
    end

    if self:IsAutomationNotify("gear") and rule.gearBinding and rule.gearBinding.setID then
        local _, info = self:ResolveEquipmentRecord(rule.gearBinding)
        if not (info and info.isEquipped) then
            local value = info and info.name or rule.gearBinding.name or T("UNKNOWN")
            table.insert(items, T("NOTIFY_GEAR", value))
            kinds.gear = true
            table.insert(keyParts, "g=" .. tostring(rule.gearBinding.setID))
        end
    end

    if #items == 0 then return nil end
    return {
        key = table.concat(keyParts, ";"),
        items = items,
        kinds = kinds,
        rule = rule,
    }
end

function addon:ApplyNotificationRecommendation(recommendation)
    recommendation = recommendation or self:GetNotificationRecommendation()
    if not recommendation or type(recommendation.kinds) ~= "table" then return end
    lastLoggedNotifyKey = recommendation.key
    notifyApplyKinds = {}
    for kind, enabled in pairs(recommendation.kinds) do
        if enabled then notifyApplyKinds[kind] = true end
    end
    notifyApplyRuleKey = recommendation.rule and (recommendation.rule.identityKey or recommendation.rule.ruleKey) or nil
    AppendEventLog("notify", "Confirmed recommendation " .. tostring(recommendation.key))
    self:ApplyCurrentRules("notify-apply", false)
end

ClearNotificationApply = function()
    notifyApplyKinds = nil
    notifyApplyRuleKey = nil
end

IsExplicitApplyKind = function(kind)
    return manualApplyPending == true or (notifyApplyKinds and notifyApplyKinds[kind] == true) or false
end

local function CreateNotifyFrame()
    local frame = CreateFrame("Frame", "LoadoutPilotNotifyFrame", UIParent, "BackdropTemplate")
    frame:SetSize(430, 118)
    frame:SetPoint("TOP", UIParent, "TOP", 0, -145)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    ApplyBackdrop(frame, 0.94)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.title:SetPoint("TOPLEFT", 14, -12)
    frame.title:SetText(T("NOTIFY_TITLE"))
    frame.title:SetTextColor(0.45, 0.88, 1)

    frame.message = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.message:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -8)
    frame.message:SetWidth(400)
    frame.message:SetJustifyH("LEFT")
    frame.message:SetJustifyV("TOP")

    frame.apply = CreateButton(frame, T("NOTIFY_APPLY"), 120, 26)
    frame.apply:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -142, 12)
    frame.apply:SetScript("OnClick", function()
        dismissedNotifyKey = nil
        frame:Hide()
        addon:ApplyNotificationRecommendation(frame.recommendation)
    end)

    frame.ignore = CreateButton(frame, T("NOTIFY_IGNORE"), 120, 26)
    frame.ignore:SetPoint("LEFT", frame.apply, "RIGHT", 8, 0)
    frame.ignore:SetScript("OnClick", function()
        if frame.recommendation then dismissedNotifyKey = frame.recommendation.key end
        lastLoggedNotifyKey = dismissedNotifyKey
        frame:Hide()
        AppendEventLog("notify", "Ignored recommendation " .. tostring(dismissedNotifyKey))
    end)

    frame:Hide()
    return frame
end

function addon:UpdateNotification()
    if not notifyFrame or not DB then return end
    -- Once Apply is accepted, keep the reminder out of the way while the
    -- confirmed operation is pending/retrying. It will naturally re-evaluate
    -- after the confirmed work completes or the context changes.
    if notifyApplyKinds then
        notifyFrame:Hide()
        return
    end
    local recommendation = self:GetNotificationRecommendation()
    if not recommendation or recommendation.key == dismissedNotifyKey then
        notifyFrame.recommendation = recommendation
        notifyFrame:Hide()
        if not recommendation then lastLoggedNotifyKey = nil end
        return
    end
    notifyFrame.recommendation = recommendation
    notifyFrame.title:SetText(T("NOTIFY_TITLE"))
    notifyFrame.message:SetText(table.concat(recommendation.items, "\n"))
    local height = 82 + (#recommendation.items * 16)
    notifyFrame:SetHeight(math.max(108, math.min(180, height)))
    notifyFrame:Show()
    if recommendation.key ~= lastLoggedNotifyKey then
        lastLoggedNotifyKey = recommendation.key
        AppendEventLog("notify", "Recommendation " .. recommendation.key)
    end
end

local function CreateMainFrame()
    local frame = CreateFrame("Frame", "LoadoutPilotMainFrame", UIParent, "BackdropTemplate")
    frame:SetSize(820, 610)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    ApplyBackdrop(frame, 0.98)
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOPLEFT", 18, -16)
    frame.title:SetText(T("ADDON_TITLE"))
    frame.title:SetTextColor(0.45, 0.88, 1)

    frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.subtitle:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -3)
    frame.subtitle:SetText(T("ADDON_SUBTITLE_V2"))

    frame.close = CreateButton(frame, "X", 28, 24)
    frame.close:SetPoint("TOPRIGHT", -12, -12)
    frame.close:SetScript("OnClick", function()
        HidePickers()
        if dungeonOverrideFrame then dungeonOverrideFrame:Hide() end
        if raidBossOverrideFrame then raidBossOverrideFrame:Hide() end
        frame:Hide()
    end)

    frame.version = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.version:SetPoint("BOTTOMRIGHT", -14, 10)
    frame.version:SetText(T("VERSION", Data.version))

    -- Sidebar navigation.
    local navKeys = { "general", "contexts", "dungeons", "raids", "automation", "hud", "advanced" }
    local navLabels = {
        general="PAGE_GENERAL", contexts="PAGE_CONTEXTS", dungeons="PAGE_DUNGEONS",
        raids="PAGE_RAID_BOSSES", automation="PAGE_AUTOMATION", hud="PAGE_HUD", advanced="PAGE_ADVANCED",
    }
    local navY = -72
    for _, key in ipairs(navKeys) do
        local button = CreateButton(frame, T(navLabels[key]), 138, 32)
        button:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, navY)
        button.pageKey = key
        button:SetScript("OnClick", function(self) addon:SetMainPage(self.pageKey) end)
        pageButtons[key] = button
        navY = navY - 38
    end

    frame.pages = {}
    local function CreatePage(key, titleKey, descKey)
        local page = CreateFrame("Frame", nil, frame)
        page:SetPoint("TOPLEFT", frame, "TOPLEFT", 168, -64)
        page:SetSize(632, 520)
        page.title = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        page.title:SetPoint("TOPLEFT", 0, 0)
        page.title:SetText(T(titleKey))
        page.description = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        page.description:SetPoint("TOPLEFT", page.title, "BOTTOMLEFT", 0, -7)
        page.description:SetWidth(610)
        page.description:SetJustifyH("LEFT")
        page.description:SetText(T(descKey))
        page:Hide()
        frame.pages[key] = page
        return page
    end

    -- General / live status page.
    local general = CreatePage("general", "PAGE_GENERAL", "PAGE_GENERAL_DESC")
    frame.currentIcon = general:CreateTexture(nil, "ARTWORK")
    frame.currentIcon:SetSize(46, 46)
    frame.currentIcon:SetPoint("TOPLEFT", general, "TOPLEFT", 0, -76)
    frame.currentIcon:SetTexCoord(0.08,0.92,0.08,0.92)
    frame.currentTitle = general:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.currentTitle:SetPoint("TOPLEFT", frame.currentIcon, "TOPRIGHT", 12, -1)
    frame.currentTitle:SetWidth(535); frame.currentTitle:SetJustifyH("LEFT")
    frame.currentContext = general:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.currentContext:SetPoint("TOPLEFT", frame.currentTitle, "BOTTOMLEFT", 0, -6)
    frame.currentContext:SetWidth(535); frame.currentContext:SetJustifyH("LEFT")
    general.slogan = general:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    general.slogan:SetPoint("TOPLEFT", general, "TOPLEFT", 0, -145)
    general.slogan:SetWidth(610); general.slogan:SetJustifyH("LEFT")
    general.slogan:SetText(T("SLOGAN_V2"))
    frame.ruleSummary = general:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.ruleSummary:SetPoint("TOPLEFT", general.slogan, "BOTTOMLEFT", 0, -18)
    frame.ruleSummary:SetWidth(610); frame.ruleSummary:SetJustifyH("LEFT"); frame.ruleSummary:SetJustifyV("TOP")
    frame.apply = CreateButton(general, T("APPLY_NOW"), 190, 30)
    frame.apply:SetPoint("BOTTOMLEFT", general, "BOTTOMLEFT", 0, 14)
    frame.apply:SetScript("OnClick", function() addon:ApplyCurrentRules("manual", true) end)
    general.explain = CreateButton(general, T("EXPLAIN_RULE"), 170, 30)
    general.explain:SetPoint("LEFT", frame.apply, "RIGHT", 8, 0)
    general.explain:SetScript("OnClick", function() addon:PrintExplain() end)
    general.log = CreateButton(general, T("VIEW_EVENT_LOG"), 170, 30)
    general.log:SetPoint("LEFT", general.explain, "RIGHT", 8, 0)
    general.log:SetScript("OnClick", function() addon:ShowTransferFrame("log") end)

    -- Context mappings page.
    local contexts = CreatePage("contexts", "PAGE_CONTEXTS", "PAGE_CONTEXTS_DESC")
    contexts.configureLabel = contexts:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    contexts.configureLabel:SetPoint("TOPLEFT", 0, -74); contexts.configureLabel:SetText(T("CONFIGURE_FOR"))
    local x = 0
    for _, context in ipairs(Data.contextOrder) do
        local button = CreateButton(contexts, ContextName(context), 96, 27)
        button:SetPoint("TOPLEFT", contexts, "TOPLEFT", x, -98)
        button.context = context
        button:SetScript("OnClick", function(self) DB.selectedContext=self.context; HidePickers(); addon:UpdateAll() end)
        contextButtons[context] = button
        x = x + 101
    end
    frame.specLabel = contexts:CreateFontString(nil,"OVERLAY","GameFontNormal"); frame.specLabel:SetPoint("TOPLEFT",0,-154); frame.specLabel:SetText(T("SPECIALIZATION"))
    frame.specValue = contexts:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); frame.specValue:SetPoint("TOPLEFT",0,-178); frame.specValue:SetWidth(600); frame.specValue:SetJustifyH("LEFT")
    frame.specChoose = CreateButton(contexts,T("CHOOSE_SPEC"),250,27); frame.specChoose:SetPoint("TOPLEFT",0,-203)
    frame.specChoose:SetScript("OnClick",function() addon:ShowSpecPicker(frame.specChoose,function(specID) addon:BindSpec(specID) end,false) end)
    frame.specClear = CreateButton(contexts,T("CLEAR"),84,27); frame.specClear:SetPoint("LEFT",frame.specChoose,"RIGHT",8,0); frame.specClear:SetScript("OnClick",function() addon:ClearSpecBinding() end)

    frame.talentLabel = contexts:CreateFontString(nil,"OVERLAY","GameFontNormal"); frame.talentLabel:SetPoint("TOPLEFT",0,-258); frame.talentLabel:SetText(T("TALENT_LOADOUT"))
    frame.talentValue = contexts:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); frame.talentValue:SetPoint("TOPLEFT",0,-282); frame.talentValue:SetWidth(600); frame.talentValue:SetJustifyH("LEFT")
    frame.talentChoose = CreateButton(contexts,T("CHOOSE_TALENT"),250,27); frame.talentChoose:SetPoint("TOPLEFT",0,-307)
    frame.talentChoose:SetScript("OnClick",function() local specID=addon:GetConfiguredSpecID(DB.selectedContext); addon:ShowTalentPicker(frame.talentChoose,specID,function(configID) addon:BindTalent(configID) end) end)
    frame.talentClear = CreateButton(contexts,T("CLEAR"),84,27); frame.talentClear:SetPoint("LEFT",frame.talentChoose,"RIGHT",8,0); frame.talentClear:SetScript("OnClick",function() addon:ClearTalentBinding() end)

    frame.gearLabel = contexts:CreateFontString(nil,"OVERLAY","GameFontNormal"); frame.gearLabel:SetPoint("TOPLEFT",0,-362); frame.gearLabel:SetText(T("EQUIPMENT_SET"))
    frame.gearValue = contexts:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); frame.gearValue:SetPoint("TOPLEFT",0,-386); frame.gearValue:SetWidth(600); frame.gearValue:SetJustifyH("LEFT")
    frame.gearChoose = CreateButton(contexts,T("CHOOSE_GEAR"),250,27); frame.gearChoose:SetPoint("TOPLEFT",0,-411); frame.gearChoose:SetScript("OnClick",function() addon:ShowGearPicker(frame.gearChoose,function(setID) addon:BindEquipment(setID) end) end)
    frame.gearClear = CreateButton(contexts,T("CLEAR"),84,27); frame.gearClear:SetPoint("LEFT",frame.gearChoose,"RIGHT",8,0); frame.gearClear:SetScript("OnClick",function() addon:ClearEquipmentBinding() end)
    contexts.modeHint = contexts:CreateFontString(nil,"OVERLAY","GameFontDisableSmall"); contexts.modeHint:SetPoint("TOPLEFT",0,-462); contexts.modeHint:SetWidth(600); contexts.modeHint:SetJustifyH("LEFT"); contexts.modeHint:SetText(T("CONTEXT_AUTOMATION_HINT"))

    -- Dungeon page.
    local dungeons = CreatePage("dungeons","PAGE_DUNGEONS","PAGE_DUNGEONS_DESC")
    dungeons.current = dungeons:CreateFontString(nil,"OVERLAY","GameFontHighlight"); dungeons.current:SetPoint("TOPLEFT",0,-95); dungeons.current:SetWidth(600); dungeons.current:SetJustifyH("LEFT")
    frame.dungeonOverrides = CreateButton(dungeons,T("OPEN_DUNGEON_OVERRIDES"),260,32); frame.dungeonOverrides:SetPoint("TOPLEFT",0,-145); frame.dungeonOverrides:SetScript("OnClick",function() addon:ToggleDungeonOverrides() end)
    dungeons.explain = dungeons:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); dungeons.explain:SetPoint("TOPLEFT",0,-205); dungeons.explain:SetWidth(600); dungeons.explain:SetJustifyH("LEFT"); dungeons.explain:SetText(T("DUNGEON_PAGE_HELP"))

    -- Raid boss page.
    local raids = CreatePage("raids","PAGE_RAID_BOSSES","PAGE_RAID_BOSSES_DESC")
    raids.current = raids:CreateFontString(nil,"OVERLAY","GameFontHighlight"); raids.current:SetPoint("TOPLEFT",0,-95); raids.current:SetWidth(600); raids.current:SetJustifyH("LEFT")
    frame.raidBossOverrides = CreateButton(raids,T("OPEN_RAID_BOSS_OVERRIDES"),280,32); frame.raidBossOverrides:SetPoint("TOPLEFT",0,-145); frame.raidBossOverrides:SetScript("OnClick",function() addon:ToggleRaidBossOverrides() end)
    raids.explain = raids:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); raids.explain:SetPoint("TOPLEFT",0,-205); raids.explain:SetWidth(600); raids.explain:SetJustifyH("LEFT"); raids.explain:SetText(T("RAID_BOSS_PAGE_HELP"))

    -- Automation modes page.
    local automation = CreatePage("automation","PAGE_AUTOMATION","PAGE_AUTOMATION_DESC")
    local autoRows = {
        {kind="spec", key="AUTOMATION_SPEC", y=-92},
        {kind="talents", key="AUTOMATION_TALENTS", y=-170},
        {kind="gear", key="AUTOMATION_GEAR", y=-248},
        {kind="lootSpec", key="AUTOMATION_LOOTSPEC", y=-326},
    }
    frame.automationButtons = {}
    for _, row in ipairs(autoRows) do
        local label=automation:CreateFontString(nil,"OVERLAY","GameFontNormal"); label:SetPoint("TOPLEFT",0,row.y); label:SetText(T(row.key))
        local desc=automation:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); desc:SetPoint("TOPLEFT",0,row.y-24); desc:SetWidth(410); desc:SetJustifyH("LEFT"); desc:SetText(T(row.key.."_DESC"))
        local button=CreateButton(automation,"",160,30); button:SetPoint("TOPRIGHT",automation,"TOPRIGHT",-8,row.y-8); button.kind=row.kind; button:SetScript("OnClick",function(self) addon:CycleAutomationMode(self.kind) end)
        frame.automationButtons[row.kind]=button
    end
    automation.legend=automation:CreateFontString(nil,"OVERLAY","GameFontDisableSmall"); automation.legend:SetPoint("BOTTOMLEFT",0,22); automation.legend:SetWidth(600); automation.legend:SetJustifyH("LEFT"); automation.legend:SetText(T("AUTOMATION_MODE_LEGEND"))
    frame.autoSpec=frame.automationButtons.spec; frame.autoTalents=frame.automationButtons.talents; frame.autoGear=frame.automationButtons.gear; frame.autoLootSpec=frame.automationButtons.lootSpec

    -- HUD / interface page.
    local hud = CreatePage("hud","PAGE_HUD","PAGE_HUD_DESC")
    -- Keep every control on this page the same width, using the longest
    -- localized toggle as the baseline so the column stays visually aligned.
    local hudButtonWidth = 220
    frame.hudToggle=CreateButton(hud,"",hudButtonWidth,30); frame.hudToggle:SetPoint("TOPLEFT",0,-95); frame.hudToggle:SetScript("OnClick",function() DB.hud.enabled=not DB.hud.enabled; addon:UpdateAll() end)
    frame.hudLock=CreateButton(hud,"",hudButtonWidth,30); frame.hudLock:SetPoint("TOPLEFT",0,-137); frame.hudLock:SetScript("OnClick",function() DB.hud.locked=not DB.hud.locked; addon:UpdateAll() end)
    frame.minimapToggle=CreateButton(hud,"",hudButtonWidth,30); frame.minimapToggle:SetPoint("TOPLEFT",0,-179); frame.minimapToggle:SetScript("OnClick",function() DB.minimap.hide=not DB.minimap.hide; addon:UpdateAll() end)
    frame.chatToggle=CreateButton(hud,"",hudButtonWidth,30); frame.chatToggle:SetPoint("TOPLEFT",0,-221); frame.chatToggle:SetScript("OnClick",function() DB.chatMessages=not DB.chatMessages; addon:UpdateAll(); Print(DB.chatMessages and T("CHAT_MESSAGES_ON_CONFIRM") or T("CHAT_MESSAGES_OFF_CONFIRM"),true) end)
    frame.resetPositions=CreateButton(hud,T("RESET_POSITIONS"),hudButtonWidth,30); frame.resetPositions:SetPoint("TOPLEFT",0,-281); frame.resetPositions:SetScript("OnClick",function() addon:ResetPositions() end)

    -- Advanced tools page.
    local advanced = CreatePage("advanced","PAGE_ADVANCED","PAGE_ADVANCED_DESC")
    frame.languageButton=CreateButton(advanced,"",250,30); frame.languageButton:SetPoint("TOPLEFT",0,-95); frame.languageButton:SetScript("OnClick",function() addon:ToggleLanguagePicker() end)
    frame.debugToggle=CreateButton(advanced,"",250,30); frame.debugToggle:SetPoint("TOPLEFT",0,-137); frame.debugToggle:SetScript("OnClick",function() DB.debug=not DB.debug; AppendEventLog("debug",DB.debug and "enabled" or "disabled"); addon:UpdateAll(); Print(DB.debug and T("DEBUG_ON") or T("DEBUG_OFF"),true) end)
    advanced.export=CreateButton(advanced,T("EXPORT_CONFIGURATION"),190,30); advanced.export:SetPoint("TOPLEFT",0,-195); advanced.export:SetScript("OnClick",function() addon:ShowTransferFrame("export") end)
    advanced.import=CreateButton(advanced,T("IMPORT_CONFIGURATION"),190,30); advanced.import:SetPoint("LEFT",advanced.export,"RIGHT",8,0); advanced.import:SetScript("OnClick",function() addon:ShowTransferFrame("import") end)
    advanced.log=CreateButton(advanced,T("VIEW_EVENT_LOG"),190,30); advanced.log:SetPoint("TOPLEFT",0,-237); advanced.log:SetScript("OnClick",function() addon:ShowTransferFrame("log") end)
    advanced.clearLog=CreateButton(advanced,T("CLEAR_EVENT_LOG"),190,30); advanced.clearLog:SetPoint("LEFT",advanced.log,"RIGHT",8,0); advanced.clearLog:SetScript("OnClick",function() DB.eventLog={}; lastLoggedRuleSignature=nil; lastLoggedNotifyKey=nil; addon:UpdateAll(); Print(T("EVENT_LOG_CLEARED"),true) end)
    frame.eventPreview=advanced:CreateFontString(nil,"OVERLAY","GameFontDisableSmall"); frame.eventPreview:SetPoint("TOPLEFT",0,-295); frame.eventPreview:SetWidth(600); frame.eventPreview:SetJustifyH("LEFT"); frame.eventPreview:SetJustifyV("TOP")

    talentPicker = CreatePicker("LoadoutPilotTalentPicker", UIParent, 300)
    gearPicker = CreatePicker("LoadoutPilotGearPicker", UIParent, 300)
    specPicker = CreatePicker("LoadoutPilotSpecPicker", UIParent, 300)
    lootSpecPicker = CreatePicker("LoadoutPilotLootSpecPicker", UIParent, 300)

    frame:Hide()
    return frame
end

function addon:SetMainPage(page)
    if not mainFrame or not mainFrame.pages then return end
    if not mainFrame.pages[page] then page="general" end
    DB.selectedPage=page
    HidePickers()
    for key, child in pairs(mainFrame.pages) do child:SetShown(key==page) end
    for key, button in pairs(pageButtons) do
        if key==page then
            button:SetBackdropColor(0.055,0.20,0.27,0.98); button:SetBackdropBorderColor(0.38,0.82,1.0,1)
        else
            button:SetBackdropColor(0.04,0.10,0.13,0.95); button:SetBackdropBorderColor(0.16,0.45,0.56,1)
        end
    end
    self:UpdateMainFrame()
end

local DUNGEON_PAGE_SIZE = 9

function addon:CleanupDungeonOverride(key)
    local override = self:GetDungeonOverride(key)
    if not override then return end
    if not override.specID and not override.talent and not override.equipment and override.lootSpecID == nil then
        DB.dungeonOverrides[key] = nil
    end
end

function addon:SetDungeonOverrideSpec(entry, specID)
    if not entry then return end

    -- A unified dungeon override can be entered as a regular dungeon/M0 or
    -- Mythic+. Capture missing defaults for both applicable contexts so the
    -- addon always knows which specialization to restore after the override.
    local currentSpecID, currentSpecName = self:GetSpecInfo()
    if currentSpecID then
        local contexts = { "dungeon" }
        if entry.supportsMythicPlus or entry.context == "mythicplus" then table.insert(contexts, "mythicplus") end
        for _, fallbackContext in ipairs(contexts) do
            if not self:ResolveSpecBinding(fallbackContext) then
                DB.specBindings[fallbackContext] = { specID = currentSpecID, name = currentSpecName }
                Print(T("BASE_SPEC_CAPTURED", currentSpecName, ContextName(fallbackContext)), true)
            end
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
    self:ClearPendingLootSpecChange()
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

function addon:SetDungeonOverrideLootSpec(entry, specID)
    if not entry or specID == nil then return end
    specID = tonumber(specID)
    if specID == nil then return end
    if specID ~= 0 and not self:GetSpecIndexByID(specID) then return end

    local override = self:EnsureDungeonOverride(entry)
    override.lootSpecID = specID
    self:ClearPendingLootSpecChange()
    self:UpdateAll()
    self:UpdateDungeonOverrideFrame()
    local current = self:GetCurrentDungeonInfo()
    if current and current.key == entry.key then self:ApplyCurrentRules("dungeon-loot-spec-override", false) end
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
    if field == "lootSpecID" then self:ClearPendingLootSpecChange() end
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
    self:ClearPendingLootSpecChange()
    pendingGearKey = nil
    self:UpdateAll()
    self:UpdateDungeonOverrideFrame()
    local current = self:GetCurrentDungeonInfo()
    if current and current.key == entry.key then self:ApplyCurrentRules("dungeon-override-removed", false) end
end

local function CreateDungeonOverrideFrame()
    local frame = CreateFrame("Frame", "LoadoutPilotDungeonOverrideFrame", UIParent, "BackdropTemplate")
    frame:SetSize(700, 600)
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

    frame.lootSpecLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.lootSpecLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", rightX, -238)
    frame.lootSpecLabel:SetText(T("LOOT_SPEC_OVERRIDE"))

    frame.lootSpecValue = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.lootSpecValue:SetPoint("TOPLEFT", frame, "TOPLEFT", rightX, -261)
    frame.lootSpecValue:SetWidth(380)
    frame.lootSpecValue:SetJustifyH("LEFT")

    frame.lootSpecChoose = CreateButton(frame, T("CHOOSE_LOOT_SPEC_OVERRIDE"), 220, 26)
    frame.lootSpecChoose:SetPoint("TOPLEFT", frame, "TOPLEFT", rightX, -286)
    frame.lootSpecChoose:SetScript("OnClick", function()
        local entry = addon:GetDungeonCatalogEntry(DB.selectedDungeonKey)
        if not entry then return end
        addon:ShowLootSpecPicker(frame.lootSpecChoose, function(specID)
            addon:SetDungeonOverrideLootSpec(entry, specID)
        end)
    end)

    frame.lootSpecInherit = CreateButton(frame, T("NO_OVERRIDE"), 100, 26)
    frame.lootSpecInherit:SetPoint("LEFT", frame.lootSpecChoose, "RIGHT", 8, 0)
    frame.lootSpecInherit:SetScript("OnClick", function()
        local entry = addon:GetDungeonCatalogEntry(DB.selectedDungeonKey)
        if entry then addon:ClearDungeonOverrideField(entry, "lootSpecID") end
    end)

    frame.talentLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.talentLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", rightX, -334)
    frame.talentLabel:SetText(T("TALENT_OVERRIDE"))

    frame.talentValue = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.talentValue:SetPoint("TOPLEFT", frame, "TOPLEFT", rightX, -357)
    frame.talentValue:SetWidth(380)
    frame.talentValue:SetJustifyH("LEFT")

    frame.talentChoose = CreateButton(frame, T("CHOOSE_TALENT_OVERRIDE"), 220, 26)
    frame.talentChoose:SetPoint("TOPLEFT", frame, "TOPLEFT", rightX, -382)
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
    frame.gearLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", rightX, -430)
    frame.gearLabel:SetText(T("EQUIPMENT_OVERRIDE"))

    frame.gearValue = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.gearValue:SetPoint("TOPLEFT", frame, "TOPLEFT", rightX, -453)
    frame.gearValue:SetWidth(380)
    frame.gearValue:SetJustifyH("LEFT")

    frame.gearChoose = CreateButton(frame, T("CHOOSE_GEAR_OVERRIDE"), 220, 26)
    frame.gearChoose:SetPoint("TOPLEFT", frame, "TOPLEFT", rightX, -478)
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
    frame.remove:SetPoint("TOPLEFT", frame, "TOPLEFT", rightX, -526)
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
            local configured = self:GetDungeonOverride(entry.key) and " |cff66ff99*|r" or ""
            row.text:SetText(tostring(entry.name) .. configured)
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
        frame.lootSpecValue:SetText("-")
        frame.talentValue:SetText("-")
        frame.gearValue:SetText("-")
        return
    end

    frame.selectedLabel:SetText(string.format("%s - %s", T("DUNGEON_SCOPE_LABEL"), tostring(entry.name)))
    local currentContext = current and current.key == entry.key and current.context or nil
    if currentContext then
        frame.fallback:SetText(T("DUNGEON_FALLBACK_CURRENT", ContextName(currentContext)))
    else
        frame.fallback:SetText(T("DUNGEON_FALLBACK_UNIFIED"))
    end

    local fallbackContext = currentContext or self:GetDungeonFallbackContext(entry)
    local override = self:GetDungeonOverride(entry.key)
    local baseSpec = self:ResolveSpecBinding(fallbackContext)
    local effectiveSpecID = self:GetDungeonOverrideEffectiveSpecID(entry)
    local effectiveSpecName = self:GetSpecNameByID(effectiveSpecID) or T("UNKNOWN")

    if override and override.specID then
        frame.specValue:SetText("|cff66ff99" .. tostring(self:GetSpecDisplayName(override.specID)) .. "|r")
    else
        local inheritedID = baseSpec and baseSpec.specID or effectiveSpecID
        local inherited = inheritedID and self:GetSpecDisplayName(inheritedID) or effectiveSpecName
        frame.specValue:SetText(T("INHERITS_VALUE", inherited))
    end

    if override and override.lootSpecID ~= nil then
        frame.lootSpecValue:SetText("|cff66ff99" .. tostring(self:GetLootSpecDisplayName(override.lootSpecID)) .. "|r")
    else
        frame.lootSpecValue:SetText(T("NO_LOOT_OVERRIDE_ACTIVE"))
    end

    if override and override.talent then
        local talent = self:ResolveTalentRecord(override.talent.specID or effectiveSpecID, override.talent)
        local value = talent and talent.name or T("MISSING_LOADOUT")
        frame.talentValue:SetText("|cff66ff99" .. tostring(value) .. "|r")
    else
        local baseTalent = self:ResolveTalentBinding(effectiveSpecID, fallbackContext)
        frame.talentValue:SetText(T("INHERITS_VALUE", baseTalent and baseTalent.name or T("NO_MAPPING")))
    end

    if override and override.equipment then
        local gear, info = self:ResolveEquipmentRecord(override.equipment)
        frame.gearValue:SetText("|cff66ff99" .. tostring(info and info.name or (gear and gear.name) or T("MISSING_GEAR")) .. "|r")
    else
        local baseGear, baseInfo = self:ResolveEquipmentBinding(effectiveSpecID, fallbackContext)
        if not baseGear and baseSpec and baseSpec.specID and baseSpec.specID ~= effectiveSpecID then
            baseGear, baseInfo = self:ResolveEquipmentBinding(baseSpec.specID, fallbackContext)
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

local RAID_BOSS_PAGE_SIZE = 7
local RAID_PICKER_PAGE_SIZE = 8

local function CreateRaidBossOverrideFrame()
    local frame = CreateFrame("Frame", "LoadoutPilotRaidBossOverrideFrame", UIParent, "BackdropTemplate")
    frame:SetSize(780, 610)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 10)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(900)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    ApplyBackdrop(frame, 0.98)
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOPLEFT", 18, -16)
    frame.title:SetText(T("RAID_BOSS_OVERRIDES"))
    frame.title:SetTextColor(0.45, 0.88, 1)

    frame.description = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.description:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -4)
    frame.description:SetWidth(730)
    frame.description:SetJustifyH("LEFT")
    frame.description:SetText(T("RAID_BOSS_OVERRIDES_DESCRIPTION"))

    frame.close = CreateButton(frame, "X", 28, 24)
    frame.close:SetPoint("TOPRIGHT", -12, -12)
    frame.close:SetScript("OnClick", function()
        HidePickers()
        if frame.raidPicker then frame.raidPicker:Hide() end
        if frame.confirm then frame.confirm:Hide() end
        frame:Hide()
    end)

    -- Raid-first navigation. The current raid is promoted to the top of the
    -- picker and automatically selected when the window is opened inside it.
    frame.raidFilterLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.raidFilterLabel:SetPoint("TOPLEFT", 18, -80)
    frame.raidFilterLabel:SetText(T("RAID_FILTER"))

    frame.raidSelect = CreateButton(frame, "", 300, 28)
    frame.raidSelect:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -100)

    frame.currentRaid = CreateButton(frame, T("CURRENT_RAID_BUTTON"), 300, 28)
    frame.currentRaid:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -136)
    frame.currentRaid:SetScript("OnClick", function()
        local count = addon:DiscoverCurrentRaidBossesFromJournal()
        local currentKey = addon:GetCurrentRaidCatalogKey()
        if currentKey and addon:GetRaidCatalogEntry(currentKey) then
            DB.selectedRaidBossRaidKey = currentKey
            frame.page = 1
            frame.ensureSelectedVisible = false
            if frame.raidPicker then frame.raidPicker:Hide() end
            addon:UpdateRaidBossOverrideFrame()
            if count > 0 then Print(T("RAID_BOSSES_REFRESHED", count), true) end
        elseif addon:IsInsideRaidInstance() then
            Print(T("RAID_BOSSES_REFRESH_FAILED"), true)
        else
            Print(T("NOT_IN_RAID"), true)
        end
    end)

    -- Keep this control on its own row. The localized PT-BR label is too
    -- wide to share the 300px navigation column with the Current Raid button.
    frame.configuredOnly = CreateButton(frame, "", 300, 28)
    frame.configuredOnly:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -172)
    frame.configuredOnly:SetScript("OnClick", function()
        DB.raidBossConfiguredOnly = not (DB.raidBossConfiguredOnly == true)
        frame.page = 1
        frame.ensureSelectedVisible = false
        addon:UpdateRaidBossOverrideFrame()
    end)

    frame.searchLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.searchLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -212)
    frame.searchLabel:SetText(T("SEARCH_BOSS"))

    frame.search = CreateFrame("EditBox", "LoadoutPilotRaidBossSearchEditBox", frame, "BackdropTemplate")
    frame.search:SetSize(300, 28)
    frame.search:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -232)
    ApplyBackdrop(frame.search, 0.92)
    frame.search:SetBackdropColor(0.04, 0.10, 0.13, 0.95)
    if frame.search.SetAutoFocus then frame.search:SetAutoFocus(false) end
    if frame.search.SetTextInsets then frame.search:SetTextInsets(8, 8, 0, 0) end
    if frame.search.SetFontObject then frame.search:SetFontObject("GameFontHighlightSmall") end
    frame.search:SetText("")
    frame.search:SetScript("OnTextChanged", function(self)
        frame.searchText = self.GetText and self:GetText() or ""
        frame.page = 1
        frame.ensureSelectedVisible = false
        addon:UpdateRaidBossOverrideFrame()
    end)
    frame.search:SetScript("OnEnterPressed", function(self) if self.ClearFocus then self:ClearFocus() end end)
    frame.search:SetScript("OnEscapePressed", function(self) if self.ClearFocus then self:ClearFocus() end end)

    frame.listLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.listLabel:SetPoint("TOPLEFT", 18, -274)
    frame.listLabel:SetText(T("RAID_BOSSES"))

    frame.rows = {}
    for index = 1, RAID_BOSS_PAGE_SIZE do
        local row = CreateButton(frame, "", 300, 30)
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -296 - ((index - 1) * 33))

        -- Two-line boss rows keep long localized names readable without letting
        -- text escape the button. The boss stays prominent on the first line,
        -- the raid is shown subtly below it, and Loot Spec gets its own slot on
        -- the right instead of being appended to the same FontString.
        row.text:ClearAllPoints()
        row.text:SetPoint("TOPLEFT", row, "TOPLEFT", 10, -3)
        row.text:SetPoint("TOPRIGHT", row, "TOPRIGHT", -10, -3)
        row.text:SetJustifyH("LEFT")
        row.text:SetJustifyV("TOP")
        if row.text.SetWordWrap then row.text:SetWordWrap(false) end
        if row.text.SetMaxLines then row.text:SetMaxLines(1) end

        row.raidText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.raidText:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 10, 3)
        row.raidText:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -10, 3)
        row.raidText:SetJustifyH("LEFT")
        row.raidText:SetJustifyV("BOTTOM")
        row.raidText:SetTextColor(0.55, 0.62, 0.68, 1)
        if row.raidText.SetWordWrap then row.raidText:SetWordWrap(false) end
        if row.raidText.SetMaxLines then row.raidText:SetMaxLines(1) end
        row.raidText:SetText("")

        row.badge = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.badge:SetPoint("RIGHT", row, "RIGHT", -10, 1)
        row.badge:SetWidth(102)
        row.badge:SetJustifyH("RIGHT")
        if row.badge.SetWordWrap then row.badge:SetWordWrap(false) end
        if row.badge.SetMaxLines then row.badge:SetMaxLines(1) end
        row.badge:SetText("")
        row.badge:Hide()

        row:SetScript("OnClick", function(self)
            DB.selectedRaidBossKey = self.bossKey
            frame.ensureSelectedVisible = false
            HidePickers()
            if frame.raidPicker then frame.raidPicker:Hide() end
            addon:UpdateRaidBossOverrideFrame()
        end)
        frame.rows[index] = row
    end

    frame.prev = CreateButton(frame, T("PREVIOUS"), 76, 26)
    frame.prev:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -530)
    frame.prev:SetScript("OnClick", function()
        frame.page = math.max(1, (frame.page or 1) - 1)
        frame.ensureSelectedVisible = false
        addon:UpdateRaidBossOverrideFrame()
    end)
    frame.pageText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.pageText:SetPoint("LEFT", frame.prev, "RIGHT", 8, 0)
    frame.pageText:SetWidth(72)
    frame.pageText:SetJustifyH("CENTER")
    frame.next = CreateButton(frame, T("NEXT"), 76, 26)
    frame.next:SetPoint("LEFT", frame.pageText, "RIGHT", 8, 0)
    frame.next:SetScript("OnClick", function()
        frame.page = (frame.page or 1) + 1
        frame.ensureSelectedVisible = false
        addon:UpdateRaidBossOverrideFrame()
    end)

    frame.countText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.countText:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -568)
    frame.countText:SetWidth(300)
    frame.countText:SetJustifyH("LEFT")

    -- Raid picker deliberately lives above the main panel so it can never be
    -- occluded by the override window (same z-order lesson as Dungeon Overrides).
    frame.raidPicker = CreateFrame("Frame", "LoadoutPilotRaidPicker", frame, "BackdropTemplate")
    frame.raidPicker:SetSize(320, 300)
    frame.raidPicker:SetPoint("TOPLEFT", frame.raidSelect, "BOTTOMLEFT", 0, -4)
    frame.raidPicker:SetFrameStrata("FULLSCREEN_DIALOG")
    frame.raidPicker:SetFrameLevel(940)
    frame.raidPicker:SetClampedToScreen(true)
    ApplyBackdrop(frame.raidPicker, 0.995)
    frame.raidPicker.rows = {}
    for index = 1, RAID_PICKER_PAGE_SIZE do
        local row = CreateButton(frame.raidPicker, "", 304, 26)
        row:SetPoint("TOPLEFT", frame.raidPicker, "TOPLEFT", 8, -8 - ((index - 1) * 28))
        row:SetScript("OnClick", function(self)
            DB.selectedRaidBossRaidKey = self.raidKey or "all"
            frame.page = 1
            frame.ensureSelectedVisible = false
            frame.raidPicker:Hide()
            addon:UpdateRaidBossOverrideFrame()
        end)
        frame.raidPicker.rows[index] = row
    end
    frame.raidPicker.prev = CreateButton(frame.raidPicker, T("PREVIOUS"), 80, 24)
    frame.raidPicker.prev:SetPoint("BOTTOMLEFT", 8, 8)
    frame.raidPicker.prev:SetScript("OnClick", function()
        frame.raidPicker.page = math.max(1, (frame.raidPicker.page or 1) - 1)
        addon:UpdateRaidBossRaidPicker()
    end)
    frame.raidPicker.pageText = frame.raidPicker:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.raidPicker.pageText:SetPoint("LEFT", frame.raidPicker.prev, "RIGHT", 8, 0)
    frame.raidPicker.pageText:SetWidth(80)
    frame.raidPicker.pageText:SetJustifyH("CENTER")
    frame.raidPicker.next = CreateButton(frame.raidPicker, T("NEXT"), 80, 24)
    frame.raidPicker.next:SetPoint("BOTTOMRIGHT", -8, 8)
    frame.raidPicker.next:SetScript("OnClick", function()
        frame.raidPicker.page = (frame.raidPicker.page or 1) + 1
        addon:UpdateRaidBossRaidPicker()
    end)
    frame.raidPicker.page = 1
    frame.raidPicker:Hide()
    frame.raidSelect:SetScript("OnClick", function()
        HidePickers()
        if frame.raidPicker:IsShown() then
            frame.raidPicker:Hide()
        else
            frame.raidPicker.page = 1
            addon:UpdateRaidBossRaidPicker(true)
            frame.raidPicker:Show()
        end
    end)

    local rightX = 350
    frame.selectedLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.selectedLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", rightX, -105)
    frame.selectedLabel:SetWidth(400)
    frame.selectedLabel:SetJustifyH("LEFT")

    frame.raidLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.raidLabel:SetPoint("TOPLEFT", frame.selectedLabel, "BOTTOMLEFT", 0, -5)
    frame.raidLabel:SetWidth(400)
    frame.raidLabel:SetJustifyH("LEFT")

    frame.lootLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.lootLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", rightX, -185)
    frame.lootLabel:SetText(T("LOOT_SPEC_OVERRIDE"))

    frame.lootValue = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.lootValue:SetPoint("TOPLEFT", frame.lootLabel, "BOTTOMLEFT", 0, -8)
    frame.lootValue:SetWidth(400)
    frame.lootValue:SetJustifyH("LEFT")

    frame.lootChoose = CreateButton(frame, T("CHOOSE_LOOT_SPEC_OVERRIDE"), 235, 28)
    frame.lootChoose:SetPoint("TOPLEFT", frame, "TOPLEFT", rightX, -238)
    frame.lootChoose:SetScript("OnClick", function()
        if frame.raidPicker then frame.raidPicker:Hide() end
        local entry = addon:GetRaidBossCatalogEntry(DB.selectedRaidBossKey)
        if not entry then return end
        addon:ShowLootSpecPicker(frame.lootChoose, function(specID) addon:SetRaidBossLootSpec(entry, specID) end)
    end)

    frame.noOverride = CreateButton(frame, T("NO_OVERRIDE"), 120, 28)
    frame.noOverride:SetPoint("LEFT", frame.lootChoose, "RIGHT", 8, 0)
    frame.noOverride:SetScript("OnClick", function()
        local entry = addon:GetRaidBossCatalogEntry(DB.selectedRaidBossKey)
        if entry then addon:RemoveRaidBossOverride(entry) end
    end)

    frame.behavior = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.behavior:SetPoint("TOPLEFT", frame, "TOPLEFT", rightX, -300)
    frame.behavior:SetWidth(395)
    frame.behavior:SetJustifyH("LEFT")
    frame.behavior:SetText(T("RAID_BOSS_TARGET_BEHAVIOR"))

    frame.remove = CreateButton(frame, T("REMOVE_RAID_BOSS_OVERRIDE"), 235, 28)
    frame.remove:SetPoint("TOPLEFT", frame, "TOPLEFT", rightX, -405)
    frame.remove:SetScript("OnClick", function()
        local entry = addon:GetRaidBossCatalogEntry(DB.selectedRaidBossKey)
        if entry then addon:RemoveRaidBossOverride(entry) end
    end)

    frame.clearRaid = CreateButton(frame, T("CLEAR_RAID_OVERRIDES"), 235, 28)
    frame.clearRaid:SetPoint("TOPLEFT", frame, "TOPLEFT", rightX, -450)

    -- Small in-addon confirmation instead of immediately deleting a whole raid.
    frame.confirm = CreateFrame("Frame", "LoadoutPilotRaidClearConfirmFrame", frame, "BackdropTemplate")
    frame.confirm:SetSize(470, 180)
    frame.confirm:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.confirm:SetFrameStrata("FULLSCREEN_DIALOG")
    frame.confirm:SetFrameLevel(980)
    ApplyBackdrop(frame.confirm, 1)
    frame.confirm.title = frame.confirm:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.confirm.title:SetPoint("TOPLEFT", 18, -18)
    frame.confirm.title:SetText(T("CLEAR_RAID_OVERRIDES_CONFIRM_TITLE"))
    frame.confirm.text = frame.confirm:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.confirm.text:SetPoint("TOPLEFT", 18, -55)
    frame.confirm.text:SetWidth(430)
    frame.confirm.text:SetJustifyH("LEFT")
    frame.confirm.yes = CreateButton(frame.confirm, T("CONFIRM"), 170, 30)
    frame.confirm.yes:SetPoint("BOTTOMLEFT", 45, 20)
    frame.confirm.no = CreateButton(frame.confirm, T("CANCEL"), 170, 30)
    frame.confirm.no:SetPoint("BOTTOMRIGHT", -45, 20)
    frame.confirm.no:SetScript("OnClick", function() frame.confirm:Hide() end)
    frame.confirm.yes:SetScript("OnClick", function()
        local raidKey = frame.confirm.raidKey
        local raid = addon:GetRaidCatalogEntry(raidKey)
        local raidName = raid and raid.name or T("CONTEXT_RAID")
        local removed = addon:ClearRaidBossOverridesForRaid(raidKey)
        frame.confirm:Hide()
        Print(T("CLEAR_RAID_OVERRIDES_DONE", removed, raidName), true)
        addon:UpdateRaidBossOverrideFrame()
    end)
    frame.confirm:Hide()

    frame.clearRaid:SetScript("OnClick", function()
        local raidKey = DB.selectedRaidBossRaidKey or "all"
        local raid = addon:GetRaidCatalogEntry(raidKey)
        if not raid then return end
        local configured = addon:GetRaidBossConfigurationCounts(raidKey)
        if configured <= 0 then return end
        frame.confirm.raidKey = raidKey
        frame.confirm.text:SetText(T("CLEAR_RAID_OVERRIDES_CONFIRM", configured, tostring(raid.name or T("CONTEXT_RAID"))))
        if frame.raidPicker then frame.raidPicker:Hide() end
        frame.confirm:Show()
    end)

    frame.page = 1
    frame.searchText = ""
    frame.ensureSelectedVisible = true
    frame.autoSelectCurrentRaid = true
    frame:Hide()
    return frame
end

function addon:UpdateRaidBossRaidPicker(ensureSelectedVisible)
    local frame = raidBossOverrideFrame
    if not frame or not frame.raidPicker or not DB then return end
    local picker = frame.raidPicker
    local raids = self:GetRaidCatalog()
    local allConfigured, allTotal = self:GetRaidBossConfigurationCounts("all")
    local options = {{ key = "all", name = T("ALL_RAIDS"), configured = allConfigured, total = allTotal, isCurrent = false }}
    for _, raid in ipairs(raids) do table.insert(options, raid) end

    local totalPages = math.max(1, math.ceil(#options / RAID_PICKER_PAGE_SIZE))
    picker.page = math.max(1, math.min(picker.page or 1, totalPages))
    if ensureSelectedVisible then
        local selected = DB.selectedRaidBossRaidKey or "all"
        for index, option in ipairs(options) do
            if option.key == selected then
                picker.page = math.floor((index - 1) / RAID_PICKER_PAGE_SIZE) + 1
                break
            end
        end
    end

    local first = ((picker.page - 1) * RAID_PICKER_PAGE_SIZE) + 1
    for rowIndex, row in ipairs(picker.rows) do
        local option = options[first + rowIndex - 1]
        if option then
            row.raidKey = option.key
            local name = tostring(option.name or option.key)
            if option.isCurrent then name = "|cffffff66" .. name .. "|r " .. T("CURRENT_RAID_SUFFIX") end
            row.text:SetText(T("RAID_PICKER_ROW", name, tonumber(option.configured) or 0, tonumber(option.total) or 0))
            row:Show()
        else
            row.raidKey = nil
            row:Hide()
        end
    end
    picker.pageText:SetText(string.format("%d/%d", picker.page, totalPages))
    picker.prev:SetShown(totalPages > 1)
    picker.next:SetShown(totalPages > 1)
end

function addon:UpdateRaidBossOverrideFrame()
    local frame = raidBossOverrideFrame
    if not frame or not DB then return end
    self:DiscoverCurrentRaidBossesFromJournal()

    local raids = self:GetRaidCatalog()
    local selectedRaidKey = DB.selectedRaidBossRaidKey or "all"
    local currentRaidKey = self:GetCurrentRaidCatalogKey()
    local currentRaidEntry = currentRaidKey and self:GetRaidCatalogEntry(currentRaidKey) or nil
    if frame.autoSelectCurrentRaid and currentRaidEntry then
        selectedRaidKey = currentRaidKey
        DB.selectedRaidBossRaidKey = currentRaidKey
    elseif selectedRaidKey ~= "all" and not self:GetRaidCatalogEntry(selectedRaidKey) then
        selectedRaidKey = currentRaidKey or "all"
        DB.selectedRaidBossRaidKey = selectedRaidKey
    end
    frame.autoSelectCurrentRaid = false

    local selectedRaid = self:GetRaidCatalogEntry(selectedRaidKey)
    if selectedRaidKey == "all" then
        frame.raidSelect.text:SetText(T("RAID_FILTER_VALUE", T("ALL_RAIDS")))
    elseif selectedRaid then
        local raidName = tostring(selectedRaid.name or T("CONTEXT_RAID"))
        if selectedRaid.isCurrent then raidName = raidName .. " " .. T("CURRENT_RAID_SUFFIX") end
        frame.raidSelect.text:SetText(T("RAID_FILTER_VALUE", raidName))
    else
        frame.raidSelect.text:SetText(T("RAID_FILTER_VALUE", T("ALL_RAIDS")))
    end
    frame.configuredOnly.text:SetText(DB.raidBossConfiguredOnly and T("CONFIGURED_ONLY_ON") or T("CONFIGURED_ONLY_OFF"))

    local catalog = self:GetFilteredRaidBossCatalog(selectedRaidKey, DB.raidBossConfiguredOnly == true, frame.searchText or "")
    local selectedVisible = false
    for _, entry in ipairs(catalog) do
        if entry.key == DB.selectedRaidBossKey then selectedVisible = true break end
    end
    if not selectedVisible then
        DB.selectedRaidBossKey = catalog[1] and catalog[1].key or nil
        frame.ensureSelectedVisible = true
    end

    local totalPages = math.max(1, math.ceil(#catalog / RAID_BOSS_PAGE_SIZE))
    frame.page = math.max(1, math.min(frame.page or 1, totalPages))
    local selectedIndex
    for i, entry in ipairs(catalog) do if entry.key == DB.selectedRaidBossKey then selectedIndex = i break end end
    if selectedIndex and frame.ensureSelectedVisible then
        frame.page = math.floor((selectedIndex - 1) / RAID_BOSS_PAGE_SIZE) + 1
    end
    frame.ensureSelectedVisible = false

    local first = ((frame.page - 1) * RAID_BOSS_PAGE_SIZE) + 1
    for rowIndex, row in ipairs(frame.rows) do
        local entry = catalog[first + rowIndex - 1]
        if entry then
            row.bossKey = entry.key
            local override = self:GetRaidBossOverride(entry.key)
            local hasLootOverride = override and override.lootSpecID ~= nil
            local bossName = tostring(entry.name or entry.key)
            local raidName = tostring(entry.raidName or T("CONTEXT_RAID"))
            local rightInset = hasLootOverride and -120 or -10

            if row.text then
                row.text:ClearAllPoints()
                row.text:SetPoint("TOPLEFT", row, "TOPLEFT", 10, -3)
                row.text:SetPoint("TOPRIGHT", row, "TOPRIGHT", rightInset, -3)
                row.text:SetJustifyH("LEFT")
                row.text:SetText(bossName)
            end

            if row.raidText then
                row.raidText:ClearAllPoints()
                row.raidText:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 10, 3)
                row.raidText:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", rightInset, 3)
                row.raidText:SetText(raidName)
            end

            if row.badge then
                if hasLootOverride then
                    row.badge:SetText("|cff66ff99[" .. tostring(self:GetLootSpecDisplayName(override.lootSpecID)) .. "]|r")
                    row.badge:Show()
                else
                    row.badge:SetText("")
                    row.badge:Hide()
                end
            end

            row:Show()
            if entry.key == DB.selectedRaidBossKey then
                row:SetBackdropColor(0.055, 0.20, 0.27, 0.98)
                row:SetBackdropBorderColor(0.38, 0.82, 1.0, 1)
            else
                row:SetBackdropColor(0.04, 0.10, 0.13, 0.95)
                row:SetBackdropBorderColor(0.16, 0.45, 0.56, 1)
            end
        else
            row.bossKey = nil
            if row.raidText then row.raidText:SetText("") end
            if row.badge then
                row.badge:SetText("")
                row.badge:Hide()
            end
            row:Hide()
        end
    end
    frame.pageText:SetText(string.format("%d/%d", frame.page, totalPages))
    frame.prev:SetShown(totalPages > 1)
    frame.next:SetShown(totalPages > 1)

    local configuredCount, totalCount = self:GetRaidBossConfigurationCounts(selectedRaidKey)
    frame.countText:SetText(T("RAID_BOSS_CONFIGURED_COUNT", configuredCount, totalCount))
    frame.clearRaid:SetShown(selectedRaidKey ~= "all" and configuredCount > 0)

    local entry = self:GetRaidBossCatalogEntry(DB.selectedRaidBossKey)
    if not entry then
        frame.selectedLabel:SetText(#catalog == 0 and T("NO_RAID_BOSSES_MATCH") or T("NO_RAID_BOSS_SELECTED"))
        frame.raidLabel:SetText(T("RAID_BOSS_SELECT_HINT"))
        frame.lootValue:SetText("-")
        frame.lootChoose:SetShown(false)
        frame.noOverride:SetShown(false)
        frame.remove:SetShown(false)
        return
    end

    frame.lootChoose:SetShown(true)
    frame.noOverride:SetShown(true)
    frame.remove:SetShown(self:GetRaidBossOverride(entry.key) ~= nil)
    frame.selectedLabel:SetText(tostring(entry.name or T("UNKNOWN")))
    local identityText
    if entry.encounterID then
        identityText = T("ENCOUNTER_ID_VALUE", tostring(entry.encounterID))
    elseif entry.npcID then
        identityText = "NPC " .. tostring(entry.npcID)
    else
        identityText = T("ENCOUNTER_ID_UNKNOWN")
    end
    frame.raidLabel:SetText(string.format("%s | %s", tostring(entry.raidName or T("CONTEXT_RAID")), identityText))
    local override = self:GetRaidBossOverride(entry.key)
    if override and override.lootSpecID ~= nil then
        frame.lootValue:SetText("|cff66ff99" .. tostring(self:GetLootSpecDisplayName(override.lootSpecID)) .. "|r")
    else
        frame.lootValue:SetText(T("NO_LOOT_OVERRIDE_ACTIVE"))
    end
end

function addon:ToggleRaidBossOverrides()
    if not raidBossOverrideFrame then return end
    HidePickers()
    if raidBossOverrideFrame:IsShown() then
        if raidBossOverrideFrame.raidPicker then raidBossOverrideFrame.raidPicker:Hide() end
        if raidBossOverrideFrame.confirm then raidBossOverrideFrame.confirm:Hide() end
        raidBossOverrideFrame:Hide()
        return
    end
    self:DiscoverCurrentRaidBossesFromJournal()
    raidBossOverrideFrame.autoSelectCurrentRaid = self:IsInsideRaidInstance()
    raidBossOverrideFrame.ensureSelectedVisible = true
    raidBossOverrideFrame.page = 1
    self:UpdateRaidBossOverrideFrame()
    raidBossOverrideFrame:Show()
end

local function CreateTransferFrame()
    local frame = CreateFrame("Frame", "LoadoutPilotTransferFrame", UIParent, "BackdropTemplate")
    frame:SetSize(700, 470)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(1100)
    frame:SetClampedToScreen(true)
    ApplyBackdrop(frame, 0.99)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOPLEFT", 18, -16)
    frame.title:SetTextColor(0.45,0.88,1)

    frame.description = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.description:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -6)
    frame.description:SetWidth(650)
    frame.description:SetJustifyH("LEFT")

    -- The transfer/event-history text can easily exceed the dialog height. Keep it
    -- inside a real ScrollFrame instead of letting a multiline EditBox grow over
    -- the rest of the UI.
    frame.scroll = CreateFrame("ScrollFrame", "LoadoutPilotTransferScrollFrame", frame, "UIPanelScrollFrameTemplate")
    frame.scroll:SetPoint("TOPLEFT", 18, -80)
    frame.scroll:SetSize(640, 320)
    if frame.scroll.SetClipsChildren then frame.scroll:SetClipsChildren(true) end
    if frame.scroll.EnableMouseWheel then frame.scroll:EnableMouseWheel(true) end

    frame.edit = CreateFrame("EditBox", "LoadoutPilotTransferEditBox", frame.scroll)
    frame.edit:SetWidth(610)
    frame.edit:SetHeight(320)
    if frame.edit.SetMultiLine then frame.edit:SetMultiLine(true) end
    if frame.edit.SetAutoFocus then frame.edit:SetAutoFocus(false) end
    if frame.edit.SetTextInsets then frame.edit:SetTextInsets(8,8,8,8) end
    if frame.edit.SetFontObject then frame.edit:SetFontObject("GameFontHighlightSmall") end
    if frame.edit.SetJustifyH then frame.edit:SetJustifyH("LEFT") end
    if frame.edit.SetJustifyV then frame.edit:SetJustifyV("TOP") end
    frame.scroll:SetScrollChild(frame.edit)

    local function RefreshTransferEditHeight()
        local visibleHeight = (frame.scroll.GetHeight and frame.scroll:GetHeight()) or 320
        local textHeight = (frame.edit.GetStringHeight and frame.edit:GetStringHeight()) or visibleHeight
        frame.edit:SetHeight(math.max(visibleHeight, (tonumber(textHeight) or 0) + 24))
        if frame.scroll.UpdateScrollChildRect then frame.scroll:UpdateScrollChildRect() end
    end

    function frame:RefreshTransferScroll(scrollToBottom)
        RefreshTransferEditHeight()
        local function ApplyScrollPosition()
            if frame.scroll.UpdateScrollChildRect then frame.scroll:UpdateScrollChildRect() end
            if not frame.scroll.SetVerticalScroll then return end
            if scrollToBottom then
                local maxScroll = (frame.scroll.GetVerticalScrollRange and frame.scroll:GetVerticalScrollRange()) or 0
                frame.scroll:SetVerticalScroll(math.max(0, tonumber(maxScroll) or 0))
            else
                frame.scroll:SetVerticalScroll(0)
            end
        end
        if C_Timer and C_Timer.After then
            C_Timer.After(0, ApplyScrollPosition)
        else
            ApplyScrollPosition()
        end
    end

    frame.edit:SetScript("OnTextChanged", function()
        RefreshTransferEditHeight()
    end)
    frame.edit:SetScript("OnEscapePressed", function(self)
        if self.ClearFocus then self:ClearFocus() end
    end)

    frame.scroll:SetScript("OnMouseWheel", function(self, delta)
        if not self.SetVerticalScroll then return end
        local current = (self.GetVerticalScroll and self:GetVerticalScroll()) or 0
        local maxScroll = (self.GetVerticalScrollRange and self:GetVerticalScrollRange()) or 0
        local target = (tonumber(current) or 0) - (tonumber(delta) or 0) * 36
        target = math.max(0, math.min(tonumber(maxScroll) or 0, target))
        self:SetVerticalScroll(target)
    end)

    frame.export = CreateButton(frame, T("EXPORT_CONFIGURATION"), 160, 28)
    frame.export:SetPoint("BOTTOMLEFT", 18, 18)
    frame.export:SetScript("OnClick", function()
        frame.mode = "export"
        frame.title:SetText(T("EXPORT_CONFIGURATION"))
        frame.description:SetText(T("EXPORT_DESCRIPTION"))
        frame.edit:SetText(addon:ExportConfiguration())
        frame:RefreshTransferScroll(false)
        if frame.edit.HighlightText then frame.edit:HighlightText() end
        if frame.edit.SetFocus then frame.edit:SetFocus() end
    end)

    frame.import = CreateButton(frame, T("IMPORT_CONFIGURATION"), 160, 28)
    frame.import:SetPoint("LEFT", frame.export, "RIGHT", 8, 0)
    frame.import:SetScript("OnClick", function()
        local text = frame.edit.GetText and frame.edit:GetText() or ""
        local ok, message = addon:ImportConfiguration(text)
        Print(message, true)
        if ok then frame:Hide() end
    end)

    frame.log = CreateButton(frame, T("COPY_EVENT_LOG"), 160, 28)
    frame.log:SetPoint("LEFT", frame.import, "RIGHT", 8, 0)
    frame.log:SetScript("OnClick", function()
        frame.mode = "log"
        frame.title:SetText(T("EVENT_LOG"))
        frame.description:SetText(T("EVENT_LOG_DESCRIPTION"))
        frame.edit:SetText(addon:GetRecentEventLogText(80))
        frame:RefreshTransferScroll(true)
        if frame.edit.ClearFocus then frame.edit:ClearFocus() end
    end)

    frame.close = CreateButton(frame, T("CLOSE"), 120, 28)
    frame.close:SetPoint("BOTTOMRIGHT", -18, 18)
    frame.close:SetScript("OnClick", function() frame:Hide() end)
    frame:Hide()
    return frame
end

function addon:ShowTransferFrame(mode)
    if not transferFrame then return end
    transferFrame.mode = mode or "export"
    if transferFrame.mode == "import" then
        transferFrame.title:SetText(T("IMPORT_CONFIGURATION"))
        transferFrame.description:SetText(T("IMPORT_DESCRIPTION"))
        transferFrame.edit:SetText("")
    elseif transferFrame.mode == "log" then
        transferFrame.title:SetText(T("EVENT_LOG"))
        transferFrame.description:SetText(T("EVENT_LOG_DESCRIPTION"))
        transferFrame.edit:SetText(self:GetRecentEventLogText(80))
    else
        transferFrame.title:SetText(T("EXPORT_CONFIGURATION"))
        transferFrame.description:SetText(T("EXPORT_DESCRIPTION"))
        transferFrame.edit:SetText(self:ExportConfiguration())
    end

    transferFrame:Show()
    if transferFrame.RefreshTransferScroll then
        transferFrame:RefreshTransferScroll(transferFrame.mode == "log")
    end

    if transferFrame.mode == "log" then
        -- Do not auto-select the whole history when it opens. That made the
        -- window look like a wall of highlighted text and made scrolling harder.
        if transferFrame.edit.ClearFocus then transferFrame.edit:ClearFocus() end
    else
        if transferFrame.mode ~= "import" and transferFrame.edit.HighlightText then
            transferFrame.edit:HighlightText()
        end
        if transferFrame.edit.SetFocus then transferFrame.edit:SetFocus() end
    end
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
    if rule and rule.raidBossInfo then
        GameTooltip:AddDoubleLine(T("RAID_BOSS"), tostring(rule.raidBossInfo.name or T("UNKNOWN")), 0.85, 0.92, 1, 1, 1, 1)
    end
    local currentLootSpecID = self:GetLootSpecializationID()
    if currentLootSpecID ~= nil then
        GameTooltip:AddDoubleLine(T("LOOT_SPECIALIZATION"), tostring(self:GetLootSpecDisplayName(currentLootSpecID)), 0.85, 0.92, 1, 1, 1, 1)
    end
    if rule and rule.lootSpecID ~= nil and currentLootSpecID ~= rule.lootSpecID then
        GameTooltip:AddDoubleLine(T("TARGET_LOOT_SPEC"), tostring(self:GetLootSpecDisplayName(rule.lootSpecID)), 0.85, 0.92, 1, 1, 1, 1)
    end
    GameTooltip:AddDoubleLine(T("TALENTS"), tostring(talentText), 0.85, 0.92, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine(T("GEAR"), tostring(gearText), 0.85, 0.92, 1, 1, 1, 1)
    if rule and rule.sources then
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine(T("SOURCE_SPEC"), tostring(rule.sources.spec or T("UNKNOWN")), 0.65, 0.82, 0.95, 0.85, 0.92, 1)
        GameTooltip:AddDoubleLine(T("SOURCE_LOOT"), tostring(rule.sources.lootSpec or T("UNKNOWN")), 0.65, 0.82, 0.95, 0.85, 0.92, 1)
        GameTooltip:AddDoubleLine(T("SOURCE_TALENTS"), tostring(rule.sources.talents or T("UNKNOWN")), 0.65, 0.82, 0.95, 0.85, 0.92, 1)
        GameTooltip:AddDoubleLine(T("SOURCE_GEAR"), tostring(rule.sources.gear or T("UNKNOWN")), 0.65, 0.82, 0.95, 0.85, 0.92, 1)
    end
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

    local specMode = self:GetAutomationMode("spec")
    if specNeedsChange and specMode == "notify" then
        return "|cffffcc55" .. T("NOTIFY_PENDING") .. "|r"
    elseif specNeedsChange and specMode == "off" then
        return "|cffffcc55" .. T("SPEC_MANUAL_REQUIRED") .. "|r"
    end
    if pendingSpecID or (specNeedsChange and specMode == "auto") then
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
    if pendingLootSpecID ~= nil then
        return "|cffffcc55" .. (lastLootSpecError or T("LOOT_SPEC_APPLYING")) .. "|r"
    end
    if pendingTalentKey and not talentReady then
        return "|cffffcc55" .. (lastTalentError or T("APPLYING")) .. "|r"
    end
    if pendingGearKey and not gearReady then
        return "|cffffcc55" .. (lastGearError or T("APPLYING")) .. "|r"
    end
    local recommendation = self:GetNotificationRecommendation()
    if recommendation then
        return "|cffffcc55" .. T("NOTIFY_PENDING") .. "|r"
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
    local talentMode = self:GetAutomationMode("talents")
    if talentMode ~= "auto" then
        talentText = talentText .. " |cffffcc55(" .. AutomationModeLabel(talentMode) .. ")|r"
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
    local gearMode = self:GetAutomationMode("gear")
    if gearMode ~= "auto" then
        gearText = gearText .. " |cffffcc55(" .. AutomationModeLabel(gearMode) .. ")|r"
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
    local rule = self:ResolveRuntimeRule(false)
    local actualContext = rule and rule.context or self:DetectContext()
    local configContext = DB.selectedContext
    local currentDungeon = rule and rule.dungeonInfo or self:GetCurrentDungeonInfo()

    mainFrame.currentIcon:SetTexture(specIcon or 134400)
    mainFrame.currentTitle:SetText(string.format("%s - %s (%s)", tostring(className), tostring(specName), self:GetRoleLabel(self:GetSpecRoleByID(specID))))
    local contextText = string.format("%s: %s", T("CURRENT"), self:GetContextDetailLabel(rule))
    if currentDungeon then
        contextText = contextText .. " - " .. tostring(currentDungeon.name)
        if self:GetDungeonOverride(currentDungeon.key) then contextText = contextText .. " |cff66ff99(" .. T("OVERRIDE_ACTIVE") .. ")|r" end
    elseif rule and rule.raidBossInfo then
        contextText = contextText .. " - " .. tostring(rule.raidBossInfo.name)
    end
    mainFrame.currentContext:SetText(contextText)

    local explainLines = self:GetRuleExplanationLines()
    mainFrame.ruleSummary:SetText(table.concat(explainLines, "\n"))

    for context, button in pairs(contextButtons) do
        if context == configContext then
            button:SetBackdropColor(0.055,0.20,0.27,0.98); button:SetBackdropBorderColor(0.38,0.82,1.0,1)
            button.text:SetText("|cff66ddff" .. ContextName(context) .. "|r")
        else
            button:SetBackdropColor(0.04,0.10,0.13,0.95); button:SetBackdropBorderColor(0.16,0.45,0.56,1)
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
    mainFrame.talentValue:SetText(talentBinding and (self:GetTalentName(talentBinding.configID) or ("|cffff7777"..T("MISSING_LOADOUT").."|r")) or ("|cffaaaaaa"..T("NO_MAPPING").."|r"))
    local gearBinding, gearInfo = configSpecID and self:ResolveEquipmentBinding(configSpecID, configContext) or nil, nil
    if configSpecID then gearBinding, gearInfo = self:ResolveEquipmentBinding(configSpecID, configContext) end
    mainFrame.gearValue:SetText(gearBinding and (gearInfo and gearInfo.name or ("|cffff7777"..T("MISSING_GEAR").."|r")) or ("|cffaaaaaa"..T("NO_MAPPING").."|r"))

    local dungeonPage = mainFrame.pages and mainFrame.pages.dungeons
    if dungeonPage and dungeonPage.current then
        if currentDungeon then dungeonPage.current:SetText(T("CURRENT_DUNGEON_VALUE", tostring(currentDungeon.name), self:GetContextDetailLabel(rule)))
        else dungeonPage.current:SetText(T("NOT_IN_DUNGEON")) end
    end
    local raidPage = mainFrame.pages and mainFrame.pages.raids
    if raidPage and raidPage.current then
        if activeRaidBossKey then
            local active = self:GetRaidBossCatalogEntry(activeRaidBossKey)
            raidPage.current:SetText(T("ACTIVE_BOSS_VALUE", tostring(active and active.name or activeRaidBossKey)))
        elseif self:IsInsideRaidInstance() then
            self:DiscoverCurrentRaidBossesFromJournal()
            local raidKey = self:GetCurrentRaidCatalogKey()
            local configured, total = self:GetRaidBossConfigurationCounts(raidKey)
            raidPage.current:SetText(T("CURRENT_RAID_STATUS", tostring(self:GetRaidName() or T("CONTEXT_RAID")), configured, total))
        else
            raidPage.current:SetText(T("NOT_IN_RAID"))
        end
    end

    for kind, button in pairs(mainFrame.automationButtons or {}) do
        local key = kind == "lootSpec" and "AUTOMATION_LOOTSPEC" or ("AUTOMATION_" .. string.upper(kind))
        button.text:SetText(T("AUTOMATION_BUTTON", T(key), AutomationModeLabel(self:GetAutomationMode(kind))))
    end

    mainFrame.hudToggle.text:SetText(DB.hud.enabled and T("HUD_ON") or T("HUD_OFF"))
    mainFrame.hudLock.text:SetText(DB.hud.locked and T("HUD_LOCKED") or T("HUD_UNLOCKED"))
    mainFrame.minimapToggle.text:SetText(DB.minimap.hide and T("MINIMAP_OFF") or T("MINIMAP_ON"))
    mainFrame.chatToggle.text:SetText(DB.chatMessages and T("CHAT_MESSAGES_ON") or T("CHAT_MESSAGES_OFF"))
    mainFrame.languageButton.text:SetText(T("LANGUAGE_BUTTON", self:GetLanguageOverrideLabel()))
    mainFrame.debugToggle.text:SetText(DB.debug and T("DEBUG_BUTTON_ON") or T("DEBUG_BUTTON_OFF"))
    mainFrame.eventPreview:SetText(T("EVENT_LOG_PREVIEW", self:GetRecentEventLogText(6)))

    local page = mainFrame.pages[DB.selectedPage] and DB.selectedPage or "general"
    DB.selectedPage = page
    for key, child in pairs(mainFrame.pages) do child:SetShown(key == page) end
    for key, button in pairs(pageButtons) do
        if key == page then
            button:SetBackdropColor(0.055,0.20,0.27,0.98); button:SetBackdropBorderColor(0.38,0.82,1.0,1)
        else
            button:SetBackdropColor(0.04,0.10,0.13,0.95); button:SetBackdropBorderColor(0.16,0.45,0.56,1)
        end
    end
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
            button.text:SetText("|cff69d8ff>|r " .. label)
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
    if specPicker then specPicker:Hide() end
    if lootSpecPicker then lootSpecPicker:Hide() end
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
    if pendingLootSpecID ~= nil then
        local currentLootSpecID = self:GetLootSpecializationID()
        if currentLootSpecID == pendingLootSpecID then
            local label = self:GetLootSpecDisplayName(pendingLootSpecID)
            local restored = pendingLootSpecIsRestore
            self:ClearPendingLootSpecChange()
            AppendEventLog("loot", (restored and "Restored " or "Switched to ") .. tostring(label))
            Print(restored and T("LOOT_SPEC_RESTORED", label) or T("LOOT_SPEC_SWITCHED", label))
            if restored then
                activeLootSpecOverrideKey = nil
                lootSpecRestoreID = nil
            end
        end
    end

    if pendingSpecID then
        local currentSpecID = select(1, self:GetSpecInfo())
        if currentSpecID == pendingSpecID then
            local name = self:GetSpecNameByID(pendingSpecID) or T("UNKNOWN")
            self:ClearPendingSpecSwitch()
            AppendEventLog("spec", "Switched to " .. tostring(name))
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
                AppendEventLog("gear", "Equipped " .. tostring(binding.name))
                Print(T("GEAR_SWITCHED", binding.name, ContextName(rule.context)))
            end
        end
    end
end

function addon:UpdateAll()
    self:UpdatePendingState()
    self:UpdateMainFrame()
    self:UpdateStatusWidget()
    self:UpdateNotification()
    self:UpdateMinimapButton()
    if dungeonOverrideFrame and dungeonOverrideFrame:IsShown() then
        self:UpdateDungeonOverrideFrame()
    end
    if raidBossOverrideFrame and raidBossOverrideFrame:IsShown() then
        self:UpdateRaidBossOverrideFrame()
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
    local raw = type(LoadoutPilotDB) == "table" and LoadoutPilotDB or {}
    local legacyModes = type(raw.automationModes) == "table" and raw.automationModes or nil
    local legacyAutoSpec, legacyAutoTalents, legacyAutoGear = raw.autoSpec, raw.autoTalents, raw.autoGear
    LoadoutPilotDB = CopyDefaults(DEFAULTS, raw)
    DB = LoadoutPilotDB
    DB.specBindings = type(DB.specBindings) == "table" and DB.specBindings or {}
    DB.talentBindings = type(DB.talentBindings) == "table" and DB.talentBindings or {}
    DB.equipmentBindings = type(DB.equipmentBindings) == "table" and DB.equipmentBindings or {}
    DB.dungeonOverrides = type(DB.dungeonOverrides) == "table" and DB.dungeonOverrides or {}
    DB.knownDungeons = type(DB.knownDungeons) == "table" and DB.knownDungeons or {}
    DB.raidBossOverrides = type(DB.raidBossOverrides) == "table" and DB.raidBossOverrides or {}
    DB.knownRaidBosses = type(DB.knownRaidBosses) == "table" and DB.knownRaidBosses or {}
    self:CleanupKnownRaidBosses()
    DB.eventLog = type(DB.eventLog) == "table" and DB.eventLog or {}
    CompactEventLog()
    DB.automationModes = type(DB.automationModes) == "table" and DB.automationModes or {}

    -- v1.x -> v2 migration: preserve the previous ON/OFF behavior rather than
    -- silently turning a disabled automation category back on.
    if not legacyModes then
        DB.automationModes.spec = legacyAutoSpec == false and "off" or "auto"
        DB.automationModes.talents = legacyAutoTalents == false and "off" or "auto"
        DB.automationModes.gear = legacyAutoGear == false and "off" or "auto"
        DB.automationModes.lootSpec = "auto"
    end
    DB.automationModes.spec = NormalizeAutomationMode(DB.automationModes.spec, DB.autoSpec ~= false)
    DB.automationModes.talents = NormalizeAutomationMode(DB.automationModes.talents, DB.autoTalents ~= false)
    DB.automationModes.gear = NormalizeAutomationMode(DB.automationModes.gear, DB.autoGear ~= false)
    DB.automationModes.lootSpec = NormalizeAutomationMode(DB.automationModes.lootSpec, true)
    DB.autoSpec = DB.automationModes.spec == "auto"
    DB.autoTalents = DB.automationModes.talents == "auto"
    DB.autoGear = DB.automationModes.gear == "auto"

    self:MigrateUnifiedDungeonOverrides()
    DB.schema = Data.schema
    DB.languageOverride = NormalizeAddonLanguage(DB.languageOverride)
    if LP.SetLocaleOverride then LP.SetLocaleOverride(DB.languageOverride) end
    if not Data.contextLabelKeys[DB.selectedContext] then DB.selectedContext = "world" end
    local validPages = {general=true,contexts=true,dungeons=true,raids=true,automation=true,hud=true,advanced=true}
    if not validPages[DB.selectedPage] then DB.selectedPage = "general" end
    AppendEventLog("init", "Loadout Pilot " .. tostring(Data.version) .. " schema=" .. tostring(Data.schema))
end

function addon:CreateUI()
    mainFrame = CreateMainFrame()
    statusWidget = CreateStatusWidget()
    minimapButton = CreateMinimapButton()
    languagePicker = CreateLanguagePicker()
    notifyFrame = CreateNotifyFrame()
    dungeonOverrideFrame = CreateDungeonOverrideFrame()
    raidBossOverrideFrame = CreateRaidBossOverrideFrame()
    transferFrame = CreateTransferFrame()
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
    Print(string.format("%s - %s | %s", tostring(className), tostring(currentSpecName), self:GetContextDetailLabel(rule)), true)
    if rule and rule.dungeonInfo then
        Print(T("DUNGEON_LABEL") .. ": " .. tostring(rule.dungeonInfo.name) .. (rule.override and (" (" .. T("OVERRIDE_ACTIVE") .. ")") or ""), true)
    end
    if rule and rule.raidBossInfo then
        Print(T("RAID_BOSS") .. ": " .. tostring(rule.raidBossInfo.name or T("UNKNOWN")), true)
    end
    if rule and rule.configuredSpecID and rule.configuredSpecID ~= currentSpecID then
        Print(T("TARGET_SPEC") .. ": " .. tostring(self:GetSpecNameByID(rule.configuredSpecID) or T("UNKNOWN")), true)
    end
    if rule and rule.lootSpecID ~= nil then
        Print(T("LOOT_SPECIALIZATION") .. ": " .. self:GetLootSpecDisplayName(rule.lootSpecID), true)
    end
    Print(T("TALENTS") .. ": " .. (talent and talent.name or T("NO_MAPPING")), true)
    Print(T("GEAR") .. ": " .. (gear and gear.name or T("NO_MAPPING")), true)
    Print(T("AUTOMATION_SPEC") .. ": " .. AutomationModeLabel(self:GetAutomationMode("spec")), true)
    Print(T("AUTOMATION_TALENTS") .. ": " .. AutomationModeLabel(self:GetAutomationMode("talents")), true)
    Print(T("AUTOMATION_GEAR") .. ": " .. AutomationModeLabel(self:GetAutomationMode("gear")), true)
    Print(T("AUTOMATION_LOOTSPEC") .. ": " .. AutomationModeLabel(self:GetAutomationMode("lootSpec")), true)
    if rule and rule.sources then
        Print(T("SOURCE_SPEC") .. ": " .. tostring(rule.sources.spec or T("UNKNOWN")), true)
        Print(T("SOURCE_LOOT") .. ": " .. tostring(rule.sources.lootSpec or T("UNKNOWN")), true)
        Print(T("SOURCE_TALENTS") .. ": " .. tostring(rule.sources.talents or T("UNKNOWN")), true)
        Print(T("SOURCE_GEAR") .. ": " .. tostring(rule.sources.gear or T("UNKNOWN")), true)
    end
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
        "PLAYER_LOOT_SPEC_UPDATED",
        "PLAYER_ROLES_ASSIGNED",
        "GROUP_ROSTER_UPDATE",
        "ENCOUNTER_START",
        "ENCOUNTER_END",
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
                    addon:TrySwitchEquipment("equipment-swap-finished", IsExplicitApplyKind("gear"))
                end
            end)
        end
    elseif event == "PLAYER_LOOT_SPEC_UPDATED" then
        self:UpdatePendingState()
        if C_Timer and C_Timer.After then
            C_Timer.After(0.20, function() addon:ApplyCurrentRules("loot-spec-updated", false) end)
        else
            self:ApplyCurrentRules("loot-spec-updated", false)
        end
    elseif event == "ENCOUNTER_START" then
        local encounterID, encounterName, difficultyID = ...
        self:HandleEncounterStart(encounterID, encounterName, difficultyID)
    elseif event == "ENCOUNTER_END" then
        local encounterID, encounterName, difficultyID, groupSize, success, encounterUnitStatus = ...
        self:HandleEncounterEnd(encounterID, encounterName, difficultyID, groupSize, success, encounterUnitStatus)
    elseif event == "PLAYER_ROLES_ASSIGNED" then
        lastRoleMismatchKey = nil
        self:ApplyCurrentRules("role-assigned", false)
    elseif event == "GROUP_ROSTER_UPDATE" then
        lastRoleMismatchKey = nil
        self:ApplyCurrentRules("group-roster", false)
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
                if addon:IsInsideRaidInstance() then
                    addon:DiscoverCurrentRaidBossesFromJournal()
                elseif activeRaidBossKey then
                    activeRaidBossKey = nil
                    lastRaidBossTargetKey = nil
                    dismissedNotifyKey = nil
                end
                ClearNotificationApply()
                manualApplyPending = false
                addon:ApplyCurrentRules("context-event", false)
            end)
        else
            lastContext = self:DetectContext()
            local dungeon = self:GetCurrentDungeonInfo()
            lastDungeonKey = dungeon and dungeon.key or nil
            if self:IsInsideRaidInstance() then
                self:DiscoverCurrentRaidBossesFromJournal()
            elseif activeRaidBossKey then
                activeRaidBossKey = nil
                lastRaidBossTargetKey = nil
                dismissedNotifyKey = nil
            end
            ClearNotificationApply()
            manualApplyPending = false
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
        AppendEventLog("context", tostring(lastContext) .. "/" .. tostring(lastDungeonKey) .. " -> " .. tostring(context) .. "/" .. tostring(dungeonKey))
        lastContext = context
        lastDungeonKey = dungeonKey
        self:ClearPendingSpecSwitch()
        self:ClearPendingTalentSwitch()
        pendingGearKey = nil
        lastGearError = nil
        gearRetryElapsed = 0
        self:ClearPendingLootSpecChange()
        ClearNotificationApply()
        manualApplyPending = false
        lastRoleMismatchKey = nil
        self:ApplyCurrentRules("context-detected", false)
    else
        self:UpdatePendingState()

        if pendingSpecID and not pendingSpecInProgress and (not InCombatLockdown or not InCombatLockdown()) then
            specRetryElapsed = specRetryElapsed + interval
            if specRetryElapsed >= 2.0 then
                specRetryElapsed = 0
                self:TrySwitchSpecialization("pending-spec-retry", IsExplicitApplyKind("spec"))
            end
        elseif not pendingSpecID then
            specRetryElapsed = 0
        end

        if pendingLootSpecID ~= nil then
            lootSpecRetryElapsed = lootSpecRetryElapsed + interval
            if lootSpecRetryElapsed >= 1.0 then
                lootSpecRetryElapsed = 0
                self:SyncLootSpecializationRule(self:ResolveRuntimeRule(IsExplicitApplyKind("lootSpec")), "pending-loot-spec-retry", IsExplicitApplyKind("lootSpec"))
            end
        else
            lootSpecRetryElapsed = 0
        end

        if not pendingSpecID then
            if pendingTalentKey and not pendingTalentInProgress and (not InCombatLockdown or not InCombatLockdown()) then
                talentRetryElapsed = talentRetryElapsed + interval
                if talentRetryElapsed >= 1.0 then
                    talentRetryElapsed = 0
                    self:TrySwitchTalents("pending-talent-retry", IsExplicitApplyKind("talents"))
                end
            elseif not pendingTalentKey then
                talentRetryElapsed = 0
            end

            if pendingGearKey and (not InCombatLockdown or not InCombatLockdown()) then
                gearRetryElapsed = gearRetryElapsed + interval
                if gearRetryElapsed >= 1.0 then
                    gearRetryElapsed = 0
                    self:TrySwitchEquipment("pending-retry", IsExplicitApplyKind("gear"))
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
    elseif command == "explain" or command == "why" then
        addon:PrintExplain()
    elseif command == "overrides" or command == "dungeons" or command == "dungeon" then
        addon:ToggleDungeonOverrides()
    elseif command == "bosses" or command == "boss" or command == "raidbosses" or command == "raid" then
        addon:ToggleRaidBossOverrides()
    elseif command == "mode" or command == "automation" then
        local kind, mode = rest:match("^(%S+)%s+(%S+)$")
        kind = string.lower(kind or "")
        mode = string.lower(mode or "")
        local aliases = { spec="spec", specialization="spec", talents="talents", talent="talents", gear="gear", equipment="gear", loot="lootSpec", lootspec="lootSpec", lootspecialization="lootSpec" }
        local resolvedKind = aliases[kind]
        if resolvedKind and (mode == "auto" or mode == "notify" or mode == "off") then
            addon:SetAutomationMode(resolvedKind, mode)
        else
            Print(T("HELP"), true)
        end
    elseif command == "spec" or command == "specialization" then
        -- Backward-compatible shortcut: /lpilot spec on|off maps to AUTO/OFF.
        local value = string.lower(rest)
        if value == "on" or value == "1" or value == "true" or value == "ligado" or value == "auto" then
            addon:SetAutomationMode("spec", "auto")
        elseif value == "notify" or value == "avisar" then
            addon:SetAutomationMode("spec", "notify")
            addon:ClearPendingSpecSwitch()
        elseif value == "off" or value == "0" or value == "false" or value == "desligado" then
            addon:SetAutomationMode("spec", "off")
            addon:ClearPendingSpecSwitch()
        else
            addon:CycleAutomationMode("spec")
        end
    elseif command == "export" then
        addon:ShowTransferFrame("export")
    elseif command == "import" then
        addon:ShowTransferFrame("import")
    elseif command == "log" or command == "history" then
        if string.lower(rest) == "clear" then
            DB.eventLog = {}
            lastLoggedRuleSignature = nil
            lastLoggedNotifyKey = nil
            Print(T("EVENT_LOG_CLEARED"), true)
            addon:UpdateAll()
        else
            addon:ShowTransferFrame("log")
        end
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
        AppendEventLog("debug", "debug=" .. tostring(DB.debug))
        Print(DB.debug and T("DEBUG_ON") or T("DEBUG_OFF"), true)
        addon:UpdateAll()
    else
        Print(T("HELP"), true)
    end
end

