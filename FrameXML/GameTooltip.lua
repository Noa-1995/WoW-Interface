-- The default tooltip border color
TOOLTIP_DEFAULT_COLOR = { r = 1, g = 1, b = 1 };
TOOLTIP_DEFAULT_BACKGROUND_COLOR = { r = 0.09, g = 0.09, b = 0.19 };
DEFAULT_TOOLTIP_POSITION = -13;

function GameTooltip_UnitColor(unit)
	local color

	if UnitPlayerControlled(unit) then
		if UnitCanAttack(unit, "player") then
			if not UnitCanAttack("player", unit) then
				color = TOOLTIP_DEFAULT_COLOR
			else
				color = FACTION_BAR_COLORS[2]
			end
		elseif UnitCanAttack("player", unit) then
			color = FACTION_BAR_COLORS[4]
		elseif UnitIsPVP(unit) then
			color = FACTION_BAR_COLORS[6]
		else
			color = TOOLTIP_DEFAULT_COLOR
		end
	else
		local reaction = UnitReaction(unit, "player")

		if reaction and FACTION_BAR_COLORS[reaction] then
			color = FACTION_BAR_COLORS[reaction]
		else
			color = TOOLTIP_DEFAULT_COLOR
		end
	end

	return color.r, color.g, color.b
end

function GameTooltip_SetDefaultAnchor(tooltip, parent)
	tooltip:SetOwner(parent, "ANCHOR_NONE");
	tooltip:SetPoint("BOTTOMRIGHT", "UIParent", "BOTTOMRIGHT", -CONTAINER_OFFSET_X - 13, CONTAINER_OFFSET_Y);
	tooltip.default = 1;
end

function GameTooltip_OnLoad(self)
	self.updateTooltip = TOOLTIP_UPDATE_TIME;
	self:SetBackdropBorderColor(TOOLTIP_DEFAULT_COLOR.r, TOOLTIP_DEFAULT_COLOR.g, TOOLTIP_DEFAULT_COLOR.b);
	self:SetBackdropColor(TOOLTIP_DEFAULT_BACKGROUND_COLOR.r, TOOLTIP_DEFAULT_BACKGROUND_COLOR.g, TOOLTIP_DEFAULT_BACKGROUND_COLOR.b);
	self.statusBar2 = _G[self:GetName().."StatusBar2"];
	self.statusBar2Text = _G[self:GetName().."StatusBar2Text"];
end

function GameTooltip_OnTooltipAddMoney(self, cost, maxcost)
	if( not maxcost ) then --We just have 1 price to display
		SetTooltipMoney(self, cost, nil, string.format("%s:", SELL_PRICE));
	else
		self:AddLine(string.format("%s:", SELL_PRICE), 1.0, 1.0, 1.0);
		local indent = string.rep(" ",4)
		SetTooltipMoney(self, cost, nil, string.format("%s%s:", indent, MINIMUM));
		SetTooltipMoney(self, maxcost, nil, string.format("%s%s:", indent, MAXIMUM));
	end
end

function SetTooltipMoney(frame, money, type, prefixText, suffixText)
	frame:AddLine(" ", 1.0, 1.0, 1.0);
	local numLines = frame:NumLines();
	if ( not frame.numMoneyFrames ) then
		frame.numMoneyFrames = 0;
	end
	if ( not frame.shownMoneyFrames ) then
		frame.shownMoneyFrames = 0;
	end
	local name = frame:GetName().."MoneyFrame"..frame.shownMoneyFrames+1;
	local moneyFrame = _G[name];
	if ( not moneyFrame ) then
		frame.numMoneyFrames = frame.numMoneyFrames+1;
		moneyFrame = CreateFrame("Frame", name, frame, "TooltipMoneyFrameTemplate");
		name = moneyFrame:GetName();
		MoneyFrame_SetType(moneyFrame, "STATIC");
	end
	_G[name.."PrefixText"]:SetText(prefixText);
	_G[name.."SuffixText"]:SetText(suffixText);
	if ( type ) then
		MoneyFrame_SetType(moneyFrame, type);
	end
	--We still have this variable offset because many AddOns use this function. The money by itself will be unaligned if we do not use this.
	local xOffset;
	if ( prefixText ) then
		xOffset = 4;
	else
		xOffset = 0;
	end
	moneyFrame:SetPoint("LEFT", frame:GetName().."TextLeft"..numLines, "LEFT", xOffset, 0);
	moneyFrame:Show();
	if ( not frame.shownMoneyFrames ) then
		frame.shownMoneyFrames = 1;
	else
		frame.shownMoneyFrames = frame.shownMoneyFrames+1;
	end
	MoneyFrame_Update(moneyFrame:GetName(), money);
	local moneyFrameWidth = moneyFrame:GetWidth();
	if ( frame:GetMinimumWidth() < moneyFrameWidth ) then
		frame:SetMinimumWidth(moneyFrameWidth);
	end
	frame.hasMoney = 1;
