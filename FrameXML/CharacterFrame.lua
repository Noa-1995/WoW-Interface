CHARACTERFRAME_SUBFRAMES = { "PaperDollFrame", "PetPaperDollFrame", "ReputationFrame", "SkillFrame", "TokenFrame" };
local NUM_CHARACTERFRAME_TABS = 5;

PANEL_DEFAULT_WIDTH = 350
CHARACTERFRAME_EXPANDED_WIDTH = 606 - 55;
CHARACTERFRAME_EXPANDED_HEIGHT = 430

function ToggleCharacter (tab)
	local subFrame = _G[tab];
	if ( subFrame ) then
		if (not subFrame.hidden) then
			PanelTemplates_SetTab(CharacterFrame, subFrame:GetID());
			if ( CharacterFrame:IsShown() ) then
				if ( subFrame:IsShown() ) then
					HideUIPanel(CharacterFrame);
				else
					PlaySound("igCharacterInfoTab");
					CharacterFrame_ShowSubFrame(tab);
				end
			else
				ShowUIPanel(CharacterFrame);
				CharacterFrame_ShowSubFrame(tab);
			end
		end
	end
end

function CharacterFrame_ShowSubFrame (frameName)
	for index, value in pairs(CHARACTERFRAME_SUBFRAMES) do
		if ( value == frameName ) then
			_G[value]:Show()
		else
			_G[value]:Hide();	
		end	
	end 
end

function CharacterFrameTab_OnClick (self, button)
	local name = self:GetName();
	
	if ( name == "CharacterFrameTab1" ) then
		ToggleCharacter("PaperDollFrame");
	elseif ( name == "CharacterFrameTab2" ) then
		ToggleCharacter("PetPaperDollFrame");
	elseif ( name == "CharacterFrameTab3" ) then
		ToggleCharacter("ReputationFrame");	
	elseif ( name == "CharacterFrameTab4" ) then
		ToggleCharacter("SkillFrame");	
	elseif ( name == "CharacterFrameTab5" ) then
		ToggleCharacter("TokenFrame");	
	end
	PlaySound("igCharacterInfoTab");
end

function CharacterFrame_OnLoad (self)
	self:RegisterEvent("UNIT_NAME_UPDATE");
	self:RegisterEvent("UNIT_PORTRAIT_UPDATE");
	self:RegisterEvent("PLAYER_PVP_RANK_CHANGED");
	self:RegisterEvent("PLAYER_TALENT_UPDATE");
	self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED");
	self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED");

	SetTextStatusBarTextPrefix(PlayerFrameHealthBar, HEALTH);
	SetTextStatusBarTextPrefix(PlayerFrameManaBar, MANA);
	SetTextStatusBarTextPrefix(MainMenuExpBar, XP);
	TextStatusBar_UpdateTextString(MainMenuExpBar);
	-- Tab Handling code
	PanelTemplates_SetNumTabs(self, NUM_CHARACTERFRAME_TABS);
	PanelTemplates_SetTab(self, 1);
	-- PanelTemplates_DisableTab(self, 2)

	CharacterFrame.TitleText:SetText(UnitPVPName("player"))
	CharacterFrame.TitleText:SetTextColor(1, 1, 1)

	for i = 1, NUM_CHARACTERFRAME_TABS do
		local tab = _G["CharacterFrameTab"..i]
		tab:SetFrameLevel(self:GetFrameLevel() + 2)
	end

	ButtonFrameTemplate_HideButtonBar(CharacterFrame)
end

function CharacterFrame_OnEvent (self, event, ...)
	if ( not self:IsShown() ) then
		return;
	end
	
	local arg1 = ...;
	if ( event == "UNIT_PORTRAIT_UPDATE" ) then
		if ( arg1 == "player" ) then
			if GetSpecName() ~= "" then
				SetSpecializationTexturePortrait();
			else
				SetPortraitTexture(CharacterFramePortrait, arg1);
			end
		end
		return;
	elseif ( event == "UNIT_NAME_UPDATE" ) then
		if ( arg1 == "player" ) then
			CharacterFrame.TitleText:SetText(UnitPVPName(arg1));
		end
		return;
	elseif ( event == "PLAYER_PVP_RANK_CHANGED" ) then
		CharacterFrame.TitleText:SetText(UnitPVPName("player"));
	elseif ( event == "PLAYER_TALENT_UPDATE" or event == "ACTIVE_TALENT_GROUP_CHANGED" or event =="PLAYER_EQUIPMENT_CHANGED" ) then
		SetSpecializationTexturePortrait();
	end
