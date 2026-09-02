-- QuestMap.lua

do
	local _orig = GetBindingFromClick;
	GetBindingFromClick = function(input, ...)
		if not input then return nil; end
		return _orig(input, ...);
	end;
end

QUESTMAP_MAP_WIDTH  = 640;
QUESTMAP_MAP_HEIGHT = 668 * QUESTMAP_MAP_WIDTH / 1002;
local QUESTMAP_MAP_SCALE = QUESTMAP_MAP_WIDTH / 1002;
QUESTMAP_WORLDMAP_ATTACHED = false;

local QM_FRAME_WIDTH_FULL    = 960;
local QM_FRAME_WIDTH_COMPACT = 650;

-- ── Quest list row heights (px) ──────────────────────────────────
local QM_H_OBJ      = 13;
local QM_H_ZONE     = 20;
local QM_H_QUEST    = 18;
local QM_ROW_WIDTH  = 270;

QuestMap_CollapsedZones = {};

local qm_oAll   = {};
local qm_zHdrs  = {};
local qm_qRows  = {};

QuestMap_SelectedQuest = nil;
QuestMap_SelectedZone  = nil;
QM_navQuestLogIdx      = nil;

local QM_updatingPOIs = false;
local QM_navFromQuest = false;

local QM_SyncNavBar;

local QM_poiPool = {};
local QM_landmarkFilterEnabled = {};
local QM_filterPanel = nil;
local QM_filterBD    = nil;
local QM_savedWMBOnUpdate = nil;

local function QM_RaiseMapOverlayControls()
	if not WorldMapButton then return; end
	local strata = WorldMapButton:GetFrameStrata();
	local baseLevel = WorldMapButton:GetFrameLevel();

	local controls = {
		_G["QuestMapLandmarkFilterButton"],
		_G["QuestMapLocateMeButton"],
		_G["QuestMapMapPinButton"],
		_G["QuestMapPanelToggleButton"],
	};

	for i, btn in ipairs(controls) do
		if btn then
			btn:SetFrameStrata(strata);
			btn:SetFrameLevel(baseLevel + 20 + i);
			btn:Show();
		end
	end
end

-- ── Movement transparency fade ────────────────────────────────────────────
local QM_fadeTarget    = 1.0;
local QM_FADE_RATE_OUT = 1.5;
local QM_FADE_RATE_IN  = 0.75;

-- ── Map zoom / pan state ──────────────────────────────────────────────────────
QM_zoomLevel  = 1.0;
local QM_ZOOM_MIN   = 1.0;
local QM_ZOOM_MAX   = 4.0;
local QM_ZOOM_STEP  = 0.20;
local QM_isDragging = false;
local QM_dragMoved = false;
local QM_dragStartX, QM_dragStartY, QM_dragScrollX, QM_dragScrollY;

local function QM_SetCompletedPOICircles(show)
	local prefix = "poiWorldMapPOIFrame4_";
	local i = 1;
	while true do
		local btn = _G[prefix..i];
		if not btn then break; end
		if not btn._qmCircleBg then
			btn:SetHitRectInsets(0, 0, 0, 0);
			local bg = btn:CreateTexture(nil, "BACKGROUND");
			bg:SetTexture("Interface\\WorldMap\\UI-QuestPoi-NumberIcons");
			bg:SetTexCoord(0.875, 1.0, 0.875, 1.0);
			bg:SetSize(32, 32);
			bg:SetPoint("CENTER", btn, "CENTER", 0, 0);
			btn._qmCircleBg = bg;
		end
		if show then btn._qmCircleBg:Show(); else btn._qmCircleBg:Hide(); end
		i = i + 1;
	end
end

local function QM_ApplyZoomTransform()
	if not (QUESTMAP_WORLDMAP_ATTACHED and QuestMapFrame._mapScroller) then return end
	local sf = QuestMapFrame._mapScroller;
	local sc = QuestMapFrame._mapScrollChild;
	local s  = QUESTMAP_MAP_SCALE * QM_zoomLevel;
	local W  = QUESTMAP_MAP_WIDTH * QM_zoomLevel;
	local H  = QUESTMAP_MAP_HEIGHT * QM_zoomLevel;
	sc:SetSize(W, H);
	WorldMapDetailFrame:SetScale(s);
	WorldMapDetailFrame:ClearAllPoints();
	WorldMapDetailFrame:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, 0);
	WorldMapBlobFrame:SetScale(s);
	WorldMapBlobFrame.xRatio = nil;
	WorldMapButton:SetScale(s);
	local maxSX = math.max(0, W - QUESTMAP_MAP_WIDTH);
	local maxSY = math.max(0, H - QUESTMAP_MAP_HEIGHT);
	sf:SetHorizontalScroll(math.max(0, math.min(maxSX, sf:GetHorizontalScroll())));
	sf:SetVerticalScroll(math.max(0, math.min(maxSY, sf:GetVerticalScroll())));
end

local _TI_NONE = "Interface\\MINIMAP\\Tracking\\None";
local _TI_FM   = "Interface\\MINIMAP\\Tracking\\FlightMaster";
local _TI_SB   = "Interface\\MINIMAP\\Tracking\\Stable";
local _TI_BM   = "Interface\\MINIMAP\\Tracking\\Battlemaster";
local _TI_RPR  = "Interface\\MINIMAP\\Tracking\\Repair";
local _TI_MINE = "Interface\\MINIMAP\\Tracking\\Mining";
local _TI_INN  = "Interface\\MINIMAP\\Tracking\\Innkeeper";
local _TI_DEF  = { _TI_NONE, 0.70,0.70,0.70, 10, "Unknown" };
local QM_TI_INFO;
do
	local function _r(from, to, tex, r, g, b, sz, label)
		for i = from, to do
			QM_TI_INFO[i] = { tex, r, g, b, sz, label };
		end
	end
	QM_TI_INFO = {};
	_r(1,  1,  _TI_MINE, 0.75,0.75,0.75, 11, "Mine");
	_r(2,  2,  _TI_MINE, 0.90,0.25,0.20, 11, "Mine");
	_r(3,  3,  _TI_MINE, 0.25,0.50,1.00, 11, "Mine");
	_r(4,  4,  _TI_NONE, 0.55,0.75,0.55, 11, "Graveyard");
	_r(5,  5,  _TI_FM,  0.90,0.85,0.50, 13, "Flightmaster");
	_r(6,  6,  _TI_BM,   1.00,0.82,0.00, 16, "City");
	_r(7,  7,  _TI_BM,   1.00,1.00,1.00, 11, "Flag");
	_r(8,  8,  _TI_NONE, 0.55,0.55,0.55, 10, "Graveyard");
	_r(9,  9,  _TI_BM,   0.25,0.50,1.00, 11, "Tower");
	_r(10, 10, _TI_BM,   0.90,0.25,0.20, 11, "Tower");
	_r(11, 11, _TI_BM,   0.25,0.50,1.00, 11, "Tower");
	_r(12, 12, _TI_BM,   0.90,0.25,0.20, 11, "Tower");
	_r(13, 14, _TI_NONE, 0.90,0.25,0.20, 11, "Graveyard");
	_r(15, 15, _TI_NONE, 0.25,0.50,1.00, 11, "Graveyard");
	_r(16, 16, _TI_NONE, 0.65,0.65,0.65, 11, "Graveyard");
	_r(17, 18, _TI_NONE, 0.35,0.55,1.00, 11, "Graveyard");
	_r(19, 19, _TI_NONE, 0.90,0.25,0.20, 11, "Graveyard");
	_r(20, 20, _TI_MINE, 0.85,0.65,0.10, 11, "Gold Mine");
	_r(21, 21, _TI_NONE, 0.70,0.60,0.40, 10, "Lumber Mill");
	_r(22, 22, _TI_NONE, 0.25,0.50,1.00, 10, "Lumber Mill");
	_r(23, 23, _TI_NONE, 0.25,0.50,1.00, 10, "Lumber Mill");
	_r(24, 24, _TI_NONE, 0.90,0.25,0.20, 10, "Lumber Mill");
	_r(25, 25, _TI_NONE, 0.90,0.25,0.20, 10, "Lumber Mill");
	_r(26, 26, _TI_RPR,  0.75,0.75,0.75, 10, "Blacksmith");
	_r(27, 27, _TI_RPR,  0.25,0.50,1.00, 10, "Blacksmith");
	_r(28, 28, _TI_RPR,  0.25,0.50,1.00, 10, "Blacksmith");
	_r(29, 29, _TI_RPR,  0.90,0.25,0.20, 10, "Blacksmith");
	_r(30, 30, _TI_RPR,  0.90,0.25,0.20, 10, "Blacksmith");
	_r(31, 31, _TI_NONE, 0.60,0.80,0.40, 10, "Farm");
	_r(32, 32, _TI_NONE, 0.25,0.50,1.00, 10, "Farm");
	_r(33, 33, _TI_NONE, 0.25,0.50,1.00, 10, "Farm");
	_r(34, 34, _TI_NONE, 0.90,0.25,0.20, 10, "Farm");
	_r(35, 35, _TI_NONE, 0.90,0.25,0.20, 10, "Farm");
	_r(36, 36, _TI_SB,   0.80,0.65,0.30, 10, "Stables");
	_r(37, 37, _TI_SB,   0.25,0.50,1.00, 10, "Stables");
	_r(38, 38, _TI_SB,   0.25,0.50,1.00, 10, "Stables");
	_r(39, 39, _TI_SB,   0.90,0.25,0.20, 10, "Stables");
	_r(40, 40, _TI_SB,   0.90,0.25,0.20, 10, "Stables");
	_r(41, 41, _TI_NONE, 0.60,0.20,0.80, 11, "Skull");
	_r(42, 42, _TI_NONE, 0.70,0.70,0.70, 10, "Unknown");
	_r(43, 43, _TI_BM,   0.25,0.50,1.00, 10, "Flag");
	_r(44, 44, _TI_BM,   0.90,0.25,0.20, 10, "Flag");
	_r(45, 45, _TI_BM,   0.85,0.85,0.85, 10, "Flag");
	_r(46, 46, _TI_BM,   0.25,0.50,1.00, 10, "Crest");
	_r(47, 47, _TI_BM,   0.50,0.65,0.90, 10, "Crest");
	_r(48, 48, _TI_BM,   0.90,0.25,0.20, 10, "Crest");
	_r(49, 49, _TI_BM,   0.90,0.55,0.50, 10, "Crest");
	_r(50, 51, _TI_BM,   0.25,0.50,1.00, 10, "Tower");
	_r(52, 53, _TI_BM,   0.90,0.25,0.20, 10, "Tower");
	_r(54, 55, _TI_BM,   0.75,0.75,0.75, 10, "Tower");
	_r(56, 58, _TI_NONE, 0.70,0.70,0.70, 10, "Bridge");
	_r(59, 61, _TI_NONE, 0.90,0.25,0.20, 10, "Bridge");
	_r(62, 64, _TI_NONE, 0.25,0.50,1.00, 10, "Bridge");
	_r(65, 67, _TI_RPR,  0.75,0.75,0.75, 10, "Workshop");
	_r(68, 70, _TI_RPR,  0.90,0.25,0.20, 10, "Workshop");
	_r(71, 73, _TI_RPR,  0.25,0.50,1.00, 10, "Workshop");
	_r(74, 76, _TI_NONE, 0.75,0.75,0.75, 10, "Gate");
	_r(77, 79, _TI_NONE, 0.90,0.25,0.20, 10, "Gate");
	_r(80, 82, _TI_NONE, 0.25,0.50,1.00, 10, "Gate");
	_r(83, 85, _TI_NONE, 0.70,0.70,0.70, 10, "Wall");
	_r(86, 88, _TI_NONE, 0.90,0.25,0.20, 10, "Wall");
	_r(89, 91, _TI_NONE, 0.25,0.50,1.00, 10, "Wall");
	_r(92,  94, _TI_NONE, 0.70,0.70,0.70, 10, "Wall");
	_r(95,  97, _TI_NONE, 0.90,0.25,0.20, 10, "Wall");
	_r(98, 100, _TI_NONE, 0.25,0.50,1.00, 10, "Wall");
	_r(101, 101, _TI_BM,  1.00,0.30,0.30, 12, "Combat");
	_r(102, 104, _TI_NONE, 0.95,0.90,0.30, 10, "Gate");
	_r(105, 107, _TI_NONE, 0.70,0.30,0.90, 10, "Gate");
	_r(108, 110, _TI_NONE, 0.30,0.80,0.40, 10, "Gate");
	_r(111, 121, _TI_NONE, 1.00,1.00,1.00, 10, "Number");
	_r(122, 124, _TI_NONE, 0.90,0.25,0.20, 10, "Unknown");
	_r(125, 127, _TI_NONE, 0.25,0.50,1.00, 10, "Unknown");
	_r(128, 130, _TI_BM,   0.30,0.80,0.40, 10, "Tower");
	_r(131, 133, _TI_BM,   0.95,0.90,0.30, 10, "Tower");
	_r(134, 134, _TI_NONE, 1.00,0.50,0.10, 12, "Skull");
	_r(135, 135, _TI_RPR,  0.75,0.75,0.75, 10, "Siege Workshop");
	_r(136, 137, _TI_RPR,  0.25,0.50,1.00, 10, "Siege Workshop");
	_r(138, 139, _TI_RPR,  0.90,0.25,0.20, 10, "Siege Workshop");
	_r(140, 140, _TI_NONE, 0.60,0.80,1.00, 10, "Hangar");
	_r(141, 142, _TI_NONE, 0.25,0.50,1.00, 10, "Hangar");
	_r(143, 144, _TI_NONE, 0.90,0.25,0.20, 10, "Hangar");
	_r(145, 145, _TI_NONE, 0.40,0.70,1.00, 10, "Docks");
	_r(146, 147, _TI_NONE, 0.25,0.50,1.00, 10, "Docks");
	_r(148, 149, _TI_NONE, 0.90,0.25,0.20, 10, "Docks");
	_r(150, 150, _TI_NONE, 0.90,0.65,0.20, 10, "Refinery");
	_r(151, 152, _TI_NONE, 0.25,0.50,1.00, 10, "Refinery");
	_r(153, 154, _TI_NONE, 0.90,0.25,0.20, 10, "Refinery");
