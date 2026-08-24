local ADDON_NAME, LP = ...
LP.L = LP.L or {}
local L = LP.L

local enUS = {
    ADDON_TITLE = "Loadout Pilot",
    ADDON_SUBTITLE = "Automatic context loadouts",
    CURRENT = "Current",
    CONFIGURE_FOR = "Configure for",
    TALENT_LOADOUT = "Talent loadout",
    EQUIPMENT_SET = "Equipment set",
    CHOOSE_TALENT = "Choose talent loadout...",
    CHOOSE_GEAR = "Choose equipment set...",
    CLEAR = "Clear",
    APPLY_NOW = "Apply mapped loadout now",
    AUTO_TALENTS_ON = "Talents AUTO: ON",
    AUTO_TALENTS_OFF = "Talents AUTO: OFF",
    AUTO_GEAR_ON = "Gear AUTO: ON",
    AUTO_GEAR_OFF = "Gear AUTO: OFF",
    HUD_ON = "Status HUD: ON",
    HUD_OFF = "Status HUD: OFF",
    HUD_LOCKED = "HUD: LOCKED",
    HUD_UNLOCKED = "HUD: UNLOCKED",
    MINIMAP_ON = "Minimap icon: ON",
    MINIMAP_OFF = "Minimap icon: OFF",
    CHAT_MESSAGES_ON = "Chat messages: ON",
    CHAT_MESSAGES_OFF = "Chat messages: OFF",
    CHAT_MESSAGES_ON_CONFIRM = "Chat notifications enabled.",
    CHAT_MESSAGES_OFF_CONFIRM = "Routine automatic switch messages disabled. Configuration and status feedback will still be shown.",
    RESET_POSITIONS = "Restore positions",
    CLOSE = "Close",
    NO_MAPPING = "Not configured",
    MISSING_LOADOUT = "Saved loadout missing",
    MISSING_GEAR = "Saved equipment set missing",
    READY = "Ready",
    QUEUED_COMBAT = "Queued until combat ends",
    APPLYING = "Applying...",
    ACTION_REQUIRED = "Click Apply",
    TALENTS = "Talents",
    GEAR = "Gear",
    AUTO = "AUTO",
    MANUAL = "MANUAL",
    CONTEXT_WORLD = "World",
    CONTEXT_DELVE = "Delve",
    CONTEXT_DUNGEON = "Dungeon",
    CONTEXT_MYTHICPLUS = "Mythic+",
    CONTEXT_RAID = "Raid",
    CONTEXT_PVP = "PvP",
    OPEN_SETTINGS = "Right-click to open Loadout Pilot",
    DRAG_HINT = "Drag to move when the HUD is unlocked.",
    MINIMAP_LEFT_CLICK = "Left-click: open or close Loadout Pilot.",
    MINIMAP_RIGHT_CLICK = "Right-click: apply the mapped loadout now.",
    MINIMAP_DRAG_HINT = "Drag: move around the minimap.",
    FIRST_RUN = "Configure a talent loadout and equipment set for each content type. Loadout Pilot will switch them automatically whenever WoW allows it.",
    TALENT_MAPPED = "Mapped talent loadout '%s' to %s / %s.",
    GEAR_MAPPED = "Mapped equipment set '%s' to %s / %s.",
    TALENT_CLEARED = "Talent mapping cleared for %s / %s.",
    GEAR_CLEARED = "Equipment mapping cleared for %s / %s.",
    TALENT_SWITCHED = "Talent loadout switched to '%s' for %s.",
    GEAR_SWITCHED = "Equipment set switched to '%s' for %s.",
    WAITING_TALENTS = "WoW is not allowing talent changes right now.",
    TALENT_FAILED = "Talent switch could not be completed automatically. Use Apply when WoW allows the change.",
    GEAR_FAILED = "Equipment switch could not be completed automatically. Use Apply after combat.",
    NO_TALENTS = "No saved talent loadouts were found for this specialization.",
    NO_GEAR = "No saved equipment sets were found.",
    UNKNOWN = "Unknown",
    STATUS = "Status",
    CLASS_LABEL = "Class",
    SPEC_LABEL = "Spec",
    CONTEXT_LABEL = "Context",
    VERSION = "Version %s - Retail 12.1.0",
    LANGUAGE = "Language",
    ADDON_LANGUAGE = "Addon language",
    LANGUAGE_DESCRIPTION = "Choose the Loadout Pilot language. Automatic follows the WoW client language; unsupported client languages use English.",
    LANGUAGE_AUTO = "Automatic (WoW)",
    LANGUAGE_PTBR = "Portuguese (Brazil)",
    LANGUAGE_EN = "English",
    LANGUAGE_CURRENT = "Current: %s",
    LANGUAGE_BUTTON = "Language: %s",
    LANGUAGE_SAVED = "Language saved as %s. Type /reload to apply it.",
    CANCEL = "Cancel",
    HELP = "Commands: /lpilot, /lpilot apply, /lpilot status, /lpilot chat on|off, /lpilot language auto|ptbr|en, /lpilot resetpos, /lpilot debug",
    RESET_POS = "HUD and minimap positions restored.",
    DEBUG_ON = "Debug logging enabled.",
    DEBUG_OFF = "Debug logging disabled.",
}

