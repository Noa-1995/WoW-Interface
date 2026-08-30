INSPECTFRAME_SUBFRAMES = { "InspectPaperDollFrame", "InspectPVPFrame", "InspectTalentFrame", "InspectTalentFrame", "InspectTalentFrame" };
UIPanelWindows["InspectFrame"] = { area = "left", pushable = 3, xOffset = "15", yOffset = "-15", width = 368 };

function InspectFrame_Show( unit )
	HideUIPanel(InspectFrame)
	if ( CanInspect(unit, true) ) then
		NotifyInspect(unit)
		InspectFrame.unit = unit
		InspectSwitchTabs(1)
		ShowUIPanel(InspectFrame)
		InspectFrame_UpdateTalentTab()
	end
end

function InspectFrame_OnLoad( self, ... )
	self:RegisterEvent("PLAYER_TARGET_CHANGED")
	self:RegisterEvent("PARTY_MEMBERS_CHANGED")
	self:RegisterEvent("UNIT_NAME_UPDATE")
	self:RegisterEvent("UNIT_PORTRAIT_UPDATE")
	self.unit = nil

	InspectFrame_LoadUI = function() end
	
	-- Tab Handling code
	PanelTemplates_SetNumTabs(self, 3);
	PanelTemplates_SetTab(self, 1);
end

function InspectFrame_OnUpdate(self)
	if ( not UnitIsVisible(self.unit) ) then
		HideUIPanel(InspectFrame)
	end
end

function InspectFrame_OnEvent(self, event, ...)
	if ( not self:IsShown() ) then
		return
	end
	if ( event == "PLAYER_TARGET_CHANGED" or event == "PARTY_MEMBERS_CHANGED" ) then
		if ( (event == "PLAYER_TARGET_CHANGED" and self.unit == "target") or
		     (event == "PARTY_MEMBERS_CHANGED" and self.unit ~= "target") ) then
			if ( CanInspect(self.unit) ) then
				InspectFrame_UnitChanged(self)
			else
				HideUIPanel(InspectFrame)
			end
		end
		return
	elseif ( event == "UNIT_NAME_UPDATE" ) then
		local arg1 = ...
		if ( arg1 == self.unit ) then
			InspectFrameTitleText:SetText(UnitName(arg1))
		end
		return
	elseif ( event == "UNIT_PORTRAIT_UPDATE" ) then
		local arg1 = ...
		if ( arg1 == self.unit ) then
			SetPortraitTexture(InspectFramePortrait, arg1)
		end
		return
	end
end

function InspectFrame_UnitChanged(self)
	local unit = self.unit
	NotifyInspect(unit)
	InspectPaperDollFrame_OnShow(self)
	SetPortraitTexture(InspectFramePortrait, unit)
	InspectFrameTitleText:SetText(UnitName(unit))
	InspectFrame_UpdateTalentTab()
	ButtonFrameTemplate_HideButtonBar(InspectFrame)

	if PanelTemplates_GetSelectedTab(InspectFrame) == 3 then
		ButtonFrameTemplate_ShowButtonBar(InspectFrame)
	end

	if ( InspectPVPFrame:IsShown() ) then
		InspectPVPFrame_OnShow()
	end

	InspectPVPFrame_Update()
	InspectSwitchTabs(1)
end

function InspectFrame_OnShow(self)
	if ( not self.unit ) then
		return
	end

	PlaySound("igCharacterInfoOpen")
	SetPortraitTexture(InspectFramePortrait, self.unit)
	InspectFrameTitleText:SetText(UnitName(self.unit))

	InspectPVPFrame_Update()
	
	-- self.UpdateTimer = C_TimerAug:NewTicker(0.1, InspectPaperDollFrame_UpdateButtons, 5)

	if self.UpdateTimer then
		self.UpdateTimer:Cancel()
		self.UpdateTimer = nil
	end
end

