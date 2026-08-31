-- ====================================================================
-- Noa - PVPFRAME - MERGED FILE
-- ====================================================================
-- Constants
MAX_ARENA_TEAMS = 3;
MAX_ARENA_TEAM_MEMBERS = 10;
MAX_ARENA_TEAM_NAME_WIDTH = 310;
NUM_DISPLAYED_BATTLEGROUNDS = 5;

-- Battleground Texture List
local PVPBATTLEGROUND_TEXTURELIST = {};
PVPBATTLEGROUND_TEXTURELIST[1] = "Interface\\PVPFrame\\pvpbackground\\pvpbg-alteracvalley-toastbg";
PVPBATTLEGROUND_TEXTURELIST[2] = "Interface\\PVPFrame\\pvpbackground\\pvpbg-warsonggulch-toastbg";
PVPBATTLEGROUND_TEXTURELIST[3] = "Interface\\PVPFrame\\pvpbackground\\pvpbg-arathibasin-toastbg";
PVPBATTLEGROUND_TEXTURELIST[7] = "Interface\\PVPFrame\\pvpbackground\\pvpbg-eyeofthestorm-toastbg";
PVPBATTLEGROUND_TEXTURELIST[9] = "Interface\\PVPFrame\\pvpbackground\\pvpbg-strandoftheancients-toastbg";
PVPBATTLEGROUND_TEXTURELIST[30] = "Interface\\PVPFrame\\pvpbackground\\pvpbg-isleofconquest-toastbg";
PVPBATTLEGROUND_TEXTURELIST[32] = "Interface\\PVPFrame\\pvpbackground\\pvpbg-twinpeaks-toastbg";
-- ====================================================================
-- PVPFRAME FUNCTIONS
-- ====================================================================
local function GetBattlegroundDisplayName(bgIndex)
	local name, canEnter, isHoliday = GetBattlegroundInfo(bgIndex);
	if not name or not canEnter then
		return nil;
	end

	if isHoliday then
		return name.." ("..BATTLEGROUND_HOLIDAY..")";
	end

	return name;
end

local function GetFirstAvailableBattlegroundIndex()
	local numBGs = GetNumBattlegroundTypes();
	for i = 1, numBGs do
		local name, canEnter = GetBattlegroundInfo(i);
		if name and canEnter then
			return i;
		end
	end
end

local function ConfigurePVPBattlegroundInfoScrollFrame()
	if not PVPBattlegroundFrameInfoScrollFrame or not PVPBattlegroundFrame or PVPBattlegroundFrame._infoScrollFrameConfigured then
		return;
	end

	PVPBattlegroundFrame._infoScrollFrameConfigured = true;
	PVPBattlegroundFrameInfoScrollFrame:ClearAllPoints();
	PVPBattlegroundFrameInfoScrollFrame:SetPoint("TOPLEFT", PVPBattlegroundFrameBGDropDown, "BOTTOMLEFT", -100, 2);
	PVPBattlegroundFrameInfoScrollFrame:SetWidth(312);
	PVPBattlegroundFrameInfoScrollFrame:SetHeight(250);
end

function PVPFrame_OnLoad(self)
	PVPFrameLine1:SetAlpha(0.3);
	PVPHonorKillsLabel:SetVertexColor(0.6, 0.6, 0.6);
	PVPHonorHonorLabel:SetVertexColor(0.6, 0.6, 0.6);
	PVPHonorTodayLabel:SetVertexColor(0.6, 0.6, 0.6);
	PVPHonorYesterdayLabel:SetVertexColor(0.6, 0.6, 0.6);
	PVPHonorLifetimeLabel:SetVertexColor(0.6, 0.6, 0.6);
	self:RegisterEvent("PLAYER_ENTERING_WORLD");
	self:RegisterEvent("ARENA_TEAM_UPDATE");
	self:RegisterEvent("ARENA_TEAM_ROSTER_UPDATE");
	self:RegisterEvent("PLAYER_PVP_KILLS_CHANGED");
	self:RegisterEvent("PLAYER_PVP_RANK_CHANGED");
	self:RegisterEvent("HONOR_CURRENCY_UPDATE");
end

function PVPFrame_SetPortrait()
    if not PVPParentFrame then
        return;
    end
    
    if PVPParentFrame.portrait then
        PVPParentFrame.portrait:Hide();
    end
    if PVPParentFrame.PortraitContainer then
        PVPParentFrame.PortraitContainer:Hide();
    end

    if not PVPParentFrame.customPortrait then
        PVPParentFrame.customPortraitFrame = CreateFrame("Frame", nil, PVPParentFrame);
        PVPParentFrame.customPortraitFrame:SetSize(60, 60);
        PVPParentFrame.customPortraitFrame:SetPoint("TOPLEFT", -4, 8);

        PVPParentFrame.customPortrait = PVPParentFrame.customPortraitFrame:CreateTexture(nil, "OVERLAY");
        PVPParentFrame.customPortrait:SetAllPoints();
        PVPParentFrame.customPortrait:SetTexture("Interface\\PVPFrame\\UI-PvP-Icon");
    end

    PVPParentFrame.customPortraitFrame:SetFrameLevel(PVPParentFrame:GetFrameLevel() + 3);
    PVPParentFrame.customPortrait:Show();
end