local ptBR = {
    ADDON_TITLE = "Loadout Pilot",
    ADDON_SUBTITLE = "Loadouts automáticos por contexto",
    CURRENT = "Atual",
    CONFIGURE_FOR = "Configurar para",
    TALENT_LOADOUT = "Loadout de talentos",
    EQUIPMENT_SET = "Conjunto de equipamento",
    CHOOSE_TALENT = "Escolher loadout de talentos...",
    CHOOSE_GEAR = "Escolher conjunto de equipamento...",
    CLEAR = "Limpar",
    APPLY_NOW = "Aplicar loadout mapeado agora",
    AUTO_TALENTS_ON = "Talentos AUTO: LIGADO",
    AUTO_TALENTS_OFF = "Talentos AUTO: DESLIGADO",
    AUTO_GEAR_ON = "Equipamento AUTO: LIGADO",
    AUTO_GEAR_OFF = "Equipamento AUTO: DESLIGADO",
    HUD_ON = "HUD de status: LIGADO",
    HUD_OFF = "HUD de status: DESLIGADO",
    HUD_LOCKED = "HUD: BLOQUEADO",
    HUD_UNLOCKED = "HUD: DESBLOQUEADO",
    MINIMAP_ON = "Ícone no minimapa: LIGADO",
    MINIMAP_OFF = "Ícone no minimapa: DESLIGADO",
    CHAT_MESSAGES_ON = "Mensagens no chat: LIGADO",
    CHAT_MESSAGES_OFF = "Mensagens no chat: DESLIGADO",
    CHAT_MESSAGES_ON_CONFIRM = "Notificações no chat ativadas.",
    CHAT_MESSAGES_OFF_CONFIRM = "Mensagens automáticas de troca desativadas. Confirmações de configuração e status continuarão aparecendo.",
    RESET_POSITIONS = "Restaurar posições",
    CLOSE = "Fechar",
    NO_MAPPING = "Não configurado",
    MISSING_LOADOUT = "Loadout salvo não encontrado",
    MISSING_GEAR = "Conjunto salvo não encontrado",
    READY = "Pronto",
    QUEUED_COMBAT = "Na fila até o combate terminar",
    APPLYING = "Aplicando...",
    ACTION_REQUIRED = "Clique em Aplicar",
    TALENTS = "Talentos",
    GEAR = "Equipamento",
    AUTO = "AUTO",
    MANUAL = "MANUAL",
    CONTEXT_WORLD = "Mundo",
    CONTEXT_DELVE = "Imersão",
    CONTEXT_DUNGEON = "Masmorra",
    CONTEXT_MYTHICPLUS = "Mítica+",
    CONTEXT_RAID = "Raide",
    CONTEXT_PVP = "JxJ",
    OPEN_SETTINGS = "Clique com o botão direito para abrir o Loadout Pilot",
    DRAG_HINT = "Arraste para mover quando o HUD estiver desbloqueado.",
    MINIMAP_LEFT_CLICK = "Clique esquerdo: abrir ou fechar o Loadout Pilot.",
    MINIMAP_RIGHT_CLICK = "Clique direito: aplicar o loadout mapeado agora.",
    MINIMAP_DRAG_HINT = "Arraste: mover ao redor do minimapa.",
    FIRST_RUN = "Configure um loadout de talentos e um conjunto de equipamento para cada tipo de conteúdo. O Loadout Pilot fará a troca automaticamente sempre que o WoW permitir.",
    TALENT_MAPPED = "Loadout de talentos '%s' associado a %s / %s.",
    GEAR_MAPPED = "Conjunto de equipamento '%s' associado a %s / %s.",
    TALENT_CLEARED = "Associação de talentos removida para %s / %s.",
    GEAR_CLEARED = "Associação de equipamento removida para %s / %s.",
    TALENT_SWITCHED = "Talentos alterados para '%s' em %s.",
    GEAR_SWITCHED = "Equipamento alterado para '%s' em %s.",
    WAITING_TALENTS = "O WoW não está permitindo alterar talentos agora.",
    TALENT_FAILED = "A troca de talentos não foi concluída automaticamente. Use Aplicar quando o WoW permitir.",
    GEAR_FAILED = "A troca de equipamento não foi concluída automaticamente. Use Aplicar depois do combate.",
    NO_TALENTS = "Nenhum loadout de talentos salvo foi encontrado para esta especialização.",
    NO_GEAR = "Nenhum conjunto de equipamento salvo foi encontrado.",
    UNKNOWN = "Desconhecido",
    STATUS = "Status",
    CLASS_LABEL = "Classe",
    SPEC_LABEL = "Especialização",
    CONTEXT_LABEL = "Contexto",
    VERSION = "Versão %s - Retail 12.1.0",
    LANGUAGE = "Idioma",
    ADDON_LANGUAGE = "Idioma do addon",
    LANGUAGE_DESCRIPTION = "Escolha o idioma do Loadout Pilot. Automático segue o idioma do cliente do WoW; idiomas ainda não traduzidos usam inglês.",
    LANGUAGE_AUTO = "Automático (WoW)",
    LANGUAGE_PTBR = "Português (Brasil)",
    LANGUAGE_EN = "English",
    LANGUAGE_CURRENT = "Atual: %s",
    LANGUAGE_BUTTON = "Idioma: %s",
    LANGUAGE_SAVED = "Idioma salvo como %s. Digite /reload para aplicar.",
    CANCEL = "Cancelar",
    HELP = "Comandos: /lpilot, /lpilot apply, /lpilot status, /lpilot chat on|off, /lpilot language auto|ptbr|en, /lpilot resetpos, /lpilot debug",
    RESET_POS = "Posições do HUD e do minimapa restauradas.",
    DEBUG_ON = "Log de debug ativado.",
    DEBUG_OFF = "Log de debug desativado.",
}