end

function GameTooltip_ClearMoney(self)
	if ( not self.shownMoneyFrames ) then
		return;
	end

	local moneyFrame;
	for i=1, self.shownMoneyFrames do
		moneyFrame = _G[self:GetName().."MoneyFrame"..i];
		if(moneyFrame) then
			moneyFrame:Hide();
			MoneyFrame_SetType(moneyFrame, "STATIC");
		end
	end
	self.shownMoneyFrames = nil;
end

function GameTooltip_InsertFrame(tooltipFrame, frame)
	local textSpacing = 2
	local textHeight = _G[tooltipFrame:GetName().."TextLeft2"]:GetHeight()
	local numLinesNeeded = math.ceil(frame:GetHeight() / (textHeight + textSpacing))
	local currentLine = tooltipFrame:NumLines()

	for i = 1, numLinesNeeded do
		tooltipFrame:AddLine(" ")
	end

	frame:SetParent(tooltipFrame)
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", tooltipFrame:GetName().."TextLeft"..(currentLine + 1), "TOPLEFT", 0, 0)

	if ( not tooltipFrame.insertedFrames ) then
		tooltipFrame.insertedFrames = { }
	end

	local frameWidth = frame:GetWidth()

	if tooltipFrame:GetMinimumWidth() < frameWidth then
		tooltipFrame:SetMinimumWidth(frameWidth)
	end

	frame:Show()
	table.insert(tooltipFrame.insertedFrames, frame)

	return (numLinesNeeded * textHeight) + (numLinesNeeded - 1) * textSpacing
end

function GameTooltip_ClearInsertedFrames(self)
	if self.insertedFrames then
		for i = 1, #self.insertedFrames do
			self.insertedFrames[i]:SetParent(nil)
			self.insertedFrames[i]:Hide()
		end
	end

	self.insertedFrames = nil
end

function GameTooltip_ClearStatusBars(self)
	if ( not self.shownStatusBars ) then
		return;
	end
	local statusBar;
	for i=1, self.shownStatusBars do
		statusBar = _G[self:GetName().."StatusBar"..i];
		if ( statusBar ) then
			statusBar:Hide();
		end
	end
	self.shownStatusBars = 0;
end

function GameTooltip_OnHide(self)
	self:SetBackdropBorderColor(TOOLTIP_DEFAULT_COLOR.r, TOOLTIP_DEFAULT_COLOR.g, TOOLTIP_DEFAULT_COLOR.b);
	self:SetBackdropColor(TOOLTIP_DEFAULT_BACKGROUND_COLOR.r, TOOLTIP_DEFAULT_BACKGROUND_COLOR.g, TOOLTIP_DEFAULT_BACKGROUND_COLOR.b);
	self.default = nil;
	GameTooltip_ClearMoney(self);
	GameTooltip_ClearStatusBars(self);
	if ( self.shoppingTooltips ) then
		for _, frame in pairs(self.shoppingTooltips) do
			frame:Hide();
		end
	end

	self.TransmogText1:Hide()
	self.TransmogText2:Hide()

	GameTooltip_FixLinePosition(self)
	GameTooltip_ClearInsertedFrames(GameTooltip)

	self.comparing = false;
end

function GameTooltip_OnUpdate(self, elapsed)
	-- Only update every TOOLTIP_UPDATE_TIME seconds
	self.updateTooltip = self.updateTooltip - elapsed;
	if ( self.updateTooltip > 0 ) then
		return;
	end
	self.updateTooltip = TOOLTIP_UPDATE_TIME;

	local owner = self:GetOwner();
	if ( owner and owner.UpdateTooltip ) then
		owner:UpdateTooltip();
	end

	GameTooltip_FixLinePosition(self)
end

function GameTooltip_FixLinePosition( self )
	if self.TransmogText1:IsShown() and self.TransmogText2:IsShown() then
		self.TextLeft2:ClearAllPoints()
		self.TextLeft2:SetPoint("TOPLEFT", self.TransmogText2, "BOTTOMLEFT", 0, -2)
	else
		if self.TextLeft2:GetText() ~= DAMAGE_SCHOOL2 then
			self.TextLeft2:ClearAllPoints()
			self.TextLeft2:SetPoint("TOPLEFT", self.TextLeft1, "BOTTOMLEFT", 0, -2)
		end
	end