function PVPFrame_OnEvent(self, event, ...)
	local arg1 = ...;
	if ( event == "PLAYER_ENTERING_WORLD" ) then
		PVPFrame_Update();
		PVPHonor_Update();
	elseif ( event == "PLAYER_PVP_KILLS_CHANGED" or event == "PLAYER_PVP_RANK_CHANGED") then
		PVPHonor_Update();
	elseif ( event == "ARENA_TEAM_UPDATE" ) then
		PVPFrame_Update();
		if ( PVPTeamDetails:IsShown() ) then
			local team = GetArenaTeam(PVPTeamDetails.team);
			if ( not team ) then
				PVPTeamDetails:Hide();
			else
				PVPTeamDetails_Update(PVPTeamDetails.team);
			end
		end
	elseif ( event == "HONOR_CURRENCY_UPDATE" ) then
		PVPHonor_Update();
	elseif ( event == "ARENA_TEAM_ROSTER_UPDATE" ) then
		if ( arg1 ) then
			if ( PVPTeamDetails:IsShown() ) then
				ArenaTeamRoster(PVPTeamDetails.team);
			end
		elseif ( PVPTeamDetails.team ) then
			PVPTeamDetails_Update(PVPTeamDetails.team);
			PVPFrame_Update();
		end
	end
end

function PVPFrame_OnShow()
	PVPFrame_SetFaction();
	PVPFrame_Update();
	PVPMicroButton_SetPushed();
	UpdateMicroButtons();
	PlaySound("igCharacterInfoOpen");
    PVPFrame_SetPortrait();
end

function PVPFrame_OnHide()
	PVPTeamDetails:Hide();
	PVPFrame_SetJustBG(false);
	PVPMicroButton_SetNormal();
	UpdateMicroButtons();
	PlaySound("igCharacterInfoClose");
end

function PVPFrame_SetFaction()
	local factionGroup = UnitFactionGroup("player");
	if ( factionGroup ) then
		PVPFrameHonorIcon:SetTexture("Interface\\TargetingFrame\\UI-PVP-"..factionGroup);
		PVPFrameHonorIcon:Show();
	end
end

function PVPFrame_Update()
	for i=1, MAX_ARENA_TEAMS do
		GetArenaTeam(i);
	end	
	PVPHonor_Update();
	PVPTeam_Update();
	
	if ( GetCurrentArenaSeason() == 0 ) then
		PVPFrame_SetToOffSeason();
	elseif ( PVPFrameOffSeason:IsShown() ) then
		PVPFrame_SetToInSeason();
	end
end

function PVPTeam_Update()
	local button, buttonName, highlight, data, standard, emblem, border;
	local teamName, teamSize, teamRating, teamPlayed, teamWins, teamLoss, seasonTeamPlayed, seasonTeamWins, playerPlayed, seasonPlayerPlayed, playerPlayedPct, teamRank, playerRating;
	local played, wins, loss;
	local background = {};
	local borderColor = {};
	local emblemColor = {};
	local ARENA_TEAMS = {};
	ARENA_TEAMS[1] = {size = 2};
	ARENA_TEAMS[2] = {size = 3};
	ARENA_TEAMS[3] = {size = 5};

	local count = 0;
	local buttonIndex = 0;
	for index, value in pairs(ARENA_TEAMS) do
		for i=1, MAX_ARENA_TEAMS do
			teamName, teamSize = GetArenaTeam(i);
			if ( value.size == teamSize ) then
				value.index = i;
			end
		end
	end

	for index, value in pairs(ARENA_TEAMS) do
		buttonIndex = buttonIndex + 1;
		button = _G["PVPTeam"..buttonIndex];
		if ( value.index ) then
			teamName, teamSize, teamRating, teamPlayed, teamWins, seasonTeamPlayed, seasonTeamWins, playerPlayed, seasonPlayerPlayed, teamRank, playerRating, background.r, background.g, background.b, emblem, emblemColor.r, emblemColor.g, emblemColor.b, border, borderColor.r, borderColor.g, borderColor.b = GetArenaTeam(value.index);

			buttonName = "PVPTeam"..buttonIndex;
			data = buttonName.."Data";
			standard = buttonName.."Standard";

			button:SetID(value.index);
			
			if ( PVPFrame.seasonStats ) then
				_G[data.."TypeLabel"]:SetText(ARENA_THIS_SEASON);
				PVPFrameToggleButton:SetText(ARENA_THIS_WEEK_TOGGLE);
				played = seasonTeamPlayed;
				wins = seasonTeamWins;
				playerPlayed = seasonPlayerPlayed;
			else
				_G[data.."TypeLabel"]:SetText(ARENA_THIS_WEEK);
				PVPFrameToggleButton:SetText(ARENA_THIS_SEASON_TOGGLE);
				played = teamPlayed;
				wins = teamWins;
				playerPlayed = playerPlayed;
			end

			loss = played - wins;
			if ( played ~= 0 ) then
				playerPlayedPct = floor( ( playerPlayed / played ) * 100 );		
			else
				playerPlayedPct = floor( ( playerPlayed / 1 ) * 100 );
			end

			_G[data.."Name"]:SetText(teamName);
			_G[data.."Rating"]:SetText(teamRating);
			_G[data.."Games"]:SetText(played);
			_G[data.."Wins"]:SetText(wins);
			_G[data.."Loss"]:SetText(loss);
			
			if ( PVPFrame.seasonStats ) then
				_G[data.."Played"]:SetText(playerRating);
				_G[data.."Played"]:SetVertexColor(1.0, 1.0, 1.0);
				_G[data.."PlayedLabel"]:SetText(PVP_YOUR_RATING);
			else
				if ( playerPlayedPct < 10 ) then
					_G[data.."Played"]:SetVertexColor(1.0, 0, 0);
				else
					_G[data.."Played"]:SetVertexColor(1.0, 1.0, 1.0);
				end
				playerPlayedPct = format("%d", playerPlayedPct);
				_G[data.."Played"]:SetText(playerPlayed.." ("..playerPlayedPct.."%)");
				_G[data.."PlayedLabel"]:SetText(PLAYED);
			end

			_G[standard.."Banner"]:SetTexture("Interface\\PVPFrame\\PVP-Banner-"..teamSize);
			_G[standard.."Banner"]:SetVertexColor(background.r, background.g, background.b);
			_G[standard.."Border"]:SetVertexColor(borderColor.r, borderColor.g, borderColor.b);
			_G[standard.."Emblem"]:SetVertexColor(emblemColor.r, emblemColor.g, emblemColor.b);
			if ( border ~= -1 ) then
				_G[standard.."Border"]:SetTexture("Interface\\PVPFrame\\PVP-Banner-"..teamSize.."-Border-"..border);
			end
			if ( emblem ~= -1 ) then
				_G[standard.."Emblem"]:SetTexture("Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-"..emblem);
			end

			_G[data]:Show();
			button:SetAlpha(1);
			_G[buttonName.."Highlight"]:SetAlpha(1);
			_G[buttonName.."Highlight"]:SetBackdropBorderColor(1.0, 0.82, 0);
			_G[standard]:SetAlpha(1);
			_G[standard.."Border"]:Show();
			_G[standard.."Emblem"]:Show();
			_G[buttonName.."Background"]:SetVertexColor(0, 0, 0);
			_G[buttonName.."Background"]:SetAlpha(1);
			_G[buttonName.."TeamType"]:Hide();
		else
			buttonName = "PVPTeam"..buttonIndex;
			data = buttonName.."Data";
			
			button:SetID(0);

			local standardBanner = _G[buttonName.."StandardBanner"];
			standardBanner:SetTexture("Interface\\PVPFrame\\PVP-Banner-"..value.size);
			standardBanner:SetVertexColor(1, 1, 1);

			button:SetAlpha(0.4);
			_G[data]:Hide();
			_G[buttonName.."Background"]:SetVertexColor(0, 0, 0);
			_G[buttonName.."Standard"]:SetAlpha(0.1);
			_G[buttonName.."StandardBorder"]:Hide();
			_G[buttonName.."StandardEmblem"]:Hide();
			_G[buttonName.."TeamType"]:SetFormattedText(PVP_TEAMSIZE, value.size, value.size);
			_G[buttonName.."TeamType"]:Show();
		end
		count = count + 1;
	end
	
	if ( count == 3 ) then
		PVPFrameToggleButton:Hide();
	else
		PVPFrameToggleButton:Show();
	end
