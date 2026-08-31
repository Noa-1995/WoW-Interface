GLYPHTYPE_MAJOR = 1;
GLYPHTYPE_MINOR = 2;

GLYPH_MINOR = { r = 0, g = 0.25, b = 1};
GLYPH_MAJOR = { r = 1, g = 0.25, b = 0};

GLYPH_SLOTS = {};
-- Empty Texture
GLYPH_SLOTS[0] = { left = 0.78125, right = 0.91015625, top = 0.69921875, bottom = 0.828125 };
-- Major Glyphs
GLYPH_SLOTS[3] = { left = 0.392578125, right = 0.521484375, top = 0.87109375, bottom = 1 };
GLYPH_SLOTS[1] = { left = 0, right = 0.12890625, top = 0.87109375, bottom = 1 };
GLYPH_SLOTS[5] = { left = 0.26171875, right = 0.390625, top = 0.87109375, bottom = 1 };
-- Minor Glyphs
GLYPH_SLOTS[2] = { left = 0.130859375, right = 0.259765625, top = 0.87109375, bottom = 1 };
GLYPH_SLOTS[6] = { left = 0.654296875, right = 0.783203125, top = 0.87109375, bottom = 1 };
GLYPH_SLOTS[4] = { left = 0.5234375, right = 0.65234375, top = 0.87109375, bottom = 1 };

GLYPH_TYPE_INFO = {};
GLYPH_TYPE_INFO[GLYPHTYPE_MAJOR] =  {
	ring = { size = 94, left = 0.00390625, right = 0.33203125, top = 0.27539063, bottom = 0.43945313 };
	highlight = { size = 108, left = 0.54296875, right = 0.92578125, top = 0.00195313, bottom = 0.19335938 };
}
GLYPH_TYPE_INFO[GLYPHTYPE_MINOR] =  {
	ring = { size = 78, left = 0.33984375, right = 0.60546875, top = 0.27539063, bottom = 0.40820313 };
	highlight = { size = 92, left = 0.61328125, right = 0.93359375, top = 0.27539063, bottom = 0.43554688 };
}

NUM_GLYPH_SLOTS = 6;

local slotAnimations = {};
local TOPLEFT, TOP, TOPRIGHT, BOTTOMRIGHT, BOTTOM, BOTTOMLEFT = 3, 1, 5, 4, 2, 6;
slotAnimations[TOPLEFT] = {["point"] = "CENTER", ["xStart"] = -13, ["xStop"] = -85, ["yStart"] = 17, ["yStop"] = 60};
slotAnimations[TOP] = {["point"] = "CENTER", ["xStart"] = -13, ["xStop"] = -13, ["yStart"] = 17, ["yStop"] = 100};
slotAnimations[TOPRIGHT] = {["point"] = "CENTER", ["xStart"] = -13, ["xStop"] = 59, ["yStart"] = 17, ["yStop"] = 60};
slotAnimations[BOTTOM] = {["point"] = "CENTER", ["xStart"] = -13, ["xStop"] = -13, ["yStart"] = 17, ["yStop"] = -64};
slotAnimations[BOTTOMLEFT] = {["point"] = "CENTER", ["xStart"] = -13, ["xStop"] = -87, ["yStart"] = 18, ["yStop"] = -27};
slotAnimations[BOTTOMRIGHT] = {["point"] = "CENTER", ["xStart"] = -13, ["xStop"] = 61, ["yStart"] = 18, ["yStop"] = -27};


SLOT_ANIMATIONS = {};
---local TOPLEFT, TOP, TOPRIGHT, BOTTOMRIGHT, BOTTOM, BOTTOMLEFT = 3, 1, 5, 4, 2, 6;
SLOT_ANIMATIONS[1] = {  ["xStart"] = 0, ["xStop"] = -13, ["yStart"] = -12, ["yStop"] =  -124};
SLOT_ANIMATIONS[2] = {  ["xStart"] = 0, ["xStop"] = -87, ["yStart"] = -12, ["yStop"] =  -27};
SLOT_ANIMATIONS[3] = {  ["xStart"] = 0, ["xStop"] =  61, ["yStart"] = -12, ["yStop"] =  -27};
SLOT_ANIMATIONS[4] = {  ["xStart"] = 0, ["xStop"] =  61, ["yStart"] = -12, ["yStop"] = -27};
SLOT_ANIMATIONS[5] = {  ["xStart"] = 0, ["xStop"] =  61, ["yStart"] = -12, ["yStop"] = -27};
SLOT_ANIMATIONS[6] = {  ["xStart"] = 0, ["xStop"] =  61, ["yStart"] = -6, ["yStop"] = -27};

