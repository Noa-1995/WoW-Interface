NUM_ALWAYS_UP_UI_FRAMES = 0;
NUM_EXTENDED_UI_FRAMES = 0;
MAX_WORLDSTATE_SCORE_BUTTONS = 20;
MAX_NUM_STAT_COLUMNS = 7;
WORLDSTATESCOREFRAME_BASE_COLUMNS = 6;
WORLDSTATESCOREFRAME_PADDING = 35;
WORLDSTATESCOREFRAME_COLUMN_SPACING = 76;
WORLDSTATECOREFRAME_BUTTON_TEXT_OFFSET = -30;

WORLDSTATEALWAYSUPFRAME_TIMESINCELAST = -25;
WORLDSTATEALWAYSUPFRAME_TIMESINCESTART = 0;
WORLDSTATEALWAYSUPFRAME_TIMETORUN = 60;
WORLDSTATEALWAYSUPFRAME_DEFAULTINTERVAL = 5;

WORLDSTATEALWAYSUPFRAME_SUSPENDEDCHATFRAMES = {};

local inBattleground = false;

--
FILTERED_BG_CHAT_ADD_GLOBALS = { "ERR_RAID_MEMBER_ADDED_S", "ERR_BG_PLAYER_JOINED_SS" };
FILTERED_BG_CHAT_SUBTRACT_GLOBALS = { "ERR_RAID_MEMBER_REMOVED_S", "ERR_BG_PLAYER_LEFT_S" };

--Filtered at the end of BGs only
FILTERED_BG_CHAT_END_GLOBALS = { "LOOT_ITEM", "LOOT_ITEM_MULTIPLE", "CREATED_ITEM", "CREATED_ITEM_MULTIPLE", "ERR_RAID_MEMBER_REMOVED_S", "ERR_BG_PLAYER_LEFT_S" };

FILTERED_BG_CHAT_ADD = {};
FILTERED_BG_CHAT_SUBTRACT = {};
FILTERED_BG_CHAT_END = {};

ADDED_PLAYERS = {};
SUBTRACTED_PLAYERS = {};

CLASS_BUTTONS = {
	["WARRIOR"]	= {0, 0.25, 0, 0.25},
	["MAGE"]		= {0.25, 0.49609375, 0, 0.25},
	["ROGUE"]		= {0.49609375, 0.7421875, 0, 0.25},
	["DRUID"]		= {0.7421875, 0.98828125, 0, 0.25},
	["HUNTER"]		= {0, 0.25, 0.25, 0.5},
	["SHAMAN"]	 	= {0.25, 0.49609375, 0.25, 0.5},
	["PRIEST"]		= {0.49609375, 0.7421875, 0.25, 0.5},
	["WARLOCK"]	= {0.7421875, 0.98828125, 0.25, 0.5},
	["PALADIN"]		= {0, 0.25, 0.5, 0.75},
	["DEATHKNIGHT"]	= {0.25, 0.49609375, 0.5, 0.75},
};

local RatedBattleGroundRankCoords = {
	{0.0009765625, 0.1259765625, 0.001953125, 0.251953125},
	{0.1259765625, 0.2509765625, 0.001953125, 0.251953125},
	{0.1259765625, 0.2509765625, 0.251953125, 0.501953125},
	{0.1259765625, 0.2509765625, 0.501953125, 0.751953125},
	{0.3759765625, 0.5009765625, 0.501953125, 0.751953125},
	{0.5009765625, 0.6259765625, 0.001953125, 0.251953125},
	{0.2509765625, 0.3759765625, 0.001953125, 0.251953125},
	{0.5009765625, 0.6259765625, 0.251953125, 0.501953125},
	{0.2509765625, 0.3759765625, 0.251953125, 0.501953125},
	{0.2509765625, 0.3759765625, 0.501953125, 0.751953125},
	{0.3759765625, 0.5009765625, 0.001953125, 0.251953125},
	{0.3759765625, 0.5009765625, 0.251953125, 0.501953125},
	{0.0009765625, 0.1259765625, 0.251953125, 0.501953125},
	{0.0009765625, 0.1259765625, 0.501953125, 0.751953125},
}

ExtendedUI = {};

local rankScoreSorted = nil
local playerRatingData = {}

function C_BattlefieldScoreSorted()
	rankScoreSorted = not rankScoreSorted
	WorldStateScoreFrame_Update()
end

function GetPlayerCrossFactionGroup()
	local playerName = UnitName("player")

	for i = 1, GetNumBattlefieldScores() do
		local name, killingBlows, honorableKills, deaths, honorGained, faction, rank, race, class, classToken, damageDone, healingDone = GetBattlefieldScore(i)

		if (playerName == name) then
			return faction
		end
	end
end

local _SortBattlefieldScoreData = _SortBattlefieldScoreData or SortBattlefieldScoreData
local sortData = {
	["name"] 	= "WorldStateScoreFrameName",
	["team"] 	= "WorldStateScoreFrameTeam",
	["kills"] 	= "WorldStateScoreFrameKB",
	["deaths"] 	= "WorldStateScoreFrameDeaths",
	["hk"] 		= "WorldStateScoreFrameHK",
	["damage"] 	= "WorldStateScoreFrameDamageDone",
	["healing"] = "WorldStateScoreFrameHealingDone",
	["team"] 	= "WorldStateScoreFrameTeamSkill",
	["cp"] 		= "WorldStateScoreFrameHonorGained",
	["stat1"] 	= "WorldStateScoreColumn1",
	["stat2"] 	= "WorldStateScoreColumn2",
	["stat3"] 	= "WorldStateScoreColumn3",
	["stat4"] 	= "WorldStateScoreColumn4",
	["stat5"] 	= "WorldStateScoreColumn5",
	["stat6"] 	= "WorldStateScoreColumn6",
	["stat7"] 	= "WorldStateScoreColumn7",
}

function BattlefieldScoreUpdateSortSelect( value )
	for _, v in pairs(sortData) do
		_G[v].Text:SetTextColor(0.68, 0.68, 0.68)
	end

	if sortData[value] then
		_G[sortData[value]].Text:SetTextColor(1, 1, 1)
	end
end

function SortBattlefieldScoreData( value )
	BattlefieldScoreUpdateSortSelect(value)
	_SortBattlefieldScoreData(value)
end

function SortDefaultBattlefieldScoreData()
	local _, kills1 = GetBattlefieldScore(1)
	local _, kills2 = GetBattlefieldScore(GetNumBattlefieldScores())

	while (kills1 and kills2) and kills1 < kills2 do
		SortBattlefieldScoreData("kills")

		_, kills1 = GetBattlefieldScore(1)
		_, kills2 = GetBattlefieldScore(GetNumBattlefieldScores())
	end

	BattlefieldScoreUpdateSortSelect("kills")
end

-- Always up stuff (i.e. capture the flag indicators)
function WorldStateAlwaysUpFrame_OnLoad(self)
	self:RegisterEvent("UPDATE_WORLD_STATES");
	self:RegisterEvent("UPDATE_BATTLEFIELD_SCORE");
	WorldStateAlwaysUpFrame_Update();
	self:RegisterEvent("PLAYER_ENTERING_WORLD");

	self:RegisterEvent("ZONE_CHANGED");
	self:RegisterEvent("ZONE_CHANGED_INDOORS");
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA");
	self:RegisterEvent("PLAYER_ENTERING_BATTLEGROUND");

	self:RegisterEvent("WORLD_STATE_UI_TIMER_UPDATE");

	FILTERED_BG_CHAT_ADD = {};
	FILTERED_BG_CHAT_SUBTRACT = {};
	FILTERED_BG_CHAT_END = {};

	local chatString;
	for _, str in next, FILTERED_BG_CHAT_ADD_GLOBALS do
		chatString = _G[str];
		if ( chatString ) then
			chatString = string.gsub(chatString, "%[", "%%[");
			chatString = string.gsub(chatString, "%]", "%%]");
			chatString = string.gsub(chatString, "%%s", "(.-)")
			tinsert(FILTERED_BG_CHAT_ADD, chatString);
		end
	end

	local chatString;
	for _, str in next, FILTERED_BG_CHAT_SUBTRACT_GLOBALS do
		chatString = _G[str];
		if ( chatString ) then
			chatString = string.gsub(chatString, "%[", "%%[");
			chatString = string.gsub(chatString, "%]", "%%]");
			chatString = string.gsub(chatString, "%%s", "(.-)")
			tinsert(FILTERED_BG_CHAT_SUBTRACT, chatString);
		end
	end

	for _, str in next, FILTERED_BG_CHAT_END_GLOBALS do
		chatString = _G[str];
		if ( chatString ) then
			chatString = string.gsub(chatString, "%[", "%%[");
			chatString = string.gsub(chatString, "%]", "%%]");
			chatString = string.gsub(chatString, "%%s", "(.-)");
			tinsert(FILTERED_BG_CHAT_END, chatString);
		end
	end
end

