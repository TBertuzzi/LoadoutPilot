local ADDON_NAME, LP = ...
LP.Data = LP.Data or {}
local Data = LP.Data

Data.version = "1.1.2"
Data.interface = 120100
Data.schema = 4

Data.contextOrder = {
    "world",
    "delve",
    "dungeon",
    "mythicplus",
    "raid",
    "pvp",
}

Data.contextLabelKeys = {
    world = "CONTEXT_WORLD",
    delve = "CONTEXT_DELVE",
    dungeon = "CONTEXT_DUNGEON",
    mythicplus = "CONTEXT_MYTHICPLUS",
    raid = "CONTEXT_RAID",
    pvp = "CONTEXT_PVP",
}