local HIGHLIGHT_BASEALPHA = .4;


function GlyphFrame_Toggle ()
	TalentFrame_LoadUI();
	if ( PlayerTalentFrame_ToggleGlyphFrame ) then
		PlayerTalentFrame_ToggleGlyphFrame(C_Talent.GetActiveTalentGroup());
	end
end

function GlyphFrame_Open ()
	TalentFrame_LoadUI();
	if ( PlayerTalentFrame_OpenGlyphFrame ) then
		PlayerTalentFrame_OpenGlyphFrame(C_Talent.GetActiveTalentGroup());
	end
end


function GlyphFrameGlyph_OnLoad (self)
	local name = self:GetName();
	self:RegisterForClicks("LeftButtonUp", "RightButtonUp");
	self.glyph = _G[name .. "Glyph"];
	self.setting = _G[name .. "Setting"];
	self.highlight = _G[name .. "Highlight"];
	self.background = _G[name .. "Background"];
	self.ring = _G[name .. "Ring"];
	self.shine = _G[name .. "Shine"];
	self.elapsed = 0;
	self.tintElapsed = 0;
	self.glyphType = nil;
end

function GlyphFrameGlyph_UpdateSlot (self)
	local id = self:GetID();
	local talentGroup = PlayerTalentFrame and PlayerTalentFrame.talentGroup;
	local enabled, glyphType, glyphSpell, iconFilename = GetGlyphSocketInfo(id, talentGroup);
	if not glyphType then
		return;
	end

	GlyphFrameGlyph_SetGlyphType(self, glyphType);

	self.elapsed = 0;
	self.tintElapsed = 0;

	local slotAnimation = SLOT_ANIMATIONS[id];
	local _, _, _, offsetX, offsetY = self:GetPoint();
	slotAnimation.xStop = offsetX;-- (self:GetWidth()/2.0);
	slotAnimation.yStop = offsetY;-- (self:GetHeight()/2.0);

	local requiredLevelFrame = self:GetParent().requiredLevelFrames[id]

	if requiredLevelFrame then
		TalentRetail_SetShown(requiredLevelFrame, not enabled)
		requiredLevelFrame.LevelText:SetText(_G["GLYPH_SLOT_TOOLTIP"..id])
	end

	if ( not enabled ) then
		slotAnimation.glyph = nil;
		self:Hide();
	elseif ( not glyphSpell ) then
		slotAnimation.glyph = nil;
		self.spell = nil;
		self.glyph:SetTexture("");
		self:Show();
	else
		slotAnimation.glyph = true;
		self.spell = glyphSpell;
		self.glyph:Show();

		local _, _, spellIcon = GetSpellInfo(glyphSpell)

		if ( spellIcon ) then
			SetPortraitToTexture(self.glyph, spellIcon);
		else
			self.glyph:SetTexture("Interface\\Spellbook\\UI-Glyph-Rune1");
		end
		self:Show();
	end
end

function GlyphFrameGlyph_SetGlyphType (glyph, glyphType)
	glyph.glyphType = glyphType;
	local info = GLYPH_TYPE_INFO[glyphType]

	if info then
		glyph.glyphType = glyphType

		glyph.ring:SetWidth(info.ring.size)
		glyph.ring:SetHeight(info.ring.size)
		glyph.ring:SetTexCoord(info.ring.left, info.ring.right, info.ring.top, info.ring.bottom)

		glyph.highlight:SetWidth(info.highlight.size)
		glyph.highlight:SetHeight(info.highlight.size)
		glyph.highlight:SetTexCoord(info.highlight.left, info.highlight.right, info.highlight.top, info.highlight.bottom)

		glyph.glyph:SetWidth(info.ring.size - 20)
		glyph.glyph:SetHeight(info.ring.size - 20)
		glyph.glyph:SetAlpha(0.75)
	end
end

-- function GlyphFrameGlyph_OnUpdate (self, elapsed)
-- 	local GLYPHFRAMEGLYPH_FINISHED = 6;
-- 	local GLYPHFRAMEGLYPH_START = 2;
-- 	local GLYPHFRAMEGLYPH_HOLD = 4;

-- 	local hasGlyph = self.glyph:IsShown();

-- 	if ( hasGlyph or self.elapsed > 0 ) then
-- 		self.elapsed = self.elapsed + elapsed;

