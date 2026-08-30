-- QuestMap_MapPin.lua
-- Persistent map pin for the QuestMap addon.
-- Loaded before QuestMap.lua; all public symbols are globals so QuestMap.lua
-- can reference them during QuestMapFrame_OnLoad and event handlers.
--
-- Public API used by QuestMap.lua:
--   QM_MapPin_InitButton(qmf, locBtn)     -- create toolbar button
--   QM_MapPin_InitMarker(qmf)             -- create viewport-space pin frame
--   QM_MapPin_PlaceAtCursor()             -- called from WorldMapButton OnMouseDown
--   QM_MapPin_OnUpdate(qmf)              -- called every frame from QuestMapFrame OnUpdate
--   QM_MapPin_Detach()                   -- called from QuestMapFrame_DetachWorldMap

-- ── State (globals so QuestMap.lua can read QM_mapPinMode) ────────────────────
QM_mapPinMode = false;   -- true while waiting for the next map left-click
QM_mapPin     = nil;     -- nil | { continent, zone, dungeonLevel, fx, fy, zoneName }

-- True while built-in navigation is active (drives the pin glow loop).
QM_mapPinNavigating = false;   -- global so QM_NavArrow.lua can reset it

-- Lazily-built context menu widgets.
local QM_mapPinMenu   = nil;
local QM_mapPinMenuBD = nil;

-- ── Addon-message relay + SAY/YELL intercept ─────────────────────────────────
-- SendChatMessage strips |H pipe codes server-side, so we send two messages:
--   1) Plain-text SAY/PARTY/RAID so everyone sees the coords (no addon required).
--   2) SendAddonMessage with full data for party/raid members who have QuestMap
--      (they get a clickable [Map Pin] link injected into their chat frame).
--
-- For SAY/YELL there is no valid SendAddonMessage distribution, so we instead
-- hook CHAT_MSG_SAY/YELL and re-render any "Map Pin: Name (X, Y)" message that
-- arrives as a clickable link (works for both sender and receiver if they have
-- the addon, no extra network message needed).
local QM_PIN_PREFIX = "QMAP_PIN";

-- Shared helper: build a clickable link from raw parts (no QM_mapPin needed).
local function QM_MakeLinkFromParts(cont, zone, dl, fxI, fyI, zoneName)
	local xPct = math.floor(fxI / 100 + 0.5);
	local yPct = math.floor(fyI / 100 + 0.5);
	return string.format(
		"|cff4fc3f7|Hqmpin:%d:%d:%d:%d:%d|h[Map Pin: %s (%d, %d)]|h|r",
		cont, zone, dl, fxI, fyI, zoneName, xPct, yPct);
end

-- Parse a plain-text "Map Pin: Name (X, Y)" into a clickable link.
-- Uses the *current* map state to fill in cont/zone/dl (best effort for SAY).
local function QM_MakeLinkFromPlainText(plain)
	-- plain = "Map Pin: ZoneName (71, 75)"
	local zoneName, xStr, yStr = plain:match("^Map Pin: (.+) %((%d+), (%d+)%)$");
	if not zoneName then return nil end;
	-- fxI/fyI from the percentage strings (lose sub-percent precision, acceptable for SAY)
	local fxI = tonumber(xStr) * 100;
	local fyI = tonumber(yStr) * 100;
	local cont = GetCurrentMapContinent() or 0;
	local zone = GetCurrentMapZone() or 0;
	local dl   = GetCurrentMapDungeonLevel() or 0;
	return QM_MakeLinkFromParts(cont, zone, dl, fxI, fyI, zoneName), cont, zone, dl, fxI, fyI, zoneName;
end

-- Inject a clickable link line into DEFAULT_CHAT_FRAME.
local function QM_InjectPinLink(sender, cont, zone, dl, fxI, fyI, zoneName)
	if not DEFAULT_CHAT_FRAME then return; end
	local link = QM_MakeLinkFromParts(cont, zone, dl, fxI, fyI, zoneName);
	local label = (sender == UnitName("player")) and "|cffffff78You|r" or ("|cffffff78" .. sender .. "|r");
	DEFAULT_CHAT_FRAME:AddMessage(label .. " pinned: " .. link);
end

