-- QM_NavArrow.lua
-- Built-in navigation HUD arrow + minimap blip for the QuestMap Map Pin.
-- Replaces the TomTom dependency.  No external addon required.
--
-- Public API (called from QuestMap_MapPin.lua):
--   QM_Nav_Start()         -- begin navigation to the current QM_mapPin
--   QM_Nav_Stop(arrived)   -- end navigation; arrived=true logs the arrival message
--
-- Internally uses Astrolabe (DongleStub "Astrolabe-0.4") for minimap blip
-- placement and yard-distance when available.  Falls back gracefully without it.

-- ── Constants ────────────────────────────────────────────────────────────────
local QM_NAV_ARRIVAL_YARDS  = 10;   -- yards: auto-arrive threshold (Astrolabe path)
local QM_NAV_ARRIVAL_FRAC   = 0.003; -- map-fraction fallback (~9yd in a ~3000yd zone)
local QM_NAV_UPDATE_RATE    = 0.05; -- seconds between HUD updates
local QM_NAV_ARROW_GOOD_COL = { 0.2, 1.0, 0.3 };  -- green  – facing waypoint
local QM_NAV_ARROW_MID_COL  = { 1.0, 0.85, 0.0 }; -- gold   – ~90° off
local QM_NAV_ARROW_BAD_COL  = { 1.0, 0.3,  0.3 }; -- red    – pointing away
local QM_NAV_WRONG_ZONE_COL = { 0.5, 0.5,  0.5 }; -- grey   – different zone

-- ── Astrolabe (grabbed lazily after other addons load) ────────────────────────
local QM_Astrolabe = nil;

-- ── Active navigation state ──────────────────────────────────────────────────
local QM_navActive             = false;
local QM_navUpdateAcc          = 0;
local QM_navTransit            = nil;  -- { label, cont, zoneIdx, fx, fy } or nil
local QM_navTransitClearedZone = nil;  -- GetZoneText() recorded when transit was last cleared
local QM_navWaitingRegion      = nil;  -- target region ID when waiting for continent arrival

-- Region ID → human-readable label for chat messages.
local QM_REGION_LABELS = {
	Kalimdor          = "Kalimdor",
	EasternKingdoms   = "Eastern Kingdoms",
	Outland           = "Outland",
	Northrend         = "Northrend",
	QuelThalas        = "Quel'Thalas",
	Azuremyst         = "Azuremyst / Exodar",
	QuelDanas         = "Isle of Quel'Danas",
};

-- ── Utility: colour gradient ──────────────────────────────────────────────────
local function QM_ColorGradient(t, r1, g1, b1, r2, g2, b2, r3, g3, b3)
	-- t in [0,1]: 0→col1, 0.5→col2, 1→col3
	if t <= 0.5 then
		local f = t * 2;
		return r1+(r2-r1)*f, g1+(g2-g1)*f, b1+(b2-b1)*f;
	else
		local f = (t - 0.5) * 2;
		return r2+(r3-r2)*f, g2+(g3-g2)*f, b2+(b3-b2)*f;
	end
end

-- ── Minimap blip ─────────────────────────────────────────────────────────────
-- A small green dot placed on the Minimap via Astrolabe (if available).

local QM_navMinimapBlip = nil;

local function QM_Nav_CreateMinimapBlip()
	-- Must be a Button so Astrolabe can register scripts on it.
	local f = CreateFrame("Button", "QMNavMinimapBlip", Minimap);
	f:SetSize(12, 12);
	f:SetPoint("CENTER", Minimap, "CENTER", 0, 0);

	local dot = f:CreateTexture(nil, "OVERLAY");
	-- Use a small circular dot.  First try the Minimap tracking dot, then
	-- fall back to a simple coloured circle via the common button highlight.
	local ok = pcall(function() dot:SetTexture("Interface\\Minimap\\Tracking\\None"); end);
	if ok then
		dot:SetVertexColor(0.2, 1.0, 0.3);
	else
		dot:SetTexture("Interface\\Buttons\\UI-Common-MouseHilight");
		dot:SetVertexColor(0.2, 1.0, 0.3, 0.8);
	end
	dot:SetSize(10, 10);
	dot:SetPoint("CENTER", f, "CENTER", 0, 0);
	f.icon  = dot;

	-- Edge arrow: shown when blip is outside the minimap circle.
	local edgeArrow = f:CreateTexture(nil, "OVERLAY");
	edgeArrow:SetTexture("Interface\\MINIMAP\\MinimapArrow");
	edgeArrow:SetVertexColor(0.2, 1.0, 0.3);
	edgeArrow:SetSize(14, 14);
	edgeArrow:SetPoint("CENTER", f, "CENTER", 0, 0);
	edgeArrow:Hide();
	f.arrow = edgeArrow;

	f:Hide();
	QM_navMinimapBlip = f;
end

local function QM_Nav_ShowMinimapBlip()
	if not QM_mapPin then return; end
	if not QM_navMinimapBlip then QM_Nav_CreateMinimapBlip(); end
	if not QM_Astrolabe then return; end  -- Astrolabe not yet available

	-- PlaceIconOnMinimap wants x/y as 0-1 fractions.
	pcall(function()
		QM_Astrolabe:PlaceIconOnMinimap(QM_navMinimapBlip,
			QM_mapPin.continent, QM_mapPin.zone,
			QM_mapPin.fx, QM_mapPin.fy);
	end);
	QM_navMinimapBlip:Show();
end

local function QM_Nav_HideMinimapBlip()
	if not QM_navMinimapBlip then return; end
	if QM_Astrolabe then
		pcall(function()
			QM_Astrolabe:RemoveIconFromMinimap(QM_navMinimapBlip);
		end);
	end
	QM_navMinimapBlip:Hide();
end

