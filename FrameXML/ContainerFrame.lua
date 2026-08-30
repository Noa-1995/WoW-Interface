NUM_CONTAINER_FRAMES = 13;
NUM_BAG_FRAMES = 4;
MAX_CONTAINER_ITEMS = 36;
NUM_CONTAINER_COLUMNS = 4;
ROWS_IN_BG_TEXTURE = 6;
MAX_BG_TEXTURES = 2;
BG_TEXTURE_HEIGHT = 512;
CONTAINER_WIDTH = 192;
CONTAINER_SPACING = 12;
VISIBLE_CONTAINER_SPACING = 12;
CONTAINER_OFFSET_Y = 70;
CONTAINER_OFFSET_X = 0;
CONTAINER_SCALE = 0.75;
BACKPACK_HEIGHT = 255;

local searchText
local expandedSearchText = nil

local isExpandedBackpack = false
local expandedTooltipFrame = nil
local MAX_COMBINED_SLOTS = 160

-- ============================================================
-- TEXTURAS DE CALIDAD
-- ============================================================
local CONTAINER_QUALITY_MIN = 2  -- Mínimo calidad para mostrar borde (2 = verde)
local CONTAINER_QUALITY_BORDER_TEXTURE = "Interface\\ContainerFrame\\Bags"

local CONTAINER_QUALITY_BORDER_LEFT   = 0.000000000
local CONTAINER_QUALITY_BORDER_RIGHT  = 0.156250000
local CONTAINER_QUALITY_BORDER_TOP    = 0.523437500
local CONTAINER_QUALITY_BORDER_BOTTOM = 0.679687500

-- ============================================================
-- FUNCIONES DE CALIDAD Y BORDES
-- ============================================================

local function ContainerItem_ApplyQualityBorderTexture(border)
    if not border then return end
    border:SetTexture(CONTAINER_QUALITY_BORDER_TEXTURE)
    border:SetTexCoord(
        CONTAINER_QUALITY_BORDER_LEFT,
        CONTAINER_QUALITY_BORDER_RIGHT,
        CONTAINER_QUALITY_BORDER_TOP,
        CONTAINER_QUALITY_BORDER_BOTTOM
    )
end

local function ContainerItem_GetItemQuality(bagID, slotID, quality)
    quality = tonumber(quality)
    if quality ~= nil then
        return quality
    end

    local itemID = GetContainerItemID and GetContainerItemID(bagID, slotID)
    if itemID and GetItemInfo then
        local _, _, itemQuality = GetItemInfo(itemID)
        return tonumber(itemQuality)
    end

    return nil
end

local function ContainerItem_EnsureQualityBorder(button)
    if not button then return nil end

    if not button.QualityBorder then
        local border = button:CreateTexture(nil, "OVERLAY")
        ContainerItem_ApplyQualityBorderTexture(border)
        border:SetBlendMode("BLEND")
        border:SetPoint("CENTER", button, "CENTER", 0, 0)
        border:SetSize(button:GetWidth() + 0, button:GetHeight() + 0)
        border:Hide()
        button.QualityBorder = border
    else
        ContainerItem_ApplyQualityBorderTexture(button.QualityBorder)
        button.QualityBorder:SetSize(button:GetWidth() + 0, button:GetHeight() + 0)
    end
    return button.QualityBorder
end

local function ContainerItem_UpdateQualityBorder(button, bagID, slotID, quality, searchMatched)
    local border = ContainerItem_EnsureQualityBorder(button)
    if not border then return end

    quality = ContainerItem_GetItemQuality(bagID, slotID, quality)

    if quality and quality >= CONTAINER_QUALITY_MIN then
        local r, g, b = GetItemQualityColor(quality)
        border:SetVertexColor(r or 1, g or 1, b or 1)
        border:SetAlpha(searchMatched == false and 0.30 or 1)
        border:Show()
    else
        border:Hide()
    end
end

local function ContainerItem_ClearQualityBorder(button)
    if button and button.QualityBorder then
        button.QualityBorder:Hide()
    end
end

-- ============================================================
-- FUNCIONES DE NIVEL DE ITEM
-- ============================================================
local CONTAINER_SHOW_ITEM_LEVEL = true
local CONTAINER_ITEM_LEVEL_MIN_QUALITY = 2

local function ContainerItem_UpdateItemLevel(button, bagID, slotID, itemLink, quality, searchMatched)
    if not CONTAINER_SHOW_ITEM_LEVEL then return end

    if not button.ItemLevelText then
        button.ItemLevelText = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        button.ItemLevelText:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3)
        button.ItemLevelText:SetJustifyH("LEFT")
        button.ItemLevelText:SetText("")
        button.ItemLevelText:Hide()
    end

    if not itemLink then
        itemLink = GetContainerItemLink(bagID, slotID)
    end

    if not itemLink then
        button.ItemLevelText:SetText("")
        button.ItemLevelText:Hide()
        return
    end

    local _, _, infoQuality, itemLevel, _, itemType = GetItemInfo(itemLink)
    quality = tonumber(quality) or tonumber(infoQuality)

    local isEquipment = itemType == ARMOR or itemType == WEAPON
    if isEquipment and itemLevel and itemLevel > 0 and quality and quality >= CONTAINER_ITEM_LEVEL_MIN_QUALITY then
        button.ItemLevelText:SetText(itemLevel)
        button.ItemLevelText:SetAlpha(searchMatched == false and 0.35 or 1)
        button.ItemLevelText:Show()
    else
        button.ItemLevelText:SetText("")
        button.ItemLevelText:Hide()
    end
end

-- ============================================================
-- FUNCIONES DE TEXTURA DE MISIÓN
-- ============================================================
local function ContainerItem_EnsureQuestTexture(button)
    if not button then return nil end

    if not button.questTexture then
        button.questTexture = button:CreateTexture(nil, "OVERLAY")
        button.questTexture:SetSize(button:GetWidth() + 0, button:GetHeight() + 0)
        button.questTexture:SetPoint("CENTER", button, "CENTER", 0, 0)
        button.questTexture:SetTexture("Interface\\ContainerFrame\\UI-Icon-QuestBang")
        button.questTexture:Hide()
    end
    return button.questTexture
end

local function ContainerItem_UpdateQuestTexture(button, questId, isActive, isQuestItem)
    local questTexture = ContainerItem_EnsureQuestTexture(button)
    if not questTexture then return end

    if questId and not isActive then
        questTexture:SetTexture("Interface\\ContainerFrame\\UI-Icon-QuestBang")
        questTexture:Show()
    elseif questId or isQuestItem then
        questTexture:SetTexture("Interface\\ContainerFrame\\UI-Icon-QuestBang")
        questTexture:Show()
    else
        questTexture:Hide()
    end
end

-- ============================================================
-- FUNCIONES DE FONDO DE SLOT
-- ============================================================
local TEXTURE_SLOT_AVAILABLE = "Interface\\ContainerFrame\\BagsItemSlot"
local TEXTURE_SLOT_LOCKED    = "Interface\\ContainerFrame\\BagsItemSlotClose"

local function ContainerFrame_EnsureSlotBackground(button)
    if not button then return nil end

    local bg = button.slotBackground or button.bg
    if not bg then
        bg = button:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(button)
        bg:SetTexture(TEXTURE_SLOT_AVAILABLE)
        button.slotBackground = bg
        button.bg = bg
    end
    return bg
end

-- ============================================================
-- FUNCIONES DE PANEL DE DINERO
-- ============================================================
local function ContainerFrame_StyleMoneyPanel(frame)
    if not frame or frame._containerMoneyStyled then return end

    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0, 0, 0, 0.92)
    frame:SetBackdropBorderColor(1.0, 0.82, 0.0, 1.0)
    frame._containerMoneyStyled = true
end

-- ============================================================
-- FUNCIONES DE ORDENAMIENTO
-- ============================================================
local BAG_SORT_IDS = { 0, 1, 2, 3, 4 }
local bagSortInProgress = false

local function BagSort_Key(itemType, itemSubType, quality, name, fallback)
    return string.format("%s|%s|%03d|%s",
        itemType or "", itemSubType or "", 99 - (quality or 0), name or fallback or "")
end

local function BagSort_PosKey(bag, slot)
    return bag * 1000 + slot
end