-- Chat events we intercept to inject clickable links on both sender and receiver.
local QM_CHAT_EVENTS = {
	"CHAT_MSG_SAY", "CHAT_MSG_YELL",
	"CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
	"CHAT_MSG_RAID",  "CHAT_MSG_RAID_LEADER",  "CHAT_MSG_RAID_WARNING",
	"CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
	"CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM",
	"CHAT_MSG_BATTLEGROUND", "CHAT_MSG_CHANNEL",
};

local QM_pinMsgFrame = CreateFrame("Frame");
QM_pinMsgFrame:RegisterEvent("CHAT_MSG_ADDON");
for _, ev in ipairs(QM_CHAT_EVENTS) do
	QM_pinMsgFrame:RegisterEvent(ev);
end

-- Build a quick lookup so the OnEvent handler doesn't iterate the list.
local QM_CHAT_EVENT_SET = {};
for _, ev in ipairs(QM_CHAT_EVENTS) do QM_CHAT_EVENT_SET[ev] = true; end

QM_pinMsgFrame:SetScript("OnEvent", function(self, event, arg1, arg2, arg3, arg4)
	if event == "CHAT_MSG_ADDON" then
		local prefix, data, distribution, sender = arg1, arg2, arg3, arg4;
		if prefix ~= QM_PIN_PREFIX then return; end
		if sender == UnitName("player") then return; end  -- we already showed our own
		local cont, zone, dl, fxI, fyI, zoneName =
			data:match("^(-?%d+):(-?%d+):(-?%d+):(%d+):(%d+):(.+)$");
		if not cont then return; end
		QM_InjectPinLink(sender,
			tonumber(cont), tonumber(zone), tonumber(dl),
			tonumber(fxI),  tonumber(fyI),  zoneName);

	elseif QM_CHAT_EVENT_SET[event] then
		-- arg1 = message text, arg2 = sender name (arg4 for CHANNEL is channel number — ignored)
		local msg, sender = arg1, arg2;
		if not msg or not msg:match("^Map Pin: .+ %(%d+, %d+%)$") then return; end
		local link, cont, zone, dl, fxI, fyI, zoneName = QM_MakeLinkFromPlainText(msg);
		if link then
			QM_InjectPinLink(sender, cont, zone, dl, fxI, fyI, zoneName);
		end
	end
end);

-- (Navigation state managed by QM_NavArrow.lua via QM_Nav_Start / QM_Nav_Stop)

-- ── Chat-link support ─────────────────────────────────────────────────────────
-- Link format: |Hqmpin:C:Z:DL:FX:FY|h[Map Pin: ZoneName (X, Y)]|h
--   C/Z/DL = integers; FX/FY = fx/fy * 10000 (4 decimal places of precision).
--
-- When another player with the addon clicks the link their pin is placed at
-- the encoded coordinates.  We hook SetItemRef to intercept the qmpin type.

local function QM_MapPin_MakeLink()
	if not QM_mapPin then return nil; end
	local p    = QM_mapPin;
	local fxI  = math.floor(p.fx * 10000 + 0.5);
	local fyI  = math.floor(p.fy * 10000 + 0.5);
	local xPct = math.floor(p.fx * 100 + 0.5);
	local yPct = math.floor(p.fy * 100 + 0.5);
	local data = string.format("qmpin:%d:%d:%d:%d:%d",
		p.continent, p.zone, p.dungeonLevel, fxI, fyI);
	local disp = string.format("Map Pin: %s (%d, %d)", p.zoneName, xPct, yPct);
	-- |cff4fc3f7 = light-blue, same style as spell links; |r resets color after |h.
	return string.format("|cff4fc3f7|H%s|h[%s]|h|r", data, disp);
end