-- ── Cross-continent routing via WotLKTravelNetwork ────────────────────────────
-- Astrolabe continent index → travel network logical region.
local QM_CONT_TO_REGION = {
	[1] = "Kalimdor",
	[2] = "EasternKingdoms",
	[3] = "Outland",
	[4] = "Northrend",
};

-- Astrolabe coordinates for every node defined in WotLKTravelNetwork.
-- zone: the camelCase internal key used by Astrolabe's WorldMapSize table.
local QM_NODE_COORDS = {
	-- Northrend
	Dalaran            = { cont=4, zone="Dalaran",        fx=0.50, fy=0.50 },
	ValianceKeep       = { cont=4, zone="BoreanTundra",   fx=0.57, fy=0.51 },
	Valgarde           = { cont=4, zone="HowlingFjord",   fx=0.25, fy=0.17 },
	WarsongHold        = { cont=4, zone="BoreanTundra",   fx=0.38, fy=0.40 },
	VengeanceLanding   = { cont=4, zone="HowlingFjord",   fx=0.45, fy=0.11 },
	-- Eastern Kingdoms
	Stormwind          = { cont=2, zone="Stormwind",      fx=0.52, fy=0.67 },
	Ironforge          = { cont=2, zone="Ironforge",      fx=0.50, fy=0.50 },
	MenethilHarbor     = { cont=2, zone="Wetlands",       fx=0.24, fy=0.62 },
	StormwindHarbor    = { cont=2, zone="Stormwind",      fx=0.13, fy=0.40 },
	Undercity          = { cont=2, zone="Undercity",      fx=0.50, fy=0.50 },
	TirisfalZeppelin   = { cont=2, zone="Tirisfal",       fx=0.62, fy=0.74 },
	BootyBay           = { cont=2, zone="Stranglethorn",  fx=0.47, fy=0.91 },
	DarkPortalAzeroth  = { cont=2, zone="BlastedLands",   fx=0.57, fy=0.27 },
	BlastedLandsPortal = { cont=2, zone="BlastedLands",   fx=0.55, fy=0.30 },
	-- Quel'Thalas (shares Astrolabe cont=2)
	Silvermoon         = { cont=2, zone="SilvermoonCity", fx=0.50, fy=0.50 },
	-- Kalimdor
	Darnassus          = { cont=1, zone="Darnassis",      fx=0.50, fy=0.51 },
	RuttheranVillage   = { cont=1, zone="Teldrassil",     fx=0.55, fy=0.91 },
	Auberdine          = { cont=1, zone="Darkshore",      fx=0.47, fy=0.56 },
	Theramore          = { cont=1, zone="Dustwallow",     fx=0.85, fy=0.28 },
	Orgrimmar          = { cont=1, zone="Ogrimmar",       fx=0.50, fy=0.50 },
	OrgrimmarZeppelin  = { cont=1, zone="Durotar",        fx=0.42, fy=0.09 },
	ThunderBluff       = { cont=1, zone="ThunderBluff",   fx=0.50, fy=0.50 },
	Ratchet            = { cont=1, zone="Barrens",        fx=0.75, fy=0.47 },
	-- Azuremyst (shares Astrolabe cont=1)
	Exodar             = { cont=1, zone="TheExodar",      fx=0.50, fy=0.50 },
	AzuremystDock      = { cont=1, zone="AzuremystIsle",  fx=0.63, fy=0.62 },
	-- Outland
	HellfireStair      = { cont=3, zone="Hellfire",       fx=0.44, fy=0.58 },
	DarkPortalOutland  = { cont=3, zone="Hellfire",       fx=0.47, fy=0.59 },
	Shattrath          = { cont=3, zone="ShattrathCity",  fx=0.48, fy=0.52 },
	-- Isle of Quel'Danas (shares Astrolabe cont=2)
	SunsReach          = { cont=2, zone="Sunwell",        fx=0.50, fy=0.50 },
};

-- Resolve an Astrolabe zone name string to its integer zone index.
local function QM_Nav_ZoneIndex(cont, zoneName)
	if not (QM_Astrolabe and QM_Astrolabe.ContinentList) then return nil; end
	local list = QM_Astrolabe.ContinentList[cont];
	if not list then return nil; end
	for i, name in ipairs(list) do
		if name == zoneName then return i; end
	end
	return nil;
end

-- Map a continent index + display zone name to a logical region ID.
-- Uses WotLKTravelNetwork.ZoneToRegion first (sub-region precision),
-- falls back to the coarse continent mapping.
local function QM_Nav_GetRegion(contIdx, zoneName)
	if WotLKTravelNetwork and zoneName then
		local r = WotLKTravelNetwork.ZoneToRegion[zoneName];
		if r then return r; end
	end
	return QM_CONT_TO_REGION[contIdx];
end

-- DFS: can we reach any node in targetRegion starting from fromNodeId?
local function QM_Nav_CanReach(fromNodeId, targetRegion, faction, visited)
	if not WotLKTravelNetwork then return false; end
	visited = visited or {};
	if visited[fromNodeId] then return false; end
	visited[fromNodeId] = true;
	local nd = WotLKTravelNetwork.nodes[fromNodeId];
	if nd and nd.region == targetRegion then return true; end
	for _, r in ipairs(WotLKTravelNetwork.GetRoutesFrom(fromNodeId, faction)) do
		if QM_Nav_CanReach(r.to, targetRegion, faction, visited) then return true; end
	end
	return false;
end