end

local function QM_GetTIData(ti)
	local info = QM_TI_INFO[ti] or _TI_DEF;
	return info[1], info[2], info[3], info[4], info[5], info[6];
end

local QM_A_CITIES = {
	"stormwind", "ironforge", "darnassus", "exodar", "teldrassil",
	"gnomeregan", "azure watch",
};
local QM_H_CITIES = {
	"orgrimmar", "thunder bluff", "undercity", "silvermoon",
	"bilgewater", "crossroads", "sen'jin", "razor hill",
};
local function QM_GetCityFaction(name)
	local lname = (name or ""):lower();
	for _, k in ipairs(QM_A_CITIES) do
		if lname:find(k, 1, true) then return 0.30,0.60,1.00; end
	end
	for _, k in ipairs(QM_H_CITIES) do
		if lname:find(k, 1, true) then return 1.00,0.30,0.20; end
	end
	return 1.00,0.82,0.00;
end

local QM_FM_KEYS = {
	"flight", "gryphon", "wyvern", "hippogryph",
	"wind rider", "bat handler", "dragonhawk",
	"flight master", "taxi", "rider", "handler",
};
local QM_FM_TI = { [3]=true, [4]=true, [5]=true };
local function QM_IsFlightMaster(ti, name, desc)
	if QM_FM_TI[ti] then return true; end
	local s = ((name or "") .. " " .. (desc or "")):lower();
	for _, k in ipairs(QM_FM_KEYS) do
		if s:find(k, 1, true) then return true; end
	end
	return false;
end

local QM_CITY_MAPID_OVERRIDES = {
	["dalaran"]         = 504,
	["wintergrasp"]     = 501,
	["stormwind"]       = 301,
	["ironforge"]       = 341,
	["darnassus"]       = 381,
	["exodar"]          = 471,
	["orgrimmar"]       = 321,
	["thunder bluff"]   = 362,
	["undercity"]       = 382,
	["silvermoon"]      = 480,
	["shattrath"]       = 481,
};

local function QM_ResolveLandmarkMapID(mapLinkID, name)
	if mapLinkID and mapLinkID ~= 0 then
		return mapLinkID;
	end
	if name then
		local lname = name:lower();
		for key, id in pairs(QM_CITY_MAPID_OVERRIDES) do
			if lname:find(key, 1, true) then return id; end
		end
	end
	return nil;
end

local function QM_UpdateMapPOIs()
	if not QUESTMAP_WORLDMAP_ATTACHED then return; end
	if QM_updatingPOIs then return; end
	QM_updatingPOIs = true;
	if QuestMapFrame._mapScrollChild then
		WorldMapPOIFrame:ClearAllPoints();
		WorldMapPOIFrame:SetPoint("TOPLEFT", QuestMapFrame._mapScrollChild, "TOPLEFT", 0, 0);
	end
	local origSize     = WORLDMAP_QUESTLIST_SIZE;
	local origSettings = WORLDMAP_SETTINGS.size;
	local qmScale      = QUESTMAP_MAP_SCALE * QM_zoomLevel;

	WORLDMAP_QUESTLIST_SIZE = qmScale;
	WORLDMAP_SETTINGS.size  = qmScale;
	WorldMapFrame_SetPOIMaxBounds();
	local ok, count = pcall(WorldMapFrame_UpdateQuests);
	WORLDMAP_QUESTLIST_SIZE = origSize;
	WORLDMAP_SETTINGS.size  = origSettings;
	WorldMapFrame_SetPOIMaxBounds();
	QM_updatingPOIs = false;

	if ok and count and count > 0 then
		WorldMapPOIFrame:Show();
		QM_SetCompletedPOICircles(true);
	else
		WorldMapPOIFrame:Hide();
		QM_SetCompletedPOICircles(false);
	end

	local function filterType(prefix)
		local i = 1;
		while true do
			local btn = _G[prefix..i];
			if not btn then break; end
			if btn:IsShown() then
				local q = btn.quest;
				if q and q.questLogIndex and not IsQuestWatched(q.questLogIndex) then
					btn:Hide();
				end
			end
			i = i + 1;
		end
	end
	filterType("poiWorldMapPOIFrame1_");
	filterType("poiWorldMapPOIFrame4_");

	local swap = _G["poiWorldMapPOIFrame_Swap"];
	if swap and swap:IsShown() then
		local q = swap.quest;
		if q and q.questLogIndex and not IsQuestWatched(q.questLogIndex) then
			swap:Hide();
		end
	end

	if QuestMap_SelectedQuest and QuestMap_SelectedQuest ~= 0 then
		local selQuestID = select(9, GetQuestLogTitle(QuestMap_SelectedQuest));
		local _, _, _, _, _, _, isComplete = GetQuestLogTitle(QuestMap_SelectedQuest);
		if selQuestID and selQuestID ~= 0 and (not isComplete or isComplete <= 0) then
			WorldMapBlobFrame:DrawQuestBlob(selQuestID, true);
			WorldMapBlobFrame:Show();
		end
		if selQuestID and selQuestID ~= 0 then
			QuestPOI_SelectButtonByQuestId("WorldMapPOIFrame", selQuestID, false);
		end
	end

	for idx = 1, NUM_WORLDMAP_POIS do
		local poi = _G["WorldMapFramePOI"..idx];
		if poi then poi:Hide(); end
	end
	if QuestMapFrame._mapScrollChild then
		local sc = QuestMapFrame._mapScrollChild;
		for _, m in ipairs(QM_poiPool) do m:Hide(); end
		local used = 0;
		for i = 1, GetNumMapLandmarks() do
			local name, desc, ti, fx, fy, mapLinkID = GetMapLandmarkInfo(i);
			if not (name and fx and fy) then
			else
				local hasEngineLink = (mapLinkID and mapLinkID ~= 0);
				local hasNameLink   = (not hasEngineLink) and (QM_ResolveLandmarkMapID(nil, name) ~= nil);
				local isTi0Link     = (ti == 0 and (hasEngineLink or hasNameLink));
				local filterKey = ti;
				if isTi0Link then filterKey = 0; end
				local visible = (isTi0Link or ti ~= 0)
					and QM_landmarkFilterEnabled[filterKey] ~= false;
				if visible then
					used = used + 1;
					local m = QM_poiPool[used];
					if not m then
						m = CreateFrame("Button", nil, sc);
						m:SetFrameLevel(sc:GetFrameLevel() + 15);
						local tex = m:CreateTexture(nil, "ARTWORK");
						tex:SetAllPoints(m);
						m._tex = tex;
						m:SetScript("OnEnter", function(self)
							GameTooltip:SetOwner(self, "ANCHOR_CURSOR");
							GameTooltip:SetText(self._name or "", 1, 0.82, 0);
							if self._typeLabel then
								GameTooltip:AddLine(self._typeLabel, 0.5, 0.5, 0.5);
							end
							if self._desc and self._desc ~= "" then
								GameTooltip:AddLine(self._desc, 0.7, 0.7, 0.7, true);
							end
							GameTooltip:Show();
						end);
						m:SetScript("OnLeave", function() GameTooltip:Hide(); end);
						m:SetScript("OnClick", function(self)
							local resolvedID = QM_ResolveLandmarkMapID(self._mapLinkID, self._name);
							if resolvedID then
								SetMapByID(resolvedID);
								WorldMapFrame_Update();
								QM_UpdateMapPOIs();
								QM_SyncNavBar(nil);
							end
						end);
						QM_poiPool[used] = m;
					end
					m._name      = name;
					m._desc      = desc or "";
					m._mapLinkID = mapLinkID;
					m._ti        = ti;
					if m:GetParent() ~= sc then
						m:SetParent(sc);
					end
					local vtex, vr, vg, vb, vsz, vlabel;
					if isTi0Link then
						if QM_IsFlightMaster(ti, name, desc) then
							vtex, vr, vg, vb, vsz, vlabel = _TI_FM, 0.50,1.00,0.55, 14, "Flight Master";
						else
							local cr, cg, cb = QM_GetCityFaction(name);
							vtex, vr, vg, vb, vsz, vlabel = _TI_BM, cr,  cg,  cb,  16, "City";
						end
					else
						vtex, vr, vg, vb, vsz, vlabel = QM_GetTIData(ti);
						if ti == 6 then
							vr, vg, vb = QM_GetCityFaction(name);
						end
						if QM_IsFlightMaster(ti, name, desc) then
							vtex, vr, vg, vb, vsz, vlabel = _TI_FM, 0.50,1.00,0.55, 14, "Flight Master";
						end
					end
					m._typeLabel = vlabel;
					m._tex:ClearAllPoints();
					m._tex:SetAllPoints(m);
					m._tex:SetTexture(vtex);
					m._tex:SetVertexColor(vr, vg, vb);
					m._tex:SetAlpha(1);
					m._tex:Show();
					m:SetSize(vsz, vsz);
					m:ClearAllPoints();
					m:SetPoint("CENTER", sc, "TOPLEFT",
						fx * QUESTMAP_MAP_WIDTH * QM_zoomLevel, -fy * QUESTMAP_MAP_HEIGHT * QM_zoomLevel);
					m:Show();
				end
			end
		end

		if WorldMapButton then
			local _strata = WorldMapButton:GetFrameStrata();
			local _lvl    = WorldMapButton:GetFrameLevel();
			for _, _pm in ipairs(QM_poiPool) do
				if _pm:GetParent() == sc then
					_pm:SetFrameStrata(_strata);
					_pm:SetFrameLevel(_lvl + 5);
				end
			end
			if WorldMapPOIFrame then
				WorldMapPOIFrame:SetFrameStrata(_strata);
				WorldMapPOIFrame:SetFrameLevel(_lvl + 10);
			end
			QM_RaiseMapOverlayControls();
		end
	end
end

local QM_CONT = { [1]="Kalimdor", [2]="Eastern Kingdoms", [3]="Outland", [4]="Northrend" };
local QM_CONT_ORDER = { 1, 2, 4, 3 };

local function QM_FindContByZoneName(name)
	if not name then return nil, nil; end
	for _, c in ipairs(QM_CONT_ORDER) do
		local zones = { GetMapZones(c) };
		for z = 1, #zones do
			if zones[z] == name then return c, z; end
		end
	end
	return nil, nil;
end

local function QM_FindContByZoneIdx(idx)
	if not idx or idx <= 0 then return nil, nil; end
	for _, c in ipairs(QM_CONT_ORDER) do
		local zones = { GetMapZones(c) };
		if zones[idx] and zones[idx] ~= "" then return c, zones[idx]; end
	end
	return nil, nil;
end

local QM_SelectQuestEntry;
QM_navOutdoorParent = QM_navOutdoorParent or nil;
QM_navActiveInstanceMap = QM_navActiveInstanceMap or nil;

local QM_INSTANCE_PARENTS = {
	THEARGENTCOLISEUM = { continent = 4, zoneNames = { "Corona de Hielo", "Icecrown" } },
	CRUSADERSCOLISEUM = { continent = 4, zoneNames = { "Corona de Hielo", "Icecrown" } },
	ICECROWNCITADEL   = { continent = 4, zoneNames = { "Corona de Hielo", "Icecrown" } },
	ULDUAR            = { continent = 4, zoneNames = { "Las Cumbres Tormentosas", "Cumbres Tormentosas", "The Storm Peaks", "Storm Peaks" } },
	KARAZHAN          = { continent = 2, zoneNames = { "Paso de la Muerte", "Deadwind Pass" } },
	NAXXRAMAS         = { continent = 4, zoneNames = { "Cementerio de Dragones", "Dragonblight" } },
	VAULTOFARCHAVON   = { continent = 4, zoneNames = { "Conquista del Invierno", "Wintergrasp" } },
};