function WorldStateAlwaysUpFrame_OnEvent(self, event, ...)
	if ( event == "PLAYER_ENTERING_WORLD" ) then
		WorldStateScoreFrame.EfficiencyFrame.Animations = false
		WorldStateFrame_ToggleBattlefieldMinimap();
		WorldStateAlwaysUpFrame_StopBGChatFilter(self);
		WorldStateScoreFrame.EfficiencyFrame.Shown = nil
		WorldStateTopCenterFrame.BottomLabel:Hide()
	elseif ( event == "PLAYER_ENTERING_BATTLEGROUND" ) then
		WorldStateAlwaysUpFrame_StartBGChatFilter(self);
	else
		WorldStateAlwaysUpFrame_Update();
	end
end

function WorldStateAlwaysUpFrame_Update()
	local currentMapAreaID = GetCurrentMapAreaID()
	local numUI = GetNumWorldStateUI();
	local name, frame, frameText, frameDynamicIcon, frameIcon, frameFlash, flashTexture, frameDynamicButton;
	local extendedUI, extendedUIState1, extendedUIState2, extendedUIState3, uiInfo;
	local uiType, text, icon, state, dynamicIcon, tooltip, dynamicTooltip, flash, relative;
	local inInstance, instanceType = IsInInstance();
	local alwaysUpShown = 1;
	local extendedUIShown = 1;

	local isShownWidgetWorldState

	for i=1, numUI do
		uiType, state, text, icon, dynamicIcon, tooltip, dynamicTooltip, extendedUI, extendedUIState1, extendedUIState2, extendedUIState3 = GetWorldStateUIInfo(i);
		if ( (uiType ~= 1) or ((WORLD_PVP_OBJECTIVES_DISPLAY == "1") or (WORLD_PVP_OBJECTIVES_DISPLAY == "2" and IsSubZonePVPPOI()) or (instanceType == "pvp")) ) then
			if ( state > 0 ) then
				-- Handle always up frames and extended ui's completely differently
				if ( extendedUI ~= "" ) then
					-- extendedUI
					uiInfo = ExtendedUI[extendedUI]
					name = uiInfo.name..extendedUIShown;
					if ( extendedUIShown > NUM_EXTENDED_UI_FRAMES ) then
						frame = uiInfo.create(extendedUIShown);
						NUM_EXTENDED_UI_FRAMES = extendedUIShown;
					else
						frame = _G[name];
					end
					uiInfo.update(extendedUIShown, extendedUIState1, extendedUIState2, extendedUIState3);
					frame:Show();
					extendedUIShown = extendedUIShown + 1;
				else
					-- Always Up AlwaysUpFrame2DynamicIconButton
					name = "AlwaysUpFrame"..alwaysUpShown;
					if ( alwaysUpShown > NUM_ALWAYS_UP_UI_FRAMES ) then
						frame = CreateFrame("Frame", name, WorldStateAlwaysUpFrame, "WorldStateAlwaysUpTemplate");
						NUM_ALWAYS_UP_UI_FRAMES = alwaysUpShown;
					else
						frame = _G[name];
					end
					if ( alwaysUpShown == 1 ) then
						frame:SetPoint("TOP", WorldStateAlwaysUpFrame, -23 , -20);
					else
						relative = _G["AlwaysUpFrame"..(alwaysUpShown - 1)];
						frame:SetPoint("TOP", relative, "BOTTOM");
					end

					frameText = _G[name.."Text"];
					frameIcon = _G[name.."Icon"];
					frameDynamicIcon = _G[name.."DynamicIconButtonIcon"];
					frameFlash = _G[name.."Flash"];
					flashTexture = _G[name.."FlashTexture"];
					frameDynamicButton = _G[name.."DynamicIconButton"];
					frameText:SetText(text);
					frameIcon:SetTexture(icon)
					frameDynamicIcon:SetTexture(dynamicIcon);

					flash = nil;
					if ( dynamicIcon ~= "" ) then
						flash = dynamicIcon.."Flash"
					end
					flashTexture:SetTexture(flash);
					frameDynamicButton.tooltip = dynamicTooltip;
					if ( state == 2 ) then
						UIFrameFlash(frameFlash, 0.5, 0.5, -1);
						frameDynamicButton:Show();
					elseif ( state == 3 ) then
						UIFrameFlashStop(frameFlash);
						frameDynamicButton:Show();
					else
						UIFrameFlashStop(frameFlash);
						frameDynamicButton:Hide();
					end

					alwaysUpShown = alwaysUpShown + 1;

					-- New Battleground WorldState
					if WorldStateTopCenterFrame then
						local statusBar = string.find(icon, "Alliance") and WorldStateTopCenterFrame.LeftBar or WorldStateTopCenterFrame.RightBar
						local barID = statusBar:GetID()

						if i == 1 and icon == "" then
							WorldStateTopCenterFrame.TimeLeft:SetText(text)
							WorldStateTopCenterFrame.TimeLeft:Show()
						elseif i == 1 and icon ~= "" then
							WorldStateTopCenterFrame.TimeLeft:SetText(" ")
							WorldStateTopCenterFrame.TimeLeft:Hide()
						end

						if currentMapAreaID == BATTLEGROUND_WARSONG_GULCH then
							local flagCountCurrent, flagCountMax = string.match(text, "(%d+)/(%d+)")
							if flagCountCurrent and flagCountMax then
								if state == 2 then
									if dynamicIcon == "Interface\\WorldStateFrame\\AllianceFlag" then
										WorldStateTopCenterFrame.BattlegroundPOIData[barID] = {"Horde", 43, dynamicTooltip, ""}
									else
										WorldStateTopCenterFrame.BattlegroundPOIData[barID] = {"Alliance", 44, dynamicTooltip, ""}
									end
								else
									WorldStateTopCenterFrame.BattlegroundPOIData[barID] = nil
								end

								WorldStateTopCenterFrameUpdateInfo(statusBar, tooltip, flagCountCurrent, flagCountMax)
								isShownWidgetWorldState = true
							end
						elseif currentMapAreaID == BATTLEGROUND_ARATHI_BASIN then
							local resourceCurrent, resourceMax = string.match(text, ".-%: %d .-%: (%d+)/(%d+)")

							if resourceCurrent and resourceMax then
								WorldStateTopCenterFrameUpdateInfo(statusBar, tooltip, resourceCurrent, resourceMax)
								isShownWidgetWorldState = true
							end
						elseif currentMapAreaID == BATTLEGROUND_ALTERAC_VALLEY then
							local reinforcements = string.match(text, ".-%: (%d+)")

							if reinforcements then
								WorldStateTopCenterFrameUpdateInfo(statusBar, tooltip, reinforcements, 600, reinforcements)
								isShownWidgetWorldState = true
							end
						elseif currentMapAreaID == BATTLEGROUND_EYE_OF_THE_STORM then
							local resourceCurrent, resourceMax = string.match(text, ".-%: (%d+)/(%d+)")

							if resourceCurrent and resourceMax then
								WorldStateTopCenterFrameUpdateInfo(statusBar, tooltip, resourceCurrent, resourceMax)
								isShownWidgetWorldState = true
							end
						elseif currentMapAreaID == BATTLEGROUND_ISLE_OF_CONQUEST then
							local reinforcements = string.match(text, ".-%: (%d+)")

							if reinforcements then
								WorldStateTopCenterFrameUpdateInfo(statusBar, tooltip, reinforcements, 300, reinforcements)
								isShownWidgetWorldState = true
							end
						end
					end
				end
				if ( icon ~= "" ) then
					frame.tooltip = tooltip;
				else
					frame.tooltip = nil;
				end
				frame:Show();
			end
		end
	end

	if GhostFrame then
		if isShownWidgetWorldState then
			GhostFrame:ClearAllPoints()
			GhostFrame:SetPoint("TOP", WorldStateTopCenterFrame, "BOTTOM", 0, 0)
		else
			local lastAlwaysFrame = alwaysUpShown - 1

			if not GhostFrame.lastAlwaysUpFrame or GhostFrame.lastAlwaysUpFrame ~= lastAlwaysFrame then
				local parentFrame = _G["AlwaysUpFrame"..lastAlwaysFrame]
				GhostFrame:ClearAllPoints()

				if parentFrame then
					GhostFrame:SetPoint("TOP", _G["AlwaysUpFrame"..lastAlwaysFrame], "BOTTOM", 28, 0)
				else
					GhostFrame:SetPoint("TOP", 0, -55)
				end

				GhostFrame.lastAlwaysUpFrame = lastAlwaysFrame
			end
		end
	end

	if isShownWidgetWorldState then
		alwaysUpShown = 1
	end

	for i=alwaysUpShown, NUM_ALWAYS_UP_UI_FRAMES do
		frame = _G["AlwaysUpFrame"..i];
		frame:Hide();
	end
	for i=extendedUIShown, NUM_EXTENDED_UI_FRAMES do
		frame = _G["WorldStateCaptureBar"..i];
		if ( frame ) then
			frame:Hide();
		end
	end

	if WorldStateTopCenterFrame then
		WorldStateTopCenterFrame:SetFrameShown(isShownWidgetWorldState)
	end
end