end

function PVPTeam_OnEnter(self)
	if ( GetArenaTeam(self:GetID() ) ) then
		_G[self:GetName().."Highlight"]:Show();
		GameTooltip_AddNewbieTip(self, ARENA_TEAM, 1.0, 1.0, 1.0, CLICK_FOR_DETAILS, 1);
	else
		GameTooltip_AddNewbieTip(self, ARENA_TEAM, 1.0, 1.0, 1.0, ARENA_TEAM_LEAD_IN, 1);
	end		
end

function PVPTeam_OnLeave(self)
	_G[self:GetName().."Highlight"]:Hide();	
	GameTooltip:Hide();
end

function PVPTeamDetails_OnShow()
	PlaySound("igSpellBookOpen");
end

function PVPTeamDetails_OnHide()
	CloseArenaTeamRoster();
	PlaySound("igSpellBookClose");
end

function PVPTeamDetails_Update(id)
	local numMembers = GetNumArenaTeamMembers(id, 1);
	local name, rank, level, class, online, played, win, loss, seasonPlayed, seasonWin, seasonLoss, rating;
	local teamName, teamSize, teamRating, teamPlayed, teamWins, seasonTeamPlayed, seasonTeamWins, playerPlayed, seasonPlayerPlayed, teamRank, personalRating = GetArenaTeam(id);		
	local button;
	local teamIndex;

	PVPTeamDetailsName:SetText(teamName);
	PVPTeamDetailsSize:SetFormattedText(PVP_TEAMSIZE, teamSize, teamSize);
	PVPTeamDetailsRank:SetText(teamRank);
	PVPTeamDetailsRating:SetText(teamRating);
	
	PVPTeamDetailsName:SetWidth(0);
	if ( PVPTeamDetailsName:GetWidth() > MAX_ARENA_TEAM_NAME_WIDTH ) then
		PVPTeamDetailsName:SetWidth(MAX_ARENA_TEAM_NAME_WIDTH);
	end
	
	if ( PVPTeamDetails.season ) then
		PVPTeamDetailsFrameColumnHeader3.sortType = "seasonplayed";
		PVPTeamDetailsFrameColumnHeader4.sortType = "seasonwon";
		PVPTeamDetailsGames:SetText(seasonTeamPlayed);
		PVPTeamDetailsWins:SetText(seasonTeamWins);
		PVPTeamDetailsLoss:SetText(seasonTeamPlayed - seasonTeamWins);
		PVPTeamDetailsStatsType:SetText(strupper(ARENA_THIS_SEASON));
		PVPTeamDetailsToggleButton:SetText(ARENA_THIS_WEEK_TOGGLE);
	else
		PVPTeamDetailsFrameColumnHeader3.sortType = "played";
		PVPTeamDetailsFrameColumnHeader4.sortType = "won";
		PVPTeamDetailsGames:SetText(teamPlayed);
		PVPTeamDetailsWins:SetText(teamWins);
		PVPTeamDetailsLoss:SetText(teamPlayed - teamWins);
		PVPTeamDetailsStatsType:SetText(strupper(ARENA_THIS_WEEK));
		PVPTeamDetailsToggleButton:SetText(ARENA_THIS_SEASON_TOGGLE);
	end

	local nameText, classText, playedText, winLossWin, winLossLoss, ratingText;
	local nameButton, classButton, playedButton, winLossButton;
	local playedValue, winValue, lossValue, playedPct;
	
	for i=1, MAX_ARENA_TEAM_MEMBERS, 1 do
		button = _G["PVPTeamDetailsButton"..i];
		if ( i > numMembers ) then
			button:Hide();
		else
			button.teamIndex = i;
			name, rank, level, class, online, played, win, seasonPlayed, seasonWin, rating = GetArenaTeamRosterInfo(id, i);
			loss = played - win;
			seasonLoss = seasonPlayed - seasonWin;
			if ( class ) then
				button.tooltip = LEVEL.." "..level.." "..class;
			else
				button.tooltip = LEVEL.." "..level;
			end

			if ( PVPTeamDetails.season ) then
				playedValue = seasonPlayed;
				winValue = seasonWin;
				lossValue = seasonLoss;
				teamPlayed = seasonTeamPlayed;
			else
				playedValue = played;
				winValue = win;
				lossValue = loss;
				teamPlayed = teamPlayed;
			end

			if ( teamPlayed ~= 0 ) then
				playedPct = floor( ( playedValue / teamPlayed ) * 100 );		
			else
				playedPct = floor( (playedValue / 1 ) * 100 );
			end

			if ( playedPct < 10 ) then
				_G["PVPTeamDetailsButton"..i.."PlayedText"]:SetVertexColor(1.0, 0, 0);
			else
				_G["PVPTeamDetailsButton"..i.."PlayedText"]:SetVertexColor(1.0, 1.0, 1.0);
			end
			
			playedPct = format("%d", playedPct);
			_G["PVPTeamDetailsButton"..i.."Played"].tooltip = playedPct.."%";

			nameText = _G["PVPTeamDetailsButton"..i.."NameText"];
			classText = _G["PVPTeamDetailsButton"..i.."ClassText"];
			playedText = _G["PVPTeamDetailsButton"..i.."PlayedText"]
			winLossWin = _G["PVPTeamDetailsButton"..i.."WinLossWin"];
			winLossLoss = _G["PVPTeamDetailsButton"..i.."WinLossLoss"];
			ratingText = _G["PVPTeamDetailsButton"..i.."RatingText"];

			nameButton = _G["PVPTeamDetailsButton"..i.."Name"];
			classButton = _G["PVPTeamDetailsButton"..i.."Class"];
			playedButton = _G["PVPTeamDetailsButton"..i.."Played"]
			winLossButton = _G["PVPTeamDetailsButton"..i.."WinLoss"];

			nameText:SetText(name);
			classText:SetText(class);
			playedText:SetText(playedValue);
			winLossWin:SetText(winValue)
			winLossLoss:SetText(lossValue);
			ratingText:SetText(rating);
		
			local r, g, b;
			if ( online ) then
				if ( rank > 0 ) then
					r = 1.0;
					g = 1.0;
					b = 1.0;
				else
					r = 1.0;
					g = 0.82;
					b = 0.0;
				end
			else
				r = 0.5;
				g = 0.5;
				b = 0.5;
			end

			nameText:SetTextColor(r, g, b);
			classText:SetTextColor(r, g, b);
			playedText:SetTextColor(r, g, b);
			winLossWin:SetTextColor(r, g, b);
			_G["PVPTeamDetailsButton"..i.."WinLoss-"]:SetTextColor(r, g, b);
			winLossLoss:SetTextColor(r, g, b);
			ratingText:SetTextColor(r, g, b);

			button:Show();

			if ( GetArenaTeamRosterSelection(id) == i ) then
				button:LockHighlight();
			else
				button:UnlockHighlight();
			end
		end
	end