-- Called when a qmpin link is clicked in chat.
local function QM_MapPin_HandleChatLink(link, text)
	-- link  = "qmpin:C:Z:DL:FX:FY"
	-- text  = "[Map Pin: ZoneName (X, Y)]"  (includes brackets)
	local cont, zone, dlevel, fxI, fyI =
		link:match("^qmpin:(-?%d+):(-?%d+):(-?%d+):(%d+):(%d+)$");
	if not cont then return; end
	cont, zone, dlevel, fxI, fyI =
		tonumber(cont), tonumber(zone), tonumber(dlevel), tonumber(fxI), tonumber(fyI);
	local fx = fxI / 10000;
	local fy = fyI / 10000;
	-- Extract zone name from the display text  "[Map Pin: ZoneName (X, Y)]"
	local zoneName = text:match("%[Map Pin: (.+) %(%d+, %d+%)%]") or "Unknown";
	QM_mapPin = {
		continent    = cont,
		zone         = zone,
		dungeonLevel = dlevel,
		fx           = fx,
		fy           = fy,
		zoneName     = zoneName,
	};
	local xPct = math.floor(fx * 100 + 0.5);
	local yPct = math.floor(fy * 100 + 0.5);
	print(string.format(
		"|cffffff78QuestMap:|r Map Pin set: |cff00ff00%s|r (%d, %d).",
		zoneName, xPct, yPct));
	-- Open QuestMap and navigate to the pin's zone.
	if QM_MapPin_OpenAndNavigate then
		QM_MapPin_OpenAndNavigate(cont, zone);
	end;
end

-- Global hook on SetItemRef so any chat frame can dispatch qmpin links.
local _orig_SetItemRef = SetItemRef;
function SetItemRef(link, text, button, chatFrame)
	if link:sub(1, 5) == "qmpin" then
		QM_MapPin_HandleChatLink(link, text);
		return;
	end
	if _orig_SetItemRef then
		_orig_SetItemRef(link, text, button, chatFrame);
	end
end

-- ── Navigation ───────────────────────────────────────────────────────────────
local function QM_MapPin_Navigate()
	if not QM_mapPin then return; end
	-- Stop any prior navigation first.
	if QM_mapPinNavigating then
		if QM_Nav_Stop then QM_Nav_Stop(false); end
	end
	QM_mapPinNavigating = true;
	-- Start glow on the map-pin marker.
	local pinF = QuestMapFrame and QuestMapFrame._mapPinFrame;
	if pinF then
		pinF._glowAlpha = 1;
		pinF._glowDir   = -1;
		pinF._glow:SetAlpha(1);
		pinF._glow:Show();
	end
	-- Delegate to the built-in navigation system (QM_NavArrow.lua).
	if QM_Nav_Start then
		QM_Nav_Start();
	end
end