-- 		elapsed = self.elapsed;
-- 		if ( elapsed >= GLYPHFRAMEGLYPH_FINISHED ) then
-- 			-- self.setting:SetAlpha(.6);
-- 			self.elapsed = 0;
-- 		elseif ( elapsed <= GLYPHFRAMEGLYPH_START ) then
-- 			-- self.setting:SetAlpha(.6 + (.4 * elapsed/GLYPHFRAMEGLYPH_START));
-- 		elseif ( elapsed >= GLYPHFRAMEGLYPH_HOLD ) then
-- 			-- self.setting:SetAlpha(1 - (.4 * (elapsed - GLYPHFRAMEGLYPH_HOLD) / (GLYPHFRAMEGLYPH_FINISHED - GLYPHFRAMEGLYPH_HOLD) ) );
-- 		end
-- 	-- elseif ( self.background:IsShown() ) then
-- 		-- self.setting:SetAlpha(.6);
-- 	-- else
-- 		-- self.setting:SetAlpha(.6);
-- 	end


-- 	local TINT_START, TINT_HOLD, TINT_FINISHED = .6, .8, 1.6;


-- 	local id = self:GetID();
-- 	if ( not hasGlyph and GlyphMatchesSocket(id) ) then -- self.background:IsShown()
-- 		self.tintElapsed = self.tintElapsed + elapsed;

-- 		-- self.background:SetTexCoord(GLYPH_SLOTS[id].left, GLYPH_SLOTS[id].right, GLYPH_SLOTS[id].top, GLYPH_SLOTS[id].bottom);

-- 		local highlight = false;
-- 		if ( not MouseIsOver(self) ) then
-- 			self.highlight:Show();
-- 			highlight = true;
-- 		end

-- 		local alpha;
-- 		elapsed = self.tintElapsed;
-- 		if ( elapsed >= TINT_FINISHED ) then
-- 			alpha = 1;

-- 			self.tintElapsed = 0;
-- 		elseif ( elapsed <= TINT_START ) then
-- 			alpha = 1 - (.6 * elapsed/TINT_START);
-- 		elseif ( elapsed >= TINT_HOLD ) then
-- 			alpha = .4 + (.6 * (elapsed - TINT_HOLD) / (TINT_FINISHED - TINT_HOLD));
-- 		end

-- 		if ( alpha ) then
-- 			-- self.background:SetAlpha(alpha);
-- 			if ( highlight ) then
-- 				self.highlight:SetAlpha(HIGHLIGHT_BASEALPHA * alpha);
-- 			else
-- 				self.highlight:SetAlpha(HIGHLIGHT_BASEALPHA);
-- 			end
-- 		end
-- 	elseif ( not hasGlyph ) then
-- 		-- self.background:SetTexCoord(GLYPH_SLOTS[0].left, GLYPH_SLOTS[0].right, GLYPH_SLOTS[0].top, GLYPH_SLOTS[0].bottom);
-- 		-- self.background:SetAlpha(1);
-- 	end

-- 	if ( self.hasCursor and SpellIsTargeting() ) then
-- 		if ( GlyphMatchesSocket(self:GetID()) ) then -- self.background:IsShown()
-- 			SetCursor("CAST_CURSOR");
-- 		else
-- 			SetCursor("CAST_ERROR_CURSOR");
-- 		end
-- 	end
-- end

function GlyphFrameGlyph_OnUpdate (self, elapsed)
	local id = self:GetID();
	if GlyphMatchesSocket(id) then
		self.highlight:SetAlpha(1);
		self.highlight.glow:Play();
	else
		self.highlight.glow:Stop();
		self.highlight:SetAlpha(0);
	end

	if self.hasCursor and SpellIsTargeting() then
		if GlyphMatchesSocket(id) then
			SetCursor("CAST_CURSOR")
		else
			SetCursor("CAST_ERROR_CURSOR")
		end
	end
end

function GlyphFrameGlyph_OnClick (self, button)
	local id = self:GetID();
	local talentGroup = PlayerTalentFrame and PlayerTalentFrame.talentGroup;
	local activeEditBox = ChatEdit_GetActiveWindow()

	if ( IsModifiedClick("CHATLINK") and activeEditBox ) then
		local link = GetGlyphLink(id, talentGroup);
		if ( link ) then
			ChatEdit_InsertLink(link);
		end
	elseif ( button == "RightButton" ) then
		if ( IsShiftKeyDown() and talentGroup == GetActiveTalentGroup() ) then
			local glyphName;
			local _, _, glyphSpell = GetGlyphSocketInfo(id, talentGroup);
			if ( glyphSpell ) then
				glyphName = GetSpellInfo(glyphSpell);
				local dialog = StaticPopup_Show("CONFIRM_REMOVE_GLYPH", glyphName);
				dialog.data = id;
			end
		end
	elseif ( talentGroup == GetActiveTalentGroup() ) then
		if ( self.glyph:IsShown() and GlyphMatchesSocket(id) ) then
			local dialog = StaticPopup_Show("CONFIRM_GLYPH_PLACEMENT", id);
			dialog.data = id;
		else
			PlaceGlyphInSocket(id);
		end
	end
