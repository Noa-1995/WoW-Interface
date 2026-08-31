StaticPopupDialogs["CONFIRM_LEARN_PREVIEW_TALENTS"] = {
    text         = CONFIRM_LEARN_PREVIEW_TALENTS,
    button1      = YES,
    button2      = NO,
	OnAccept = function (self)
        LearnPreviewTalents(PlayerTalentFrame.pet);
    end,
	OnCancel = function (self)
    end,
    hideOnEscape = 1,
    timeout      = 0,
    exclusive    = 1,
}

UIPanelWindows["PlayerTalentFrame"] = { area = "left", pushable = 1, whileDead = 1, xOffset = "15", yOffset = "-10" };


-- global constants
TALENTS_TAB = 1;
PET_TALENTS_TAB = 2;
GLYPH_TALENT_TAB = 3;
NUM_TALENT_FRAME_TABS = 3;

NUM_TALENT_POPUP_ICONS_SHOWN = 35
NUM_TALENT_POPUP_ICONS_PER_ROW = 5
NUM_TALENT_POPUP_ICON_ROWS = 7
TALENT_POPUP_ICON_ROW_HEIGHT = 36

-- speed references
local next                                          = next;
local ipairs                                        = ipairs;

-- local data
local specs                                         = {
    ["spec1"]    = {
        name               = TALENT_SPEC_PRIMARY,
        talentGroup        = 1,
        unit               = "player",
        pet                = false,
        tooltip            = TALENT_SPEC_PRIMARY,
        portraitUnit       = "player",
        defaultSpecTexture = "Interface\\Icons\\Ability_Marksmanship",
        hasGlyphs          = true,
        glyphName          = TALENT_SPEC_PRIMARY_GLYPH,
    },
    ["spec2"]    = {
        name               = TALENT_SPEC_SECONDARY,
        talentGroup        = 2,
        unit               = "player",
        pet                = false,
        tooltip            = TALENT_SPEC_SECONDARY,
        portraitUnit       = "player",
        defaultSpecTexture = "Interface\\Icons\\Ability_Marksmanship",
        hasGlyphs          = true,
        glyphName          = TALENT_SPEC_SECONDARY_GLYPH,
    },
    ["petspec1"] = {
        name               = TALENT_SPEC_PET_PRIMARY,
        talentGroup        = 1,
        unit               = "pet",
        tooltip            = TALENT_SPEC_PET_PRIMARY,
        pet                = true,
        portraitUnit       = "pet",
        defaultSpecTexture = nil,
        hasGlyphs          = false,
        glyphName          = nil,
    },
};

local specTabs = { };    -- filled in by PlayerSpecTab_OnLoad
local numSpecTabs = 0;
local selectedSpec = nil;
local activeSpec = nil;


-- cache talent info so we can quickly display cool stuff like the number of points spent in each tab
local talentSpecInfoCache                           = {
    ["spec1"]    = { },
    ["spec2"]    = { },
    ["petspec1"] = { },
};
-- cache talent tab widths so we can resize tabs to fit for localization
local talentTabWidthCache                           = { };

-- ACTIVESPEC_DISPLAYTYPE values:
-- "BLUE", "GOLD_INSIDE", "GOLD_BACKGROUND"
local ACTIVESPEC_DISPLAYTYPE = nil;

-- SELECTEDSPEC_DISPLAYTYPE values:
-- "BLUE", "GOLD_INSIDE", "PUSHED_OUT", "PUSHED_OUT_CHECKED"
local SELECTEDSPEC_DISPLAYTYPE                      = "GOLD_INSIDE";
local SELECTEDSPEC_OFFSETX;
if (SELECTEDSPEC_DISPLAYTYPE == "PUSHED_OUT" or SELECTEDSPEC_DISPLAYTYPE == "PUSHED_OUT_CHECKED") then
    SELECTEDSPEC_OFFSETX = 5;
else
    SELECTEDSPEC_OFFSETX = 0;
end

local PREVIEW_LEARN_ANIM_TIME = 0.07
local lastCloseTime

local function AnimationStopAndPlay(object, ...)
	local numVarArg = select("#", ...)
	if numVarArg > 0 then
		for i = 1, numVarArg do
			local obj = select(i, ...)
			if obj and obj:IsPlaying() then
				obj:Stop()
			end
		end
	end

	if object then
		object:Stop()
		object:Play()
	end
end

-- PlayerTalentFrame

function PlayerTalentFrame_Toggle(pet)
    local selectedTab = PanelTemplates_GetSelectedTab(PlayerTalentFrame);

    if (not PlayerTalentFrame:IsShown()) then
        ShowUIPanel(PlayerTalentFrame);
    else
        if not PlayerTalentFrame.previewState then
            if (selectedTab == TALENTS_TAB and not pet) then
                -- if a talent tab is selected then toggle the frame off
                HideUIPanel(PlayerTalentFrame);
            elseif (selectedTab == PET_TALENTS_TAB and pet) then
                HideUIPanel(PlayerTalentFrame);
            elseif selectedTab == GLYPH_TALENT_TAB then
                HideUIPanel(PlayerTalentFrame);
            end
        end
    end
end

function PlayerTalentFrame_Open(talentGroup)
    ShowUIPanel(PlayerTalentFrame);

    -- Show the talents tab
    PlayerTalentTab_OnClick(_G["PlayerTalentFrameTab" .. TALENTS_TAB]);

    -- open the spec with the requested talent group
    for index, spec in next, specs do
        if (spec.talentGroup == talentGroup) then
            PlayerSpecTab_OnClick(specTabs[index]);
            break ;
        end
    end
end

function PlayerTalentFrame_ToggleGlyphFrame(suggestedTalentGroup)
    GlyphFrame_LoadUI();
    if (GlyphFrame) then
        local hidden = false;
        if (not PlayerTalentFrame:IsShown()) then
            ShowUIPanel(PlayerTalentFrame);
            hidden = false;
        else
            local spec = selectedSpec and specs[selectedSpec];
            if (spec and spec.hasGlyphs and
                    PanelTemplates_GetSelectedTab(PlayerTalentFrame) == GLYPH_TALENT_TAB) then
                -- if the glyph tab is selected then toggle the frame off
                HideUIPanel(PlayerTalentFrame);
                hidden = true;
            else
                hidden = false;
            end
        end
        if (not hidden) then
            -- open the spec with the requested talent group (or the current talent group if the selected
            -- spec has one)
            if (selectedSpec) then
                local spec = specs[selectedSpec];
                if (spec.hasGlyphs) then
                    suggestedTalentGroup = spec.talentGroup;
                end
            end
            for _, index in ipairs(TALENT_SORT_ORDER) do
                local spec = specs[index];
                if (spec.hasGlyphs and spec.talentGroup == suggestedTalentGroup) then
                    PlayerSpecTab_OnClick(specTabs[index]);
                    break ;
                end
            end
        end
    end
end

function PlayerTalentFrame_OpenGlyphFrame(talentGroup)
    GlyphFrame_LoadUI();
    if (GlyphFrame) then
        ShowUIPanel(PlayerTalentFrame);
        -- open the spec with the requested talent group
        PlayerSpecTab_OnClick(PlayerTalentFrame.specTabs[talentGroup])
        PlayerTalentFrameTab_OnClick(_G["PlayerTalentFrameTab"..GLYPH_TALENT_TAB]);
    end
end

function PlayerTalentFrame_ShowGlyphFrame()
    GlyphFrame_LoadUI();
    if (GlyphFrame) then
        -- show/update the glyph frame
        if (GlyphFrame:IsShown()) then
            GlyphFrame_Update();
        else
			PlayerTalentFrame.LoadingFrame:SetAllPoints(PlayerTalentFrame.Inset)
            GlyphFrame:Show();
        end
    end
end

function PlayerTalentFrame_HideGlyphFrame()
    if (not GlyphFrame or not GlyphFrame:IsShown()) then
        return ;
    end

    GlyphFrame_LoadUI();
    if (GlyphFrame) then
        GlyphFrame:Hide();
    end
end

function PlayerTalentFrame_OnLoad(self)
--	self:RegisterEvent("ADDON_LOADED");
	self:RegisterEvent("PREVIEW_TALENT_POINTS_CHANGED");
	self:RegisterEvent("PREVIEW_PET_TALENT_POINTS_CHANGED");
	self:RegisterEvent("UNIT_PORTRAIT_UPDATE");
	self:RegisterEvent("UNIT_PET");
	self:RegisterEvent("PLAYER_LEVEL_UP");
	self:RegisterEvent("PLAYER_TALENT_UPDATE");
	self:RegisterEvent("PET_TALENT_UPDATE");
	self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED");
	-- The standalone 3.3.5a port uses native talent events only.

	self.unit = "player";
	self.inspect = false;
	self.pet = false;
	self.talentGroup = 1;
	self.updateFunction = PlayerTalentFrame_Update;

	self.specTabs = {}
	self.selectedPlayerSpec = DEFAULT_TALENT_SPEC;
	self.elapsed = 0
	self.learnPreviewTabIndex = 1

	TalentFrame_Load(self);

	-- setup tabs
	PanelTemplates_SetNumTabs(self, NUM_TALENT_FRAME_TABS);
	PlayerTalentFrameTab_OnClick(PlayerTalentFrameTab1)

	-- setup portrait texture
	SetPortraitToTexture(PlayerTalentFramePortrait, "Interface\\Icons\\Ability_Marksmanship")

	self.initializedExtended = C_Talent.IsSpecInfoLoaded()
	-- initialize active spec as a fail safe
	local activeTalentGroup = GetActiveTalentGroup();
	local numTalentGroups = GetNumTalentGroups();
	PlayerTalentFrame_UpdateActiveSpec(activeTalentGroup, numTalentGroups);

	-- setup active spec highlight
	if (ACTIVESPEC_DISPLAYTYPE == "BLUE") then
		PlayerTalentFrameActiveSpecTabHighlight:SetDrawLayer("OVERLAY");
		PlayerTalentFrameActiveSpecTabHighlight:SetBlendMode("ADD");
		PlayerTalentFrameActiveSpecTabHighlight:SetTexture("Interface\\Buttons\\UI-Button-Outline");
	elseif (ACTIVESPEC_DISPLAYTYPE == "GOLD_INSIDE") then
		PlayerTalentFrameActiveSpecTabHighlight:SetDrawLayer("OVERLAY");
		PlayerTalentFrameActiveSpecTabHighlight:SetBlendMode("ADD");
		PlayerTalentFrameActiveSpecTabHighlight:SetTexture("Interface\\Buttons\\CheckButtonHilight");
	elseif (ACTIVESPEC_DISPLAYTYPE == "GOLD_BACKGROUND") then
		PlayerTalentFrameActiveSpecTabHighlight:SetDrawLayer("BACKGROUND");
		PlayerTalentFrameActiveSpecTabHighlight:SetWidth(74);
		PlayerTalentFrameActiveSpecTabHighlight:SetHeight(86);
		PlayerTalentFrameActiveSpecTabHighlight:SetTexture("Interface\\SpellBook\\SpellBook-SkillLineTab-Glow");
	end

	UIDropDownMenu_Initialize(self.LinkToDropDown, PlayerTalentLinkToDropDownInit, "MENU")
end