end

function PVPTeamDetailsToggleButton_OnClick()
	if ( PVPTeamDetails.season ) then
		PVPTeamDetails.season = nil;
	else
		PVPTeamDetails.season = 1;		
	end
	PVPTeamDetails_Update(PVPTeamDetails.team);
end

function PVPFrameToggleButton_OnClick()
	if ( PVPFrame.seasonStats ) then
		PVPFrame.seasonStats = nil;
	else
		PVPFrame.seasonStats = 1;		
	end
	PVPTeam_Update();
end

function PVPTeamDetailsButton_OnClick(self, button)
	if ( button == "LeftButton" ) then
		PVPTeamDetails.previousSelectedTeamMember = PVPTeamDetails.selectedTeamMember;
		PVPTeamDetails.selectedTeamMember = self.teamIndex;
		SetArenaTeamRosterSelection(PVPTeamDetails.team, PVPTeamDetails.selectedTeamMember);
		PVPTeamDetails_Update(PVPTeamDetails.team);
	else
		local name, rank, level, class, online = GetArenaTeamRosterInfo(PVPTeamDetails.team, self.teamIndex);
		PVPFrame_ShowDropdown(name, online);
	end
end

function PVPDropDown_Initialize()
	UnitPopup_ShowMenu(UIDROPDOWNMENU_OPEN_MENU, "TEAM", nil, PVPDropDown.name);
end