function WorldStateTopCenterFrameUpdateInfo( statusBar, tooltip, currentValue, maxValue, formattedText )
	local _, _maxValue = statusBar:GetMinMaxValues()

	currentValue = tonumber(currentValue)
	maxValue = tonumber(maxValue)

	if not _maxValue then
		statusBar:SetMinMaxValues(0, maxValue)
	elseif currentValue > _maxValue then
		statusBar:SetMinMaxValues(currentValue, currentValue, formattedText)
	end

	statusBar:SetValue(currentValue, formattedText)

	statusBar.tooltip = tooltip
end

function WorldStateAlwaysUpFrame_OnUpdate(self, elapsed)
	WORLDSTATEALWAYSUPFRAME_TIMESINCELAST = WORLDSTATEALWAYSUPFRAME_TIMESINCELAST + elapsed;
	WORLDSTATEALWAYSUPFRAME_TIMESINCESTART = WORLDSTATEALWAYSUPFRAME_TIMESINCESTART + elapsed;
	if ( WORLDSTATEALWAYSUPFRAME_TIMESINCELAST >= WORLDSTATEALWAYSUPFRAME_DEFAULTINTERVAL ) then
		local subtractedPlayers, playerString = 0;

		for i in next, SUBTRACTED_PLAYERS do
			if ( not playerString ) then
				playerString = i;
			else
				playerString = playerString .. PLAYER_LIST_DELIMITER .. i;
			end

			subtractedPlayers = subtractedPlayers + 1;
		end

		local message, info;

		if ( subtractedPlayers > 0 ) then
			info = ChatTypeInfo["SYSTEM"];
			if ( subtractedPlayers > 1 and subtractedPlayers <= 3 ) then
				message = ERR_PLAYERLIST_LEFT_BATTLE;
				DEFAULT_CHAT_FRAME:AddMessage(string.format(message, subtractedPlayers, playerString), info.r, info.g, info.b, info.id);
			elseif ( subtractedPlayers > 3 ) then
				message = ERR_PLAYERS_LEFT_BATTLE_D;
				DEFAULT_CHAT_FRAME:AddMessage(string.format(message, subtractedPlayers), info.r, info.g, info.b, info.id);
			else
				message = ERR_PLAYER_LEFT_BATTLE_D;
				DEFAULT_CHAT_FRAME:AddMessage(string.format(message, playerString), info.r, info.g, info.b, info.id);
			end

			for i in next, SUBTRACTED_PLAYERS do
				SUBTRACTED_PLAYERS[i] = nil;
			end
		end

		local addedPlayers, playerString = 0;
		for i in next, ADDED_PLAYERS do
			if ( not playerString ) then
				playerString = i;
			else
				playerString = playerString .. PLAYER_LIST_DELIMITER .. i;
			end

			addedPlayers = addedPlayers + 1;
		end


		if ( addedPlayers > 0 ) then
			info = ChatTypeInfo["SYSTEM"];
			if ( addedPlayers > 1 and addedPlayers <= 3 ) then
				message = ERR_PLAYERLIST_JOINED_BATTLE;
				DEFAULT_CHAT_FRAME:AddMessage(string.format(message, addedPlayers, playerString), info.r, info.g, info.b, info.id);
			elseif ( addedPlayers > 3 ) then
				message = ERR_PLAYERS_JOINED_BATTLE_D;
				DEFAULT_CHAT_FRAME:AddMessage(string.format(message, addedPlayers), info.r, info.g, info.b, info.id);
			else
				message = ERR_PLAYER_JOINED_BATTLE_D;
				DEFAULT_CHAT_FRAME:AddMessage(string.format(message, playerString), info.r, info.g, info.b, info.id);
			end

			for i in next, ADDED_PLAYERS do
				ADDED_PLAYERS[i] = nil;
			end
		end

		WORLDSTATEALWAYSUPFRAME_TIMESINCELAST = 0;
	elseif ( WORLDSTATEALWAYSUPFRAME_TIMESINCESTART >= WORLDSTATEALWAYSUPFRAME_TIMETORUN ) then
		WORLDSTATEALWAYSUPFRAME_TIMESINCELAST = WORLDSTATEALWAYSUPFRAME_DEFAULTINTERVAL;
		WorldStateAlwaysUpFrame_OnUpdate(self, 0);
		self:SetScript("OnUpdate", nil);
	end
end

function WorldStateAlwaysUpFrame_StartBGChatFilter (self)
	inBattleground = true;

	-- Reset the OnUpdate timer variables
	WORLDSTATEALWAYSUPFRAME_TIMESINCELAST = -25;
	WORLDSTATEALWAYSUPFRAME_TIMESINCESTART = 0;

	ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", WorldStateAlwaysUpFrame_FilterChatMsgSystem);
	ChatFrame_AddMessageEventFilter("CHAT_MSG_LOOT", WorldStateAlwaysUpFrame_FilterChatMsgLoot);

	self:SetScript("OnUpdate", WorldStateAlwaysUpFrame_OnUpdate);
end

function WorldStateAlwaysUpFrame_StopBGChatFilter (self)
	inBattleground = false;

	ChatFrame_RemoveMessageEventFilter("CHAT_MSG_SYSTEM", WorldStateAlwaysUpFrame_FilterChatMsgSystem);
	ChatFrame_RemoveMessageEventFilter("CHAT_MSG_LOOT", WorldStateAlwaysUpFrame_FilterChatMsgLoot);

	for i in next, ADDED_PLAYERS do
		ADDED_PLAYERS[i] = nil;
	end

	for i in next, SUBTRACTED_PLAYERS do
		SUBTRACTED_PLAYERS[i] = nil;
	end

	self:SetScript("OnUpdate", nil);
end

function WorldStateAlwaysUpFrame_FilterChatMsgSystem (self, event, ...)
	local playerName;

	local message = ...;

	if ( GetBattlefieldWinner() ) then
		-- Filter out leaving messages when the battleground is over.
		for i, str in next, FILTERED_BG_CHAT_SUBTRACT do
			playerName = string.match(message, str);
			if ( playerName ) then
				return true;
			end
		end
	elseif ( WORLDSTATEALWAYSUPFRAME_TIMESINCESTART < WORLDSTATEALWAYSUPFRAME_TIMETORUN ) then
		-- Filter out leaving and joining messages when the battleground starts.
		for i, str in next, FILTERED_BG_CHAT_ADD do
			playerName = string.match(message, str);
			if ( playerName ) then
				-- Trim realm names
				playerName = string.match(playerName, "([^%-]+)%-?.*");
				ADDED_PLAYERS[playerName] = true;
				return true;
			end
		end

		for i, str in next, FILTERED_BG_CHAT_SUBTRACT do
			playerName = string.match(message, str);
			if ( playerName ) then
				playerName = string.match(playerName, "([^%-]+)%-?.*");
				SUBTRACTED_PLAYERS[playerName] = true;
				return true;
			end
		end
	end
	return false;
end

local matchString = string.gsub(LOOT_ITEM_CREATED_SELF, "%%s%.", ".+")

function WorldStateAlwaysUpFrame_FilterChatMsgLoot (self, event, ...)
	if ( GetBattlefieldWinner() ) then
		local message = ...;
		-- Suppress loot messages for other players at the end of battlefields and arenas
		if ( not string.match(message, matchString) ) then
			return true;
		end
	end

	return false;
end

function WorldStateFrame_ToggleBattlefieldMinimap()
	local _, instanceType = IsInInstance();
	if ( instanceType ~= "pvp" and instanceType ~= "none" ) then
		if ( BattlefieldMinimap and BattlefieldMinimap:IsShown() ) then
			BattlefieldMinimap:Hide();
		end
		return;
	end

	if ( WorldStateFrame_CanShowBattlefieldMinimap() ) then
		if ( not BattlefieldMinimap ) then
			BattlefieldMinimap_LoadUI();
		end
		BattlefieldMinimap:Show();
	end
end

function WorldStateFrame_CanShowBattlefieldMinimap()
	local _, instanceType = IsInInstance();

	if ( instanceType == "pvp" ) then
		return GetCVar("showBattlefieldMinimap") == "1";
	end

	if ( instanceType == "none" ) then
		return GetCVar("showBattlefieldMinimap") == "2";
	end

	return false;
end

-- UI Specific functions
function CaptureBar_Create(id)
	local frame = CreateFrame("Frame", "WorldStateCaptureBar"..id, UIParent, "WorldStateCaptureBarTemplate");
	return frame;
end