local function BagSort_Scan()
    local positions, items = {}, {}
    local anyLocked = false

    for _, bagID in ipairs(BAG_SORT_IDS) do
        local numSlots = GetContainerNumSlots(bagID) or 0
        for slot = 1, numSlots do
            positions[#positions + 1] = { bag = bagID, slot = slot }

            local _, itemCount, locked, quality = GetContainerItemInfo(bagID, slot)
            local itemLink = GetContainerItemLink(bagID, slot)
            if itemLink then
                if locked then
                    anyLocked = true
                end
                local name, _, itemInfoQuality, _, _, itemType, itemSubType = GetItemInfo(itemLink)
                items[#items + 1] = {
                    bag = bagID,
                    slot = slot,
                    sortKey = BagSort_Key(itemType, itemSubType, itemInfoQuality or quality, name, itemLink),
                }
            end
        end
    end

    return positions, items, anyLocked
end

function ContainerFrame_SortButton_OnClick(self)
    if bagSortInProgress then
        return
    end
    if InCombatLockdown and InCombatLockdown() then
        if UIErrorsFrame then
            UIErrorsFrame:AddMessage("No se puede organizar la mochila en combate.", 1.0, 0.1, 0.1)
        end
        return
    end

    local positions, items, anyLocked = BagSort_Scan()

    if anyLocked then
        if UIErrorsFrame then
            UIErrorsFrame:AddMessage("No se pudo organizar: hay un objeto bloqueado.", 1.0, 0.1, 0.1)
        end
        return
    end

    if #items == 0 then
        return
    end

    table.sort(items, function(a, b) return a.sortKey < b.sortKey end)

    local posIndex, itemAt = {}, {}
    for i, pos in ipairs(positions) do
        posIndex[BagSort_PosKey(pos.bag, pos.slot)] = i
        itemAt[i] = false
    end
    for _, item in ipairs(items) do
        local idx = posIndex[BagSort_PosKey(item.bag, item.slot)]
        if idx then
            itemAt[idx] = item
        end
    end

    local itemLocation = {}
    for i, occupant in ipairs(itemAt) do
        if occupant then
            itemLocation[occupant] = i
        end
    end

    bagSortInProgress = true

    for i = 1, #positions do
        local wanted = items[i] or false
        if itemAt[i] ~= wanted then
            local j
            if wanted then
                j = itemLocation[wanted]
            else
                for k = i + 1, #positions do
                    if not itemAt[k] then
                        j = k
                        break
                    end
                end
            end

            if j and j ~= i then
                local posA, posB = positions[i], positions[j]
                PickupContainerItem(posA.bag, posA.slot)
                PickupContainerItem(posB.bag, posB.slot)
                if CursorHasItem() then
                    PickupContainerItem(posA.bag, posA.slot)
                end

                local movedFromI, movedFromJ = itemAt[i], itemAt[j]
                itemAt[i], itemAt[j] = movedFromJ, movedFromI
                if movedFromJ then itemLocation[movedFromJ] = i end
                if movedFromI then itemLocation[movedFromI] = j end
            end
        end
    end

    bagSortInProgress = false
    PlaySound("igBackPackOpen")
end

-- ============================================================
-- FUNCIONES DE MOCHILA EXPANDIDA
-- ============================================================
function IsExpandedBackpackActive()
    return isExpandedBackpack and expandedBackpackFrame and expandedBackpackFrame:IsShown()
end

function UpdateAllExpandButtons()
    for i = 1, NUM_CONTAINER_FRAMES do
        local frame = _G["ContainerFrame"..i]
        if frame and frame.ExpandButton then
            UpdateExpandButtonTexture(frame.ExpandButton)
        end
    end
end

function UpdateExpandButtonTexture(button)
    if not button then return end
    
    if isExpandedBackpack then
        button:GetNormalTexture():SetTexture("Interface\\Buttons\\UI-Panel-SmallerButton-Up")
        button:GetPushedTexture():SetTexture("Interface\\Buttons\\UI-Panel-SmallerButton-Down")
    else
        button:GetNormalTexture():SetTexture("Interface\\Buttons\\UI-Panel-BiggerButton-Up")
        button:GetPushedTexture():SetTexture("Interface\\Buttons\\UI-Panel-BiggerButton-Down")
    end
end

-- ============================================================
-- FUNCIONES DE PORTRAIT Y TÍTULO
-- ============================================================
local function ContainerFrame_GetPortraitTexture(frame)
    if not frame then return nil end
    return frame.portrait or _G[frame:GetName().."Portrait"]
end

local function ContainerFrame_GetTitleText(frame)
    if not frame then return nil end
    return frame.TitleText or _G[frame:GetName().."TitleText"] or _G[frame:GetName().."Name"]
end

local function ContainerFrame_SetPortraitForBag(frame, bagID)
    local portrait = ContainerFrame_GetPortraitTexture(frame)
    if not portrait then return end
    
    local iconSize = 46

    if bagID == 0 then
        portrait:SetTexture("Interface\\ContainerFrame\\Button-Backpack-Up")
        portrait:SetTexCoord(0, 1, 0, 1)
        portrait:SetSize(iconSize, iconSize)
        portrait:SetPoint("TOPLEFT", frame, "TOPLEFT", -5, 5)
    elseif bagID == KEYRING_CONTAINER then
        portrait:SetTexture("Interface\\ContainerFrame\\KeyRing-Bag-Icon")
        portrait:SetTexCoord(0, 1, 0, 1)
        portrait:SetSize(iconSize, iconSize)
        portrait:SetPoint("TOPLEFT", frame, "TOPLEFT", -5, 5)
    else
        SetBagPortraitTexture(portrait, bagID)
        portrait:SetSize(iconSize, iconSize)
        portrait:SetPoint("TOPLEFT", frame, "TOPLEFT", -5, 5)
    end
end

local function ContainerFrame_RaiseHeaderControls(frame)
    if not frame then return end
    local level = frame:GetFrameLevel() + 30
    if frame.SearchBox then
        frame.SearchBox:SetFrameLevel(level)
    end
    if frame.SortButton then
        frame.SortButton:SetFrameLevel(level + 1)
    end
end

-- ============================================================
-- FUNCIONES DE BUSQUEDA
-- ============================================================
function SetupSearchBoxPlaceholder(searchBox)
    local placeholderText = searchBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    placeholderText:SetPoint("LEFT", searchBox, "LEFT", 15, 0)
    placeholderText:SetText(CONTAINER_SEARCH)
    placeholderText:SetTextColor(0.5, 0.5, 0.5)
    searchBox.placeholderText = placeholderText

    searchBox:SetTextInsets(15, 25, 0, 0)

    local clearButton = CreateFrame("Button", nil, searchBox)
    clearButton:SetSize(12, 12)
    clearButton:SetPoint("RIGHT", searchBox, "RIGHT", -5, 0)
    clearButton:SetNormalTexture("Interface\\Common\\VoiceChat-Muted")
    clearButton:GetNormalTexture():SetVertexColor(0.7, 0.7, 0.7)
    clearButton:SetHighlightTexture("Interface\\Common\\VoiceChat-Muted")
    clearButton:GetHighlightTexture():SetVertexColor(1, 1, 1)
    clearButton:SetAlpha(0.7)

    clearButton:SetScript("OnClick", function(self)
        searchBox:SetText("")
        searchBox:ClearFocus()
        searchText = nil
        ContainerFrame_Update(searchBox:GetParent())
        self:Hide()
    end)
    
    clearButton:SetScript("OnEnter", function(self)
        self:SetAlpha(1)
    end)
    
    clearButton:SetScript("OnLeave", function(self)
        self:SetAlpha(0.7)
    end)
    
    searchBox.clearButton = clearButton
    clearButton:Hide()

    searchBox:SetScript("OnTextChanged", function(self, isUserInput)
        ContainerSearchBox_OnTextChanged(self)
        
        if self:GetText() == "" then
            self.placeholderText:Show()
            self.clearButton:Hide()
        else
            self.placeholderText:Hide()
            self.clearButton:Show()
        end
    end)

    searchBox:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
        if self:GetText() ~= "" then
            self.clearButton:Show()
        end
    end)
    
    searchBox:SetScript("OnEditFocusLost", function(self)
        self:HighlightText(0, 0)
        if self:GetText() == "" then
            self.clearButton:Hide()
        end
    end)
    placeholderText:Show()
end

function ContainerSearchBox_OnTextChanged(self)
    if SearchBoxTemplate_OnTextChanged then
        SearchBoxTemplate_OnTextChanged(self)
    end
    
    local text = self:GetText()

    if #text > 0 then
        if not IsBagOpen(0) then
            ToggleBackpack()
        end

        for i = 1, 4 do
            if not IsBagOpen(i) then
                ToggleBag(i)
            end
        end
        
        searchText = text
    else
        searchText = nil
    end

    for i = 1, NUM_CONTAINER_FRAMES do
        local containerFrame = _G["ContainerFrame"..i]
        if containerFrame and containerFrame:IsShown() then
            ContainerFrame_Update(containerFrame)
        end
    end
end