function PVPFrame_ShowDropdown(name, online)
	HideDropDownMenu(1);
	
	if ( not IsArenaTeamCaptain(PVPTeamDetails.team) ) and ( not online ) then
		return;
	end

	PVPDropDown.initialize = PVPDropDown_Initialize;
	PVPDropDown.displayMode = "MENU";
	PVPDropDown.name = name;
	PVPDropDown.online = online;
	ToggleDropDownMenu(1, nil, PVPDropDown, "cursor");
end

function PVPStandard_OnLoad(self)
	self:SetAlpha(0.1);
end

function PVPTeam_OnClick(self)
	local id = self:GetID();

	local teamName, teamSize = GetArenaTeam(id);
	if ( not teamName ) then
		return;
	else
		if ( PVPTeamDetails:IsShown() and id == PVPTeamDetails.team ) then
			PVPTeamDetails:Hide();
		else
			PVPTeamDetails.team = id;
			ArenaTeamRoster(id);
			PVPTeamDetails_Update(id);
			PVPTeamDetails:Show();
		end
	end
end

function PVPTeam_OnMouseDown(self)
	if ( GetArenaTeam(self:GetID()) and (not self.isDown) ) then
		self.isDown = true;
		local point, relativeTo, relativePoint, offsetX, offsetY = self:GetPoint();
		self:SetPoint(point, relativeTo, relativePoint, offsetX-2, offsetY-2);
	end
end

function PVPTeam_OnMouseUp(self)
	if ( GetArenaTeam(self:GetID()) and (self.isDown) ) then
		self.isDown = false;
		local point, relativeTo, relativePoint, offsetX, offsetY = self:GetPoint();
		self:SetPoint(point, relativeTo, relativePoint, offsetX+2, offsetY+2);
	end
end

function PVPHonor_Update()
	local hk, contribution = GetPVPYesterdayStats();
	PVPHonorYesterdayKills:SetText(hk);
	PVPHonorYesterdayHonor:SetText(contribution);

	hk = GetPVPLifetimeStats();
	PVPHonorLifetimeKills:SetText(hk);
	PVPFrameHonorPoints:SetText(GetHonorCurrency());
	PVPFrameArenaPoints:SetText(GetArenaCurrency());

	-- Actualiza la barra visual de honor añadida encima de conquista.
	if PVPFrameHonorLimitBar and PVPFrameHonorLimitBarText then
		local currentHonor = GetHonorCurrency and GetHonorCurrency() or 0;
		local honorCap = MAX_HONOR_POINTS or 75000;
		if currentHonor > honorCap then
			honorCap = currentHonor;
		end
		PVPFrameHonorLimitBar:SetMinMaxValues(0, honorCap);
		PVPFrameHonorLimitBar:SetValue(currentHonor);
		PVPFrameHonorLimitBarText:SetText(currentHonor.." / "..honorCap);
	end
	
	local sessionHK, sessionHonor = GetPVPSessionStats();
	PVPHonorTodayKills:SetText(sessionHK);
	PVPHonorTodayHonor:SetText(sessionHonor);
	PVPHonorTodayHonor:SetHeight(14);
end

function PVPMicroButton_SetPushed()
	PVPMicroButtonTexture:SetPoint("TOP", PVPMicroButton, "TOP", 5, -31);
	PVPMicroButtonTexture:SetAlpha(0.5);
end

function PVPMicroButton_SetNormal()
	PVPMicroButtonTexture:SetPoint("TOP", PVPMicroButton, "TOP", 6, -30);
	PVPMicroButtonTexture:SetAlpha(1.0);
end

function PVPFrame_SetToOffSeason()
    PVPTeam1:Hide();
    PVPTeam1Standard:Hide();
    PVPTeam2:Hide();
    PVPTeam2Standard:Hide();
    PVPTeam3:Hide();
    PVPTeam3Standard:Hide();
    
    if PVPFrameBlackFilter then
        PVPFrameBlackFilter:Show();
    end
    
    local previousArenaSeason = GetPreviousArenaSeason();
    if PVPFrameOffSeasonText then
        PVPFrameOffSeasonText:SetText(format(ARENA_OFF_SEASON_TEXT, previousArenaSeason, previousArenaSeason+1));
    end
    if PVPFrameOffSeason then
        PVPFrameOffSeason:Show();
    end
end

function PVPFrame_SetToInSeason()
    PVPTeam1:Show();
    PVPTeam1Standard:Show();
    PVPTeam2:Show();
    PVPTeam2Standard:Show();
    PVPTeam3:Show();
    PVPTeam3Standard:Show();
    
    if PVPFrameBlackFilter then
        PVPFrameBlackFilter:Hide();
    end
    if PVPFrameOffSeason then
        PVPFrameOffSeason:Hide();
    end
end

function TogglePVPFrame()
    if ( PVPFrame_IsJustBG() ) then
        PVPFrame_SetJustBG(false);
    else
        if ( UnitLevel("player") >= SHOW_PVP_LEVEL ) then
            ToggleFrame(PVPParentFrame);
            if PVPParentFrame:IsShown() then
                PVPFrame_SetPortrait();
            end
        end
    end
end

function PVPFrame_IsJustBG()
	return PVPParentFrame.justBG;
end

function PVPFrame_SetJustBG(justBG)
	local pvpParentFrame = PVPParentFrame;
	if ( justBG ) then
		pvpParentFrame.justBG = true;
		pvpParentFrame.savedSelectedTab = PanelTemplates_GetSelectedTab(pvpParentFrame);
		PVPParentFrameTab2:Click();
		PVPParentFrameTab1:Hide();
		PVPParentFrameTab2:Hide();
		UpdateMicroButtons();
	else
		pvpParentFrame.justBG = false;
		if ( pvpParentFrame.savedSelectedTab ) then
			_G["PVPParentFrameTab"..pvpParentFrame.savedSelectedTab]:Click();
			pvpParentFrame.savedSelectedTab = nil;
		end
		CloseBattlefield();
		PVPBattlegroundFrame_UpdateVisible();
		UpdateMicroButtons();
	end