function InspectFrame_OnHide(self)
	self.unit = nil
	PlaySound("igCharacterInfoClose")

	-- Clear the player being inspected
	ClearInspectPlayer()

	-- in the InspectTalentFrame_Update function, a default talent tab is selected smartly if there is no tab selected
	-- it actually ends up feeling natural to have this behavior happen every time the frame is shown
	PanelTemplates_SetTab(InspectTalentFrame, nil)
	
	self.UpdateTimer = C_TimerAug:NewTicker(0.1, InspectPaperDollFrame_UpdateButtons, 5)

	if not self.UpdateTimer then
		self.UpdateTimer:Cancel()
		self.UpdateTimer = nil
	end
end

function InspectPaperDollFrame_OnLoad( self )
	self.equipmentItemsList = {}
	
	self:RegisterEvent("UNIT_INVENTORY_CHANGED")
	self:RegisterEvent("UNIT_MODEL_CHANGED")
	self:RegisterEvent("UNIT_LEVEL")
	self:RegisterEvent("UNIT_PORTRAIT_UPDATE")
	
	InspectFrame.TitleText:SetText(UnitName("target"))
	InspectFrame.TitleText:SetTextColor(1, 1, 1)
	
	-- print(PRETTY_PATCH_LOAD);
end

function InspectPaperDollFrame_OnEvent(self, event, unit)
	if (unit and unit == InspectFrame.unit and InspectFrame:IsShown()) then
		if ( event == "UNIT_INVENTORY_CHANGED" ) then
			InspectPaperDollFrame_SetLevel()
			InspectPaperDollFrame_UpdateButtons()

			if InspectFrame.UpdateTimer then
				InspectFrame.UpdateTimer:Cancel()
				InspectFrame.UpdateTimer = nil
			end

			InspectFrame.UpdateTimer = C_TimerAug:NewTicker(0.1, InspectPaperDollFrame_UpdateButtons, 5)
		elseif ( event == "UNIT_MODEL_CHANGED" ) then
			InspectModelFrame:RefreshUnit()
		elseif ( event == "UNIT_NAME_UPDATE" ) then
			InspectFrame.TitleText:SetText(UnitName(unit))
		elseif ( event == "UNIT_LEVEL" ) then
			InspectPaperDollFrame_SetLevel()
		elseif ( event == "UNIT_PORTRAIT_UPDATE" ) then
			SetPortraitTexture(InspectFramePortrait, unit)
		end
	end
end

function InspectPaperDollFrame_OnShow()
	ButtonFrameTemplate_HideButtonBar(InspectFrame)
	InspectModelFrame:SetUnit(InspectFrame.unit)
	InspectPaperDollFrame_SetLevel()
	InspectPaperDollFrame_UpdateButtons()
	
	InspectFrame.TitleText:SetText(UnitName(InspectFrame.unit))
	SetPortraitTexture(InspectFramePortrait, InspectFrame.unit)

	SetPaperDollBackground(InspectModelFrame, InspectFrame.unit)
	InspectModelFrameBackgroundTopLeft:SetDesaturated(true)
	InspectModelFrameBackgroundTopRight:SetDesaturated(true)
	InspectModelFrameBackgroundBotLeft:SetDesaturated(true)
	InspectModelFrameBackgroundBotRight:SetDesaturated(true)
	
	InspectFrame:SetWidth(CHARACTERFRAME_EXPANDED_WIDTH - 207)
	InspectFrame:SetHeight(CHARACTERFRAME_EXPANDED_HEIGHT)
	
	-- if InspectFrame.UpdateTimer then
		-- InspectFrame.UpdateTimer:Cancel()
		-- InspectFrame.UpdateTimer = nil
	-- end

	-- InspectFrame.UpdateTimer = C_TimerAug:NewTicker(0.1, InspectPaperDollFrame_UpdateButtons, 5)
end