local function QM_NavNamesEqual(a, b)
	if not a or not b then return false; end
	local aa = string.lower((string.gsub(a, "[%s%p]", "")));
	local bb = string.lower((string.gsub(b, "[%s%p]", "")));
	return aa == bb;
end

local function QM_ResolveFixedInstanceParent(def)
	if not def or not def.continent or not def.zoneNames then return nil; end
	local zones = { GetMapZones(def.continent) };
	for zoneID, localizedName in ipairs(zones) do
		for _, expectedName in ipairs(def.zoneNames) do
			if QM_NavNamesEqual(localizedName, expectedName) then
				return {
					continent = def.continent,
					zone = zoneID,
					zoneName = localizedName,
				};
			end
		end
	end
	return nil;
end

local function QM_CaptureOutdoorNavParent()
	local inInstance = IsInInstance and IsInInstance();
	if inInstance then return; end

	QM_navActiveInstanceMap = nil;

	local cont = GetCurrentMapContinent();
	local zone = GetCurrentMapZone();
	if cont and cont > 0 and zone and zone > 0 then
		local zones = { GetMapZones(cont) };
		local zoneName = zones[zone];
		if zoneName and zoneName ~= "" then
			QM_navOutdoorParent = {
				continent = cont,
				zone = zone,
				zoneName = zoneName,
			};
		end
	end
end

local function QM_ResolveInstanceNavContext(mapFileName, continentID, cosmicID, zoneID)
	local inInstance, instanceType;
	if IsInInstance then inInstance, instanceType = IsInInstance(); end
	if not inInstance or not instanceType or instanceType == "none" then return nil; end
	if not mapFileName or mapFileName == "" then return nil; end

	local mapKey = string.upper(mapFileName);
	local def = QM_INSTANCE_PARENTS[mapKey];

	if not def then
		for instanceMapKey, definition in pairs(QM_INSTANCE_PARENTS) do
			if string.find(mapKey, instanceMapKey, 1, true) == 1 then
				def = definition;
				break;
			end
		end
	end

	local parent = QM_ResolveFixedInstanceParent(def);

	if QM_navActiveInstanceMap and QM_navActiveInstanceMap ~= mapFileName then
		return nil;
	end

	if not parent and continentID and continentID > 0 and zoneID and zoneID > 0 then
		local zones = { GetMapZones(continentID) };
		if zones[zoneID] and zones[zoneID] ~= "" then
			parent = {
				continent = continentID,
				zone = zoneID,
				zoneName = zones[zoneID],
			};
		end
	end

	if not QM_navActiveInstanceMap and not def
			and (not GetCurrentMapDungeonLevel or (GetCurrentMapDungeonLevel() or 0) <= 0) then
		return nil;
	end

	if not parent then parent = QM_navOutdoorParent; end
	if not parent then return nil; end

	local instanceName = nil;
	if GetRealZoneText then instanceName = GetRealZoneText(); end
	if not instanceName or instanceName == "" then
		instanceName = GetInstanceInfo and GetInstanceInfo() or nil;
	end
	if not instanceName or instanceName == "" then
		instanceName = mapFileName;
	end

	QM_navActiveInstanceMap = mapFileName;
	return {
		continent = parent.continent,
		zone = parent.zone,
		zoneName = parent.zoneName,
		name = instanceName,
		instanceType = instanceType,
		mapFileName = mapFileName,
	};
end

if not QM_NavOutdoorMonitor then
	QM_NavOutdoorMonitor = CreateFrame("Frame");
	QM_NavOutdoorMonitor._elapsed = 0;
	QM_NavOutdoorMonitor:SetScript("OnUpdate", function(self, elapsed)
		self._elapsed = self._elapsed + elapsed;
		if self._elapsed >= 1 then
			self._elapsed = 0;
			QM_CaptureOutdoorNavParent();
		end
	end);
end

QM_SyncNavBar = function(mapID)
	if not QuestMapFrame or not QuestMapFrame.navBar then return; end

	local navBar  = QuestMapFrame.navBar;
	local COSMIC  = WORLDMAP_COSMIC_ID  or -1;
	local WORLD   = WORLDMAP_WORLD_ID   or 0;
	local OUTLAND = WORLDMAP_OUTLAND_ID or 3;

	local continentID = GetCurrentMapContinent();
	local zoneID = GetCurrentMapZone();
	local dungeonLevel = GetCurrentMapDungeonLevel and (GetCurrentMapDungeonLevel() or 0) or 0;
	local mapFileName = GetMapInfo();

	local instanceContext = QM_ResolveInstanceNavContext(mapFileName, continentID, COSMIC, zoneID);
	local resolvedContinent = (continentID and continentID > 0) and continentID or nil;
	local onAzerothWorld = continentID == WORLD;
	local parentZoneName = nil;
	local parentZoneID = nil;

	if instanceContext then
		resolvedContinent = instanceContext.continent;
		parentZoneID = instanceContext.zone;
		parentZoneName = instanceContext.zoneName;
		onAzerothWorld = false;
	else
		if resolvedContinent and zoneID and zoneID > 0 then
			local zones = { GetMapZones(resolvedContinent) };
			parentZoneID = zoneID;
			parentZoneName = zones[zoneID];
		end
	end

	local contName = resolvedContinent and QM_CONT[resolvedContinent] or nil;

	NavBar_Reset(navBar);

	if continentID == COSMIC and not instanceContext then
		return;
	end

	if instanceContext then
		if resolvedContinent == OUTLAND then
			local capCont = resolvedContinent;
			NavBar_AddButton(navBar, { name = contName or "Outland", OnClick = function()
				SetMapZoom(capCont, 0); WorldMapFrame_Update(); QM_UpdateMapPOIs(); QM_SyncNavBar(nil);
			end });
		else
			NavBar_AddButton(navBar, { name = "Azeroth", OnClick = function()
				SetMapZoom(WORLD); WorldMapFrame_Update(); QM_UpdateMapPOIs(); QM_SyncNavBar(nil);
			end });

			if contName then
				local capCont = resolvedContinent;
				NavBar_AddButton(navBar, { name = contName, OnClick = function()
					SetMapZoom(capCont, 0); WorldMapFrame_Update(); QM_UpdateMapPOIs(); QM_SyncNavBar(nil);
				end });
			end
		end

		if parentZoneName and parentZoneID then
			local capCont, capZone = resolvedContinent, parentZoneID;
			NavBar_AddButton(navBar, { name = parentZoneName, OnClick = function()
				SetMapZoom(capCont, capZone); WorldMapFrame_Update(); QM_UpdateMapPOIs(); QM_SyncNavBar(nil);
			end });
		end

		local capLevel = (dungeonLevel and dungeonLevel > 0) and dungeonLevel or 1;
		local instanceLabel = instanceContext.name or mapFileName or "Instance";
		NavBar_AddButton(navBar, { name = instanceLabel, OnClick = function()
			if SetMapToCurrentZone then SetMapToCurrentZone(); end
			if SetDungeonMapLevel and capLevel > 0 then SetDungeonMapLevel(capLevel); end
			WorldMapFrame_Update(); QM_UpdateMapPOIs(); QM_SyncNavBar(nil);
		end });

	elseif resolvedContinent then
		if resolvedContinent == OUTLAND then
			local capCont = resolvedContinent;
			NavBar_AddButton(navBar, { name = contName or "Outland", OnClick = function()
				SetMapZoom(capCont, 0); WorldMapFrame_Update(); QM_UpdateMapPOIs(); QM_SyncNavBar(nil);
			end });
		else
			NavBar_AddButton(navBar, { name = "Azeroth", OnClick = function()
				SetMapZoom(WORLD); WorldMapFrame_Update(); QM_UpdateMapPOIs(); QM_SyncNavBar(nil);
			end });

			if contName then
				local capCont = resolvedContinent;
				NavBar_AddButton(navBar, { name = contName, OnClick = function()
					SetMapZoom(capCont, 0); WorldMapFrame_Update(); QM_UpdateMapPOIs(); QM_SyncNavBar(nil);
				end });
			end
		end

		if parentZoneName and parentZoneID then
			local capCont, capZone = resolvedContinent, parentZoneID;
			NavBar_AddButton(navBar, { name = parentZoneName, OnClick = function()
				SetMapZoom(capCont, capZone); WorldMapFrame_Update(); QM_UpdateMapPOIs(); QM_SyncNavBar(nil);
			end });
		end

	elseif onAzerothWorld then
		NavBar_AddButton(navBar, { name = "Azeroth", OnClick = function()
			SetMapZoom(WORLD); WorldMapFrame_Update(); QM_UpdateMapPOIs(); QM_SyncNavBar(nil);
		end });
	end
end

local function QM_NavigateToQuest(questID)
	if not QUESTMAP_WORLDMAP_ATTACHED then return; end
	if not questID or questID == 0 then return; end

	QuestMapFrame:UnregisterEvent("WORLD_MAP_UPDATE");
	QuestMapFrame:UnregisterEvent("QUEST_POI_UPDATE");

	local mapID = GetQuestWorldMapAreaID(questID);
	local found = false;

	if mapID and mapID ~= 0 then
		SetMapByID(mapID);
		local n = QuestMapUpdateAllQuests();
		for i = 1, n do
			if (QuestPOIGetQuestIDByVisibleIndex(i)) == questID then
				found = true; break;
			end
		end
	end

	if not found then
		local hintCont = (mapID and mapID ~= 0) and GetCurrentMapContinent() or nil;
		if hintCont and hintCont <= 0 then hintCont = nil; end
		local scanOrder = {};
		if hintCont then
			table.insert(scanOrder, hintCont);
			for _, c in ipairs(QM_CONT_ORDER) do
				if c ~= hintCont then table.insert(scanOrder, c); end
			end
		else
			for _, c in ipairs(QM_CONT_ORDER) do table.insert(scanOrder, c); end
		end
		for _, c in ipairs(scanOrder) do
			local zones = { GetMapZones(c) };
			for z = 1, #zones do
				if zones[z] and zones[z] ~= "" then
					SetMapZoom(c, z);
					local n = QuestMapUpdateAllQuests();
					for i = 1, n do
						if (QuestPOIGetQuestIDByVisibleIndex(i)) == questID then
							found = true; break;
						end
					end
					if found then break; end
				end
			end
			if found then break; end
		end
	end

	if not found and mapID and mapID ~= 0 then
		SetMapByID(mapID);
	end

	QuestMapFrame:RegisterEvent("WORLD_MAP_UPDATE");
	QuestMapFrame:RegisterEvent("QUEST_POI_UPDATE");
	WorldMapFrame_Update();
	QM_UpdateMapPOIs();
	QM_navFromQuest = true;
	QM_SyncNavBar(nil);
end

function QM_MapPin_OpenAndNavigate(cont, zone)
	if not QuestMapFrame then return; end
	if not QuestMapFrame:IsShown() then
		QuestMapFrame:Show();
	end
	if not QUESTMAP_WORLDMAP_ATTACHED then return; end
	if cont and cont > 0 and zone and zone >= 0 then
		SetMapZoom(cont, zone);
	end
	WorldMapFrame_Update();
	QM_UpdateMapPOIs();
	QM_SyncNavBar(nil);
end

local function QM_MakeObjLine(parent)
	local f = CreateFrame("Frame", nil, parent);
	f:SetSize(QM_ROW_WIDTH, QM_H_OBJ);
	f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	f.text:SetPoint("TOPLEFT", f, "TOPLEFT", 22, 0);
	f.text:SetWidth(QM_ROW_WIDTH - 24);
	f.text:SetJustifyH("LEFT");
	f.text:SetJustifyV("TOP");
	f.text:SetWordWrap(true);
	return f;
end

local function QM_MakeZoneHdr(parent)
	local f = CreateFrame("Button", nil, parent);
	f:SetSize(QM_ROW_WIDTH, QM_H_ZONE);
	f:RegisterForClicks("LeftButtonUp");

	local atlas = "Interface\\QuestFrame\\questlogframe2x";

	local left = f:CreateTexture(nil, "BACKGROUND");
	left:SetTexture(atlas);
	left:SetTexCoord(0.602539063, 0.631210938, 0.206054688, 0.245117188);
	left:SetPoint("LEFT", f, "LEFT", 0, 0);
	left:SetSize(16, QM_H_ZONE);
	f.headerLeft = left;

	local right = f:CreateTexture(nil, "BACKGROUND");
	right:SetTexture(atlas);
	right:SetTexCoord(0.699218750, 0.734375000, 0.206054688, 0.245117188);
	right:SetPoint("RIGHT", f, "RIGHT", 0, 0);
	right:SetSize(16, QM_H_ZONE);
	f.headerRight = right;

	local center = f:CreateTexture(nil, "BACKGROUND");
	center:SetTexture(atlas);
	center:SetTexCoord(0.633789063, 0.692109375, 0.206054688, 0.245117188);
	center:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0);
	center:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", 0, 0);
	f.headerCenter = center;

	f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	f.text:SetPoint("LEFT", f, "LEFT", 14, 0);
	f.text:SetPoint("RIGHT", f, "RIGHT", -22, 0);
	f.text:SetHeight(QM_H_ZONE);
	f.text:SetJustifyH("LEFT");

	f.arrow = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	f.arrow:SetPoint("RIGHT", f, "RIGHT", -6, 0);
	f.arrow:SetSize(12, QM_H_ZONE);
	f.arrow:SetJustifyH("CENTER");

	return f;