-- ── Context menu ─────────────────────────────────────────────────────────────
local function QM_MapPin_BuildMenu()
	-- Full-screen click-dismisser
	local bd = CreateFrame("Frame", nil, UIParent);
	bd:SetAllPoints(UIParent);
	bd:SetFrameStrata("DIALOG");
	bd:EnableMouse(true);
	bd:SetScript("OnMouseDown", function()
		bd:Hide();
		if QM_mapPinMenu then QM_mapPinMenu:Hide(); end
	end);
	bd:Hide();
	QM_mapPinMenuBD = bd;

	local f = CreateFrame("Frame", "QuestMapPinContextMenu", UIParent);
	-- 3 buttons: Navigate, Remove, Share  (22px each + gaps + title + divider)
	f:SetSize(152, 120);
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

	-- Gold zone-name title
	local titleStr = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	titleStr:SetPoint("TOPLEFT",  f, "TOPLEFT",  6, -6);
	titleStr:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6);
	titleStr:SetHeight(14);
	titleStr:SetJustifyH("CENTER");
	titleStr:SetTextColor(1, 0.82, 0);
	f.title = titleStr;

	-- Coords sub-label (grey, smaller)
	local coordStr = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	coordStr:SetPoint("TOPLEFT",  titleStr, "BOTTOMLEFT",  0, -1);
	coordStr:SetPoint("TOPRIGHT", titleStr, "BOTTOMRIGHT", 0, -1);
	coordStr:SetHeight(12);
	coordStr:SetJustifyH("CENTER");
	coordStr:SetTextColor(0.65, 0.65, 0.65);
	f.coords = coordStr;

	-- Thin gold divider
	local divider = f:CreateTexture(nil, "ARTWORK");
	divider:SetTexture(0.55, 0.44, 0.1, 0.7);
	divider:SetHeight(1);
	divider:SetPoint("LEFT",  f, "LEFT",  4, 0);
	divider:SetPoint("RIGHT", f, "RIGHT", -4, 0);
	divider:SetPoint("TOP", coordStr, "BOTTOM", 0, -3);

	local function makeBtn(label, r, g, b)
		local btn = CreateFrame("Button", nil, f);
		btn:SetSize(140, 20);
		local hl = btn:CreateTexture(nil, "HIGHLIGHT");
		hl:SetTexture("Interface\\QuestFrame\\UI-QuestLogHighlight");
		hl:SetBlendMode("ADD");
		hl:SetAllPoints(btn);
		local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
		lbl:SetAllPoints(btn);
		lbl:SetJustifyH("CENTER");
		lbl:SetText(label);
		lbl:SetTextColor(r, g, b);
		return btn;
	end

	-- Navigate via TomTom
	local navBtn = makeBtn("Navigate", 0.4, 1.0, 0.5);
	navBtn:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", -2, -3);
	navBtn:SetScript("OnClick", function()
		QM_mapPinMenuBD:Hide();
		f:Hide();
		QM_MapPin_Navigate();
	end);
	navBtn:SetScript("OnEnter", function(btn)
		GameTooltip:SetOwner(btn, "ANCHOR_RIGHT");
		GameTooltip:SetText("Navigate to Pin", 1, 1, 1);
		GameTooltip:AddLine("Shows a HUD direction arrow pointing toward the pin.", 0.7, 0.7, 0.7, true);
		GameTooltip:AddLine("Also places a blip on the minimap (requires Astrolabe).", 0.5, 0.5, 0.5, true);
		GameTooltip:Show();
	end);
	navBtn:SetScript("OnLeave", function() GameTooltip:Hide(); end);

	-- Remove Pin
	local removeBtn = makeBtn("Remove Pin", 1, 0.35, 0.35);
	removeBtn:SetPoint("TOPLEFT", navBtn, "BOTTOMLEFT", 0, -2);
	removeBtn:SetScript("OnClick", function()
		QM_mapPinMenuBD:Hide();
		f:Hide();
		QM_mapPin = nil;
		-- Stop active navigation (no arrival message).
		if QM_mapPinNavigating then
			if QM_Nav_Stop then QM_Nav_Stop(false); end
		end
		if QuestMapFrame._mapPinFrame then QuestMapFrame._mapPinFrame:Hide(); end
		if QuestMapFrame._mapPinBtn then
			QuestMapFrame._mapPinBtn._normalTex:SetVertexColor(1, 1, 1);
		end
	end);

	-- Share in Chat
	local shareBtn = makeBtn("Share Pin", 0.85, 0.85, 0.85);
	shareBtn:SetPoint("TOPLEFT", removeBtn, "BOTTOMLEFT", 0, -2);
	shareBtn:SetScript("OnClick", function()
		QM_mapPinMenuBD:Hide();
		f:Hide();
		if not QM_mapPin then return; end
		local p    = QM_mapPin;
		local xPct = math.floor(p.fx * 100 + 0.5);
		local yPct = math.floor(p.fy * 100 + 0.5);
		-- Paste plain-text into the chat input box so the player can choose channel & send.
		local plainText = string.format("Map Pin: %s (%d, %d)", p.zoneName, xPct, yPct);
		ChatFrame_OpenChat(plainText);
	end);
	shareBtn:SetScript("OnEnter", function(btn)
		GameTooltip:SetOwner(btn, "ANCHOR_RIGHT");
		GameTooltip:SetText("Share Pin", 1, 1, 1);
		GameTooltip:AddLine("Pastes the pin coordinates into your chat input box.", 0.7, 0.7, 0.7, true);
		GameTooltip:AddLine("Choose your channel and press Enter to send.", 0.5, 0.5, 0.5, true);
		GameTooltip:Show();
	end);
	shareBtn:SetScript("OnLeave", function() GameTooltip:Hide(); end);

	f:Hide();
	return f;
end

