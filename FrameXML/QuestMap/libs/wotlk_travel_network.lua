WotLKTravelNetwork = WotLKTravelNetwork or {}
local WotLKTravelNetwork = WotLKTravelNetwork

--[[
WotLK / 3.3.5a continent-switch travel data.

Design notes:
- This is intended for route planning, not exact movement/pathing.
- Several "old world expansion" zones share map 530 in WotLK data but are NOT walk-connected
  to Outland. Because of that, this file uses logical travel regions in addition to raw map IDs.
- Only in-game interactable travel methods are listed here: boats, zeppelins, world portals,
  city portals, and translocation orbs. No mage portals, summons, hearthstones, or class spells.
- Some routes are optional / server-phase dependent. Those are marked in `restrictions` / `notes`.

Suggested usage:
1. Determine the player's current logical region.
2. Determine the target's logical region.
3. If equal, do normal on-continent navigation.
4. If different, choose the best outgoing route from the current node/region for that faction.
5. Route the player to the route's `from` node first, then recompute after transfer.

Coordinate notes:
- Route coordinates may use either `/way`-style local zone coordinates or raw world spawn coordinates.
- `system = "way"` means zone-local `%` coordinates with a `zone` label.
- `system = "world"` means raw map/X/Y/Z/O coordinates taken from your world DB gameobject spawn.
- `precision = "exact"` means a verified boarding / interaction point.
- `precision = "hub"` or `precision = "city_anchor"` means a practical routing anchor when an exact portal landing
  or exact dock coordinate was not cleanly verifiable.
- For multi-dock hubs, prefer route-specific coordinates over generic node data.
]]

WotLKTravelNetwork.regions = {
    EasternKingdoms = {
        id = "EasternKingdoms",
        mapId = 0,
        label = "Eastern Kingdoms",
    },
    Kalimdor = {
        id = "Kalimdor",
        mapId = 1,
        label = "Kalimdor",
    },
    Northrend = {
        id = "Northrend",
        mapId = 571,
        label = "Northrend",
    },
    Outland = {
        id = "Outland",
        mapId = 530,
        label = "Outland",
    },
    QuelThalas = {
        id = "QuelThalas",
        mapId = 530,
        label = "Quel'Thalas / Silvermoon region",
    },
    Azuremyst = {
        id = "Azuremyst",
        mapId = 530,
        label = "Azuremyst / Exodar region",
    },
    QuelDanas = {
        id = "QuelDanas",
        mapId = 530,
        label = "Isle of Quel'Danas",
    },
}