function ContainerSearchBox_OnEscapePressed(self)
    local text = self:GetText()
    
    if text and #text > 0 then
        self:SetText("")
        searchText = nil

        for i = 1, NUM_CONTAINER_FRAMES do
            local containerFrame = _G["ContainerFrame"..i]
            if containerFrame and containerFrame:IsShown() then
                ContainerFrame_Update(containerFrame)
            end
        end
    else
        self:ClearFocus()
        searchText = nil

        for i = 1, NUM_CONTAINER_FRAMES do
            local containerFrame = _G["ContainerFrame"..i]
            if containerFrame and containerFrame:IsShown() then
                ContainerFrame_Update(containerFrame)
            end
        end
    end
end

function ToggleContainerSearch()
    local backpackFrame = GetBackpackFrame()
    if backpackFrame then
        ContainerFrame_CreateSearchBox(backpackFrame)
        local searchBox = backpackFrame.SearchBox
        
        if searchBox:IsShown() then
            searchBox:Hide()
            searchBox:ClearFocus()
            searchText = nil
        else
            searchBox:Show()
            searchBox:SetFocus()
        end

        for i = 1, NUM_CONTAINER_FRAMES do
            local containerFrame = _G["ContainerFrame"..i]
            if containerFrame and containerFrame:IsShown() then
                ContainerFrame_Update(containerFrame)
            end
        end
    end
end

-- ============================================================
-- FUNCIONES DE ITEM BUTTON
-- ============================================================
function ContainerFrameItemButton_OnLoad(self)
    self:RegisterForClicks("LeftButtonUp", "RightButtonUp");
    self:RegisterForDrag("LeftButton");
    ContainerFrame_EnsureSlotBackground(self)

    -- Crear textura de misión
    ContainerItem_EnsureQuestTexture(self)

    self.SplitStack = function(button, split)
        local bag, slot = ContainerFrameItemButton_GetBagAndSlot(button)
        if bag ~= nil and slot then
            SplitContainerItem(bag, slot, split);
        end
    end
    self.UpdateTooltip = ContainerFrameItemButton_OnEnter;
end

local function ContainerFrameItemButton_GetBagAndSlot(self)
    if not self then return nil, nil end
    if self.bag ~= nil and self.slot ~= nil then
        return self.bag, self.slot
    end
    local parent = self:GetParent()
    if parent and parent.GetID then
        return parent:GetID(), self:GetID()
    end
    return nil, self:GetID()
end

function ContainerFrameItemButton_OnDrag (self)
    ContainerFrameItemButton_OnClick(self, "LeftButton");
end

function ContainerFrame_GetExtendedPriceString(itemButton, isEquipped, quantity)
    quantity = (quantity or 1);
    local bag, slot = ContainerFrameItemButton_GetBagAndSlot(itemButton)
    if bag == nil or not slot then return false end

    local money, honorPoints, arenaPoints, itemCount, refundSec = GetContainerItemPurchaseInfo(bag, slot, isEquipped);
    if ( not refundSec or ((honorPoints == 0) and (arenaPoints == 0) and (itemCount == 0) and (money == 0)) ) then
        return false;
    end
    
    local count = itemButton.count or 1;
    honorPoints, arenaPoints, itemCount = (honorPoints or 0) * quantity, (arenaPoints or 0) * quantity, (itemCount or 0) * quantity;
    local itemsString;

    if ( honorPoints and honorPoints ~= 0 ) then
        local factionGroup = UnitFactionGroup("player");
        if ( factionGroup ) then	
            local pointsTexture = "Interface\\PVPFrame\\PVP-Currency-"..factionGroup;
            itemsString = " |T" .. pointsTexture .. ":0:0:0:-1|t" ..  honorPoints .. " " .. HONOR_POINTS;
        end
    end
    if ( arenaPoints and arenaPoints ~= 0 ) then
        if ( itemsString ) then
            itemsString = itemsString .. "  |TInterface\\PVPFrame\\PVP-ArenaPoints-Icon:0:0:0:-1|t" .. arenaPoints .. " " .. ARENA_POINTS;
        else
            itemsString = " |TInterface\\PVPFrame\\PVP-ArenaPoints-Icon:0:0:0:-1|t" .. arenaPoints .. " " .. ARENA_POINTS;
        end
    end
    
    local maxQuality = 0;
    for i=1, itemCount, 1 do
        local itemTexture, itemQuantity, itemLink = GetContainerItemPurchaseItem(bag, slot, i, isEquipped);
        if ( itemLink ) then
            local _, _, itemQuality = GetItemInfo(itemLink);
            maxQuality = math.max(itemQuality, maxQuality);
            if ( itemsString ) then
                itemsString = itemsString .. ", " .. format(ITEM_QUANTITY_TEMPLATE, (itemQuantity or 0) * quantity, itemLink);
            else
                itemsString = format(ITEM_QUANTITY_TEMPLATE, (itemQuantity or 0) * quantity, itemLink);
            end
        end
    end
    if(itemsString == nil) then
        itemsString = "";
    end
    MerchantFrame.price = money;
    MerchantFrame.refundBag = bag;
    MerchantFrame.refundSlot = slot;
    MerchantFrame.honorPoints = honorPoints;
    MerchantFrame.arenaPoints = arenaPoints;

    local refundItemTexture, refundItemLink;
    if ( isEquipped ) then
        refundItemTexture = GetInventoryItemTexture("player", slot);
        refundItemLink = GetInventoryItemLink("player", slot);
    else
        refundItemTexture, _, _, _, _, _, refundItemLink = GetContainerItemInfo(bag, slot);
    end
    local itemName, _, itemQuality = GetItemInfo(refundItemLink);
    local r, g, b = GetItemQualityColor(itemQuality);
    StaticPopupDialogs["CONFIRM_REFUND_TOKEN_ITEM"].hasMoneyFrame = (money ~= 0) and 1 or nil;
    StaticPopup_Show("CONFIRM_REFUND_TOKEN_ITEM", itemsString, "", {["texture"] = refundItemTexture, ["name"] = itemName, ["color"] = {r, g, b, 1}, ["link"] = refundItemLink, ["index"] = index, ["count"] = count * quantity});
    return true;
end

function ContainerFrameItemButton_OnClick(self, button)
    local bag, slot = ContainerFrameItemButton_GetBagAndSlot(self)
    if bag == nil or not slot then return end

    MerchantFrame_ResetRefundItem();

    if ( button == "LeftButton" ) then
        local type, money = GetCursorInfo();
        if ( SpellCanTargetItem() ) then
            UseContainerItem(bag, slot);
        elseif ( type == "guildbankmoney" ) then
            WithdrawGuildBankMoney(money);
            ClearCursor();
        elseif ( type == "money" ) then
            DropCursorMoney();
            ClearCursor();
        elseif ( type == "merchant" ) then
            if ( MerchantFrame.extendedCost ) then
                MerchantFrame_ConfirmExtendedItemCost(MerchantFrame.extendedCost);
            elseif ( MerchantFrame.price and MerchantFrame.price >= MERCHANT_HIGH_PRICE_COST ) then
                MerchantFrame_ConfirmHighCostItem(self);
            else
                PickupContainerItem(bag, slot);
            end
        else
            PickupContainerItem(bag, slot);
            if ( CursorHasItem() and self.bag == nil ) then
                MerchantFrame_SetRefundItem(self);
            end
        end
        StackSplitFrame:Hide();
    else
        if ( MerchantFrame:IsShown() ) then
            if ( MerchantFrame.selectedTab == 2 ) then
                return;
            end
            if ( ContainerFrame_GetExtendedPriceString(self)) then
                return;
            end
        end
        UseContainerItem(bag, slot);
        StackSplitFrame:Hide();
    end
end

function ContainerFrameItemButton_OnModifiedClick(self, button)
    local bag, slot = ContainerFrameItemButton_GetBagAndSlot(self)
    if bag == nil or not slot then return end

    if ( HandleModifiedItemClick(GetContainerItemLink(bag, slot)) ) then
        return;
    end
    if ( IsModifiedClick("SOCKETITEM") ) then
        SocketContainerItem(bag, slot);
    end
    if ( IsModifiedClick("SPLITSTACK") ) then
        local texture, itemCount, locked = GetContainerItemInfo(bag, slot);
        if ( not locked ) then
            self.SplitStack = function(button, split)
                local splitBag, splitSlot = ContainerFrameItemButton_GetBagAndSlot(button)
                if splitBag ~= nil and splitSlot then
                    SplitContainerItem(splitBag, splitSlot, split);
                end
            end
            OpenStackSplitFrame(itemCount, self, "BOTTOMRIGHT", "TOPRIGHT");
        end
        return;
    end