function InspectSwitchTabs(newID)
	local newFrame = _G[INSPECTFRAME_SUBFRAMES[newID]];
	local oldFrame = _G[INSPECTFRAME_SUBFRAMES[PanelTemplates_GetSelectedTab(InspectFrame)]];
	if ( newFrame ) then
		if ( oldFrame ) then
			oldFrame:Hide();
		end
		PanelTemplates_SetTab(InspectFrame, newID);
		ShowUIPanel(InspectFrame);
		newFrame:Show();
	end
end

function InspectFrameTab_OnClick(self)
	PlaySound("igCharacterInfoTab")
	InspectSwitchTabs(self:GetID())
end

function InspectFrame_UpdateTalentTab()
	if ( not InspectFrame.unit ) then
		return;
	end
	local level = UnitLevel(InspectFrame.unit);
	if ( level > 0 and level < 10 ) then
		PanelTemplates_DisableTab(InspectFrame, 3);
		if ( PanelTemplates_GetSelectedTab(InspectFrame) == 3 ) then
			InspectSwitchTabs(1);
		end
	else
		PanelTemplates_EnableTab(InspectFrame, 3);
		InspectTalentFrame_UpdateTabs();
	end
end

function InspectModelFrame_OnUpdate(self, elapsedTime)
	if ( InspectModelRotateLeftButton:GetButtonState() == "PUSHED" ) then
		self.rotation = self.rotation + (elapsedTime * 2 * PI * ROTATIONS_PER_SECOND)
		if ( self.rotation < 0 ) then
			self.rotation = self.rotation + (2 * PI)
		end
		self:SetRotation(self.rotation)
	end
	if ( InspectModelRotateRightButton:GetButtonState() == "PUSHED" ) then
		self.rotation = self.rotation - (elapsedTime * 2 * PI * ROTATIONS_PER_SECOND)
		if ( self.rotation > (2 * PI) ) then
			self.rotation = self.rotation - (2 * PI)
		end
		self:SetRotation(self.rotation)
	end
end

function InspectModelFrame_OnLoad(self)
	self.rotation = 0.61;
	InspectModelFrame:SetRotation(self.rotation);
	self:RegisterEvent("DISPLAY_SIZE_CHANGED");
end

function InspectModelRotateLeftButton_OnClick()
	InspectModelFrame.rotation = InspectModelFrame.rotation - 0.03
	InspectModelFrame:SetRotation(InspectModelFrame.rotation)
	PlaySound("igInventoryRotateCharacter")
end

function InspectModelRotateRightButton_OnClick()
	InspectModelFrame.rotation = InspectModelFrame.rotation + 0.03
	InspectModelFrame:SetRotation(InspectModelFrame.rotation)
	PlaySound("igInventoryRotateCharacter")
end

function InspectPaperDollItemSlotButton_OnLoad( self )
	local slotName = self:GetName()
	local id
	local textureName
	local checkRelic
	id, textureName, checkRelic = GetInventorySlotInfo(strsub(slotName,8))
	self:SetID(id)
	local texture = _G[slotName.."IconTexture"]
	texture:SetTexture(textureName)
	self.backgroundTextureName = textureName
	self.checkRelic = checkRelic
	self.paperDoll = self:GetParent():GetParent()
end

function InspectPaperDollItemSlotButton_OnEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	if ( not GameTooltip:SetInventoryItem(InspectFrame.unit, self:GetID()) ) then
		local text = _G[strupper(strsub(self:GetName(), 8))]
		if ( self.checkRelic and UnitHasRelicSlot(InspectFrame.unit) ) then
			text = _G["RELICSLOT"]
		end
		GameTooltip:SetText(text)
	end
	CursorUpdate(self)

	local itemLink = GetInventoryItemLink(InspectFrame.unit, self:GetID())
	local itemID = GetInventoryItemID(InspectFrame.unit, self:GetID())

	if itemLink and itemID then
		local _, link = GetItemInfo(itemID)
		if tonumber(string.match(itemLink, "item:(%d+)")) ~= itemID then
			GameTooltip:SetTransmogItem(itemID)
		end
	end