WotLKTravelNetwork.nodes = {
    -- Northrend
    Dalaran = {
        id = "Dalaran",
        label = "Dalaran",
        region = "Northrend",
        faction = "Neutral",
        type = "portal_hub",
    },
    ValianceKeep = {
        id = "ValianceKeep",
        label = "Valiance Keep",
        region = "Northrend",
        faction = "Alliance",
        type = "boat_dock",
    },
    Valgarde = {
        id = "Valgarde",
        label = "Valgarde",
        region = "Northrend",
        faction = "Alliance",
        type = "boat_dock",
    },
    WarsongHold = {
        id = "WarsongHold",
        label = "Warsong Hold",
        region = "Northrend",
        faction = "Horde",
        type = "zeppelin_tower",
    },
    VengeanceLanding = {
        id = "VengeanceLanding",
        label = "Vengeance Landing",
        region = "Northrend",
        faction = "Horde",
        type = "zeppelin_tower",
    },

    -- Eastern Kingdoms
    Stormwind = {
        id = "Stormwind",
        label = "Stormwind City",
        region = "EasternKingdoms",
        faction = "Alliance",
        type = "capital",
    },
    Ironforge = {
        id = "Ironforge",
        label = "Ironforge",
        region = "EasternKingdoms",
        faction = "Alliance",
        type = "capital",
    },
    MenethilHarbor = {
        id = "MenethilHarbor",
        label = "Menethil Harbor",
        region = "EasternKingdoms",
        faction = "Alliance",
        type = "boat_dock",
    },
    StormwindHarbor = {
        id = "StormwindHarbor",
        label = "Stormwind Harbor",
        region = "EasternKingdoms",
        faction = "Alliance",
        type = "boat_dock",
    },
    Undercity = {
        id = "Undercity",
        label = "Undercity / Ruins of Lordaeron",
        region = "EasternKingdoms",
        faction = "Horde",
        type = "capital",
    },
    TirisfalZeppelin = {
        id = "TirisfalZeppelin",
        label = "Tirisfal Zeppelin Tower",
        region = "EasternKingdoms",
        faction = "Horde",
        type = "zeppelin_tower",
    },
    BootyBay = {
        id = "BootyBay",
        label = "Booty Bay",
        region = "EasternKingdoms",
        faction = "Neutral",
        type = "boat_dock",
    },
    BlastedLandsPortal = {
        id = "BlastedLandsPortal",
        label = "Blasted Lands (in front of the Dark Portal)",
        region = "EasternKingdoms",
        faction = "Neutral",
        type = "portal_arrival",
    },
    DarkPortalAzeroth = {
        id = "DarkPortalAzeroth",
        label = "Dark Portal (Azeroth side)",
        region = "EasternKingdoms",
        faction = "Neutral",
        type = "world_portal",
    },

    -- Kalimdor
    Darnassus = {
        id = "Darnassus",
        label = "Darnassus",
        region = "Kalimdor",
        faction = "Alliance",
        type = "capital",
    },
    RuttheranVillage = {
        id = "RuttheranVillage",
        label = "Rut'theran Village",
        region = "Kalimdor",
        faction = "Alliance",
        type = "portal_and_boat_hub",
    },
    Auberdine = {
        id = "Auberdine",
        label = "Auberdine",
        region = "Kalimdor",
        faction = "Alliance",
        type = "boat_dock",
    },
    Theramore = {
        id = "Theramore",
        label = "Theramore Isle",
        region = "Kalimdor",
        faction = "Alliance",
        type = "boat_dock",
    },
    Orgrimmar = {
        id = "Orgrimmar",
        label = "Orgrimmar",
        region = "Kalimdor",
        faction = "Horde",
        type = "capital",
    },
    OrgrimmarZeppelin = {
        id = "OrgrimmarZeppelin",
        label = "Orgrimmar Zeppelin Tower",
        region = "Kalimdor",
        faction = "Horde",
        type = "zeppelin_tower",
    },
    ThunderBluff = {
        id = "ThunderBluff",
        label = "Thunder Bluff",
        region = "Kalimdor",
        faction = "Horde",
        type = "capital",
    },
    Ratchet = {
        id = "Ratchet",
        label = "Ratchet",
        region = "Kalimdor",
        faction = "Neutral",
        type = "boat_dock",
    },

    -- Outland
    HellfireStair = {
        id = "HellfireStair",
        label = "Stair of Destiny / Hellfire Peninsula",
        region = "Outland",
        faction = "Neutral",
        type = "world_portal_arrival",
    },
    DarkPortalOutland = {
        id = "DarkPortalOutland",
        label = "Dark Portal (Outland side)",
        region = "Outland",
        faction = "Neutral",
        type = "world_portal",
    },
    Shattrath = {
        id = "Shattrath",
        label = "Shattrath City",
        region = "Outland",
        faction = "Neutral",
        type = "portal_hub",
    },

    -- Quel'Thalas / Silvermoon region (map 530, not walk-connected to Outland)
    Silvermoon = {
        id = "Silvermoon",
        label = "Silvermoon City",
        region = "QuelThalas",
        faction = "Horde",
        type = "capital",
    },

    -- Azuremyst / Exodar region (map 530, not walk-connected to Outland)
    Exodar = {
        id = "Exodar",
        label = "The Exodar",
        region = "Azuremyst",
        faction = "Alliance",
        type = "capital",
    },
    AzuremystDock = {
        id = "AzuremystDock",
        label = "Azuremyst Isle dock (outside Exodar)",
        region = "Azuremyst",
        faction = "Alliance",
        type = "boat_dock",
    },

    -- Isle of Quel'Danas (map 530, not walk-connected to Outland / Quel'Thalas)
    SunsReach = {
        id = "SunsReach",
        label = "Sun's Reach",
        region = "QuelDanas",
        faction = "Neutral",
        type = "portal_arrival",
    },
}