end

function ContainerFrameItemButton_OnEnter(self)
    local bag, slot = ContainerFrameItemButton_GetBagAndSlot(self)
    if bag == nil or not slot then return end

    local x;
    x = self:GetRight();
    if ( x >= ( GetScreenWidth() / 2 ) ) then
        GameTooltip:SetOwner(self, "ANCHOR_LEFT");
    else
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
    end

    if ( bag == KEYRING_CONTAINER and self.bag == nil ) then
        GameTooltip:SetInventoryItem("player", KeyRingButtonIDToInvSlotID(slot));
        CursorUpdate(self);
        return;
    end

    local showSell = nil;
    local hasCooldown, repairCost = GameTooltip:SetBagItem(bag, slot);
    if ( InRepairMode() and (repairCost and repairCost > 0) ) then
        GameTooltip:AddLine(REPAIR_COST, "", 1, 1, 1);
        SetTooltipMoney(GameTooltip, repairCost);
        GameTooltip:Show();
    elseif ( MerchantFrame:IsShown() and MerchantFrame.selectedTab == 1 ) then
        showSell = 1;
    end

    if ( IsModifiedClick("DRESSUP") and self.hasItem ) then
        ShowInspectCursor();
    elseif ( showSell ) then
        ShowContainerSellCursor(bag, slot);
    elseif ( self.readable ) then
        ShowInspectCursor();
    else
        ResetCursor();
    end
end

-- ============================================================
-- FUNCIONES DE MOCHILA INDIVIDUAL
-- ============================================================
function ContainerFrame_OnLoad(self)
    self:RegisterEvent("BAG_OPEN");
    self:RegisterEvent("BAG_CLOSED");
    self:RegisterEvent("QUEST_ACCEPTED");
    self:RegisterEvent("UNIT_QUEST_LOG_CHANGED");
    ContainerFrame1.bagsShown = 0;
    ContainerFrame1.bags = {};
end

function ContainerFrame_OnEvent(self, event, ...)
    local arg1, arg2 = ...;
    if ( event == "BAG_OPEN" ) then
        if ( self:GetID() == arg1 ) then
            self:Show();
        end
    elseif ( event == "BAG_CLOSED" ) then
        if ( self:GetID() == arg1 ) then
            self:Hide();
        end
    elseif ( event == "BAG_UPDATE" ) then
        if ( self:GetID() == arg1 ) then
            ContainerFrame_Update(self);
        end
    elseif ( event == "ITEM_LOCK_CHANGED" ) then
        local bag, slot = arg1, arg2;
        if ( bag and slot and (bag == self:GetID()) ) then
            ContainerFrame_UpdateLockedItem(self, slot);
        end
    elseif ( event == "BAG_UPDATE_COOLDOWN" ) then
        ContainerFrame_UpdateCooldowns(self);
    elseif ( event == "QUEST_ACCEPTED" or (event == "UNIT_QUEST_LOG_CHANGED" and arg1 == "player") ) then
        for i = 1, ContainerFrame1.bagsShown do
            local bag = _G[ContainerFrame1.bags[i]];
            ContainerFrame_Update(bag);
        end
    elseif ( event == "DISPLAY_SIZE_CHANGED" ) then
        updateContainerFrameAnchors();
    end
end

function ContainerFrame_OnHide(self)
    self:UnregisterEvent("BAG_UPDATE");
    self:UnregisterEvent("ITEM_LOCK_CHANGED");
    self:UnregisterEvent("BAG_UPDATE_COOLDOWN");
    self:UnregisterEvent("DISPLAY_SIZE_CHANGED");

    if ( self:GetID() == 0 ) then
        MainMenuBarBackpackButton:SetChecked(0);
    else
        local bagButton = _G["CharacterBag"..(self:GetID() - 1).."Slot"];
        if ( bagButton ) then
            bagButton:SetChecked(0);
        else
            UpdateBagButtonHighlight(self:GetID()); 
        end
    end
    ContainerFrame1.bagsShown = ContainerFrame1.bagsShown - 1;
    local index = 1;
    while ContainerFrame1.bags[index] do
        if ( ContainerFrame1.bags[index] == self:GetName() ) then
            local tempIndex = index;
            while ContainerFrame1.bags[tempIndex] do
                if ( ContainerFrame1.bags[tempIndex + 1] ) then
                    ContainerFrame1.bags[tempIndex] = ContainerFrame1.bags[tempIndex + 1];
                else
                    ContainerFrame1.bags[tempIndex] = nil;
                end
                tempIndex = tempIndex + 1;
            end
        end
        index = index + 1;
    end
    updateContainerFrameAnchors();

    if ( self:GetID() == KEYRING_CONTAINER ) then
        UpdateMicroButtons();
        PlaySound("KeyRingClose");
    else
        PlaySound("igBackPackClose");
    end
end

function ContainerFrame_OnShow(self)
    self:RegisterEvent("BAG_UPDATE");
    self:RegisterEvent("ITEM_LOCK_CHANGED");
    self:RegisterEvent("BAG_UPDATE_COOLDOWN");
    self:RegisterEvent("DISPLAY_SIZE_CHANGED");

    if ( self:GetID() == 0 ) then
        MainMenuBarBackpackButton:SetChecked(1);
    elseif ( self:GetID() <= NUM_BAG_SLOTS ) then 
        local button = _G["CharacterBag"..(self:GetID() - 1).."Slot"];
        if ( button ) then
            button:SetChecked(1);
        end
    else
        UpdateBagButtonHighlight(self:GetID());
    end
    ContainerFrame1.bagsShown = ContainerFrame1.bagsShown + 1;
    if ( self:GetID() == KEYRING_CONTAINER ) then
        UpdateMicroButtons();
        PlaySound("KeyRingOpen");
    else
        PlaySound("igBackPackOpen");
    end
    ContainerFrame_Update(self);

    if ( ManageBackpackTokenFrame ) then
        ManageBackpackTokenFrame();
    end
end

function ContainerFrame_Update(frame)
    local id = frame:GetID();
    local name = frame:GetName();
    local itemButton;
    local texture, itemCount, locked, quality, readable;
    local isQuestItem, questId, isActive;
    local tooltipOwner = GameTooltip:GetOwner();
    
    for i=1, frame.size, 1 do
        itemButton = _G[name.."Item"..i];
        
        texture, itemCount, locked, quality, readable = GetContainerItemInfo(id, itemButton:GetID());
        isQuestItem, questId, isActive = GetContainerItemQuestInfo(id, itemButton:GetID());
        
        SetItemButtonTexture(itemButton, texture);
        SetItemButtonCount(itemButton, itemCount);
        SetItemButtonDesaturated(itemButton, locked, 0.5, 0.5, 0.5);
        
        -- Actualizar textura de misión
        ContainerItem_UpdateQuestTexture(itemButton, questId, isActive, isQuestItem);
        
        if ( texture ) then
            ContainerFrame_UpdateCooldown(id, itemButton);
            itemButton.hasItem = 1;
            
            -- Actualizar borde de calidad
            local itemLink = GetContainerItemLink(id, itemButton:GetID());
            local searchMatched = true
            
            if searchText and searchText ~= "" then
                local itemEntry = GetContainerItemID(id, itemButton:GetID())
                local itemName = GetItemInfo(itemEntry)
                if itemName then
                    searchMatched = string.find(string.upper(itemName), string.upper(searchText), 1, true) ~= nil
                else
                    searchMatched = false
                end
            end
            
            ContainerItem_UpdateQualityBorder(itemButton, id, itemButton:GetID(), quality, searchMatched)
            ContainerItem_UpdateItemLevel(itemButton, id, itemButton:GetID(), itemLink, quality, searchMatched)
            
        else
            _G[name.."Item"..i.."Cooldown"]:Hide();
            itemButton.hasItem = nil;
            ContainerItem_ClearQualityBorder(itemButton)
        end
        itemButton.readable = readable;
        
        if ( itemButton == tooltipOwner ) then
            itemButton.UpdateTooltip(itemButton);
        end
        if itemButton.searchOverlay then
            itemButton.searchOverlay:Hide()
        end

        if searchText and searchText ~= "" and texture then
            local itemEntry = GetContainerItemID(id, itemButton:GetID())
            local itemName = GetItemInfo(itemEntry)
    
            if itemName then
                if itemButton.searchOverlay then
                    itemButton.searchOverlay:Show()
                end
                if string.find(string.upper(itemName), string.upper(searchText)) then
                    if itemButton.searchOverlay then
                        itemButton.searchOverlay:Hide()
                    end
                end
            end
        end
    end
end