local function QM_MapPin_ShowMenu(anchor)
	if not QM_mapPinMenu then
		QM_mapPinMenu = QM_MapPin_BuildMenu();
	end
	local f = QM_mapPinMenu;
	local p = QM_mapPin;
	-- Update title and coords
	local zoneName = (p and p.zoneName) or "Pin";
	local display  = (#zoneName > 20) and (zoneName:sub(1, 18) .. "..") or zoneName;
	f.title:SetText(display);
	if p then
		local xPct = math.floor(p.fx * 100 + 0.5);
		local yPct = math.floor(p.fy * 100 + 0.5);
		f.coords:SetText(string.format("(%d, %d)", xPct, yPct));
	else
		f.coords:SetText("");
	end
	f:ClearAllPoints();
	f:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 5, 0);
	QM_mapPinMenuBD:Show();
	f:SetAlpha(0);
	UIFrameFadeIn(f, 0.12, 0, 1);
	f:Show();
end

-- ── Init: pin marker frame (call once from QuestMapFrame_OnLoad) ───────────────
-- The frame is parented to mapArea (NOT the scroll child) so it is positioned
-- via viewport-space coordinates in QM_MapPin_OnUpdate, exactly like the player
-- arrow.  This guarantees it always renders above WorldMapButton.
function QM_MapPin_InitMarker(qmf)
	local pinF = CreateFrame("Button", "QuestMapPinMarker", qmf.mapArea);
	pinF:SetSize(22, 22);
	pinF:SetFrameStrata("TOOLTIP");
	pinF:EnableMouse(true);
	pinF:RegisterForClicks("RightButtonUp");

	local pinTex = pinF:CreateTexture(nil, "ARTWORK");
	pinTex:SetAllPoints(pinF);
	local ok = pcall(function() pinTex:SetRetailAtlas("crosshair_track_32"); end);
	if not ok then
		pinTex:SetTexture("Interface\\MINIMAP\\Tracking\\None");
		pinTex:SetVertexColor(1, 0.85, 0);
	end
	-- Placement pulse ring (brief flash on pin drop)
	local pulseRing = pinF:CreateTexture(nil, "BACKGROUND");
	pulseRing:SetTexture("Interface\\Buttons\\UI-Common-MouseHilight");
	pulseRing:SetBlendMode("ADD");
	pulseRing:SetVertexColor(1, 0.85, 0, 1);
	pulseRing:SetSize(38, 38);
	pulseRing:SetPoint("CENTER", pinF, "CENTER", 0, 0);
	pulseRing:Hide();
	pinF._pulse      = pulseRing;
	pinF._pulseAlpha = 0;
	-- Navigate glow ring (cyan loop while navigating via TomTom)
	local glowRing = pinF:CreateTexture(nil, "BACKGROUND");
	glowRing:SetTexture("Interface\\Buttons\\UI-Common-MouseHilight");
	glowRing:SetBlendMode("ADD");
	glowRing:SetVertexColor(0.3, 0.9, 1, 1);
	glowRing:SetSize(46, 46);
	glowRing:SetPoint("CENTER", pinF, "CENTER", 0, 0);
	glowRing:Hide();
	pinF._glow      = glowRing;
	pinF._glowAlpha = 0;
	pinF._glowDir   = -1;

	pinF:SetScript("OnClick", function(btn, button)
		if button == "RightButton" then
			QM_MapPin_ShowMenu(btn);
		end
	end);
	pinF:SetScript("OnEnter", function(btn)
		GameTooltip:SetOwner(btn, "ANCHOR_CURSOR");
		GameTooltip:SetText("Map Pin", 1, 0.82, 0);
		if QM_mapPin then
			local xPct = math.floor(QM_mapPin.fx * 100 + 0.5);
			local yPct = math.floor(QM_mapPin.fy * 100 + 0.5);
			GameTooltip:AddLine(
				string.format("%s  (%d, %d)", QM_mapPin.zoneName, xPct, yPct),
				0.7, 0.7, 0.7);
		end
		GameTooltip:AddLine("Right-click to navigate, remove, or share.", 0.5, 0.5, 0.5);
		GameTooltip:Show();
	end);
	pinF:SetScript("OnLeave", function() GameTooltip:Hide(); end);
	pinF:Hide();
	qmf._mapPinFrame = pinF;
end