WotLKTravelNetwork.routes = {
    ------------------------------------------------------------------------
    -- Dalaran -> Alliance capitals
    ------------------------------------------------------------------------
    {
        id = "DALARAN_TO_STORMWIND",
        from = "Dalaran",
        to = "Stormwind",
        type = "portal",
        faction = "Alliance",
        oneWay = true,
        cost = 1,
        note = "Fastest Alliance exit from Dalaran to Eastern Kingdoms.",
    },
    {
        id = "DALARAN_TO_IRONFORGE",
        from = "Dalaran",
        to = "Ironforge",
        type = "portal",
        faction = "Alliance",
        oneWay = true,
        cost = 1,
        note = "Use this for Dalaran -> Ironforge instead of trying to route across continents.",
    },
    {
        id = "DALARAN_TO_DARNASSUS",
        from = "Dalaran",
        to = "Darnassus",
        type = "portal",
        faction = "Alliance",
        oneWay = true,
        cost = 1,
    },
    {
        id = "DALARAN_TO_EXODAR",
        from = "Dalaran",
        to = "Exodar",
        type = "portal",
        faction = "Alliance",
        oneWay = true,
        cost = 1,
    },

    ------------------------------------------------------------------------
    -- Dalaran -> Horde capitals
    ------------------------------------------------------------------------
    {
        id = "DALARAN_TO_ORGRIMMAR",
        from = "Dalaran",
        to = "Orgrimmar",
        type = "portal",
        faction = "Horde",
        oneWay = true,
        cost = 1,
    },
    {
        id = "DALARAN_TO_THUNDERBLUFF",
        from = "Dalaran",
        to = "ThunderBluff",
        type = "portal",
        faction = "Horde",
        oneWay = true,
        cost = 1,
    },
    {
        id = "DALARAN_TO_UNDERCITY",
        from = "Dalaran",
        to = "Undercity",
        type = "portal",
        faction = "Horde",
        oneWay = true,
        cost = 1,
    },
    {
        id = "DALARAN_TO_SILVERMOON",
        from = "Dalaran",
        to = "Silvermoon",
        type = "portal",
        faction = "Horde",
        oneWay = true,
        cost = 1,
    },

    ------------------------------------------------------------------------
    -- Alliance intercontinental boats
    ------------------------------------------------------------------------
    {
        id = "STORMWIND_TO_VALIANCE",
        from = "StormwindHarbor",
        to = "ValianceKeep",
        type = "boat",
        faction = "Alliance",
        oneWay = false,
        cost = 2,
    },
    {
        id = "MENETHIL_TO_VALGARDE",
        from = "MenethilHarbor",
        to = "Valgarde",
        type = "boat",
        faction = "Alliance",
        oneWay = false,
        cost = 2,
    },
    {
        id = "STORMWIND_TO_AUBERDINE",
        from = "StormwindHarbor",
        to = "Auberdine",
        type = "boat",
        faction = "Alliance",
        oneWay = false,
        cost = 2,
    },
    {
        id = "MENETHIL_TO_THERAMORE",
        from = "MenethilHarbor",
        to = "Theramore",
        type = "boat",
        faction = "Alliance",
        oneWay = false,
        cost = 2,
    },

    ------------------------------------------------------------------------
    -- Horde intercontinental zeppelins
    ------------------------------------------------------------------------
    {
        id = "ORGRIMMAR_TO_UNDERCITY",
        from = "OrgrimmarZeppelin",
        to = "TirisfalZeppelin",
        type = "zeppelin",
        faction = "Horde",
        oneWay = false,
        cost = 2,
        note = "Major Kalimdor <-> Eastern Kingdoms Horde connection.",
    },
    {
        id = "ORGRIMMAR_TO_WARSONG",
        from = "OrgrimmarZeppelin",
        to = "WarsongHold",
        type = "zeppelin",
        faction = "Horde",
        oneWay = false,
        cost = 2,
    },
    {
        id = "TIRISFAL_TO_VENGEANCE",
        from = "TirisfalZeppelin",
        to = "VengeanceLanding",
        type = "zeppelin",
        faction = "Horde",
        oneWay = false,
        cost = 2,
    },

    ------------------------------------------------------------------------
    -- Neutral intercontinental ship
    ------------------------------------------------------------------------
    {
        id = "RATCHET_TO_BOOTYBAY",
        from = "Ratchet",
        to = "BootyBay",
        type = "boat",
        faction = "Neutral",
        oneWay = false,
        cost = 3,
    },

    ------------------------------------------------------------------------
    -- Quel'Thalas <-> Eastern Kingdoms (Horde only)
    ------------------------------------------------------------------------
    {
        id = "SILVERMOON_TO_UNDERCITY",
        from = "Silvermoon",
        to = "Undercity",
        type = "orb",
        faction = "Horde",
        oneWay = false,
        cost = 1,
        note = "Orb of Translocation between Silvermoon and the Ruins of Lordaeron.",
    },

    ------------------------------------------------------------------------
    -- Azuremyst / Exodar region <-> Kalimdor (Alliance primary)
    ------------------------------------------------------------------------
    {
        id = "RUTTHERAN_TO_AZUREMYST",
        from = "RuttheranVillage",
        to = "AzuremystDock",
        type = "boat",
        faction = "Alliance",
        oneWay = false,
        cost = 2,
        note = "Primary route between Kalimdor and the Exodar/Azuremyst region.",
    },
    {
        id = "DARNASSUS_TO_RUTTHERAN",
        from = "Darnassus",
        to = "RuttheranVillage",
        type = "portal",
        faction = "Alliance",
        oneWay = false,
        cost = 1,
        note = "Not an intercontinental edge by itself, but necessary to reach Azuremyst boats.",
    },

    ------------------------------------------------------------------------
    -- Major city -> Blasted Lands portals (patch 3.2+)
    ------------------------------------------------------------------------
    {
        id = "SW_TO_BLASTED",
        from = "Stormwind",
        to = "BlastedLandsPortal",
        type = "portal",
        faction = "Alliance",
        oneWay = true,
        cost = 1,
        restrictions = { minLevel = 58 },
    },
    {
        id = "IF_TO_BLASTED",
        from = "Ironforge",
        to = "BlastedLandsPortal",
        type = "portal",
        faction = "Alliance",
        oneWay = true,
        cost = 1,
        restrictions = { minLevel = 58 },
    },
    {
        id = "DARN_TO_BLASTED",
        from = "Darnassus",
        to = "BlastedLandsPortal",
        type = "portal",
        faction = "Alliance",
        oneWay = true,
        cost = 1,
        restrictions = { minLevel = 58 },
    },
    {
        id = "EXO_TO_BLASTED",
        from = "Exodar",
        to = "BlastedLandsPortal",
        type = "portal",
        faction = "Alliance",
        oneWay = true,
        cost = 1,
        restrictions = { minLevel = 58 },
    },
    {
        id = "ORG_TO_BLASTED",
        from = "Orgrimmar",
        to = "BlastedLandsPortal",
        type = "portal",
        faction = "Horde",
        oneWay = true,
        cost = 1,
        restrictions = { minLevel = 58 },
    },
    {
        id = "TB_TO_BLASTED",
        from = "ThunderBluff",
        to = "BlastedLandsPortal",
        type = "portal",
        faction = "Horde",
        oneWay = true,
        cost = 1,
        restrictions = { minLevel = 58 },
    },
    {
        id = "UC_TO_BLASTED",
        from = "Undercity",
        to = "BlastedLandsPortal",
        type = "portal",
        faction = "Horde",
        oneWay = true,
        cost = 1,
        restrictions = { minLevel = 58 },
    },
    {
        id = "SM_TO_BLASTED",
        from = "Silvermoon",
        to = "BlastedLandsPortal",
        type = "portal",
        faction = "Horde",
        oneWay = true,
        cost = 1,
        restrictions = { minLevel = 58 },
    },

    ------------------------------------------------------------------------
    -- Dark Portal: Eastern Kingdoms <-> Outland
    ------------------------------------------------------------------------
    {
        id = "AZEROTH_TO_OUTLAND_DARK_PORTAL",
        from = "DarkPortalAzeroth",
        to = "DarkPortalOutland",
        type = "world_portal",
        faction = "Neutral",
        oneWay = false,
        cost = 1,
    },
    {
        id = "BLASTED_TO_AZEROTH_PORTAL_FACE",
        from = "BlastedLandsPortal",
        to = "DarkPortalAzeroth",
        type = "walk",
        faction = "Neutral",
        oneWay = false,
        cost = 0,
        note = "Small local connector to let routing flow through the portal crater arrival point.",
    },
    {
        id = "OUTLAND_PORTAL_TO_STAIR",
        from = "DarkPortalOutland",
        to = "HellfireStair",
        type = "walk",
        faction = "Neutral",
        oneWay = false,
        cost = 0,
        note = "Small local connector on the Outland side.",
    },

    ------------------------------------------------------------------------
    -- Shattrath -> capitals (one-way city portals)
    ------------------------------------------------------------------------
    {
        id = "SHATTRATH_TO_STORMWIND",
        from = "Shattrath",
        to = "Stormwind",
        type = "portal",
        faction = "Alliance",
        oneWay = true,
        cost = 1,
    },
    {
        id = "SHATTRATH_TO_IRONFORGE",
        from = "Shattrath",
        to = "Ironforge",
        type = "portal",
        faction = "Alliance",
        oneWay = true,
        cost = 1,
    },
    {
        id = "SHATTRATH_TO_DARNASSUS",
        from = "Shattrath",
        to = "Darnassus",
        type = "portal",
        faction = "Alliance",
        oneWay = true,
        cost = 1,
    },
    {
        id = "SHATTRATH_TO_EXODAR",
        from = "Shattrath",
        to = "Exodar",
        type = "portal",
        faction = "Alliance",
        oneWay = true,
        cost = 1,
    },
    {
        id = "SHATTRATH_TO_ORGRIMMAR",
        from = "Shattrath",
        to = "Orgrimmar",
        type = "portal",
        faction = "Horde",
        oneWay = true,
        cost = 1,
    },
    {
        id = "SHATTRATH_TO_THUNDERBLUFF",
        from = "Shattrath",
        to = "ThunderBluff",
        type = "portal",
        faction = "Horde",
        oneWay = true,
        cost = 1,
    },
    {
        id = "SHATTRATH_TO_UNDERCITY",
        from = "Shattrath",
        to = "Undercity",
        type = "portal",
        faction = "Horde",
        oneWay = true,
        cost = 1,
    },
    {
        id = "SHATTRATH_TO_SILVERMOON",
        from = "Shattrath",
        to = "Silvermoon",
        type = "portal",
        faction = "Horde",
        oneWay = true,
        cost = 1,
    },

    ------------------------------------------------------------------------
    -- Shattrath <-> Isle of Quel'Danas (special case)
    ------------------------------------------------------------------------
    {
        id = "SHATTRATH_TO_QUELDANAS",
        from = "Shattrath",
        to = "SunsReach",
        type = "portal",
        faction = "Neutral",
        oneWay = true,
        cost = 1,
        restrictions = {
            shatteredSunPhaseRequired = true,
        },
        note = "Many cores treat the return trip differently; keep this one-way unless you verify otherwise on your server.",
    },
}

