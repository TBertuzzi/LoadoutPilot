local ROOT = (arg and arg[1]) or "."

local state = {
    locale = "ptBR",
    specIndex = 1,
    specID = 64,
    specName = "Frost",
    selectedTalent = 101,
    inDelve = false,
    inInstance = false,
    instanceType = "none",
    challenge = false,
    slottedKeystone = false,
    combat = false,
    equippedSet = 1,
    equipmentUseFailures = 0,
    talentEditFailures = 0,
    talentSwitchFailures = 0,
}

local talentIDs = {101, 202}
local talentNames = { [101] = "Frost World", [202] = "Frost Dungeon" }
local gearNames = { [1] = "World Gear", [2] = "Dungeon Gear" }

local function widget()
    local o = { shown = false, point = {"CENTER", nil, "CENTER", 0, 0}, scripts = {} }
    local methods = {}
    function methods:SetSize() end
    function methods:SetWidth() end
    function methods:SetHeight() end
    function methods:SetFrameStrata() end
    function methods:SetFrameLevel() end
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
GameTooltip = { SetOwner=function() end, AddLine=function() end, Show=function() end, Hide=function() end }
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
function GetSpecializationInfo() return state.specID, state.specName, "", 135846 end
function UnitClass() return "Mage", "MAGE", 8 end
function IsInInstance() return state.inInstance, state.instanceType end
function InCombatLockdown() return state.combat end
function issecretvalue() return false end
function GetCursorPosition() return 350, 350 end