end

function InspectPaperDollItemSlotButton_Update(button)
	local unit = InspectFrame.unit

	if unit then
		local textureName = GetInventoryItemTexture(unit, button:GetID())

		if ( textureName ) then
			local link = GetInventoryItemLink(unit, button:GetID())

			if link then
				local itemName, _, quality, _, _, _, _, _, _, originalTexture = GetItemInfo(link)
				if itemName then
					textureName = originalTexture
					button.paperDoll.equipmentItemsList[itemName:lower()] = link
					SetItemButtonQuality(button, quality)
				end
			end

			SetItemButtonTexture(button, textureName)
			SetItemButtonCount(button, GetInventoryItemCount(unit, button:GetID()))
			button.hasItem = 1
		else
			textureName = button.backgroundTextureName
			if ( button.checkRelic and UnitHasRelicSlot(unit) ) then
				textureName = "Interface\\Paperdoll\\UI-PaperDoll-Slot-Relic.blp"
			end
			SetItemButtonQuality(button, nil)
			SetItemButtonTexture(button, textureName)
			SetItemButtonCount(button, 0)
			button.hasItem = nil
		end
		if ( GameTooltip:IsOwned(button) ) then
			if ( textureName ) then
	            if ( not GameTooltip:SetInventoryItem(InspectFrame.unit, button:GetID()) ) then
					GameTooltip:SetText(_G[strupper(strsub(button:GetName(), 8))])
				end
			else
				GameTooltip:Hide()
			end
		end
	end
end

function InspectPaperDollFrame_SetLevel()
	if (not InspectFrame.unit) then
		return
	end
	
	local class, classFilename 			= UnitClass(InspectFrame.unit);
	local unit, level 					= InspectFrame.unit, UnitLevel(InspectFrame.unit)
	local specName						= GetInspectSpecName(InspectFrame.unit);

	class = GetClassColorObj(classFilename):WrapTextInColorTableCode(class)

	if ( level == -1 ) then
		level = "??"
	end
	
	if (specName and specName ~= "") then
		if GetLocale() == "ruRU" then
			specName = GetClassColorObj(classFilename):WrapTextInColorTableCode("("..specName..")")
			InspectLevelText:SetFormattedText(PLAYER_LEVEL_SPEC, level, class, specName);
		else
			specName = GetClassColorObj(classFilename):WrapTextInColorTableCode(specName)
			InspectLevelText:SetFormattedText(PLAYER_LEVEL, level, specName, class);
		end
	else
		InspectLevelText:SetFormattedText(PLAYER_LEVEL_NO_SPEC, level, class);
	end
end

function SetPaperDollBackground(model, unit)
	local texture = GetDressUpTexturePath(unit)
	local overlayAlpha = GetDressUpTextureAlpha(unit)

	model.BackgroundOverlay:SetAlpha(overlayAlpha)
	model.BackgroundTopLeft:SetTexture(texture..1)
	model.BackgroundTopRight:SetTexture(texture..2)
	model.BackgroundBotLeft:SetTexture(texture..3)
	model.BackgroundBotRight:SetTexture(texture..4)
end