end

function GameTooltip_OnTooltipSetSpell( self, ... )
	local _, _, spellID = self:GetSpell()

	if spellID then
		if spellID == 1804 then
			local currentSkillRank, maxSkillRank
			local currenBarValue

			for i = 1, GetNumSkillLines() do
				local skillName, _, _, skillRank, _, _, skillMaxRank = GetSkillLineInfo(i)

				if skillName == SKILL_NAME_LOCKPICKING then
					currentSkillRank = skillRank
					maxSkillRank = skillMaxRank
					break
				end
			end

			currenBarValue = (currentSkillRank / maxSkillRank) * 100

			GameTooltip_InsertFrame(GameTooltip, SpellTooltipStatusBar)

			SpellTooltipStatusBar.Bar:SetValue(currenBarValue)
			SpellTooltipStatusBar.Bar.Label:SetFontObject("GameFontNormal")
			SpellTooltipStatusBar.Bar.Label:SetFormattedText("%d / %d", currentSkillRank, maxSkillRank)

			SpellTooltipStatusBar.Bar.LeftDivider:Hide()
			SpellTooltipStatusBar.Bar.RightDivider:Hide()
		end
	end
end

EQUIPMENT_SET_LAST_TOOLTIP = {}

function GameTooltip_OnTooltipSetItem( self, ... )
	local numLines 	= self:NumLines()
	local itemName 	= self:GetItem()
	local owner 	= self:GetOwner()

	if itemName and owner and owner.containerID then
		if not EQUIPMENT_SET_LAST_TOOLTIP[owner.containerID] then
			EQUIPMENT_SET_LAST_TOOLTIP[owner.containerID] = {}
		end

		local slotID = owner.slotID or -1

		EQUIPMENT_SET_LAST_TOOLTIP[owner.containerID][slotID] = {}

		for i = 1, numLines do
			local line = _G[self:GetName().."TextLeft"..i]
			local text = line:GetText()

			if text then
				local sets = string.match(text, EQUIPMENT_SETS_PATTERN)

				if sets then
					local setsStorage 	= C_Split(sets, ", ")
					EQUIPMENT_SET_LAST_TOOLTIP[owner.containerID][slotID] = setsStorage
					break
				end
			end
		end
	end

	if ( IsModifiedClick("COMPAREITEMS") or
		(GetCVarBool("alwaysCompareItems") and not self:IsEquippedItem()) ) then
		GameTooltip_ShowCompareItem(self, 1);
	end

	local owner = self:GetOwner();
	self.IsMerchantTooltip = false

	if owner and MerchantFrame then
		local ownerFrame = owner:GetParent()

		while ownerFrame and ownerFrame ~= MerchantFrame do
			ownerFrame = ownerFrame:GetParent()
		end

		self.IsMerchantTooltip = ownerFrame == MerchantFrame
	end

	C_Tooltip_CustomRender( self, ... )
end

local equipSetsItemColor = CreateColorRGB(0.999, 0.999, 0.592, 0.999)
local grayTextColor = CreateColorRGB(0.501, 0.501, 0.501, 0.999)
local greenTextColor = CreateColorRGB(0, 0.999, 0, 0.999)