-- Build a transit waypoint { label, cont, zoneIdx, fx, fy } for a node ID.
-- If a specific outgoing route is provided and has departure coordinates,
-- those override the generic node anchor so we arrive at the exact boarding spot.
-- zoneIdx falls back to 0 (continent level) when Astrolabe hasn't loaded yet;
-- ComputeDistance still works at continent level, just slightly less precise.
local function QM_Nav_MakeWaypoint(nodeId, optRoute)
	local coords = QM_NODE_COORDS[nodeId];
	if not coords then return nil; end
	local nd = WotLKTravelNetwork and WotLKTravelNetwork.nodes[nodeId];
	local fx, fy = coords.fx, coords.fy;
	-- Only apply routeCoords when they use /way-style 0-100 percentages.
	-- World-coordinate (system="world") entries have raw X/Y/Z spawn data
	-- that is NOT a zone percentage — skip those and keep the node anchor.
	if optRoute and optRoute.fromCoords
			and optRoute.fromCoords.x and optRoute.fromCoords.y
			and optRoute.fromCoords.system == "way" then
		fx = optRoute.fromCoords.x / 100;
		fy = optRoute.fromCoords.y / 100;
	end
	return {
		label   = nd and nd.label or nodeId,
		cont    = coords.cont,
		zoneIdx = QM_Nav_ZoneIndex(coords.cont, coords.zone) or 0,
		fx      = fx,
		fy      = fy,
	};
end

-- Route type → natural-language verb for chat instructions.
local QM_ROUTE_VERB = {
	portal       = "Take portal",
	boat         = "Take boat",
	zeppelin     = "Take zeppelin",
	orb          = "Use Orb of Translocation",
	world_portal = "Enter the Dark Portal",
	walk         = "Follow path",
};

local function QM_Nav_BuildInstruction(routeType, hubLabel, destLabel)
	local verb = QM_ROUTE_VERB[routeType] or ("Travel via " .. (routeType or "?"));
	if routeType == "orb" or routeType == "world_portal" then
		return verb .. " at " .. hubLabel;
	elseif routeType == "portal" then
		return verb .. " to " .. destLabel .. " (" .. hubLabel .. ")";
	else  -- boat, zeppelin, walk
		return verb .. " to " .. destLabel .. " from " .. hubLabel;
	end
end

-- Find the nearest valid first-hop transit node from the player toward the pin.
-- Considers faction, uses ZoneToRegion for sub-region precision (e.g. Quel'Thalas),
-- and picks the closest reachable node by yard distance.
-- When Astrolabe can't compute distance, picks the lowest-cost route as fallback.
local function QM_Nav_FindTransit(pC, pZ, px, py, pin)
	if not WotLKTravelNetwork then return nil; end
	local faction = "Neutral";
	if UnitFactionGroup then
		local g = UnitFactionGroup("player");
		if g == "Alliance" or g == "Horde" then faction = g; end
	end
	-- Determine regions — use GetRealZoneText for the player's actual region
	-- even when pC is nil or the viewed map is on the wrong continent.
	local realZone     = GetRealZoneText and GetRealZoneText() or (GetZoneText and GetZoneText() or nil);
	local playerRegion = QM_Nav_GetRegion(pC, realZone);
	local pinRegion    = QM_Nav_GetRegion(pin.continent, pin.zoneName);
	if not playerRegion or not pinRegion or playerRegion == pinRegion then return nil; end
	local bestWp, bestDist, bestCost = nil, math.huge, math.huge;
	for nodeId, nd in pairs(WotLKTravelNetwork.nodes) do
		if nd.region == playerRegion
				and WotLKTravelNetwork.IsFactionAllowed(nd.faction or "Neutral", faction)
				and QM_Nav_CanReach(nodeId, pinRegion, faction, {}) then
			-- Find an outgoing route that leads toward pinRegion.
			-- Prefer routes with exact departure coords (faction-specific portals/docks).
			-- Fall back to any valid route so routing works even without full routeCoords.
			local routes = WotLKTravelNetwork.GetRoutesFrom(nodeId, faction);
			local bestRoute = nil;
			for _, r in ipairs(routes) do
				if r.fromCoords and r.fromCoords.x and r.fromCoords.y then
					local destNd = WotLKTravelNetwork.nodes[r.to];
					if (destNd and destNd.region == pinRegion)
							or QM_Nav_CanReach(r.to, pinRegion, faction, {}) then
						bestRoute = r;
						break;
					end
				end
			end
			-- Fallback: any route toward pinRegion, even without routeCoords.
			if not bestRoute then
				for _, r in ipairs(routes) do
					local destNd = WotLKTravelNetwork.nodes[r.to];
					if (destNd and destNd.region == pinRegion)
							or QM_Nav_CanReach(r.to, pinRegion, faction, {}) then
						bestRoute = r;
						break;
					end
				end
			end
			local wp = QM_Nav_MakeWaypoint(nodeId, bestRoute);
			if wp then
				-- Attach a human-readable instruction for chat + HUD.
				if bestRoute then
					local destNd = WotLKTravelNetwork.nodes[bestRoute.to];
					local destLabel = destNd and destNd.label or bestRoute.to;
					wp.instruction = QM_Nav_BuildInstruction(bestRoute.type, nd.label, destLabel);
					wp.routeCost = bestRoute.cost or 99;
				end
				local d = math.huge;
				if QM_Astrolabe and pC and px and py then
					pcall(function()
						d = QM_Astrolabe:ComputeDistance(pC, pZ or 0, px, py, wp.cont, wp.zoneIdx, wp.fx, wp.fy) or math.huge;
					end);
				end
				-- Pick by distance when available; fall back to route cost when
				-- Astrolabe can't compute distance (all d == math.huge).
				local cost = wp.routeCost or 99;
				if d < bestDist
						or (d == bestDist and cost < bestCost)
						or (not bestWp) then
					bestDist = d; bestCost = cost; bestWp = wp;
				end
			end
		end
	end
	return bestWp;
end
-- Print the full cross-region route plan to chat. Called from both QM_Nav_Start
-- (immediate, if Astrolabe has position) and the tick (deferred fallback).
local function QM_Nav_PrintRoutePlan(t, pin)
	if not DEFAULT_CHAT_FRAME then return; end
	local dest = pin.zoneName or "?";
	local xPct = math.floor(pin.fx * 100 + 0.5);
	local yPct = math.floor(pin.fy * 100 + 0.5);
	DEFAULT_CHAT_FRAME:AddMessage(string.format(
		"|cffffff78QuestMap:|r Route to Map Pin in |cff00ff00%s|r (%d, %d):", dest, xPct, yPct));
	if t.instruction then
		DEFAULT_CHAT_FRAME:AddMessage(
			"  |cffd0d0d0-|r |cff66ff66" .. t.instruction .. "|r");
	end
	DEFAULT_CHAT_FRAME:AddMessage(
		"  |cffd0d0d0-|r Travel to Map Pin");
end
-- ── HUD Arrow ─────────────────────────────────────────────────────────────────
-- A draggable on-screen arrow pointing toward the map pin.

local QM_navArrowFrame = nil;

local function QM_Nav_CreateArrowFrame()
	local f = CreateFrame("Button", "QMNavArrow", UIParent);
	f:SetSize(56, 72);
	-- Default position: upper-centre of screen.
	f:SetPoint("TOP", UIParent, "TOP", 0, -120);
	f:SetFrameStrata("HIGH");
	f:SetMovable(true);
	f:EnableMouse(true);
	f:RegisterForDrag("LeftButton");
	f:SetClampedToScreen(true);
	f:SetScript("OnDragStart", function(self) self:StartMoving(); end);
	f:SetScript("OnDragStop",  function(self) self:StopMovingOrSizing(); end);

	-- Backdrop
	f:SetBackdrop({
		bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 10,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	});
	f:SetBackdropColor(0.04, 0.04, 0.08, 0.88);
	f:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8);

	-- Arrow texture (same texture as the map-pin player arrow in QuestMap)
	local arrowTex = f:CreateTexture(nil, "OVERLAY");
	arrowTex:SetTexture("Interface\\MINIMAP\\MinimapArrow");
	arrowTex:SetSize(40, 40);
	arrowTex:SetPoint("TOP", f, "TOP", 0, -6);
	f.arrowTex = arrowTex;

	-- Final destination label (always shows the map pin zone name, gold)
	local destStr = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	destStr:SetPoint("TOPLEFT",  f, "BOTTOMLEFT",  4,  0);
	destStr:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", -4, 0);
	destStr:SetHeight(14);
	destStr:SetJustifyH("CENTER");
	destStr:SetTextColor(1, 0.82, 0);
	f.destStr = destStr;

	-- Transit step label ("→ Hub Name" when cross-region routing is active, otherwise hidden)
	local titleStr = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	titleStr:SetPoint("TOP", destStr, "BOTTOM", 0, -1);
	titleStr:SetWidth(130);
	titleStr:SetHeight(12);
	titleStr:SetJustifyH("CENTER");
	titleStr:SetTextColor(0.75, 0.85, 1.0);  -- light blue for transit info
	f.titleStr = titleStr;

	-- Distance label
	local distStr = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	distStr:SetPoint("TOP", titleStr, "BOTTOM", 0, -1);
	distStr:SetWidth(120);
	distStr:SetHeight(12);
	distStr:SetJustifyH("CENTER");
	distStr:SetTextColor(0.7, 0.7, 0.7);
	f.distStr = distStr;

	-- Right-click to stop navigation
	f:RegisterForClicks("RightButtonUp");
	f:SetScript("OnClick", function(self, button)
		if button == "RightButton" then
			QM_Nav_Stop(false);
		end
	end);
	f:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT");
		GameTooltip:SetText("Map Pin Navigation", 1, 1, 1);
		GameTooltip:AddLine("Drag to move.", 0.7, 0.7, 0.7);
		GameTooltip:AddLine("Right-click to stop navigation.", 0.7, 0.7, 0.7);
		GameTooltip:Show();
	end);
	f:SetScript("OnLeave", function() GameTooltip:Hide(); end);

	f:Hide();
	QM_navArrowFrame = f;