end

local function QM_MakeQuestRow(parent)
	local f = CreateFrame("Button", nil, parent);
	f:SetSize(QM_ROW_WIDTH, QM_H_QUEST);
	f:RegisterForClicks("LeftButtonUp", "RightButtonUp");

	local sel = f:CreateTexture(nil, "ARTWORK");
	sel:SetTexture("Interface\\WorldMap\\UI-QuestPoi-SelectionBar");
	sel:SetBlendMode("ADD"); sel:SetAllPoints(f);
	sel:Hide();
	f.selHl = sel;

	local hl = f:CreateTexture(nil, "HIGHLIGHT");
	hl:SetTexture("Interface\\WorldMap\\UI-QuestPoi-HighlightBar");
	hl:SetBlendMode("ADD"); hl:SetAllPoints(f);

	local pin = CreateFrame("Frame", nil, f);
	pin:SetSize(14, 14);
	pin:SetPoint("LEFT", f, "LEFT", 1, 0);
	local pinBg = pin:CreateTexture(nil, "ARTWORK");
	pinBg:SetTexture("Interface\\WorldMap\\UI-QuestPoi-NumberIcons");
	pinBg:SetTexCoord(0.500, 0.625, 0.875, 1.0);
	pinBg:SetAllPoints(pin);
	pin.bg = pinBg;
	local pinNum = pin:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	pinNum:SetAllPoints(pin);
	pinNum:SetJustifyH("CENTER"); pinNum:SetJustifyV("MIDDLE");
	pin.num = pinNum;
	f.pin = pin;

	f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	f.text:SetPoint("LEFT",  f, "LEFT",  18, 0);
	f.text:SetPoint("RIGHT", f, "RIGHT", -20, 0);
	f.text:SetHeight(QM_H_QUEST);
	f.text:SetWordWrap(false);
	f.text:SetJustifyH("LEFT");

	local cb = CreateFrame("CheckButton", nil, f);
	cb:SetSize(16, 16);
	cb:SetPoint("RIGHT", f, "RIGHT", -3, 0);
	cb:RegisterForClicks("LeftButtonUp");

	cb:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up");
	cb:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down");
	cb:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD");

	local check = cb:CreateTexture(nil, "OVERLAY");
	check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check");
	check:SetAllPoints(cb);
	cb:SetCheckedTexture(check);

	f.checkbox = cb;
	return f;
end

local function qmPoolReset(pool)
	for _, f in ipairs(pool) do f:Hide(); end
end

local function qmPoolGet(pool, factory, parent)
	for _, f in ipairs(pool) do
		if not f:IsShown() then
			f:Show();
			return f;
		end
	end
	local f = factory(parent);
	f:Show();
	pool[#pool + 1] = f;
	return f;
end

local function QM_HideScrollControls(sf)
	local n = sf:GetName();
	if not n then return; end
	local up  = _G[n.."ScrollUpButton"];
	local dn  = _G[n.."ScrollDownButton"];
	local bar = _G[n.."ScrollBar"];
	if up  then up:Hide();  up:SetScript("OnShow",  function(s) s:Hide(); end); end
	if dn  then dn:Hide();  dn:SetScript("OnShow",  function(s) s:Hide(); end); end
	if bar then bar:Hide(); bar:SetScript("OnShow",  function(s) s:Hide(); end); end
end

local QM_ContextMenu        = nil;
local QM_ContextMenuBD      = nil;
local QM_ContextMenu_LogIdx = nil;

local function QM_BuildContextMenu()
	local bd = CreateFrame("Frame", nil, UIParent);
	bd:SetAllPoints(UIParent);
	bd:SetFrameStrata("DIALOG");
	bd:EnableMouse(true);
	bd:SetScript("OnMouseDown", function()
		bd:Hide();
		if QM_ContextMenu then QM_ContextMenu:Hide(); end
	end);
	bd:Hide();
	QM_ContextMenuBD = bd;

	local f = CreateFrame("Frame", "QuestMapContextMenu", UIParent);
	f:SetSize(134, 92);
	f:SetFrameStrata("TOOLTIP");
	f:SetClampedToScreen(true);
	f:SetBackdrop({
		bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 12,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	});
	f:SetBackdropColor(0.06, 0.06, 0.10, 0.95);
	f:SetBackdropBorderColor(0.55, 0.44, 0.1, 1);

	local titleStr = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	titleStr:SetPoint("TOPLEFT",  f, "TOPLEFT",  6, -6);
	titleStr:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6);
	titleStr:SetHeight(14);
	titleStr:SetJustifyH("CENTER");
	titleStr:SetTextColor(1, 0.82, 0);
	f.title = titleStr;

	local divider = f:CreateTexture(nil, "ARTWORK");
	divider:SetTexture(0.55, 0.44, 0.1, 0.7);
	divider:SetHeight(1);
	divider:SetPoint("LEFT",  f, "LEFT",  4, 0);
	divider:SetPoint("RIGHT", f, "RIGHT", -4, 0);
	divider:SetPoint("TOP", titleStr, "BOTTOM", 0, -2);

	local function makeMenuBtn(labelText, r, g, b)
		local btn = CreateFrame("Button", nil, f);
		btn:SetSize(122, 20);
		local hl = btn:CreateTexture(nil, "HIGHLIGHT");
		hl:SetTexture("Interface\\QuestFrame\\UI-QuestLogHighlight");
		hl:SetBlendMode("ADD");
		hl:SetAllPoints(btn);
		local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
		lbl:SetAllPoints(btn);
		lbl:SetJustifyH("CENTER");
		lbl:SetText(labelText);
		lbl:SetTextColor(r, g, b);
		return btn;
	end

	local navigateBtn = makeMenuBtn("Navigate", 0.3, 1.0, 0.55);
	navigateBtn:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", -2, -3);
	navigateBtn:SetScript("OnClick", function()
		local idx = QM_ContextMenu_LogIdx;
		QM_ContextMenuBD:Hide();
		f:Hide();
		if not idx then return; end
		local questID = select(9, GetQuestLogTitle(idx));
		if not questID or questID == 0 then return; end
		QM_SelectQuestEntry(idx, questID);
		QM_NavigateToQuest(questID);
		local _, fx, fy = QuestPOIGetIconInfo(questID);
		if fx and fy and fx > 0 and fy > 0 then
			QM_mapPin = {
				continent    = GetCurrentMapContinent(),
				zone         = GetCurrentMapZone(),
				dungeonLevel = GetCurrentMapDungeonLevel() or 0,
				fx           = fx,
				fy           = fy,
				zoneName     = GetMapInfo() or "Unknown",
			};
			local pinF = QuestMapFrame and QuestMapFrame._mapPinFrame;
			if pinF then pinF:Show(); end;
			if QM_Nav_Stop then QM_Nav_Stop(false); end
			QM_navQuestLogIdx = idx;
			if QM_Nav_Start then QM_Nav_Start(); end
			QuestMapFrame_UpdateQuestList();
		else
			DEFAULT_CHAT_FRAME:AddMessage("|cffffff78QuestMap:|r No map location found for that quest.");
		end
	end);

	local shareBtn = makeMenuBtn(SHARE_QUEST or "Share Quest", 0.85, 0.85, 0.85);
	shareBtn:SetPoint("TOPLEFT", navigateBtn, "BOTTOMLEFT", 0, -2);
	shareBtn:SetScript("OnClick", function()
		local idx = QM_ContextMenu_LogIdx;
		QM_ContextMenuBD:Hide();
		f:Hide();
		if idx then
			SelectQuestLogEntry(idx);
			if GetQuestLogPushable() and (GetNumPartyMembers() > 0 or GetNumRaidMembers() > 1) then
				QuestLogPushQuest();
				PlaySound("igQuestLogOpen");
			else
				print("|cffff8800" .. (SHARE_QUEST or "Share Quest") .. ":|r " .. (ERR_QUEST_PUSH_NOT_IN_PARTY or "Not in a group."));
			end
		end
	end);

	local abandonBtn = makeMenuBtn(ABANDON_QUEST or "Abandon Quest", 1, 0.35, 0.35);
	abandonBtn:SetPoint("TOPLEFT", shareBtn, "BOTTOMLEFT", 0, -2);
	abandonBtn:SetScript("OnClick", function()
		local idx = QM_ContextMenu_LogIdx;
		QM_ContextMenuBD:Hide();
		f:Hide();
		if idx then
			SelectQuestLogEntry(idx);
			SetAbandonQuest();
			local items = GetAbandonQuestItems();
			if items then
				StaticPopup_Hide("ABANDON_QUEST");
				StaticPopup_Show("ABANDON_QUEST_WITH_ITEMS", GetAbandonQuestName(), items);
			else
				StaticPopup_Hide("ABANDON_QUEST_WITH_ITEMS");
				StaticPopup_Show("ABANDON_QUEST", GetAbandonQuestName());
			end
		end
	end);

	f:Hide();
	return f;
end