function PlayerTalentFrame_OnShow(self)
	SetParentFrameLevel(PlayerTalentFramePetTalents, 2)
	SetParentFrameLevel(self.LoadingFrame, 9)

	PlayerTalentFrame_UpdateSpecTabs(self)

    local currentTime = time()

    if (not lastCloseTime or currentTime - lastCloseTime >= S_RESET_FRAME_STATE_TIME) then
        self.secureLastTabIndex = nil
    end

    local lastTab = _G["PlayerTalentFrameTab1"]

    if (self.secureLastTabIndex) then
        lastTab = _G["PlayerTalentFrameTab" .. self.secureLastTabIndex]
    end

    -- Stop buttons from flashing after skill up
    MicroButtonPulseStop(TalentMicroButton);

    PlaySound("TalentScreenOpen");
    UpdateMicroButtons();

    C_Talent.SelectTalentGroup(C_Talent.GetActiveTalentGroup())

    -- Set flag
    if (not GetCVarBool("talentFrameShown")) then
        SetCVar("talentFrameShown", 1);
    end

    PlayerTalentFramePanel1.ShadowFrame:Hide()
    PlayerTalentFramePanel1.Summary:Hide()
    PlayerTalentFramePanel1.Summary.needAnimation     = false
    PlayerTalentFramePanel1.Summary.elapsed           = 0
    PlayerTalentFramePanel1.Summary.isHiddenAnimation = false

    PlayerTalentFramePanel2.ShadowFrame:Hide()
    PlayerTalentFramePanel2.Summary:Hide()
    PlayerTalentFramePanel2.Summary.needAnimation     = false
    PlayerTalentFramePanel2.Summary.elapsed           = 0
    PlayerTalentFramePanel2.Summary.isHiddenAnimation = false

    PlayerTalentFramePanel3.ShadowFrame:Hide()
    PlayerTalentFramePanel3.Summary:Hide()
    PlayerTalentFramePanel3.Summary.needAnimation     = false
    PlayerTalentFramePanel3.Summary.elapsed           = 0
    PlayerTalentFramePanel3.Summary.isHiddenAnimation = false

	if EventRegistry and EventRegistry.TriggerEvent then
		EventRegistry:TriggerEvent("PlayerTalentFrame.OnShow")
	end
end

function PlayerTalentFrame_OnHide( self )
    PanelTemplates_SetTab(PlayerTalentFrame, 1)

    lastCloseTime = time()

    UpdateMicroButtons();
    PlaySound("TalentScreenClose");

    if PlayerTalentFrame.learnPreviewTalentsAnimation then
        TalentFrameSetupPreviewTalents()
        LearnPreviewTalents(false)
        PlayerTalentFrame.learnPreviewTalentsAnimation = nil
    end

    -- clear caches
    for _, info in next, talentSpecInfoCache do
        wipe(info);
    end
    TalentFramePreviewHide()
    wipe(talentTabWidthCache);

    self.LoadingFrame:Hide()

    StaticPopup_Hide("TALENTS_IMPORT_POPUP")

    PlayerTalentPopupFrame:Hide()
	if EventRegistry and EventRegistry.TriggerEvent then
		EventRegistry:TriggerEvent("PlayerTalentFrame.OnHide")
	end
end