function CaptureBar_Update(id, value, neutralPercent)
	local position = 25 + 124*(1 - value/100);
	local bar = _G["WorldStateCaptureBar"..id];
	local barSize = 121;
	if ( not bar.oldValue ) then
		bar.oldValue = position;
	end
	-- Show an arrow in the direction the bar is moving
	if ( position < bar.oldValue ) then
		_G["WorldStateCaptureBar"..id.."IndicatorLeft"]:Show();
		_G["WorldStateCaptureBar"..id.."IndicatorRight"]:Hide();
	elseif ( position > bar.oldValue ) then
		_G["WorldStateCaptureBar"..id.."IndicatorLeft"]:Hide();
		_G["WorldStateCaptureBar"..id.."IndicatorRight"]:Show();
	else
		_G["WorldStateCaptureBar"..id.."IndicatorLeft"]:Hide();
		_G["WorldStateCaptureBar"..id.."IndicatorRight"]:Hide();
	end
	-- Figure out if the ticker is in neutral territory or on a faction's side
	if ( value > (50 + neutralPercent/2) ) then
		_G["WorldStateCaptureBar"..id.."LeftIconHighlight"]:Show();
		_G["WorldStateCaptureBar"..id.."RightIconHighlight"]:Hide();
	elseif ( value < (50 - neutralPercent/2) ) then
		_G["WorldStateCaptureBar"..id.."LeftIconHighlight"]:Hide();
		_G["WorldStateCaptureBar"..id.."RightIconHighlight"]:Show();
	else
		_G["WorldStateCaptureBar"..id.."LeftIconHighlight"]:Hide();
		_G["WorldStateCaptureBar"..id.."RightIconHighlight"]:Hide();
	end
	-- Setup the size of the neutral bar
	local middleBar = _G["WorldStateCaptureBar"..id.."MiddleBar"];
	local leftLine = _G["WorldStateCaptureBar"..id.."LeftLine"];
	if ( neutralPercent == 0 ) then
		middleBar:SetWidth(1);
		leftLine:Hide();
	else
		middleBar:SetWidth(neutralPercent/100*barSize);
		leftLine:Show();
	end

	bar.oldValue = position;
	_G["WorldStateCaptureBar"..id.."Indicator"]:SetPoint("CENTER", "WorldStateCaptureBar"..id, "LEFT", position, 0);
end


-- This has to be after all the functions are loaded
ExtendedUI["CAPTUREPOINT"] = {
	name = "WorldStateCaptureBar",
	create = CaptureBar_Create,
	update = CaptureBar_Update,
	onHide = CaptureBar_Hide,
}

-------------- FINAL SCORE FUNCTIONS ---------------
function WorldStateScoreFrame_OnLoad(self)
	self:RegisterEvent("UPDATE_BATTLEFIELD_SCORE");
	self:RegisterEvent("UPDATE_WORLD_STATES");
	self:RegisterEvent("PLAYER_ENTERING_WORLD");

	-- Tab Handling code
	PanelTemplates_SetNumTabs(self, 3);

	UIDropDownMenu_Initialize(ScorePlayerDropDown, ScorePlayerDropDown_Initialize, "MENU");

	self.Winner.WreatchRight:SetSubTexCoords(1.0, 0.0, 0.0, 1.0)
end

function WorldStateScoreFrame_OnShow( self, ... )
	WorldStateScoreFrame_Resize()
	WorldStateScoreFrame_Update()
	WorldStateScoreFrameTab_OnClick(WorldStateScoreFrameTab1)
end

function WorldStateScoreFrame_OnEvent( self, event, ... )
	if ( event == "PLAYER_ENTERING_WORLD" ) then
		RequestBattlefieldScoreData()
		WorldStateScoreFrame_UpdateFactionGroup()
		HideUIPanel(WorldStateScoreFrame);
		BATTLEFIELD_SHUTDOWN_TIMER = 0;
	elseif event == "UPDATE_BATTLEFIELD_SCORE" then
		WorldStateScoreFrame_Resize()
		WorldStateScoreFrame_Update()
	elseif event == "UPDATE_WORLD_STATES" then
		if WorldStateScoreFrame:IsShown() or GetBattlefieldWinner() then
			WorldStateScoreFrame_Resize()
			WorldStateScoreFrame_Update(true)
		end
	end
end