C_Timer = { After = function(_, fn) fn() end }
C_PartyInfo = {
    IsDelveInProgress = function() return state.inDelve end,
    IsChallengeModeActive = function() return state.challenge end,
}
C_ChallengeMode = {
    IsChallengeModeActive = function() return state.challenge end,
    HasSlottedKeystone = function() return state.slottedKeystone end,
}
C_Traits = {
    GetConfigInfo = function(id)
        if not talentNames[id] then return nil end
        return { ID=id, name=talentNames[id] }
    end,
}
C_ClassTalents = {
    GetConfigIDsBySpecID = function() return talentIDs end,
    GetLastSelectedSavedConfigID = function() return state.selectedTalent end,
    GetActiveConfigID = function() return state.selectedTalent end,
    UpdateLastSelectedSavedConfigID = function(_, id) state.selectedTalent = id end,
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
        state.selectedTalent = talentIDs[index]
    end,
    LoadConfig = function(id)
        if not talentNames[id] then return Enum.LoadConfigResult.Error, "missing" end
        state.selectedTalent = id
        return Enum.LoadConfigResult.Ready
    end,
}
C_EquipmentSet = {
    GetEquipmentSetIDs = function() return {1,2} end,
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

-- Load and initialize.
event("ADDON_LOADED", "LoadoutPilot")
event("PLAYER_LOGIN")
assert(type(LoadoutPilotDB) == "table", "DB not initialized")
assert(LoadoutPilotDB.autoTalents == true and LoadoutPilotDB.autoGear == true, "auto defaults wrong")
assert(LoadoutPilotDB.selectedContext == "world", "default context wrong")
assert(LoadoutPilotDB.languageOverride == "auto", "language override default wrong")
assert(LoadoutPilotDB.chatMessages == true, "chat messages default wrong")
SlashCmdList.LOADOUTPILOT("chat off")
assert(LoadoutPilotDB.chatMessages == false, "chat messages did not disable")
SlashCmdList.LOADOUTPILOT("chat on")
assert(LoadoutPilotDB.chatMessages == true, "chat messages did not enable")
assert(LP.GetLocaleOverride and LP.GetLocaleOverride() == "auto", "localization override did not initialize")
SlashCmdList.LOADOUTPILOT("language en")
assert(LoadoutPilotDB.languageOverride == "enUS", "English language override was not saved")
SlashCmdList.LOADOUTPILOT("idioma ptbr")
assert(LoadoutPilotDB.languageOverride == "ptBR", "Portuguese language override was not saved")
SlashCmdList.LOADOUTPILOT("lang auto")
assert(LoadoutPilotDB.languageOverride == "auto", "automatic language override was not restored")

-- Manual automation state is visible in the compact HUD.
LoadoutPilotDB.autoTalents = false
LoadoutPilotDB.autoGear = false
addon:UpdateStatusWidget()
assert(_G.LoadoutPilotStatusWidget.title.text and _G.LoadoutPilotStatusWidget.title.text:find("MANUAL", 1, true), "talent manual marker missing")
assert(_G.LoadoutPilotStatusWidget.talent.text and _G.LoadoutPilotStatusWidget.talent.text:find("MANUAL", 1, true), "gear manual marker missing")
LoadoutPilotDB.autoTalents = true
LoadoutPilotDB.autoGear = true
addon:UpdateStatusWidget()

-- Reset restores both HUD and minimap positions.
LoadoutPilotDB.hud.x = 123
LoadoutPilotDB.hud.y = -77
LoadoutPilotDB.minimap.angle = 45
SlashCmdList.LOADOUTPILOT("resetpos")
assert(LoadoutPilotDB.hud.x == 0 and LoadoutPilotDB.hud.y == 170, "HUD reset failed")
assert(LoadoutPilotDB.minimap.angle == 225, "minimap reset failed")

-- Minimap button uses the actual minimap dimensions instead of a fixed radius.
local minimapButton = _G.LoadoutPilotMinimapButton
if minimapButton then
    local _, relativeTo, _, x, y = minimapButton:GetPoint()
    assert(relativeTo == Minimap, "minimap button is not anchored to Minimap")
    local angle = math.rad(LoadoutPilotDB.minimap.angle or 225)
    local expectedX = math.cos(angle) * ((Minimap:GetWidth() * 0.5) + 10)
    local expectedY = math.sin(angle) * ((Minimap:GetHeight() * 0.5) + 10)
    assert(math.abs(x - expectedX) < 0.01, "minimap X orbit is wrong")
    assert(math.abs(y - expectedY) < 0.01, "minimap Y orbit is wrong")
end

-- World mapping and explicit apply.
LoadoutPilotDB.talentBindings["64:world"] = {configID=202, name="Frost Dungeon"}
LoadoutPilotDB.equipmentBindings["64:world"] = {setID=2, name="Dungeon Gear"}
SlashCmdList.LOADOUTPILOT("apply")
assert(state.selectedTalent == 202, "world talent auto/apply failed")
assert(state.equippedSet == 2, "world gear auto/apply failed")

-- Delve context switches automatically.
LoadoutPilotDB.talentBindings["64:delve"] = {configID=101, name="Frost World"}
LoadoutPilotDB.equipmentBindings["64:delve"] = {setID=1, name="World Gear"}
state.inDelve = true
state.inInstance = true
state.instanceType = "party"
tick(0.6)
assert(addon:DetectContext() == "delve", "delve detection failed")
assert(state.selectedTalent == 101, "delve talent switch failed")
assert(state.equippedSet == 1, "delve gear switch failed")

-- Dungeon change during combat queues, then applies after combat.
LoadoutPilotDB.talentBindings["64:dungeon"] = {configID=202, name="Frost Dungeon"}
LoadoutPilotDB.equipmentBindings["64:dungeon"] = {setID=2, name="Dungeon Gear"}
state.inDelve = false
state.challenge = false
state.combat = true
tick(0.6)
assert(addon:DetectContext() == "dungeon", "dungeon detection failed")
assert(state.selectedTalent == 101, "talents changed during combat")
assert(state.equippedSet == 1, "gear changed during combat")
state.combat = false
event("PLAYER_REGEN_ENABLED")
assert(state.selectedTalent == 202, "queued dungeon talent switch failed")
assert(state.equippedSet == 2, "queued dungeon gear switch failed")

-- Mythic+ is distinct from dungeon, including the pre-start slotted-key state.
state.slottedKeystone = true
assert(addon:DetectContext() == "mythicplus", "slotted-keystone mythic+ detection failed")
state.slottedKeystone = false
state.challenge = true
assert(addon:DetectContext() == "mythicplus", "active mythic+ detection failed")

-- Raid and PvP detection.
state.challenge = false
state.instanceType = "raid"
assert(addon:DetectContext() == "raid", "raid detection failed")
state.instanceType = "pvp"
assert(addon:DetectContext() == "pvp", "pvp detection failed")
tick(0.6)

-- Leaving PvP can transiently reject both talent and equipment requests. The
-- addon must keep retrying the World mappings until both are confirmed. The
-- talent delegate is also forced to miss once so the LoadConfig fallback path
-- is exercised.
LoadoutPilotDB.talentBindings["64:pvp"] = {configID=101, name="Frost World"}
LoadoutPilotDB.talentBindings["64:world"] = {configID=202, name="Frost Dungeon"}
LoadoutPilotDB.equipmentBindings["64:pvp"] = {setID=1, name="World Gear"}
LoadoutPilotDB.equipmentBindings["64:world"] = {setID=2, name="Dungeon Gear"}
state.selectedTalent = 101
state.equippedSet = 1
state.talentEditFailures = 1
state.talentSwitchFailures = 1
state.equipmentUseFailures = 1
state.inInstance = false
state.instanceType = "none"
tick(0.6)
assert(addon:DetectContext() == "world", "world detection after pvp failed")
tick(0.6)
tick(0.6)
assert(state.selectedTalent == 202, "pending world talents were not retried after leaving pvp")
assert(state.equippedSet == 2, "pending world gear was not retried after leaving pvp")
addon:UpdateStatusWidget()
local hudStatus = _G.LoadoutPilotStatusWidget.gear.text or ""
assert(not hudStatus:find("Applying", 1, true) and not hudStatus:find("Aplicando", 1, true), "HUD remained stuck on Applying after PvP exit")

print("Smoke test passed: language selection, chat toggle, position reset, manual HUD state, generic mappings, context detection, auto switching, combat queue, and PvP exit talent/gear retry.")
