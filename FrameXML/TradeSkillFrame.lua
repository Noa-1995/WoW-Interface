-- =====================================================
-- Noa - Custom_TradeSkill_New
-- Reemplazo completo del TradeSkillFrame de Blizzard
-- =====================================================

local FRAME_WIDTH = 700
local FRAME_HEIGHT = 510
local LIST_WIDTH = 250
local ROW_HEIGHT = 20
local VISIBLE_ROWS = 17
local MAX_REAGENTS = 8

PROFESSION_BACKGROUNDS = {
    [ALCHEMY] = "professionbackgroundartalchemy",
    [BLACKSMITHING] = "professionbackgroundartblacksmithing",
    [COOKING] = "professionbackgroundartcooking",
    [ENCHANTING] = "professionbackgroundartenchanting",
    [ENGINEERING] = "professionbackgroundartengineering",
    [FISHING] = "professionbackgroundartfishing",
    [HERBALISM] = "professionbackgroundartherbalism",
    [INSCRIPTION] = "professionbackgroundartinscription",
    [JEWELCRAFTING] = "professionbackgroundartjewelcrafting",
    [LEATHERWORKING] = "professionbackgroundartleatherworking",
    [MINING] = "professionbackgroundartmining",
    [SKINNING] = "professionbackgroundartskinning",
    [TAILORING] = "professionbackgroundarttailoring",
}

PROFESSION_ICONS = {
    [ALCHEMY] = "ui_profession_alchemy",
    [BLACKSMITHING] = "ui_profession_blacksmithing",
    [COOKING] = "ui_profession_cooking",
    [ENCHANTING] = "ui_profession_enchanting",
    [ENGINEERING] = "ui_profession_engineering",
    [FISHING] = "ui_profession_fishing",
    [HERBALISM] = "ui_profession_herbalism",
    [INSCRIPTION] = "ui_profession_inscription",
    [JEWELCRAFTING] = "ui_profession_jewelcrafting",
    [LEATHERWORKING] = "ui_profession_leatherworking",
    [MINING] = "ui_profession_mining",
    [SKINNING] = "ui_profession_skinning",
    [TAILORING] = "ui_profession_tailoring",
    [FIRST_AID] = "inv_first_aid_70_bandage",
}

local function SetProfessionBackground(frame, profession)
    if not frame or not frame.rightPanelBackground then return end
    local file = "professions-recipe-background"
    if profession and PROFESSION_BACKGROUNDS[profession] then
        file = PROFESSION_BACKGROUNDS[profession]
    end
    frame.rightPanelBackground:SetTexture("Interface\\Professions\\" .. file)
    frame.rightPanelBackground:SetTexCoord(0.000977, 0.660156, 0.000977, 0.536133)
end

local function SetProfessionIcon(portrait, profession)
    if not portrait then return end
    local icon = "Interface\\Icons\\INV_Misc_QuestionMark"
    if profession and PROFESSION_ICONS[profession] then
        icon = "Interface\\Icons\\" .. PROFESSION_ICONS[profession]
    end
    portrait:SetTexture(icon)
    portrait:SetTexCoord(0, 1, 0, 1)
end

local function SetTitle(frame, text)
    local title = frame.TitleText or _G[frame:GetName() .. "TitleText"]
    if title then title:SetText(text or "Profesión") end
end

local function CreateBackdropFrame(parent, name)
    local frame = CreateFrame("Frame", name, parent)
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = {left = 3, right = 3, top = 3, bottom = 3},
    })
    frame:SetBackdropColor(0.02, 0.02, 0.02, 0.88)
    frame:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)
    return frame
end

local function CreateText(parent, template, justify)
    local text = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
    text:SetJustifyH(justify or "LEFT")
    return text
end

local function CreateItemButton(parent, size)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(size, size)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints(button)
    button.border = button:CreateTexture(nil, "OVERLAY")
    button.border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    button.border:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.border:SetSize(size * 1.65, size * 1.65)
    button.count = CreateText(button, "NumberFontNormal", "RIGHT")
    button.count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    return button
end

local function GetResultTexture(index)
    if not index then return "Interface\\Icons\\INV_Misc_QuestionMark" end
    local icon = GetTradeSkillIcon(index)
    if icon then return icon end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function GetSelectedIndex(frame)
    if not frame or not frame.selectedRecipe then return nil end
    local total = GetNumTradeSkills() or 0
    if frame.selectedRecipe >= 1 and frame.selectedRecipe <= total then
        local _, skillType = GetTradeSkillInfo(frame.selectedRecipe)
        if skillType and skillType ~= "header" then 
            return frame.selectedRecipe 
        end
    end
    return nil