-- ── Init: toolbar button (call once from QuestMapFrame_OnLoad) ─────────────────
function QM_MapPin_InitButton(qmf, locBtn)
	local mapPinBtn = CreateFrame("Button", "QuestMapMapPinButton", qmf.mapArea);
	mapPinBtn:SetSize(22, 22);
	-- QuestMap.lua synchronizes this button to WorldMapButton's strata/level.
	mapPinBtn:SetPoint("TOPLEFT", locBtn, "TOPRIGHT", 4, 0);

	local pinBtnTex = mapPinBtn:CreateTexture(nil, "ARTWORK");
	pinBtnTex:SetAllPoints(mapPinBtn);
	local ok = pcall(function() pinBtnTex:SetRetailAtlas("crosshair_track_32"); end);
	if not ok then
		pinBtnTex:SetTexture("Interface\\MINIMAP\\Tracking\\None");
		pinBtnTex:SetVertexColor(0.8, 0.8, 1);
	end
	mapPinBtn._normalTex = pinBtnTex;
	mapPinBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD");

	local _pinBtnLastClick = 0;
	mapPinBtn:SetScript("OnClick", function(btn)
		local now = GetTime();
		if now - _pinBtnLastClick < 0.4 then
			-- Double-click: undo the first-click mode toggle and navigate the
			-- embedded map to the pin's zone.
			_pinBtnLastClick = 0;
			QM_mapPinMode = not QM_mapPinMode;  -- revert first-click toggle
			pinBtnTex:SetVertexColor(QM_mapPinMode and 1 or 1,
			                         QM_mapPinMode and 0.85 or 1,
			                         QM_mapPinMode and 0 or 1);
			if QM_mapPin and QM_MapPin_OpenAndNavigate then
				QM_MapPin_OpenAndNavigate(QM_mapPin.continent, QM_mapPin.zone);
			end
			GameTooltip:Hide();
			return;
		end
		_pinBtnLastClick = now;
		QM_mapPinMode = not QM_mapPinMode;
		pinBtnTex:SetVertexColor(QM_mapPinMode and 1 or 1,
		                         QM_mapPinMode and 0.85 or 1,
		                         QM_mapPinMode and 0 or 1);
		GameTooltip:Hide();
	end);
	mapPinBtn:SetScript("OnEnter", function(btn)
		GameTooltip:SetOwner(btn, "ANCHOR_BOTTOMLEFT");
		GameTooltip:SetText("Map Pin", 1, 1, 1);
		if QM_mapPinMode then
			GameTooltip:AddLine("Click on the map to place the pin.", 1, 0.85, 0, true);
		else
			GameTooltip:AddLine("Click to enter placement mode, then click the map.", 0.7, 0.7, 0.7, true);
			GameTooltip:AddLine("Double-click to jump the map view to the pin location.", 0.7, 0.7, 0.7, true);
			GameTooltip:AddLine("Right-click the pin icon on the map for navigation/sharing.", 0.5, 0.5, 0.5, true);
		end
		GameTooltip:Show();
	end);
	mapPinBtn:SetScript("OnLeave", function() GameTooltip:Hide(); end);
	qmf._mapPinBtn = mapPinBtn;
end