WotLKTravelNetwork.routeCoords = {
    -- For portal/orb routes, prefer `system = "world"` source coordinates when available.
    -- Dalaran portals use practical faction-hub anchors inside the correct quarter.
    DALARAN_TO_STORMWIND = {
        from = {
            map = 571,
            x = 5719.19, y = 719.681, z = 641.728, o = 0.837757,
            system = "world", precision = "exact",
            guid = 61217, objectEntry = 190960, objectName = "Dalaran Portal to Stormwind",
            phaseMask = 1, zoneId = 0, areaId = 0, interactRadius = 3.0,
            note = "Exact clickable portal spawn from world DB.",
        },
        to = { zone = "Stormwind City", x = 38.0, y = 62.0, system = "way", precision = "city_anchor", note = "City anchor near central services; exact portal landing not yet extracted." },
    },
    DALARAN_TO_IRONFORGE = {
        from = {
            map = 571,
            x = 5712.68, y = 724.845, z = 641.736, o = 0.890117,
            system = "world", precision = "exact",
            guid = 56552, objectEntry = 191008, objectName = "Dalaran Portal to Ironforge",
            phaseMask = 1, zoneId = 0, areaId = 0, interactRadius = 3.0,
            note = "Exact clickable portal spawn from world DB.",
        },
        to = { zone = "Ironforge", x = 65.0, y = 26.0, system = "way", precision = "city_anchor", note = "City anchor near central services; exact portal landing not yet extracted." },
    },
    DALARAN_TO_DARNASSUS = {
        from = {
            map = 571,
            x = 5706.16, y = 730.102, z = 641.745, o = -0.820303,
            system = "world", precision = "exact",
            guid = 56465, objectEntry = 191006, objectName = "Dalaran Portal to Darnassus",
            phaseMask = 1, zoneId = 0, areaId = 0, interactRadius = 3.0,
            note = "Exact clickable portal spawn from world DB.",
        },
        to = { zone = "Darnassus", x = 56.0, y = 91.0, system = "way", precision = "city_anchor", note = "City anchor; exact portal landing not yet extracted." },
    },
    DALARAN_TO_EXODAR = {
        from = {
            map = 571,
            x = 5699.58, y = 735.469, z = 641.769, o = 2.02458,
            system = "world", precision = "exact",
            guid = 56485, objectEntry = 191007, objectName = "Dalaran Portal to Exodar",
            phaseMask = 1, zoneId = 0, areaId = 0, interactRadius = 3.0,
            note = "Exact clickable portal spawn from world DB.",
        },
        to = { zone = "The Exodar", x = 41.0, y = 24.0, system = "way", precision = "city_anchor", note = "City anchor near central services; exact portal landing not yet extracted." },
    },
    DALARAN_TO_ORGRIMMAR = {
        from = { zone = "Dalaran", x = 66.0, y = 32.2, system = "way", precision = "hub", note = "Sunreaver's Sanctuary portal hub / The Filthy Animal area." },
        to = { zone = "Orgrimmar", x = 48.0, y = 37.0, system = "way", precision = "city_anchor", note = "City anchor near central services; exact portal landing not separately verified." },
    },
    DALARAN_TO_THUNDERBLUFF = {
        from = { zone = "Dalaran", x = 66.0, y = 32.2, system = "way", precision = "hub", note = "Sunreaver's Sanctuary portal hub / The Filthy Animal area." },
        to = { zone = "Thunder Bluff", x = 20.0, y = 25.0, system = "way", precision = "city_anchor", note = "City anchor near central services; exact portal landing not separately verified." },
    },
    DALARAN_TO_UNDERCITY = {
        from = { zone = "Dalaran", x = 66.0, y = 32.2, system = "way", precision = "hub", note = "Sunreaver's Sanctuary portal hub / The Filthy Animal area." },
        to = { zone = "Undercity", x = 68.0, y = 11.0, system = "way", precision = "city_anchor", note = "City anchor near central services; exact portal landing not separately verified." },
    },
    DALARAN_TO_SILVERMOON = {
        from = { zone = "Dalaran", x = 66.0, y = 32.2, system = "way", precision = "hub", note = "Sunreaver's Sanctuary portal hub / The Filthy Animal area." },
        to = { zone = "Silvermoon City", x = 68.0, y = 41.0, system = "way", precision = "city_anchor", note = "City anchor near central services; exact portal landing not separately verified." },
    },

    STORMWIND_TO_VALIANCE = {
        from = { zone = "Stormwind City", x = 18.6, y = 26.2, system = "way", precision = "exact", note = "Kraken dock, northernmost Stormwind Harbor dock." },
        to = { zone = "Borean Tundra", x = 59.0, y = 65.0, system = "way", precision = "hub", note = "Valiance Keep settlement anchor." },
    },
    MENETHIL_TO_VALGARDE = {
        from = { zone = "Wetlands", x = 4.6, y = 57.2, system = "way", precision = "exact", note = "Northspear dock, northernmost Menethil Harbor dock." },
        to = { zone = "Howling Fjord", system = "way", precision = "hub", note = "Valgarde harbor / settlement anchor still needs an exact numeric arrival coordinate." },
    },
    STORMWIND_TO_AUBERDINE = {
        from = { zone = "Stormwind City", system = "way", precision = "hub", note = "Stormwind Harbor southern / night elf dock; exact numeric dock coordinate still needs verification." },
        to = { zone = "Darkshore", x = 32.7, y = 43.7, system = "way", precision = "hub", note = "Auberdine south dock anchor." },
    },
    MENETHIL_TO_THERAMORE = {
        from = { zone = "Wetlands", x = 5.0, y = 63.0, system = "way", precision = "exact", note = "Menethil southern dock to Theramore." },
        to = { zone = "Dustwallow Marsh", x = 71.0, y = 56.0, system = "way", precision = "exact", note = "Theramore central dock." },
    },

    ORGRIMMAR_TO_UNDERCITY = {
        from = { zone = "Durotar", x = 50.8, y = 13.6, system = "way", precision = "exact", note = "Orgrimmar zeppelin tower south platform to Undercity." },
        to = { zone = "Tirisfal Glades", x = 61.0, y = 59.0, system = "way", precision = "exact", note = "Tirisfal zeppelin tower west platform to Orgrimmar." },
    },
    ORGRIMMAR_TO_WARSONG = {
        from = { zone = "Durotar", x = 41.4, y = 18.7, system = "way", precision = "exact", note = "Warsong tower entrance / practical boarding anchor." },
        to = { zone = "Borean Tundra", x = 41.4, y = 53.6, system = "way", precision = "hub", note = "Warsong Hold settlement anchor." },
    },
    TIRISFAL_TO_VENGEANCE = {
        from = { zone = "Tirisfal Glades", x = 59.2, y = 59.0, system = "way", precision = "exact", note = "Cloudkisser tower dockmaster / boarding anchor." },
        to = { zone = "Howling Fjord", x = 79.6, y = 30.6, system = "way", precision = "hub", note = "Vengeance Landing settlement anchor." },
    },

    RATCHET_TO_BOOTYBAY = {
        from = { zone = "The Barrens", x = 63.6, y = 38.7, system = "way", precision = "exact", note = "Ratchet dock." },
        to = { zone = "Stranglethorn Vale", x = 26.0, y = 73.2, system = "way", precision = "exact", note = "Booty Bay dock." },
    },

    SILVERMOON_TO_UNDERCITY = {
        from = {
            map = 530,
            x = 10032.4, y = -7000.29, z = 61.3098, o = -1.57654,
            system = "world", precision = "exact",
            guid = 12608, objectEntry = 184502, objectName = "Orb of Translocation",
            phaseMask = 1, zoneId = 3487, areaId = 3487, interactRadius = 3.0,
            note = "Exact Silvermoon-side orb spawn from world DB.",
        },
        to = {
            map = 0,
            x = 1805.85, y = 348.865, z = 70.8727, o = -0.008727,
            system = "world", precision = "exact",
            guid = 44984, objectEntry = 184503, objectName = "Orb of Translocation",
            phaseMask = 1, zoneId = 0, areaId = 0, interactRadius = 3.0,
            note = "Exact Undercity/Ruins of Lordaeron-side orb spawn from world DB.",
        },
    },

    RUTTHERAN_TO_AZUREMYST = {
        from = { zone = "Teldrassil", x = 55.5, y = 93.0, system = "way", precision = "exact", note = "Rut'theran Village dock to Azuremyst." },
        to = { zone = "Azuremyst Isle", x = 20.4, y = 54.2, system = "way", precision = "exact", note = "Valaar's Berth / Azuremyst dock." },
    },
    DARNASSUS_TO_RUTTHERAN = {
        from = { zone = "Teldrassil", x = 56.0, y = 91.0, system = "way", precision = "hub", note = "Practical Darnassus <-> Rut'theran portal anchor." },
        to = { zone = "Teldrassil", x = 55.5, y = 93.0, system = "way", precision = "exact", note = "Rut'theran Village dock / portal-side anchor." },
    },

    SW_TO_BLASTED = {
        from = { zone = "Stormwind City", x = 38.0, y = 62.0, system = "way", precision = "city_anchor", note = "Stormwind city-side portal-room anchor." },
        to = { zone = "Blasted Lands", x = 58.4, y = 55.8, system = "way", precision = "exact", note = "Dark Portal approach in Blasted Lands." },
    },
    IF_TO_BLASTED = {
        from = { zone = "Ironforge", x = 65.0, y = 26.0, system = "way", precision = "city_anchor", note = "Ironforge city-side portal anchor." },
        to = { zone = "Blasted Lands", x = 58.4, y = 55.8, system = "way", precision = "exact", note = "Dark Portal approach in Blasted Lands." },
    },
    DARN_TO_BLASTED = {
        from = { zone = "Darnassus", x = 56.0, y = 91.0, system = "way", precision = "city_anchor", note = "Darnassus city-side portal anchor." },
        to = { zone = "Blasted Lands", x = 58.4, y = 55.8, system = "way", precision = "exact", note = "Dark Portal approach in Blasted Lands." },
    },
    EXO_TO_BLASTED = {
        from = { zone = "The Exodar", x = 41.0, y = 24.0, system = "way", precision = "city_anchor", note = "Exodar city-side portal anchor." },
        to = { zone = "Blasted Lands", x = 58.4, y = 55.8, system = "way", precision = "exact", note = "Dark Portal approach in Blasted Lands." },
    },
    ORG_TO_BLASTED = {
        from = { zone = "Orgrimmar", x = 48.0, y = 37.0, system = "way", precision = "city_anchor", note = "Orgrimmar city-side portal anchor." },
        to = { zone = "Blasted Lands", x = 58.0, y = 55.8, system = "way", precision = "exact", note = "Dark Portal approach in Blasted Lands." },
    },
    TB_TO_BLASTED = {
        from = { zone = "Thunder Bluff", x = 20.0, y = 25.0, system = "way", precision = "city_anchor", note = "Thunder Bluff city-side portal anchor." },
        to = { zone = "Blasted Lands", x = 58.0, y = 55.8, system = "way", precision = "exact", note = "Dark Portal approach in Blasted Lands." },
    },
    UC_TO_BLASTED = {
        from = { zone = "Undercity", x = 68.0, y = 11.0, system = "way", precision = "city_anchor", note = "Undercity city-side portal anchor." },
        to = { zone = "Blasted Lands", x = 58.0, y = 55.8, system = "way", precision = "exact", note = "Dark Portal approach in Blasted Lands." },
    },
    SM_TO_BLASTED = {
        from = { zone = "Silvermoon City", x = 68.0, y = 41.0, system = "way", precision = "city_anchor", note = "Silvermoon city-side portal anchor." },
        to = { zone = "Blasted Lands", x = 58.0, y = 55.8, system = "way", precision = "exact", note = "Dark Portal approach in Blasted Lands." },
    },

    AZEROTH_TO_OUTLAND_DARK_PORTAL = {
        from = { zone = "Blasted Lands", x = 58.2, y = 55.8, system = "way", precision = "exact", note = "Azeroth-side Dark Portal approach." },
        to = { zone = "Hellfire Peninsula", system = "way", precision = "hub", note = "Stair of Destiny / Dark Portal arrival anchor still needs an exact numeric coordinate." },
    },
    BLASTED_TO_AZEROTH_PORTAL_FACE = {
        from = { zone = "Blasted Lands", x = 58.4, y = 55.8, system = "way", precision = "exact", note = "Blasted Lands arrival point in front of the portal." },
        to = { zone = "Blasted Lands", x = 58.2, y = 55.8, system = "way", precision = "exact", note = "Portal face." },
    },
    OUTLAND_PORTAL_TO_STAIR = {
        from = { zone = "Hellfire Peninsula", system = "way", precision = "hub", note = "Portal face / Stair of Destiny anchor still needs an exact numeric coordinate." },
        to = { zone = "Hellfire Peninsula", system = "way", precision = "hub", note = "Short local connector on the Outland side; exact numeric coordinate still needs verification." },
    },

    SHATTRATH_TO_STORMWIND = {
        from = { zone = "Shattrath City", x = 59.0, y = 47.24, system = "way", precision = "exact", note = "Shattrath capital portal hub." },
        to = { zone = "Stormwind City", x = 38.0, y = 62.0, system = "way", precision = "city_anchor", note = "City anchor near central services; exact portal landing not separately verified." },
    },
    SHATTRATH_TO_IRONFORGE = {
        from = { zone = "Shattrath City", x = 59.0, y = 47.24, system = "way", precision = "exact", note = "Shattrath capital portal hub." },
        to = { zone = "Ironforge", x = 65.0, y = 26.0, system = "way", precision = "city_anchor", note = "City anchor near central services; exact portal landing not separately verified." },
    },
    SHATTRATH_TO_DARNASSUS = {
        from = { zone = "Shattrath City", x = 59.0, y = 47.24, system = "way", precision = "exact", note = "Shattrath capital portal hub." },
        to = { zone = "Darnassus", x = 56.0, y = 91.0, system = "way", precision = "city_anchor", note = "Practical Teldrassil-side arrival anchor." },
    },
    SHATTRATH_TO_EXODAR = {
        from = { zone = "Shattrath City", x = 59.0, y = 47.24, system = "way", precision = "exact", note = "Shattrath capital portal hub." },
        to = { zone = "The Exodar", x = 41.0, y = 24.0, system = "way", precision = "city_anchor", note = "City anchor near central services; exact portal landing not separately verified." },
    },
    SHATTRATH_TO_ORGRIMMAR = {
        from = { zone = "Shattrath City", x = 59.0, y = 47.24, system = "way", precision = "exact", note = "Shattrath capital portal hub." },
        to = { zone = "Orgrimmar", x = 48.0, y = 37.0, system = "way", precision = "city_anchor", note = "City anchor near central services; exact portal landing not separately verified." },
    },
    SHATTRATH_TO_THUNDERBLUFF = {
        from = { zone = "Shattrath City", x = 59.0, y = 47.24, system = "way", precision = "exact", note = "Shattrath capital portal hub." },
        to = { zone = "Thunder Bluff", x = 20.0, y = 25.0, system = "way", precision = "city_anchor", note = "City anchor near central services; exact portal landing not separately verified." },
    },
    SHATTRATH_TO_UNDERCITY = {
        from = { zone = "Shattrath City", x = 59.0, y = 47.24, system = "way", precision = "exact", note = "Shattrath capital portal hub." },
        to = { zone = "Undercity", x = 68.0, y = 11.0, system = "way", precision = "city_anchor", note = "City anchor near central services; exact portal landing not separately verified." },
    },
    SHATTRATH_TO_SILVERMOON = {
        from = { zone = "Shattrath City", x = 59.0, y = 47.24, system = "way", precision = "exact", note = "Shattrath capital portal hub." },
        to = { zone = "Silvermoon City", x = 68.0, y = 41.0, system = "way", precision = "city_anchor", note = "City anchor near central services; exact portal landing not separately verified." },
    },

    SHATTRATH_TO_QUELDANAS = {
        from = { zone = "Shattrath City", x = 59.0, y = 47.24, system = "way", precision = "hub", note = "Capital portal hub area; Isle portal sits nearby in the same terrace zone." },
        to = { zone = "Isle of Quel'Danas", system = "way", precision = "hub", note = "Sun's Reach arrival anchor still needs an exact numeric coordinate." },
    },
}