function ContainerFrame_UpdateLocked(frame)
    local id = frame:GetID();
    local name = frame:GetName();
    local itemButton;
    local texture, itemCount, locked, quality, readable;
    for i=1, frame.size, 1 do
        itemButton = _G[name.."Item"..i];
        
        texture, itemCount, locked, quality, readable = GetContainerItemInfo(id, itemButton:GetID());

        SetItemButtonDesaturated(itemButton, locked, 0.5, 0.5, 0.5);
    end
end

function ContainerFrame_UpdateLockedItem(frame, slot)
    local index = frame.size + 1 - slot;
    local itemButton = _G[frame:GetName().."Item"..index];
    local texture, itemCount, locked, quality, readable = GetContainerItemInfo(frame:GetID(), itemButton:GetID());

    SetItemButtonDesaturated(itemButton, locked, 0.5, 0.5, 0.5);
end

function ContainerFrame_UpdateCooldowns(frame)
    local id = frame:GetID();
    local name = frame:GetName();
    for i=1, frame.size, 1 do
        local itemButton = _G[name.."Item"..i];
        if ( GetContainerItemInfo(id, itemButton:GetID()) ) then
            ContainerFrame_UpdateCooldown(id, itemButton);
        else
            _G[name.."Item"..i.."Cooldown"]:Hide();
        end
    end
end

function ContainerFrame_UpdateCooldown(container, button)
    local cooldown = _G[button:GetName().."Cooldown"];
    local start, duration, enable = GetContainerItemCooldown(container, button:GetID());
    CooldownFrame_SetTimer(cooldown, start, duration, enable);
    if ( duration > 0 and enable == 0 ) then
        SetItemButtonTextureVertexColor(button, 0.4, 0.4, 0.4);
    else
        SetItemButtonTextureVertexColor(button, 1, 1, 1);
    end
end

function ContainerFrame_GenerateFrame(frame, size, id)
    frame.size = size;
    local name = frame:GetName();
    local columns = NUM_CONTAINER_COLUMNS;
    local rows = ceil(size / columns);

    if id == 0 then
        local moneyBorder = _G[name.."MoneyBorder"];
        local moneyFrame = _G[name.."MoneyFrame"];
        if moneyBorder then
            moneyBorder:SetSize(165, 20)
            moneyBorder:Show();
            ContainerFrame_StyleMoneyPanel(moneyBorder)
        end
        if moneyFrame then
            moneyFrame:Show();
        end

        if frame.SearchBox then
            frame.SearchBox:Show();
            frame.SearchBox:SetText("");
        end
        if frame.SortButton then
            frame.SortButton:Show();
        end

        frame:SetHeight(BACKPACK_HEIGHT);
    else
        local moneyBorder = _G[name.."MoneyBorder"];
        if moneyBorder then moneyBorder:Hide(); end
        local moneyFrame = _G[name.."MoneyFrame"];
        if moneyFrame then moneyFrame:Hide(); end

        if frame.SearchBox then
            frame.SearchBox:Hide();
        end
        if frame.SortButton then
            frame.SortButton:Hide();
        end

        if size == 1 then
            frame:SetHeight(70);
        else
            local firstRowHeight;
            if mod(size, columns) == 2 then
                firstRowHeight = 73;
            else
                firstRowHeight = 95;
            end
            frame:SetHeight(firstRowHeight + math.max(0, rows - 1) * 41);
        end
    end

    if (size == 1) then
        frame:SetWidth(99);
        local titleText = ContainerFrame_GetTitleText(frame)
        if titleText then titleText:SetText("") end
        ContainerFrame_SetPortraitForBag(frame, id);
        local itemButton = _G[name.."Item1"];
        itemButton:SetID(1);
        itemButton:SetPoint("BOTTOMRIGHT", name, "BOTTOMRIGHT", -10, 5);
        itemButton:Show();
    else
        frame:SetWidth(CONTAINER_WIDTH);

        local titleText = ContainerFrame_GetTitleText(frame)
        if ( id == KEYRING_CONTAINER ) then
            if titleText then titleText:SetText(KEYRING) end
        else
            if titleText then titleText:SetText(GetBagName(id)) end
        end
        ContainerFrame_SetPortraitForBag(frame, id);

        local index, itemButton;
        for i=1, size, 1 do
            index = size - i + 1;
            itemButton = _G[name.."Item"..i];
            itemButton:SetID(index);
            if ( i == 1 ) then
                if ( id == 0 ) then
                    itemButton:SetPoint("BOTTOMRIGHT", name, "TOPRIGHT", -12, -225);
                else
                    itemButton:SetPoint("BOTTOMRIGHT", name, "BOTTOMRIGHT", -12, 9);
                end
                
            else
                if ( mod((i-1), columns) == 0 ) then
                    itemButton:SetPoint("BOTTOMRIGHT", name.."Item"..(i - columns), "TOPRIGHT", 0, 4);    
                else
                    itemButton:SetPoint("BOTTOMRIGHT", name.."Item"..(i - 1), "BOTTOMLEFT", -5, 0);    
                end
            end
            itemButton:Show();
        end

        if id == 0 then
            local moneyBorder = _G[name.."MoneyBorder"];
            if moneyBorder and size > 0 then

                local lastSlotButton = _G[name.."Item1"]
                if lastSlotButton then
                    moneyBorder:ClearAllPoints()
                    moneyBorder:SetPoint("BOTTOMRIGHT", lastSlotButton, "BOTTOMRIGHT", 0, -24)
                end
            end
        end
    end

    for i=size + 1, MAX_CONTAINER_ITEMS, 1 do
        _G[name.."Item"..i]:Hide();
    end
	
    if frame.ExpandButton then
        frame.ExpandButton:SetFrameLevel(frame:GetFrameLevel() + 50)
    end
    
    frame:SetID(id);
    _G[frame:GetName().."PortraitButton"]:SetID(id);

    ContainerFrame1.bags[ContainerFrame1.bagsShown + 1] = frame:GetName();
    ContainerFrame_RaiseHeaderControls(frame)
    updateContainerFrameAnchors();
    frame:Show();
    
    if frame.ExpandButton then
        if id == 0 then
            UpdateExpandButtonTexture(frame.ExpandButton)
            frame.ExpandButton:Show()
        else
            frame.ExpandButton:Hide()
        end
    end
end

function updateContainerFrameAnchors()
    local frame, xOffset, yOffset, screenHeight, freeScreenHeight, leftMostPoint, column;
    local screenWidth = GetScreenWidth();
    local containerScale = 1;
    local leftLimit = 0;

    local combinedActive = IsExpandedBackpackActive();
    local anchorFrame = UIParent;
    local anchorRelPoint = "BOTTOMRIGHT";
    local startRight = screenWidth;
    local COMBINED_GAP = 0;

    if ( combinedActive ) then
        anchorFrame = expandedBackpackFrame;
        anchorRelPoint = "BOTTOMLEFT";
        startRight = (expandedBackpackFrame:GetLeft() or screenWidth) - COMBINED_GAP;
    elseif ( BankFrame:IsShown() ) then
        leftLimit = BankFrame:GetRight() - 25;
    end
    
    while ( containerScale > CONTAINER_SCALE ) do
        screenHeight = GetScreenHeight() / containerScale;
        xOffset = CONTAINER_OFFSET_X / containerScale; 
        yOffset = CONTAINER_OFFSET_Y / containerScale; 
        freeScreenHeight = screenHeight - yOffset;
        leftMostPoint = startRight - xOffset;
        column = 1;
        local frameHeight;
        for index, frameName in ipairs(ContainerFrame1.bags) do
            frameHeight = _G[frameName]:GetHeight();
            if ( freeScreenHeight < frameHeight ) then
                column = column + 1;
                leftMostPoint = startRight - ( column * CONTAINER_WIDTH * containerScale ) - xOffset;
                freeScreenHeight = screenHeight - yOffset;
            end
            freeScreenHeight = freeScreenHeight - frameHeight - VISIBLE_CONTAINER_SPACING;
        end
        if ( leftMostPoint < leftLimit ) then
            containerScale = containerScale - 0.01;
        else
            break;
        end
    end
    
    if ( containerScale < CONTAINER_SCALE ) then
        containerScale = CONTAINER_SCALE;
    end
    
    screenHeight = GetScreenHeight() / containerScale;
    xOffset = CONTAINER_OFFSET_X / containerScale;
    yOffset = CONTAINER_OFFSET_Y / containerScale;
    freeScreenHeight = screenHeight - yOffset;
    column = 0;
    for index, frameName in ipairs(ContainerFrame1.bags) do
        frame = _G[frameName];
        frame:SetScale(containerScale);
        if ( index == 1 ) then
            frame:SetPoint("BOTTOMRIGHT", anchorFrame, anchorRelPoint, -xOffset, yOffset );
        elseif ( freeScreenHeight < frame:GetHeight() ) then
            column = column + 1;
            freeScreenHeight = screenHeight - yOffset;
            frame:SetPoint("BOTTOMRIGHT", anchorFrame, anchorRelPoint, -(column * CONTAINER_WIDTH) - xOffset, yOffset );
        else
            frame:SetPoint("BOTTOMRIGHT", ContainerFrame1.bags[index - 1], "TOPRIGHT", 0, CONTAINER_SPACING);    
        end
        freeScreenHeight = freeScreenHeight - frame:GetHeight() - VISIBLE_CONTAINER_SPACING;
    end