-- ── Placement: called from WorldMapButton OnMouseDown in QuestMap.lua ──────────
function QM_MapPin_PlaceAtCursor()
	if not QUESTMAP_WORLDMAP_ATTACHED then return false; end
	local sf = QuestMapFrame and QuestMapFrame._mapScroller;
	if not sf then return false; end	-- Block placement at continent/world overview levels.
	-- Players must be viewing an actual zone to drop a pin.
	local placeCont = GetCurrentMapContinent();
	local placeZone = GetCurrentMapZone();
	if (not placeCont) or placeCont <= 0 or (not placeZone) or placeZone == 0 then
		if DEFAULT_CHAT_FRAME then
			DEFAULT_CHAT_FRAME:AddMessage(
				"|cffffff78QuestMap:|r Zoom into a specific zone to place a Map Pin.");
		end
		return false;
	end	local cx, cy = GetCursorPosition();
	local es      = sf:GetEffectiveScale();
	local vx      = cx / es - sf:GetLeft();
	local vy      = sf:GetTop() - cy / es;
	local fx = math.max(0, math.min(1, (sf:GetHorizontalScroll() + vx) / ((QUESTMAP_MAP_WIDTH or 640) * QM_zoomLevel)));
	local fy = math.max(0, math.min(1, (sf:GetVerticalScroll()   + vy) / ((QUESTMAP_MAP_HEIGHT or (668 * 640 / 1002)) * QM_zoomLevel)));
	QM_mapPin = {
		continent    = GetCurrentMapContinent(),
		zone         = GetCurrentMapZone(),
		dungeonLevel = GetCurrentMapDungeonLevel(),
		fx           = fx,
		fy           = fy,
		zoneName     = GetMapInfo() or "Unknown",
	};
	QM_mapPinMode = false;
	local pb = QuestMapFrame._mapPinBtn;
	if pb then pb._normalTex:SetVertexColor(1, 1, 1); end
	-- Pulse the ring briefly on placement
	local pinF = QuestMapFrame._mapPinFrame;
	if pinF then
		pinF._pulseAlpha = 1;
		pinF._pulse:SetAlpha(1);
		pinF._pulse:Show();
	end
	-- Show 'You pinned' clickable link in chat
	local fxI = math.floor(fx * 10000 + 0.5);
	local fyI = math.floor(fy * 10000 + 0.5);
	QM_InjectPinLink(
		UnitName("player"),
		QM_mapPin.continent, QM_mapPin.zone, QM_mapPin.dungeonLevel,
		fxI, fyI, QM_mapPin.zoneName);
	PlaySound("igMainMenuOptionCheckBoxOn");
	return true;  -- caller should consume the click event (return early)
end

-- ── Coordinate projection for parent-map views ──────────────────────────────────
-- Given a pin and the currently viewed map (viewCont, viewZone, viewDL),
-- returns (fx, fy) expressed in the viewed map's 0-1 coordinate space,
-- or (nil, nil) when the pin is not part of the visible map hierarchy.
--
-- Three levels are supported:
--   Zone level  : exact cont+zone match (original behaviour)
--   Continent   : same continent, viewZone == 0   → project zone within continent
--   World/Azeroth: viewCont == 0 (WORLDMAP_WORLD_ID) → project through continent into world
--                  Only continents whose parentContinent == 0 appear here
--                  (Outland has parentContinent == 3 and is hidden at world view).
local function QM_MapPin_GetFxFy(pin, viewCont, viewZone, viewDL)
	-- ── Exact zone match ───────────────────────────────────────────────────────
	if viewCont == pin.continent and viewZone == pin.zone then
		if viewDL ~= pin.dungeonLevel then return nil, nil; end
		return pin.fx, pin.fy;
	end
	-- Dungeon-floor pins are only shown on their exact floor.
	if pin.dungeonLevel and pin.dungeonLevel > 0 then return nil, nil; end
	-- ── Continent view (same continent, zone = 0) ─────────────────────────────
	if viewCont == pin.continent and viewZone == 0 then
		if pin.zone == 0 then return pin.fx, pin.fy; end   -- pin already at continent level
		local astro = QM_Nav_GetAstrolabe and QM_Nav_GetAstrolabe();
		if not (astro and astro.WorldMapSize) then return nil, nil; end
		local WMS      = astro.WorldMapSize;
		local contData = WMS[pin.continent];
		local zoneData = contData and contData[pin.zone];
		if not (contData and zoneData
				and (contData.width  or 0) > 0 and (contData.height or 0) > 0
				and (zoneData.width  or 0) > 0 and (zoneData.height or 0) > 0) then return nil, nil; end
		local x = pin.fx * zoneData.width  + (zoneData.xOffset or 0);
		local y = pin.fy * zoneData.height + (zoneData.yOffset or 0);
		return x / contData.width, y / contData.height;
	end
	-- ── World / Azeroth overview (viewCont == 0) ─────────────────────────────
	local WORLD_ID = WORLDMAP_WORLD_ID or 0;
	if viewCont == WORLD_ID then
		local astro = QM_Nav_GetAstrolabe and QM_Nav_GetAstrolabe();
		if not (astro and astro.WorldMapSize) then return nil, nil; end
		local WMS       = astro.WorldMapSize;
		local contData  = WMS[pin.continent];
		local worldData = WMS[0];
		-- Only show if the continent belongs to the Azeroth world overview.
		if not (contData and worldData
				and (worldData.width  or 0) > 0 and (worldData.height or 0) > 0
				and contData.parentContinent == 0
				and (contData.width  or 0) > 0  and (contData.height or 0) > 0) then return nil, nil; end
		local x_cont, y_cont;
		if pin.zone == 0 then
			x_cont = pin.fx * contData.width;
			y_cont = pin.fy * contData.height;
		else
			local zoneData = contData[pin.zone];
			if not (zoneData and (zoneData.width or 0) > 0) then return nil, nil; end
			x_cont = pin.fx * zoneData.width  + (zoneData.xOffset or 0);
			y_cont = pin.fy * zoneData.height + (zoneData.yOffset or 0);
		end
		local x_world = x_cont + (contData.xOffset or 0);
		local y_world = y_cont + (contData.yOffset or 0);
		return x_world / worldData.width, y_world / worldData.height;
	end
	return nil, nil;