end

function PVPParentFrame_ShowTab(tabID)
	if tabID == 1 then
		if LFDParentFrame_ShowTab then
			LFDParentFrame_ShowTab(1)
		end
	elseif tabID == 2 then
		PVPFrame:Show()
		if PVPBattlegroundFrame then
			PVPBattlegroundFrame:Hide()
		end
		if PVPParentFramePvPButton then
			PVPParentFramePvPButton.selection:Show()
		end
		if PVPParentFrameBattlegroundButton then
			PVPParentFrameBattlegroundButton.selection:Hide()
		end
		PVPFrame_SetPortrait()
		UpdateMicroButtons()
	end
end

function ToggleLFDParentFrame()
	if LFDParentFrame:IsShown() or PVPParentFrame:IsShown() then
		HideUIPanel(LFDParentFrame)
		HideUIPanel(PVPParentFrame)
	else
		ShowUIPanel(LFDParentFrame)
	end
	UpdateMicroButtons()
end
-- ====================================================================
-- BATTLEGROUND FRAME FUNCTIONS
-- ====================================================================
function PVPBattlegroundFrame_BGDropDown_Initialize()
	UIDropDownMenu_Initialize(PVPBattlegroundFrameBGDropDown, function(self, level)
		local info = UIDropDownMenu_CreateInfo();
		local numBGs = GetNumBattlegroundTypes();
		
		for i = 1, numBGs do
			local displayName = GetBattlegroundDisplayName(i);
			if displayName then
				info.text = displayName;
				info.value = i;
				info.func = function()
					PVPBattlegroundFrame_SelectBattlegroundFromDropdown(i);
				end;
				info.checked = (PVPBattlegroundFrame.selectedBG == i);
				UIDropDownMenu_AddButton(info);
			end
		end
	end);
	
	UIDropDownMenu_SetWidth(PVPBattlegroundFrameBGDropDown, 180);

	if PVPBattlegroundFrame.selectedBG then
		local displayName = GetBattlegroundDisplayName(PVPBattlegroundFrame.selectedBG);
		if displayName then
			UIDropDownMenu_SetText(PVPBattlegroundFrameBGDropDown, displayName);
			return;
		end
		PVPBattlegroundFrame.selectedBG = nil;
	end

	local firstBG = GetFirstAvailableBattlegroundIndex();
	if firstBG then
		PVPBattlegroundFrame_SelectBattlegroundFromDropdown(firstBG);
	end
end

function PVPBattlegroundFrame_SelectBattlegroundFromDropdown(bgIndex)
	local displayName = GetBattlegroundDisplayName(bgIndex);
	if not displayName then
		return;
	end
	
	PVPBattlegroundFrame.selectedBG = bgIndex;
	UIDropDownMenu_SetText(PVPBattlegroundFrameBGDropDown, displayName);

	PVPBattleground_ResetInfo();
	PVPBattleground_UpdateJoinButton();
	PVPBattlegroundFrame_UpdateGroupAvailable();
end

function PVPBattleground_UpdateInfo(BGindex)
    if not BGindex then
        BGindex = PVPBattlegroundFrame.selectedBG;
    end
    
    if not BGindex then
        return;
    end
    
    local BGname, canEnter, isHoliday, isRandom, BattleGroundID = GetBattlegroundInfo(BGindex);
    
    if not BGname then
        return;
    end

    if BattleGroundID and PVPBATTLEGROUND_TEXTURELIST[BattleGroundID] then
        PVPBattlegroundFrameBGTex:SetTexture(PVPBATTLEGROUND_TEXTURELIST[BattleGroundID]);
    else
        PVPBattlegroundFrameBGTex:SetTexture("Interface\\PVPFrame\\PvpRandomBg");
    end

    if (isRandom or isHoliday) then
        if PVPQueue_UpdateRandomInfo and PVPBattlegroundFrameInfoScrollFrameChildFrameRewardsInfo then
            PVPQueue_UpdateRandomInfo(PVPBattlegroundFrameInfoScrollFrameChildFrameRewardsInfo, function()
                return GetBattlegroundInfo(BGindex);
            end);
        end
        
        PVPBattlegroundFrameInfoScrollFrameChildFrameRewardsInfo:Show();
        PVPBattlegroundFrameInfoScrollFrameChildFrameDescription:Hide();
    else
        local mapName, mapDescription, maxGroup = GetBattlefieldInfo();
        
        if mapDescription and mapDescription ~= PVPBattlegroundFrameInfoScrollFrameChildFrameDescription:GetText() then
            PVPBattlegroundFrameInfoScrollFrameChildFrameDescription:SetText(mapDescription);
            PVPBattlegroundFrameInfoScrollFrameChildFrameDescription:SetTextColor(1.0, 1.0, 1.0);
            PVPBattlegroundFrameInfoScrollFrameChildFrameDescription:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE");
            PVPBattlegroundFrameInfoScrollFrame:SetVerticalScroll(0);
        end
        
        PVPBattlegroundFrameInfoScrollFrameChildFrameRewardsInfo:Hide();
        PVPBattlegroundFrameInfoScrollFrameChildFrameDescription:Show();
    end
end