end

-- ============================================================
-- FUNCIONES DE ABRIR/CERRAR
-- ============================================================
function OpenBag(id)
    if ( not CanOpenPanels() ) then
        if ( UnitIsDead("player") ) then
            NotWhileDeadError();
        end
        return;
    end

    local size = GetContainerNumSlots(id);
    if ( size > 0 ) then
        local containerShowing;
        for i=1, NUM_CONTAINER_FRAMES, 1 do
            local frame = _G["ContainerFrame"..i];
            if ( frame:IsShown() and frame:GetID() == id ) then
                containerShowing = i;
            end
        end
        if ( not containerShowing ) then
            ContainerFrame_GenerateFrame(ContainerFrame_GetOpenFrame(), size, id);
        end
    end
end

function CloseBag(id)
    for i=1, NUM_CONTAINER_FRAMES, 1 do
        local containerFrame = _G["ContainerFrame"..i];
        if ( containerFrame:IsShown() and (containerFrame:GetID() == id) ) then
            containerFrame:Hide();
            return;
        end
    end
end

function IsBagOpen(id)
    for i=1, NUM_CONTAINER_FRAMES, 1 do
        local containerFrame = _G["ContainerFrame"..i];
        if ( containerFrame:IsShown() and (containerFrame:GetID() == id) ) then
            return i;
        end
    end
    return nil;
end

function ContainerFrame_GetOpenFrame()
    for i=1, NUM_CONTAINER_FRAMES, 1 do
        local frame = _G["ContainerFrame"..i];
        if ( not frame:IsShown() ) then
            return frame;
        end
        if ( i == NUM_CONTAINER_FRAMES ) then
            frame:Hide();
            return frame;
        end
    end
end

function OpenBackpack()
    if ( not CanOpenPanels() ) then
        if ( UnitIsDead("player") ) then
            NotWhileDeadError();
        end
        return;
    end

    for i=1, NUM_CONTAINER_FRAMES, 1 do
        local containerFrame = _G["ContainerFrame"..i];
        if ( containerFrame:IsShown() and (containerFrame:GetID() == 0) ) then
            ContainerFrame1.backpackWasOpen = 1;
            return;
        else
            ContainerFrame1.backpackWasOpen = nil;
        end
    end

    if ( not ContainerFrame1.backpackWasOpen ) then
        ToggleBackpack();
    end
    
    return ContainerFrame1.backpackWasOpen;
end

function CloseBackpack()
    for i=1, NUM_CONTAINER_FRAMES, 1 do
        local containerFrame = _G["ContainerFrame"..i];
        if ( containerFrame:IsShown() and (containerFrame:GetID() == 0) and (ContainerFrame1.backpackWasOpen == nil) ) then
            containerFrame:Hide();
            return;
        end
    end
end

function GetBackpackFrame()
    local index = IsBagOpen(0);
    if ( index ) then
        return _G["ContainerFrame"..index];
    else
        return nil;
    end
end

function CloseAllBags()
    CloseBackpack();
    for i=1, NUM_CONTAINER_FRAMES, 1 do
        CloseBag(i);
    end
end

function ToggleBackpack()
    if ( IsOptionFrameOpen() ) then
        return;
    end

    if isExpandedBackpack then
        if expandedBackpackFrame and expandedBackpackFrame:IsShown() then
            expandedBackpackFrame:Hide()
        else
            ToggleExpandedBackpack()
        end
    else
        if ( IsBagOpen(0) ) then
            for i=1, NUM_CONTAINER_FRAMES, 1 do
                local frame = _G["ContainerFrame"..i];
                if ( frame:IsShown() ) then
                    frame:Hide();
                end
                if ( BackpackTokenFrame ) then
                    BackpackTokenFrame:Hide();
                end
            end
        else
            ToggleBag(0);
            if ( ManageBackpackTokenFrame ) then
                BackpackTokenFrame_Update();
                ManageBackpackTokenFrame();
            end
        end
    end
end

function ToggleBag(id)
    if ( IsOptionFrameOpen() ) then
        return;
    end

    local isMergeableBag = (id >= 0) and (id <= NUM_BAG_FRAMES);

    if isExpandedBackpack and isMergeableBag then
        if expandedBackpackFrame and expandedBackpackFrame:IsShown() then
            expandedBackpackFrame:Hide()
        else
            ToggleExpandedBackpack()
        end
        return
    end

    local size = GetContainerNumSlots(id);
    if ( size > 0 or id == KEYRING_CONTAINER ) then
        local containerShowing;
        for i=1, NUM_CONTAINER_FRAMES, 1 do
            local frame = _G["ContainerFrame"..i];
            if ( frame:IsShown() and frame:GetID() == id ) then
                containerShowing = i;
                frame:Hide();
            end
        end
        if ( not containerShowing ) then
            ContainerFrame_GenerateFrame(ContainerFrame_GetOpenFrame(), size, id);
        end
    end
end

function OpenAllBags(forceOpen)
    if ( not UIParent:IsShown() ) then
        return;
    end

    if isExpandedBackpack and not forceOpen then
        if not (expandedBackpackFrame and expandedBackpackFrame:IsShown()) then
            ToggleExpandedBackpack()
        end
        if ( BankFrame:IsShown() ) then
            for i = 5, 11 do
                if not IsBagOpen(i) then
                    ToggleBag(i)
                end
            end
        end
        return
    end

    local bagsOpen = 0;
    local totalBags = 1;
    for i=1, NUM_CONTAINER_FRAMES, 1 do
        local containerFrame = _G["ContainerFrame"..i];
        local bagButton = _G["CharacterBag"..(i -1).."Slot"];
        if ( (i <= NUM_BAG_FRAMES) and GetContainerNumSlots(bagButton:GetID() - CharacterBag0Slot:GetID() + 1) > 0) then        
            totalBags = totalBags + 1;
        end
        if ( containerFrame:IsShown() ) then
            containerFrame:Hide();
            if ( containerFrame:GetID() ~= KEYRING_CONTAINER ) then
                bagsOpen = bagsOpen + 1;
            end
        end
    end
    if ( bagsOpen >= totalBags and not forceOpen ) then
        return;
    else
        ToggleBackpack();
        ToggleBag(1);
        ToggleBag(2);
        ToggleBag(3);
        ToggleBag(4);
        if ( BankFrame:IsShown() ) then
            ToggleBag(5);
            ToggleBag(6);
            ToggleBag(7);
            ToggleBag(8);
            ToggleBag(9);
            ToggleBag(10);
            ToggleBag(11);
        end
    end
end

function CloseMergedBackpackBags()
    for i=1, NUM_CONTAINER_FRAMES, 1 do
        local frame = _G["ContainerFrame"..i];
        if ( frame:IsShown() ) then
            local id = frame:GetID();
            if ( id ~= KEYRING_CONTAINER and id >= 0 and id <= NUM_BAG_FRAMES ) then
                frame:Hide();
            end
        end
    end
end

-- ============================================================
-- FUNCIONES DE KEYRING
-- ============================================================
function PutKeyInKeyRing()
    local texture;
    local emptyKeyRingSlot;
    for i=1, GetKeyRingSize() do
        texture = GetContainerItemInfo(KEYRING_CONTAINER, i);
        if ( not texture ) then
            emptyKeyRingSlot = i;
            break;
        end
    end
    if ( emptyKeyRingSlot ) then
        PickupContainerItem(KEYRING_CONTAINER, emptyKeyRingSlot);
    else
        UIErrorsFrame:AddMessage(NO_EMPTY_KEYRING_SLOTS, 1.0, 0.1, 0.1, 1.0);
    end
end

function ToggleKeyRing()
    if ( IsOptionFrameOpen() ) then
        return;
    end
    
    local shownContainerID = IsBagOpen(KEYRING_CONTAINER);
    if ( shownContainerID ) then
        _G["ContainerFrame"..shownContainerID]:Hide();
    else
        ContainerFrame_GenerateFrame(ContainerFrame_GetOpenFrame(), GetKeyRingSize(), KEYRING_CONTAINER);
        SetButtonPulse(KeyRingButton, 0, 1);
    end