local saveTime = 0
local recallCount = 5
function WorldStateScoreFrame_Update( needSleep )
	local isArena, isRegistered = IsActiveBattlefieldArena();
	
	if (data and data.alliance and data.horde) and not isArena then
		local MAX_BAR = BattlegroundBalanceProgressBar:GetWidth() - 6
		local progressBarValue = data.alliance / (data.alliance + data.horde)

		BattlegroundBalanceProgressBar.TextLeft:SetText(data.alliance)
		BattlegroundBalanceProgressBar.TextRight:SetText(data.horde)
		BattlegroundBalanceProgressBar.Alliance:SetWidth(MAX_BAR * progressBarValue + 1)
	end

	WorldStateScoreFrame_UpdateFactionGroup()

	if ( isArena ) then
		-- Hide unused tabs
		WorldStateScoreFrameTab1:Hide();
		WorldStateScoreFrameTab2:Hide();
		WorldStateScoreFrameTab3:Hide();

		-- Hide unused columns
		WorldStateScoreFrameTeam:Hide();
		WorldStateScoreFrameDeaths:Hide();
		WorldStateScoreFrameHK:Hide();

		-- Reanchor some columns.
		WorldStateScoreFrameDamageDone:SetPoint("LEFT", "WorldStateScoreFrameKB", "RIGHT", -5, 0);
		if ( isRegistered ) then
			-- WorldStateScoreFrameTeam:Show();
			WorldStateScoreFrameHonorGained:Show();
			WorldStateScoreFrameHonorGainedText:SetText(SCORE_RATING_CHANGE);
			WorldStateScoreFrameHonorGained.sortType = "team";
			WorldStateScoreFrameHonorGained.tooltip = RATING_CHANGE_TOOLTIP;
			WorldStateScoreFrameTeamSkill:Show();
			WorldStateScoreFrameTeamSkillText:SetText(SCORE_TEAM_SKILL);
			WorldStateScoreFrameTeamSkill.sortType = "team";
			WorldStateScoreFrameTeamSkill.tooltip = TEAM_SKILL_TOOLTIP;
			-- WorldStateScoreFrameKB:SetPoint("LEFT", "WorldStateScoreFrameTeam", "RIGHT", -10, 0);
			WorldStateScoreFrameKB:SetPoint("LEFT", "WorldStateScoreFrameName", "RIGHT", 4, 0)
		else
			WorldStateScoreFrameHonorGained:Hide();
			WorldStateScoreFrameTeamSkill:Hide();
			WorldStateScoreFrameKB:SetPoint("LEFT", "WorldStateScoreFrameName", "RIGHT", 4, 0);
		end
	else
		-- Show Tabs
		WorldStateScoreFrameTab1:Show();
		WorldStateScoreFrameTab2:Show();
		WorldStateScoreFrameTab3:Show();

		WorldStateScoreFrameTeam:Hide();
		WorldStateScoreFrameTeamSkill:Hide();
		WorldStateScoreFrameDeaths:Show();
		WorldStateScoreFrameHK:Show();
		WorldStateScoreFrameHonorGained.sortType = "cp";
		WorldStateScoreFrameHonorGainedText:SetText(SCORE_HONOR_GAINED);
		WorldStateScoreFrameHonorGained.tooltip = HONOR_GAINED_TOOLTIP;
		WorldStateScoreFrameHKText:SetText(SCORE_HONORABLE_KILLS);
		WorldStateScoreFrameHonorGained:Show();
		-- Reanchor some columns.
		WorldStateScoreFrameDamageDone:SetPoint("LEFT", "WorldStateScoreFrameHK", "RIGHT", -5, 0);
		WorldStateScoreFrameKB:SetPoint("LEFT", "WorldStateScoreFrameName", "RIGHT", 4, 0);
	end

	--Show the frame if its hidden and there is a victor
	local battlefieldWinner = GetBattlefieldWinner()
	WorldStateScoreFrameLeaveButton:SetFrameShown(battlefieldWinner)
	WorldStateScoreFrame.Winner:SetFrameShown(battlefieldWinner)
	WorldStateScoreFrameTimerLabel:SetFrameShown(battlefieldWinner)
	WorldStateScoreFrameTimer:SetFrameShown(battlefieldWinner)

	WorldStateScoreFrame.Container.AllianceGlow:SetFrameShown(not isArena)
	WorldStateScoreFrame.Container.HordeGlow:SetFrameShown(not isArena)
	WorldStateScoreFrame.Container.BattlegroundNameFrame.BattlegroundName:SetFrameShown(not isArena)
	WorldStateScoreFrame.Container.AllianceScore:SetFrameShown(not isArena)
	WorldStateScoreFrame.Container.HordeScore:SetFrameShown(not isArena)
	WorldStateScoreFrame.Alliance:SetFrameShown(not isArena)
	WorldStateScoreFrame.Horde:SetFrameShown(not isArena)
	if (BattlegroundBalanceProgressBar.TextLeft:GetText() ~= "0" and BattlegroundBalanceProgressBar.TextRight:GetText() ~= "0") then
		BattlegroundBalanceProgressBar:SetFrameShown(not isArena)
		BattlegroundBalanceProgressBarHitArea:SetFrameShown(not isArena)
	end
	WorldStateScoreFrame.Container.YouFactionLabel:SetFrameShown(not isArena)
	WorldStateScoreFrame.Container.YouFaction:SetFrameShown(not isArena)
	WorldStateScoreFrame.Container.FactionGlow:SetFrameShown(not isArena)

	if not WorldStateScoreFrame.EfficiencyFrame.Shown and (isArena or not battlefieldWinner) then
		WorldStateScoreFrame.EfficiencyFrame:Hide()
	end

	if battlefieldWinner then
		local teamName = GetBattlefieldTeamInfo(battlefieldWinner)

		WorldStateScoreFrameLeaveButton:SetText(isArena and LEAVE_ARENA or LEAVE_BATTLEGROUND)
		WorldStateScoreFrameTimerLabel:SetText(isArena and TIME_TO_PORT_ARENA or TIME_TO_PORT);
		WorldStateScoreFrame.Winner.Glow:SetTexture(isArena and "Interface\\PVPFrame\\ScoreboardArena" or "Interface\\PVPFrame\\Scoreboard")
		WorldStateScoreFrame.Winner.FactionLogo:SetFrameShown(not isArena and battlefieldWinner ~= 2)

		WorldStateScoreFrame.Winner.Glow:SetWidth(isArena and 693 or 993)

		if battlefieldWinner == 0 then
			-- Horde \ Green
			WorldStateScoreFrame.Winner.Glow:SetTexCoord(0.0136719, 0.983398, 0.244141, 0.407227)
		else
			-- Alliance \ Gold
			WorldStateScoreFrame.Winner.Glow:SetTexCoord(0.0136719, 0.983398, 0.40918, 0.572266)
		end

		if isArena then
			WorldStateScoreFrame.Winner.WinnerText:SetText(_G["VICTORY_TEXT_ARENA"..battlefieldWinner])
		else
			WorldStateScoreFrame.Winner.WinnerText:SetText(_G["VICTORY_TEXT"..battlefieldWinner])

			if battlefieldWinner == 2 then
				WorldStateScoreFrame.Winner.Glow:SetVertexColor(0.5, 0.3, 0.3)
			else
				WorldStateScoreFrame.Winner.Glow:SetVertexColor(1, 1, 1)
			end

			WorldStateScoreFrame.Winner.FactionLogo:SetTexture(battlefieldWinner == 0 and "Interface\\Timer\\Horde-Logo" or "Interface\\Timer\\Alliance-LogoWhite")
		end

		ShowUIPanel(WorldStateScoreFrame)
	end

	-- Update buttons
	local numScores = GetNumBattlefieldScores(); --GetNumBattlefieldScores()

	local scoreButton, buttonIcon, buttonClass, buttonClassIcon, buttonName, buttonNameText, nameButton, buttonKills, buttonKillingBlows, buttonDeaths, buttonHonorGained, buttonTeamSkill, buttonFaction, columnButtonText, columnButtonIcon, buttonFactionLeft, buttonFactionRight, buttonDamage, buttonHealing, buttonTeam, buttonRank
	local name, kills, killingBlows, honorableKills, deaths, honorGained, faction, rank, race, class, classToken, damageDone, healingDone, additionalStatData;
	local teamName, teamRating, newTeamRating, teamSkill;
	local index;
	local columnData;

	-- ScrollFrame update
	local hasScrollBar;
	if ( numScores > MAX_WORLDSTATE_SCORE_BUTTONS ) then
		hasScrollBar = 1;
		WorldStateScoreScrollFrame:Show();
	else
		WorldStateScoreScrollFrame:Hide();
	end
	FauxScrollFrame_Update(WorldStateScoreScrollFrame, numScores, MAX_WORLDSTATE_SCORE_BUTTONS, 16, nil, nil, nil, nil, nil, nil, true, true );

	-- Setup Columns
	local text, icon, tooltip, columnButton;
	local numStatColumns = GetNumBattlefieldStats()
	local columnButton, columnButtonText, columnTextButton, columnIcon;
	local honorGainedAnchorFrame = "WorldStateScoreFrameHealingDone";
	for i=1, MAX_NUM_STAT_COLUMNS do
		if ( i <= numStatColumns ) then
			text, icon, tooltip = GetBattlefieldStatInfo(i);
			columnButton = _G["WorldStateScoreColumn"..i];
			columnButtonText = _G["WorldStateScoreColumn"..i.."Text"];
			columnButtonText:SetText(text or "None");
			columnButton.icon = icon;
			columnButton.tooltip = tooltip;

			columnTextButton = _G["WorldStateScoreButton1Column"..i.."Text"];

			if ( icon ~= "" ) then
				columnTextButton:SetPoint("CENTER", "WorldStateScoreColumn"..i, "CENTER", 6, WORLDSTATECOREFRAME_BUTTON_TEXT_OFFSET);
			else
				columnTextButton:SetPoint("CENTER", "WorldStateScoreColumn"..i, "CENTER", -1, WORLDSTATECOREFRAME_BUTTON_TEXT_OFFSET);
			end

			if ( i == numStatColumns ) then
				honorGainedAnchorFrame = "WorldStateScoreColumn"..i;
			end

			_G["WorldStateScoreColumn"..i]:Show();
		else
			_G["WorldStateScoreColumn"..i]:Hide();
		end
	end

	if ( isArena and isRegistered ) then
		WorldStateScoreFrameTeamSkill:SetPoint("LEFT", honorGainedAnchorFrame, "RIGHT", 10, 0);
		honorGainedAnchorFrame = "WorldStateScoreFrameTeamSkill";
	end

	-- Anchor the bonus honor gained to the last column shown
	WorldStateScoreFrameHonorGained:SetPoint("LEFT", honorGainedAnchorFrame, "RIGHT", 5, 0);

	-- Last button shown is what the player count anchors to
	local lastButtonShown
	local teamDataFailed, coords;

	for i=1, MAX_WORLDSTATE_SCORE_BUTTONS do
		-- Need to create an index adjusted by the scrollframe offset
		index = FauxScrollFrame_GetOffset(WorldStateScoreScrollFrame) + i;
		scoreButton = _G["WorldStateScoreButton"..i];
		if ( hasScrollBar ) then
			scoreButton:SetWidth(WorldStateScoreFrame.scrollBarButtonWidth);
		else
			scoreButton:SetWidth(WorldStateScoreFrame.buttonWidth);
		end
		if ( index <= numScores ) then
			buttonClass = _G["WorldStateScoreButton"..i.."ClassButton"]
			buttonClassIcon = _G["WorldStateScoreButton"..i.."ClassButtonIcon"]
			buttonName = _G["WorldStateScoreButton"..i.."Name"]
			buttonNameText = _G["WorldStateScoreButton"..i.."NameText"]
			buttonTeam =  _G["WorldStateScoreButton"..i.."Team"]
			buttonKills = _G["WorldStateScoreButton"..i.."HonorableKills"]
			buttonKillingBlows = _G["WorldStateScoreButton"..i.."KillingBlows"]
			buttonDeaths = _G["WorldStateScoreButton"..i.."Deaths"]
			buttonDamage = _G["WorldStateScoreButton"..i.."Damage"]
			buttonHealing = _G["WorldStateScoreButton"..i.."Healing"]
			buttonTeamSkill = _G["WorldStateScoreButton"..i.."TeamSkill"]
			buttonHonorGained = _G["WorldStateScoreButton"..i.."HonorGained"]
			buttonFactionLeft = _G["WorldStateScoreButton"..i.."FactionLeft"]
			buttonFactionRight = _G["WorldStateScoreButton"..i.."FactionRight"]
			buttonRank = _G["WorldStateScoreButton"..i.."RBGRankButton"]

			name, killingBlows, honorableKills, deaths, honorGained, faction, rank, race, class, classToken, damageDone, healingDone, additionalStatData = GetBattlefieldScore(index)
			teamName, teamRating, newTeamRating, teamSkill = GetBattlefieldTeamInfo(faction)

			if playerRatingData[name] then
				newTeamRating = playerRatingData[name]
			else
				newTeamRating = (newTeamRating or 0) - (teamRating or 0)
			end

			buttonRank.RankIcon:SetFrameShown(rank and rank > 0)
			buttonRank.FactionIcon:SetFrameShown(not rank or rank == 0)
			buttonClassIcon:SetFrameShown(classToken)

			if rank ~= 0 then
				local texCoord = RatedBattleGroundRankCoords[rank]

				if texCoord then
					buttonRank.RankIcon:SetTexCoord(unpack(texCoord))

					if rank > 0 then
						buttonRank.tooltip = string.format(RBG_SCORE_TOOLTIP_RANK, _G[string.format("PVP_RANK_%d_%d", 4 + rank, faction == "Alliance" and 1 or 0)], rank)
					end
				end
			else
				buttonRank.tooltip = nil

				if faction == 1 then
					buttonRank.FactionIcon:SetTexCoord(0.00390625, 0.136719, 0.511719, 0.671875)
				else
					buttonRank.FactionIcon:SetTexCoord(0.00390625, 0.136719, 0.679688, 0.839844)
				end
			end

			if classToken then
				coords = CLASS_BUTTONS[classToken]
				buttonClassIcon:SetTexCoord(unpack(coords))
			end

			buttonNameText:SetText(name --[[.." - ".. i .. " - " .. index]] or UNKNOWNOBJECT)
			buttonNameText:Show()

			if classToken and RAID_CLASS_COLORS[classToken] then
				buttonNameText:SetTextColor(RAID_CLASS_COLORS[classToken].r, RAID_CLASS_COLORS[classToken].g, RAID_CLASS_COLORS[classToken].b)
			end

			buttonName.name = name
			buttonName.tooltip = string.format("%s %s", race or "-", class or "-")

			buttonClass.tooltip = class or "-"

			buttonKillingBlows:SetText(killingBlows or "-")
			buttonDamage:SetText(damageDone or "-")
			buttonHealing:SetText(healingDone or "-")

			if isArena then
				if isRegistered then
					-- buttonTeam:SetText(teamName)
					-- buttonTeam:Show()

					buttonTeamSkill:SetText(teamSkill)
					buttonTeamSkill:Show()

					buttonHonorGained:SetText(newTeamRating or "----")
					buttonHonorGained:Show()
				else
					buttonTeamSkill:Hide()
					buttonHonorGained:Hide()
					buttonTeam:Hide()
				end

				buttonKills:Hide()
				buttonDeaths:Hide()
			else
				buttonKills:SetText(honorableKills)
				buttonDeaths:SetText(deaths)
				buttonHonorGained:SetText(honorGained)

				buttonTeam:Hide()
				buttonTeamSkill:Hide()
				buttonKills:Show()
				buttonDeaths:Show()
				buttonHonorGained:Show()
			end

			for j = 1, MAX_NUM_STAT_COLUMNS do
				columnButtonText = _G["WorldStateScoreButton"..i.."Column"..j.."Text"]
				columnButtonIcon = _G["WorldStateScoreButton"..i.."Column"..j.."Icon"]

				if j <= numStatColumns then
					-- columnData = additionalStatData[j]
					columnData = GetBattlefieldStatData(index, j);

					if columnData then
						if _G["WorldStateScoreColumn"..j].icon ~= "" then
							if columnData > 0 then
								columnButtonText:SetFormattedText("x %d", columnData)
								columnButtonIcon:SetTexture(_G["WorldStateScoreColumn"..j].icon..faction)
								columnButtonIcon:Show()
							else
								columnButtonText:SetText("")
								columnButtonIcon:Hide()
							end
						else
							columnButtonText:SetText(columnData)
							columnButtonIcon:Hide()
						end

						columnButtonText:Show()
					end
				else
					columnButtonText:Hide()
					columnButtonIcon:Hide()
				end
			end

			if faction then
				if faction == 0 then
					if isArena then
						-- Green Team
						buttonFactionLeft:SetVertexColor(0.19, 0.57, 0.11)
						buttonFactionRight:SetVertexColor(0.19, 0.57, 0.11)
					else
						-- Horde
						buttonFactionLeft:SetVertexColor(0.52, 0.075, 0.18)
						buttonFactionRight:SetVertexColor(0.5, 0.075, 0.18)
					end
				else
					if isArena then
						-- Gold Team
						buttonFactionLeft:SetVertexColor(0.85, 0.71, 0.26)
						buttonFactionRight:SetVertexColor(0.85, 0.71, 0.26)
					else
						-- Alliance
						buttonFactionLeft:SetVertexColor(0.11, 0.26, 0.51)
						buttonFactionRight:SetVertexColor(0.11, 0.26, 0.51)
					end
				end

				buttonFactionLeft:SetAlpha(0.7)
				buttonFactionRight:SetAlpha(0.7)

				if not isArena and name == UnitName("player") then
					buttonNameText:SetVertexColor(1, 1, 1)
					buttonFactionLeft:SetVertexColor(1.0, 0.82, 0)
					buttonFactionRight:SetVertexColor(1.0, 0.82, 0)

					buttonFactionLeft:SetAlpha(0.8)
					buttonFactionRight:SetAlpha(0.8)
				end

				buttonFactionLeft:Show()
				buttonFactionRight:Show()
			else
				buttonFactionLeft:Hide()
				buttonFactionRight:Hide()
			end

			lastButtonShown = scoreButton
			scoreButton:Show()
		else
			scoreButton:Hide()
		end
	end

	-- Count number of players on each side
	if PanelTemplates_GetSelectedTab(WorldStateScoreFrame) == 1 then
		local numHorde = 0
		local numAlliance = 0
		for i=1, numScores do
			name, killingBlows, honorableKills, deaths, honorGained, faction, rank, race, class = GetBattlefieldScore(i)
			if ( faction ) then
				if ( faction == 0 ) then
					numHorde = numHorde + 1
				else
					numAlliance = numAlliance + 1
				end
			end
		end
		WorldStateScoreFrameTab2:SetFormattedText(WORLDSTATE_SCORE_TAB_ALLIANCE, numAlliance)
		WorldStateScoreFrameTab3:SetFormattedText(WORLDSTATE_SCORE_TAB_HORDE, numHorde)
	end

	for i = 1, MAX_BATTLEFIELD_QUEUES do
		local status, mapName, instanceID, levelRangeMin, levelRangeMax, teamSize, registeredMatch = GetBattlefieldStatus(i)

		if status == "active" then
			WorldStateScoreFrame.Container.BattlegroundNameFrame.BattlegroundName:SetText(mapName)
		end
	end

	for i = 1, GetNumWorldStateUI() do
		local uiType, state, text, icon, dynamicIcon, tooltip, dynamicTooltip, extendedUI, extendedUIState1, extendedUIState2, extendedUIState3 = GetWorldStateUIInfo(i)

		if uiType == 0 and icon and icon ~= "" then
			local value = GetWorldStateUIInfoParce(text)

			if icon == "Interface\\TargetingFrame\\UI-PVP-Alliance" then
				WorldStateScoreFrame.Container.AllianceScore:SetText(value)
			elseif icon == "Interface\\TargetingFrame\\UI-PVP-Horde" then
				WorldStateScoreFrame.Container.HordeScore:SetText(value)
			end
		end
	end

	local elapsedTime = floor((GetBattlefieldInstanceRunTime() / 1000) / 60)
	WorldStateScoreFrame.Container.ElapsedTime:SetFormattedText(WORLDSTATE_SCORE_ELAPSED_TIME, elapsedTime)