end

-- Called every QM_NAV_UPDATE_RATE seconds while navigating.
local function QM_Nav_UpdateArrow(elapsed)
	if not QM_navArrowFrame then return; end
	local f = QM_navArrowFrame;
	local pin = QM_mapPin;
	if not pin then f:Hide(); return; end

	-- If waiting for continent arrival, keep the arrow hidden.
	if QM_navWaitingRegion then
		f:Hide();
		return;
	end

	-- ── Player position (two-pass) ───────────────────────────────────────────
	-- Pass 1: Astrolabe (may return nil when world map is open).
	-- IMPORTANT: Skip Astrolabe when the embedded map is at world/continent zoom
	-- (GetCurrentMapContinent <= 0 or GetCurrentMapZone == 0).  At those levels
	-- GetPlayerMapPosition("player") returns 0,0, which causes Astrolabe's
	-- GetCurrentPlayerPosition to internally call SetMapToCurrentZone + SetMapZoom
	-- as a fix-up.  Those calls fire WORLD_MAP_UPDATE, which triggers our
	-- QuestMap handler (WorldMapFrame_Update + QM_UpdateMapPOIs + QM_SyncNavBar).
	-- Because this tick runs every 0.05 s the result is ~40 WORLD_MAP_UPDATE
	-- events per second, freezing the WorldMapFrame.
	local pC, pZ, px, py = nil, nil, nil, nil;
	if QM_Astrolabe then
		local viewC = GetCurrentMapContinent();
		local viewZ = GetCurrentMapZone();
		if viewC and viewZ and viewC > 0 and viewZ > 0 then
			pcall(function()
				pC, pZ, px, py = QM_Astrolabe:GetCurrentPlayerPosition();
			end);
			if not (pC and pC >= 0) then pC, pZ, px, py = nil, nil, nil, nil; end
		end
	end
	-- Pass 2: map display fallback (safe — does not modify the map state).
	if not pC then
		local mx, my = GetPlayerMapPosition("player");
		if mx and my and (mx ~= 0 or my ~= 0) then
			pC = GetCurrentMapContinent();
			pZ = GetCurrentMapZone();
			px, py = mx, my;
		end
	end

	-- ── Region routing (continent + sub-region aware) ──────────────────────────
	-- Use GetRealZoneText for reliable region detection even when pC is nil or
	-- the viewed map is showing the pin's continent instead of the player's.
	local realZone     = GetRealZoneText and GetRealZoneText() or (GetZoneText and GetZoneText() or nil);
	local playerRegion = QM_Nav_GetRegion(pC, realZone);
	local pinRegion    = QM_Nav_GetRegion(pin.continent, pin.zoneName);
	local sameRegion   = (playerRegion and pinRegion and playerRegion == pinRegion);

	-- Player reached the pin's region — clear transit and forget the cleared-zone guard.
	if sameRegion and QM_navTransit then
		QM_navTransit            = nil;
		QM_navTransitClearedZone = nil;
	end

	-- Need cross-region routing and no waypoint yet → find nearest transit node.
	-- Only re-evaluate once the player has actually moved to a different zone
	-- (i.e. boarded a boat/portal and zoned) since the last transit was cleared.
	-- Allow routing even without exact position (pC may be nil) — FindTransit
	-- uses GetRealZoneText internally for region detection and falls back to
	-- route cost when Astrolabe distance is unavailable.
	if not sameRegion and not QM_navTransit then
		local currentZone = realZone;
		if currentZone ~= QM_navTransitClearedZone then
			local t = QM_Nav_FindTransit(pC, pZ, px, py, pin);
			if t then
				QM_navTransit = t;
				QM_Nav_PrintRoutePlan(t, pin);
			end
		end
	end

	-- ── Active navigation target (transit hub or final pin) ─────────────────
	local tCont, tZone, tFx, tFy;
	if QM_navTransit then
		tCont = QM_navTransit.cont;
		tZone = QM_navTransit.zoneIdx;
		tFx   = QM_navTransit.fx;
		tFy   = QM_navTransit.fy;
	elseif sameRegion then
		tCont = pin.continent;
		tZone = pin.zone;
		tFx   = pin.fx;
		tFy   = pin.fy;
	else
		-- Different continent, no transit hub — hide arrow.
		f:Hide();
		return;
	end

	-- ── Distance + direction ─────────────────────────────────────────────────
	local distYards     = nil;
	local xDir, yDir    = nil, nil;

	if QM_Astrolabe and pC and pC >= 0 and px then
		pcall(function()
			local d, xd, yd = QM_Astrolabe:ComputeDistance(pC, pZ, px, py, tCont, tZone, tFx, tFy);
			if d then distYards = d; xDir = xd; yDir = yd; end
		end);
	end

	-- Map-fraction fallback: same region, same zone, no transit active.
	local fxDir, fyDir = nil, nil;
	if not xDir and sameRegion and not QM_navTransit then
		local mpx, mpy = GetPlayerMapPosition("player");
		if mpx and mpy and (mpx ~= 0 or mpy ~= 0) then
			local cc = GetCurrentMapContinent();
			local cz = GetCurrentMapZone();
			if cc == pin.continent and cz == pin.zone then
				fxDir = pin.fx - mpx;
				fyDir = pin.fy - mpy;
				-- Retry ComputeDistance with this confirmed-valid position.
				if QM_Astrolabe then
					pcall(function()
						local d, xd, yd = QM_Astrolabe:ComputeDistance(cc, cz, mpx, mpy, pin.continent, pin.zone, pin.fx, pin.fy);
						if d then distYards = d; xDir = xd; yDir = yd; end
					end);
				end
				-- Fallback arrival by map fraction.
				if math.sqrt(fxDir*fxDir + fyDir*fyDir) <= QM_NAV_ARRIVAL_FRAC then
					QM_Nav_Stop(true);
					return;
				end
			end
		end
	end

	-- ── Arrival check ────────────────────────────────────────────────────────
	if distYards and distYards <= QM_NAV_ARRIVAL_YARDS then
		if QM_navTransit then
			-- Reached the transit hub — clear it and remember which zone we're in.
			-- FindTransit won't re-fire until the player has zoned somewhere different.
			if DEFAULT_CHAT_FRAME then
				local msg = "|cffffff78QuestMap:|r At |cff00ff00" .. QM_navTransit.label .. "|r";
				if QM_navTransit.instruction then
					msg = msg .. " — |cff66ff66" .. QM_navTransit.instruction .. "|r";
				else
					msg = msg .. " — use the transit to continue.";
				end
				DEFAULT_CHAT_FRAME:AddMessage(msg);
			end
			QM_navTransit            = nil;
			QM_navTransitClearedZone = GetZoneText and GetZoneText() or "";
		else
			QM_Nav_Stop(true);
		end
		return;
	end

	-- ── Arrow direction ──────────────────────────────────────────────────────
	-- SetRotation and GetPlayerFacing use COUNTERCLOCKWISE-from-North.
	-- CCW bearing from east-positive/south-positive components: atan2(-x,-y).
	local br,bg,bb = unpack(QM_NAV_ARROW_BAD_COL);
	local mr,mg,mb = unpack(QM_NAV_ARROW_MID_COL);
	local gr,gg,gb = unpack(QM_NAV_ARROW_GOOD_COL);
	local hasDir = false;

	local function applyBearing(ex, sy)
		local bearing  = math.atan2(-ex, -sy);
		local relAngle = bearing - GetPlayerFacing();
		local perc     = math.abs((math.pi - math.abs(relAngle)) / math.pi);
		f.arrowTex:SetRotation(relAngle);
		f.arrowTex:SetVertexColor(QM_ColorGradient(perc, br,bg,bb, mr,mg,mb, gr,gg,gb));
	end

	if xDir and yDir then
		applyBearing(xDir, yDir);
		hasDir = true;
	elseif fxDir and fyDir then
		applyBearing(fxDir, fyDir);
		hasDir = true;
	else
		f.arrowTex:SetRotation(0);
		f.arrowTex:SetVertexColor(unpack(QM_NAV_WRONG_ZONE_COL));
	end

	-- ── Labels ───────────────────────────────────────────────────────────────
	-- Final destination: always gold, always visible.
	local pinZone = pin.zoneName or "Unknown";
	f.destStr:SetText((#pinZone > 22) and (pinZone:sub(1, 20) .. "..") or pinZone);

	-- Transit step: light blue, only when cross-region routing is active.
	if QM_navTransit then
		f.titleStr:SetText("\226\134\146 " .. QM_navTransit.label);  -- → arrow prefix
	else
		f.titleStr:SetText("");
	end

	if distYards then
		f.distStr:SetText(string.format("%d yd", math.floor(distYards + 0.5)));
	elseif not sameRegion and not QM_navTransit then
		f.distStr:SetText("(no route)");
	elseif hasDir then
		f.distStr:SetText("(no zone data)");
	else
		f.distStr:SetText("(different zone)");
	end

	if not f:IsShown() then f:Show(); end
end

-- ── Per-frame driver ──────────────────────────────────────────────────────────
-- Attached to a standalone frame so it runs independently of QuestMapFrame.

local QM_navTickFrame = CreateFrame("Frame");
QM_navTickFrame:SetScript("OnUpdate", function(self, elapsed)
	if not QM_navActive then return; end
	QM_navUpdateAcc = QM_navUpdateAcc + elapsed;
	if QM_navUpdateAcc < QM_NAV_UPDATE_RATE then return; end
	QM_navUpdateAcc = 0;
	QM_Nav_UpdateArrow(elapsed);
end);

-- Listen for zone changes so we detect when the player arrives on the
-- target continent (after taking a portal/boat/zeppelin manually).
QM_navTickFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA");
QM_navTickFrame:SetScript("OnEvent", function(self, event)
	if event ~= "ZONE_CHANGED_NEW_AREA" then return; end
	if not (QM_navActive and QM_navWaitingRegion and QM_mapPin) then return; end

	-- Re-check the player's region after zoning.
	local realZone = GetRealZoneText and GetRealZoneText() or (GetZoneText and GetZoneText() or nil);
	-- Also query the map API for continent index after the zone change.
	SetMapToCurrentZone();
	local pC = GetCurrentMapContinent();
	local currentRegion = QM_Nav_GetRegion(pC, realZone);

	if currentRegion == QM_navWaitingRegion then
		-- Player arrived on the correct continent!
		QM_navWaitingRegion = nil;
		local pin = QM_mapPin;
		if DEFAULT_CHAT_FRAME then
			local regionLabel = QM_REGION_LABELS[currentRegion] or currentRegion;
			DEFAULT_CHAT_FRAME:AddMessage(string.format(
				"|cffffff78QuestMap:|r Arrived in |cff00ff00%s|r — navigating to Map Pin.",
				regionLabel));
		end
		-- Show the arrow and minimap blip now.
		QM_Nav_ShowMinimapBlip();
		if QM_navArrowFrame then
			local zoneName = pin.zoneName or "Unknown";
			local display  = (#zoneName > 22) and (zoneName:sub(1, 20) .. "..") or zoneName;
			QM_navArrowFrame.destStr:SetText(display);
			QM_navArrowFrame.titleStr:SetText("");
			QM_navArrowFrame.distStr:SetText("...");
			QM_navArrowFrame.arrowTex:SetVertexColor(unpack(QM_NAV_ARROW_GOOD_COL));
			QM_navArrowFrame:Show();
		end
	end
end);

-- ── Astrolabe deferred grab + blip re-register ────────────────────────────────
local QM_navAstroFrame = CreateFrame("Frame");
QM_navAstroFrame:RegisterEvent("ADDON_LOADED");
QM_navAstroFrame:SetScript("OnEvent", function(self, event, addonName)
	if QM_Astrolabe then
		self:UnregisterEvent("ADDON_LOADED");
		return;
	end
	if not DongleStub then return; end
	local ok, lib = pcall(DongleStub, "Astrolabe-0.4", true);
	if ok and lib then
		QM_Astrolabe = lib;
		self:UnregisterEvent("ADDON_LOADED");
		-- Sync WorldMapVisible: if the embedded map is already open, tell Astrolabe so
		-- its minimap-icon coroutine does not call SetMapToCurrentZone()+SetMapZoom()
		-- when GetPlayerMapPosition returns 0,0 at world/continent zoom levels.
		if QUESTMAP_WORLDMAP_ATTACHED then
			QM_Astrolabe.WorldMapVisible = true;
		end
		-- If navigation was already started before Astrolabe loaded, place the blip now.
		if QM_navActive and QM_mapPin then
			QM_Nav_ShowMinimapBlip();
		end
	end
end);

-- ── Public API ────────────────────────────────────────────────────────────────

function QM_Nav_Start()
	if not QM_mapPin then return; end
	if not QM_navArrowFrame then QM_Nav_CreateArrowFrame(); end

	QM_navActive             = true;
	QM_navUpdateAcc          = 0;
	QM_navTransit            = nil;   -- re-evaluated on first tick
	QM_navTransitClearedZone = nil;

	-- Minimap blip
	QM_Nav_ShowMinimapBlip();

	-- Update labels immediately.
	local pin = QM_mapPin;
	if QM_navArrowFrame then
		local zoneName = pin.zoneName or "Unknown";
		local display  = (#zoneName > 22) and (zoneName:sub(1, 20) .. "..") or zoneName;
		QM_navArrowFrame.destStr:SetText(display);
		QM_navArrowFrame.titleStr:SetText("...");
		QM_navArrowFrame.distStr:SetText("...");
		QM_navArrowFrame.arrowTex:SetVertexColor(unpack(QM_NAV_ARROW_GOOD_COL));
		QM_navArrowFrame:Show();
	end

	-- Try immediate transit routing.
	-- Pass 1: Astrolabe position (best — enables distance-based node selection).
	-- Pass 2: zone-text fallback (always available — uses route cost ranking).
	local pC, pZ, px, py;
	if QM_Astrolabe then
		pcall(function()
			pC, pZ, px, py = QM_Astrolabe:GetCurrentPlayerPosition();
		end);
		if not (pC and pC >= 0) then pC, pZ, px, py = nil, nil, nil, nil; end
	end
	-- FindTransit uses GetRealZoneText internally so it works even without pC.
	local t = QM_Nav_FindTransit(pC, pZ, px, py, pin);
	if t then
		QM_navTransit = t;
		QM_Nav_PrintRoutePlan(t, pin);
	end

	if not QM_navTransit then
		-- Determine whether we are on a different continent.
		local realZone     = GetRealZoneText and GetRealZoneText() or (GetZoneText and GetZoneText() or nil);
		local playerRegion = QM_Nav_GetRegion(pC, realZone);
		local pinRegion    = QM_Nav_GetRegion(pin.continent, pin.zoneName);
		local xPct = math.floor(pin.fx * 100 + 0.5);
		local yPct = math.floor(pin.fy * 100 + 0.5);

		if playerRegion and pinRegion and playerRegion ~= pinRegion then
			-- Cross-continent with no known travel route — hide arrow,
			-- tell the player to get to the correct continent manually.
			local regionLabel = QM_REGION_LABELS[pinRegion] or pinRegion;
			QM_navWaitingRegion = pinRegion;
			if QM_navArrowFrame then QM_navArrowFrame:Hide(); end
			QM_Nav_HideMinimapBlip();
			if DEFAULT_CHAT_FRAME then
				DEFAULT_CHAT_FRAME:AddMessage(string.format(
					"|cffffff78QuestMap:|r Map Pin is in |cff00ff00%s|r (%d, %d) — |cff00ff00%s|r.",
					pin.zoneName, xPct, yPct, regionLabel));
				DEFAULT_CHAT_FRAME:AddMessage(
					"  |cffd0d0d0-|r Travel to |cff00ff00" .. regionLabel .. "|r");
				DEFAULT_CHAT_FRAME:AddMessage(
					"  |cffd0d0d0-|r Travel to Map Pin");
			end
		else
			-- Same continent — show arrow, navigate directly.
			if DEFAULT_CHAT_FRAME then
				DEFAULT_CHAT_FRAME:AddMessage(string.format(
					"|cffffff78QuestMap:|r Navigating to Map Pin in |cff00ff00%s|r (%d, %d).",
					pin.zoneName, xPct, yPct));
				DEFAULT_CHAT_FRAME:AddMessage(
					"  |cffd0d0d0-|r Travel to Map Pin");
			end
		end
	end
end

function QM_Nav_Stop(arrived)
	QM_navActive             = false;
	QM_navTransit            = nil;
	QM_navTransitClearedZone = nil;
	QM_navWaitingRegion      = nil;
	-- Clear the navigating-quest indicator and refresh the list so the arrow
	-- icon reverts to the normal golden circle immediately.
	if QM_navQuestLogIdx then
		QM_navQuestLogIdx = nil;
		if QuestMapFrame and QuestMapFrame:IsShown() and QuestMapFrame_UpdateQuestList then
			QuestMapFrame_UpdateQuestList();
		end
	end

	-- Hide the HUD arrow.
	if QM_navArrowFrame then
		QM_navArrowFrame:Hide();
	end

	-- Hide the minimap blip.
	QM_Nav_HideMinimapBlip();

	-- Notify QuestMap_MapPin.lua to clear its glow state.
	if arrived then
		-- Log arrival in chat.
		local zoneName = QM_mapPin and QM_mapPin.zoneName or "waypoint";
		if DEFAULT_CHAT_FRAME then
			DEFAULT_CHAT_FRAME:AddMessage(string.format(
				"|cffffff78QuestMap:|r Arrived at |cff00ff00%s|r — navigation complete.", zoneName));
		end
	end

	-- Clear the pin glow in QuestMap_MapPin.lua.
	-- (QM_mapPinNavigating is owned by MapPin.lua; we reset it here so the
	--  glow loop stops even when Stop is called from this file's arrival check.)
	QM_mapPinNavigating = false;
	local pinF = QuestMapFrame and QuestMapFrame._mapPinFrame;
	if pinF then
		pinF._glowAlpha = 0;
		if pinF._glow then pinF._glow:Hide(); end
	end

	-- On arrival, remove the pin entirely (same as pressing "Remove Pin").
	if arrived then
		QM_mapPin = nil;
		if pinF then pinF:Hide(); end
		if QuestMapFrame and QuestMapFrame._mapPinBtn then
			QuestMapFrame._mapPinBtn._normalTex:SetVertexColor(1, 1, 1);
		end
	end
end

-- Public getter so QuestMap_MapPin.lua (loaded after this file) can access
-- Astrolabe for coordinate projection to parent-map views.
function QM_Nav_GetAstrolabe()
	return QM_Astrolabe;
end

-- ── Coordinates Display Window ────────────────────────────────────────────────
-- Shows current zone + /way-style coordinates (0-100) and the Astrolabe zone key.
-- Toggle with /qmcoords.  Useful for verifying transport point positions for
-- wotlk_travel_network.lua routeCoords entries.
--
-- Coordinate format matches routeCoords entries (divide by 100 for Astrolabe fx/fy).

local QM_coordsFrame   = nil;
local QM_coordsTickAcc = 0;
local QM_COORDS_RATE   = 0.12;  -- update ~8× per second; smooth but not spammy

local function QM_Coords_Create()
	local f = CreateFrame("Button", "QMCoordsFrame", UIParent);
	f:SetSize(190, 60);
	f:SetPoint("TOP", UIParent, "TOP", 0, -190);
	f:SetFrameStrata("HIGH");
	f:SetMovable(true);
	f:EnableMouse(true);
	f:RegisterForDrag("LeftButton");
	f:SetClampedToScreen(true);
	f:SetScript("OnDragStart", function(self) self:StartMoving(); end);
	f:SetScript("OnDragStop",  function(self) self:StopMovingOrSizing(); end);

	f:SetBackdrop({
		bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 10,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	});
	f:SetBackdropColor(0.04, 0.04, 0.08, 0.88);
	f:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8);

	-- Header: "QuestMap Coords"
	local header = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	header:SetPoint("TOPLEFT",  f, "TOPLEFT",  6, -5);
	header:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -5);
	header:SetHeight(12);
	header:SetJustifyH("CENTER");
	header:SetTextColor(1, 0.82, 0);
	header:SetText("QuestMap Coords");
	f.header = header;

	-- Zone display name (GetZoneText)
	local zoneStr = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	zoneStr:SetPoint("TOPLEFT",  f, "TOPLEFT",  6, -20);
	zoneStr:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -20);
	zoneStr:SetHeight(13);
	zoneStr:SetJustifyH("LEFT");
	zoneStr:SetTextColor(0.9, 0.9, 0.9);
	f.zoneStr = zoneStr;

	-- /way coordinates line
	local wayStr = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	wayStr:SetPoint("TOPLEFT",  f, "TOPLEFT",  6, -33);
	wayStr:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -33);
	wayStr:SetHeight(13);
	wayStr:SetJustifyH("LEFT");
	wayStr:SetTextColor(0.4, 1.0, 0.4);
	f.wayStr = wayStr;

	-- Astrolabe zone key (only shown when different from display name)
	local astroStr = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	astroStr:SetPoint("TOPLEFT",  f, "TOPLEFT",  6, -46);
	astroStr:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -46);
	astroStr:SetHeight(11);
	astroStr:SetJustifyH("LEFT");
	astroStr:SetTextColor(0.55, 0.55, 0.75);
	f.astroStr = astroStr;

	-- Right-click closes
	f:RegisterForClicks("RightButtonUp");
	f:SetScript("OnClick", function(self, button)
		if button == "RightButton" then self:Hide(); end
	end);
	f:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT");
		GameTooltip:SetText("QuestMap Coordinates", 1, 1, 1);
		GameTooltip:AddLine("Drag to move.", 0.7, 0.7, 0.7);
		GameTooltip:AddLine("Right-click to close.", 0.7, 0.7, 0.7);
		GameTooltip:AddLine("Green line: /way coords for routeCoords entries.", 0.4, 1.0, 0.4);
		GameTooltip:AddLine("Blue line: Astrolabe zone key for QM_NODE_COORDS.", 0.55, 0.55, 0.75);
		GameTooltip:Show();
	end);
	f:SetScript("OnLeave", function() GameTooltip:Hide(); end);

	f:Hide();
	QM_coordsFrame = f;