end

function GlyphFrameGlyph_OnEnter (self)
	self.hasCursor = true;
	-- if ( self.background:IsShown() ) then
	-- 	self.highlight:Show();
	-- end
	self.highlight:SetAlpha(1)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	GameTooltip:SetGlyph(self:GetID(), PlayerTalentFrame and PlayerTalentFrame.talentGroup);
	GameTooltip:Show();
end

function GlyphFrameGlyph_OnLeave (self)
	self.hasCursor = nil;
	self.highlight:SetAlpha(0)
	GameTooltip:Hide();
end

local GLYPH_SPARKLE_SIZES = 3;
local GLYPH_DURATION_MODIFIERS = { 1.25, 1.5, 1.8 };

function GlyphFrame_OnUpdate (self, elapsed)
	for i = 1, #slotAnimations do
		local animation = slotAnimations[i];
		if ( animation.glyph and not (animation.sparkle and animation.sparkle.animGroup:IsPlaying()) ) then
			local sparkleSize = math.random(GLYPH_SPARKLE_SIZES);
			GlyphFrame_StartSlotAnimation(i, sparkleSize * GLYPH_DURATION_MODIFIERS[sparkleSize], sparkleSize);
		end
	end
end

function GlyphFrame_PulseGlow()
	GlyphFrame.glow.pulse:Play()
end


function GlyphFrame_OnShow (self)
	SetParentFrameLevel(self, 2)
	SetParentFrameLevel(self.sparkleFrame, 2)
	GlyphFrame_Update();
end

function GlyphFrame_OnLoad (self)
	local name = self:GetName();
	self.background = _G[name .. "Background"];
	self.sparkleFrame = SparkleFrame:New(self);
	self:RegisterEvent("ADDON_LOADED");
	self:RegisterEvent("GLYPH_ADDED");
	self:RegisterEvent("GLYPH_REMOVED");
	self:RegisterEvent("GLYPH_UPDATED");
	self:RegisterEvent("USE_GLYPH");
	self:RegisterEvent("PLAYER_LEVEL_UP");

end

function GlyphFrame_OnEnter (self)
	if ( SpellIsTargeting() ) then
		SetCursor("CAST_ERROR_CURSOR");
	end
end

function GlyphFrame_OnLeave (self)

end

function GlyphFrame_OnEvent (self, event, ...)
	if ( event == "ADDON_LOADED" ) then
		local name = ...;
		if ( name == "Blizzard_GlyphUI" and IsAddOnLoaded("Blizzard_TalentUI") or name == "Blizzard_TalentUI" ) then
			self:ClearAllPoints();
			self:SetParent(PlayerTalentFrame);
			self:SetAllPoints();
			-- make sure this shows up above the talent UI
			local frameLevel = self:GetParent():GetFrameLevel() + 4;
			self:SetFrameLevel(frameLevel);
			PlayerTalentFrameCloseButton:SetFrameLevel(frameLevel + 1);
		end
	elseif ( event == "USE_GLYPH" or event == "PLAYER_LEVEL_UP" ) then
		GlyphFrame_Update();
	elseif ( event == "GLYPH_ADDED" or event == "GLYPH_REMOVED" or event == "GLYPH_UPDATED" ) then
		local index = ...;
		local glyph = _G["GlyphFrameGlyph" .. index];
		if ( glyph and self:IsVisible() ) then
			-- update the glyph
			GlyphFrameGlyph_UpdateSlot(glyph);
			-- play effects based on the event and glyph type
			GlyphFrame_PulseGlow();
			local glyphType = glyph.glyphType;
			if ( event == "GLYPH_ADDED" or event == "GLYPH_UPDATED" ) then
				if ( glyphType == GLYPHTYPE_MINOR ) then
					PlaySound("Glyph_MinorCreate");
				elseif ( glyphType == GLYPHTYPE_MAJOR ) then
					PlaySound("Glyph_MajorCreate");
				end
			elseif ( event == "GLYPH_REMOVED" ) then
				GlyphFrame_StopSlotAnimation(index);
				if ( glyphType == GLYPHTYPE_MINOR ) then
					PlaySound("Glyph_MinorDestroy");
				elseif ( glyphType == GLYPHTYPE_MAJOR ) then
					PlaySound("Glyph_MajorDestroy");
				end
			end
		end

		--Refresh tooltip!
		if ( GameTooltip:IsOwned(glyph) ) then
			GlyphFrameGlyph_OnEnter(glyph);
		end
	end