function PVPBattleground_GetSelectedBattlegroundInfo()
	if not PVPBattlegroundFrame.selectedBG then
		return;
	end
	return GetBattlegroundInfo(PVPBattlegroundFrame.selectedBG);
end

function PVPBattleground_UpdateRandomInfo()
	if not PVPBattlegroundFrame.selectedBG then
		return;
	end
	
	if PVPQueue_UpdateRandomInfo and PVPBattlegroundFrameInfoScrollFrameChildFrameRewardsInfo then
		PVPQueue_UpdateRandomInfo(PVPBattlegroundFrameInfoScrollFrameChildFrameRewardsInfo, PVPBattleground_GetSelectedBattlegroundInfo);
	end
end

function PVPBattleground_ResetInfo()
	if not PVPBattlegroundFrame.selectedBG then
		return;
	end
	
	RequestBattlegroundInstanceInfo(PVPBattlegroundFrame.selectedBG);
	PVPBattleground_UpdateInfo();
end

function PVPBattleground_UpdateJoinButton()
	if not PVPBattlegroundFrame.selectedBG then
		return;
	end
	
	local _, _, maxGroup = GetBattlefieldInfo();
	if maxGroup and maxGroup == 5 then
		PVPBattlegroundFrameGroupJoinButton:SetText(JOIN_AS_PARTY);
	else
		PVPBattlegroundFrameGroupJoinButton:SetText(JOIN_AS_GROUP);
	end
end

function PVPBattlegroundFrameJoinButton_OnClick(self)
	local joinAsGroup;
	if self == PVPBattlegroundFrameGroupJoinButton then
		joinAsGroup = true;
	end
	
	JoinBattlefield(0, joinAsGroup);
end

local function PVPHonorLimit_CreateBar()
	if not PVPFrameHonorLimit or PVPFrameHonorLimit.honorBar then return; end

	local honorFrame = CreateFrame("Frame", nil, PVPFrameHonorLimit, "InsetFrameTemplateNoBackground");
	honorFrame:SetPoint("TOPLEFT", 10, -24);
	honorFrame:SetPoint("BOTTOMRIGHT", -10, 7);

	local honorBar = CreateFrame("StatusBar", "PVPFrameHonorLimitBar", honorFrame);
	honorBar:SetPoint("TOPLEFT", 20, -4);
	honorBar:SetPoint("BOTTOMRIGHT", -20, 4);
	local barTexture = honorBar:CreateTexture(nil, "BACKGROUND");
	barTexture:SetAllPoints();
	barTexture:SetTexture("Interface\\PVPFrame\\PvPQueue");
	barTexture:SetTexCoord(0.251953125, 0.500976563, 0.000000000, 0.020000000);
	honorBar:SetStatusBarTexture(barTexture);

	local overlay = CreateFrame("Frame", nil, honorBar);
	overlay:SetPoint("TOPLEFT", honorBar, "TOPLEFT", 0, 10);
	overlay:SetPoint("BOTTOMRIGHT", honorBar, "BOTTOMRIGHT", 0, -10);

	local left = overlay:CreateTexture(nil, "OVERLAY");
	left:SetPoint("LEFT", overlay, "LEFT", -5, 0);
	left:SetPoint("TOP", overlay, "TOP", 0, 0);
	left:SetPoint("BOTTOM", overlay, "BOTTOM", 0, 0);
	left:SetWidth(16);
	left:SetTexture("Interface\\PVPFrame\\PvPQueue");
	left:SetTexCoord(0.000000000, 0.030000000, 0.955078125, 0.999023438);

	local center = overlay:CreateTexture(nil, "OVERLAY");
	center:SetPoint("LEFT", left, "RIGHT", 0, 0);
	center:SetPoint("RIGHT", overlay, "RIGHT", 0, 0);
	center:SetPoint("TOP", overlay, "TOP", 0, 0);
	center:SetPoint("BOTTOM", overlay, "BOTTOM", 0, 0);
	center:SetTexture("Interface\\PVPFrame\\PvPQueue");
	center:SetTexCoord(0.045898438, 0.295390625, 0.955078125, 0.999023438);
	center:SetHorizTile(true);

	local right = overlay:CreateTexture(nil, "OVERLAY");
	right:SetPoint("RIGHT", overlay, "RIGHT", 5, 0);
	right:SetPoint("TOP", overlay, "TOP", 0, 0);
	right:SetPoint("BOTTOM", overlay, "BOTTOM", 0, 0);
	right:SetWidth(16);
	right:SetTexture("Interface\\PVPFrame\\PvPQueue");
	right:SetTexCoord(0.030000000, 0.000000000, 0.955078125, 0.999023438);

	local honorText = honorBar:CreateFontString("PVPFrameHonorLimitBarText", "OVERLAY", "GameFontHighlightSmall");
	honorText:SetPoint("CENTER");

	PVPFrameHonorLimit.honorFrame = honorFrame;
	PVPFrameHonorLimit.honorBar = honorBar;
	PVPFrameHonorLimit.honorText = honorText;
end