end

local function RecipeMatchesMaterials(index)
    if not index then return false end
    local numAvailable = select(3, GetTradeSkillInfo(index))
    return (tonumber(numAvailable) or 0) > 0
end

local function GetVisibleRecipes(frame)
    local recipes = {}
    local total = GetNumTradeSkills() or 0
    if total == 0 then return recipes end
    
    for index = 1, total do
        local name, skillType = GetTradeSkillInfo(index)
        if name then
            if skillType == "header" or not frame.haveMaterialsOnly or RecipeMatchesMaterials(index) then
                recipes[#recipes + 1] = index
            end
        end
    end
    return recipes
end

local function UpdateTools(frame, index)
    if not index then
        frame.toolsText:SetText("")
        frame.toolsText:Hide()
        return
    end
    
    local values = {GetTradeSkillTools(index)}
    local missing = {}
    for i = 1, #values, 2 do
        local name = values[i]
        local available = values[i + 1]
        if name and name ~= "" and not available then
            missing[#missing + 1] = name
        end
    end
    if #missing > 0 then
        frame.toolsText:SetText("Necesita: |cffff2020" .. table.concat(missing, ", ") .. "|r")
        frame.toolsText:Show()
    else
        frame.toolsText:SetText("")
        frame.toolsText:Hide()
    end
end

local function UpdateReagents(frame, index)
    if not index then
        for i = 1, MAX_REAGENTS do
            frame.reagents[i]:Hide()
            frame.reagents[i].tradeSkillIndex = nil
            frame.reagents[i].reagentIndex = nil
        end
        return
    end
    
    local count = GetTradeSkillNumReagents(index) or 0
    for slot = 1, MAX_REAGENTS do
        local reagent = frame.reagents[slot]
        if slot <= count then
            local name, texture, required, owned = GetTradeSkillReagentInfo(index, slot)
            required = tonumber(required) or 0
            owned = tonumber(owned) or 0
            reagent.tradeSkillIndex = index
            reagent.reagentIndex = slot
            reagent.icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
            reagent.name:SetText(name or "")
            if owned < required then
                reagent.amount:SetText(string.format("|cffff2020%d/%d|r", owned, required))
            else
                reagent.amount:SetText(string.format("|cff20ff20%d/%d|r", owned, required))
            end
            reagent:Show()
        else
            reagent:Hide()
            reagent.tradeSkillIndex = nil
            reagent.reagentIndex = nil
        end
    end
end

local function UpdateDetails(frame)
    local index = GetSelectedIndex(frame)
    if not index then
        frame.resultButton:Hide()
        frame.resultName:SetText("Selecciona una receta")
        frame.toolsText:Hide()
        frame.componentsLabel:Hide()
        for i = 1, MAX_REAGENTS do frame.reagents[i]:Hide() end
        frame.createButton:Disable()
        frame.createAllButton:Disable()
        return
    end

    local name, _, numAvailable, _, _, altVerb = GetTradeSkillInfo(index)
    if not name then
        frame.resultButton:Hide()
        frame.resultName:SetText("Error al cargar receta")
        frame.toolsText:Hide()
        frame.componentsLabel:Hide()
        for i = 1, MAX_REAGENTS do frame.reagents[i]:Hide() end
        frame.createButton:Disable()
        frame.createAllButton:Disable()
        return
    end
    
    frame.resultButton.tradeSkillIndex = index
    frame.resultButton.icon:SetTexture(GetResultTexture(index))
    frame.resultButton:Show()
    frame.resultName:SetText(name or "")
    frame.componentsLabel:Show()
    UpdateTools(frame, index)
    UpdateReagents(frame, index)

    local available = tonumber(numAvailable) or 0
    local requested = tonumber(frame.quantityBox:GetText()) or 1
    if requested < 1 then requested = 1 end
    if available > 0 then
        frame.createButton:Enable()
        frame.createAllButton:Enable()
    else
        frame.createButton:Disable()
        frame.createAllButton:Disable()
    end
    frame.createButton:SetText(altVerb or CREATE or "Crear")
end

local function UpdateRecipeList(frame)
    local recipes = GetVisibleRecipes(frame)
    if #recipes == 0 and frame.visibleRecipes and #frame.visibleRecipes > 0 and GetTradeSkillLine() then
        return
    end
    frame.visibleRecipes = recipes
    
    if not frame.selectedRecipe or not GetSelectedIndex(frame) then
        frame.selectedRecipe = nil
        for _, idx in ipairs(frame.visibleRecipes) do
            local _, skillType = GetTradeSkillInfo(idx)
            if skillType and skillType ~= "header" then
                frame.selectedRecipe = idx
                break
            end
        end
    end
    
    local total = #frame.visibleRecipes
    FauxScrollFrame_Update(frame.recipeScroll, total, VISIBLE_ROWS, ROW_HEIGHT)
    local offset = FauxScrollFrame_GetOffset(frame.recipeScroll) or 0

    for rowIndex = 1, VISIBLE_ROWS do
        local row = frame.recipeRows[rowIndex]
        local mapped = frame.visibleRecipes[offset + rowIndex]
        if mapped then
            local name, skillType, numAvailable, isExpanded = GetTradeSkillInfo(mapped)
            if name then
                row.tradeSkillIndex = mapped
                row.text:ClearAllPoints()
                if skillType == "header" then
                    row.text:SetPoint("LEFT", row, "LEFT", 22, 0)
                    row.text:SetText(name or "")
                    row.text:SetTextColor(1, 0.82, 0)
                    row.expand:SetNormalTexture(isExpanded and "Interface\\Buttons\\UI-MinusButton-Up" or "Interface\\Buttons\\UI-PlusButton-Up")
                    row.expand:Show()
                    row.count:SetText("")
                else
                    row.text:SetPoint("LEFT", row, "LEFT", 9, 0)
                    row.text:SetText(name or "")
                    row.expand:Hide()
                    local color = TradeSkillTypeColor and TradeSkillTypeColor[skillType]
                    if color then row.text:SetTextColor(color.r, color.g, color.b) else row.text:SetTextColor(1, 1, 1) end
                    row.count:SetText((tonumber(numAvailable) or 0) > 0 and tostring(numAvailable) or "")
                end
                if mapped == frame.selectedRecipe then
                    row.highlight:Show()
                else
                    row.highlight:Hide()
                end
                row:Show()
            else
                row:Hide()
                row.tradeSkillIndex = nil
            end
        else
            row:Hide()
            row.tradeSkillIndex = nil
        end
    end
end

local updating = false

function CustomTradeSkillNew_Update(frame)
    if not frame or not frame:IsShown() then return end
    if updating then return end
    updating = true
    
    local profession, rank, maxRank = GetTradeSkillLine()
    
    -- Actualizar fondo profesional y icono
    SetProfessionBackground(frame, profession)
    SetProfessionIcon(frame.professionIcon, profession)
    
    if not frame.filtersReady and profession and profession ~= "" then
        frame.filtersReady = true
        frame.InitTradeSkillFilters()
    end
	
    local titleText = _G["CustomTradeSkillNewFrameTitleText"]
    if titleText then
        if TRADE_SKILL_TITLE then
            titleText:SetFormattedText(TRADE_SKILL_TITLE, profession)
        else
            titleText:SetText(profession)
        end
    end
    
    if frame.skillBar then
        frame.skillBar:SetMinMaxValues(0, math.max(tonumber(maxRank) or 1, 1))
        frame.skillBar:SetValue(tonumber(rank) or 0)
        frame.skillBarText:SetText(string.format("%d/%d", tonumber(rank) or 0, tonumber(maxRank) or 0))
    end
    
    UpdateRecipeList(frame)
    UpdateDetails(frame)
    
    updating = false
end

local function SelectRecipe(frame, index)
    if not index then return end
    local _, skillType, _, isExpanded = GetTradeSkillInfo(index)
    if not skillType then return end
    
    if skillType == "header" then
        if isExpanded then 
            CollapseTradeSkillSubClass(index) 
        else 
            ExpandTradeSkillSubClass(index) 
        end
        CustomTradeSkillNew_Update(frame)
    else
        frame.selectedRecipe = index
        SelectTradeSkill(index)
        CustomTradeSkillNew_Update(frame)
    end
end

function TradeSkillFrame_LoadUI()
    -- No hacer nada - esto evita que Blizzard cargue su UI
end

function TradeSkillFrame_Show()
    -- Mostrar nuestro frame personalizado usando ShowUIPanel
    if not CustomTradeSkillNewFrame:IsShown() then
        ShowUIPanel(CustomTradeSkillNewFrame);
    end
    CustomTradeSkillNew_Update(CustomTradeSkillNewFrame)
end

function TradeSkillFrame_Hide()
    HideUIPanel(CustomTradeSkillNewFrame);
end

local function BuildInterface(frame)
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:SetClampedToScreen(true)
    frame:SetMovable(false)

    frame.professionIcon = frame:CreateTexture(nil, "ARTWORK")
    frame.professionIcon:SetPoint("TOPLEFT", frame, "TOPLEFT", -5, 5)
    frame.professionIcon:SetSize(58, 58)
    frame.professionIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")

    frame.skillBarContainer = CreateFrame("Frame", nil, frame)
    frame.skillBarContainer:SetPoint("TOP", frame, "TOP", 0, -34)
    frame.skillBarContainer:SetSize(394, 21)

    frame.skillBarContainer:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
        insets = {left = 4, right = 4, top = 4, bottom = 4},
    })
    frame.skillBarContainer:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)

    frame.skillBar = CreateFrame("StatusBar", nil, frame.skillBarContainer)
    frame.skillBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    frame.skillBar:SetStatusBarColor(0.25, 0.25, 0.8)
    frame.skillBar:SetPoint("TOPLEFT", frame.skillBarContainer, "TOPLEFT", 4, -4)
    frame.skillBar:SetPoint("BOTTOMRIGHT", frame.skillBarContainer, "BOTTOMRIGHT", -4, 4)
    frame.skillBar:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        tile = true, tileSize = 16,
        insets = {left = 2, right = 2, top = 2, bottom = 2},
    })
    frame.skillBar:SetBackdropColor(0, 0, 0, 0.95)
    
    frame.skillBarText = CreateText(frame.skillBar, "GameFontHighlightSmall", "CENTER")
    frame.skillBarText:SetPoint("CENTER")

    frame.haveMaterials = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    frame.haveMaterials:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -57)
    frame.haveMaterials:SetSize(24, 24)
    frame.haveMaterials.text = CreateText(frame.haveMaterials, "GameFontNormalSmall")
    frame.haveMaterials.text:SetPoint("LEFT", frame.haveMaterials, "RIGHT", 2, 0)
    frame.haveMaterials.text:SetText("Tengo materiales")
    frame.haveMaterials:SetScript("OnClick", function(self)
        frame.haveMaterialsOnly = self:GetChecked() and true or false
        frame.recipeScroll:SetVerticalScroll(0)
        FauxScrollFrame_SetOffset(frame.recipeScroll, 0)
        CustomTradeSkillNew_Update(frame)
    end)

    frame.invSlotDropDown = CreateFrame("Frame", "CustomTradeSkillNewInvSlotDropDown", frame, "UIDropDownMenuTemplate")
    frame.invSlotDropDown:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -20, -54)

    frame.subClassDropDown = CreateFrame("Frame", "CustomTradeSkillNewSubClassDropDown", frame, "UIDropDownMenuTemplate")
    frame.subClassDropDown:SetPoint("RIGHT", frame.invSlotDropDown, "LEFT", 35, 0)

    local function FilterInvSlotName(...)
        for i = 1, select("#", ...) do
            if GetTradeSkillInvSlotFilter(i) then return select(i, ...) end
        end
    end

    local function RefreshFilteredList()
        frame.recipeScroll:SetVerticalScroll(0)
        FauxScrollFrame_SetOffset(frame.recipeScroll, 0)
        CustomTradeSkillNew_Update(frame)
    end

    local function InvSlotDropDownButton_OnClick(self)
        UIDropDownMenu_SetSelectedID(frame.invSlotDropDown, self:GetID())
        SetTradeSkillInvSlotFilter(self:GetID() - 1, 1, 1)
        frame.invSlotSelected = FilterInvSlotName(GetTradeSkillInvSlots())
        RefreshFilteredList()
    end

    local function LoadInvSlots(...)
        UIDropDownMenu_SetSelectedID(frame.invSlotDropDown, nil)
        local allChecked = GetTradeSkillInvSlotFilter(0)
        local filterCount = select("#", ...)
        local info = UIDropDownMenu_CreateInfo()
        info.text = ALL_INVENTORY_SLOTS
        info.func = InvSlotDropDownButton_OnClick
        info.checked = allChecked
        UIDropDownMenu_AddButton(info)
        for i = 1, filterCount do
            local checked
            if allChecked and filterCount > 1 then
                checked = nil
                UIDropDownMenu_SetText(frame.invSlotDropDown, ALL_INVENTORY_SLOTS)
            else
                checked = GetTradeSkillInvSlotFilter(i)
                if checked then UIDropDownMenu_SetText(frame.invSlotDropDown, (select(i, ...))) end
            end
            info.text = select(i, ...)
            info.func = InvSlotDropDownButton_OnClick
            info.checked = checked
            UIDropDownMenu_AddButton(info)
        end
    end

    local function SubClassDropDownButton_OnClick(self)
        UIDropDownMenu_SetSelectedID(frame.subClassDropDown, self:GetID())
        SetTradeSkillSubClassFilter(self:GetID() - 1, 1, 1)
        if self:GetID() ~= 1 then
            if FilterInvSlotName(GetTradeSkillInvSlots()) ~= frame.invSlotSelected then
                SetTradeSkillInvSlotFilter(0, 1, 1)
                UIDropDownMenu_SetSelectedID(frame.invSlotDropDown, 1)
                UIDropDownMenu_SetText(frame.invSlotDropDown, ALL_INVENTORY_SLOTS)
            end
        end
        RefreshFilteredList()
    end

    local function LoadSubClasses(...)
        local selectedID = UIDropDownMenu_GetSelectedID(frame.subClassDropDown)
        local allChecked = GetTradeSkillSubClassFilter(0)
        local info = UIDropDownMenu_CreateInfo()
        info.text = ALL_SUBCLASSES
        info.func = SubClassDropDownButton_OnClick
        info.checked = allChecked and (selectedID == nil or selectedID == 1)
        UIDropDownMenu_AddButton(info)
        if info.checked then UIDropDownMenu_SetText(frame.subClassDropDown, ALL_SUBCLASSES) end
        for i = 1, select("#", ...) do
            local checked
            if allChecked then
                checked = nil
            else
                checked = GetTradeSkillSubClassFilter(i)
                if checked then UIDropDownMenu_SetText(frame.subClassDropDown, (select(i, ...))) end
            end
            info.text = select(i, ...)
            info.func = SubClassDropDownButton_OnClick
            info.checked = checked
            UIDropDownMenu_AddButton(info)
        end
    end

    frame.InitTradeSkillFilters = function()
        UIDropDownMenu_Initialize(frame.subClassDropDown, function() LoadSubClasses(GetTradeSkillSubClasses()) end)
        UIDropDownMenu_SetWidth(frame.subClassDropDown, 120)
        UIDropDownMenu_SetSelectedID(frame.subClassDropDown, 1)
        SetTradeSkillSubClassFilter(0, 1, 1)

        UIDropDownMenu_Initialize(frame.invSlotDropDown, function() LoadInvSlots(GetTradeSkillInvSlots()) end)
        UIDropDownMenu_SetWidth(frame.invSlotDropDown, 120)
        UIDropDownMenu_SetSelectedID(frame.invSlotDropDown, 1)
        SetTradeSkillInvSlotFilter(0, 1, 1)
    end

    frame.leftPanel = CreateFrame("Frame", nil, frame)
    frame.leftPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -82)
    frame.leftPanel:SetSize(LIST_WIDTH, 385)
    frame.leftPanel:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = {left = 3, right = 3, top = 3, bottom = 3},
    })
    frame.leftPanel:SetBackdropColor(0.02, 0.02, 0.02, 0.88)
    frame.leftPanel:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)

    frame.leftPanelBackground = frame.leftPanel:CreateTexture(nil, "BACKGROUND")
    frame.leftPanelBackground:SetAllPoints(frame.leftPanel)
    frame.leftPanelBackground:SetTexture("Interface\\Professions\\craftingorders")
    frame.leftPanelBackground:SetTexCoord(0.000000000, 0.156000000, 0.000000000, 0.914000000)
    frame.leftPanelBackground:SetDrawLayer("BACKGROUND", -1)

    frame.rightPanel = CreateFrame("Frame", nil, frame)
    frame.rightPanel:SetPoint("TOPLEFT", frame.leftPanel, "TOPRIGHT", 10, 0)
    frame.rightPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 43)

    frame.rightPanelBackground = frame.rightPanel:CreateTexture(nil, "BACKGROUND")
    frame.rightPanelBackground:SetAllPoints(frame.rightPanel)
    frame.rightPanelBackground:SetTexture("Interface\\Professions\\professions-recipe-background")
    frame.rightPanelBackground:SetTexCoord(0.000977, 0.660156, 0.000977, 0.536133)

    local rightBorder = CreateFrame("Frame", nil, frame.rightPanel)
    rightBorder:SetAllPoints(frame.rightPanel)
    rightBorder:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = {left = 3, right = 3, top = 3, bottom = 3},
    })
    rightBorder:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)
    rightBorder:SetFrameLevel(frame.rightPanel:GetFrameLevel() + 1)

    frame.recipeRows = {}
    for i = 1, VISIBLE_ROWS do
        local row = CreateFrame("Button", nil, frame.leftPanel)
        row:SetPoint("TOPLEFT", frame.leftPanel, "TOPLEFT", 6, -6 - (i - 1) * ROW_HEIGHT)
        row:SetSize(LIST_WIDTH - 28, ROW_HEIGHT)
        row.highlight = row:CreateTexture(nil, "BACKGROUND")
        row.highlight:SetAllPoints(row)
        row.highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        row.highlight:SetBlendMode("ADD")
        row.highlight:Hide()
        row.expand = CreateFrame("Button", nil, row)
        row.expand:SetPoint("LEFT", row, "LEFT", 1, 0)
        row.expand:SetSize(16, 16)
        row.expand:SetScript("OnClick", function() SelectRecipe(frame, row.tradeSkillIndex) end)
        row.text = CreateText(row, "GameFontNormalSmall")
        row.text:SetPoint("RIGHT", row, "RIGHT", -35, 0)
        row.text:SetHeight(ROW_HEIGHT)
        row.count = CreateText(row, "GameFontHighlightSmall", "RIGHT")
        row.count:SetPoint("RIGHT", row, "RIGHT", -3, 0)
        row:SetScript("OnClick", function() SelectRecipe(frame, row.tradeSkillIndex) end)
        row:SetScript("OnEnter", function()
            if row.tradeSkillIndex then
                local _, skillType = GetTradeSkillInfo(row.tradeSkillIndex)
                if skillType and skillType ~= "header" then
                    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
                    GameTooltip:SetTradeSkillItem(row.tradeSkillIndex)
                end
            end
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        frame.recipeRows[i] = row
    end

    frame.recipeScroll = CreateFrame("ScrollFrame", "CustomTradeSkillNewRecipeScroll", frame.leftPanel, "FauxScrollFrameTemplate")
    frame.recipeScroll:SetPoint("TOPLEFT", frame.leftPanel, "TOPLEFT", 4, -5)
    frame.recipeScroll:SetPoint("BOTTOMRIGHT", frame.leftPanel, "BOTTOMRIGHT", -25, 5)
    frame.recipeScroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, function() UpdateRecipeList(frame) end)
    end)

    frame.resultButton = CreateItemButton(frame.rightPanel, 44)
    frame.resultButton:SetPoint("TOPLEFT", frame.rightPanel, "TOPLEFT", 18, -22)
    frame.resultButton:SetScript("OnEnter", function(self)
        if self.tradeSkillIndex then
            local _, skillType = GetTradeSkillInfo(self.tradeSkillIndex)
            if skillType and skillType ~= "header" then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetTradeSkillItem(self.tradeSkillIndex)
           end
        end
    end)
    frame.resultButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.resultButton:SetScript("OnClick", function(self, button)
        if button == "LeftButton" and IsShiftKeyDown() then
            local index = self.tradeSkillIndex
            if index then
                local link = GetTradeSkillItemLink(index)
                if link then
                    ChatEdit_InsertLink(link)
                end
            end
        end
    end)

    frame.resultName = CreateText(frame.rightPanel, "GameFontNormalLarge")
    frame.resultName:SetPoint("TOPLEFT", frame.resultButton, "TOPRIGHT", 12, -2)
    frame.resultName:SetPoint("RIGHT", frame.rightPanel, "RIGHT", -14, 0)
    frame.resultName:SetHeight(24)

    frame.toolsText = CreateText(frame.rightPanel, "GameFontHighlightSmall")
    frame.toolsText:SetPoint("TOPLEFT", frame.resultName, "BOTTOMLEFT", 0, -4)
    frame.toolsText:SetPoint("RIGHT", frame.rightPanel, "RIGHT", -12, 0)

    frame.componentsLabel = CreateText(frame.rightPanel, "GameFontNormal")
    frame.componentsLabel:SetPoint("TOPLEFT", frame.rightPanel, "TOPLEFT", 18, -88)
    frame.componentsLabel:SetText(SPELL_REAGENTS)

    frame.reagents = {}
    for i = 1, MAX_REAGENTS do
        local reagent = CreateFrame("Button", nil, frame.rightPanel)
        local column = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        reagent:SetPoint("TOPLEFT", frame.rightPanel, "TOPLEFT", 18 + column * 170, -112 - row * 58)
        reagent:SetSize(158, 48)
        reagent.item = CreateItemButton(reagent, 36)
        reagent.item:SetPoint("LEFT", reagent, "LEFT", 0, 0)
        reagent.icon = reagent.item.icon
        reagent.name = CreateText(reagent, "GameFontHighlightSmall")
        reagent.name:SetPoint("TOPLEFT", reagent.item, "TOPRIGHT", 8, -2)
        reagent.name:SetPoint("RIGHT", reagent, "RIGHT", 0, 0)
        reagent.name:SetHeight(28)
        reagent.amount = CreateText(reagent, "GameFontHighlightSmall")
        reagent.amount:SetPoint("BOTTOMLEFT", reagent.item, "BOTTOMRIGHT", 8, 2)
        reagent:SetScript("OnEnter", function(self)
            if self.tradeSkillIndex and self.reagentIndex then
                local _, skillType = GetTradeSkillInfo(self.tradeSkillIndex)
                if skillType and skillType ~= "header" then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetTradeSkillItem(self.tradeSkillIndex, self.reagentIndex)
                end
            end
        end)
        reagent:SetScript("OnLeave", function() GameTooltip:Hide() end)
        frame.reagents[i] = reagent
        reagent:SetScript("OnClick", function(self, button)
            if button == "LeftButton" and IsShiftKeyDown() then
                if self.tradeSkillIndex and self.reagentIndex then
                    local link = GetTradeSkillReagentItemLink(self.tradeSkillIndex, self.reagentIndex)
                    if link then
                        ChatEdit_InsertLink(link)
                    end
               end
            end
        end)
    end

    frame.createAllButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.createAllButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -215, 13)
    frame.createAllButton:SetSize(105, 24)
    frame.createAllButton:SetText(CREATE_ALL or "Crear todos")
    frame.createAllButton:SetScript("OnClick", function()
        local index = GetSelectedIndex(frame)
        if not index then return end
        local available = tonumber(select(3, GetTradeSkillInfo(index))) or 0
        if available > 0 then DoTradeSkill(index, available) end
    end)

    frame.quantityDown = CreateFrame("Button", nil, frame)
    frame.quantityDown:SetPoint("LEFT", frame.createAllButton, "RIGHT", 6, 0)
    frame.quantityDown:SetSize(23, 22)
    frame.quantityDown:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
    frame.quantityDown:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
    frame.quantityDown:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Disabled")
    frame.quantityDown:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")

    frame.quantityBox = CreateFrame("EditBox", nil, frame)
    frame.quantityBox:SetPoint("LEFT", frame.quantityDown, "RIGHT", 6, 0)
    frame.quantityBox:SetSize(30, 20)
    frame.quantityBox:SetAutoFocus(false)
    frame.quantityBox:SetNumeric(true)
    frame.quantityBox:SetMaxLetters(3)
    frame.quantityBox:SetJustifyH("CENTER")
    frame.quantityBox:SetFontObject("ChatFontNormal")
    frame.quantityBox:SetText("1")
    frame.quantityBox:SetScript("OnEnterPressed", EditBox_ClearFocus)
    frame.quantityBox:SetScript("OnEscapePressed", EditBox_ClearFocus)
    frame.quantityBox:SetScript("OnTextChanged", function(self)
        if self:GetText() == "0" then self:SetText("1") end
    end)

    local qtyBgLeft = frame.quantityBox:CreateTexture(nil, "BACKGROUND")
    qtyBgLeft:SetTexture("Interface\\Common\\Common-Input-Border")
    qtyBgLeft:SetSize(8, 20)
    qtyBgLeft:SetPoint("TOPLEFT", frame.quantityBox, "TOPLEFT", -5, 0)
    qtyBgLeft:SetTexCoord(0, 0.0625, 0, 0.625)

    local qtyBgRight = frame.quantityBox:CreateTexture(nil, "BACKGROUND")
    qtyBgRight:SetTexture("Interface\\Common\\Common-Input-Border")
    qtyBgRight:SetSize(8, 20)
    qtyBgRight:SetPoint("TOPRIGHT", frame.quantityBox, "TOPRIGHT", 5, 0)
    qtyBgRight:SetTexCoord(0.9375, 1.0, 0, 0.625)

    local qtyBgMiddle = frame.quantityBox:CreateTexture(nil, "BACKGROUND")
    qtyBgMiddle:SetTexture("Interface\\Common\\Common-Input-Border")
    qtyBgMiddle:SetHeight(20)
    qtyBgMiddle:SetPoint("LEFT", qtyBgLeft, "RIGHT", 0, 0)
    qtyBgMiddle:SetPoint("RIGHT", qtyBgRight, "LEFT", 0, 0)
    qtyBgMiddle:SetTexCoord(0.0625, 0.9375, 0, 0.625)

    frame.quantityUp = CreateFrame("Button", nil, frame)
    frame.quantityUp:SetPoint("LEFT", frame.quantityBox, "RIGHT", 8, 0)
    frame.quantityUp:SetSize(23, 22)
    frame.quantityUp:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    frame.quantityUp:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
    frame.quantityUp:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Disabled")
    frame.quantityUp:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")

    local function ChangeQuantity(delta)
        local value = tonumber(frame.quantityBox:GetText()) or 1
        value = math.max(1, value + delta)
        local index = GetSelectedIndex(frame)
        if index then
            local available = tonumber(select(3, GetTradeSkillInfo(index))) or 0
            if available > 0 then value = math.min(value, available) end
        end
        frame.quantityBox:SetText(value)
    end
    frame.quantityDown:SetScript("OnClick", function() ChangeQuantity(-1); frame.quantityBox:ClearFocus() end)
    frame.quantityUp:SetScript("OnClick", function() ChangeQuantity(1); frame.quantityBox:ClearFocus() end)

    frame.createButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.createButton:SetPoint("LEFT", frame.quantityUp, "RIGHT", 8, 0)
    frame.createButton:SetSize(90, 24)
    frame.createButton:SetText(CREATE or "Crear")
    frame.createButton:SetScript("OnClick", function()
        local index = GetSelectedIndex(frame)
        if index then DoTradeSkill(index, math.max(1, tonumber(frame.quantityBox:GetText()) or 1)) end
    end)

    frame.closeButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.closeButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 13, 13)
    frame.closeButton:SetSize(90, 24)
    frame.closeButton:SetText(CLOSE or "Cerrar")
    frame.closeButton:SetScript("OnClick", function()
        if CloseTradeSkill then CloseTradeSkill() end
        HideUIPanel(frame)
    end)

    local inheritedClose = frame.CloseButton or _G[frame:GetName() .. "CloseButton"]
    if inheritedClose then
        inheritedClose:SetScript("OnClick", function()
            if CloseTradeSkill then CloseTradeSkill() end
            HideUIPanel(frame)
        end)
    end