end

function WorldStateScoreFrame_UpdateFactionGroup()
	local factionTag = GetPlayerCrossFactionGroup()
	-- local factionGroup = PLAYER_FACTION_GROUP[factionTag]

	if factionTag then
		local factionName = _G["BATTLEGROUND_CROSS_FACTION_"..factionTag]
		WorldStateScoreFrame.Container.YouFaction:SetText(factionName)
		if ( factionTag == 1 ) then
			WorldStateScoreFrame.Container.FactionGlow:SetTexCoord(0.830625, 0.918945, 0.150391, 0.217773)
		else
			WorldStateScoreFrame.Container.FactionGlow:SetTexCoord(0.680352, 0.763672, 0.150391, 0.217773)
		end
	end
end

function GetWorldStateUIInfoParce( text )
	if string.find(text, ".-%: (%d+)%/(%d+)") then -- Ущелье песни войны, Низина Арати, Око бури
		local minValue = text:match(".-%: (%d+)%/(%d+)")

		if minValue then
			return tonumber(minValue)
		end
	elseif string.find(text, ".-%: (%d+)") then -- Альтеракская долина, Остров завоеваний
		local minValue = text:match(".-%: (%d+)")

		if minValue then
			return tonumber(minValue)
		end
	else -- Берег древних
		return text
	end
end