function InspectPaperDollFrame_UpdateButtons()
	table.wipe(InspectPaperDollFrame.equipmentItemsList)

	InspectPaperDollItemSlotButton_Update(InspectHeadSlot)
	InspectPaperDollItemSlotButton_Update(InspectNeckSlot)
	InspectPaperDollItemSlotButton_Update(InspectShoulderSlot)
	InspectPaperDollItemSlotButton_Update(InspectBackSlot)
	InspectPaperDollItemSlotButton_Update(InspectChestSlot)
	InspectPaperDollItemSlotButton_Update(InspectShirtSlot)
	InspectPaperDollItemSlotButton_Update(InspectTabardSlot)
	InspectPaperDollItemSlotButton_Update(InspectWristSlot)
	InspectPaperDollItemSlotButton_Update(InspectHandsSlot)
	InspectPaperDollItemSlotButton_Update(InspectWaistSlot)
	InspectPaperDollItemSlotButton_Update(InspectLegsSlot)
	InspectPaperDollItemSlotButton_Update(InspectFeetSlot)
	InspectPaperDollItemSlotButton_Update(InspectFinger0Slot)
	InspectPaperDollItemSlotButton_Update(InspectFinger1Slot)
	InspectPaperDollItemSlotButton_Update(InspectTrinket0Slot)
	InspectPaperDollItemSlotButton_Update(InspectTrinket1Slot)
	InspectPaperDollItemSlotButton_Update(InspectMainHandSlot)
	InspectPaperDollItemSlotButton_Update(InspectSecondaryHandSlot)
	InspectPaperDollItemSlotButton_Update(InspectRangedSlot)
end

function InspectPVPFrame_OnLoad(self)
	self:RegisterEvent("INSPECT_HONOR_UPDATE")

	-- PanelTemplates_SetNumTabs(self, 2)
	-- InspectPVPFrameTab_OnClick(InspectPVPFrameTab1)

	InspectFrameCloseButton:SetToplevel(true)
	InspectFrameCloseButton:SetFrameStrata("HIGH")
end

function InspectPVPFrame_OnEvent(self, event, ...)
	if ( event == "INSPECT_HONOR_UPDATE" ) then
		InspectPVPFrame_Update()
	end
end

function InspectPVPFrame_OnShow()
	-- InspectPVPFrameTab_OnClick(InspectPVPFrameTab1)
	ButtonFrameTemplate_HideButtonBar(InspectFrame)
	InspectPVPFrame_Update()
	if ( not HasInspectHonorData() ) then
		RequestInspectHonorData()
	else
		InspectPVPFrame_Update()
	end
end

function InspectPVPFrame_SetFaction()
	local factionGroup = UnitFactionGroup(InspectFrame.unit)
	if ( factionGroup == "Alliance" ) then
		InspectPVPFrameFaction:SetTexCoord(0.69433594, 0.74804688, 0.60351563, 0.72851563)
	else
		InspectPVPFrameFaction:SetTexCoord(0.63867188, 0.69238281, 0.60351563, 0.73242188)
	end
end

function InspectPVPFrame_Update()
	for i=1, MAX_ARENA_TEAMS do
		GetInspectArenaTeamData(i)
	end
	InspectPVPFrame_SetFaction()
	InspectPVPTeam_Update()

	local todayHK, todayHonor, yesterdayHK, yesterdayHonor, lifetimeHK, lifetimeRank = GetInspectHonorData()

	InspectPVPFrame.Rating.Container.KillsToDay:SetText(todayHK)
	InspectPVPFrame.Rating.Container.KillsYesterDay:SetText(yesterdayHK)

	InspectPVPFrame.Rating.Container.HonorToDay:SetText(todayHonor)
	InspectPVPFrame.Rating.Container.HonorYesterDay:SetText(yesterdayHonor)

	InspectPVPFrame.Rating.Container.TotalHK:SetText(lifetimeHK)
end

local s2 = sqrt(2);
local cos, sin, rad = math.cos, math.sin, math.rad;

local function CalculateCorner(angle)
	local r = rad(angle);
	return 0.5 + cos(r) / s2, 0.5 + sin(r) / s2;
end

local function RotateTexture(texture, angle)
	local LRx, LRy = CalculateCorner(angle + 45);
	local LLx, LLy = CalculateCorner(angle + 135);
	local ULx, ULy = CalculateCorner(angle + 225);
	local URx, URy = CalculateCorner(angle - 45);
	
	texture:SetTexCoord(ULx, ULy, LLx, LLy, URx, URy, LRx, LRy);
end