end

local bagUpdatePending = false
local bagUpdateElapsed = 0
local bagUpdateThrottle = CreateFrame("Frame")

local function ScheduleBagUpdate(frame)
    bagUpdatePending = true
    bagUpdateElapsed = 0
    bagUpdateThrottle:SetScript("OnUpdate", function(self, elapsed)
        bagUpdateElapsed = bagUpdateElapsed + elapsed
        if bagUpdateElapsed >= 0.3 then
            self:SetScript("OnUpdate", nil)
            bagUpdatePending = false
            if frame:IsShown() then
                CustomTradeSkillNew_Update(frame)
            end
        end
    end)
end

function CustomTradeSkillNew_OnLoad(self)
    BuildInterface(self)
    self.haveMaterialsOnly = false
    self.selectedRecipe = nil
    self:RegisterEvent("TRADE_SKILL_SHOW")
    self:RegisterEvent("TRADE_SKILL_CLOSE")
end

function CustomTradeSkillNew_OnShow(self)
    self.selectedRecipe = nil
    self:RegisterEvent("TRADE_SKILL_UPDATE")
    self:RegisterEvent("BAG_UPDATE")
    self:RegisterEvent("LEARNED_SPELL_IN_TAB")
    CustomTradeSkillNew_Update(self)
end

function CustomTradeSkillNew_OnHide(self)
    self:UnregisterEvent("TRADE_SKILL_UPDATE")
    self:UnregisterEvent("BAG_UPDATE")
    self:UnregisterEvent("LEARNED_SPELL_IN_TAB")
    bagUpdateThrottle:SetScript("OnUpdate", nil)
    bagUpdatePending = false
    GameTooltip:Hide()
end

function CustomTradeSkillNew_OnEvent(self, event)
    if event == "TRADE_SKILL_SHOW" then
        if TradeSkillFrame and TradeSkillFrame ~= self then 
            TradeSkillFrame:Hide() 
        end
        if not self:IsShown() then
            ShowUIPanel(self)
        end
        CustomTradeSkillNew_Update(self)
    elseif event == "TRADE_SKILL_CLOSE" then
        HideUIPanel(self)
    elseif event == "BAG_UPDATE" then
        if self:IsShown() then 
            ScheduleBagUpdate(self) 
        end
    elseif event == "LEARNED_SPELL_IN_TAB" then
        if self:IsShown() then
            self.filtersReady = false
            CustomTradeSkillNew_Update(self)
        end
    elseif self:IsShown() then
        CustomTradeSkillNew_Update(self)
    end
end