end

-- ── Per-frame update: called from QuestMapFrame's OnUpdate ────────────────────
-- Positions the pin marker in viewport-space (same math as the player arrow).
function QM_MapPin_OnUpdate(qmf, elapsed)
	local pinF = qmf._mapPinFrame;
	if not pinF then return; end

	-- Fade out the placement pulse ring
	if pinF._pulseAlpha and pinF._pulseAlpha > 0 then
		pinF._pulseAlpha = math.max(0, pinF._pulseAlpha - elapsed * 0.9);
		if pinF._pulseAlpha <= 0 then
			pinF._pulse:Hide();
		else
			pinF._pulse:SetAlpha(pinF._pulseAlpha);
		end
	end
	-- Breathe the navigate glow while navigating
	if QM_mapPinNavigating and pinF._glow then
		pinF._glowAlpha = pinF._glowAlpha + elapsed * 1.4 * (pinF._glowDir or -1);
		if pinF._glowAlpha <= 0.15 then
			pinF._glowAlpha = 0.15;
			pinF._glowDir   =  1;
		elseif pinF._glowAlpha >= 1 then
			pinF._glowAlpha = 1;
			pinF._glowDir   = -1;
		end
		pinF._glow:SetAlpha(pinF._glowAlpha);
		pinF._glow:Show();
	end

	if not QM_mapPin or not QUESTMAP_WORLDMAP_ATTACHED then
		pinF:Hide();
		return;
	end
	-- Project pin into current map's coordinate space.
	-- Supports zone, continent, and world-overview levels.
	local viewCont = GetCurrentMapContinent();
	local viewZone = GetCurrentMapZone();
	local viewDL   = GetCurrentMapDungeonLevel();
	local fx, fy = QM_MapPin_GetFxFy(QM_mapPin, viewCont, viewZone, viewDL);
	if not fx then
		pinF:Hide();
		return;
	end
	local sfr = qmf._mapScroller;
	if not sfr then pinF:Hide(); return; end

	-- Convert map-fraction → viewport pixel, same as player arrow.
	local mapPx = fx * (QUESTMAP_MAP_WIDTH or 640) * QM_zoomLevel;
	local mapPy = fy * (QUESTMAP_MAP_HEIGHT or (668 * 640 / 1002)) * QM_zoomLevel;
	local viewX = mapPx - sfr:GetHorizontalScroll();
	local viewY = mapPy - sfr:GetVerticalScroll();

	-- Margin of half the pin size (11 px) keeps it visible when partially on-screen.
	if viewX >= -11 and viewX <= 525 and viewY >= -11 and viewY <= 353 then
		pinF:ClearAllPoints();
		pinF:SetPoint("CENTER", qmf.mapArea, "TOPLEFT", viewX, -viewY);
		pinF:Show();
	else
		pinF:Hide();
	end
end

-- ── Detach: called from QuestMapFrame_DetachWorldMap ──────────────────────────
function QM_MapPin_Detach()
	QM_mapPinMode = false;
	if QuestMapFrame._mapPinBtn then
		QuestMapFrame._mapPinBtn._normalTex:SetVertexColor(1, 1, 1);
	end
	if QuestMapFrame._mapPinFrame then
		QuestMapFrame._mapPinFrame:Hide();
	end
end