end

function GetKeyRingSize()
    local numSlots = GetContainerNumSlots(KEYRING_CONTAINER)
    if not numSlots or numSlots == 0 then return 8 end

    local maxF = 0
    for i = 1, numSlots do
        local texture = GetContainerItemInfo(KEYRING_CONTAINER, i)
        if texture then
            maxF = i
        end
    end

    local minSlots = 6
    local size = math.max(minSlots, maxF)
    size = math.ceil(size / 4) * 4
    return math.min(size, numSlots)
end

-- ============================================================
-- FUNCIONES DE MOCHILA EXPANDIDA
-- ============================================================
function ToggleExpandedBackpack(parentFrame)
    if isExpandedBackpack and expandedBackpackFrame and expandedBackpackFrame:IsShown() then
        expandedBackpackFrame:Hide()
        isExpandedBackpack = false
        expandedSearchText = nil
        PlaySound("igBackPackClose")
        ToggleBag(0)
        updateContainerFrameAnchors()
        UpdateBackpackButtonState()
    else
        CloseMergedBackpackBags()
        isExpandedBackpack = true

        if not expandedBackpackFrame then
            local f = CreateFrame("Frame", "ExpandedBackpackFrame", UIParent, "ExpandedBackpackTemplate")
            f:SetWidth(435)
            f:SetHeight(780)
            f:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -80, 100)
            f:SetMovable(true)
            f:EnableMouse(true)
            f:RegisterForDrag("LeftButton")
            f:SetScript("OnDragStart", function(self) self:StartMoving() end)
            f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
            
            table.insert(UISpecialFrames, "ExpandedBackpackFrame")

            if f.TitleText then
                f.TitleText:SetText(CONTAINER_EXPAND)
            end
            ContainerFrame_SetPortraitForBag(f, 0)

            f:SetScript("OnHide", function(self)
                PlaySound("igBackPackClose")
                UpdateBackpackButtonState()
            end)

            CreateExpandedBackpackSearchBox(f)

            f.itemContainer = CreateFrame("Frame", nil, f)
            f.itemContainer:SetPoint("TOPLEFT", 20, -80)
            f.itemContainer:SetWidth(460)
            f.itemContainer:SetHeight(420)

            f:RegisterEvent("BAG_UPDATE")
            f:SetScript("OnEvent", function(self, event, ...)
                if event == "BAG_UPDATE" then
                    RefreshExpandedBackpackIcons()
                end
            end)

            expandedBackpackFrame = f
        else
            if expandedBackpackFrame.SearchBox then
                expandedBackpackFrame.SearchBox:SetText("")
                expandedSearchText = nil
            end
        end

        RefreshExpandedBackpackIcons()
        expandedBackpackFrame:Show()
        PlaySound("igBackPackOpen")
        updateContainerFrameAnchors()
        UpdateBackpackButtonState()
    end
end

function UpdateBackpackButtonState()
    if MainMenuBarBackpackButton then
        local anyBagOpen = false

        if isExpandedBackpack and expandedBackpackFrame and expandedBackpackFrame:IsShown() then
            anyBagOpen = true
        else
            for i = 0, NUM_BAG_FRAMES do
                if IsBagOpen(i) then
                    anyBagOpen = true
                    break
                end
            end
        end

        if anyBagOpen then
            MainMenuBarBackpackButton:SetChecked(1)
        else
            MainMenuBarBackpackButton:SetChecked(0)
        end
    end
end

function CreateExpandedBackpackSearchBox(frame)
    if frame.SearchBox then
        return frame.SearchBox
    end
    
    local searchBox = CreateFrame("EditBox", "ExpandedBackpackSearchBox", frame)
    searchBox:SetSize(220, 22)
    searchBox:SetPoint("TOP", frame, "TOP", 0, -45)
    searchBox:SetAutoFocus(false)
    searchBox:SetFontObject("ChatFontNormal")

    searchBox:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    searchBox:SetBackdropColor(0, 0, 0, 0.5)

    local searchIcon = searchBox:CreateTexture(nil, "ARTWORK")
    searchIcon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
    searchIcon:SetSize(16, 16)
    searchIcon:SetPoint("LEFT", searchBox, "LEFT", 5, -2)

    local placeholderText = searchBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    placeholderText:SetPoint("LEFT", searchIcon, "RIGHT", 4, 2)
    placeholderText:SetText(CONTAINER_SEARCH)
    placeholderText:SetTextColor(0.5, 0.5, 0.5)
    searchBox.placeholderText = placeholderText

    searchBox:SetTextInsets(22, 25, 0, 0)

    searchBox:SetScript("OnTextChanged", function(self)
        if self:GetText() == "" then
            self.placeholderText:Show()
        else
            self.placeholderText:Hide()
        end
    end)

    local clearButton = CreateFrame("Button", nil, searchBox)
    clearButton:SetSize(12, 12)
    clearButton:SetPoint("RIGHT", searchBox, "RIGHT", -5, 0)
    clearButton:SetNormalTexture("Interface\\Common\\VoiceChat-Muted")
    clearButton:GetNormalTexture():SetVertexColor(0.7, 0.7, 0.7)
    clearButton:SetHighlightTexture("Interface\\Common\\VoiceChat-Muted")
    clearButton:GetHighlightTexture():SetVertexColor(1, 1, 1)
    clearButton:SetAlpha(0.7)
    
    clearButton:SetScript("OnClick", function(self)
        searchBox:SetText("")
        searchBox:ClearFocus()
        expandedSearchText = nil
        RefreshExpandedBackpackIcons()
        self:Hide()
    end)
    
    clearButton:SetScript("OnEnter", function(self)
        self:SetAlpha(1)
    end)
    
    clearButton:SetScript("OnLeave", function(self)
        self:SetAlpha(0.7)
    end)
    
    searchBox.clearButton = clearButton
    clearButton:Hide()

    local sortButton = CreateFrame("Button", nil, frame)
    sortButton:SetSize(28, 28)
    sortButton:SetPoint("LEFT", searchBox, "RIGHT", 6, 0)
    sortButton:SetFrameLevel(frame:GetFrameLevel() + 31)

    local sortNormalTex = sortButton:CreateTexture(nil, "ARTWORK")
    sortNormalTex:SetTexture("Interface\\ContainerFrame\\Bags")
    sortNormalTex:SetTexCoord(0.160156250, 0.277343750, 0.578125000, 0.695312500)
    sortNormalTex:SetAllPoints(sortButton)
    sortButton:SetNormalTexture(sortNormalTex)

    local sortPushedTex = sortButton:CreateTexture(nil, "ARTWORK")
    sortPushedTex:SetTexture("Interface\\ContainerFrame\\Bags")
    sortPushedTex:SetTexCoord(0.160156250, 0.277343750, 0.468750000, 0.585937500)
    sortPushedTex:SetAllPoints(sortButton)
    sortButton:SetPushedTexture(sortPushedTex)

    local sortHighlightTex = sortButton:CreateTexture(nil, "HIGHLIGHT")
    sortHighlightTex:SetTexture("Interface\\ContainerFrame\\Bags")
    sortHighlightTex:SetTexCoord(0.160156250, 0.277343750, 0.578125000, 0.695312500)
    sortHighlightTex:SetBlendMode("ADD")
    sortHighlightTex:SetAllPoints(sortButton)
    sortButton:SetHighlightTexture(sortHighlightTex)

    sortButton:SetScript("OnClick", ContainerFrame_SortButton_OnClick)
    sortButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(CONTAINER_SORT or "Organizar objetos", 1.0, 1.0, 1.0)
    end)
    sortButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.SortButton = sortButton
    ContainerFrame_RaiseHeaderControls(frame)
	
    if frame.toggleButton then
        frame.toggleButton:SetFrameLevel(frame:GetFrameLevel() + 50)
    end

    searchBox:SetScript("OnTextChanged", function(self, isUserInput)
        local text = self:GetText()
        
        if text == "" then
            self.placeholderText:Show()
            self.clearButton:Hide()
            expandedSearchText = nil
        else
            self.placeholderText:Hide()
            self.clearButton:Show()
            expandedSearchText = text
        end
        
        RefreshExpandedBackpackIcons()
    end)
    
    searchBox:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
        if self:GetText() ~= "" then
            self.clearButton:Show()
        end
    end)
    
    searchBox:SetScript("OnEditFocusLost", function(self)
        self:HighlightText(0, 0)
        if self:GetText() == "" then
            self.clearButton:Hide()
        end
    end)
    
    searchBox:SetScript("OnEscapePressed", function(self)
        local text = self:GetText()
        
        if text and #text > 0 then
            self:SetText("")
            expandedSearchText = nil
            RefreshExpandedBackpackIcons()
        else
            self:ClearFocus()
        end
    end)
    
    placeholderText:Show()
    frame.SearchBox = searchBox
    
    return searchBox