local clientLocale = (GetLocale and GetLocale()) or "enUS"
local localeOverride = "auto"
local locale = clientLocale

local function NormalizeLanguageOverride(value)
    value = tostring(value or "auto")
    local lower = string.lower(value)
    if lower == "ptbr" or lower == "pt" or lower == "portuguese" or lower == "portugues" then
        return "ptBR"
    end
    if lower == "enus" or lower == "engb" or lower == "en" or lower == "english" then
        return "enUS"
    end
    return "auto"
end

local function ResolveEffectiveLocale(override)
    override = NormalizeLanguageOverride(override)
    local resolved = override == "auto" and clientLocale or override
    if resolved ~= "ptBR" then resolved = "enUS" end
    return resolved, override
end

if type(_G.LoadoutPilotDB) == "table" then
    locale, localeOverride = ResolveEffectiveLocale(_G.LoadoutPilotDB.languageOverride)
else
    locale, localeOverride = ResolveEffectiveLocale("auto")
end

setmetatable(L, {
    __index = function(_, key)
        local active = locale == "ptBR" and ptBR or enUS
        return active[key] or enUS[key] or key
    end,
})

function LP:T(key, ...)
    local text = L[key] or key
    if select("#", ...) > 0 then
        local ok, formatted = pcall(string.format, text, ...)
        if ok then return formatted end
    end
    return text
end

function LP.SetLocaleOverride(value)
    locale, localeOverride = ResolveEffectiveLocale(value)
    LP.locale = locale
    LP.rawLocale = clientLocale
    LP.languageOverride = localeOverride
    return locale
end

function LP.GetLocaleOverride()
    return localeOverride
end

function LP.GetClientLocale()
    return clientLocale
end

LP.SetLocaleOverride(localeOverride)