local function QM_ShowContextMenu(logIdx, title, anchorRow)
	if not QM_ContextMenu then
		QM_ContextMenu = QM_BuildContextMenu();
	end
	local f = QM_ContextMenu;
	QM_ContextMenu_LogIdx = logIdx;
	local display = (title and #title > 20) and (title:sub(1, 18) .. "..") or (title or "");
	f.title:SetText(display);
	f:ClearAllPoints();
	f:SetPoint("TOPLEFT", anchorRow, "BOTTOMLEFT", 0, -2);
	QM_ContextMenuBD:Show();
	f:SetAlpha(0);
	UIFrameFadeIn(f, 0.12, 0, 1);
	f:Show();
end

local function QM_OpenLandmarkFilter(anchorBtn)
	if not QM_filterBD then
		local bd = CreateFrame("Frame", nil, UIParent);
		bd:SetAllPoints(UIParent);
		bd:SetFrameStrata("DIALOG");
		bd:EnableMouse(true);
		bd:SetScript("OnMouseDown", function()
			bd:Hide();
			if QM_filterPanel then QM_filterPanel:Hide(); end
		end);
		bd:Hide();
		QM_filterBD = bd;
	end

	if not QM_filterPanel then
		local f = CreateFrame("Frame", "QuestMapLandmarkFilterPanel", UIParent);
		f:SetFrameStrata("TOOLTIP");
		f:SetClampedToScreen(true);
		f:SetBackdrop({
			bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true, tileSize = 16, edgeSize = 12,
			insets = { left = 3, right = 3, top = 3, bottom = 3 },
		});
		f:SetBackdropColor(0.06, 0.06, 0.10, 0.95);
		f:SetBackdropBorderColor(0.55, 0.44, 0.1, 1);
		f._rows      = {};
		f._allOnBtn  = nil;
		f._allOffBtn = nil;
		f._titleStr  = nil;
		f._sepLine   = nil;
		f._emptyLbl  = nil;
		QM_filterPanel = f;
	end
	local f   = QM_filterPanel;
	local PAD = 5;
	local W   = 200;
	local RH  = 18;

	if not f._titleStr then
		local t = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
		t:SetPoint("TOPLEFT",  f, "TOPLEFT",  PAD, -PAD);
		t:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, -PAD);
		t:SetHeight(14);
		t:SetJustifyH("CENTER");
		t:SetTextColor(1, 0.82, 0);
		t:SetText("Landmark Types");
		f._titleStr = t;
	end

	if not f._sepLine then
		local sep = f:CreateTexture(nil, "ARTWORK");
		sep:SetTexture(0.55, 0.44, 0.1, 0.7);
		sep:SetHeight(1);
		sep:SetPoint("LEFT",  f, "LEFT",  PAD,  0);
		sep:SetPoint("RIGHT", f, "RIGHT", -PAD, 0);
		sep:SetPoint("TOP", f._titleStr, "BOTTOM", 0, -3);
		f._sepLine = sep;
	end

	for _, row in ipairs(f._rows) do row:Hide(); end
	if f._emptyLbl then f._emptyLbl:Hide(); end

	local tiList  = {};
	local seen    = {};
	local hasTi0Link = false;
	for i = 1, GetNumMapLandmarks() do
		local name, desc, ti, _, _, mapLinkID = GetMapLandmarkInfo(i);
		if ti == 0 and ((mapLinkID and mapLinkID ~= 0) or QM_ResolveLandmarkMapID(nil, name) ~= nil) then
			hasTi0Link = true;
		elseif ti and ti ~= 0 and not seen[ti] then
			seen[ti] = true;
			tiList[#tiList + 1] = ti;
		end
	end

	if hasTi0Link then table.insert(tiList, 1, 0); end
	table.sort(tiList);

	local function tiFilterLabel(key)
		if key == 0 then return "Interesting Point"; end
		local _, _, _, _, _, lbl = QM_GetTIData(key);
		return lbl or "Unknown";
	end
	local function tiFilterColor(key)
		if key == 0 then return 1.00, 0.82, 0.00; end
		local _, r, g, b = QM_GetTIData(key);
		return r, g, b;
	end
	local function tiFilterTexture(key)
		if key == 0 then return _TI_BM; end
		local tex = QM_GetTIData(key);
		return tex or _TI_NONE;
	end
	local curY = -(PAD + 14 + 3 + 2);
	if #tiList == 0 then
		if not f._emptyLbl then
			local lbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
			lbl:SetPoint("TOPLEFT",  f, "TOPLEFT",  PAD, curY);
			lbl:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, curY);
			lbl:SetHeight(RH);
			lbl:SetJustifyH("CENTER");
			lbl:SetTextColor(0.5, 0.5, 0.5);
			lbl:SetText("No landmarks on this map.");
			f._emptyLbl = lbl;
		end
		f._emptyLbl:Show();
		f:SetSize(W, math.abs(curY - RH - PAD));
		f:ClearAllPoints();
		f:SetPoint("TOPRIGHT", anchorBtn, "BOTTOMLEFT", 4, -2);
		QM_filterBD:Show();
		f:Show();
		return;
	end

	for ri, ti in ipairs(tiList) do
		local row = f._rows[ri];
		if not row then
			row = CreateFrame("Frame", nil, f);
			row:SetHeight(RH);
			local cb = CreateFrame("Button", nil, row);
			cb:SetSize(14, 14);
			cb:SetPoint("LEFT", row, "LEFT", 0, 0);
			local boxTex = cb:CreateTexture(nil, "BACKGROUND");
			boxTex:SetAllPoints(cb);
			boxTex:SetTexture("Interface\\Buttons\\UI-CheckBox-Up");
			local chkTex = cb:CreateTexture(nil, "OVERLAY");
			chkTex:SetAllPoints(cb);
			chkTex:SetTexture("Interface\\Buttons\\UI-CheckBox-Check");
			cb.chk = chkTex;
			row.cb = cb;
			local icon = row:CreateTexture(nil, "ARTWORK");
			icon:SetSize(14, 14);
			icon:SetPoint("LEFT", cb, "RIGHT", 2, 0);
			row.icon = icon;
			local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
			lbl:SetPoint("LEFT",  icon, "RIGHT", 4, 0);
			lbl:SetPoint("RIGHT", row, "RIGHT", 0, 0);
			lbl:SetHeight(RH);
			lbl:SetJustifyH("LEFT");
			lbl:SetWordWrap(false);
			row.lbl = lbl;
			f._rows[ri] = row;
		end
		row:Show();
		row:ClearAllPoints();
		row:SetPoint("TOPLEFT",  f, "TOPLEFT",  PAD, curY);
		row:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, curY);
		local enabled = QM_landmarkFilterEnabled[ti] ~= false;
		local r, g, b = tiFilterColor(ti);
		row.icon:SetTexture(tiFilterTexture(ti));
		row.icon:SetVertexColor(r, g, b);
		if enabled then row.cb.chk:Show(); else row.cb.chk:Hide(); end
		local label = tiFilterLabel(ti);
		if #label > 26 then label = label:sub(1, 24) .. ".."; end
		row.lbl:SetText(label);
		row.lbl:SetTextColor(r, g, b);
		local capTI = ti;
		row.cb:SetScript("OnClick", function()
			if QM_landmarkFilterEnabled[capTI] == false then
				QM_landmarkFilterEnabled[capTI] = nil;
				row.cb.chk:Show();
			else
				QM_landmarkFilterEnabled[capTI] = false;
				row.cb.chk:Hide();
			end
			QM_UpdateMapPOIs();
		end);
		curY = curY - RH;
	end

	curY = curY - 4;
	if not f._allOnBtn then
		local btn = CreateFrame("Button", nil, f);
		local hl  = btn:CreateTexture(nil, "HIGHLIGHT");
		hl:SetTexture("Interface\\QuestFrame\\UI-QuestLogHighlight");
		hl:SetBlendMode("ADD"); hl:SetAllPoints(btn);
		local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
		lbl:SetAllPoints(btn); lbl:SetJustifyH("CENTER");
		lbl:SetText("All On"); lbl:SetTextColor(0.5, 1, 0.5);
		f._allOnBtn = btn;
	end
	if not f._allOffBtn then
		local btn = CreateFrame("Button", nil, f);
		local hl  = btn:CreateTexture(nil, "HIGHLIGHT");
		hl:SetTexture("Interface\\QuestFrame\\UI-QuestLogHighlight");
		hl:SetBlendMode("ADD"); hl:SetAllPoints(btn);
		local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
		lbl:SetAllPoints(btn); lbl:SetJustifyH("CENTER");
		lbl:SetText("All Off"); lbl:SetTextColor(1, 0.5, 0.5);
		f._allOffBtn = btn;
	end
	local halfW = math.floor((W - PAD * 2) / 2) - 1;
	f._allOnBtn:SetSize(halfW, RH);
	f._allOffBtn:SetSize(halfW, RH);
	f._allOnBtn:ClearAllPoints();
	f._allOffBtn:ClearAllPoints();
	f._allOnBtn:SetPoint( "TOPLEFT",  f, "TOPLEFT",  PAD,  curY);
	f._allOffBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, curY);
	f._allOnBtn:SetScript("OnClick", function()
		for _, tti in ipairs(tiList) do
			QM_landmarkFilterEnabled[tti] = nil;
		end
		for ri2 = 1, #tiList do
			if f._rows[ri2] then f._rows[ri2].cb.chk:Show(); end
		end
		QM_UpdateMapPOIs();
	end);
	f._allOffBtn:SetScript("OnClick", function()
		for _, tti in ipairs(tiList) do
			QM_landmarkFilterEnabled[tti] = false;
		end
		for ri2 = 1, #tiList do
			if f._rows[ri2] then f._rows[ri2].cb.chk:Hide(); end
		end
		QM_UpdateMapPOIs();
	end);
	curY = curY - RH - PAD;
	f:SetSize(W, math.abs(curY));
	f:ClearAllPoints();
	f:SetPoint("TOPRIGHT", anchorBtn, "BOTTOMLEFT", 4, -2);
	QM_filterBD:Show();
	UIFrameFadeIn(f, 0.10, 0, 1);
	f:Show();
end

function QuestMap_ShowBlizzardMap()
	local questID = QuestMap_SelectedQuest and select(9, GetQuestLogTitle(QuestMap_SelectedQuest));
	if QuestMapFrame and QuestMapFrame:IsShown() then
		QuestMapFrame:Hide();
	end
	if WORLDMAP_SETTINGS and WORLDMAP_SETTINGS.size == WORLDMAP_WINDOWED_SIZE then
		SetCVar("miniWorldMap", 0);
		WorldMap_ToggleSizeUp();
	end
	if questID and questID > 0 then
		WorldMap_OpenToQuest(questID);
	else
		ShowUIPanel(WorldMapFrame);
		WorldMapFrame_Update();
	end
end

function QuestMap_ShowEmbeddedMap()
	if WorldMapFrame and WorldMapFrame:IsShown() then
		HideUIPanel(WorldMapFrame);
	end
	if QuestMapFrame then QuestMapFrame:Show(); end
end

local function QM_CreateWorldMapViewButtons()
    return;
end

function QuestMapFrame_TrackQuestButton_OnClick(self)
	if not QuestMap_SelectedQuest or QuestMap_SelectedQuest == 0 then return; end
	local nowWatched = IsQuestWatched(QuestMap_SelectedQuest);
	if nowWatched then
		RemoveQuestWatch(QuestMap_SelectedQuest);
		self:SetChecked(false);
		PlaySound("igMainMenuOptionCheckBoxOff");
	else
		if GetNumQuestWatches and MAX_WATCHABLE_QUESTS and GetNumQuestWatches() >= MAX_WATCHABLE_QUESTS then
			self:SetChecked(false);
			if UIErrorsFrame then
				UIErrorsFrame:AddMessage("Has alcanzado el máximo de misiones seguidas.", 1.0, 0.1, 0.1, 1.0);
			end
			return;
		end
		AddQuestWatch(QuestMap_SelectedQuest);
		self:SetChecked(true);
		PlaySound("igMainMenuOptionCheckBoxOn");
	end

	if WatchFrame_Update then WatchFrame_Update(); end
	if QuestLog_Update then QuestLog_Update(); end
	QM_UpdateMapPOIs();
end