end

function ExpandedBackpack_Init()
    if expandedBackpackFrame.itemButtons then return end

    expandedBackpackFrame.itemButtons = {}
    expandedBackpackFrame.maxButtons = MAX_COMBINED_SLOTS or 200
end

local function SafeTimer(delay, callback)
    if _G.C_Timer and _G.C_Timer.After then
        _G.C_Timer.After(delay, callback)
    else
        callback()
    end
end

function RefreshExpandedBackpackIcons()
    if not expandedBackpackFrame
       or not expandedBackpackFrame.itemContainer then
        return
    end

    ExpandedBackpack_Init()

    local container = expandedBackpackFrame.itemContainer
    local iconSize = 36
    local spacing  = 4
    local columns  = 10

    local totalRealSlots = 0
    local items = {}

    for bag = 0, NUM_BAG_FRAMES do
        local slots = GetContainerNumSlots(bag)
        if slots and slots > 0 then
            for slot = 1, slots do
                totalRealSlots = totalRealSlots + 1
                items[totalRealSlots] = bag * 1000 + slot
            end
        end
    end

    local x, y = 0, 0
    local visibleCount = 0

    for i = 1, expandedBackpackFrame.maxButtons do
        local itemButton = expandedBackpackFrame.itemButtons[i]
        if itemButton then
            itemButton:Hide()
        end
    end

    for i = 1, totalRealSlots do
        local itemButton = expandedBackpackFrame.itemButtons[i]

        if not itemButton then
            itemButton = CreateFrame(
                "Button",
                "ExpandedBackpackItem"..i,
                container
            )
            itemButton:SetSize(iconSize, iconSize)

            ContainerFrame_EnsureSlotBackground(itemButton)

            itemButton.icon = itemButton:CreateTexture(nil, "ARTWORK")
            itemButton.icon:SetAllPoints()

            ContainerFrameItemButton_OnLoad(itemButton)
            itemButton:SetScript("OnEnter", ContainerFrameItemButton_OnEnter)
            itemButton:SetScript("OnLeave", function(self)
                GameTooltip:Hide()
                ResetCursor()
            end)
            itemButton:SetScript("OnClick", function(self, button)
                local modifiedClick = IsModifiedClick()
                if modifiedClick then
                    ContainerFrameItemButton_OnModifiedClick(self, button)
                else
                    ContainerFrameItemButton_OnClick(self, button)
                end
                SafeTimer(0.1, RefreshExpandedBackpackIcons)
            end)
            itemButton:SetScript("OnDragStart", ContainerFrameItemButton_OnDrag)
            itemButton:SetScript("OnReceiveDrag", function(self)
                ContainerFrameItemButton_OnDrag(self)
                SafeTimer(0.1, RefreshExpandedBackpackIcons)
            end)

            expandedBackpackFrame.itemButtons[i] = itemButton
        end

        local row = math.floor((i - 1) / columns)
        local col = (i - 1) % columns
        x = col * (iconSize + spacing)
        y = -row * (iconSize + spacing)

        itemButton:ClearAllPoints()
        itemButton:SetPoint("TOPLEFT", x, y)

        local packed = items[i]
        local bag  = floor(packed / 1000)
        local slot = packed % 1000

        itemButton.bag  = bag
        itemButton.slot = slot

        local texture, itemCount, locked, quality, readable = GetContainerItemInfo(bag, slot)
        local isQuestItem, questId, isActive = GetContainerItemQuestInfo(bag, slot)
        local shouldShow = true

        if expandedSearchText and expandedSearchText ~= "" then
            local itemID = GetContainerItemID(bag, slot)
            if itemID then
                local itemName = GetItemInfo(itemID)
                if itemName then
                    shouldShow =
                        string.find(
                            string.upper(itemName),
                            string.upper(expandedSearchText),
                            1,
                            true
                        ) ~= nil
                else
                    shouldShow = false
                end
            else
                shouldShow = false
            end
        end

        ContainerItem_UpdateQuestTexture(itemButton, questId, isActive, isQuestItem)

        if texture then
            itemButton.icon:SetTexture(texture)
            ContainerFrame_EnsureSlotBackground(itemButton)
            itemButton.hasItem = true
            itemButton.readable = readable

            if shouldShow then
                itemButton.icon:SetVertexColor(1, 1, 1)
                itemButton.icon:SetAlpha(1)
            else
                itemButton.icon:SetVertexColor(0.3, 0.3, 0.3)
                itemButton.icon:SetAlpha(0.4)
            end

            local itemLink = GetContainerItemLink(bag, slot)
            ContainerItem_UpdateQualityBorder(itemButton, bag, slot, quality, shouldShow)
            ContainerItem_UpdateItemLevel(itemButton, bag, slot, itemLink, quality, shouldShow)

        else
            itemButton.icon:SetTexture(nil)
            ContainerFrame_EnsureSlotBackground(itemButton)
            itemButton.hasItem = false
            itemButton.readable = false
            ContainerItem_ClearQualityBorder(itemButton)
        end

        itemButton:Show()
        visibleCount = visibleCount + 1
    end

    if visibleCount > 0 then
        local rowsNeeded = math.ceil(visibleCount / columns)
        local containerHeight = rowsNeeded * (iconSize + spacing) + 10
        local containerWidth = columns * (iconSize + spacing) + 10

        if containerWidth < 100 then
            containerWidth = 100
        end
        
        container:SetWidth(containerWidth)
        container:SetHeight(containerHeight)

        if expandedBackpackFrame then
            local currentWidth = expandedBackpackFrame:GetWidth()
            local frameHeight = containerHeight + 120
            expandedBackpackFrame:SetHeight(frameHeight)

            if containerWidth + 40 > currentWidth then
                expandedBackpackFrame:SetWidth(containerWidth + 40)
            end
        end
    end

    if not expandedBackpackFrame.moneyFrame then
        local containerMoney = CreateFrame(
            "Frame",
            "ExpandedBackpackMoneyFrameContainer",
            expandedBackpackFrame
        )
        containerMoney:SetSize(250, 40)
        containerMoney:SetPoint("BOTTOM", expandedBackpackFrame, "BOTTOM", 0, 10)

        ContainerFrame_StyleMoneyPanel(containerMoney)

        local moneyFrame = CreateFrame(
            "Frame",
            "ExpandedBackpackMoneyFrame",
            containerMoney,
            "SmallMoneyFrameTemplate"
        )
        moneyFrame:SetPoint("CENTER")

        MoneyFrame_SetType(moneyFrame, "PLAYER")

        expandedBackpackFrame.moneyFrame = moneyFrame
    end

    MoneyFrame_Update(
        expandedBackpackFrame.moneyFrame:GetName(),
        GetMoney()
    )
end

local function SetupExpandedBackpackEvents()
    if expandedBackpackFrame then
        expandedBackpackFrame:RegisterEvent("BAG_UPDATE")
        expandedBackpackFrame:RegisterEvent("BAG_UPDATE_COOLDOWN")
        expandedBackpackFrame:RegisterEvent("ITEM_LOCK_CHANGED")
        
        expandedBackpackFrame:SetScript("OnEvent", function(self, event, ...)
            if event == "BAG_UPDATE" or event == "ITEM_LOCK_CHANGED" then
                RefreshExpandedBackpackIcons()
            elseif event == "BAG_UPDATE_COOLDOWN" then
                RefreshExpandedBackpackIcons()
            end
        end)
    end
end

if expandedBackpackFrame then
    SetupExpandedBackpackEvents()
end

function SwitchBackpackMode()
    isExpandedBackpack = not isExpandedBackpack
    if isExpandedBackpack then
        CloseMergedBackpackBags()
        ToggleExpandedBackpack()
    else
        if expandedBackpackFrame then
            expandedBackpackFrame:Hide()
        end
        OpenAllBags(1)
    end
end

-- ============================================================
-- HOOK PARA CREAR BUSQUEDA EN MOCHILA INDIVIDUAL
-- ============================================================
local original_ContainerFrame_GenerateFrame = ContainerFrame_GenerateFrame
function ContainerFrame_GenerateFrame(frame, size, id)
    original_ContainerFrame_GenerateFrame(frame, size, id)

    if frame.SearchBox and not frame.SearchBox.placeholderSetup then
        SetupSearchBoxPlaceholder(frame.SearchBox)
        frame.SearchBox.placeholderSetup = true
    end
end