end

local function QM_Coords_Update()
	if not QM_coordsFrame or not QM_coordsFrame:IsShown() then return; end

	local zoneName = GetZoneText and GetZoneText() or "Unknown";

	-- Prefer Astrolabe: tracked every frame, zone-independent, full precision.
	-- GetCurrentPlayerPosition returns cont, zone_index, x, y  (x/y are 0-1 fractions).
	local wayLine  = "/way  --  --";
	local astroKey = nil;

	if QM_Astrolabe and QM_Astrolabe.ContinentList then
		local pC, pZ, ax, ay;
		pcall(function()
			pC, pZ, ax, ay = QM_Astrolabe:GetCurrentPlayerPosition();
		end);
		if pC and pZ and ax and ay then
			-- ×100 converts 0-1 fraction to the /way-style 0-100 format
			-- used in routeCoords entries (same numbers you verified in-game).
			wayLine  = string.format("%.2f, %.2f", ax * 100, ay * 100);
			astroKey = QM_Astrolabe.ContinentList[pC] and QM_Astrolabe.ContinentList[pC][pZ];
		end
	end

	-- Fallback when Astrolabe is unavailable or returned nil (e.g. indoors, loading).
	if wayLine == "/way  --  --" then
		local mx, my = GetPlayerMapPosition("player");
		if mx and my and (mx ~= 0 or my ~= 0) then
			wayLine = string.format("%.2f, %.2f  (map)", mx * 100, my * 100);
		end
	end

	QM_coordsFrame.zoneStr:SetText(zoneName);
	QM_coordsFrame.wayStr:SetText(wayLine);

	-- Show Astrolabe's internal camelCase zone key below when it differs from the
	-- display name — useful to spot mismatches in QM_NODE_COORDS.zone entries.
	if astroKey and astroKey ~= zoneName then
		QM_coordsFrame.astroStr:SetText("key: " .. astroKey);
		QM_coordsFrame:SetHeight(62);
	else
		QM_coordsFrame.astroStr:SetText("");
		QM_coordsFrame:SetHeight(50);
	end
end

-- Attach coords update to the existing nav tick frame (runs even when nav is off).
local _origNavOnUpdate = QM_navTickFrame:GetScript("OnUpdate");
QM_navTickFrame:SetScript("OnUpdate", function(self, elapsed)
	if _origNavOnUpdate then _origNavOnUpdate(self, elapsed); end
	QM_coordsTickAcc = QM_coordsTickAcc + elapsed;
	if QM_coordsTickAcc >= QM_COORDS_RATE then
		QM_coordsTickAcc = 0;
		QM_Coords_Update();
	end
end);

-- /qmcoords slash command
SLASH_QMCOORDS1 = "/qmcoords";
SlashCmdList["QMCOORDS"] = function()
	if not QM_coordsFrame then QM_Coords_Create(); end
	if QM_coordsFrame:IsShown() then
		QM_coordsFrame:Hide();
	else
		QM_coordsFrame:Show();
		QM_Coords_Update();  -- refresh immediately on open
	end
end;