function C_Tooltip_CustomRender( self, ... )
	local owner = self:GetOwner()

	local setTextChecked
	local startEquipmentSetLine, endEquipmentSetLine
	local currentSetItems, totalSetItems
	local setNumItems = 0

	local newLines
	-- local showAppearanceLine = false;

	for i = 1, self:NumLines() do
		local line = _G[self:GetName().."TextLeft"..i]

		if line then
			local text = line:GetText()
			local rbgTitle

			if not totalSetItems then
				currentSetItems, totalSetItems = string.match(text, "%((%d+)/(%d+)%)$")

				if totalSetItems then
					currentSetItems = tonumber(currentSetItems)
					totalSetItems = tonumber(totalSetItems)

					startEquipmentSetLine = i + 1
					endEquipmentSetLine = i + totalSetItems
				end
			end

			if (startEquipmentSetLine and endEquipmentSetLine) and C_InRange(i, startEquipmentSetLine, endEquipmentSetLine) then
				local itemName = string.match(text, "%s+(.*)")

				if itemName then
					local equipmentItemsList = owner and owner.paperDoll and owner.paperDoll.equipmentItemsList or PaperDollFrame.equipmentItemsList
					if equipmentItemsList then
						if equipmentItemsList[itemName:lower()] then
							setNumItems = setNumItems + 1
							line:SetTextColor(equipSetsItemColor.r, equipSetsItemColor.g, equipSetsItemColor.b)
						else
							line:SetTextColor(grayTextColor.r, grayTextColor.g, grayTextColor.b)
						end
					end
				end
			end

			if not setTextChecked and endEquipmentSetLine and i > endEquipmentSetLine then
				if setNumItems > currentSetItems and setNumItems <= totalSetItems then
					local setHeaderLine = _G[self:GetName().."TextLeft"..(startEquipmentSetLine - 1)]
					setHeaderLine:SetText(setHeaderLine:GetText():gsub("%((%d+)/(%d+)%)$", string.format("(%i/%s)", setNumItems, "%2")))
				end
				setTextChecked = true
			end

			local setBonus = string.match(text, EQUIPMENT_SET_PATTERN)

			if setBonus then
				local numRequiredSetItems = tonumber(string.match(text, ITEM_SET_BONUS_GRAY_PATTERN))

				if not numRequiredSetItems and setNumItems > 0 then
					line:SetTextColor(greenTextColor.r, greenTextColor.g, greenTextColor.b)
				elseif numRequiredSetItems and setNumItems >= numRequiredSetItems then
					line:SetTextColor(greenTextColor.r, greenTextColor.g, greenTextColor.b)
				else
					line:SetTextColor(grayTextColor.r, grayTextColor.g, grayTextColor.b)
				end
			end

			if text then
				rbgTitle = string.match(text, string.sub(LOCKED_WITH_SPELL, 1, -3).."(.*)")
			end

			if text and string.find(text, CHARACTER_LINK_ITEM_LEVEL_TOOLTIP) then
				line:SetTextColor(1.0, 0.82, 0, 1)
			end

			if text and string.find(text, ITEM_REQ_ARENA_RATING_3V3) then
				local needRating = tonumber(string.match(text, "(%d+)"))
				local _, _, _, _, rating = GetRatedBattlegroundRankInfo()

				if rating >= needRating then
					line:SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
				end
			elseif text and string.find(text, ITEM_REQ_ARENA_RATING) then
				local needRating = tonumber(string.match(text, "(%d+)"))
				local rating = math.max(GetArenaRating(1), GetArenaRating(2))

				if rating >= needRating then
					line:SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
				end
			elseif text == TRANSMOGRIFY_TOOLTIP_APPEARANCE_UNKNOWN then
				showAppearanceLine = false;
			end
		end
	end

	if showAppearanceLine then
		self:AddLine(TRANSMOGRIFY_TOOLTIP_APPEARANCE_UNKNOWN, 0.53, 0.67, 1);
		newLines = true
	end

	if newLines then
		self:Show();
	end
end

function GameTooltip_AddNewbieTip(frame, normalText, r, g, b, newbieText, noNormalText)
	if ( SHOW_NEWBIE_TIPS == "1" ) then
		GameTooltip_SetDefaultAnchor(GameTooltip, frame);
		if ( normalText ) then
			GameTooltip:SetText(normalText, r, g, b);
			GameTooltip:AddLine(newbieText, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1);
		else
			GameTooltip:SetText(newbieText, r, g, b, 1, 1);
		end
		GameTooltip:Show();
	else
		if ( not noNormalText ) then
			GameTooltip:SetOwner(frame, "ANCHOR_RIGHT");
			GameTooltip:SetText(normalText, r, g, b);
		end
	end
end