function PlayerTalentFrame_OnEvent(self, event, ...)
    if (event == "PLAYER_TALENT_UPDATE" or event == "PET_TALENT_UPDATE") then
        PlayerTalentFrame_Refresh();
    elseif (event == "PREVIEW_TALENT_POINTS_CHANGED") then
        --local talentIndex, tabIndex, groupIndex, points = ...;
        if (selectedSpec and not specs[selectedSpec].pet) then
            PlayerTalentFrame_Refresh();
        end
    elseif (event == "PREVIEW_PET_TALENT_POINTS_CHANGED") then
        PlayerTalentFrame_Refresh();
    elseif (event == "UNIT_PORTRAIT_UPDATE") then
        local unit = ...;
        -- update the talent frame's portrait
        if (unit == PlayerTalentFramePortrait.unit) then
            SetPortraitTexture(PlayerTalentFramePortrait, unit);
        end
    elseif (event == "UNIT_PET") then
        local summoner = ...;
        if (summoner == "player") then
            if (selectedSpec and specs[selectedSpec].pet) then
                -- if the selected spec is a pet spec...
                local numTalentGroups = GetNumTalentGroups(false, true);
                if (numTalentGroups == 0) then
                    --...and a pet spec is not available, select the default spec
                    PlayerSpecTab_OnClick(activeSpec and specTabs[activeSpec] or specTabs[DEFAULT_TALENT_SPEC]);
                    return ;
                end
            end
            PlayerTalentFrame_Refresh();
        end
    elseif (event == "PLAYER_LEVEL_UP") then
        if (selectedSpec and not specs[selectedSpec].pet) then
            local level = ...;
            PlayerTalentFrame_Update(level);
        end
	elseif event == "PLAYER_TALENT_UPDATE_EX" then
		if not self.initializedExtended then
			self.initializedExtended = true
			local activeTalentGroup = GetActiveTalentGroup()
			local numTalentGroups = GetNumTalentGroups()
			PlayerTalentFrame_UpdateActiveSpec(activeTalentGroup, numTalentGroups)
		end
		PlayerTalentFrame_UpdateSpecTabs(self)
		PlayerTalentFrame_Refresh()
	elseif event == "PLAYER_TALENT_ACTIVE_GROUP_CHANGED" then
		local talentGroupID, talentGroupIndex, talentsReady = ...

		if talentGroupIndex == 1 then
			selectedSpec = "spec1"
			PlayerTalentFrame.talentGroup = 1
		elseif talentGroupIndex == 2 then
			selectedSpec = "spec2"
			PlayerTalentFrame.talentGroup = 2
		end

		for _, button in pairs(PlayerTalentFrame.specTabs) do
			button:SetChecked(button.specIndex == talentGroupID)
			button.EtherealBorder:SetAlpha(button.specIndex == talentGroupID and 0 or 0.7)
		end

		if talentsReady then
			PlayerTalentFrame.LoadingFrame:Hide()
			PlayerTalentFrame_Refresh()
		else
			PlayerTalentFrame.LoadingFrame:Show()
		end
	elseif event == "PLAYER_TALENT_ACTIVE_GROUP_REFRESH" then
		PlayerTalentFrame.LoadingFrame:Hide()
	elseif event == "PLAYER_TALENT_RESET" then
		local success = ...

		if self.resetTalentsForPreview then
			PlayerTalentFrame_SetPreviewTalentState(self, success)
			self.resetTalentsForPreview = nil
		end
	elseif event == "PLAYER_TALENT_NOTES_UPDATE" then
		PlayerTalentFrame_RefreshSpecTabs()
	elseif event == "PLAYER_TALENT_PREVIEW" then
		if PlayerTalentFrame.previewState then
			TalentFrameSetupPreviewTalents()
			PlayerTalentFrame_Toggle()

			local previewName = C_Talent.GetPreviewName()
			if previewName then
				PlayerTalentFrameTitleText:SetFormattedText(PLAYER_TALENT_PREVIEW_PLAYER_TITLE, previewName)
			else
				PlayerTalentFrameTitleText:SetText(PLAYER_TALENT_PREVIEW_TITLE)
			end

			local hasGlyphData = false
			local majorGlyphs, minorGlyphs = C_Talent.GetPreviewGlyphs()
			if majorGlyphs and minorGlyphs
			and (#majorGlyphs > 0 or #minorGlyphs> 0)
			then
				hasGlyphData = true
			end

			TalentRetail_SetShown(PlayerGlyphPreviewFrame, hasGlyphData)
		end
	elseif event == "PLAYER_TALENT_PREVIEW_PARSED" then
		local available, className = ...
		if available then
			TalentFramePreviewShow()
		else
			StaticPopup_Show("PLAYER_TALENT_PREVIEW_CLASS_ERROR", TalentRetail_GetClassColoredText(className))
		end
	end
end

function PlayerTalentFrame_OnUpdate(self, elapsed, ...)
	if PlayerTalentFrame.learnPreviewTalentsAnimation then
		self.elapsed = self.elapsed + elapsed

		if self.elapsed >= PREVIEW_LEARN_ANIM_TIME then
			local tabInfo = PlayerTalentFrame.learnPreviewTalents[self.learnPreviewTabIndex]

			while tabInfo and #tabInfo == 0 and self.learnPreviewTabIndex < NUM_TALENT_FRAME_TABS do
				self.learnPreviewTabIndex = self.learnPreviewTabIndex + 1
				tabInfo = PlayerTalentFrame.learnPreviewTalents[self.learnPreviewTabIndex]
			end

			if not tabInfo or #tabInfo == 0 then
				self.learnPreviewTabIndex = 1
				self.elapsed = 0

				PlayerTalentFrame.learnPreviewTalentsAnimation = nil
				LearnPreviewTalents(false)
				return
			end

			local talentInfo = table.remove(tabInfo, 1)
			local talentIndex, points = unpack(talentInfo)
			local talentButton = _G[string.format("PlayerTalentFramePanel%dTalent%d", self.learnPreviewTabIndex, talentIndex)]
			if talentButton then
				PlayerTalentFrameTalent_PlayLearnAnim(talentButton)
			end
			AddPreviewTalentPoints(self.learnPreviewTabIndex, talentIndex, points)

			self.elapsed = self.elapsed - PREVIEW_LEARN_ANIM_TIME
		end
	end

	if C_Talent.GetSelectedTalentGroup() > 2 then
		local selectedCurrency = C_Talent.GetSelectedCurrency()
		if selectedCurrency then
			local name, icon, amount, itemID, itemLink = C_Talent.GetCurrencyInfo(selectedCurrency)
			TalentRetail_SetEnabled(PlayerTalentFrame.ActivateButton, amount > 0)
			PlayerTalentFrame.ActivateButton.disabledReason = TALENTS_ACTIVE_BUTTON_DISABLE_REASON_1
		else
			PlayerTalentFrame.ActivateButton:Disable()
			PlayerTalentFrame.ActivateButton.disabledReason = TALENTS_ACTIVE_BUTTON_DISABLE_REASON_1 -- TALENTS_ACTIVE_BUTTON_DISABLE_REASON_2
		end
	else
		PlayerTalentFrameActivateButton:Enable()
	end

	TalentRetail_SetEnabled(PlayerTalentFrame.ResetTalentGroupButton, C_Talent.CanResetTalents())
end

function PlayerTalentFrame_UpdateSpecTabs(self)
	for talentGroupID = max(#self.specTabs, 1), C_Talent.GetNumTalentGroups() do
		local specTab = self.specTabs[talentGroupID]

		if not specTab then
			specTab = CreateFrame("CheckButton", "PlayerSpecTab"..talentGroupID, self, "PlayerSpecTabTemplate")
			specTab.specIndex = talentGroupID

			self.specTabs[talentGroupID] = specTab

			self.specPurchaseButton:SetPoint("TOPLEFT", specTab, "BOTTOMLEFT", 0, -22)
		end

		if talentGroupID == 1 then
			specTab:SetPoint("TOPLEFT", self, "TOPRIGHT", 0, -40)
		else
			specTab:SetPoint("TOPLEFT", self.specTabs[talentGroupID - 1], "BOTTOMLEFT", 0, -22)

			if talentGroupID > 2 then
				specTab:GetHighlightTexture():SetTexture("Interface\\Buttons\\ButtonHilight-Square")
				specTab:GetCheckedTexture():SetTexture("Interface\\Buttons\\CheckButtonHilight")
				specTab.EtherealBorder:Show()
			end
		end

		local talentPointsSpent = {C_Talent.GetTalentGroupPointSpent(talentGroupID)}
		local primaryTabIndex = C_Talent.GetPrimaryTabIndexForTalentGroup(talentGroupID)
		specTab.primaryTabIndex = primaryTabIndex

		for j = 1, 3 do
			local name, icon, _, _, _ = GetTalentTabInfo(j, false, false, 1)

			if not specTab.tabInfo then
				specTab.tabInfo = {}
			end

			specTab.tabInfo[j] = {
				name = name,
				icon = icon,
				pointsSpent = talentPointsSpent[j],
				isPrimary = primaryTabIndex == j
			}
		end

		specTab:GetNormalTexture():SetTexture(specTab.tabInfo[primaryTabIndex]and specTab.tabInfo[primaryTabIndex].icon or "Interface\\Icons\\Ability_Marksmanship")
	end

	if #self.specTabs <= 1 and not PlayerTalentFrame.pet and not PlayerTalentFrame.previewState then
		local enabled = UnitLevel("player") >= 40
		self.specPurchaseButton.NormalTexture:SetTexture(enabled and [[Interface\Icons\Misc_ArrowLUP]] or [[Interface\Icons\Ability_Marksmanship]])
		self.specPurchaseButton.NormalTexture:SetDesaturated(not enabled)
		TalentRetail_SetEnabled(self.specPurchaseButton, enabled)
		self.specPurchaseButton:Show()
	else
		self.specPurchaseButton:Hide()
	end
end

function PlayerTalentFrame_ShowTalentTab()
	PlayerTalentFrame.LoadingFrame:ClearAllPoints()
	PlayerTalentFrame.LoadingFrame:SetPoint("TOPLEFT", 14, -102)
	PlayerTalentFrame.LoadingFrame:SetPoint("BOTTOMRIGHT", -16, 30)
    PlayerTalentFrameTalents:Show();
end

function PlayerTalentFrame_HideTalentTab()
    PlayerTalentFrameTalents:Hide();
end

function PlayerTalentFrame_ShowPetTalentTab()
	PlayerTalentFrame.LoadingFrame:ClearAllPoints()
	PlayerTalentFrame.LoadingFrame:SetPoint("TOPLEFT", 397, -64)
	PlayerTalentFrame.LoadingFrame:SetPoint("BOTTOMRIGHT", -11, 148)
    PlayerTalentFramePetTalents:Show();
end

function PlayerTalentFrame_HidePetTalentTab()
    PlayerTalentFramePetTalents:Hide();
end

function PlayerTalentFrame_Collapse()
    PlayerTalentFrame:SetWidth(542)
    PlayerTalentFrame.Expanded = false
    UpdateUIPanelPositions(PlayerTalentFrame)
    ButtonFrameTemplate_HideButtonBar(PlayerTalentFrame)
end

function PlayerTalentFrame_Expand()
    PlayerTalentFrame:SetWidth(646)
    PlayerTalentFrame.Expanded = true
    UpdateUIPanelPositions(PlayerTalentFrame)
    ButtonFrameTemplate_ShowButtonBar(PlayerTalentFrame)
end

local iconYOffset = 0
function PlayerTalentFrame_Refresh()
    local selectedTab       = PanelTemplates_GetSelectedTab(PlayerTalentFrame);

    -- HACK - If this is the Pet Talents Tab, ignore the selected spec since pets only display one spec
--[[
	if (selectedTab == PET_TALENTS_TAB) then
		selectedSpec = "spec1";
		PlayerTalentFrame.talentGroup = 1;
	else
		selectedSpec = PlayerTalentFrame.selectedPlayerSpec;
		PlayerTalentFrame.talentGroup = specs[selectedSpec].talentGroup;
	end
--]]

    if (selectedTab == GLYPH_TALENT_TAB) then
        PlayerTalentFrame_HideTalentTab();
        PlayerTalentFrame_HidePetTalentTab();
        PlayerTalentFrame.pet = false;
        PlayerTalentFrame_ShowGlyphFrame();
        PlayerTalentFrame_Collapse()
    elseif (selectedTab == PET_TALENTS_TAB) then
        PlayerTalentFrame_HideGlyphFrame();
        PlayerTalentFrame_HideTalentTab();
        PlayerTalentFrame_ShowPetTalentTab();
        PlayerTalentFrame.pet = true;
        PlayerTalentFrame_Expand()
    else
        PlayerTalentFrame_HideGlyphFrame();
        PlayerTalentFrame_HidePetTalentTab();
        PlayerTalentFrame_ShowTalentTab();
        PlayerTalentFrame.pet = false;
        PlayerTalentFrame_Expand()
    end

    PlayerTalentFramePanel1.talentGroup = PlayerTalentFrame.talentGroup;
    PlayerTalentFramePanel2.talentGroup = PlayerTalentFrame.talentGroup;
    PlayerTalentFramePanel3.talentGroup = PlayerTalentFrame.talentGroup;

    if (not PlayerTalentFrame_Update()) then
        return;
    end

    iconYOffset = 0

    if (PlayerTalentFramePanel1:IsVisible()) then
        PlayerTalentFramePanel_Update(PlayerTalentFramePanel1);
    end
    if (PlayerTalentFramePanel2:IsVisible()) then
        PlayerTalentFramePanel_Update(PlayerTalentFramePanel2);
    end
    if (PlayerTalentFramePanel3:IsVisible()) then
        PlayerTalentFramePanel_Update(PlayerTalentFramePanel3);
    end
    if (PlayerTalentFramePetPanel:IsVisible()) then
        PlayerTalentFramePanel_Update(PlayerTalentFramePetPanel);
    end


    for i = 1, 3 do
        -- hack
        local summary = _G["PlayerTalentFramePanel" .. i .. "Summary"]

        summary.ActiveBonus1:ClearAllPoints()
        summary.ActiveBonus1:SetPoint("TOPLEFT", summary.DescriptionText, "TOPLEFT", 10, 56 + iconYOffset)
    end

    PlayerTalentFrame.CurrencySelectFrame.Currency1.Icon:SetDesaturated(true)
    PlayerTalentFrame.CurrencySelectFrame.Currency2.Icon:SetDesaturated(true)

    PlayerTalentFrame.CurrencySelectFrame.Currency1:Disable()
    PlayerTalentFrame.CurrencySelectFrame.Currency2:Disable()

	for currencyIndex = 1, 2 do
		local name, icon, amount, itemID, itemLink = C_Talent.GetCurrencyInfo(currencyIndex)
		if name then
			local currencyButton = _G["PlayerTalentFrameCurrencySelectFrameCurrency"..currencyIndex]

			currencyButton.Icon:SetDesaturated(amount == 0)
			currencyButton.Count:SetText(amount > 99 and "99.." or amount)
			currencyButton.name = name

			TalentRetail_SetEnabled(currencyButton, amount > 0)

			if amount > 0 then
                if not C_Talent.GetSelectedCurrency() then
                    currencyButton:Click()
                end
            else
                currencyButton:SetChecked(false)
            end
        end
    end

    PlayerTalentFrame_RefreshSpecTabs()
end

function PlayerTalentFrame_RefreshSpecTabs()
    for _, button in pairs(PlayerTalentFrame.specTabs) do
		local note, texture = C_Talent.GetTalentGroupNote(button.specIndex)
		if not texture then
			local primaryTabIndex = C_Talent.GetPrimaryTabIndexForTalentGroup(button.specIndex)
			local tabName, icon = GetTalentTabInfo(primaryTabIndex, false, false, 1)
			texture = icon
		end
		button:GetNormalTexture():SetTexture(texture or "Interface\\Icons\\Ability_Marksmanship")
    end
end

function PlayerTalentFrame_Update(playerLevel)
    if not C_Talent.IsSpecInfoLoaded() then
        return
    end

    local activeTalentGroup, numTalentGroups = GetActiveTalentGroup(false, PlayerTalentFrame.pet), GetNumTalentGroups(false, PlayerTalentFrame.pet);
    -- local activePetTalentGroup, numPetTalentGroups = GetActiveTalentGroup(false, true), GetNumTalentGroups(false, true);

    -- update specs
    if (not PlayerTalentFrame_UpdateSpecs(activeTalentGroup, numTalentGroups)) then
        -- the current spec is not selectable any more, discontinue updates
        return false;
    end

    -- update tabs
    if (not PlayerTalentFrame_UpdateTabs(playerLevel)) then
        -- the current spec is not selectable any more, discontinue updates
        return false;
    end

    -- set the frame portrait
    SetPortraitTexture(PlayerTalentFramePortrait, PlayerTalentFrame.unit);

    -- update active talent group stuff
    PlayerTalentFrame_UpdateActiveSpec(activeTalentGroup, numTalentGroups);

    -- update talent controls
    PlayerTalentFrame_UpdateControls(activeTalentGroup, numTalentGroups);

    for _, button in pairs(PlayerTalentFrame.specTabs) do
        TalentRetail_SetShown(button, not PlayerTalentFrame.pet and not PlayerTalentFrame.previewState)
    end

    if PlayerTalentFrame.pet then
        PlayerTalentFrame_UpdatePetInfo(PlayerTalentFrame)
    end

    return true;
end

function PlayerTalentFrame_UpdatePetInfo(self)
    if (self.pet) then
        if (UnitCreatureFamily("pet")) then
            PlayerTalentFramePetTypeText:SetText(UnitCreatureFamily("pet"));
        else
            PlayerTalentFramePetTypeText:SetText("");
        end

        if (UnitLevel("pet")) then
            PlayerTalentFramePetLevelText:SetFormattedText(UNIT_LEVEL_TEMPLATE, UnitLevel("pet"));
        else
            PlayerTalentFramePetLevelText:SetText("");
        end

        if (UnitName("pet")) then
            PlayerTalentFramePetNameText:SetText(UnitName("pet"));
        else
            PlayerTalentFramePetNameText:SetText("");
        end

        PlayerTalentFramePetIcon:SetTexture(GetPetIcon());
    end
end

function PlayerTalentFrame_SetPreviewTalentState(self, shouldLearn)
	if success then
		TalentFramePreviewHide(true)
		PlayerTalentFrameHeaderFrame:Hide()
		self.learnPreviewTalents = C_Talent.GetPreviewTalents()
		self.learnPreviewTalentsAnimation = true
		self.learnPreviewTabIndex = 1
		ResetGroupPreviewTalentPoints(false, PlayerTalentFrame.talentGroup)
		TalentFrame_Update(PlayerTalentFramePanel1)
		TalentFrame_Update(PlayerTalentFramePanel2)
		TalentFrame_Update(PlayerTalentFramePanel3)
	else
		TalentFramePreviewHide(false)
	end
end

-- PlayerTalentFramePanel

function PlayerTalentFramePanel_OnLoad(self)
    self.inspect          = false;
    self.talentGroup      = 1;
    self.talentButtonSize = 30;
    self.initialOffsetX   = 20;
    self.initialOffsetY   = 50;
    self.buttonSpacingX   = 46;
    self.buttonSpacingY   = 40;
    self.arrowInsetX      = 2;
    self.arrowInsetY      = 2;

    TalentFrame_Load(self);
end

local function PlayerTalentFramePanel_UpdateBonusAbility(bonusFrame, spellId, spellId2, formatString, desaturated)
	local name, subname, icon = GetSpellInfo(spellId);
	if (spellId2) then
		local name2, _, _ = GetSpellInfo(spellId2);
		if (name2) then
			name = name .. "/" .. name2;
		end
	end
	bonusFrame.Icon:SetTexture(icon);
	if (formatString) then
		bonusFrame.Label:SetFormattedText(formatString, name);
	else
		bonusFrame.Label:SetText(name);
	end
	bonusFrame.spellId = spellId;
	bonusFrame.spellId2 = spellId2;
	bonusFrame.extraTooltip = nil;
	bonusFrame.Label:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b);

	bonusFrame:Show();
end

function PlayerTalentFramePanel_UpdateSummary(self)
	local name, icon, _, _, _ = GetTalentTabInfo(self.talentTree, self.inspect, self.pet, self.talentGroup);

    if (self.Summary and icon) then
		local summary = self.Summary;
        local _, class     = UnitClass("player")
        local talentInfo   = TALENT_RETAIL_INFO[class] or TALENT_RETAIL_INFO["default"]
		local role1, role2 = C_Talent.GetClassSpecRole(class, self.talentTree)

		-- Update roles
        if (role1 == "TANK" or role1 == "HEALER" or role1 == "DAMAGER") then
			summary.RoleIcon.Icon:SetTexCoord(GetTexCoordsForRoleSmallCircle(role1));
			summary.RoleIcon:Show();
			summary.RoleIcon.role = role1;
		else
			summary.RoleIcon:Hide();
		end

        if (role2 == "TANK" or role2 == "HEALER" or role2 == "DAMAGER") then
			summary.RoleIcon2.Icon:SetTexCoord(GetTexCoordsForRoleSmallCircle(role2));
			summary.RoleIcon2:Show();
			summary.RoleIcon2.role = role2;
			summary.RoleIcon:SetPoint("BOTTOMRIGHT", summary.IconBorder, -9, -1);
		else
			summary.RoleIcon2:Hide();
			summary.RoleIcon:SetPoint("BOTTOMRIGHT", summary.IconBorder, -1, 3);
		end

        SetPortraitToTexture(summary.Icon, icon)
        summary.TitleText:SetText(name)

        summary.Icon:ClearAllPoints()
        summary.Icon:SetPoint("BOTTOM", summary.ActiveBonus1, "TOP", -14, 10)

		-- Update border glow
        if (PlayerTalentFrame.primaryTree and self.talentTree == PlayerTalentFrame.primaryTree) then
			summary.GlowTopLeft:Show();
			summary.GlowTop:Show();
			summary.GlowTopRight:Show();
			summary.GlowRight:Show();
			summary.GlowBottomRight:Show();
			summary.GlowBottom:Show();
			summary.GlowBottomLeft:Show();
			summary.GlowLeft:Show();
			summary.Border:SetVertexColor(0, 0, 0);

			local desaturate = (selectedSpec ~= activeSpec);
			summary.GlowTopLeft:SetDesaturated(desaturate);
			summary.GlowTop:SetDesaturated(desaturate);
			summary.GlowTopRight:SetDesaturated(desaturate);
			summary.GlowRight:SetDesaturated(desaturate);
			summary.GlowBottomRight:SetDesaturated(desaturate);
			summary.GlowBottom:SetDesaturated(desaturate);
			summary.GlowBottomLeft:SetDesaturated(desaturate);
			summary.GlowLeft:SetDesaturated(desaturate);
		else
			summary.GlowTopLeft:Hide();
			summary.GlowTop:Hide();
			summary.GlowTopRight:Hide();
			summary.GlowRight:Hide();
			summary.GlowBottomRight:Hide();
			summary.GlowBottom:Hide();
			summary.GlowBottomLeft:Hide();
			summary.GlowLeft:Hide();
		end

		local numSmallBonuses = 0;

        local treeInfo = talentInfo[self.talentTree] or TALENT_RETAIL_INFO.default[self.talentTree]
        summary.ActiveBonus1:Hide()

        if treeInfo.ActiveBonus then
            for i = 1, #treeInfo.ActiveBonus do
                local bonusFrame = _G[summary:GetName() .. "ActiveBonus" .. i]
                if (bonusFrame) then
                    PlayerTalentFramePanel_UpdateBonusAbility(bonusFrame, treeInfo.ActiveBonus[i], nil, nil, 0)
                end
            end
        end

        if treeInfo.PassiveBonus then
            for i = 1, #treeInfo.PassiveBonus do
                local bonusFrame = _G[summary:GetName() .. "Bonus" .. i]
                if (bonusFrame) then
                    numSmallBonuses       = numSmallBonuses + 1
                    bonusFrame.showButton = true
                    PlayerTalentFramePanel_UpdateBonusAbility(bonusFrame, treeInfo.PassiveBonus[i], nil, nil, 0)
                end
            end
        end

        for i = numSmallBonuses + 1, 5 do
            if _G[summary:GetName() .. "Bonus" .. i] then
                _G[summary:GetName() .. "Bonus" .. i].showButton = false
                _G[summary:GetName() .. "Bonus" .. i]:Hide()
            end
        end

        local offsetY = 20 * numSmallBonuses

        if offsetY >= iconYOffset then
            iconYOffset = offsetY
        end

        summary.DescriptionText:SetText(treeInfo.Description or "")
    end
end

function PlayerTalentFramePanel_Update(self)
	local _, class = UnitClass("player")
	local name, icon, pointsSpent, _, previewPointsSpent = GetTalentTabInfo(self.talentTree, self.inspect, self.pet, self.talentGroup);
	local primaryTree = PlayerTalentFrame.primaryTree;

	if (self.PointsSpent) then
		self.PointsSpent:SetText(pointsSpent + previewPointsSpent);
	end

	if (self.HeaderIcon) then
        local pointSpent = C_Talent.GetTabPointSpent(C_Talent.GetSelectedTalentGroup())[self.talentTree] or (pointsSpent + previewPointsSpent)
		self.HeaderIcon.Icon:SetTexture(icon);
        self.HeaderIcon.PointsSpent:SetText(pointSpent)
    end

	if (self.NameLarge) then
		self.NameLarge:SetText(name);
	end

    if self.Name then
        self.Name:SetText(name)
    end

	local talentInfo;
	if (self.pet) then
        talentInfo = TALENT_RETAIL_INFO["PET_410"]
    else
        talentInfo = TALENT_RETAIL_INFO[class] or TALENT_RETAIL_INFO["default"]
    end

    local color = talentInfo and talentInfo[self.talentTree] and talentInfo[self.talentTree].color;
	if (color) then
		self.HeaderBackground:SetVertexColor(color.r, color.g, color.b);
        if self.HeaderBackgroundHighlight then
            self.HeaderBackgroundHighlight:SetVertexColor(color.r, color.g, color.b)
        end
		if (self.Summary) then
			self.Summary.Border:SetVertexColor(color.r, color.g, color.b);
			self.Summary.IconGlow:SetVertexColor(color.r, color.g, color.b);
		end
	else
		self.HeaderBackground:SetVertexColor(1, 1, 1);
	end

	TalentFrame_Update(self);

	PlayerTalentFramePanel_UpdateSummary(self);

    if (self.SelectTreeButton) then
        if (not primaryTree and GetNumTalentPoints() > 0) then
			self.SelectTreeButton:Show();
			self.SelectTreeButton:SetText(name);
            if (selectedSpec and (activeSpec == selectedSpec)) then
				self.SelectTreeButton:Enable();
            else
				self.SelectTreeButton:Disable();
            end
        else
			self.SelectTreeButton:Hide();
        end
    end

	-- Update appearance of the Header icon and surrounding art
    if (self.HeaderIcon and not self.pet) then
        if (primaryTree == self.talentTree) then
			self.HeaderIcon.PointsSpent:Show();
			self.HeaderIcon.PrimaryBorder:Show();
			self.HeaderIcon.PointsSpentBgGold:Show();
			self.HeaderIcon.SecondaryBorder:Hide();
			self.HeaderIcon.PointsSpentBgSilver:Hide();
			self.HeaderIcon.LockIcon:Hide();
        else
			self.HeaderIcon.PointsSpent:Show();
			self.HeaderIcon.PrimaryBorder:Hide();
			self.HeaderIcon.PointsSpentBgGold:Hide();
			self.HeaderIcon.PointsSpentBgSilver:Show();
			self.HeaderIcon.LockIcon:Hide();

            local selectedTalentGroup = C_Talent.GetSelectedTalentGroup()

            TalentRetail_SetShown(self.HeaderIcon.SecondaryBorder, selectedTalentGroup < 3)
            TalentRetail_SetShown(self.HeaderBorder, selectedTalentGroup < 3)

            TalentRetail_SetShown(self.EtherealHeaderBorder, selectedTalentGroup > 2)
            TalentRetail_SetShown(self.HeaderIcon.EtherealBorder, selectedTalentGroup > 2)
            TalentRetail_SetShown(self.HeaderIcon.EtherealGlow, selectedTalentGroup > 2)
        end
    end

    if (self.RoleIcon) then
		local role1, role2 = C_Talent.GetClassSpecRole(class, self.talentTree)

        -- swap roles to match order on the summary screen
        if (role2) then
            role1, role2 = role2, role1;
        end

        -- Update roles
        if (role1 == "TANK" or role1 == "HEALER" or role1 == "DAMAGER") then
			self.RoleIcon.Icon:SetTexCoord(GetTexCoordsForRoleSmallCircle(role1));
			self.RoleIcon:Show();
			self.RoleIcon.role = role1;
        else
			self.RoleIcon:Hide();
        end

        if (role2 == "TANK" or role2 == "HEALER" or role2 == "DAMAGER") then
			self.RoleIcon2.Icon:SetTexCoord(GetTexCoordsForRoleSmallCircle(role2));
			self.RoleIcon2:Show();
			self.RoleIcon2.role = role2;
        else
			self.RoleIcon2:Hide();
        end
    end
end

function PlayerTalentFrame_UpdateActiveSpec(activeTalentGroup, numTalentGroups)
    -- set the active spec
    activeSpec = DEFAULT_TALENT_SPEC;
    for index, spec in next, specs do
        if (not spec.pet and spec.talentGroup == activeTalentGroup) then
            activeSpec = index;
            break ;
        end
    end
    -- make UI adjustments
    local spec = selectedSpec and specs[selectedSpec];
    local hasMultipleTalentGroups = numTalentGroups > 1;
    local selectedTalentGroup     = C_Talent.GetSelectedTalentGroup()

    if (spec and hasMultipleTalentGroups) then
		local note = C_Talent.GetTalentGroupNote(selectedTalentGroup)
		if note and note ~= "" then
			PlayerTalentFrameTitleText:SetText(note);
		else
            PlayerTalentFrameTitleText:SetFormattedText(TALENT_TAB_NAME, selectedTalentGroup);
        end
    else
        PlayerTalentFrameTitleText:SetText(TALENTS);
    end

    if (selectedSpec == activeSpec and hasMultipleTalentGroups) then
        --PlayerTalentFrameActiveTalentGroupFrame:Show();
    else
        -- PlayerTalentFrameActiveTalentGroupFrame:Hide();
    end

    if selectedTalentGroup > 2 then
        PlayerTalentFrameTitleGlowLeft:SetTexture("Interface\\TalentFrame\\TalentFrame-Parts")
        PlayerTalentFrameTitleGlowRight:SetTexture("Interface\\TalentFrame\\TalentFrame-Parts")
        PlayerTalentFrameTitleGlowCenter:SetTexture("Interface\\TalentFrame\\TalentFrame-Horizontal")
    else
        PlayerTalentFrameTitleGlowLeft:SetTexture("Interface\\TalentFrame\\TalentFrame-Parts")
        PlayerTalentFrameTitleGlowRight:SetTexture("Interface\\TalentFrame\\TalentFrame-Parts")
        PlayerTalentFrameTitleGlowCenter:SetTexture("Interface\\TalentFrame\\TalentFrame-Horizontal")
    end

    TalentRetail_SetShown(PlayerTalentFrame.EtherealBackground, selectedTalentGroup > 2)

    TalentRetail_SetShown(PlayerTalentFrame.EtherealLines, selectedTalentGroup > 2)
    TalentRetail_SetShown(PlayerTalentFrame.EtherealLinesGlow1, selectedTalentGroup > 2)

	if not PlayerTalentFrame.EtherealLinesGlow1.animIn:IsPlaying() then
	--	AnimationStopAndPlay(PlayerTalentFrame.EtherealLines.animIn, PlayerTalentFrame.EtherealLines.animIn)
		AnimationStopAndPlay(PlayerTalentFrame.EtherealLinesGlow1.animIn, PlayerTalentFrame.EtherealLinesGlow1.animIn)
	end
end


-- PlayerTalentFrameTalents

function PlayerTalentFrameTalent_OnLoad(self)
	self:RegisterForDrag("LeftButton");
	self:RegisterForClicks("LeftButtonUp", "RightButtonUp");
	self:RegisterEvent("PREVIEW_TALENT_POINTS_CHANGED");
	self:RegisterEvent("PREVIEW_PET_TALENT_POINTS_CHANGED");
	self:RegisterEvent("PLAYER_TALENT_UPDATE");
	self:RegisterEvent("PET_TALENT_UPDATE");

	-- Artifact sparkle atlases do not exist in the 3.3.5a client.
	self.CrestRune1:SetTexture(nil)
	self.CrestSparks:SetTexture(nil)
	self.CrestSparks2:SetTexture(nil)
	self.CrestGlowies:SetTexture(nil)
	self.CrestGlowies2:SetTexture(nil)
	self.CrestGlowies3:SetTexture(nil)
	self.CrestGlowies4:SetTexture(nil)
	self.CrestGlowies5:SetTexture(nil)
	self.CrestGlowies6:SetTexture(nil)
end

function PlayerTalentFrameTalent_OnClick(self, button)
    if PlayerTalentFrame.previewState then
        return
    end

    if (IsModifiedClick("CHATLINK")) then
        local link = GetTalentLink(self:GetParent().talentTree, self:GetID(),
			PlayerTalentFrame.inspect, PlayerTalentFrame.pet, PlayerTalentFrame.talentGroup, GetCVarBool("previewTalents"));
        if (link) then
            ChatEdit_InsertLink(link);
        end
    elseif (selectedSpec and (activeSpec == selectedSpec)) then
        -- only allow functionality if an active spec is selected
        if (button == "LeftButton") then
            if (GetCVarBool("previewTalents")) then
                AddPreviewTalentPoints(self:GetParent().talentTree, self:GetID(), 1, PlayerTalentFrame.pet, PlayerTalentFrame.talentGroup);
            else
                LearnTalent(self:GetParent().talentTree, self:GetID(), PlayerTalentFrame.pet, PlayerTalentFrame.talentGroup);
            end
        elseif (button == "RightButton") then
            if (GetCVarBool("previewTalents")) then
                AddPreviewTalentPoints(self:GetParent().talentTree, self:GetID(), -1, PlayerTalentFrame.pet, PlayerTalentFrame.talentGroup);
            end
        end
    end
end

function PlayerTalentFrameTalent_OnEvent(self, event, ...)
    if (GameTooltip:IsOwned(self)) then
        GameTooltip:SetTalent(self:GetParent().talentTree, self:GetID(),
                PlayerTalentFrame.inspect, PlayerTalentFrame.pet, PlayerTalentFrame.talentGroup, GetCVarBool("previewTalents"));
    end
end

function PlayerTalentFrameTalent_OnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
    GameTooltip:SetTalent(self:GetParent().talentTree, self:GetID(),
            PlayerTalentFrame.inspect, PlayerTalentFrame.pet, PlayerTalentFrame.talentGroup, GetCVarBool("previewTalents"));

    local _, _, spellID = GameTooltip:GetSpell()
    if spellID then
        self.spellID = spellID
    end
end

function PlayerTalentFrameTalent_OnDragStart(self, button)
	if self.isExceptional and not self._isDisable then
		PickupSpell(GetSpellInfo(self.spellID))
	end
end

function PlayerTalentFrameTalent_PlayLearnAnim(self)
	self.CrestSparks.RuneAnim:Play()
	self.CrestSparks.RuneAnim:Play()
	self.CrestGlowies.RuneAnim:Play()
	self.CrestGlowies2.RuneAnim:Play()
	self.CrestGlowies3.RuneAnim:Play()
	self.CrestGlowies4.RuneAnim:Play()
	self.CrestGlowies5.RuneAnim:Play()
	self.CrestGlowies6.RuneAnim:Play()

	self.CrestRune1.RuneAnim:Play()
	self.GlowBorderAnim.RuneAnim:Play()
end


-- Controls

function PlayerTalentFrame_UpdateControls(activeTalentGroup, numTalentGroups)
	local spec = selectedSpec and specs[selectedSpec];
	local isActiveSpec = selectedSpec == activeSpec;

    -- show the multi-spec status frame if this is not a pet spec or we have more than one talent group
    local showStatusFrame    = not spec.pet and numTalentGroups > 1;
    -- show the activate button if we were going to show the status frame but this is not the active spec
    local showActivateButton = showStatusFrame and not isActiveSpec;
	local selectedTab = PanelTemplates_GetSelectedTab(PlayerTalentFrame)

    if (showActivateButton) then
		TalentRetail_SetShown(PlayerTalentFrame.ActivateButton, selectedTab ~= GLYPH_TALENT_TAB and not PlayerTalentFrame.previewState);
		TalentRetail_SetShown(PlayerTalentFrame.CurrencySelectFrame, selectedTab ~= GLYPH_TALENT_TAB and C_Talent.GetSelectedTalentGroup() > 2)
        PlayerTalentFrameStatusFrame:Hide();
    else
        PlayerTalentFrameActivateButton:Hide();
        PlayerTalentFrame.CurrencySelectFrame:Hide()
        if (showStatusFrame) then
            PlayerTalentFrameStatusFrame:Show();
        else
            PlayerTalentFrameStatusFrame:Hide();
        end
    end

	local hasSpentPoints = C_Talent.GetTalentGroupTotalPointSpent(C_Talent.GetSelectedTalentGroup()) > 0
	TalentRetail_SetShown(PlayerTalentFrame.ResetTalentGroupButton, isActiveSpec and hasSpentPoints and not spec.pet and selectedTab ~= GLYPH_TALENT_TAB and not PlayerTalentFrame.previewState)

	local preview = GetCVarBool("previewTalents");

    -- enable the control bar if this is the active spec, preview is enabled, and preview points were spent
    local talentPoints = GetUnspentTalentPoints(false, PlayerTalentFrame.pet, spec.talentGroup);
    if ((spec.pet or isActiveSpec) and talentPoints > 0 and preview) then
        PlayerTalentFramePreviewBar:Show();
        -- squish all frames to make room for this bar
        PlayerTalentFramePointsBar:SetPoint("BOTTOM", PlayerTalentFramePreviewBar, "TOP", 0, -4);
    else
        PlayerTalentFramePreviewBar:Hide();
        -- unsquish frames since the bar is now hidden
        PlayerTalentFramePointsBar:SetPoint("BOTTOM", PlayerTalentFrame, "BOTTOM", 0, 81);
    end

    -- enable accept/cancel buttons if preview talent points were spent
	local previewPointsSpent = GetGroupPreviewTalentPointsSpent(PlayerTalentFrame.pet, spec.talentGroup);
	if (previewPointsSpent > 0) and not PlayerTalentFrame.learnPreviewTalentsAnimation then
        PlayerTalentFrameLearnButton:Enable();
        PlayerTalentFrameResetButton:Enable();
    else
        PlayerTalentFrameLearnButton:Disable();
        PlayerTalentFrameResetButton:Disable();
    end

    local unspentPreviewPoints = talentPoints - GetGroupPreviewTalentPointsSpent(PlayerTalentFrame.pet, PlayerTalentFrame.talentGroup)
    local selectedTab          = PanelTemplates_GetSelectedTab(PlayerTalentFrame)

    TalentRetail_SetShown(PlayerTalentFrameResetButton, selectedTab ~= GLYPH_TALENT_TAB and preview)
    TalentRetail_SetShown(PlayerTalentFrameLearnButton, selectedTab ~= GLYPH_TALENT_TAB and preview)

	if PlayerTalentFrame.previewState then
		PlayerTalentFrame.HeaderFrame.Text:SetFormattedText(PREVIEW_UNSPENT_TALENT_POINTS, unspentPreviewPoints)
	else
		PlayerTalentFrame.HeaderFrame.Text:SetFormattedText(PlayerTalentFrame.pet and PET_UNSPENT_TALENT_POINTS or PLAYER_UNSPENT_TALENT_POINTS, unspentPreviewPoints)
	end
	TalentRetail_SetShown(PlayerTalentFrame.HeaderFrame.Text, not PlayerTalentFrame.resetTalentsForPreview and not PlayerTalentFrame.learnPreviewTalentsAnimation)
	PlayerTalentFrame.HeaderFrame.SubText:Hide()
	TalentRetail_SetShown(PlayerTalentFrameHeaderFrame, unspentPreviewPoints and unspentPreviewPoints > 0 and selectedTab ~= GLYPH_TALENT_TAB and isActiveSpec)

    TalentRetail_SetShown(PlayerTalentFrameBackButton, PlayerTalentFrame.previewState)
    TalentRetail_SetShown(PlayerTalentFrameScreenshotButton, PlayerTalentFrame.previewState)

	TalentRetail_SetShown(PlayerTalentLinkButton, selectedTab == TALENTS_TAB and not PlayerTalentFrame.previewState and C_Talent.HasPlayerAnyTalentInfo(true, false))

    if PlayerTalentFrame.previewState then
		PlayerTalentFrameResetButton:Hide()
		PlayerTalentFrameTab1:Hide()
		PlayerTalentFrameTab2:Hide()
		PlayerTalentFrameTab3:Hide()
    end
end

function PlayerTalentFrameActivateButton_OnLoad(self)
    self:SetWidth(self:GetTextWidth() + 40);
end

function PlayerTalentFrameActivateButton_OnClick(self)
	C_Talent.SetActiveTalentGroup(C_Talent.GetLastSecondTalentGroup())
end

function PlayerTalentFrameActivateButton_OnShow(self)
    self:RegisterEvent("CURRENT_SPELL_CAST_CHANGED");
    PlayerTalentFrameActivateButton_Update();
end

function PlayerTalentFrameActivateButton_OnHide(self)
    self:UnregisterEvent("CURRENT_SPELL_CAST_CHANGED");
end

function PlayerTalentFrameActivateButton_OnEvent(self, event, ...)
    PlayerTalentFrameActivateButton_Update();
end

function PlayerTalentFrameActivateButton_OnEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:SetText(TALENT_SPEC_ACTIVATE, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)

	if self:IsEnabled() == 1 then
		if C_Talent.GetSelectedTalentGroup() > 2 then
			local name, icon, amount, itemID, itemLink = C_Talent.GetCurrencyInfo(C_Talent.GetSelectedCurrency())
			if name then
				GameTooltip:AddLine(string.format(TALENTS_ACTIVE_BUTTON_DESC, BAG_ITEM_QUALITY_COLORS[LE_ITEM_QUALITY_EPIC]:WrapTextInColorCode("["..name.."]")), NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1)
			end
		end
	else
		GameTooltip:AddLine(self.disabledReason, RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b, 1)
	end

	local selectedCurrency = C_Talent.GetSelectedCurrency()
	if selectedCurrency then
		local animationObject = _G["PlayerTalentFrameCurrencySelectFrameCurrency"..selectedCurrency]:GetCheckedTexture().animPulse
		AnimationStopAndPlay(animationObject, animationObject)
	end

	GameTooltip:Show()
end

function PlayerTalentFrameActivateButton_OnLeave(self)
	local selectedCurrency = C_Talent.GetSelectedCurrency()
	if selectedCurrency then
		_G["PlayerTalentFrameCurrencySelectFrameCurrency"..selectedCurrency]:GetCheckedTexture().animPulse:Stop()
	end

	GameTooltip_Hide()
end

function PlayerTalentFrameActivateButton_Update()
    local spec = selectedSpec and specs[selectedSpec];
    if (spec and PlayerTalentFrameActivateButton:IsShown()) then
        -- if the activation spell is being cast currently, disable the activate button
        if (IsCurrentSpell(TALENT_ACTIVATION_SPELLS[spec.talentGroup])) then
            PlayerTalentFrameActivateButton:Disable();
        else
            PlayerTalentFrameActivateButton:Enable();
        end
    end
end

function PlayerTalentFrameResetTalentGroupButton_OnEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	if self:IsEnabled() == 1 then
		GameTooltip:AddLine(TALENT_TOOLTIP_RESET_LEARNED_TALENTGROUP)
	else
		GameTooltip:AddLine(TALENT_TOOLTIP_RESET_LEARNED_TALENTGROUP_NOT_ENOUGH_MONEY, RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b)
	end

	local resetCost = C_Talent.GetResetCost()
	if resetCost then
		GameTooltip:AddLine(string.format(TALENT_TOOLTIP_RESET_LEARNED_TALENTGROUP_PRICE, GetMoneyString(resetCost)), HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
	end
	GameTooltip:Show()
end

function PlayerTalentFrameResetTalentGroupButton_OnClick(self, button)
	local resetCost = C_Talent.GetResetCost()
	if not resetCost then
		return
	end

	local dialog = StaticPopup_Show("CONFIRM_TALENT_WIPE_DIRECT")
	if dialog then
		MoneyFrame_Update(dialog:GetName().."MoneyFrame", resetCost)
	end
end

function PlayerTalentFrameResetButton_OnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
    GameTooltip:SetText(TALENT_TOOLTIP_RESETTALENTGROUP);
end

function PlayerTalentFrameResetButton_OnClick(self)
    ResetGroupPreviewTalentPoints(PlayerTalentFrame.pet, PlayerTalentFrame.talentGroup);
end

function PlayerTalentFrameLearnButton_OnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
    GameTooltip:SetText(TALENT_TOOLTIP_LEARNTALENTGROUP);
end

function PlayerTalentFrameLearnButton_OnClick(self)
	if (not PlayerTalentFrame.pet and UnitIsDeadOrGhost("player")) then
		UIErrorsFrame:AddMessage(ERR_PLAYER_DEAD, 1.0, 0.1, 0.1, 1.0);
	elseif PlayerTalentFrame.previewState then
		if PlayerTalentFrame.pointSprent == 0 then
			PlayerTalentFrame_SetPreviewTalentState(PlayerTalentFrame, true)
		else
			local resetCost = C_Talent.GetResetCost()
			if resetCost then
				if resetCost > 0 then
					StaticPopup_Show("PLAYER_TALENT_LEARN_PREVIEW_PAY", PLAYER_TALENT_LEARN_PREVIEW_TEXT_PAY, nil, resetCost)
				else
					StaticPopup_Show("PLAYER_TALENT_LEARN_PREVIEW_NO_PAY", PLAYER_TALENT_LEARN_PREVIEW_TEXT_NO_PAY)
				end
			end
		end
    else
        StaticPopup_Show("CONFIRM_LEARN_PREVIEW_TALENTS");
    end
end

function TalentFramePanelSummary_OnUpdate(self, elapsed, ...)
	if not self.needAnimation then
		return
	end

	local easing = EasingUtil.OutSine(self.elapsed, 0, 250 + iconYOffset, 0.500)
	local offset

	if self.isHiddenAnimation then
		offset = (250 + iconYOffset) - easing
	else
		offset = easing
	end

	if offset > 0 then
		self:SetAlpha(1)
		self:SetHeight(offset)
	else
		self:SetAlpha(0)
		self:SetHeight(0)
	end

	self.elapsed = self.elapsed + elapsed
	if self.elapsed > 0.500 then
		self.needAnimation = false
		self.elapsed = 0

		if self.isHiddenAnimation then
			self:Hide()
			self:GetParent().ShadowFrame:Hide()
		end
	end
end

function ToggleSummariesButton_OnClick(self, button)
	if PlayerTalentFramePanel1.Summary.needAnimation then
		return
	end

	for i = 1, 3 do
		local panel = _G["PlayerTalentFramePanel" .. i]

		panel.Summary:SetHeight(0)
		panel.Summary.needAnimation = true
		panel.Summary.elapsed = 0
		panel.Summary.isHiddenAnimation = panel.Summary:IsShown()

		if not panel.Summary.isHiddenAnimation then
			panel.Summary:Show()
			panel.ShadowFrame:Show()

			AnimationStopAndPlay(panel.Summary.TitleText.animIN, panel.Summary.TitleText.animOUT)
			AnimationStopAndPlay(panel.Summary.IconBorder.animIN, panel.Summary.IconBorder.animOUT)
			AnimationStopAndPlay(panel.Summary.Icon.animIN, panel.Summary.Icon.animOUT)
			AnimationStopAndPlay(panel.Summary.IconGlow.animIN, panel.Summary.IconGlow.animOUT)
			AnimationStopAndPlay(panel.Summary.DescriptionText.animIN, panel.Summary.DescriptionText.animOUT)
			AnimationStopAndPlay(panel.Summary.RoleIcon.animIN, panel.Summary.RoleIcon.animOUT)
			AnimationStopAndPlay(panel.Summary.RoleIcon2.animIN, panel.Summary.RoleIcon2.animOUT)
			AnimationStopAndPlay(panel.Summary.ActiveBonus1.animIN, panel.Summary.ActiveBonus1.animOUT)
			AnimationStopAndPlay(panel.Summary.Bonus1.animIN, panel.Summary.Bonus1.animOUT)
			AnimationStopAndPlay(panel.Summary.Bonus2.animIN, panel.Summary.Bonus2.animOUT)
			AnimationStopAndPlay(panel.Summary.Bonus3.animIN, panel.Summary.Bonus3.animOUT)
			AnimationStopAndPlay(panel.Summary.Bonus4.animIN, panel.Summary.Bonus4.animOUT)
			AnimationStopAndPlay(panel.Summary.Bonus5.animIN, panel.Summary.Bonus5.animOUT)

			AnimationStopAndPlay(panel.ShadowFrame.animIN, panel.ShadowFrame.animOUT)
		else
			AnimationStopAndPlay(panel.Summary.TitleText.animOUT, panel.Summary.TitleText.animIN)
			AnimationStopAndPlay(panel.Summary.IconBorder.animOUT, panel.Summary.IconBorder.animIN)
			AnimationStopAndPlay(panel.Summary.Icon.animOUT, panel.Summary.Icon.animIN)
			AnimationStopAndPlay(panel.Summary.IconGlow.animOUT, panel.Summary.IconGlow.animIN)
			AnimationStopAndPlay(panel.Summary.DescriptionText.animOUT, panel.Summary.DescriptionText.animIN)
			AnimationStopAndPlay(panel.Summary.RoleIcon.animOUT, panel.Summary.RoleIcon.animIN)
			AnimationStopAndPlay(panel.Summary.RoleIcon2.animOUT, panel.Summary.RoleIcon2.animIN)
			AnimationStopAndPlay(panel.Summary.ActiveBonus1.animOUT, panel.Summary.ActiveBonus1.animIN)
			AnimationStopAndPlay(panel.Summary.Bonus1.animOUT, panel.Summary.Bonus1.animIN)
			AnimationStopAndPlay(panel.Summary.Bonus2.animOUT, panel.Summary.Bonus2.animIN)
			AnimationStopAndPlay(panel.Summary.Bonus3.animOUT, panel.Summary.Bonus3.animIN)
			AnimationStopAndPlay(panel.Summary.Bonus4.animOUT, panel.Summary.Bonus4.animIN)
			AnimationStopAndPlay(panel.Summary.Bonus5.animOUT, panel.Summary.Bonus5.animIN)

			AnimationStopAndPlay(panel.ShadowFrame.animOUT, panel.ShadowFrame.animIN)
		end
	end

	if EventRegistry and EventRegistry.TriggerEvent then
		EventRegistry:TriggerEvent("PlayerTalentFrame.Summary")
	end
end

function PlayerTalentCurrency_OnLoad(self)
	local parent = self:GetParent()
	parent.currencyButtons = parent.currencyButtons or {}
	table.insert(parent.currencyButtons, self)

	local name, icon, amount, itemID, itemLink = C_Talent.GetCurrencyInfo(self:GetID())
	self.Icon:SetTexture(icon)
end

function PlayerTalentCurrency_OnClick(self, button)
	for index, currencyButton in ipairs(self:GetParent().currencyButtons) do
		currencyButton:SetChecked(currencyButton == self)
	end
	C_Talent.SelectedCurrency(self:GetID())
end


-- PlayerTalentFrameDownArrow

function PlayerTalentFrameDownArrow_OnClick(self, button) -- deprecated
    local parent = self:GetParent();
    parent:SetValue(parent:GetValue() + (parent:GetHeight() / 2));
    PlaySound("UChatScrollButton");
end


-- PlayerTalentFrameTab

function PlayerTalentFrame_UpdateTabs(playerLevel)
    local totalTabWidth              = 0;
    local firstShownTab              = _G["PlayerTalentFrameTab" .. TALENTS_TAB];
    local selectedTab                = PanelTemplates_GetSelectedTab(PlayerTalentFrame) or TALENTS_TAB;
    local numVisibleTabs             = 0;
    local tab;

    -- setup talent tab
    talentTabWidthCache[TALENTS_TAB] = 0;
    tab                              = _G["PlayerTalentFrameTab" .. TALENTS_TAB];
    if (tab) then
        tab:Show();
        firstShownTab = firstShownTab or tab;
        PanelTemplates_TabResize(tab, 0);
        talentTabWidthCache[TALENTS_TAB] = PanelTemplates_GetTabWidth(tab);
        totalTabWidth                    = totalTabWidth + talentTabWidthCache[TALENTS_TAB];
        numVisibleTabs                   = numVisibleTabs + 1;
    end

    -- setup pet talents tab
    talentTabWidthCache[PET_TALENTS_TAB] = 0;
    tab                                  = _G["PlayerTalentFrameTab" .. PET_TALENTS_TAB];
    local petTalentGroups                = GetNumTalentGroups(false, true);
    if (tab and petTalentGroups > 0 and select(2, HasPetUI())) then
        tab:Show();
        firstShownTab = firstShownTab or tab;
        PanelTemplates_TabResize(tab, 0);
        talentTabWidthCache[PET_TALENTS_TAB] = PanelTemplates_GetTabWidth(tab);
        totalTabWidth                        = totalTabWidth + talentTabWidthCache[PET_TALENTS_TAB];
        numVisibleTabs                       = numVisibleTabs + 1;
    else
        tab:Hide();
        talentTabWidthCache[PET_TALENTS_TAB] = 0;
    end

    -- setup glyph tab
    playerLevel           = playerLevel or UnitLevel("player");
    local meetsGlyphLevel = playerLevel >= SHOW_INSCRIPTION_LEVEL;
    tab                   = _G["PlayerTalentFrameTab" .. GLYPH_TALENT_TAB];
    if (meetsGlyphLevel) then
        tab:Show();
        firstShownTab = firstShownTab or tab;
        PanelTemplates_TabResize(tab, 0);
        talentTabWidthCache[GLYPH_TALENT_TAB] = PanelTemplates_GetTabWidth(tab);
        totalTabWidth                         = totalTabWidth + talentTabWidthCache[GLYPH_TALENT_TAB];
        numVisibleTabs                        = numVisibleTabs + 1;
    else
        tab:Hide();
        talentTabWidthCache[GLYPH_TALENT_TAB] = 0;
    end

    -- select the first shown tab if the selected tab does not exist for the selected spec
    tab = _G["PlayerTalentFrameTab" .. selectedTab];
    if (tab and not tab:IsShown()) then
        if (firstShownTab) then
            PlayerTalentFrameTab_OnClick(firstShownTab);
        end
        return false;
    end

    -- readjust tab sizes to fit
    local maxTotalTabWidth = PlayerTalentFrame:GetWidth();
    while (totalTabWidth >= maxTotalTabWidth) do
        -- progressively shave 10 pixels off of the largest tab until they all fit within the max width
        local largestTab = 1;
        for i = 2, #talentTabWidthCache do
            if (talentTabWidthCache[largestTab] < talentTabWidthCache[i]) then
                largestTab = i;
            end
        end
        -- shave the width
        talentTabWidthCache[largestTab] = talentTabWidthCache[largestTab] - 10;
        -- apply the shaved width
        tab                             = _G["PlayerTalentFrameTab" .. largestTab];
        PanelTemplates_TabResize(tab, 0, talentTabWidthCache[largestTab]);
        -- now update the total width
        totalTabWidth = totalTabWidth - 10;
    end

    -- Reposition the visible tabs
    local x = 15;
    for i = 1, NUM_TALENT_FRAME_TABS do
        tab = _G["PlayerTalentFrameTab" .. i];
        if (tab:IsShown()) then
            tab:ClearAllPoints();
            tab:SetPoint("TOPLEFT", PlayerTalentFrame, "BOTTOMLEFT", x, 1);
            x = x + talentTabWidthCache[i] - 15;
        end
    end

    -- update the tabs
    PanelTemplates_UpdateTabs(PlayerTalentFrame);

    return true;
end

function PlayerTalentFrameTab_OnLoad(self)
    self:SetFrameLevel(self:GetFrameLevel() + 2);
end

function PlayerTalentFrameTab_OnClick(self)
	local id = self:GetID();
    PlayerTalentFrame.secureLastTabIndex = id
	PanelTemplates_SetTab(PlayerTalentFrame, id);
	PlayerTalentFrame_Refresh();
	if PlayerTalentPopupFrame then
		PlayerTalentPopupFrame:Hide()
	end
	PlaySound("igCharacterInfoTab");
end

function PlayerTalentFrameTab_OnEnter(self)
    if (self.textWidth and self.textWidth > self:GetTextWidth()) then
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM");
        GameTooltip:SetText(self:GetText());
    end
end


-- PlayerTalentTab

function PlayerTalentTab_OnLoad(self)
    PlayerTalentFrameTab_OnLoad(self);

    self:RegisterEvent("PLAYER_LEVEL_UP");
end

function PlayerTalentTab_OnClick(self)
    PlayerTalentFrameTab_OnClick(self);
    for i = 1, MAX_TALENT_TABS do
        SetButtonPulse(_G["PlayerTalentFrameTab" .. i], 0, 0);
    end
end

function PlayerTalentTab_OnEvent(self, event, ...)
    if (UnitLevel("player") == (SHOW_TALENT_LEVEL - 1) and PanelTemplates_GetSelectedTab(PlayerTalentFrame) ~= self:GetID()) then
        SetButtonPulse(self, 60, 0.75);
    end
end

function PlayerTalentTab_GetBestDefaultTab(specIndex)
    if (not specIndex) then
        return DEFAULT_TALENT_TAB;
    end

    local spec = specs[specIndex];
    if (not spec) then
        return DEFAULT_TALENT_TAB;
    end

    local specInfoCache = talentSpecInfoCache[specIndex];
    TalentFrame_UpdateSpecInfoCache(specInfoCache, false, spec.pet, spec.talentGroup);
    if (specInfoCache.primaryTabIndex > 0) then
        return talentSpecInfoCache[specIndex].primaryTabIndex;
    else
        return DEFAULT_TALENT_TAB;
    end
end


-- PlayerGlyphTab

function PlayerGlyphTab_OnLoad(self)
    PlayerTalentFrameTab_OnLoad(self);

    self:RegisterEvent("PLAYER_LEVEL_UP");
    GLYPH_TALENT_TAB = self:GetID();
    -- we can record the text width for the glyph tab now since it never changes
    self.textWidth   = self:GetTextWidth();
end

function PlayerGlyphTab_OnClick(self)
    PlayerTalentFrameTab_OnClick(self);
    SetButtonPulse(_G["PlayerTalentFrameTab" .. GLYPH_TALENT_TAB], 0, 0);
end

function PlayerGlyphTab_OnEvent(self, event, ...)
    if (UnitLevel("player") == (SHOW_INSCRIPTION_LEVEL - 1) and PanelTemplates_GetSelectedTab(PlayerTalentFrame) ~= self:GetID()) then
        SetButtonPulse(self, 60, 0.75);
    end
end


-- Specs

-- PlayerTalentFrame_UpdateSpecs is a helper function for PlayerTalentFrame_Update.
-- Returns true on a successful update, false otherwise. An update may fail if the currently
-- selected tab is no longer selectable. In this case, the first selectable tab will be selected.
function PlayerTalentFrame_UpdateSpecs(activeTalentGroup, numTalentGroups)
    -- set the active spec highlight to be hidden initially, if a spec is the active one then it will
    -- be shown in PlayerSpecTab_Update
    PlayerTalentFrameActiveSpecTabHighlight:Hide();

    -- update each of the spec tabs
    local firstShownTab, lastShownTab;
    local numShown = 0;
    local offsetX  = 0;
    for i = 1, numSpecTabs do
        local frame     = _G["PlayerSpecTab" .. i];
        local specIndex = frame.specIndex;
        if (PlayerSpecTab_Update(frame, activeTalentGroup, numTalentGroups)) then
            firstShownTab = firstShownTab or frame;
            numShown      = numShown + 1;
            frame:ClearAllPoints();
            -- set an offsetX fudge if we're the selected tab, otherwise use the previous offsetX
            offsetX = specIndex == selectedSpec and SELECTEDSPEC_OFFSETX or offsetX;
            if (numShown == 1) then
                --...start the first tab off at a base location
                frame:SetPoint("TOPLEFT", frame:GetParent(), "TOPRIGHT", offsetX, -36);
                -- we'll need to negate the offsetX after the first tab so all subsequent tabs offset
                -- to their default positions
                offsetX = -offsetX;
            else
                --...offset subsequent tabs from the previous one
                frame:SetPoint("TOPLEFT", lastShownTab, "BOTTOMLEFT", 0 + offsetX, -22);
            end
            lastShownTab = frame;
        else
            -- if the selected tab is not shown then clear out the selected spec
            if (specIndex == selectedSpec) then
                selectedSpec = nil;
            end
        end
    end

    if (not selectedSpec) then
        if (firstShownTab) then
            PlayerSpecTab_OnClick(firstShownTab);
        end
        return false;
    end

    if (numShown == 1 and lastShownTab) then
        -- if we're only showing one tab, we might as well hide it since it doesn't need to be there
        lastShownTab:Hide();
    end

    return true;
end

function PlayerSpecTab_Update(self, activeTalentGroup, numTalentGroups)
    local specIndex = self.specIndex;
    local spec      = specs[specIndex];

    -- determine whether or not we need to hide the tab
    local canShow   = spec.talentGroup <= numTalentGroups;

    if (not canShow) then
        self:Hide();
        return false;
    end

    local isSelectedSpec = specIndex == selectedSpec;
    local isActiveSpec   = spec.talentGroup == activeTalentGroup;
    local normalTexture  = self:GetNormalTexture();

    -- set the background based on whether or not we're selected
    if (isSelectedSpec and (SELECTEDSPEC_DISPLAYTYPE == "PUSHED_OUT" or SELECTEDSPEC_DISPLAYTYPE == "PUSHED_OUT_CHECKED")) then
		local name = self:GetName();
        local backgroundTexture = _G[name .. "Background"];
        backgroundTexture:SetTexture("Interface\\TalentFrame\\UI-TalentFrame-SpecTab");
        backgroundTexture:SetPoint("TOPLEFT", self, "TOPLEFT", -13, 11);
        if (SELECTEDSPEC_DISPLAYTYPE == "PUSHED_OUT_CHECKED") then
            self:GetCheckedTexture():Show();
        else
            self:GetCheckedTexture():Hide();
        end
    else
		local name = self:GetName();
        local backgroundTexture = _G[name .. "Background"];
        backgroundTexture:SetTexture("Interface\\SpellBook\\SpellBook-SkillLineTab");
        backgroundTexture:SetPoint("TOPLEFT", self, "TOPLEFT", -3, 11);
    end

    -- update the active spec info
    local hasMultipleTalentGroups = numTalentGroups > 1;
    if (isActiveSpec and hasMultipleTalentGroups) then
        PlayerTalentFrameActiveSpecTabHighlight:ClearAllPoints();
        if (ACTIVESPEC_DISPLAYTYPE == "BLUE") then
            PlayerTalentFrameActiveSpecTabHighlight:SetParent(self);
            PlayerTalentFrameActiveSpecTabHighlight:SetPoint("TOPLEFT", self, "TOPLEFT", -13, 14);
            PlayerTalentFrameActiveSpecTabHighlight:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 15, -14);
            PlayerTalentFrameActiveSpecTabHighlight:Show();
        elseif (ACTIVESPEC_DISPLAYTYPE == "GOLD_INSIDE") then
            PlayerTalentFrameActiveSpecTabHighlight:SetParent(self);
            PlayerTalentFrameActiveSpecTabHighlight:SetAllPoints(self);
            PlayerTalentFrameActiveSpecTabHighlight:Show();
        elseif (ACTIVESPEC_DISPLAYTYPE == "GOLD_BACKGROUND") then
            PlayerTalentFrameActiveSpecTabHighlight:SetParent(self);
            PlayerTalentFrameActiveSpecTabHighlight:SetPoint("TOPLEFT", self, "TOPLEFT", -3, 20);
            PlayerTalentFrameActiveSpecTabHighlight:Show();
        else
            PlayerTalentFrameActiveSpecTabHighlight:Hide();
        end
    end

    -- update the spec info cache
    TalentFrame_UpdateSpecInfoCache(talentSpecInfoCache[specIndex], false, PlayerTalentFrame.pet, spec.talentGroup);

	-- update spec tab icon
    if (hasMultipleTalentGroups) then
		local specInfoCache = talentSpecInfoCache[specIndex];
		local primaryTree = specInfoCache.primaryTabIndex
		if specInfoCache[primaryTree] and specInfoCache[primaryTree].icon then
			normalTexture:SetTexture(specInfoCache[primaryTree].icon);
		else
			if ( spec.defaultSpecTexture ) then
				-- the spec is probably untalented...set to the default spec texture if we have one
				normalTexture:SetTexture(spec.defaultSpecTexture);
			end
        end
    end

    PlayerTalentFrame.talentCache = talentSpecInfoCache

    TalentRetail_SetShown(self, not PlayerTalentFrame.pet)
    return true;
end

function PlayerSpecTab_Load(self, specIndex)
    self.specIndex      = specIndex;
    specTabs[specIndex] = self;
    numSpecTabs         = numSpecTabs + 1;

    -- set the spec's portrait
    local spec          = specs[self.specIndex];
    if (spec.portraitUnit) then
        SetPortraitTexture(self:GetNormalTexture(), spec.portraitUnit);
        self.usingPortraitTexture = true;
    else
        self.usingPortraitTexture = false;
    end

    -- set the checked texture
    if (SELECTEDSPEC_DISPLAYTYPE == "BLUE") then
        local checkedTexture = self:GetCheckedTexture();
        checkedTexture:SetTexture("Interface\\Buttons\\UI-Button-Outline");
        checkedTexture:SetWidth(64);
        checkedTexture:SetHeight(64);
        checkedTexture:ClearAllPoints();
        checkedTexture:SetPoint("CENTER", self, "CENTER", 0, 0);
    elseif (SELECTEDSPEC_DISPLAYTYPE == "GOLD_INSIDE") then
        local checkedTexture = self:GetCheckedTexture();
        checkedTexture:SetTexture("Interface\\Buttons\\CheckButtonHilight");
    end

	local activeTalentGroup, numTalentGroups = GetActiveTalentGroup(false, false), GetNumTalentGroups(false, false);
    local activePetTalentGroup, numPetTalentGroups = GetActiveTalentGroup(false, true), GetNumTalentGroups(false, true);
    PlayerSpecTab_Update(self, activeTalentGroup, numTalentGroups, activePetTalentGroup, numPetTalentGroups);
end

function PlayerSpecTab_OnClick(self, button)
    self = self or PlayerTalentFrame.specTabs[1]

    local selectedTalentGroup = C_Talent.GetSelectedTalentGroup()

    if button and button ~= "LeftButton" then
        self:SetChecked(selectedTalentGroup == self.specIndex)
        return
    end

    if PlayerTalentPopupFrame and PlayerTalentPopupFrame:IsShown() then
        PlayerTalentPopupFrame:Hide()
    end

    if not selectedTalentGroup or selectedTalentGroup ~= self.specIndex then
        C_Talent.SelectTalentGroup( self.specIndex )
    else
        self:SetChecked(true)
    end
end

function PlayerSpecTab_OnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

	local note = C_Talent.GetTalentGroupNote(self.specIndex)
	if note and note ~= "" then
		GameTooltip:AddLine(note)
	else
        GameTooltip:AddLine(string.format(TALENT_TAB_NAME, self.specIndex))
    end

    if self.specIndex == C_Talent.GetActiveTalentGroup() then
        GameTooltip:AddLine(TALENT_ACTIVE_SPEC_STATUS, GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g, GREEN_FONT_COLOR.b)
    end

	local tabPointSpent = {C_Talent.GetTalentGroupPointSpent(self.specIndex)}
	local pointsColor;
    for index, tabInfo in pairs(self.tabInfo) do
        if tabInfo.isPrimary then
			pointsColor = GREEN_FONT_COLOR;
		else
			pointsColor = HIGHLIGHT_FONT_COLOR;
		end

		GameTooltip:AddDoubleLine(
			tabInfo.name,
			tabPointSpent[index],
			HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b,
			pointsColor.r, pointsColor.g, pointsColor.b,
			1
		);
	end

    GameTooltip:AddLine(" ");
    GameTooltip:AddLine(CLICK_TALENT_TAB_SETTING, GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g, GREEN_FONT_COLOR.b, 1);
    GameTooltip:Show()
end

function TalentFrameButtonTemplate_OnUpdate( self )
    local name = self:GetName()

    if self:IsEnabled() == 0 then
        _G[name.."Left"]:SetTexture("Interface\\Buttons\\UI-Panel-Button-Disabled")
        _G[name.."Middle"]:SetTexture("Interface\\Buttons\\UI-Panel-Button-Disabled")
        _G[name.."Right"]:SetTexture("Interface\\Buttons\\UI-Panel-Button-Disabled")
    else
		local stateTexture

		if self:GetButtonState() == "PUSHED" then
			stateTexture = [[Interface\Buttons\UI-Panel-Button-Down]]
		else
			stateTexture = [[Interface\Buttons\UI-Panel-Button-Up]]
		end

		_G[name.."Left"]:SetTexture(stateTexture)
		_G[name.."Middle"]:SetTexture(stateTexture)
		_G[name.."Right"]:SetTexture(stateTexture)
		self:GetHighlightTexture():SetTexture([[Interface\Buttons\UI-Panel-Button-Highlight]])
	end
end

function PlayerTalentPopupFrame_OnLoad(self)
    self.buttons = {};
    self.searchResult = {};
    self.hasSearchResults = false;

    local previousButton = CreateFrame("CheckButton", "PlayerTalentPopupButton1", self, "PlayerTalentPopupButtonTemplate")
    self.buttons[1] = previousButton
    local cornerButton = previousButton
    previousButton:SetPoint("TOPLEFT", 24, -95)

    local numIcons = NUM_TALENT_POPUP_ICONS_PER_ROW * NUM_TALENT_POPUP_ICON_ROWS;
    for i = 2, numIcons do
        local newButton = CreateFrame("CheckButton", "PlayerTalentPopupButton"..i, self, "PlayerTalentPopupButtonTemplate")
        self.buttons[i] = newButton

        if i % NUM_TALENT_POPUP_ICONS_PER_ROW == 1 then
            newButton:SetPoint("TOPLEFT", cornerButton, "BOTTOMLEFT", 0, -8)
            cornerButton = newButton
        else
            newButton:SetPoint("LEFT", previousButton, "RIGHT", 10, 0)
        end

        previousButton = newButton
        newButton:Hide()
    end
end

function PlayerTalentPopupFrame_OnShow(self)
	SetParentFrameLevel(self.BorderBox, 1)
    PlayerTalentPopupFrame_UpdateSettings(self)
end

function PlayerTalentPopupFrame_OnHide(self)
    PlayerTalentPopupFrame_ResetSearch(self)
	self.specIndex = nil
end

function PlayerTalentPopupFrame_UpdateSettings(self)
	if not self or not self.BorderBox or not self.BorderBox.EditBox then
		return
	end

	local editTalentGroup = self.specIndex or 1

    if self.BorderBox.EditBox.Instructions then
        self.BorderBox.EditBox.Instructions:SetFormattedText(TALENT_TAB_NAME, editTalentGroup)
    end

	local note, texture = C_Talent.GetTalentGroupNote(editTalentGroup)
	self.BorderBox.EditBox:SetText(note or "")
    self.selectedIconTexture = texture or "Interface\\Icons\\INV_Misc_QuestionMark"

    PlayerTalentPopupFrame_Update()
end

function PlayerTalentPopupFrame_Update()
    local popupFrame = PlayerTalentPopupFrame
    local searchResults = popupFrame.searchResult
    local hasSearchResults = popupFrame.hasSearchResults
    local numIcons = hasSearchResults and #searchResults or GetNumMacroIcons()
    local offset = FauxScrollFrame_GetOffset(popupFrame.ScrollFrame)

    for i, popupButton in ipairs(popupFrame.buttons) do
        local index = (offset * NUM_ICONS_PER_ROW) + i
        local texture = GetMacroIconInfo(hasSearchResults and (searchResults[index] or 0) or index)

        if texture and texture ~= "" and index <= numIcons then
            popupButton.Icon:SetTexture(texture)
            popupButton:Show()
        else
            popupButton.Icon:SetTexture("")
            popupButton:Hide()
        end

        popupButton:SetChecked(PlayerTalentPopupFrame.selectedIconTexture == texture)
    end

    FauxScrollFrame_Update(popupFrame.ScrollFrame, ceil(numIcons / NUM_TALENT_POPUP_ICONS_PER_ROW), NUM_TALENT_POPUP_ICON_ROWS, TALENT_POPUP_ICON_ROW_HEIGHT)
end

function PlayerTalentPopupFrame_ResetSearch(self)
    self.BorderBox.SearchBox:SetText("")
    table.wipe(self.searchResult)
    self.hasSearchResults = false
end

function PlayerTalentPopupFrame_SearchUpdate(self)
    local searchText = strtrim(self.BorderBox.SearchBox:GetText() or "")

    if searchText == "" then
        self.hasSearchResults = false
    else
        table.wipe(self.searchResult)
        searchText = string.lower(searchText)

        for index = 1, GetNumMacroIcons() do
            local texture = GetMacroIconInfo(index)
            if texture and string.find(string.lower(texture), searchText, 1, true) then
                self.searchResult[#self.searchResult + 1] = index
            end
        end

        self.hasSearchResults = true
    end
end

function PlayerTalentPopupButton_OnClick(self)
    PlayerTalentPopupFrame.selectedIconTexture = self.Icon:GetTexture()
    PlayerTalentPopupFrame_Update()
end

function PlayerTalentPopuptCancelButton_OnClick(self)
    PlayerTalentPopupFrame:Hide()
    PlaySound("gsTitleOptionOK")
end

function PlayerTalentPopupOkayButton_OnClick(self)
    local popupFrame = PlayerTalentPopupFrame

	C_Talent.SetTalentGroupNote(popupFrame.specIndex or 1, popupFrame.BorderBox.EditBox:GetText(), popupFrame.selectedIconTexture)

    PlayerTalentPopupFrame:Hide()
    PlayerTalentFrame_UpdateActiveSpec(GetActiveTalentGroup(), GetNumTalentGroups())
    PlayerTalentFrame_RefreshSpecTabs()
    PlaySound("gsTitleOptionOK")
end

function PlayerSpecTabAdvertising_OnLoad(self)
	self:RegisterForClicks("LeftButtonUp")
end

function PlayerSpecTabAdvertising_OnClick(self, button)
	if C_Talent.CanPurchaseSecondSpec() then
		StaticPopup_Show("PLAYER_TALENT_PURCHASE_SPEC")
		PlaySound("igCharacterInfoTab")
	end
end

function PlayerSpecTabAdvertising_OnEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

	GameTooltip:SetText(TALENTS_SECOND_SPEC_HINT)

	if self:IsEnabled() == 1 then
		GameTooltip:AddLine(TALENTS_SECOND_SPEC_LEARN_HINT, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b, true)
		GameTooltip:AddLine(TALENTS_SECOND_SPEC_CLICK_HINT, GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g, GREEN_FONT_COLOR.b, true)
		SetTooltipMoney(GameTooltip, C_Talent.GetSecondSpecPrice(), nil, COSTS_LABEL)
	else
		GameTooltip:AddLine(TALENTS_SECOND_SPEC_LOW_LEVEL_HINT, GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b, true)
	end

	GameTooltip:Show()
end

-- Preview

function TalentFramePreviewShow()
	local pointSprent = 0

	for i = 1, 3 do
		local _, _, pointsSpent, _, previewPointsSpent = GetTalentTabInfo(i, PlayerTalentFrame.inspect, PlayerTalentFrame.pet, 1)
		pointSprent = pointSprent + (pointsSpent + previewPointsSpent)
	end

	PlayerTalentFrame.pointSprent = pointSprent
	PlayerTalentFrame.previewState = true

	PlayerGlyphPreviewFrame_OnShow(PlayerGlyphPreviewFrame)
end

function TalentFramePreviewHide(keepPreview)
	PlayerTalentFrame.previewState = false
	PlayerGlyphPreviewFrame:Hide()

	if not keepPreview then
		C_Talent.SetPreviewEnabled(false)
	end
end

function TalentFrameSetupPreviewTalents()
	local previewTalents = C_Talent.GetPreviewTalents()
	if not previewTalents then
		return
	end

	if C_Talent.GetSelectedTalentGroup() ~= C_Talent.GetActiveTalentGroup() then
		C_Talent.SelectTalentGroup(C_Talent.GetActiveTalentGroup())
	end

	for tabIndex = 1, NUM_TALENT_FRAME_TABS do
		local pointsSpent = 0

		for index, talentInfo in ipairs(previewTalents[tabIndex]) do
			local talentIndex, points = unpack(talentInfo, 1, 2)
			AddPreviewTalentPoints(tabIndex, talentIndex, points)
			pointsSpent = pointsSpent + points
		end

		_G["PlayerTalentFramePanel"..tabIndex].HeaderIcon.PointsSpent:SetText(pointsSpent)
	end
end

function PlayerTalentLinkToButton_OnClick(self, button)
	local link = C_Talent.GenerateTalentHyperlink(true, false)
    if link then
        if MacroFrameText and MacroFrameText:IsShown() and MacroFrameText:HasFocus() then
            local text = MacroFrameText:GetText() .. link
            if strlenutf8(text) <= MacroFrameText:GetMaxLetters() then
                MacroFrameText:Insert(link)
            end
        else
            local activeEditBox = ChatEdit_GetActiveWindow()
            if activeEditBox then
                ChatEdit_InsertLink(link)
            else
                ToggleDropDownMenu(1, nil, self:GetParent().LinkToDropDown, self, 25, 25)
            end
        end
    end
end

function PlayerTalentLinkToDropDownInit(self, level, menuList)
	local info = UIDropDownMenu_CreateInfo()
	local channels = {GetChannelList()}

	info.text = TRADESKILL_POST
	info.isTitle = true
	info.notCheckable = true
	UIDropDownMenu_AddButton(info)

	do
		info.isTitle = nil
		info.func = function(_, channel)
			local link = C_Talent.GenerateTalentHyperlink(true, false)
			if link then
				ChatFrame_OpenChat(string.format("%s %s", channel, link), DEFAULT_CHAT_FRAME)
			end
		end

		info.text = GUILD
		info.arg1 = SLASH_GUILD1
		info.disabled = not IsInGuild()
		UIDropDownMenu_AddButton(info)

		info.text = PARTY
		info.arg1 = SLASH_PARTY1
		info.disabled = GetRealNumPartyMembers() == 0 and GetRealNumRaidMembers() == 0
		UIDropDownMenu_AddButton(info)

		info.text = RAID
		info.arg1 = SLASH_RAID1
		info.disabled = GetRealNumPartyMembers() == 0 and GetRealNumRaidMembers() == 0
		UIDropDownMenu_AddButton(info)

		info.disabled = nil

		for i = 1, #channels, 2 do
			local name = Chat_GetChannelShortcutName(channels[i])
			info.text = name
			info.arg1 = "/" .. channels[i]
			UIDropDownMenu_AddButton(info)
		end
	end

	UIDropDownMenu_AddSeparator()

	info = UIDropDownMenu_CreateInfo()
	info.text = OTHER
	info.isTitle = true
	info.notCheckable = true
	UIDropDownMenu_AddButton(info)
	info.isTitle = nil

	info.text = TALENT_GET_URL_ADRESS_DROPDOWN_TITLE
	info.func = function()
		StaticPopup_Show("TALENTS_EXPORT_URL_POPUP")
	end
	UIDropDownMenu_AddButton(info)

	info.text = TALENT_GET_HYPERLINK_DROPDOWN_TITLE
	info.func = function()
		StaticPopup_Show("TALENTS_EXPORT_INGAMELINK_POPUP")
	end
	UIDropDownMenu_AddButton(info)
end

function PlayerGlyphPreviewFrame_OnLoad(self)
	self.MajorSlots = {self.MajorSlot1, self.MajorSlot2, self.MajorSlot3}
	self.MinorSlots = {self.MinorSlot1, self.MinorSlot2, self.MinorSlot3}
end

function PlayerGlyphPreviewFrame_OnShow(self)
	local majorGlyphs, minorGlyphs = C_Talent.GetPreviewGlyphs()
	if majorGlyphs and minorGlyphs then
		for i = 1, 3 do
			PlayerGlyphPreviewFrame_SetGlyph(self.MajorSlots[i], majorGlyphs[i])
			PlayerGlyphPreviewFrame_SetGlyph(self.MinorSlots[i], minorGlyphs[i])
		end
	end
end

function PlayerGlyphPreviewFrame_SetGlyph(frame, glyphID)
	if not frame or not frame.Name then return end

	if glyphID then
		local name, _, icon, _, _, _, _, _, _ = GetSpellInfo(glyphID)
		frame.spellID = glyphID
		frame.Name:SetText(name)
		frame.Name:SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
		SetItemButtonTexture(frame, icon)
		SetItemButtonTextureVertexColor(frame, 1, 1, 1)
	else
		frame.spellID = nil
		frame.Name:SetText(EMPTY)
		frame.Name:SetTextColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
		SetItemButtonTexture(frame, "Interface\\PaperDoll\\UI-PaperDoll-Slot-Back")
		SetItemButtonTextureVertexColor(frame, 0.5, 0.5, 0.5)
	end
end
