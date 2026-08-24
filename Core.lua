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
local contextButtons = {}
local pollElapsed = 0
local lastContext
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
    schema = 1,
    firstRun = true,
    selectedContext = "world",
    autoTalents = true,
    autoGear = true,
    chatMessages = true,
    debug = false,
    languageOverride = "auto",
    talentBindings = {},
    equipmentBindings = {},
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

function addon:GetSpecInfo()
    local specIndex = GetSpecialization and GetSpecialization() or nil
    if not specIndex then
        return nil, T("UNKNOWN"), nil, nil
    end
    local specID, specName, _, specIcon = GetSpecializationInfo(specIndex)
    return specID, specName or T("UNKNOWN"), specIcon, specIndex
end

function addon:GetPlayerClassInfo()
    local className, classFile, classID = UnitClass("player")
    return className or T("UNKNOWN"), classFile, classID
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
    local context = self:DetectContext()
    local binding = specID and self:ResolveTalentBinding(specID, context) or nil

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
    local specID = select(1, self:GetSpecInfo())
    if not specID then return false end
    local context = self:DetectContext()
    local key = BindingKey(specID, context)
    local binding = self:ResolveTalentBinding(specID, context)
    if type(binding) ~= "table" or not binding.configID then
        self:ClearPendingTalentSwitch()
        return true
    end

    if self:GetSelectedTalentConfigID(specID) == binding.configID then
        self:ClearPendingTalentSwitch()
        return true
    end

    -- A context change replaces any older pending target.
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

    -- Prefer Blizzard's saved-loadout switch because it keeps the default loadout
    -- selector synchronized. If the transition never confirms, the watcher falls
    -- back to LoadConfig once.
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
    local specID = select(1, self:GetSpecInfo())
    if not specID then return false end
    local context = self:DetectContext()
    local key = BindingKey(specID, context)
    local binding, info = self:ResolveEquipmentBinding(specID, context)
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
            -- Keep the target pending until Equipment Manager reports that this
            -- exact set is actually equipped. A successful API return means the
            -- swap request was accepted, not that a later transition cannot abort it.
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
    self:TrySwitchTalents(reason or "apply", userInitiated == true)
    self:TrySwitchEquipment(reason or "apply", userInitiated == true)
    self:ScheduleUpdate()
end

function addon:BindTalent(configID)
    local specID, specName = self:GetSpecInfo()
    if not specID then return end
    local context = DB.selectedContext
    local name = self:GetTalentName(configID)
    if not name then return end
    DB.talentBindings[BindingKey(specID, context)] = { configID = configID, name = name }
    self:ClearPendingTalentSwitch()
    Print(T("TALENT_MAPPED", name, specName, ContextName(context)), true)
    self:UpdateAll()
    if DB.autoTalents and context == self:DetectContext() then self:ApplyCurrentRules("mapping", false) end
end

function addon:BindEquipment(setID)
    local specID, specName = self:GetSpecInfo()
    if not specID then return end
    local context = DB.selectedContext
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
    local specID, specName = self:GetSpecInfo()
    if not specID then return end
    local context = DB.selectedContext
    DB.talentBindings[BindingKey(specID, context)] = nil
    self:ClearPendingTalentSwitch()
    Print(T("TALENT_CLEARED", specName, ContextName(context)), true)
    self:UpdateAll()
end

function addon:ClearEquipmentBinding()
    local specID, specName = self:GetSpecInfo()
    if not specID then return end
    local context = DB.selectedContext
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