function QuestMapFrame_OnLoad(self)
	QM_CreateWorldMapViewButtons();

	local navBar = CreateFrame("Frame", "QuestMapFrameNavBar", self, "NavBarTemplate");
	navBar:SetHeight(45);
	navBar:SetWidth(580);
	navBar:SetPoint("TOPLEFT", self, "TOPLEFT", 60, -24);
	navBar:SetFrameLevel(self:GetFrameLevel() + 10);
	self.navBar = navBar;

	local homeData = { name = HOME, OnClick = function()
		SetMapZoom(WORLDMAP_COSMIC_ID or -1);
		WorldMapFrame_Update();
		QM_UpdateMapPOIs();
		NavBar_Reset(QuestMapFrame.navBar);
	end };
	NavBar_Initialize(self.navBar, "NavButtonTemplate", homeData,
		self.navBar.home, self.navBar.overflow);
	self.navBar.home:SetWidth(self.navBar.home.text:GetStringWidth() + 50);

	QM_HideScrollControls(self.questDetailsPanel.questDetailLeft.scrollFrame);
	QM_HideScrollControls(self.questDetailsPanel.questDetailRight.scrollFrame);

	local locBtn = CreateFrame("Button", "QuestMapLocateMeButton", self.mapArea);
	locBtn:SetSize(25, 25);
	locBtn:SetPoint("TOPRIGHT", self.mapArea, "TOPRIGHT", -30, -8);

	locBtn:SetNormalTexture("Interface\\MINIMAP\\Tracking\\None");
	locBtn:SetPushedTexture("Interface\\MINIMAP\\Tracking\\None");
	locBtn:GetPushedTexture():SetVertexColor(0.6, 0.6, 0.6);
	locBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD");

	locBtn:SetScript("OnClick", function()
		if not QUESTMAP_WORLDMAP_ATTACHED then return; end
		SetMapToCurrentZone();
		if QM_zoomLevel ~= 1.0 then
			QM_zoomLevel = 1.0;
			local sc_ = QuestMapFrame._mapScrollChild;
			local sf_ = QuestMapFrame._mapScroller;
			if sc_ then sc_:SetSize(QUESTMAP_MAP_WIDTH, QUESTMAP_MAP_HEIGHT); end
			if sf_ then
				sf_:SetHorizontalScroll(0);
				sf_:SetVerticalScroll(0);
			end
			WorldMapDetailFrame:SetScale(QUESTMAP_MAP_SCALE);
			WorldMapBlobFrame:SetScale(QUESTMAP_MAP_SCALE);
			WorldMapButton:SetScale(QUESTMAP_MAP_SCALE);
		end
		WorldMapFrame_Update();
		QM_UpdateMapPOIs();
		QM_SyncNavBar(nil);
		PlaySound("igMainMenuOptionCheckBoxOn");
		local arr = QuestMapFrame._playerArrow;
		if arr then
			arr._glowAlpha = 1;
			arr._glow:SetAlpha(1);
			arr._glow:Show();
		end
	end);
	locBtn:SetScript("OnEnter", function(btn)
		GameTooltip:SetOwner(btn, "ANCHOR_BOTTOMLEFT");
		GameTooltip:SetText("Current Zone", 1, 1, 1);
		GameTooltip:AddLine("Navigate the map to your current zone.", 0.7, 0.7, 0.7, true);
		GameTooltip:Show();
	end);
	locBtn:SetScript("OnLeave", function() GameTooltip:Hide(); end);

	local filterBtn = CreateFrame("Button", "QuestMapLandmarkFilterButton", self.mapArea);
	filterBtn:SetSize(22, 22);
	filterBtn:SetPoint("TOPRIGHT", locBtn, "TOPLEFT", -4, 0);
	filterBtn:SetNormalTexture("Interface\\MINIMAP\\Tracking\\None");
	filterBtn:GetNormalTexture():SetVertexColor(0.3, 0.7, 1);
	filterBtn:SetPushedTexture("Interface\\MINIMAP\\Tracking\\None");
	filterBtn:GetPushedTexture():SetVertexColor(0.2, 0.5, 0.8);
	filterBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD");
	filterBtn:SetScript("OnClick", function(btn)
		if QM_filterPanel and QM_filterPanel:IsShown() then
			QM_filterBD:Hide();
			QM_filterPanel:Hide();
		else
			QM_OpenLandmarkFilter(btn);
		end
	end);
	filterBtn:SetScript("OnEnter", function(btn)
		GameTooltip:SetOwner(btn, "ANCHOR_BOTTOMLEFT");
		GameTooltip:SetText("Landmark Filter", 1, 1, 1);
		GameTooltip:AddLine("Toggle which landmark types appear on the map.", 0.7, 0.7, 0.7, true);
		GameTooltip:Show();
	end);
	filterBtn:SetScript("OnLeave", function() GameTooltip:Hide(); end);

	local panelToggleBtn = CreateFrame("Button", "QuestMapPanelToggleButton", self.mapArea);
	panelToggleBtn:SetSize(32, 32);
	panelToggleBtn:SetPoint("BOTTOMRIGHT", self.mapArea, "BOTTOMRIGHT", 2, 15);
	panelToggleBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD");
	self.panelToggleButton = panelToggleBtn;
	self.rightPanelHidden  = false;

	panelToggleBtn:SetScript("OnClick", function()
		PlaySound("igMainMenuOptionCheckBoxOn");
		QuestMapFrame_TogglePanel();
	end);
	panelToggleBtn:SetScript("OnEnter", function(btn)
		GameTooltip:SetOwner(btn, "ANCHOR_LEFT");
		GameTooltip:SetText(QuestMapFrame.rightPanelHidden and SHOW_QUEST_LIST or HIDE_QUEST_LIST, 1, 1, 1);
		GameTooltip:Show();
	end);
	panelToggleBtn:SetScript("OnLeave", function() GameTooltip:Hide(); end);

	QuestMapFrame_UpdatePanelToggleIcon();

	QM_MapPin_InitButton(self, locBtn);
	QM_RaiseMapOverlayControls();

	local sf = CreateFrame("ScrollFrame", "QuestMapScrollView", self.mapArea);
	sf:SetSize(QUESTMAP_MAP_WIDTH, QUESTMAP_MAP_HEIGHT);
	sf:SetPoint("TOPLEFT", self.mapArea, "TOPLEFT", 0, 0);
	sf:EnableMouseWheel(true);
	local sc = CreateFrame("Frame", "QuestMapScrollChild", sf);
	sc:SetSize(QUESTMAP_MAP_WIDTH, QUESTMAP_MAP_HEIGHT);
	sf:SetScrollChild(sc);
	self._mapScroller    = sf;
	self._mapScrollChild = sc;

	QM_MapPin_InitMarker(self);

	sf:SetScript("OnMouseWheel", function(sfr, delta)
		if not QUESTMAP_WORLDMAP_ATTACHED then return end
		local newZoom = math.max(QM_ZOOM_MIN, math.min(QM_ZOOM_MAX,
			QM_zoomLevel + delta * QM_ZOOM_STEP));
		if newZoom == QM_zoomLevel then return end
		local cx, cy = GetCursorPosition();
		local es = sfr:GetEffectiveScale();
		local vx = cx / es - sfr:GetLeft();
		local vy = sfr:GetTop() - cy / es;
		local sx = sfr:GetHorizontalScroll();
		local sy = sfr:GetVerticalScroll();
		local fx = (sx + vx) / (QUESTMAP_MAP_WIDTH * QM_zoomLevel);
		local fy = (sy + vy) / (QUESTMAP_MAP_HEIGHT * QM_zoomLevel);
		QM_zoomLevel = newZoom;
		local W = QUESTMAP_MAP_WIDTH * QM_zoomLevel;
		local H = QUESTMAP_MAP_HEIGHT * QM_zoomLevel;
		sc:SetSize(W, H);
		sfr:SetHorizontalScroll(math.max(0, math.min(W - QUESTMAP_MAP_WIDTH, fx * W - vx)));
		sfr:SetVerticalScroll(math.max(0, math.min(H - QUESTMAP_MAP_HEIGHT, fy * H - vy)));
		local s = QUESTMAP_MAP_SCALE * QM_zoomLevel;
		WorldMapDetailFrame:SetScale(s);
		WorldMapBlobFrame:SetScale(s);
		WorldMapBlobFrame.xRatio = nil;
		WorldMapButton:SetScale(s);
		QM_UpdateMapPOIs();
	end);

	if WorldMapButton then
		local origDown  = WorldMapButton:GetScript("OnMouseDown");
		local origUp    = WorldMapButton:GetScript("OnMouseUp");
		local origClick = WorldMapButton:GetScript("OnClick");

		WorldMapButton:SetScript("OnMouseDown", function(btn, button)
			if QUESTMAP_WORLDMAP_ATTACHED then

				if button == "LeftButton" then
					if QM_mapPinMode and QM_MapPin_PlaceAtCursor then
						if QM_MapPin_PlaceAtCursor() then return; end
					end

					if QM_zoomLevel > 1 then
						QM_isDragging  = true;
						QM_dragMoved    = false;
						QM_dragStartX, QM_dragStartY = GetCursorPosition();
						QM_dragScrollX = sf:GetHorizontalScroll();
						QM_dragScrollY = sf:GetVerticalScroll();
					end
				end
			end

			if origDown then origDown(btn, button); end
		end);

		WorldMapButton:SetScript("OnMouseUp", function(btn, button)
			if button == "LeftButton" then
				QM_isDragging = false;
			end
			if origUp then origUp(btn, button); end
		end);

		WorldMapButton:SetScript("OnClick", function(btn, button)
			if QUESTMAP_WORLDMAP_ATTACHED then

				if button == "LeftButton" and QM_dragMoved then
					QM_dragMoved = false;
					return;
				end
			end
			if origClick then origClick(btn, button); end
		end);
	end

	local arrowF = CreateFrame("Frame", "QuestMapPlayerArrow", self.mapArea);
	arrowF:SetSize(32, 32);
	arrowF:SetFrameStrata("TOOLTIP");
	local arrowTex = arrowF:CreateTexture(nil, "OVERLAY");
	arrowTex:SetTexture("Interface\\MINIMAP\\MinimapArrow");
	arrowTex:SetAllPoints(arrowF);
	arrowF._tex = arrowTex;

	local glowTex = arrowF:CreateTexture(nil, "BACKGROUND");
	glowTex:SetTexture("Interface\\Buttons\\UI-Common-MouseHilight");
	glowTex:SetBlendMode("ADD");
	glowTex:SetVertexColor(1, 0.85, 0, 1);
	glowTex:SetSize(56, 56);
	glowTex:SetPoint("CENTER", arrowF, "CENTER", 0, 0);
	glowTex:Hide();
	arrowF._glow      = glowTex;
	arrowF._glowAlpha = 0;
	arrowF:Hide();
	self._playerArrow = arrowF;

	self:RegisterEvent("WORLD_MAP_UPDATE");
	self:RegisterEvent("QUEST_LOG_UPDATE");
	self:RegisterEvent("QUEST_POI_UPDATE");

	self:SetScript("OnUpdate", function(self, elapsed)
		local speed = GetUnitSpeed("player");
		QM_fadeTarget = (speed and speed > 0) and 0.25 or 1.0;
		local cur = self:GetAlpha();
		if math.abs(cur - QM_fadeTarget) >= 0.001 then
			if cur > QM_fadeTarget then
				self:SetAlpha(math.max(cur - QM_FADE_RATE_OUT * elapsed, QM_fadeTarget));
			else
				self:SetAlpha(math.min(cur + QM_FADE_RATE_IN  * elapsed, QM_fadeTarget));
			end
		end

		if QM_isDragging and self._mapScroller then
			local sfr = self._mapScroller;
			local cx, cy = GetCursorPosition();
			local es = sfr:GetEffectiveScale();
			local rawDX = QM_dragStartX - cx;
			local rawDY = cy - QM_dragStartY;
			if math.abs(rawDX) > 3 or math.abs(rawDY) > 3 then
				QM_dragMoved = true;
			end
			local dx = rawDX / es;
			local dy = rawDY / es;
			local maxSX = math.max(0, QUESTMAP_MAP_WIDTH * (QM_zoomLevel - 1));
			local maxSY = math.max(0, QUESTMAP_MAP_HEIGHT * (QM_zoomLevel - 1));
			sfr:SetHorizontalScroll(math.max(0, math.min(maxSX, QM_dragScrollX + dx)));
			sfr:SetVerticalScroll(math.max(0, math.min(maxSY, QM_dragScrollY + dy)));
		end

		if QUESTMAP_WORLDMAP_ATTACHED and self._playerArrow and self._mapScroller then
			local sfr = self._mapScroller;
			local arr = self._playerArrow;
			local x, y = GetPlayerMapPosition("player");
			if x and y and not (x == 0 and y == 0) then
				local mapPx = x * QUESTMAP_MAP_WIDTH * QM_zoomLevel;
				local mapPy = y * QUESTMAP_MAP_HEIGHT * QM_zoomLevel;
				local viewX = mapPx - sfr:GetHorizontalScroll();
				local viewY = mapPy - sfr:GetVerticalScroll();
				if viewX >= -16 and viewX <= 530 and viewY >= -16 and viewY <= 358 then
					arr:ClearAllPoints();
					arr:SetPoint("CENTER", self.mapArea, "TOPLEFT", viewX, -viewY);
					arr._tex:SetRotation(GetPlayerFacing());
					arr:Show();
				else
					arr:Hide();
				end
			else
				arr:Hide();
			end
			if arr._glowAlpha and arr._glowAlpha > 0 then
				arr._glowAlpha = math.max(0, arr._glowAlpha - elapsed * 0.7);
				if arr._glowAlpha <= 0 then
					arr._glow:Hide();
				else
					arr._glow:SetAlpha(arr._glowAlpha);
				end
			end
		else
			if self._playerArrow then self._playerArrow:Hide(); end
		end
		QM_MapPin_OnUpdate(self, elapsed);
	end);
end

function QuestMapFrame_OnEvent(self, event, ...)
	if event == "QUEST_LOG_UPDATE" then
		QuestMapFrame_UpdateQuestList();
	elseif event == "WORLD_MAP_UPDATE" or event == "QUEST_POI_UPDATE" then
		if QUESTMAP_WORLDMAP_ATTACHED then
			WorldMapFrame_Update();
			QM_UpdateMapPOIs();
			if QM_navFromQuest then
				QM_navFromQuest = false;
			else
				QM_SyncNavBar(nil);
			end
		end
	end
end

function QuestMapFrame_AttachWorldMap()
	if QUESTMAP_WORLDMAP_ATTACHED then return; end
	if WorldMapFrame:IsShown() then return; end

	local mapArea = QuestMapFrame.mapArea;

	if not (QuestMap_PendingFromWorldMap and QuestMap_PendingFromWorldMap ~= 0) then
		SetMapToCurrentZone();
	end
	WorldMap_LoadTextures();

	local sc = QuestMapFrame._mapScrollChild;
	local sf = QuestMapFrame._mapScroller;
	if not sc then sc = mapArea; end

	QM_zoomLevel = 1.0;
	if sf then sf:SetHorizontalScroll(0); sf:SetVerticalScroll(0); end
	if QuestMapFrame._mapScrollChild then
		QuestMapFrame._mapScrollChild:SetSize(QUESTMAP_MAP_WIDTH, QUESTMAP_MAP_HEIGHT);
	end

	WorldMapDetailFrame:SetParent(sc);
	WorldMapDetailFrame:ClearAllPoints();
	WorldMapDetailFrame:SetScale(QUESTMAP_MAP_SCALE);
	WorldMapDetailFrame:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, 0);
	WorldMapDetailFrame:Show();

	WorldMapButton:SetParent(sc);
	WorldMapButton:SetScale(QUESTMAP_MAP_SCALE);

	WorldMapBlobFrame:SetParent(sc);
	WorldMapBlobFrame:SetScale(QUESTMAP_MAP_SCALE);
	WorldMapBlobFrame.xRatio = nil;

	WorldMapPOIFrame:SetParent(sc);
	WorldMapPOIFrame:ClearAllPoints();
	WorldMapPOIFrame:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, 0);

	if not QM_savedWMBOnUpdate then
		QM_savedWMBOnUpdate = WorldMapButton:GetScript("OnUpdate");
	end
	WorldMapButton:SetScript("OnUpdate", function(self, elapsed)
		local cx, cy = GetCursorPosition();
		cx = cx / self:GetEffectiveScale();
		cy = cy / self:GetEffectiveScale();
		local ctrX, ctrY = self:GetCenter();
		local w = self:GetWidth();
		local h = self:GetHeight();
		local adjY = (ctrY + (h / 2) - cy) / h;
		local adjX = (cx - (ctrX - (w / 2))) / w;
		local name, fileName, tpx, tpy, tx, ty, scx, scy;
		if self:IsMouseOver() then
			name, fileName, tpx, tpy, tx, ty, scx, scy = UpdateMapHighlight(adjX, adjY);
		end
		WorldMapFrame.areaName = name;
		if not WorldMapFrame.poiHighlight then
			WorldMapFrameAreaLabel:SetText(name);
		end
		if fileName then
			WorldMapHighlight:SetTexCoord(0, tpx, 0, tpy);
			WorldMapHighlight:SetTexture("Interface\\WorldMap\\" .. fileName .. "\\" .. fileName .. "Highlight");
			tx = tx * w;
			ty = ty * h;
			scx = scx * w;
			scy = -scy * h;
			if (tx > 0) and (ty > 0) then
				WorldMapHighlight:SetWidth(tx);
				WorldMapHighlight:SetHeight(ty);
				WorldMapHighlight:SetPoint("TOPLEFT", "WorldMapDetailFrame", "TOPLEFT", scx, scy);
				WorldMapHighlight:Show();
			end
		else
			WorldMapHighlight:Hide();
		end
	end);

	QUESTMAP_WORLDMAP_ATTACHED = true;
	local _qa = QM_Nav_GetAstrolabe and QM_Nav_GetAstrolabe();
	if _qa then _qa.WorldMapVisible = true; end
	WorldMapFrame_Update();
	QM_UpdateMapPOIs();

	local wmbStrata = WorldMapButton:GetFrameStrata();
	local wmbLevel  = WorldMapButton:GetFrameLevel();
	local sc = QuestMapFrame._mapScrollChild;
	for _, pm in ipairs(QM_poiPool) do
		if pm:GetParent() == sc then
			pm:SetFrameStrata(wmbStrata);
			pm:SetFrameLevel(wmbLevel + 5);
		end
	end
	if WorldMapPOIFrame then
		WorldMapPOIFrame:SetFrameStrata(wmbStrata);
		WorldMapPOIFrame:SetFrameLevel(wmbLevel + 10);
	end
	QM_RaiseMapOverlayControls();

	QM_SyncNavBar(nil);