function PVPBattlegroundFrame_OnLoad(self)
	if PVPFrameHonorLimit then
		PVPFrameHonorLimit:SetParent(self);
		PVPFrameHonorLimit:ClearAllPoints();
		PVPFrameHonorLimit:SetPoint("TOPLEFT", PVPParentFrame, "TOPLEFT", 220, -28);
		PVPFrameHonorLimit:SetSize(335, 55);
		PVPHonorLimit_CreateBar();
	end
	if WintergraspTimer then
		WintergraspTimer:ClearAllPoints();
		WintergraspTimer:SetPoint("TOPLEFT", PVPParentFrame, "TOPLEFT", 220, -87);
		WintergraspTimer:SetSize(335, 55);
	end

	self:RegisterEvent("PVPQUEUE_ANYWHERE_SHOW");
	self:RegisterEvent("NPC_PVPQUEUE_ANYWHERE");
	self:RegisterEvent("UPDATE_BATTLEFIELD_STATUS");
	self:RegisterEvent("PVPQUEUE_ANYWHERE_UPDATE_AVAILABLE");
	self:RegisterEvent("PLAYER_ENTERING_WORLD");
	self:RegisterEvent("PARTY_MEMBERS_CHANGED");
	
	PanelTemplates_SetTab(PVPParentFrame, 1);
	PVPBattlegroundFrame_UpdateVisible();

	PVPBattlegroundFrame_BGDropDown_Initialize();
end

function PVPBattlegroundFrame_OnEvent(self, event, ...)
	if event == "PVPQUEUE_ANYWHERE_SHOW" or event == "NPC_PVPQUEUE_ANYWHERE" then
		self.currentData = true;
		PVPBattlegroundFrame_BGDropDown_Initialize();
		
		if self.selectedBG then
			PVPBattleground_UpdateInfo();
		end
		
		if event == "NPC_PVPQUEUE_ANYWHERE" then
			ShowUIPanel(PVPParentFrame);
			PVPFrame_SetJustBG(true);
		end
	elseif event == "PVPQUEUE_ANYWHERE_UPDATE_AVAILABLE" or event == "PLAYER_ENTERING_WORLD" then
		self:UnregisterEvent("PLAYER_ENTERING_WORLD");
		PVPBattlegroundFrame_BGDropDown_Initialize();
		
		if self.selectedBG then
			PVPBattleground_ResetInfo();
			PVPBattleground_UpdateJoinButton();
		end
		PVPBattlegroundFrame_UpdateVisible();
	elseif event == "PARTY_MEMBERS_CHANGED" then
		PVPBattlegroundFrame_UpdateGroupAvailable();
	end
end

function PVPBattlegroundFrame_OnShow(self)
	PVPHonor_Update();
    if IsInInstance() then
        WintergraspTimer:Hide();
    else
        WintergraspTimer:Show();
    end
    
    SortBGList();
    PVPBattlegroundFrame_BGDropDown_Initialize();
    
    if self.selectedBG then
        RequestBattlegroundInstanceInfo(self.selectedBG);
    end
    PVPBattlegroundFrame_UpdateGroupAvailable();
	ConfigurePVPBattlegroundInfoScrollFrame();
    PVPFrame_SetPortrait();
end

function PVPParentFrame_SetPortrait()
    -- Esta función vacía previene que el template sobrescriba nuestro retrato personalizado
end

function PVPBattlegroundFrame_OnHide(self)
	CloseBattlefield();
end

function RaiseFrameLevelByThree(frame)
    if frame then
        frame:SetFrameLevel(frame:GetFrameLevel() + 3);
    end
end

function PVPBattlegroundFrame_UpdateVisible()
    if not PVPParentFrame then
        return;
    end

	if GetFirstAvailableBattlegroundIndex() then
		if not PVPFrame_IsJustBG() then
			if PVPParentFrameTab1 then
				PVPParentFrameTab1:Show();
			end
			if PVPParentFrameTab2 then
				PVPParentFrameTab2:Show();
			end
		end
		return;
	end

    if PVPParentFrameTab1 and PVPParentFrameTab1.Click then
        PVPParentFrameTab1:Click();
    end

    if PVPParentFrameTab1 then
        PVPParentFrameTab1:Hide();
    end
    if PVPParentFrameTab2 then
        PVPParentFrameTab2:Hide();
    end
end

function PVPBattlegroundFrame_UpdateGroupAvailable()
	if ((GetNumPartyMembers() > 0) or (GetNumRaidMembers() > 0)) and IsPartyLeader() then
		PVPBattlegroundFrameGroupJoinButton:Enable();
	else
		PVPBattlegroundFrameGroupJoinButton:Disable();
	end
end

function WintergraspTimer_OnLoad(self)
	self.canQueue = false;
	self.tooltip = PVPBATTLEGROUND_WINTERGRASPTIMER_CANNOT_QUEUE;
	self.texture:SetTexCoord(0.0, 1.0, 0.0, 0.5);
	if self.title then
		self.title:SetText(WINTERGRASP);
	end
	if self.hover then
		self.hover:Hide();
	end
end

function WintergraspTimer_OnUpdate(self, elapsed)
	local nextBattleTime = GetWintergraspWaitTime();
	if nextBattleTime and nextBattleTime > 60 then
		self.text:SetText(SecondsToTime(nextBattleTime, true));
	elseif nextBattleTime and nextBattleTime > 0 then
		self.text:SetText(SecondsToTime(nextBattleTime, false));
	else
		self.text:SetText(WINTERGRASP_IN_PROGRESS);
	end

	local canQueue = CanQueueForWintergrasp();
	if self.canQueue ~= canQueue then
		if canQueue then
			self.tooltip = PVPBATTLEGROUND_WINTERGRASPTIMER_CAN_QUEUE;
			self.texture:SetTexCoord(0.0, 1.0, 0.5, 1.0);
		else
			self.tooltip = PVPBATTLEGROUND_WINTERGRASPTIMER_CANNOT_QUEUE;
			self.texture:SetTexCoord(0.0, 1.0, 0.0, 0.5);
		end
		self.canQueue = canQueue;
	end
end