function WotLKTravelNetwork.IsFactionAllowed(routeFaction, playerFaction)
    return routeFaction == "Neutral" or routeFaction == playerFaction
end

function WotLKTravelNetwork.GetNode(nodeId)
    return WotLKTravelNetwork.nodes[nodeId]
end

function WotLKTravelNetwork.GetRegion(regionId)
    return WotLKTravelNetwork.regions[regionId]
end

local function CloneCoord(coord)
    if not coord then
        return nil
    end

    return {
        zone = coord.zone,
        map = coord.map,
        x = coord.x,
        y = coord.y,
        z = coord.z,
        o = coord.o,
        system = coord.system,
        precision = coord.precision,
        note = coord.note,
        guid = coord.guid,
        objectEntry = coord.objectEntry,
        objectName = coord.objectName,
        phaseMask = coord.phaseMask,
        areaId = coord.areaId,
        zoneId = coord.zoneId,
        interactRadius = coord.interactRadius,
    }
end

function WotLKTravelNetwork.GetRouteCoords(routeId)
    local isReverse = routeId:sub(-8) == "_REVERSE"
    local baseId = isReverse and routeId:sub(1, -9) or routeId
    local data = WotLKTravelNetwork.routeCoords and WotLKTravelNetwork.routeCoords[baseId]

    if not data then
        return nil
    end

    if isReverse then
        return {
            from = CloneCoord(data.to),
            to = CloneCoord(data.from),
        }
    end

    return {
        from = CloneCoord(data.from),
        to = CloneCoord(data.to),
    }