function GameTooltip_ShowCompareItem(self, shift)
	if ( not self ) then
		self = GameTooltip;
	end
	local item, link = self:GetItem();
	if ( not link ) then
		return;
	end

	local shoppingTooltip1, shoppingTooltip2, shoppingTooltip3 = unpack(self.shoppingTooltips);

	local item1 = nil;
	local item2 = nil;
	local item3 = nil;
	local side = "left";
	if ( shoppingTooltip1:SetHyperlinkCompareItem(link, 1, shift, self) ) then
		item1 = true;
	end
	if ( shoppingTooltip2:SetHyperlinkCompareItem(link, 2, shift, self) ) then
		item2 = true;
	end
	if ( shoppingTooltip3:SetHyperlinkCompareItem(link, 3, shift, self) ) then
		item3 = true;
	end

	-- find correct side
	local rightDist = 0;
	local leftPos = self:GetLeft();
	local rightPos = self:GetRight();
	if ( not rightPos ) then
		rightPos = 0;
	end
	if ( not leftPos ) then
		leftPos = 0;
	end

	rightDist = GetScreenWidth() - rightPos;

	if (leftPos and (rightDist < leftPos)) then
		side = "left";
	else
		side = "right";
	end

	-- see if we should slide the tooltip
	if ( self:GetAnchorType() and self:GetAnchorType() ~= "ANCHOR_PRESERVE" ) then
		local totalWidth = 0;
		if ( item1  ) then
			totalWidth = totalWidth + shoppingTooltip1:GetWidth();
		end
		if ( item2  ) then
			totalWidth = totalWidth + shoppingTooltip2:GetWidth();
		end
		if ( item3  ) then
			totalWidth = totalWidth + shoppingTooltip3:GetWidth();
		end

		if ( (side == "left") and (totalWidth > leftPos) ) then
			self:SetAnchorType(self:GetAnchorType(), (totalWidth - leftPos), 0);
		elseif ( (side == "right") and (rightPos + totalWidth) >  GetScreenWidth() ) then
			self:SetAnchorType(self:GetAnchorType(), -((rightPos + totalWidth) - GetScreenWidth()), 0);
		end
	end

	-- anchor the compare tooltips
	if ( item3 ) then
		shoppingTooltip3:SetOwner(self, "ANCHOR_NONE");
		shoppingTooltip3:ClearAllPoints();
		if ( side and side == "left" ) then
			shoppingTooltip3:SetPoint("TOPRIGHT", self, "TOPLEFT", 0, -10);
		else
			shoppingTooltip3:SetPoint("TOPLEFT", self, "TOPRIGHT", 0, -10);
		end
		shoppingTooltip3:SetHyperlinkCompareItem(link, 3, shift, self);
		shoppingTooltip3:Show();
	end

	if ( item1 ) then
		if( item3 ) then
			shoppingTooltip1:SetOwner(shoppingTooltip3, "ANCHOR_NONE");
		else
			shoppingTooltip1:SetOwner(self, "ANCHOR_NONE");
		end
		shoppingTooltip1:ClearAllPoints();
		if ( side and side == "left" ) then
			if( item3 ) then
				shoppingTooltip1:SetPoint("TOPRIGHT", shoppingTooltip3, "TOPLEFT", 0, 0);
			else
				shoppingTooltip1:SetPoint("TOPRIGHT", self, "TOPLEFT", 0, -10);
			end
		else
			if( item3 ) then
				shoppingTooltip1:SetPoint("TOPLEFT", shoppingTooltip3, "TOPRIGHT", 0, 0);
			else
				shoppingTooltip1:SetPoint("TOPLEFT", self, "TOPRIGHT", 0, -10);
			end
		end
		shoppingTooltip1:SetHyperlinkCompareItem(link, 1, shift, self);
		shoppingTooltip1:Show();

		if ( item2 ) then
			shoppingTooltip2:SetOwner(shoppingTooltip1, "ANCHOR_NONE");
			shoppingTooltip2:ClearAllPoints();
			if ( side and side == "left" ) then
				shoppingTooltip2:SetPoint("TOPRIGHT", shoppingTooltip1, "TOPLEFT", 0, 0);
			else
				shoppingTooltip2:SetPoint("TOPLEFT", shoppingTooltip1, "TOPRIGHT", 0, 0);
			end
			shoppingTooltip2:SetHyperlinkCompareItem(link, 2, shift, self);
			shoppingTooltip2:Show();
		end
	end
end

function GameTooltip_ShowStatusBar(self, min, max, value, text)
	self:AddLine(" ", 1.0, 1.0, 1.0);
	local numLines = self:NumLines();
	if ( not self.numStatusBars ) then
		self.numStatusBars = 0;
	end
	if ( not self.shownStatusBars ) then
		self.shownStatusBars = 0;
	end
	local index = self.shownStatusBars+1;
	local name = self:GetName().."StatusBar"..index;
	local statusBar = _G[name];
	if ( not statusBar ) then
		self.numStatusBars = self.numStatusBars+1;
		statusBar = CreateFrame("StatusBar", name, self, "TooltipStatusBarTemplate");
	end
	if ( not text ) then
		text = "";
	end
	_G[name.."Text"]:SetText(text);
	statusBar:SetMinMaxValues(min, max);
	statusBar:SetValue(value);
	statusBar:Show();
	statusBar:SetPoint("LEFT", self:GetName().."TextLeft"..numLines, "LEFT", 0, -2);
	statusBar:SetPoint("RIGHT", self, "RIGHT", -9, 0);
	statusBar:Show();
	self.shownStatusBars = index;
	self:SetMinimumWidth(140);
end

function GameTooltip_Hide()
	-- Used for XML OnLeave handlers
	GameTooltip:Hide();
end

function GameTooltip_HideResetCursor()
	GameTooltip:Hide();
	ResetCursor();
end