function WorldStateScoreFrame_Resize(width)
	local isArena, isRegistered = IsActiveBattlefieldArena();
	local columns = WORLDSTATESCOREFRAME_BASE_COLUMNS;
	local scrollBar = 37;
	local name;
	if ( not width ) then

		width = WORLDSTATESCOREFRAME_PADDING + WorldStateScoreFrameName:GetWidth() --+ WorldStateScoreFrameClass:GetWidth();

		if ( isArena ) then
			columns = 3;
			if ( isRegistered ) then
				columns = 5;
				width = width + WorldStateScoreFrameTeam:GetWidth();
			else
				width = width + 43;
			end
		end

		columns = columns + GetNumBattlefieldStats();

		width = width + (columns*WORLDSTATESCOREFRAME_COLUMN_SPACING) + scrollBar;
	end

	WorldStateScoreFrame:SetWidth(width);

	WorldStateScoreFrame.scrollBarButtonWidth = WorldStateScoreFrame:GetWidth() - 58;
	WorldStateScoreFrame.buttonWidth = WorldStateScoreFrame:GetWidth() - 58;
	WorldStateScoreScrollFrame:SetWidth(WorldStateScoreFrame.scrollBarButtonWidth);

	-- Position Column data horizontally
	local buttonTeam, buttonTeamSkill, buttonKills, buttonKillingBlows, buttonDeaths, buttonDamage, buttonHealing, buttonHonorGained, buttonReturnedIcon, buttonCapturedIcon;
	for i=1, MAX_WORLDSTATE_SCORE_BUTTONS do
		if ( isRegistered ) then
			buttonTeam = _G["WorldStateScoreButton"..i.."Team"];
			buttonTeamSkill = _G["WorldStateScoreButton"..i.."TeamSkill"];
		end
		buttonKills = _G["WorldStateScoreButton"..i.."HonorableKills"];
		buttonKillingBlows = _G["WorldStateScoreButton"..i.."KillingBlows"];
		buttonDeaths = _G["WorldStateScoreButton"..i.."Deaths"];
		buttonDamage = _G["WorldStateScoreButton"..i.."Damage"];
		buttonHealing = _G["WorldStateScoreButton"..i.."Healing"];
		buttonHonorGained = _G["WorldStateScoreButton"..i.."HonorGained"];
		if ( i == 1 ) then
			if ( isRegistered ) then
				buttonTeam:SetPoint("LEFT", "WorldStateScoreFrameTeam", "LEFT", 0, WORLDSTATECOREFRAME_BUTTON_TEXT_OFFSET);
				buttonTeamSkill:SetPoint("CENTER", "WorldStateScoreFrameTeamSkill", "CENTER", 0, WORLDSTATECOREFRAME_BUTTON_TEXT_OFFSET);
			end
			buttonKills:SetPoint("CENTER", "WorldStateScoreFrameHK", "CENTER", 0, WORLDSTATECOREFRAME_BUTTON_TEXT_OFFSET);
			buttonKillingBlows:SetPoint("CENTER", "WorldStateScoreFrameKB", "CENTER", 0, WORLDSTATECOREFRAME_BUTTON_TEXT_OFFSET);
			buttonDeaths:SetPoint("CENTER", "WorldStateScoreFrameDeaths", "CENTER", 0, WORLDSTATECOREFRAME_BUTTON_TEXT_OFFSET);
			buttonDamage:SetPoint("CENTER", "WorldStateScoreFrameDamageDone", "CENTER", 0, WORLDSTATECOREFRAME_BUTTON_TEXT_OFFSET);
			buttonHealing:SetPoint("CENTER", "WorldStateScoreFrameHealingDone", "CENTER", 0, WORLDSTATECOREFRAME_BUTTON_TEXT_OFFSET);
			buttonHonorGained:SetPoint("CENTER", "WorldStateScoreFrameHonorGained", "CENTER", 0, WORLDSTATECOREFRAME_BUTTON_TEXT_OFFSET);
			for j=1, MAX_NUM_STAT_COLUMNS do
				_G["WorldStateScoreButton"..i.."Column"..j.."Text"]:SetPoint("CENTER", _G["WorldStateScoreColumn"..j], "CENTER", 0,  WORLDSTATECOREFRAME_BUTTON_TEXT_OFFSET);
			end
		else
			if ( isRegistered ) then
				buttonTeam:SetPoint("LEFT", "WorldStateScoreButton"..(i-1).."Team", "LEFT", 0,  -16);
				buttonTeamSkill:SetPoint("CENTER", "WorldStateScoreButton"..(i-1).."TeamSkill", "CENTER", 0, -16);
			end
			buttonKills:SetPoint("CENTER", "WorldStateScoreButton"..(i-1).."HonorableKills", "CENTER", 0, -16);
			buttonKillingBlows:SetPoint("CENTER", "WorldStateScoreButton"..(i-1).."KillingBlows", "CENTER", 0, -16);
			buttonDeaths:SetPoint("CENTER", "WorldStateScoreButton"..(i-1).."Deaths", "CENTER", 0, -16);
			buttonDamage:SetPoint("CENTER", "WorldStateScoreButton"..(i-1).."Damage", "CENTER", 0, -16);
			buttonHealing:SetPoint("CENTER", "WorldStateScoreButton"..(i-1).."Healing", "CENTER", 0, -16);
			buttonHonorGained:SetPoint("CENTER", "WorldStateScoreButton"..(i-1).."HonorGained", "CENTER", 0, -16);
			for j=1, MAX_NUM_STAT_COLUMNS do
				_G["WorldStateScoreButton"..i.."Column"..j.."Text"]:SetPoint("CENTER", "WorldStateScoreButton"..(i-1).."Column"..j.."Text", "CENTER", 0, -16);
			end
		end
	end
	return width;
end

function WorldStateScoreFrameTab_OnClick(tab)
	local faction = tab:GetID();
	PanelTemplates_SetTab(WorldStateScoreFrame, faction);
	if ( faction == 2 ) then
		faction = 1;
	elseif ( faction == 3 ) then
		faction = 0;
	else
		faction = nil;
	end

	SetBattlefieldScoreFaction(faction);
	PlaySound("igCharacterInfoTab");
end

function ToggleWorldStateScoreFrame()
	if ( WorldStateScoreFrame:IsShown() ) then
		HideUIPanel(WorldStateScoreFrame);
	else
		if ( not IsActiveBattlefieldArena() and MiniMapBattlefieldFrame.status == "active" ) then
			ShowUIPanel(WorldStateScoreFrame);
		end
	end
end

-- Report AFK feature
local AFK_PLAYER_CLICKED = nil;

function ScorePlayer_OnMouseUp(self, mouseButton)
	if ( mouseButton == "RightButton" ) then
		if ( not UnitIsUnit(self.name,"player") and UnitInRaid(self.name)) then
			AFK_PLAYER_CLICKED = self.name;
			ToggleDropDownMenu(1, nil, ScorePlayerDropDown, self:GetName(), 0, -5);
		end
	end
end

function ScorePlayerDropDown_OnClick()
	ReportPlayerIsPVPAFK(AFK_PLAYER_CLICKED);
	PlaySound("UChatScrollButton");
	AFK_PLAYER_CLICKED = nil;
end

function ScorePlayerDropDown_Cancel()
	AFK_PLAYER_CLICKED = nil;
	PlaySound("UChatScrollButton");
end

function ScorePlayerDropDown_Initialize()
	local info = UIDropDownMenu_CreateInfo();
	info.text = PVP_REPORT_AFK;
	info.func = ScorePlayerDropDown_OnClick;
	UIDropDownMenu_AddButton(info);

	info = UIDropDownMenu_CreateInfo();
	info.text = CANCEL;
	info.func = ScorePlayerDropDown_Cancel;
	UIDropDownMenu_AddButton(info);
end

function WorldStateTopCenterFrameStatusBar_UpdateBarWidth( self )
	local calcWidth = (self.value / self.maxValue) * 90
	local barWidth = min(calcWidth, 90)
	self.BarFillTexture:SetWidth(barWidth)
end

function WorldStateTopCenterFrameStatusBar_GetMinMaxValues( self )
	return self.minValue, self.maxValue
end

function WorldStateTopCenterFrameStatusBar_SetMinMaxValues( self, minValue, maxValue, formattedText )
	self.minValue = minValue
	self.maxValue = maxValue

	self:SetValue(minValue, formattedText)
end

function WorldStateTopCenterFrameStatusBar_SetValue( self, value, formattedText )
	if formattedText then
		self.SubLayer.Label:SetText(formattedText)
	else
		self.SubLayer.Label:SetFormattedText("%d/%d", value, self.maxValue or 0)
	end

	self.BarFillTexture:SetFrameShown(value > 0)
	self.SubLayer.Spark:SetFrameShown(value > 0 and value < self.maxValue)

	self.value = value

	self:UpdateBarWidth()
end

function WorldStateTopCenterFrameStatusBar_Reset( self )
	self.minValue = nil
	self.maxValue = nil
	self.value = nil

	for i = 1, #self.POIButtons do
		local button = self.POIButtons[i]
		button:Hide()
	end
end

function WorldStateTopCenterFrameStatusBar_OnLoad( self, ... )
	self.SetValue = WorldStateTopCenterFrameStatusBar_SetValue
	self.SetMinMaxValues = WorldStateTopCenterFrameStatusBar_SetMinMaxValues
	self.GetMinMaxValues = WorldStateTopCenterFrameStatusBar_GetMinMaxValues
	self.UpdateBarWidth = WorldStateTopCenterFrameStatusBar_UpdateBarWidth
	self.Reset = WorldStateTopCenterFrameStatusBar_Reset

	local barID = self:GetID()
	local barSide = barID == 1 and "left" or "right"

	self.BG:SetAtlasTex("objectivewidget-bar-background")
	self.BorderLeft:SetAtlasTex("objectivewidget-bar-border-left")
	self.BorderRight:SetAtlasTex("objectivewidget-bar-border-right")
	self.BorderCenter:SetAtlasTex("objectivewidget-bar-border-middle")
	self.BarFillTexture:SetAtlasTex("objectivewidget-bar-fill-"..barSide)

	self.SubLayer.Spark:SetAtlasTex("objectivewidget-bar-spark-"..barSide)
	self.SubLayer.Icon:SetAtlasTex("objectivewidget-icon-"..barSide)

	if barID == 1 then
		self.SubLayer.Icon:ClearAllPoints()
		self.BarFillTexture:ClearAllPoints()
		self.SubLayer.Spark:ClearAllPoints()

		self.SubLayer.Icon:SetPoint("RIGHT", self, "LEFT", 4, 0)
		self.BarFillTexture:SetPoint("LEFT", self, "LEFT", 1, 0)
		self.SubLayer.Spark:SetPoint("LEFT", self.BarFillTexture, "RIGHT", -7, 0)
	else
		self.SubLayer.Icon:ClearAllPoints()
		self.BarFillTexture:ClearAllPoints()

		self.SubLayer.Icon:SetPoint("LEFT", self, "RIGHT", -8, 0)
		self.BarFillTexture:SetPoint("RIGHT", self, "RIGHT", -1, 0)
		self.SubLayer.Spark:SetPoint("RIGHT", self.BarFillTexture, "LEFT", 7, 0)
	end

	for i = 1, 5 do
		local button = self.POIButtons[i]

		button:ClearAllPoints()

		if barID == 1 then
			if i == 1 then
				button:SetPoint("RIGHT", self.Container, "RIGHT", 0, 0)
			else
				button:SetPoint("RIGHT", self.POIButtons[i - 1], "LEFT", -2, 0)
			end
		else
			if i == 1 then
				button:SetPoint("LEFT", self.Container, "LEFT", 0, 0)
			else
				button:SetPoint("LEFT", self.POIButtons[i - 1], "RIGHT", 2, 0)
			end
		end
	end