end

function WotLKTravelNetwork.GetRoutesFrom(nodeId, playerFaction)
    local out = {}
    for _, route in ipairs(WotLKTravelNetwork.routes) do
        if route.from == nodeId and WotLKTravelNetwork.IsFactionAllowed(route.faction, playerFaction) then
            local coords = WotLKTravelNetwork.GetRouteCoords(route.id)
            local enriched = {
                id = route.id,
                from = route.from,
                to = route.to,
                type = route.type,
                faction = route.faction,
                oneWay = route.oneWay,
                cost = route.cost,
                restrictions = route.restrictions,
                note = route.note,
                fromCoords = coords and coords.from or nil,
                toCoords = coords and coords.to or nil,
            }
            out[#out + 1] = enriched
        elseif route.to == nodeId and route.oneWay == false and WotLKTravelNetwork.IsFactionAllowed(route.faction, playerFaction) then
            -- expose reverse edge dynamically for bidirectional routes
            local coords = WotLKTravelNetwork.GetRouteCoords(route.id .. "_REVERSE")
            out[#out + 1] = {
                id = route.id .. "_REVERSE",
                from = route.to,
                to = route.from,
                type = route.type,
                faction = route.faction,
                oneWay = false,
                cost = route.cost,
                restrictions = route.restrictions,
                note = route.note,
                fromCoords = coords and coords.from or nil,
                toCoords = coords and coords.to or nil,
            }
        end
    end
    return out
end

-- Optional helper if you want to normalize special map 530 areas into logical regions.
-- Extend this with your own zone / area / map mapping as needed.
WotLKTravelNetwork.ZoneToRegion = {
    -- Northrend
    ["Dalaran"] = "Northrend",
    ["Borean Tundra"] = "Northrend",
    ["Howling Fjord"] = "Northrend",
    ["Dragonblight"] = "Northrend",
    ["Grizzly Hills"] = "Northrend",
    ["Sholazar Basin"] = "Northrend",
    ["Icecrown"] = "Northrend",
    ["The Storm Peaks"] = "Northrend",
    ["Crystalsong Forest"] = "Northrend",
    ["Zul'Drak"] = "Northrend",

    -- Eastern Kingdoms
    ["Stormwind City"] = "EasternKingdoms",
    ["Ironforge"] = "EasternKingdoms",
    ["Undercity"] = "EasternKingdoms",
    ["Tirisfal Glades"] = "EasternKingdoms",
    ["Wetlands"] = "EasternKingdoms",
    ["Blasted Lands"] = "EasternKingdoms",
    ["Booty Bay"] = "EasternKingdoms",

    -- Kalimdor
    ["Orgrimmar"] = "Kalimdor",
    ["Thunder Bluff"] = "Kalimdor",
    ["Darnassus"] = "Kalimdor",
    ["Darkshore"] = "Kalimdor",
    ["Ratchet"] = "Kalimdor",
    ["Theramore Isle"] = "Kalimdor",
    ["Rut'theran Village"] = "Kalimdor",

    -- Outland proper
    ["Hellfire Peninsula"] = "Outland",
    ["Shattrath City"] = "Outland",
    ["Nagrand"] = "Outland",
    ["Terokkar Forest"] = "Outland",
    ["Zangarmarsh"] = "Outland",
    ["Blade's Edge Mountains"] = "Outland",
    ["Netherstorm"] = "Outland",
    ["Shadowmoon Valley"] = "Outland",

    -- Special map 530 regions
    ["Silvermoon City"] = "QuelThalas",
    ["Eversong Woods"] = "QuelThalas",
    ["Ghostlands"] = "QuelThalas",

    ["The Exodar"] = "Azuremyst",
    ["Azuremyst Isle"] = "Azuremyst",
    ["Bloodmyst Isle"] = "Azuremyst",

    ["Isle of Quel'Danas"] = "QuelDanas",
}

return WotLKTravelNetwork