function InspectPVPTeam_Update()
	-- Display Elements
	local button, buttonName, data, standard, emblem, border;
	
	-- Data Elements
	local teamName, teamSize, teamRating, teamPlayed, teamWins, teamLoss, playerPlayed, playerRating, playerPlayedPct, teamRank;
	local background = {};
	local borderColor = {};
	local emblemColor = {};
	local ARENA_TEAMS = {};
	ARENA_TEAMS[1] = {size = 2};
	ARENA_TEAMS[2] = {size = 3};
	ARENA_TEAMS[3] = {size = 5};

	-- Sort teams by size
	local buttonIndex = 0;
	for index, value in pairs(ARENA_TEAMS) do
		for i=1, MAX_ARENA_TEAMS do
			teamName, teamSize = GetInspectArenaTeamData(i);
			if ( value.size == teamSize ) then
				value.index = i;
			end
		end
	end

	-- fill out data
	for index, value in pairs(ARENA_TEAMS) do
		if ( value.index ) then
			buttonIndex = buttonIndex + 1;
			
			-- Pull Values
			teamName, teamSize, teamRating, teamPlayed, teamWins, playerPlayed, playerRating, background.r, background.g, background.b, emblem, emblemColor.r, emblemColor.g, emblemColor.b, border, borderColor.r, borderColor.g, borderColor.b = GetInspectArenaTeamData(value.index);
			teamLoss = teamPlayed - teamWins;
			if ( teamPlayed ~= 0 ) then
				playerPlayedPct = floor((playerPlayed / teamPlayed) * 100)
			else
				playerPlayedPct = floor((playerPlayed / 1) * 100)
			end

			-- Set button elements to variables 
			button = _G["InspectPVPTeam"..buttonIndex];
			buttonName = "InspectPVPTeam"..buttonIndex;
			data = buttonName.."Data";
			standard = buttonName.."Standard";

			button:SetID(value.index);

			-- Populate Data
			_G[data.."Name"]:SetText(teamName);
			_G[data.."Rating"]:SetText(teamRating);
			_G[data.."Games"]:SetText(teamPlayed);
			_G[data.."Wins"]:SetText(teamWins);
			_G[data.."Lose"]:SetText(teamLoss);

			-- Set TeamSize Banner
			_G[standard.."Bar"]:ClearAndSetNewPoint("TOPLEFT", _G[data.."Name"], 6, 7)
			_G[standard.."Bar"]:SetAlpha(0)
			_G[standard.."Emblem"]:SetVertexColor(emblemColor.r, emblemColor.g, emblemColor.b);
			
			if ( emblem ~= -1 ) then
				_G[standard.."Emblem"]:SetTexture("Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-"..emblem);
				_G[standard.."Emblem"]:SetSize(58, 58);
				_G[standard.."Emblem"]:SetAlpha(0.76);
				RotateTexture(_G[standard.."Emblem"], -22);
			end

			-- Set visual elements
			button:SetAlpha(1);
			
			_G[data]:Show();
			_G[standard]:SetAlpha(1);
			_G[standard]:SetFrameLevel(button:GetFrameLevel() - 1)
			_G[standard.."Banner"]:Hide();
			_G[standard.."Border"]:Hide();
			_G[standard.."Emblem"]:Show();
			_G[buttonName.."TeamType"]:Hide();
		end
	end

	-- show unused teams
	for index, value in pairs(ARENA_TEAMS) do
		if ( not value.index ) then
			-- Set button elements to variables 
			buttonIndex = buttonIndex + 1;
			button = _G["InspectPVPTeam"..buttonIndex];
			buttonName = "InspectPVPTeam"..buttonIndex;
			data = buttonName.."Data";

			-- Hide or Show items
			button:SetAlpha(0.6);
			_G[data]:Hide();
			_G[buttonName.."Standard"]:SetAlpha(0);
			_G[buttonName.."StandardBorder"]:Hide();
			_G[buttonName.."StandardEmblem"]:Hide();
			_G[buttonName.."TeamType"]:SetFormattedText(PVP_TEAMSIZE, value.size, value.size);
			_G[buttonName.."TeamType"]:Show();
		end
	end