function addon:PopulateTalentPicker()
    if not talentPicker then return end
    local specID = select(1, self:GetSpecInfo())
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
        row.text:SetText((entry.selected and "|cff66ff99* |r" or "") .. entry.name)
        row:SetScript("OnClick", function()
            talentPicker:Hide()
            addon:BindTalent(entry.configID)
        end)
        row:Show()
        y = y - 28
    end
    talentPicker:SetHeight(math.min(260, 14 + (#list * 28)))
end

function addon:PopulateGearPicker()
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
            addon:BindEquipment(entry.setID)
        end)
        row:Show()
        y = y - 28
    end
    gearPicker:SetHeight(math.min(260, 14 + (#list * 28)))
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
    frame:SetSize(650, 468)
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
    frame.close:SetScript("OnClick", function() HidePickers(); frame:Hide() end)

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

    frame.talentLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.talentLabel:SetPoint("TOPLEFT", 18, -196)
    frame.talentLabel:SetText(T("TALENT_LOADOUT"))

    frame.talentValue = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.talentValue:SetPoint("TOPLEFT", 18, -219)
    frame.talentValue:SetWidth(600)
    frame.talentValue:SetJustifyH("LEFT")

    frame.talentChoose = CreateButton(frame, T("CHOOSE_TALENT"), 250, 26)
    frame.talentChoose:SetPoint("TOPLEFT", 18, -244)
    frame.talentChoose:SetScript("OnClick", function()
        gearPicker:Hide()
        addon:PopulateTalentPicker()
        talentPicker:ClearAllPoints()
        talentPicker:SetPoint("TOPLEFT", frame.talentChoose, "BOTTOMLEFT", 0, -4)
        talentPicker:SetShown(not talentPicker:IsShown())
    end)

    frame.talentClear = CreateButton(frame, T("CLEAR"), 84, 26)
    frame.talentClear:SetPoint("LEFT", frame.talentChoose, "RIGHT", 8, 0)
    frame.talentClear:SetScript("OnClick", function() addon:ClearTalentBinding() end)

    frame.gearLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.gearLabel:SetPoint("TOPLEFT", 18, -286)
    frame.gearLabel:SetText(T("EQUIPMENT_SET"))

    frame.gearValue = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.gearValue:SetPoint("TOPLEFT", 18, -309)
    frame.gearValue:SetWidth(600)
    frame.gearValue:SetJustifyH("LEFT")

    frame.gearChoose = CreateButton(frame, T("CHOOSE_GEAR"), 250, 26)
    frame.gearChoose:SetPoint("TOPLEFT", 18, -334)
    frame.gearChoose:SetScript("OnClick", function()
        talentPicker:Hide()
        addon:PopulateGearPicker()
        gearPicker:ClearAllPoints()
        gearPicker:SetPoint("TOPLEFT", frame.gearChoose, "BOTTOMLEFT", 0, -4)
        gearPicker:SetShown(not gearPicker:IsShown())
    end)

    frame.gearClear = CreateButton(frame, T("CLEAR"), 84, 26)
    frame.gearClear:SetPoint("LEFT", frame.gearChoose, "RIGHT", 8, 0)
    frame.gearClear:SetScript("OnClick", function() addon:ClearEquipmentBinding() end)

    frame.autoTalents = CreateButton(frame, "", 145, 26)
    frame.autoTalents:SetPoint("TOPLEFT", 373, -244)
    frame.autoTalents:SetScript("OnClick", function()
        DB.autoTalents = not DB.autoTalents
        addon:UpdateAll()
        if DB.autoTalents then addon:ApplyCurrentRules("toggle", false) end
    end)

    frame.autoGear = CreateButton(frame, "", 145, 26)
    frame.autoGear:SetPoint("TOPLEFT", 373, -334)
    frame.autoGear:SetScript("OnClick", function()
        DB.autoGear = not DB.autoGear
        addon:UpdateAll()
        if DB.autoGear then addon:ApplyCurrentRules("toggle", false) end
    end)

    frame.hudToggle = CreateButton(frame, "", 145, 26)
    frame.hudToggle:SetPoint("TOPLEFT", 18, -378)
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

    frame.chatToggle = CreateButton(frame, "", 200, 26)
    frame.chatToggle:SetPoint("TOPLEFT", 18, -412)
    frame.chatToggle:SetScript("OnClick", function()
        DB.chatMessages = not DB.chatMessages
        addon:UpdateAll()
        Print(DB.chatMessages and T("CHAT_MESSAGES_ON_CONFIRM") or T("CHAT_MESSAGES_OFF_CONFIRM"), true)
    end)

    frame.resetPositions = CreateButton(frame, T("RESET_POSITIONS"), 220, 26)
    frame.resetPositions:SetPoint("LEFT", frame.chatToggle, "RIGHT", 8, 0)
    frame.resetPositions:SetScript("OnClick", function() addon:ResetPositions() end)

    frame.version = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.version:SetPoint("BOTTOMRIGHT", -14, 10)
    frame.version:SetText(T("VERSION", Data.version))

    talentPicker = CreatePicker("LoadoutPilotTalentPicker", frame, 300)
    gearPicker = CreatePicker("LoadoutPilotGearPicker", frame, 300)

    frame:Hide()
    return frame
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

    local specID, specName = self:GetSpecInfo()
    local className = self:GetPlayerClassInfo()
    local context = self:DetectContext()
    local talentBinding = specID and self:ResolveTalentBinding(specID, context) or nil
    local gearBinding, gearInfo = nil, nil
    if specID then gearBinding, gearInfo = self:ResolveEquipmentBinding(specID, context) end

    local talentText = T("NO_MAPPING")
    if type(talentBinding) == "table" then
        local actualName = self:GetTalentName(talentBinding.configID)
        if actualName then talentText = actualName else talentText = T("MISSING_LOADOUT") end
    end

    local gearText = T("NO_MAPPING")
    if type(gearBinding) == "table" then
        if gearInfo then
            gearText = gearInfo.name
        else
            gearText = T("MISSING_GEAR")
        end
    end

    GameTooltip:SetOwner(widget, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(T("ADDON_TITLE"))
    GameTooltip:AddDoubleLine(T("CLASS_LABEL"), tostring(className), 0.85, 0.92, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine(T("SPEC_LABEL"), tostring(specName), 0.85, 0.92, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine(T("CONTEXT_LABEL"), ContextName(context), 0.85, 0.92, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine(T("TALENTS"), tostring(talentText), 0.85, 0.92, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine(T("GEAR"), tostring(gearText), 0.85, 0.92, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine(T("STATUS"), tostring(self:GetStatusState(specID, context)), 0.85, 0.92, 1, 1, 1, 1)
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

function addon:GetStatusState(specID, context)
    local talentBinding = self:ResolveTalentBinding(specID, context)
    local gearBinding, gearInfo = self:ResolveEquipmentBinding(specID, context)
    local currentTalentID = self:GetSelectedTalentConfigID(specID)

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
    local specID, specName, specIcon = self:GetSpecInfo()
    local className, classFile = self:GetPlayerClassInfo()
    local context = self:DetectContext()
    local talentBinding = specID and self:ResolveTalentBinding(specID, context) or nil
    local gearBinding, gearInfo = specID and self:ResolveEquipmentBinding(specID, context) or nil, nil
    if specID then gearBinding, gearInfo = self:ResolveEquipmentBinding(specID, context) end

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
    local currentTalent = self:GetSelectedTalentConfigID(specID)
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
    statusWidget.gear:SetText(self:GetStatusState(specID, context))
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

    mainFrame.currentIcon:SetTexture(specIcon or 134400)
    mainFrame.currentTitle:SetText(string.format("%s - %s", tostring(className), tostring(specName)))
    mainFrame.currentContext:SetText(string.format("%s: %s", T("CURRENT"), ContextName(actualContext)))

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

    local talentBinding = specID and self:ResolveTalentBinding(specID, configContext) or nil
    if talentBinding then
        local name = self:GetTalentName(talentBinding.configID)
        mainFrame.talentValue:SetText(name or ("|cffff7777" .. T("MISSING_LOADOUT") .. "|r"))
    else
        mainFrame.talentValue:SetText("|cffaaaaaa" .. T("NO_MAPPING") .. "|r")
    end

    local gearBinding, gearInfo = specID and self:ResolveEquipmentBinding(specID, configContext) or nil, nil
    if specID then gearBinding, gearInfo = self:ResolveEquipmentBinding(specID, configContext) end
    if gearBinding then
        mainFrame.gearValue:SetText(gearInfo and gearInfo.name or ("|cffff7777" .. T("MISSING_GEAR") .. "|r"))
    else
        mainFrame.gearValue:SetText("|cffaaaaaa" .. T("NO_MAPPING") .. "|r")
    end

    mainFrame.autoTalents.text:SetText(DB.autoTalents and T("AUTO_TALENTS_ON") or T("AUTO_TALENTS_OFF"))
    mainFrame.autoGear.text:SetText(DB.autoGear and T("AUTO_GEAR_ON") or T("AUTO_GEAR_OFF"))
    mainFrame.hudToggle.text:SetText(DB.hud.enabled and T("HUD_ON") or T("HUD_OFF"))
    mainFrame.hudLock.text:SetText(DB.hud.locked and T("HUD_LOCKED") or T("HUD_UNLOCKED"))
    mainFrame.minimapToggle.text:SetText(DB.minimap.hide and T("MINIMAP_OFF") or T("MINIMAP_ON"))
    mainFrame.chatToggle.text:SetText(DB.chatMessages and T("CHAT_MESSAGES_ON") or T("CHAT_MESSAGES_OFF"))
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
    if pendingTalentTargetID then
        local specID = pendingTalentSpecID or select(1, self:GetSpecInfo())
        if specID and self:GetSelectedTalentConfigID(specID) == pendingTalentTargetID then
            self:CompletePendingTalentSwitch(false)
        end
    end

    if pendingGearKey then
        local specID = select(1, self:GetSpecInfo())
        local context = self:DetectContext()
        local binding, info = self:ResolveEquipmentBinding(specID, context)
        if info and info.isEquipped then
            pendingGearKey = nil
            lastGearError = nil
            gearRetryElapsed = 0
            if binding and binding.name then
                Print(T("GEAR_SWITCHED", binding.name, ContextName(context)))
            end
        end
    end
end

function addon:UpdateAll()
    self:UpdatePendingState()
    self:UpdateMainFrame()
    self:UpdateStatusWidget()
    self:UpdateMinimapButton()
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
    DB.languageOverride = NormalizeAddonLanguage(DB.languageOverride)
    if LP.SetLocaleOverride then LP.SetLocaleOverride(DB.languageOverride) end
    if not Data.contextLabelKeys[DB.selectedContext] then DB.selectedContext = "world" end
end

function addon:CreateUI()
    mainFrame = CreateMainFrame()
    statusWidget = CreateStatusWidget()
    minimapButton = CreateMinimapButton()
    languagePicker = CreateLanguagePicker()
    self:RestoreHUDPosition()
    self:UpdateMinimapButtonPosition()
end

function addon:Open()
    HidePickers()
    mainFrame:SetShown(not mainFrame:IsShown())
    if mainFrame:IsShown() then self:UpdateAll() end
end

function addon:PrintStatus()
    local specID, specName = self:GetSpecInfo()
    local className = self:GetPlayerClassInfo()
    local context = self:DetectContext()
    local talent = specID and self:ResolveTalentBinding(specID, context) or nil
    local gear = specID and select(1, self:ResolveEquipmentBinding(specID, context)) or nil
    Print(string.format("%s - %s | %s", tostring(className), tostring(specName), ContextName(context)), true)
    Print(T("TALENTS") .. ": " .. (talent and talent.name or T("NO_MAPPING")), true)
    Print(T("GEAR") .. ": " .. (gear and gear.name or T("NO_MAPPING")), true)
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
        "PLAYER_ENTERING_BATTLEGROUND",
        "PVP_MATCH_ACTIVE",
        "PVP_MATCH_COMPLETE",
        "UPDATE_BATTLEFIELD_STATUS",
        "CHALLENGE_MODE_KEYSTONE_SLOTTED",
        "CHALLENGE_MODE_START",
        "CHALLENGE_MODE_COMPLETED",
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
        self:UpdateAll()
        if DB.firstRun then
            DB.firstRun = false
            mainFrame:Show()
            Print(T("FIRST_RUN"), true)
        end
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        pendingTalentInProgress = false
        talentRetryElapsed = 1.0
        self:ApplyCurrentRules("combat-ended", false)
    elseif event == "CONFIG_COMMIT_FAILED" then
        pendingTalentInProgress = false
        pendingTalentWatchToken = pendingTalentWatchToken + 1
        talentRetryElapsed = 1.0
        lastTalentError = T("TALENT_FAILED")
    elseif event == "TRAIT_CONFIG_UPDATED" and pendingTalentKey and pendingTalentInProgress then
        -- This is the same completion signal used by DK Mentor. The talents were
        -- committed; sync Blizzard's saved-loadout selector and clear Applying.
        self:CompletePendingTalentSwitch(true)
    elseif event == "ACTIVE_TALENT_GROUP_CHANGED" or event == "PLAYER_TALENT_UPDATE"
        or event == "PLAYER_PVP_TALENT_UPDATE" or event == "SELECTED_LOADOUT_CHANGED"
        or event == "ACTIVE_COMBAT_CONFIG_CHANGED" or event == "SPELLS_CHANGED" then
        self:UpdatePendingState()
    elseif event == "EQUIPMENT_SWAP_FINISHED" then
        local result = AccessibleBoolean((...))
        -- Never clear a pending target just because *a* swap finished. During
        -- PvP transitions this event can belong to the previous context. Verify
        -- the currently mapped set before considering the operation complete.
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
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        local unit = ...
        if not unit or unit == "player" then
            if C_Timer and C_Timer.After then
                C_Timer.After(0.8, function() addon:ApplyCurrentRules("specialization", false) end)
            end
        end
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA"
        or event == "PLAYER_ENTERING_BATTLEGROUND" or event == "PVP_MATCH_ACTIVE"
        or event == "PVP_MATCH_COMPLETE" or event == "UPDATE_BATTLEFIELD_STATUS"
        or event == "CHALLENGE_MODE_KEYSTONE_SLOTTED"
        or event == "CHALLENGE_MODE_START" or event == "CHALLENGE_MODE_COMPLETED" then
        if C_Timer and C_Timer.After then
            C_Timer.After(1.0, function()
                lastContext = addon:DetectContext()
                addon:ApplyCurrentRules("context-event", false)
            end)
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
    if context ~= lastContext then
        Debug("Context changed from " .. tostring(lastContext) .. " to " .. tostring(context))
        lastContext = context
        talentRetryElapsed = 0
        gearRetryElapsed = 0
        pendingTalentInProgress = false
        pendingTalentWatchToken = pendingTalentWatchToken + 1
        self:ApplyCurrentRules("context-detected", false)
    else
        self:UpdatePendingState()

        -- Talent changes can also be temporarily rejected while leaving PvP.
        -- Keep retrying out of combat until Blizzard confirms the mapped saved
        -- loadout, but do not issue another request while one is in progress.
        if pendingTalentKey and not pendingTalentInProgress and (not InCombatLockdown or not InCombatLockdown()) then
            talentRetryElapsed = talentRetryElapsed + interval
            if talentRetryElapsed >= 1.0 then
                talentRetryElapsed = 0
                self:TrySwitchTalents("pending-talent-retry", false)
            end
        elseif not pendingTalentKey then
            talentRetryElapsed = 0
        end

        -- Equipment Manager can briefly reject swaps while leaving PvP/instances
        -- even after PLAYER_ENTERING_WORLD fires. Keep retrying the mapped gear
        -- out of combat until the Equipment Manager confirms the target set.
        if pendingGearKey and (not InCombatLockdown or not InCombatLockdown()) then
            gearRetryElapsed = gearRetryElapsed + interval
            if gearRetryElapsed >= 1.0 then
                gearRetryElapsed = 0
                self:TrySwitchEquipment("pending-retry", false)
            end
        else
            gearRetryElapsed = 0
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