end

QM_SelectQuestEntry = function(logIdx, questID)
	if not logIdx or logIdx == 0 then return; end
	if not questID then
		questID = select(9, GetQuestLogTitle(logIdx));
	end
	if QuestMap_SelectedQuest and QuestMap_SelectedQuest ~= logIdx then
		local prevQuestID = select(9, GetQuestLogTitle(QuestMap_SelectedQuest));
		if prevQuestID and prevQuestID ~= 0 then
			WorldMapBlobFrame:DrawQuestBlob(prevQuestID, false);
		end
	end
	QuestMap_SelectedQuest = logIdx;
	if WORLDMAP_SETTINGS then
		WORLDMAP_SETTINGS.selectedQuestId = questID or 0;
	end
	SelectQuestLogEntry(logIdx);
	QuestMapFrame_UpdateQuestList();
	if questID and questID ~= 0 then
		local _, _, _, _, _, _, isComplete = GetQuestLogTitle(logIdx);
		if not isComplete or isComplete <= 0 then
			WorldMapBlobFrame:DrawQuestBlob(questID, true);
			WorldMapBlobFrame:Show();
		end
	end
	if WatchFrame and WatchFrame:IsShown() then
		WatchFrame_Update();
	end
end

function QuestMapFrame_DetachWorldMap()
	if not QUESTMAP_WORLDMAP_ATTACHED then return; end

	WorldMapDetailFrame:SetParent(WorldMapFrame);
	WorldMapDetailFrame:ClearAllPoints();
	WorldMapDetailFrame:SetScale(WORLDMAP_QUESTLIST_SIZE);
	WorldMapDetailFrame:SetPoint("TOPLEFT", WorldMapPositioningGuide, "TOP", -726, -99);

	WorldMapButton:SetParent(WorldMapFrame);
	WorldMapButton:SetScale(WORLDMAP_QUESTLIST_SIZE);

	if QM_savedWMBOnUpdate then
		WorldMapButton:SetScript("OnUpdate", QM_savedWMBOnUpdate);
	end

	WorldMapBlobFrame:SetParent(WorldMapFrame);
	WorldMapBlobFrame:SetScale(WORLDMAP_QUESTLIST_SIZE);
	WorldMapBlobFrame.xRatio = nil;

	WorldMapPOIFrame:SetParent(WorldMapFrame);
	WorldMapPOIFrame:SetScale(1.0);
	WorldMapPOIFrame:ClearAllPoints();
	WorldMapPOIFrame:SetPoint("TOPLEFT", WorldMapDetailFrame, "TOPLEFT", 0, 0);

	WorldMapFrame_SetPOIMaxBounds();

	WorldMap_ClearTextures();
	QM_SetCompletedPOICircles(false);

	for _, pm in ipairs(QM_poiPool) do
		pm:Hide();
		pm:SetParent(QuestMapFrame);
	end

	if QuestMapFrame._playerArrow then
		QuestMapFrame._playerArrow:Hide();
	end

	QM_MapPin_Detach();

	WorldMapPOIFrame:SetFrameStrata("FULLSCREEN_DIALOG");

	QUESTMAP_WORLDMAP_ATTACHED = false;
	local _qa = QM_Nav_GetAstrolabe and QM_Nav_GetAstrolabe();
	if _qa then _qa.WorldMapVisible = false; end
	QM_zoomLevel  = 1.0;
	QM_isDragging = false;
	if QuestMapFrame._mapScroller then
		QuestMapFrame._mapScroller:SetHorizontalScroll(0);
		QuestMapFrame._mapScroller:SetVerticalScroll(0);
	end
	if QuestMapFrame._mapScrollChild then
		QuestMapFrame._mapScrollChild:SetSize(QUESTMAP_MAP_WIDTH, QUESTMAP_MAP_HEIGHT);
	end
end

function QuestMapFrame_ShowQuestDetails(logIdx, questID)
	if not logIdx or logIdx == 0 then return; end
	QuestMapFrame.questListPanel:Hide();
	QuestMapFrame.questDetailsPanel:Show();
	QM_SelectQuestEntry(logIdx, questID);
end

function QuestMapFrame_HideQuestDetails()
	QuestMapFrame.questDetailsPanel:Hide();
	QuestMapFrame.questListPanel:Show();
	QuestMapFrame_UpdateQuestList();
end

-- ── Toggle del panel derecho (lista de misiones + detalles) ──────────────
function QuestMapFrame_UpdatePanelToggleIcon()
	local button = QuestMapFrame.panelToggleButton;
	if not button then return; end

	if QuestMapFrame.rightPanelHidden then
		button:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up");
		button:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down");
		button:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Disabled");
	else
		button:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up");
		button:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down");
		button:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Disabled");
	end

	if GameTooltip:IsShown() and GameTooltip:GetOwner() == button then
		GameTooltip:SetText(QuestMapFrame.rightPanelHidden and SHOW_QUEST_LIST or HIDE_QUEST_LIST, 1, 1, 1);
	end
end

function QuestMapFrame_SetPanelCollapsed(collapsed, skipRestore)
	if not QuestMapFrame.panelToggleButton then return; end
	if QuestMapFrame.rightPanelHidden == collapsed then return; end
	QuestMapFrame.rightPanelHidden = collapsed;

	if collapsed then
		-- Recordamos si se estaban viendo los detalles para poder restaurarlos al expandir
		QuestMapFrame._panelWasShowingDetails =
			QuestMapFrame.questDetailsPanel and QuestMapFrame.questDetailsPanel:IsShown();

		QuestMapFrame.questListPanel:Hide();
		QuestMapFrame.questDetailsPanel:Hide();
		QuestMapFrame:SetWidth(QM_FRAME_WIDTH_COMPACT);
	else
		QuestMapFrame:SetWidth(QM_FRAME_WIDTH_FULL);

		if not skipRestore then
			if QuestMapFrame._panelWasShowingDetails and QuestMap_SelectedQuest and QuestMap_SelectedQuest ~= 0 then
				QuestMapFrame.questListPanel:Hide();
				QuestMapFrame.questDetailsPanel:Show();
				QuestMapFrame_UpdateQuestDetail();
			else
				QuestMapFrame.questDetailsPanel:Hide();
				QuestMapFrame.questListPanel:Show();
				QuestMapFrame_UpdateQuestList();
			end
		end
	end

	QuestMapFrame_UpdatePanelToggleIcon();
end

function QuestMapFrame_TogglePanel()
	QuestMapFrame_SetPanelCollapsed(not QuestMapFrame.rightPanelHidden);
end