end

local talentSpecInfoCache = {}

function InspectTalentFrameTalent_OnClick(self, button)
	if ( IsModifiedClick("CHATLINK") ) then
		local link = GetTalentLink(PanelTemplates_GetSelectedTab(InspectTalentFrame), self:GetID(),
			InspectTalentFrame.inspect, InspectTalentFrame.pet, InspectTalentFrame.talentGroup)
		if ( link ) then
			ChatEdit_InsertLink(link)
		end
	end
end

function InspectTalentFrameTalent_OnEvent(self, event, ...)
	if ( GameTooltip:IsOwned(self) ) then
		GameTooltip:SetTalent(PanelTemplates_GetSelectedTab(InspectTalentFrame), self:GetID(),
			InspectTalentFrame.inspect, InspectTalentFrame.pet, InspectTalentFrame.talentGroup)
	end
end

function InspectTalentFrameTalent_OnEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:SetTalent(PanelTemplates_GetSelectedTab(InspectTalentFrame), self:GetID(),
		InspectTalentFrame.inspect, InspectTalentFrame.pet, InspectTalentFrame.talentGroup)
end

function InspectTalentFrame_UpdateTabs()
	local numTabs = GetNumTalentTabs(InspectTalentFrame.inspect)
	local selectedTab = PanelTemplates_GetSelectedTab(InspectTalentFrame)
	local tab
	for i = 1, MAX_TALENT_TABS do
		tab = _G["InspectTalentFrameTab"..i]
		if ( tab ) then
			talentSpecInfoCache[i] = talentSpecInfoCache[i] or { }
			if ( i <= numTabs ) then
				-- local id, name, description, icon, pointsSpent, background, previewPointsSpent, isUnlocked = GetTalentTabInfo(i, InspectTalentFrame.inspect, InspectTalentFrame.pet, InspectTalentFrame.talentGroup)
				local name, iconTexture, pointsSpent = GetTalentTabInfo(i, InspectTalentFrame.inspect, InspectTalentFrame.pet, InspectTalentFrame.talentGroup)
				if ( i == selectedTab ) then
					-- If tab is the selected tab set the points spent info
					InspectTalentFrameSpentPointsText:SetFormattedText(MASTERY_POINTS_SPENT, name, HIGHLIGHT_FONT_COLOR_CODE..pointsSpent..FONT_COLOR_CODE_CLOSE)
					InspectTalentFrame.pointsSpent = pointsSpent
					InspectTalentFrame.previewPointsSpent = 999
				end
				tab:SetText(name)
				PanelTemplates_TabResize(tab, -10)
				tab:Show()
			else
				tab:Hide()
				talentSpecInfoCache[i].name = nil
			end
		end
	end
end

function InspectTalentFrame_Update()
	InspectTalentFrame.talentGroup = GetActiveTalentGroup(InspectTalentFrame.inspect)
	InspectTalentFrame.unit = InspectFrame.unit

	-- update spec info first
	TalentFrame_UpdateSpecInfoCache(talentSpecInfoCache, InspectTalentFrame.inspect, InspectTalentFrame.pet, InspectTalentFrame.talentGroup)

	-- update tabs

	-- select a tab if one is not already selected
	if ( not PanelTemplates_GetSelectedTab(InspectTalentFrame) ) then
		-- if there is a primary tab then we'll prefer that one
		if ( talentSpecInfoCache.primaryTabIndex > 0 ) then
			PanelTemplates_SetTab(InspectTalentFrame, talentSpecInfoCache.primaryTabIndex)
		else
			PanelTemplates_SetTab(InspectTalentFrame, DEFAULT_TALENT_TAB)
		end
	end
	InspectTalentFrame_UpdateTabs()

	-- update parent tabs
	PanelTemplates_UpdateTabs(InspectFrame)

	-- Update talents
	TalentFrame_Update(InspectTalentFrame)