end

local requiredLevelActiveTextColor = {r = 0.2, g = 0.1, b = 0.09, a = 0.8}
local requiredLevelDisableTextColor = {r = 0.2, g = 0.2, b = 0.2, a = 0.8}

function GlyphFrame_Update ()
	local isActiveTalentGroup = PlayerTalentFrame and not PlayerTalentFrame.pet and PlayerTalentFrame.talentGroup == GetActiveTalentGroup(PlayerTalentFrame.pet);

	SetDesaturation(GlyphFrame.background, not isActiveTalentGroup)

	local levelTextColor = not isActiveTalentGroup and requiredLevelDisableTextColor or requiredLevelActiveTextColor
	for _, frame in pairs(GlyphFrame.requiredLevelFrames) do
		frame.levelOverlay:SetDesaturated(not isActiveTalentGroup)
		frame.LevelText:SetTextColor(levelTextColor.r, levelTextColor.g, levelTextColor.b)
	end

	for i = 1, NUM_GLYPH_SLOTS do
		local glyph = _G["GlyphFrameGlyph"..i];
		GlyphFrameGlyph_UpdateSlot(glyph);
		SetDesaturation(glyph.ring, not isActiveTalentGroup);
		SetDesaturation(glyph.glyph, not isActiveTalentGroup);
		if isActiveTalentGroup then
			glyph.highlight:Show();
		else
			glyph.highlight:Hide();
		end
	end

	local talentGroupButton = PlayerTalentFrame.specTabs[C_Talent.GetSelectedTalentGroup()]
	local specIcon

	if talentGroupButton and talentGroupButton.primaryTabIndex and talentGroupButton.tabInfo[talentGroupButton.primaryTabIndex] then
		specIcon = talentGroupButton.tabInfo[talentGroupButton.primaryTabIndex].icon
	else
		specIcon = "Interface\\Icons\\Ability_Marksmanship"
	end

	GlyphFrame.SpecButton.specIcon:Show()
	GlyphFrame.SpecButton.specRing:Show()

	SetPortraitToTexture(GlyphFrame.SpecButton.specIcon, specIcon)
	SetDesaturation(GlyphFrame.SpecButton.specIcon, true)

	if ( isActiveTalentGroup ) then
		SetDesaturation(GlyphFrame.SpecButton.specRing, false)
	else
		SetDesaturation(GlyphFrame.SpecButton.specRing, true)
	end
end

function GlyphFrame_StartSlotAnimation (slotID, duration, size)
	local animation = slotAnimations[slotID];

	-- init texture to animate
	local sparkleName = "GlyphFrameSparkle"..slotID;
	local sparkle = _G[sparkleName];
	if ( not sparkle ) then
		sparkle = GlyphFrame:CreateTexture(sparkleName, "OVERLAY", "GlyphSparkleTexture");
		sparkle.slotID = slotID;
	end
	local template;
	if ( size == 1 ) then
		template = "SparkleTextureSmall";
	elseif ( size == 2 ) then
		template = "SparkleTextureKindaSmall";
	else
		template = "SparkleTextureNormal";
	end
	local sparkleDim = SparkleDimensions[template];
	sparkle:SetHeight(sparkleDim.height);
	sparkle:SetWidth(sparkleDim.width);
	sparkle:SetPoint("CENTER", GlyphFrame, animation.point, animation.xStart, animation.yStart);
	sparkle:Show();

	-- init animation
	local offsetX, offsetY = animation.xStop - animation.xStart, animation.yStop - animation.yStart;
	local animGroupAnim = sparkle.animGroup.translate;
	animGroupAnim:SetOffset(offsetX, offsetY);
	animGroupAnim:SetDuration(duration);
	animGroupAnim:Play();

	animation.sparkle = sparkle;
end

function GlyphFrame_StopSlotAnimation (slotID)
	local animation = slotAnimations[slotID];
	if ( animation.sparkle ) then
		animation.sparkle.animGroup:Stop();
		animation.sparkle:Hide();
		animation.sparkle = nil;
	end
end