end

function CharacterFrame_OnShow (self)
	PlaySound("igCharacterInfoOpen");
	SetSpecializationTexturePortrait();
	-- SetPortraitTexture(CharacterFrame.portrait, "player");
	-- CharacterNameText:SetText(UnitPVPName("player"));
	CharacterFrame.TitleText:SetText(UnitPVPName("player"))
	UpdateMicroButtons();
	PlayerFrameHealthBar.showNumeric = true;
	PlayerFrameManaBar.showNumeric = true;
	PlayerFrameAlternateManaBar.showNumeric = true;
	MainMenuExpBar.showNumeric = true;
	PetFrameHealthBar.showNumeric = true;
	PetFrameManaBar.showNumeric = true;
	ShowTextStatusBarText(PlayerFrameHealthBar);
	ShowTextStatusBarText(PlayerFrameManaBar);
	ShowTextStatusBarText(PlayerFrameAlternateManaBar);
	ShowTextStatusBarText(MainMenuExpBar);
	ShowTextStatusBarText(PetFrameHealthBar);
	ShowTextStatusBarText(PetFrameManaBar);
	ShowWatchedReputationBarText();
	
	SetButtonPulse(CharacterMicroButton, 0, 1);	--Stop the button pulse
end

function CharacterFrame_OnHide (self)
	PlaySound("igCharacterInfoClose");
	UpdateMicroButtons();
	PlayerFrameHealthBar.showNumeric = nil;
	PlayerFrameManaBar.showNumeric = nil;
	PlayerFrameAlternateManaBar.showNumeric = nil;
	MainMenuExpBar.showNumeric =nil;
	PetFrameHealthBar.showNumeric = nil;
	PetFrameManaBar.showNumeric = nil;
	HideTextStatusBarText(PlayerFrameHealthBar);
	HideTextStatusBarText(PlayerFrameManaBar);
	HideTextStatusBarText(PlayerFrameAlternateManaBar);
	HideTextStatusBarText(MainMenuExpBar);
	HideTextStatusBarText(PetFrameHealthBar);
	HideTextStatusBarText(PetFrameManaBar);
	HideWatchedReputationBarText();
	PaperDollFrame:Show()
end

function CharacterFrame_Collapse()
	CharacterFrame:SetWidth(PANEL_DEFAULT_WIDTH)
	CharacterFrame.Expanded = false
	UpdateUIPanelPositions(CharacterFrame)
	PaperDollFrame_SetLevel()
end

function CharacterFrame_Expand()
	CharacterFrame:SetWidth(CHARACTERFRAME_EXPANDED_WIDTH)
	CharacterFrame:SetHeight(CHARACTERFRAME_EXPANDED_HEIGHT)
	CharacterFrame.Expanded = true
	UpdateUIPanelPositions(CharacterFrame)
	PaperDollFrame_SetLevel()
end

local function CompareFrameSize(frame1, frame2)
	return frame1:GetWidth() > frame2:GetWidth();
end

local CharTabtable = {};
function CharacterFrame_TabBoundsCheck(self)
	if ( string.sub(self:GetName(), 1, 17) ~= "CharacterFrameTab" ) then
		return;
	end
	
	local totalSize = 60;
	for i=1, NUM_CHARACTERFRAME_TABS do
		_G["CharacterFrameTab"..i.."Text"]:SetWidth(0);
		PanelTemplates_TabResize(_G["CharacterFrameTab"..i], 0);
		totalSize = totalSize + _G["CharacterFrameTab"..i]:GetWidth();
	end
	
	local diff = totalSize - 465
	
	if ( diff > 0 and CharacterFrameTab5:IsShown() and CharacterFrameTab2:IsShown()) then
		--Find the biggest tab
		for i=1, NUM_CHARACTERFRAME_TABS do
			CharTabtable[i]=_G["CharacterFrameTab"..i];
		end
		table.sort(CharTabtable, CompareFrameSize);
		
		local i=1;
		while ( diff > 0 and i <= NUM_CHARACTERFRAME_TABS) do
			local tabText = _G[CharTabtable[i]:GetName().."Text"]
			local change = min(10, diff);
			tabText:SetWidth(tabText:GetWidth() - change);
			diff = diff - change;
			PanelTemplates_TabResize(CharTabtable[i], 0);
			i = i+1;
		end
	end
end