function QuestMapFrame_UpdateQuestList()
	if not QuestMapFrame:IsShown() then return; end

	local wasPendingFromWorldMap = (QuestMap_PendingFromWorldMap and QuestMap_PendingFromWorldMap ~= 0) and true or false;
	if wasPendingFromWorldMap then
		local pending = QuestMap_PendingFromWorldMap;
		QuestMap_PendingFromWorldMap = nil;
		local n = GetNumQuestLogEntries();
		for i = 1, n do
			local t, _, _, _, isHdr = GetQuestLogTitle(i);
			if t and not isHdr then
				if select(9, GetQuestLogTitle(i)) == pending then
					QuestMap_SelectedQuest = i;
					SelectQuestLogEntry(i);
					break;
				end
			end
		end
	end

	local listPanel   = QuestMapFrame.questListPanel;
	local scrollFrame = listPanel.scrollFrame;
	local scrollChild = scrollFrame:GetScrollChild();
	local searchBox   = listPanel.searchBox;
	if not scrollChild or not searchBox then return; end

	qmPoolReset(qm_oAll);
	qmPoolReset(qm_zHdrs);
	qmPoolReset(qm_qRows);

	local rawText = searchBox:GetText() or "";
	local filter  = (rawText == searchBox.placeholder) and "" or rawText:lower();

	local y = 0;
	local function placeAt(f, h)
		f:ClearAllPoints();
		f:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, y);
		y = y - h;
	end

	local numEntries = GetNumQuestLogEntries();
	local zoneCollapsed = false;
	local currentZone   = "";

	for i = 1, numEntries do
		local title, level, _, _, isHeader, isCollapsed, isComplete, _, questID = GetQuestLogTitle(i);
		if title then
			if isHeader then
				currentZone = title;
				zoneCollapsed = (isCollapsed == 1 or QuestMap_CollapsedZones[title]) and true or false;

				local hasMatch = false;
				for k = i + 1, numEntries do
					local ct, _, _, _, cIsHdr = GetQuestLogTitle(k);
					if cIsHdr then break; end
					if ct and (filter == "" or ct:lower():find(filter, 1, true)) then
						hasMatch = true; break;
					end
				end

				if hasMatch then
					local zBtn = qmPoolGet(qm_zHdrs, QM_MakeZoneHdr, scrollChild);
					zBtn.text:SetText(title);
					zBtn.text:SetTextColor(0.90, 0.75, 0.35);
					zBtn.arrow:SetText(zoneCollapsed and "+" or "-");
					local zoneName = title;
					zBtn:SetScript("OnClick", function()
						if QuestMap_CollapsedZones[zoneName] then
							QuestMap_CollapsedZones[zoneName] = nil;
							PlaySound("gsTitleOption16bit");
						else
							QuestMap_CollapsedZones[zoneName] = true;
							PlaySound("gsTitleOption32bit");
						end
						QuestMapFrame_UpdateQuestList();
					end);
					placeAt(zBtn, QM_H_ZONE);
				end
			else
				if not zoneCollapsed then
					if filter == "" or title:lower():find(filter, 1, true) then
						local watched = IsQuestWatched(i);
						local qBtn = qmPoolGet(qm_qRows, QM_MakeQuestRow, scrollChild);
						if QuestMap_SelectedQuest == i then
							qBtn.text:SetTextColor(1, 1, 1);
						elseif watched then
							qBtn.text:SetTextColor(1, 0.82, 0);
						else
							qBtn.text:SetTextColor(0.5, 0.5, 0.5);
						end
						local levelPfx = (level and level > 0) and ("["..level.."] ") or "";
						qBtn.text:SetText(levelPfx .. title);
						qBtn.checkbox:SetChecked(watched and true or false);
						local capturedI      = i;
						local capturedZone   = currentZone;
						local capturedQuestID = questID;

						qBtn.pin.num:SetText("");
						local isNavRow = (QM_navQuestLogIdx == i);
						if isNavRow then
							qBtn.pin.bg:SetTexture("Interface\\MINIMAP\\MinimapArrow");
							qBtn.pin.bg:SetTexCoord(0, 1, 0, 1);
							qBtn.pin.bg:SetVertexColor(0.3, 1.0, 0.55);
							qBtn.pin:SetScript("OnUpdate", function(self)
								local s = 12 + 3 * math.abs(math.sin(GetTime() * 3));
								self:SetSize(s, s);
							end);
						elseif QuestMap_SelectedQuest == i then
							qBtn.pin.bg:SetTexture("Interface\\WorldMap\\UI-QuestPoi-NumberIcons");
							qBtn.pin.bg:SetTexCoord(0.500, 0.625, 0.875, 1.0);
							qBtn.selHl:Show();
							qBtn.pin.bg:SetVertexColor(1, 0.88, 0);
							qBtn.pin:SetScript("OnUpdate", function(self)
								local s = 12 + 5 * math.abs(math.sin(GetTime() * 4));
								self:SetSize(s, s);
							end);
						else
							qBtn.pin.bg:SetTexture("Interface\\WorldMap\\UI-QuestPoi-NumberIcons");
							qBtn.pin.bg:SetTexCoord(0.500, 0.625, 0.875, 1.0);
							qBtn.selHl:Hide();
							qBtn.pin.bg:SetVertexColor(0.55, 0.44, 0);
							qBtn.pin:SetScript("OnUpdate", nil);
							qBtn.pin:SetSize(12, 12);
						end

						qBtn:SetScript("OnClick", function(self, button)
							if button == "RightButton" then
								QM_ShowContextMenu(capturedI, title, self);
								return;
							end
							PlaySound("igQuestListSelect");
							QuestMap_SelectedZone = capturedZone;
							QuestMapFrame_ShowQuestDetails(capturedI, capturedQuestID);
							QM_NavigateToQuest(capturedQuestID);
						end);

						qBtn:SetScript("OnEnter", function(self)
							if capturedQuestID and capturedQuestID ~= 0
									and QuestMap_SelectedQuest ~= capturedI then
								local _, _, _, _, _, _, complete = GetQuestLogTitle(capturedI);
								if not complete or complete <= 0 then
									WorldMapBlobFrame:DrawQuestBlob(capturedQuestID, true);
									WorldMapBlobFrame:Show();
								end
							end
						end);
						qBtn:SetScript("OnLeave", function(self)
							if capturedQuestID and capturedQuestID ~= 0
									and QuestMap_SelectedQuest ~= capturedI then
								WorldMapBlobFrame:DrawQuestBlob(capturedQuestID, false);
								if QuestMap_SelectedQuest and QuestMap_SelectedQuest ~= 0 then
									local selectedID = select(9, GetQuestLogTitle(QuestMap_SelectedQuest));
									local _, _, _, _, _, _, selectedComplete =
										GetQuestLogTitle(QuestMap_SelectedQuest);
									if selectedID and selectedID ~= 0
											and (not selectedComplete or selectedComplete <= 0) then
										WorldMapBlobFrame:DrawQuestBlob(selectedID, true);
										WorldMapBlobFrame:Show();
									end
								end
							end
						end);

						qBtn.checkbox:SetScript("OnClick", function(self)
							local nowWatched = IsQuestWatched(capturedI);
							if nowWatched then
								RemoveQuestWatch(capturedI);
								PlaySound("igMainMenuOptionCheckBoxOff");
							else
								if GetNumQuestWatches and MAX_WATCHABLE_QUESTS
										and GetNumQuestWatches() >= MAX_WATCHABLE_QUESTS then
									self:SetChecked(false);
									if UIErrorsFrame then
										UIErrorsFrame:AddMessage(ERR_QUEST_WATCH_TOO_MANY, 1.0, 0.1, 0.1, 1.0);
									end
									return;
								end
								AddQuestWatch(capturedI);
								PlaySound("igMainMenuOptionCheckBoxOn");
							end

							if WatchFrame_Update then WatchFrame_Update(); end
							if QuestLog_Update then QuestLog_Update(); end
							QM_UpdateMapPOIs();
							QuestMapFrame_UpdateQuestList();
						end);

						qBtn.checkbox:SetScript("OnEnter", function(self)
							GameTooltip:SetOwner(self, "ANCHOR_LEFT");
							if IsQuestWatched(capturedI) then
								GameTooltip:SetText(UNTRACK_QUEST);
							else
								GameTooltip:SetText(TRACK_QUEST);
							end
							GameTooltip:Show();
						end);
						qBtn.checkbox:SetScript("OnLeave", function()
							GameTooltip:Hide();
						end);
						placeAt(qBtn, QM_H_QUEST);

						if watched then
							local numObj = GetNumQuestLeaderBoards(i);
							for j = 1, numObj do
								local objText, _, finished = GetQuestLogLeaderBoard(j, i);
								if objText and objText ~= "" then
									local objRow = qmPoolGet(qm_oAll, QM_MakeObjLine, scrollChild);
									objRow.text:SetText("  - " .. objText);
									objRow.text:SetTextColor(0.75, 0.75, 0.75);
									local objRowH = math.max(QM_H_OBJ, math.ceil(objRow.text:GetStringHeight() or QM_H_OBJ) + 2);
									objRow:SetHeight(objRowH);
									placeAt(objRow, objRowH);
								end
							end
						end
					end
				end
			end
		end
	end

	local totalH = math.abs(y);
	scrollChild:SetHeight(totalH > 0 and totalH or 1);
	scrollFrame:SetVerticalScroll(0);

	if not QuestMap_SelectedQuest or QuestMap_SelectedQuest == 0 then
		local numEntries = GetNumQuestLogEntries();
		for i = 1, numEntries do
			local t, _, _, _, isHdr = GetQuestLogTitle(i);
			if t and not isHdr then
				QuestMap_SelectedQuest = i;
				SelectQuestLogEntry(i);
				break;
			end
		end
	end

	if QUESTMAP_WORLDMAP_ATTACHED then
		local selQuestID = QuestMap_SelectedQuest and QuestMap_SelectedQuest ~= 0
		                   and select(9, GetQuestLogTitle(QuestMap_SelectedQuest));
		if wasPendingFromWorldMap and selQuestID and selQuestID ~= 0 then
			QM_NavigateToQuest(selQuestID);
		elseif not (QuestMap_SelectedQuest and QuestMap_SelectedQuest ~= 0) then
			SetMapToCurrentZone();
			local px, py = GetPlayerMapPosition("player");
			if px and py and not (px == 0 and py == 0) then
				WorldMapFrame_Update();
				QM_UpdateMapPOIs();
				QM_SyncNavBar(nil);
			else
				local fb = GetNumQuestLogEntries();
				for fi = 1, fb do
					local _, _, _, _, fiHdr = GetQuestLogTitle(fi);
					if not fiHdr then
						local fqID = select(9, GetQuestLogTitle(fi));
						if fqID and fqID ~= 0 then QM_NavigateToQuest(fqID); break; end
					end
				end
			end
		else
			WorldMapFrame_Update();
			QM_UpdateMapPOIs();
			QM_SyncNavBar(nil);
		end
	end

	QuestMapFrame_UpdateQuestDetail();
end

function QuestMapFrame_UpdateQuestDetail()
	if not QuestMapFrame:IsShown() then return; end
	local detailsPanel = QuestMapFrame.questDetailsPanel;
	if not detailsPanel or not detailsPanel:IsShown() then return; end
	local leftPanel  = detailsPanel.questDetailLeft;
	local rightPanel = detailsPanel.questDetailRight;
	if not leftPanel or not rightPanel then return; end

	if not QuestMap_SelectedQuest or QuestMap_SelectedQuest == 0 then return; end

	SelectQuestLogEntry(QuestMap_SelectedQuest);

	-- Sincronizar el estado del checkbox TrackQuest en el panel de detalles
	if detailsPanel.trackQuest then
		detailsPanel.trackQuest:SetChecked(IsQuestWatched(QuestMap_SelectedQuest) and true or false);
	end

	local leftSF  = leftPanel.scrollFrame;
	local rightSF = rightPanel.scrollFrame;
	local leftChild  = leftSF:GetScrollChild();
	local rightChild = rightSF:GetScrollChild();

	if not leftChild or not rightChild then return; end

	QuestInfo_Display(QUEST_TEMPLATE_MAP1, leftChild);
	leftSF:SetVerticalScroll(0);

	local _leftChild = leftChild;
	local _leftSF    = leftSF;
	local _resizer   = CreateFrame("Frame");
	_resizer:SetScript("OnUpdate", function(self)
		self:SetScript("OnUpdate", nil);
		local top    = _leftChild:GetTop();
		local bottom = QuestInfoSpacerFrame:GetBottom();
		if top and bottom then
			_leftChild:SetHeight(math.max(top - bottom + 12, 20));
		end
		ScrollFrame_OnScrollRangeChanged(_leftSF);
	end);

	QuestInfo_Display(QUEST_TEMPLATE_MAP2, rightChild);
	QuestInfoFrame.tooltip = "GameTooltip";

	-- Título "Rewards" en blanco, conservando su sombreado amarillo original
	if QuestInfoRewardsHeader then
		QuestInfoRewardsHeader:SetTextColor(1, 1, 1);
	end

	QuestInfoReputationsFrame:SetParent(rightChild);
	local repBottom = QuestInfo_DoReputations(QuestInfoAnchor);

	-- Textos de reputación (dentro de Rewards) en blanco con sombreado negro,
	-- para que se lean sobre el panel oscuro. No afecta a las descripciones de misión.
	do
		local QM_MAX_REP = MAX_REPUTATIONS or 10;
		if QuestInfoReputationText then
			QuestInfoReputationText:SetTextColor(1, 1, 1);
			QuestInfoReputationText:SetShadowColor(0, 0, 0, 1);
			QuestInfoReputationText:SetShadowOffset(1, -1);
		end
		for QM_repIdx = 1, QM_MAX_REP do
			local QM_repFaction = _G["QuestInfoReputation"..QM_repIdx.."Faction"];
			local QM_repAmount  = _G["QuestInfoReputation"..QM_repIdx.."Amount"];
			if QM_repFaction then
				QM_repFaction:SetTextColor(1, 1, 1);
				QM_repFaction:SetShadowColor(0, 0, 0, 1);
				QM_repFaction:SetShadowOffset(1, -1);
			end
			if QM_repAmount then
				QM_repAmount:SetTextColor(1, 1, 1);
				QM_repAmount:SetShadowColor(0, 0, 0, 1);
				QM_repAmount:SetShadowOffset(1, -1);
			end
		end
	end

	local _rightChild = rightChild;
	local _rightSF    = rightSF;
	local _bottomRef  = repBottom;
	local _resizerR   = CreateFrame("Frame");
	_resizerR:SetScript("OnUpdate", function(self)
		self:SetScript("OnUpdate", nil);
		local top    = _rightChild:GetTop();
		local bottom = _bottomRef:GetBottom();
		if top and bottom then
			_rightChild:SetHeight(math.max(top - bottom + 12, 20));
		end
		ScrollFrame_OnScrollRangeChanged(_rightSF);
	end);

	rightSF:SetVerticalScroll(0);
	ScrollFrame_OnScrollRangeChanged(rightSF);
end

local QM_origQuestPOI_OnClick  = WorldMapQuestPOI_OnClick;
local QM_origQuestPOI_OnEnter = WorldMapQuestPOI_OnEnter;
local QM_origQuestPOI_OnLeave = WorldMapQuestPOI_OnLeave;

function WorldMapQuestPOI_OnClick(self)
	if not (QUESTMAP_WORLDMAP_ATTACHED and QuestMapFrame:IsShown()) then
		QM_origQuestPOI_OnClick(self); return;
	end
	local quest = self.quest;
	if not quest or not quest.questLogIndex then return; end
	PlaySound("igMainMenuOptionCheckBoxOn");
	QM_SelectQuestEntry(quest.questLogIndex, quest.questId);
end

function WorldMapQuestPOI_OnEnter(self)
	if not (QUESTMAP_WORLDMAP_ATTACHED and QuestMapFrame:IsShown()) then
		QM_origQuestPOI_OnEnter(self);
		return;
	end
	WorldMapPOIFrame.allowBlobTooltip = false;
	local quest = self.quest;
	if not quest or not quest.questLogIndex then return; end
	local logIdx = quest.questLogIndex;
	local title = GetQuestLogTitle(logIdx);
	if not title then return; end
	GameTooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT");
	GameTooltip:SetText(title, 1, 0.82, 0);
	if self.type == QUEST_POI_COMPLETE_SWAP then
		local completeText = GetQuestLogCompletionText(logIdx);
		if completeText and completeText ~= "" then
			GameTooltip:AddLine(completeText, 1, 1, 1, true);
		end
	else
		local numObj = GetNumQuestLeaderBoards(logIdx);
		for i = 1, numObj do
			local text, _, finished = GetQuestLogLeaderBoard(i, logIdx);
			if text and text ~= "" then
				if finished then
					GameTooltip:AddLine("  - "..text, 0.5, 0.8, 0.5, true);
				else
					GameTooltip:AddLine("  - "..text, 1, 1, 1, true);
				end
			end
		end
	end
	GameTooltip:Show();
end

function WorldMapQuestPOI_OnLeave(self)
	if not (QUESTMAP_WORLDMAP_ATTACHED and QuestMapFrame:IsShown()) then
		QM_origQuestPOI_OnLeave(self);
		return;
	end
	WorldMapPOIFrame.allowBlobTooltip = true;
	GameTooltip:Hide();
end

function QuestLog_OpenToQuest(questIndex, keepOpen)
	if not questIndex or questIndex == 0 then return; end
	local numEntries = GetNumQuestLogEntries();
	if questIndex < 1 or questIndex > numEntries then return; end
	local questID = select(9, GetQuestLogTitle(questIndex));
	QuestMap_SelectedQuest = questIndex;
	SelectQuestLogEntry(questIndex);
	if not QuestMapFrame:IsShown() then
		ShowUIPanel(QuestMapFrame);
	else
		QM_SelectQuestEntry(questIndex, questID);
	end
end