end

local flagUnitFactionID
local function GetUnitFactionIDByEvent( self, event, ... )
	local factionAlliance = PLAYER_FACTION_GROUP["Alliance"]
	local factionHorde = PLAYER_FACTION_GROUP["Horde"]
	
	if event == "CHAT_MSG_BG_SYSTEM_ALLIANCE" then
		for msg in string.gmatch(arg1, EYE_OF_THE_STORM_FLAG_PICK) do
			flagUnitFactionID = factionAlliance
		end
	elseif event == "CHAT_MSG_BG_SYSTEM_HORDE" then
		for msg in string.gmatch(arg1, EYE_OF_THE_STORM_FLAG_PICK) do
			flagUnitFactionID = factionHorde
		end
	end
	return flagUnitFactionID
end

function WorldStateTopCenterFrame_OnLoad( self, ... )
	self.BattlegroundPOIData = {}
	self:RegisterEvent("CHAT_MSG_BG_SYSTEM_HORDE")
	self:RegisterEvent("CHAT_MSG_BG_SYSTEM_ALLIANCE")
	self:SetScript('OnEvent', GetUnitFactionIDByEvent)
end

function WorldStateTopCenterFrame_OnShow( self, ... )
	if self.UpdateStateTimer then
		self.UpdateStateTimer:Cancel()
		self.UpdateStateTimer = nil
	end

	self.UpdateStateTimer = C_TimerAug:NewTicker(1, function()
		WorldStateTopCenterFrame_UpdateState(self)
	end)
end

local BattlegroundPOITextureID = {
	[BATTLEGROUND_ARATHI_BASIN] = { -- Низина Арати
		Alliance = {17, 22, 27, 32, 37, 18, 23, 28, 33, 38},
		Horde 	 = {19, 24, 29, 34, 39, 20, 25, 30, 35, 40},
	},
	[BATTLEGROUND_ISLE_OF_CONQUEST] = { -- Остров завоеваний
		Alliance = {147, 137, 142, 17, 152, 146, 136, 141, 18, 151},
		Horde 	 = {149, 139, 144, 19, 154, 148, 138, 153, 20, 153},
	},
	[BATTLEGROUND_EYE_OF_THE_STORM] = { -- Око Бури
		Alliance = {9, 11},
		Horde 	 = {10, 12}
	},
}

local eyeOfTheStormFlagIndex
function WorldStateTopCenterFrame_UpdateState( self )
	local currentMapAreaID = GetCurrentMapAreaID()

	for i = 1, 5 do
		local name, description, textureIndex, x, y, mapLinkID = GetMapLandmarkInfo(i)

		if textureIndex and textureIndex ~= 0 then
			local texturePOIData = BattlegroundPOITextureID[currentMapAreaID]

			if currentMapAreaID == BATTLEGROUND_EYE_OF_THE_STORM then
				if textureIndex == 45 then
					eyeOfTheStormFlagIndex = i
				end
			end

			if texturePOIData then
				if tContains(texturePOIData.Alliance, textureIndex) then
					self.BattlegroundPOIData[i] = {"Alliance", textureIndex, name, description}
				elseif tContains(texturePOIData.Horde, textureIndex) then
					self.BattlegroundPOIData[i] = {"Horde", textureIndex, name, description}
				else
					self.BattlegroundPOIData[i] = nil
				end
			end
		else
			if currentMapAreaID ~= BATTLEGROUND_WARSONG_GULCH then
				if currentMapAreaID == BATTLEGROUND_EYE_OF_THE_STORM and i == eyeOfTheStormFlagIndex then
					-- local factionID = GetUnitFactionIDByEvent()
					if flagUnitFactionID then
						self.BattlegroundPOIData[i] = {PLAYER_FACTION_GROUP[flagUnitFactionID], 45, EYE_OF_THE_STORM_FLAG_NAME, EYE_OF_THE_STORM_FLAG_DESC}
					end
				else
					self.BattlegroundPOIData[i] = nil
				end
			end
		end
	end

	local index = {}
	index["Alliance"] = 1
	index["Horde"] = 1

	for _, POIData in pairs(self.BattlegroundPOIData) do
		local button

		if POIData[1] == "Alliance" then
			button = self.LeftBar.POIButtons[index["Alliance"]]
			index["Alliance"] = index["Alliance"] + 1
		else
			button = self.RightBar.POIButtons[index["Horde"]]
			index["Horde"] = index["Horde"] + 1
		end

		if button then
			if type(POIData[2]) == "number" then
				local x1, x2, y1, y2 = WorldMap_GetPOITextureCoords(POIData[2])

				button.Icon:SetTexture("Interface\\Minimap\\POIICONS")
				button.Icon:SetTexCoord(x1, x2, y1, y2)
			else
				button.Icon:SetTexture(POIData[2])

				if POIData.iconCoord then
					button.Icon:SetTexCoord(unpack(POIData.iconCoord))
				else
					button.Icon:SetTexCoord(0.15625, 0.84375, 0.09375, 0.875)
				end
			end

			button.name = POIData[3]
			button.description = POIData[4]

			button:Show()
		end
	end

	for i = index["Alliance"], 5 do
		local button = self.LeftBar.POIButtons[index["Alliance"]]

		if button then
			button:Hide()
		end
	end

	for i = index["Horde"], 5 do
		local button = self.RightBar.POIButtons[index["Horde"]]

		if button then
			button:Hide()
		end
	end

	if index["Alliance"] > 1 or index["Horde"] > 1 then
		WorldStateTopCenterFrame.BottomLabel:SetPoint("TOP", WorldStateTopCenterFrame, "BOTTOM", 0, 2)
	else
		WorldStateTopCenterFrame.BottomLabel:SetPoint("TOP", WorldStateTopCenterFrame, "BOTTOM", 0, 20)
	end
end

function WorldStateTopCenterFrame_OnHide( self, ... )
	self.LeftBar:Reset()
	self.RightBar:Reset()

	if self.UpdateStateTimer then
		self.UpdateStateTimer:Cancel()
		self.UpdateStateTimer = nil
	end

	self.BattlegroundPOIData = {}
end

StatusBarWidgetMixin = {}
function StatusBarWidgetMixin:OnLoad()
	self.elapsed = 0
	self.lockAnimation = true
	self:SetMinMaxValues(1, 100)
	self.Spark:SetSubTexCoords(1.0, 0.0, 1.0, 0.0)
end

function StatusBarWidgetMixin:PLAYER_ENTERING_WORLD()
	self:UpdateState()
end

function StatusBarWidgetMixin:ZONE_CHANGED()
	self:UpdateState()
end

function StatusBarWidgetMixin:ZONE_CHANGED_NEW_AREA()
	self:UpdateState()
end

function StatusBarWidgetMixin:UpdateState()
	if GetCurrentMapAreaID() ~= 530 then
		self:Hide()
	end
end

function StatusBarWidgetMixin:UNIT_AURA( _, _, _, _, _, count, _, _, _, _, _, _, spellID )
	if spellID == 63050 then
		self:SetValue(tonumber(count))
	end
end

function StatusBarWidgetMixin:OnEnter()
	self.Text:Show()
end

function StatusBarWidgetMixin:OnLeave()
	self.Text:Hide()
end

function StatusBarWidgetMixin:GetValue()
	return self.currentValue
end

function StatusBarWidgetMixin:SetMinMaxValues( min, max )
	self.minValue = min
	self.maxValue = max
end

function StatusBarWidgetMixin:GetMinValue()
	return self.minValue or 0
end

function StatusBarWidgetMixin:GetMaxValue()
	return self.maxValue or 0
end

function StatusBarWidgetMixin:SetValue( value )
	self:SetFrameShown(value and GetCurrentMapAreaID() == 530)

	if not value then
		return
	end

	if value < self.minValue then
		value = self.minValue
	elseif value > self.maxValue then
		value = self.maxValue
	end

	self.currentValue = value

	local MAX_BAR = self:GetWidth() - 12
	local progress = min(MAX_BAR * value / self.maxValue, MAX_BAR)

	self.Fill:SetWidth(progress)
	self.Fill:SetTexCoord(0.13671875, 0.13671875 + ((0.86328125 - 0.13671875) / self.maxValue) * value, 0.484375, 0.859375)

	self.Spark:SetFrameShown(value < 100)

	self.Text:SetFormattedText(SANITY_COUNT, value, self:GetMaxValue())
end