end

function InspectTalentFrame_OnLoad(self)
	self.inspect = true
	self.talentButtonSize = 30;
	self.initialOffsetX = 62;
	self.initialOffsetY = 12;
	self.buttonSpacingX = 56;
	self.buttonSpacingY = 46;
	self.arrowInsetX = 2;
	self.arrowInsetY = 2;

	TalentFrame_Load(self)

	local button
	for i = 1, MAX_NUM_TALENTS do
		button = _G["InspectTalentFrameTalent"..i]
		if ( button ) then
			button:SetScript("OnClick",	InspectTalentFrameTalent_OnClick)
			button:SetScript("OnEvent", InspectTalentFrameTalent_OnEvent)
			button:SetScript("OnEnter", InspectTalentFrameTalent_OnEnter)
		end
	end

	-- setup tabs
	PanelTemplates_SetNumTabs(self, MAX_TALENT_TABS)
	PanelTemplates_UpdateTabs(self)
end

function InspectTalentFrame_OnShow()
	InspectTalentFrame:RegisterEvent("INSPECT_TALENT_READY")
	ButtonFrameTemplate_ShowButtonBar(InspectFrame)
	InspectTalentFrame_Update()
end

function InspectTalentFrame_OnHide()
	InspectTalentFrame:UnregisterEvent("INSPECT_TALENT_READY")
	wipe(talentSpecInfoCache)
end

function InspectTalentFrame_OnEvent(self, event, ...)
	if ( event == "INSPECT_TALENT_READY" ) then
		InspectTalentFrame_Update()
	end
end

function InspectTalentFrameDownArrow_OnClick(self)
	local parent = self:GetParent()
	parent:SetValue(parent:GetValue() + (parent:GetHeight() / 2))
	PlaySound("UChatScrollButton")
	UIFrameFlashStop(InspectTalentFrameScrollButtonOverlay)
end

function InspectTalentFramePointsBar_OnEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:AddLine(TALENT_POINTS)
	local pointsColor
	for index, info in ipairs(talentSpecInfoCache) do
		if ( info.name ) then
			if ( talentSpecInfoCache.primaryTabIndex == index ) then
				pointsColor = GREEN_FONT_COLOR
			else
				pointsColor = HIGHLIGHT_FONT_COLOR
			end
			GameTooltip:AddDoubleLine(
				info.name,
				info.pointsSpent,
				HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b,
				pointsColor.r, pointsColor.g, pointsColor.b,
				1
			)
		end
	end

	GameTooltip:Show()
end

function InspectPaperDollViewButton_OnLoad(self)
	self:SetWidth(30 + self:GetFontString():GetStringWidth());
end

local transmogrifySlotButton = {
	"InspectHeadSlot",
	"InspectShoulderSlot",
	"InspectBackSlot",
	"InspectChestSlot",
	"InspectShirtSlot",
	"InspectTabardSlot",
	"InspectWristSlot",
	"InspectHandsSlot",
	"InspectWaistSlot",
	"InspectLegsSlot",
	"InspectFeetSlot",
	"InspectMainHandSlot",
	"InspectSecondaryHandSlot",
	"InspectRangedSlot",
}

function InspectPaperDollViewButton_OnClick(self)
	local unit = InspectFrame.unit

	if not unit then
		return
	end
	
	if IsAddOnLoaded("ezCollections") or InspectFrameViewButton and InspectFrameViewButton:IsShown() then
		DressUpSources(C_TransmogCollection.GetInspectSources());
	else
		DressUpModel:Undress();

		for _, slotName in pairs(transmogrifySlotButton) do
			local slotButton = _G[slotName]
			local itemID = GetInventoryItemID(unit, slotButton:GetID())
			if itemID then
				local _, itemLink = GetItemInfo(itemID)
				DressUpItemLink(itemLink)
			end
		end
	end
end