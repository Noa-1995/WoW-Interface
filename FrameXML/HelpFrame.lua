-- global data
HELPFRAME_BULLET_SPACING = -3;
HELPFRAME_SECTION_SPACING = -20;
GMTICKET_CHECK_INTERVAL = 600;		-- 10 Minutes

HELPFRAME_START_PAGE = "KBase";

-- CONSTANTS para Knowledge Base
KBASE_NUM_ARTICLES_PER_PAGE = 20;
KBASE_TOOLTIP_DELAY = .7;
KBASE_SEARCH_BUTTON_DELAY = 1;

-- Internal variables
KBASE_CURRENT_PAGE = 1;
KBASE_SEARCH_PERFORMED = 0;
KBASE_SETUP_LOADED = 0;
KBASE_ENABLE_SEARCH = 1;

-- local data

-- helpFrames contains the names of all the frames that can go into the frameStack
local helpFrames = {
	["KBase"] = "KnowledgeBaseFrame",
};

local HelpPanelURLPopup;

local function HelpPanel_CreateURLPopup()
	if HelpPanelURLPopup then
		return HelpPanelURLPopup;
	end

	local f = CreateFrame("Frame", "HelpPanelURLPopup", UIParent);
	f:SetSize(460, 140);
	f:SetPoint("CENTER");
	f:SetFrameStrata("DIALOG");
	f:Hide();

	f:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\border-tooltip-Noa",
		tile = true, tileSize = 32, edgeSize = 32,
		insets = { left = 11, right = 11, top = 11, bottom = 11 },
	});
	f:SetBackdropColor(0, 0, 0, 0.95);
	
	local closeButton = CreateFrame("Button", nil, f, "UIPanelCloseButton");
	closeButton:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -12);
	closeButton:SetScript("OnClick", function()
		f:Hide();
	end);

	local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
	title:SetPoint("TOP", f, "TOP", 0, -16);
	title:SetText(HELPFRAME_OPEN_SERVER_URL_TEXT);

	local bg = CreateFrame("Frame", nil, f);
	bg:SetPoint("TOPLEFT", f, "TOPLEFT", 24, -42);
	bg:SetPoint("TOPRIGHT", f, "TOPRIGHT", -24, -42);
	bg:SetHeight(32);
	bg:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\border-tooltip-Noa",
		tile = true, tileSize = 16, edgeSize = 16,
		insets = { left = 6, right = 6, top = 6, bottom = 6 },
	});
	bg:SetBackdropColor(0.05, 0.05, 0.05, 1);

	local eb = CreateFrame("EditBox", nil, bg);
	eb:SetPoint("TOPLEFT", bg, "TOPLEFT", 10, -6);
	eb:SetPoint("BOTTOMRIGHT", bg, "BOTTOMRIGHT", -10, 6);
	eb:SetFontObject("ChatFontNormal");
	eb:SetAutoFocus(false);
	eb:SetJustifyH("LEFT");

	local function SelectURL()
		eb:SetText(f.pendingURL or "");
		eb:SetFocus();
		eb:HighlightText();
		eb:SetCursorPosition(0);
	end

	-- Solo lectura: si intentan escribir, restaura el enlace
	eb:SetScript("OnTextChanged", function(self, userInput)
		if self._restoring then return; end
		if userInput then
			self._restoring = true;
			self:SetText(f.pendingURL or "");
			self._restoring = nil;
			self:SetFocus();
			self:HighlightText();
			self:SetCursorPosition(0);
		end
	end);

	-- Seleccionar al hacer click
	eb:SetScript("OnMouseUp", function()
		SelectURL();
	end);

	-- Enter = seleccionar otra vez
	eb:SetScript("OnEnterPressed", function()
		SelectURL();
	end);

	-- Esc = cerrar
	eb:SetScript("OnEscapePressed", function()
		f:Hide();
	end);

	local close = CreateFrame("Button", nil, f, "GameMenuButtonTemplate");
	close:SetSize(140, 26);
	close:SetPoint("BOTTOM", f, "BOTTOM", 0, 18);
	close:SetText(CALENDAR_COPY_EVENT);
	close:SetScript("OnClick", function()
		SelectURL();
		DEFAULT_CHAT_FRAME:AddMessage(URL_TEXT_INF);
	end);

	f.editBox = eb;
	f.inputBG = bg;
	f.SelectURL = SelectURL;

	f:SetScript("OnShow", function(self)
		self.editBox:SetText(self.pendingURL or "");
		self:SelectURL();
	end);

	HelpPanelURLPopup = f;
	return f;
end

local function HelpPanel_ShowURLPopup(url)
	local popup = HelpPanel_CreateURLPopup();
	popup.pendingURL = url or "";
	popup:Show();
end

-- openFrame is the current help frame that a player has opened.
local openFrame;
local frameStack = { };

local refreshTime;
local ticketQueueActive = true;

local haveTicket = false;		-- true if the server tells us we have an open ticket
local haveResponse = false;		-- true if we got a GM response to a previous ticket
local needResponse = true;		-- true if we want a GM to contact us when we open a new ticket

local KnowledgeBaseFrame_UpdateMotd
local KnowledgeBaseFrame_UpdateServerMessage

local TicketState;
do
	local dirty = false;
	local callback = nil;  -- se asigna en runtime desde MarkDirty
	local ticker = CreateFrame("Frame");
	ticker:Hide();
	ticker:SetScript("OnUpdate", function()
		if dirty then
			dirty = false;
			ticker:Hide();
			if callback then callback(); end
		end
	end);
	TicketState = {
		MarkDirty = function(fn)
			-- fn solo se pasa la primera vez para registrar la callback
			if fn then callback = fn; end
			if not dirty then
				dirty = true;
				ticker:Show();
			end
		end,
	};
end

-- Configuración de iconos para botones usando el Atlas
local KnowledgeBaseButtonIcons = {
    ["KnowledgeBaseFrameInfo"] = "HelpSidebar-Icon-KnowledgeBase",
    ["KnowledgeBaseFrameLag"] = "HelpSidebar-Icon-CharacterStuck",
    ["KnowledgeBaseFrameRed"] = "HelpSidebar-Icon-Contacts",
    ["KnowledgeBaseFrameGMTalk"] = "HelpSidebar-Icon-OpenTicket",
    ["KnowledgeBaseFrameStuck"] = "HelpSidebar-Icon-Support",
}

--- Función para obtener coordenadas del atlas
local function GetAtlasCoords(atlasName)
    if N_ATLAS_STORAGE and N_ATLAS_STORAGE[atlasName] then
        local data = N_ATLAS_STORAGE[atlasName]
        local _, _, left, right, top, bottom, _, _, texturePath = unpack(data)
        return left, right, top, bottom, texturePath
    end
    return nil
end

-- Función única para configurar botones con atlas
function KnowledgeBaseButton_OnLoad(self, iconAtlas)
    local buttonText = self:GetText()

    local normalTex = self:CreateTexture(self:GetName() .. "Normal", "BACKGROUND")
    normalTex:SetAllPoints()
    self:SetNormalTexture(normalTex)

    local pushedTex = self:CreateTexture(self:GetName() .. "Pushed", "BACKGROUND")
    pushedTex:SetAllPoints()
    pushedTex:Hide()
    self:SetPushedTexture(pushedTex)

    local disabledTex = self:CreateTexture(self:GetName() .. "Disabled", "BACKGROUND")
    disabledTex:SetAllPoints()
    disabledTex:Hide()
    self:SetDisabledTexture(disabledTex)

    local highlightTex = self:CreateTexture(self:GetName() .. "Highlight", "HIGHLIGHT")
    highlightTex:SetAllPoints()
    highlightTex:SetBlendMode("ADD")
    highlightTex:Hide()
    self:SetHighlightTexture(highlightTex)

    local left, right, top, bottom, texturePath = GetAtlasCoords("HelpSidebar-Button-Normal")
    if texturePath then
        normalTex:SetTexture(texturePath)
        normalTex:SetTexCoord(left, right, top, bottom)
    end
    
    left, right, top, bottom, texturePath = GetAtlasCoords("HelpSidebar-Button-Pushed")
    if texturePath then
        pushedTex:SetTexture(texturePath)
        pushedTex:SetTexCoord(left, right, top, bottom)
    end
    
    left, right, top, bottom, texturePath = GetAtlasCoords("HelpSidebar-Button-Disabled")
    if texturePath then
        disabledTex:SetTexture(texturePath)
        disabledTex:SetTexCoord(left, right, top, bottom)
    end
    
    left, right, top, bottom, texturePath = GetAtlasCoords("HelpSidebar-Button-Highlight")
    if texturePath then
        highlightTex:SetTexture(texturePath)
        highlightTex:SetTexCoord(left, right, top, bottom)
    end

    local icon
    if iconAtlas then
        left, right, top, bottom, texturePath = GetAtlasCoords(iconAtlas)
        if texturePath then
            icon = self:CreateTexture(self:GetName() .. "Icon", "OVERLAY")
            icon:SetSize(28, 28)
            icon:SetPoint("LEFT", 12, 0)
            icon:SetTexture(texturePath)
            icon:SetTexCoord(left, right, top, bottom)
        end
    end

    local text = self:CreateFontString(self:GetName() .. "Text", "OVERLAY", "GameFontNormal")
    text:SetJustifyH("LEFT")
    text:SetJustifyV("MIDDLE")
    text:SetText(buttonText or self:GetName())

    if icon then
        text:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    else
        text:SetPoint("LEFT", 12, 0)
    end
    text:SetPoint("RIGHT", self, "RIGHT", -10, 0)

    self:SetFontString(text)
    self:SetScript("OnEnter", function(self)
        local high = self:GetHighlightTexture()
        if high then
            high:Show()
        end
    end)
    
    self:SetScript("OnLeave", function(self)
        local high = self:GetHighlightTexture()
        if high then
            high:Hide()
        end
    end)
    
    self:SetScript("OnMouseDown", function(self)
        local norm = self:GetNormalTexture()
        local push = self:GetPushedTexture()
        if norm and push then
            norm:Hide()
            push:Show()
        end
    end)
    
    self:SetScript("OnMouseUp", function(self)
        local norm = self:GetNormalTexture()
        local push = self:GetPushedTexture()
        if norm and push then
            norm:Show()
            push:Hide()
        end
    end)
    
    self:SetScript("OnDisable", function(self)
        local norm = self:GetNormalTexture()
        local push = self:GetPushedTexture()
        local dis = self:GetDisabledTexture()
        if norm and push and dis then
            norm:Hide()
            push:Hide()
            dis:Show()
        end
    end)
    
    self:SetScript("OnEnable", function(self)
        local norm = self:GetNormalTexture()
        local dis = self:GetDisabledTexture()
        if norm and dis then
            dis:Hide()
            norm:Show()
        end
    end)
end

-- Cargar textura desde atlas
local function SetTextureFromAtlas(texture, atlasName)
    local left, right, top, bottom, texturePath = GetAtlasCoords(atlasName)
    if left and texturePath then
        texture:SetTexture(texturePath)
        texture:SetTexCoord(left, right, top, bottom)
        return true
    end
    return false
end

-- Función OnLoad para los botones
function KnowledgeBaseSidebarButton_OnLoad(self)
    local normalTex = _G[self:GetName() .. "NormalTexture"]
    local pushedTex = _G[self:GetName() .. "PushedTexture"]
    local disabledTex = _G[self:GetName() .. "DisabledTexture"]
    local highlightTex = _G[self:GetName() .. "HighlightTexture"]
    
    if normalTex then
        self:SetNormalTexture(normalTex)
    end
    if pushedTex then
        self:SetPushedTexture(pushedTex)
    end
    if disabledTex then
        self:SetDisabledTexture(disabledTex)
    end
    if highlightTex then
        self:SetHighlightTexture(highlightTex)
        highlightTex:SetBlendMode("ADD")
    end

    local iconTex = _G[self:GetName() .. "Icon"]
    if iconTex and KnowledgeBaseButtonIcons[self:GetName()] then
        local atlasName = KnowledgeBaseButtonIcons[self:GetName()]
        if not SetTextureFromAtlas(iconTex, atlasName) then
            iconTex:SetTexture("Interface\\HelpFrame\\HelpSidebar")
        end
    end
end

function KnowledgeBaseSidebarButton_OnEnter(self)
    local normalTex = _G[self:GetName() .. "NormalTexture"]
    local pushedTex = _G[self:GetName() .. "PushedTexture"]
    local highlightTex = _G[self:GetName() .. "HighlightTexture"]
    
    if normalTex and pushedTex then
        normalTex:Hide()
        pushedTex:Show()
    end
    if highlightTex then
        highlightTex:Show()
    end

    if self.tooltipText then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.tooltipText, 1.0, 1.0, 1.0)
        GameTooltip:Show()
    end
end

function KnowledgeBaseSidebarButton_OnLeave(self)
    local normalTex = _G[self:GetName() .. "NormalTexture"]
    local pushedTex = _G[self:GetName() .. "PushedTexture"]
    local highlightTex = _G[self:GetName() .. "HighlightTexture"]
    
    if normalTex and pushedTex then
        normalTex:Show()
        pushedTex:Hide()
    end
    if highlightTex then
        highlightTex:Hide()
    end
    
    GameTooltip:Hide()
end

function KnowledgeBaseSidebarButton_OnMouseDown(self)
    local normalTex = _G[self:GetName() .. "NormalTexture"]
    local pushedTex = _G[self:GetName() .. "PushedTexture"]
    
    if normalTex and pushedTex then
        normalTex:Hide()
        pushedTex:Show()
    end
end

function KnowledgeBaseSidebarButton_OnMouseUp(self)
    local normalTex = _G[self:GetName() .. "NormalTexture"]
    local pushedTex = _G[self:GetName() .. "PushedTexture"]
    
    if normalTex and pushedTex then
        normalTex:Show()
        pushedTex:Hide()
    end
end

--
-- HelpFrame
--

function HelpFrame_OnLoad(self)
	self:RegisterEvent("PLAYER_ENTERING_WORLD");
	self:RegisterEvent("UPDATE_GM_STATUS");
	self:RegisterEvent("UPDATE_TICKET");
	self:RegisterEvent("GMSURVEY_DISPLAY");
	self:RegisterEvent("GMRESPONSE_RECEIVED");
end

function HelpFrame_OnShow(self)
	UpdateMicroButtons();
	PlaySound("igCharacterInfoOpen");
	GetGMStatus();
	GetGMTicket();
end

function HelpFrame_OnHide(self)
	PlaySound("igCharacterInfoClose");
	UpdateMicroButtons();
	if ( openFrame ) then
		openFrame:Hide();
		openFrame = nil;
	end
	HelpFrame_PopAllFrames();
end

function HelpFrame_OnEvent(self, event, ...)
	if ( event == "PLAYER_ENTERING_WORLD" ) then
		GetGMTicket();
	elseif ( event ==  "UPDATE_GM_STATUS" ) then
		local status = ...;
		if ( status == GMTICKET_QUEUE_STATUS_ENABLED ) then
			ticketQueueActive = true;
			-- Legacy Stuck/OpenTicket button removed.
		else
			ticketQueueActive = false;
			-- Legacy Stuck/OpenTicket button removed.
			if ( status == GMTICKET_QUEUE_STATUS_DISABLED ) then
				StaticPopup_Show("HELP_TICKET_QUEUE_DISABLED");
			end
		end
	elseif ( event == "GMSURVEY_DISPLAY" ) then
		-- If there's a survey to display then fill out info and return
		TicketStatusTitleText:SetText(CHOSEN_FOR_GMSURVEY);
		TicketStatusTime:Hide();
		TicketStatusFrame:SetHeight(TicketStatusTitleText:GetHeight() + 20);
		TicketStatusFrame:Show();
		TicketStatusFrame.hasGMSurvey = true;
		haveResponse = false;
		haveTicket = false;
		TicketState.MarkDirty();
		UIFrameFlash(TicketStatusFrameIcon, 0.75, 0.75, 20);
	elseif ( event == "UPDATE_TICKET" ) then
		local category, ticketDescription, ticketAge, oldestTicketTime, updateTime, assignedToGM, openedByGM = ...;

		if category then
			lastTicketText = ticketDescription or lastTicketText or "";
			haveResponse = false;
			haveTicket = true;

			local statusText;
			TicketStatusFrame.ticketTimer = nil;

			if openedByGM == GMTICKET_OPENEDBYGM_STATUS_OPENED then
				if assignedToGM == GMTICKET_ASSIGNEDTOGM_STATUS_ESCALATED then
					statusText = GM_TICKET_ESCALATED;
				else
					statusText = GM_TICKET_SERVICE_SOON;
				end
			else
				local estimatedWaitTime = (oldestTicketTime - ticketAge) * 24 * 60 * 60;
				if estimatedWaitTime < 0 then estimatedWaitTime = 0; end

				if oldestTicketTime < 0 or updateTime < 0 or updateTime > 0.042 then
					statusText = GM_TICKET_UNAVAILABLE;
				elseif estimatedWaitTime > 7200 then
					statusText = GM_TICKET_HIGH_VOLUME;
				elseif estimatedWaitTime > 300 then
					statusText = format(GM_TICKET_WAIT_TIME, SecondsToTime(estimatedWaitTime, 1));
					TicketStatusFrame.ticketTimer = estimatedWaitTime;
				else
					statusText = GM_TICKET_SERVICE_SOON;
				end
			end

			if TicketStatusTitleText then TicketStatusTitleText:SetText(TICKET_STATUS); end
			if TicketStatusTime then
				TicketStatusTime:SetText(statusText or "");
				if statusText then TicketStatusTime:Show(); else TicketStatusTime:Hide(); end
			end
		else
			haveResponse = false;
			haveTicket = false;
			if TicketStatusTime then
				TicketStatusTime:SetText("");
				TicketStatusTime:Hide();
			end
		end

		TicketState.MarkDirty();

	elseif ( event == "GMRESPONSE_RECEIVED" ) then
		local ticketDescription = ...;
		lastTicketText = ticketDescription or lastTicketText or "";
		haveResponse = true;
		haveTicket = false;

		if TicketStatusTitleText then TicketStatusTitleText:SetText(GM_RESPONSE_ALERT); end
		if TicketStatusTime then
			TicketStatusTime:SetText("");
			TicketStatusTime:Hide();
		end
		if TicketStatusFrame then
			TicketStatusFrame.hasGMSurvey = false;
		end

		TicketState.MarkDirty();
	end
end

-- Paneles personalizados por sección (se crean en HelpPanel_InitAll)
local helpPanels = {};
local activePanel = nil;  -- Panel actualmente visible; usado como API pública por otros módulos
local lastTicketPanel = "GMTalk"; -- panel que abrió el último ticket (para volver al editar)
local lastTicketText  = "";         -- texto del último ticket enviado (cache para edición)
local HelpFrameAnnouncementCarousel;

-- Muestra un panel custom por clave
function HelpPanel_Show(key)
	if not next(helpPanels) then return; end  -- InitAll aún no corrió

	for _, p in pairs(helpPanels) do p:Hide(); end
	activePanel = nil;

	local isInfo = (key == "Info");

	if KnowledgeBaseFrameEditBox then KnowledgeBaseFrameEditBox:SetShown(isInfo); end
	if KnowledgeBaseFrameSearchButton then KnowledgeBaseFrameSearchButton:SetShown(isInfo); end
	if KnowledgeBaseMotdLabel then KnowledgeBaseMotdLabel:SetShown(isInfo); end
	if KnowledgeBaseMotdTextFrame then KnowledgeBaseMotdTextFrame:SetShown(isInfo); end
	if KnowledgeBaseServerMessageLabel then KnowledgeBaseServerMessageLabel:SetShown(isInfo); end
	if KnowledgeBaseServerMessageTextFrame then KnowledgeBaseServerMessageTextFrame:SetShown(isInfo); end

	if HelpFrameAnnouncementCarousel then
		HelpFrameAnnouncementCarousel:SetShown(isInfo);
		if isInfo and HelpFrameAnnouncementCarousel.OnInfoShown then
			HelpFrameAnnouncementCarousel:OnInfoShown();
		elseif HelpFrameAnnouncementCarousel.OnInfoHidden then
			HelpFrameAnnouncementCarousel:OnInfoHidden();
		end
	end

	if isInfo then
		if ( KBASE_SETUP_LOADED == 0 ) then
			KBSetup_BeginLoading(KBASE_NUM_ARTICLES_PER_PAGE, KBASE_CURRENT_PAGE);
		end
		KnowledgeBaseFrame_UpdateMotd();
		KnowledgeBaseFrame_UpdateServerMessage();
		if KnowledgeBaseArticleListFrame and KBASE_SETUP_LOADED == 1 then
			KnowledgeBaseArticleListFrame:Show();
		end
		if KnowledgeBaseFrameEditBox then KnowledgeBaseFrameEditBox:SetFocus(); end
		return;
	end

	if KnowledgeBaseArticleListFrame then KnowledgeBaseArticleListFrame:Hide(); end
	if KnowledgeBaseArticleScrollFrame then KnowledgeBaseArticleScrollFrame:Hide(); end
	if KnowledgeBaseErrorFrame then KnowledgeBaseErrorFrame:Hide(); end

	local panel = helpPanels[key];
	if not panel then return; end
	panel:Show();
	activePanel = panel;
end

-- Helper: crea un FontString de título en el área de contenido (a la derecha de la sidebar)

local function MakeTitle(parent, text)
	local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge");
	fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, -20);
	fs:SetWidth(520);
	fs:SetJustifyH("LEFT");
	fs:SetText(text);
	return fs;
end

-- Helper: crea un FontString de cuerpo debajo de otro widget
local function MakeBody(parent, anchor, offsetY, text, width)
	local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight");
	fs:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, offsetY or -8);
	fs:SetWidth(width or 520);
	fs:SetJustifyH("LEFT");
	fs:SetText(text);
	return fs;
end

-- Helper: crea un botón de acción estilo UIPanelButton

-- Inicializa todos los paneles custom dentro de KnowledgeBaseFrame
local function HelpFrame_UpdateTicketButtons()
	local gmHasTicket = haveTicket and (lastTicketPanel == "GMTalk");
	local gmHasResponse = haveResponse and (lastTicketPanel == "GMTalk");

	if HelpPanelGMSend then
		if gmHasTicket then
			HelpPanelGMSend:SetText(EDIT_TICKET);
		elseif gmHasResponse then
			HelpPanelGMSend:SetText(HELPFRAME_NEED_MORE_HELP or SUBMIT);
		else
			HelpPanelGMSend:SetText(SUBMIT);
		end
	end

	if HelpPanelGMAbandonTicket then
		HelpPanelGMAbandonTicket:SetShown(gmHasTicket);
	end
end
TicketState.MarkDirty(HelpFrame_UpdateTicketButtons);
--------------------------------------------------------------------
-- HelpPanel_InitAll - Versión modularizada con contenido centrado
local function HelpPanel_InitAll()
	local parent = KnowledgeBaseFrame;
	if not parent then return; end

	-- Inicializar todos los paneles
	HelpPanel_CreateLag(parent);
	HelpPanel_CreateContact(parent);
	HelpPanel_CreateStuck(parent);
	HelpPanel_CreateGMTalk(parent);
end

-- ============================================================================
-- Funciones Helper Centradas
-- ============================================================================

local function MakeTitleCentered(parent, text)
	local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge");
	fs:SetPoint("TOP", parent, "TOP", 120, -90);
	fs:SetWidth(520);
	fs:SetJustifyH("CENTER");
	fs:SetText(text);
	return fs;
end

local function MakeBodyCentered(parent, anchor, offsetY, text, width)
	local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight");
	fs:SetPoint("TOP", anchor, "BOTTOM", 0, offsetY or -8);
	fs:SetWidth(width or 520);
	fs:SetJustifyH("CENTER");
	fs:SetText(text);
	return fs;
end

-- ============================================================================
-- Helper para crear contenedor centrado
-- ============================================================================
local function CreateCenteredContainer(parent)
	local container = CreateFrame("Frame", nil, parent);
	container:SetWidth(600);
	container:SetHeight(parent:GetHeight());
	container:SetPoint("CENTER", parent, "CENTER", 0, 0);
	return container;
end

-- ============================================================================
-- PANEL: Report Lag
-- ============================================================================
function HelpPanel_CreateLag(parent)
	local pLag = CreateFrame("Frame", nil, parent);
	pLag:SetAllPoints(parent);
	pLag:Hide();

	local container = CreateCenteredContainer(pLag);
	local title = MakeTitleCentered(container, HELPFRAME_LAG_TITLE);
	local body = MakeBodyCentered(container, title, -8, HELPFRAME_LAG_TEXT1, 520);

	local entries = {
		{ text = BUTTON_LAG_LOOT,         tooltip = BUTTON_LAG_LOOT_TOOLTIP,         kind = "Loot" },
		{ text = BUTTON_LAG_AUCTIONHOUSE, tooltip = BUTTON_LAG_AUCTIONHOUSE_TOOLTIP, kind = "AuctionHouse" },
		{ text = BUTTON_LAG_MAIL,         tooltip = BUTTON_LAG_MAIL_TOOLTIP,         kind = "Mail" },
		{ text = BUTTON_LAG_CHAT,         tooltip = BUTTON_LAG_CHAT_TOOLTIP,         kind = "Chat" },
		{ text = BUTTON_LAG_MOVEMENT,     tooltip = BUTTON_LAG_MOVEMENT_TOOLTIP,     kind = "Movement" },
		{ text = BUTTON_LAG_SPELL,        tooltip = BUTTON_LAG_SPELL_TOOLTIP,        kind = "Spell" },
	};

	local previous = body;
	for i, info in ipairs(entries) do
		local button = CreateFrame("Button", nil, container, "GameMenuButtonTemplate");
		button:SetSize(320, 30);
		button:SetText(info.text);
		button:SetPoint("TOP", previous, "BOTTOM", 0, i == 1 and -20 or -10);
		button:SetScript("OnClick", function()
			HelpReportLag(info.kind);
		end);
		button:SetScript("OnEnter", function(self)
			if info.tooltip then
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
				GameTooltip:SetText(info.tooltip, 1, 1, 1, 1, true);
				GameTooltip:Show();
			end
		end);
		button:SetScript("OnLeave", function() GameTooltip:Hide(); end);
		previous = button;
	end

	helpPanels["Lag"] = pLag;
end

-- ============================================================================
-- PANEL: Contáctanos
-- ============================================================================
function HelpPanel_CreateContact(parent)
	local pContact = CreateFrame("Frame", nil, parent);
	pContact:SetAllPoints(parent);
	pContact:Hide();
	
	local container = CreateCenteredContainer(pContact);
	HelpPanel_AddContactContent(container);
	
	helpPanels["Red"] = pContact;
end

function HelpPanel_AddContactContent(container)
	local cTitle = MakeTitleCentered(container, HELPFRAME_CONTACT_TITLE);
	local cText1 = MakeBodyCentered(container, cTitle, -8, HELPFRAME_CONTACT_TEXT1, 520);
	local cText2 = MakeBodyCentered(container, cText1, -6, HELPFRAME_CONTACT_TEXT2, 520);
	local cText3 = MakeBodyCentered(container, cText2, -8, HELPFRAME_CONTACT_TEXT3, 520);
	local cText4 = MakeBodyCentered(container, cText3, -4, HELPFRAME_CONTACT_TEXT4, 520);

	local buttonContainer = CreateFrame("Frame", nil, container);
	buttonContainer:SetPoint("TOP", cText4, "BOTTOM", 0, -30);
	buttonContainer:SetWidth(400);
	buttonContainer:SetHeight(100);
	
	-- Botón Discord con icono
	local discordBtn = HelpPanel_CreateIconButton(buttonContainer, 
		"Interface\\GLUES\\common\\Red\\DiscordIcon",
		HELPFRAME_DISCORD_BUTTON,
		HELPFRAME_DISCORD_URL,
		"LEFT");
	
	-- Botón Web con icono
	local webBtn = HelpPanel_CreateIconButton(buttonContainer,
		"Interface\\GLUES\\common\\Red\\WebIcon",
		HELPFRAME_WEB_BUTTON,
		HELPFRAME_WEB_URL,
		"RIGHT",
		discordBtn);
end

function HelpPanel_CreateIconButton(parent, iconPath, text, url, position, referenceButton)
	local button = CreateFrame("Button", nil, parent);
	button:SetSize(120, 90);
	
	if position == "LEFT" then
		button:SetPoint("LEFT", parent, "LEFT", 40, 0);
	elseif position == "RIGHT" and referenceButton then
		button:SetPoint("LEFT", referenceButton, "RIGHT", 40, 0);
	end
	
	-- Icono
	local icon = button:CreateTexture(nil, "ARTWORK");
	icon:SetSize(82, 82);
	icon:SetPoint("TOP", button, "TOP", 0, 0);
	icon:SetTexture(iconPath);
	
	-- Texto debajo del icono
	local buttonText = button:CreateFontString(nil, "OVERLAY", "GameFontNormal");
	buttonText:SetPoint("TOP", icon, "BOTTOM", 0, -5);
	buttonText:SetText(text);
	buttonText:SetJustifyH("CENTER");
	
	-- Efecto hover
	button:SetScript("OnEnter", function(self)
		local highlight = self:CreateTexture(nil, "HIGHLIGHT");
		highlight:SetAllPoints(icon);
		highlight:SetTexture("Interface\\GLUES\\common\\Red\\Rune");
		highlight:SetBlendMode("ADD");
		self.highlight = highlight;
	end);
	
	button:SetScript("OnLeave", function(self)
		if self.highlight then
			self.highlight:Hide();
			self.highlight = nil;
		end
	end);
	
	button:SetScript("OnClick", function()
		HelpPanel_ShowURLPopup(url);
	end);
	
	return button;
end

-- ============================================================================
-- PANEL: Personaje Atascado
-- ============================================================================
function HelpPanel_CreateStuck(parent)
	local pStuck = CreateFrame("Frame", nil, parent);
	pStuck:SetAllPoints(parent);
	pStuck:Hide();
	
	local container = CreateCenteredContainer(pStuck);
	HelpPanel_AddStuckContent(container);
	
	helpPanels["Stuck"] = pStuck;
end

function HelpPanel_AddStuckContent(container)
	local stTitle = MakeTitleCentered(container, HELPFRAME_STUCK_TITLE);
	local stText1 = MakeBodyCentered(container, stTitle, -5, HELPFRAME_STUCK_TEXT1, 520);
	
	-- Contenedor para la piedra de hogar
	local hearthstoneContainer = CreateFrame("Frame", nil, container);
	hearthstoneContainer:SetSize(100, 100);
	hearthstoneContainer:SetPoint("TOP", stText1, "BOTTOM", 0, -50);
	
	local hearthstoneBtn = CreateFrame("Button", nil, hearthstoneContainer);
	hearthstoneBtn:SetSize(64, 64);
	hearthstoneBtn:SetPoint("TOP", hearthstoneContainer, "TOP", 0, 0);
	
	-- Icono
	local hearthstoneIcon = hearthstoneBtn:CreateTexture(nil, "ARTWORK");
	hearthstoneIcon:SetAllPoints();

	local textureFound = false;
	local hearthstoneTextures = {
		"Interface\\BUTTONS\\hearthstone_button",
	};
	
	for _, texturePath in ipairs(hearthstoneTextures) do
		hearthstoneIcon:SetTexture(texturePath);
		local width = hearthstoneIcon:GetWidth();
		if width and width > 0 then
			textureFound = true;
			break;
		end
	end
	
	if not textureFound then
		hearthstoneIcon:SetTexture("Interface\\Icons\\INV_Misc_Hearthstone");
	end
	
	local function OnEnter()
		local glow = hearthstoneBtn:CreateTexture(nil, "HIGHLIGHT");
		glow:SetAllPoints(hearthstoneIcon);
		glow:SetTexture("Interface\\BUTTONS\\hearthstone_button");
		glow:SetBlendMode("ADD");
		hearthstoneBtn.glow = glow;
	end
	
	local function OnLeave()
		if hearthstoneBtn.glow then
			hearthstoneBtn.glow:Hide();
			hearthstoneBtn.glow = nil;
		end
	end
	
	hearthstoneBtn:SetScript("OnEnter", OnEnter);
	hearthstoneBtn:SetScript("OnLeave", OnLeave);
	
	hearthstoneBtn:SetScript("OnClick", function()
		Stuck();
		HideUIPanel(HelpFrame);
	end);
	
	local hearthstoneText = hearthstoneContainer:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall");
	hearthstoneText:SetPoint("TOP", hearthstoneBtn, "BOTTOM", 0, -5);
	hearthstoneText:SetText(TUTORIAL_TITLE31);
	hearthstoneText:SetJustifyH("CENTER");
	
	local stBtn = CreateFrame("Button", nil, container, "GameMenuButtonTemplate");
	stBtn:SetSize(220, 30);
	stBtn:SetText(STUCK_BUTTON_TEXT);

	local buttonText = stBtn:GetFontString();
	if buttonText then
		buttonText:SetJustifyH("CENTER");
	end
	
	stBtn:SetPoint("TOP", hearthstoneContainer, "BOTTOM", 0, -20);
	stBtn:SetScript("OnClick", function()
		Stuck();
		HideUIPanel(HelpFrame);
	end);
end

-- ============================================================================
-- PANEL: Hablar con un MJ
-- ============================================================================
function HelpPanel_CreateGMTalk(parent)
	local pGM = CreateFrame("Frame", nil, parent);
	pGM:SetAllPoints(parent);
	pGM:Hide();
	
	local container = CreateCenteredContainer(pGM);
	HelpPanel_AddGMTalkContent(container);
	
	pGM:SetScript("OnShow", function()
		needResponse = true;
		HelpPanel_GMTalk_OnShow(pGM);
		HelpFrame_UpdateTicketButtons();
	end);
	
	helpPanels["GMTalk"] = pGM;
end

function HelpPanel_AddGMTalkContent(container)
	local gmTitle = MakeTitleCentered(container, HELPFRAME_GMTALK_TITLE);
	local gmText1 = MakeBodyCentered(container, gmTitle, -5, HELPFRAME_GMTALK_TEXT1, 520);
	local gmText2 = MakeBodyCentered(container, gmText1, -5, HELPFRAME_GMTALK_TEXT2, 520);
	
	-- Label
	local gmLabel = container:CreateFontString(nil, "ARTWORK", "GameFontHighlight");
	gmLabel:SetPoint("TOP", gmText2, "BOTTOM", 0, -12);
	gmLabel:SetWidth(520); gmLabel:SetJustifyH("CENTER");
	gmLabel:SetText(HELPFRAME_OPENTICKET_TEXT);
	
	-- Fondo y editbox
	local gmBG, gmEditBox = HelpPanel_CreateEditBoxAreaCentered(container, gmLabel, "HelpPanelGMEditBox");
	
	-- Botones
	HelpPanel_CreateAbandonButtonCentered(container, gmLabel, "HelpPanelGMAbandonTicket");
	local gmSend = HelpPanel_CreateSendButtonCentered(container, gmBG, "HelpPanelGMSend", 
		function() return HelpPanel_GMTalk_OnSend() end);

	-- Tooltip informativo igual que el antiguo de Informar problema
	HelpPanel_CreateInfoTooltipCentered(container, gmSend);
	
	-- Botón de chat log
	HelpPanel_CreateChatLogButtonCentered(container, gmSend);
	
	-- Store references
	container.editBox = gmEditBox;
	container.label = gmLabel;
	container.bg = gmBG;
end

function HelpPanel_GMTalk_OnShow(pGM)
	local container = pGM:GetChildren()[1];
	if container and container.editBox then
		if haveTicket and lastTicketPanel == "GMTalk" then
			local t = lastTicketText or "";
			container.editBox:SetText(t);
		else
			container.editBox:SetText("");
		end
	end
end

function HelpPanel_GMTalk_OnSend()
	local text = HelpPanelGMEditBox:GetText();
	if text and text ~= "" then
		lastTicketPanel = "GMTalk";
		lastTicketText = text;
		if haveResponse then
			GMResponseNeedMoreHelp(text);
		elseif haveTicket then
			UpdateGMTicket(text);
		else
			NewGMTicket(text, needResponse);
		end
		HideUIPanel(HelpFrame);
	end
end

function HelpPanel_CreateChatLogButtonCentered(container, anchor)
	local gmChatLog = CreateFrame("Button", nil, container, "GameMenuButtonTemplate");
	gmChatLog:SetSize(220, 30);
	gmChatLog:SetText(HELPFRAME_GMTALK_OPEN_LOG);
	
	-- Centrar texto del botón
	local buttonText = gmChatLog:GetFontString();
	if buttonText then
		buttonText:SetJustifyH("CENTER");
	end
	
	-- Cambiar posición: debajo del botón Enviar, a la izquierda
	gmChatLog:SetPoint("TOP", anchor, "BOTTOM", 0, -15);
	
	if GMChatFrame_Show then
		gmChatLog:SetScript("OnClick", function()
			GMChatFrame_Show();
			HideUIPanel(HelpFrame);
		end);
	else
		gmChatLog:Disable();
		gmChatLog:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
			GameTooltip:SetText(HELPFRAME_GMTALK_LOG_DISABLED, 1.0, 0.0, 0.0);
			GameTooltip:Show();
		end);
		gmChatLog:SetScript("OnLeave", function()
			GameTooltip:Hide();
		end);
	end
	
	return gmChatLog;
end

-- ============================================================================
-- Funciones Helper Centradas
-- ============================================================================

function HelpPanel_CreateEditBoxAreaCentered(parent, anchor, editBoxName)
	local bg = CreateFrame("Frame", nil, parent);
	bg:SetSize(520, 180);
	bg:SetPoint("TOP", anchor, "BOTTOM", 0, -6);
	bg:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\border-tooltip-Noa",
		tile = true, tileSize = 32, edgeSize = 32,
		insets = { left=11, right=11, top=11, bottom=11 },
	});
	bg:SetBackdropColor(0, 0, 0, 0.9);
	bg:EnableMouse(true);
	
	local input = CreateFrame("ScrollFrame", nil, bg);
	input:SetPoint("TOPLEFT", bg, "TOPLEFT", 14, -20);
	input:SetPoint("BOTTOMRIGHT", bg, "BOTTOMRIGHT", -14, 20);
	input:EnableMouse(true);
	
	local editBox = CreateFrame("EditBox", editBoxName, input);
	editBox:SetMultiLine(true);
	editBox:SetMaxLetters(500);
	editBox:SetAutoFocus(false);
	editBox:SetFontObject("ChatFontNormal");
	editBox:SetJustifyH("LEFT");
	if editBox.SetJustifyV then
		editBox:SetJustifyV("TOP");
	end
	editBox:SetPoint("TOPLEFT", input, "TOPLEFT", 0, 0);
	editBox:SetWidth(492);
	editBox:SetHeight(1000);
	editBox:SetScript("OnEscapePressed", function(s) s:ClearFocus(); end);
	editBox:SetScript("OnMouseDown", function(s) s:SetFocus(); end);
	editBox:SetScript("OnCursorChanged", function(self, x, y, w, h)
		local offset = -y;
		local maxScroll = math.max(0, self:GetHeight() - input:GetHeight());
		if offset < 0 then
			offset = 0;
		elseif offset > maxScroll then
			offset = maxScroll;
		end
		input:SetVerticalScroll(offset);
	end);
	
	input:SetScrollChild(editBox);
	input:SetVerticalScroll(0);
	
	local function FocusEditBox()
		local eb = _G[editBoxName];
		if eb then eb:SetFocus(); end
	end
	
	bg:SetScript("OnMouseDown", FocusEditBox);
	input:SetScript("OnMouseDown", FocusEditBox);
	
	return bg, editBox;
end

function HelpPanel_CreateAbandonButtonCentered(parent, anchor, buttonName)
	local button = CreateFrame("Button", buttonName, parent, "GameMenuButtonTemplate");
	button:SetSize(160, 24);
	button:SetText(HELP_TICKET_ABANDON);
	
	-- Centrar texto del botón
	local buttonText = button:GetFontString();
	if buttonText then
		buttonText:SetJustifyH("CENTER");
	end

	button:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", 0, 0);
	button:Hide();
	button:SetScript("OnClick", function()
		StaticPopup_Show("HELP_TICKET_ABANDON_CONFIRM");
	end);
	return button;
end

function HelpPanel_CreateSendButtonCentered(parent, anchor, buttonName, onClickFunc)
	local button = CreateFrame("Button", buttonName, parent, "GameMenuButtonTemplate");
	button:SetSize(160, 26);
	button:SetText(SUBMIT);
	
	-- Centrar texto del botón
	local buttonText = button:GetFontString();
	if buttonText then
		buttonText:SetJustifyH("CENTER");
	end
	
	-- Reducir el espacio entre el editbox y el botón
	button:SetPoint("TOP", anchor, "BOTTOM", 0, -5);
	button:SetScript("OnClick", onClickFunc);
	return button;
end

function HelpPanel_CreateInfoTooltipCentered(parent, anchor)
	local info = CreateFrame("Button", nil, parent);
	info:SetSize(20, 20);
	info:SetPoint("LEFT", anchor, "RIGHT", 8, 0);
	local infoTex = info:CreateTexture(nil, "ARTWORK");
	infoTex:SetAllPoints();
	infoTex:SetTexture("Interface\\Common\\help-i");
	info:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		GameTooltip:SetText(HELPFRAME_REPORTISSUE_TOOLTIP, 1, 1, 1, 1, true);
		GameTooltip:Show();
	end);
	info:SetScript("OnLeave", function() GameTooltip:Hide(); end);
	return info;
end
----------------------------------------------------------------
-- Abre el panel inline correcto para editar el ticket existente,
local function HelpFrame_EditTicketInline()
	ShowUIPanel(HelpFrame);
	if KnowledgeBaseFrame and not KnowledgeBaseFrame:IsShown() then
		KnowledgeBaseFrame:Show();
	end
	HelpPanel_Show("GMTalk");
	if HelpPanelGMEditBox then
		HelpPanelGMEditBox:SetText(lastTicketText or "");
	end
end

function HelpFrame_ShowFrame(key)
	if key == "Info" or key == "KBase" then
		ShowUIPanel(HelpFrame);
		if KnowledgeBaseFrame and not KnowledgeBaseFrame:IsShown() then
			KnowledgeBaseFrame:Show();
		end
		HelpPanel_Show("Info");
		return;
	end

	if key == "Lag" or key == "Red" or key == "Stuck" or key == "GMTalk" then
		ShowUIPanel(HelpFrame);
		if KnowledgeBaseFrame and not KnowledgeBaseFrame:IsShown() then
			KnowledgeBaseFrame:Show();
		end
		HelpPanel_Show(key);
	end
end

function HelpFrame_PopFrame()
	if ( not openFrame) then
		return;
	end
	openFrame:Hide();
	local top = tremove(frameStack);
	if ( not top ) then
		HideUIPanel(HelpFrame);
		return;
	end
	top:Show();
	openFrame = top;
end

function HelpFrame_PopAllFrames()
	for i = #frameStack, 1, -1 do
		local f = tremove(frameStack, i);
		if f then f:Hide(); end
	end
end

function HelpFrame_IsGMTicketQueueActive()
	return ticketQueueActive;
end

function HelpFrame_HaveGMTicket()
	return haveTicket;
end

function HelpFrame_HaveGMResponse()
	return haveResponse;
end

-- Legacy full-screen GM/Stuck/OpenTicket/GMResponse handlers removed.\n\n--
-- TicketStatusFrame
--

function TicketStatusFrame_OnLoad(self)
	self:RegisterEvent("UPDATE_TICKET");
	self:RegisterEvent("GMRESPONSE_RECEIVED");
end

function TicketStatusFrame_OnEvent(self, event, ...)
	if ( event == "UPDATE_TICKET" ) then
		local category = ...;
		if ( (category or self.hasGMSurvey) and (not GMChatStatusFrame or not GMChatStatusFrame:IsShown()) ) then
			self:Show();
			refreshTime = GMTICKET_CHECK_INTERVAL;
		else
			self:Hide();
		end
	elseif ( event == "GMRESPONSE_RECEIVED" ) then
		if ( not GMChatStatusFrame or not GMChatStatusFrame:IsShown() ) then
			self:Show();
		else
			self:Hide();
		end
	end
end

function TicketStatusFrame_OnUpdate(self, elapsed)
	if ( haveTicket ) then
		if ( refreshTime ) then
			refreshTime = refreshTime - elapsed;
			if ( refreshTime <= 0 ) then
				refreshTime = GMTICKET_CHECK_INTERVAL;
				GetGMTicket();
			end
		end
		if ( self.ticketTimer ) then
			self.ticketTimer = self.ticketTimer - elapsed;
			if ( self.ticketTimer < 0 ) then
				self.ticketTimer = 0;
			end
			TicketStatusTime:SetFormattedText(GM_TICKET_WAIT_TIME, SecondsToTime(self.ticketTimer, 1));
		end
	end
end

function TicketStatusFrame_OnShow(self)
	ConsolidatedBuffs:ClearAndSetNewPoint("TOPRIGHT", self:GetParent(), "TOPRIGHT", -205, -self:GetHeight());
end

function TicketStatusFrame_OnHide(self)
	if ( not GMChatStatusFrame or not GMChatStatusFrame:IsShown() ) then
		ConsolidatedBuffs:ClearAndSetNewPoint("TOPRIGHT", "UIParent", "TOPRIGHT", -180, -13);
	end
end

--
-- TicketStatusFrameButton
--

function TicketStatusFrameButton_OnLoad(self)
	self:SetBackdropBorderColor(TOOLTIP_DEFAULT_COLOR.r, TOOLTIP_DEFAULT_COLOR.g, TOOLTIP_DEFAULT_COLOR.b);
	self:SetBackdropColor(TOOLTIP_DEFAULT_BACKGROUND_COLOR.r, TOOLTIP_DEFAULT_BACKGROUND_COLOR.g, TOOLTIP_DEFAULT_BACKGROUND_COLOR.b);

	local parentLevel = self:GetParent():GetFrameLevel();
	self:SetFrameLevel(parentLevel > 0 and parentLevel - 1 or 0);
end

function TicketStatusFrameButton_OnClick(self)
	if TicketStatusFrame.hasGMSurvey then
		GMSurveyFrame_LoadUI();
		ShowUIPanel(GMSurveyFrame);
		TicketStatusFrame:Hide();
		return;
	end

	if haveTicket or haveResponse then
		HelpFrame_ShowFrame("GMTalk");
	end
end


function HelpReportLag(kind)
	local lagKind = STATIC_CONSTANTS and STATIC_CONSTANTS[kind];
	if not lagKind then return; end
	HideUIPanel(HelpFrame);
	GMReportLag(lagKind);
	StaticPopup_Show("LAG_SUCCESS");
end

--
-- KnowledgeBaseFrame
--

local function KnowledgeBaseUpdateTopPanelPositions()
	if ( KnowledgeBaseMotdText:GetText() ) then
		KnowledgeBaseMotdLabel:Show();
		KnowledgeBaseMotdTextFrame:Show();
	else
		KnowledgeBaseMotdLabel:Hide();
		KnowledgeBaseMotdTextFrame:Hide();
	end

	if ( KnowledgeBaseServerMessageText:GetText() ) then
		KnowledgeBaseServerMessageLabel:Show();
		KnowledgeBaseServerMessageTextFrame:Show();
	else
		KnowledgeBaseServerMessageLabel:Hide();
		KnowledgeBaseServerMessageTextFrame:Hide();
	end

	KnowledgeBaseServerMessageLabel:ClearAndSetNewPoint(
		"TOPLEFT",
		KnowledgeBaseMotdLabel:IsShown() and KnowledgeBaseMotdTextFrame or KnowledgeBaseMotdLabel,
		KnowledgeBaseMotdLabel:IsShown() and "BOTTOMLEFT" or "TOPLEFT",
		0,
		KnowledgeBaseMotdLabel:IsShown() and -5 or 0
	);
end

KnowledgeBaseFrame_UpdateMotd = function()
    local currentMotd = KBSystem_GetMOTD();
    if ( currentMotd ) then
        local singleLine = gsub(currentMotd, "\n", " ");
        KnowledgeBaseMotdText:SetText(singleLine);
    else
        KnowledgeBaseMotdText:SetText(nil);
    end
    KnowledgeBaseMotdTextFrame:SetHeight(KnowledgeBaseMotdText:GetHeight());
    KnowledgeBaseUpdateTopPanelPositions();
end

KnowledgeBaseFrame_UpdateServerMessage = function()
    local currrentServerNotice = KBSystem_GetServerNotice();
    if ( currrentServerNotice ) then
        local closeBracketIndex = strfind(currrentServerNotice, "] ", 1, true);
        if ( closeBracketIndex ) then
            currrentServerNotice = strsub(currrentServerNotice, closeBracketIndex + 2);
        end
        KnowledgeBaseServerMessageText:SetText(currrentServerNotice);
    else
        KnowledgeBaseServerMessageText:SetText(nil);
    end
    KnowledgeBaseServerMessageTextFrame:SetHeight(KnowledgeBaseServerMessageText:GetHeight());
    KnowledgeBaseUpdateTopPanelPositions();
end

local function KnowledgeBaseFrame_ShowSearchFrame()
	KnowledgeBaseArticleListFrame:Show();
	KnowledgeBaseArticleScrollFrame:Hide();
	KnowledgeBaseErrorFrame:Hide();
end

local function KnowledgeBaseFrame_ShowArticleFrame()
	KnowledgeBaseArticleListFrame:Hide();
	KnowledgeBaseArticleScrollFrame:Show();
	KnowledgeBaseErrorFrame:Hide();
end

local function KnowledgeBaseFrame_ShowErrorFrame()
	KnowledgeBaseArticleListFrame:Hide();
	KnowledgeBaseArticleScrollFrame:Hide();
	KnowledgeBaseErrorFrame:Show();
end

local function KnowledgeBaseErrorFrame_SetErrorMessage(message)
	KnowledgeBaseErrorFrameText:SetText(message);
end

local function DisablePagingButton(button)
	button:Disable();
	local buttonText = button:GetName() and _G[button:GetName() .. "Text"];
	if buttonText then
		buttonText:SetTextColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b);
	end
end

local function EnablePagingButton(button)
	button:Enable();
	local buttonText = button:GetName() and _G[button:GetName() .. "Text"];
	if buttonText then
		buttonText:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b);
	end
end

local function KnowledgeBaseArticleListFrame_HideArticleList()
	for i=1, KBASE_NUM_ARTICLES_PER_PAGE do
		local frame = _G["KnowledgeBaseArticleListItem" .. i];
		if frame then frame:Hide(); end
	end
end

function KnowledgeBaseFrame_DisableButtons()
	KBASE_ENABLE_SEARCH = 0;
	if KnowledgeBaseFrameSearchButton then
		KnowledgeBaseFrameSearchButton:Disable();
		KnowledgeBaseFrameSearchButton.enableDelay = KBASE_SEARCH_BUTTON_DELAY;
	end
	DisablePagingButton(KnowledgeBaseArticleListFrameNextButton);
	DisablePagingButton(KnowledgeBaseArticleListFramePreviousButton);
end

function KnowledgeBaseFrame_EnableButtons(articleCount, totalArticleCount)
	KBASE_ENABLE_SEARCH = 1;
	if KnowledgeBaseFrameSearchButton and not KnowledgeBaseFrameSearchButton.enableDelay then
		KnowledgeBaseFrameSearchButton:Enable();
	end
	if ( KBASE_CURRENT_PAGE == 1 ) then
		DisablePagingButton(KnowledgeBaseArticleListFramePreviousButton);
	else
		EnablePagingButton(KnowledgeBaseArticleListFramePreviousButton);
	end
	if ( articleCount ) then
		if (articleCount == KBASE_NUM_ARTICLES_PER_PAGE and (totalArticleCount > (KBASE_CURRENT_PAGE * KBASE_NUM_ARTICLES_PER_PAGE)) ) then
			EnablePagingButton(KnowledgeBaseArticleListFrameNextButton);
		else
			DisablePagingButton(KnowledgeBaseArticleListFrameNextButton);
		end
	end
end

function KnowledgeBaseFrame_Search(resetCurrentPage)
	if ( not KBSetup_IsLoaded() ) then
		return;
	end
	KnowledgeBaseFrame_DisableButtons();
	local searchText = KnowledgeBaseFrameEditBox:GetText();
	if ( searchText == KBASE_DEFAULT_SEARCH_TEXT ) then
		searchText = "";
	end
	if ( resetCurrentPage ) then
		KBASE_CURRENT_PAGE = 1;
	end
	KBQuery_BeginLoading(searchText, 0, 0, KBASE_NUM_ARTICLES_PER_PAGE, KBASE_CURRENT_PAGE);
	KBASE_SEARCH_PERFORMED = 1;
end

function KnowledgeBaseFrame_LoadTopIssues()
	KnowledgeBaseFrame_DisableButtons();
	KBASE_SEARCH_PERFORMED = 0;
	KBASE_CURRENT_PAGE = 1;
	KBASE_SETUP_LOADED = 0;
	KBSetup_BeginLoading(KBASE_NUM_ARTICLES_PER_PAGE, KBASE_CURRENT_PAGE);
end

function KnowledgeBaseFrame_OnEvent(self, event, ...)
	if ( event ==  "KNOWLEDGE_BASE_SETUP_LOAD_SUCCESS" ) then
		KBASE_SETUP_LOADED = 1;
		local articleHeaderCount = KBSetup_GetArticleHeaderCount();
		local totalArticleHeaderCount = KBSetup_GetTotalArticleCount();
		KnowledgeBaseFrame_EnableButtons(articleHeaderCount, totalArticleHeaderCount);
		if ( articleHeaderCount > 0 ) then
			KnowledgeBaseArticleListFrame_PopulateArticleList(articleHeaderCount, totalArticleHeaderCount, KBSetup_GetArticleHeaderData);
			KnowledgeBaseFrame_ShowSearchFrame();
		else
			KnowledgeBaseErrorFrame_SetErrorMessage(KBASE_ERROR_NO_RESULTS);
			KnowledgeBaseFrame_ShowErrorFrame();
		end
	elseif ( event ==  "KNOWLEDGE_BASE_SETUP_LOAD_FAILURE" ) then
		KnowledgeBaseErrorFrame_SetErrorMessage(KBASE_ERROR_LOAD_FAILURE);
		KnowledgeBaseFrame_ShowErrorFrame();
		KnowledgeBaseFrame_DisableButtons(nil);
		KBASE_SETUP_LOADED = 0;
	elseif ( event == "KNOWLEDGE_BASE_QUERY_LOAD_SUCCESS" ) then
		KnowledgeBaseArticleListFrameTitle:SetText(KBASE_SEARCH_RESULTS);
		local articleHeaderCount = KBQuery_GetArticleHeaderCount();
		local totalArticleHeaderCount = KBQuery_GetTotalArticleCount();
		KnowledgeBaseFrame_EnableButtons(articleHeaderCount, totalArticleHeaderCount);
		if ( articleHeaderCount > 0 ) then
			KnowledgeBaseArticleListFrame_PopulateArticleList(articleHeaderCount, totalArticleHeaderCount, KBQuery_GetArticleHeaderData);
			KnowledgeBaseFrame_ShowSearchFrame();
		else
			KnowledgeBaseErrorFrame_SetErrorMessage(KBASE_ERROR_NO_RESULTS);
			KnowledgeBaseFrame_ShowErrorFrame();
		end
	elseif ( event == "KNOWLEDGE_BASE_QUERY_LOAD_FAILURE" ) then
		KnowledgeBaseErrorFrame_SetErrorMessage(KBASE_ERROR_LOAD_FAILURE);
		KnowledgeBaseFrame_ShowErrorFrame();
	elseif ( event == "KNOWLEDGE_BASE_ARTICLE_LOAD_SUCCESS" ) then
		local id, subject, subjectAlt, bodyText = KBArticle_GetData();
		KnowledgeBaseArticleScrollChildFrameTitle:SetText(subject);
		KnowledgeBaseArticleScrollChildFrameText:SetText(bodyText);
		KnowledgeBaseArticleScrollChildFrameArticleId:SetFormattedText(KBASE_ARTICLE_ID, id);
		KnowledgeBaseArticleScrollFrameScrollBar:SetValue(0);
		KnowledgeBaseFrame_ShowArticleFrame();
	elseif ( event == "KNOWLEDGE_BASE_ARTICLE_LOAD_FAILURE" ) then
		KnowledgeBaseErrorFrame_SetErrorMessage(KBASE_ERROR_LOAD_FAILURE);
		KnowledgeBaseFrame_ShowErrorFrame();
	elseif ( event == "UPDATE_GM_STATUS" ) then
		local status = ...;
		if ( status == GMTICKET_QUEUE_STATUS_ENABLED ) then
			GetGMTicket();
			if KnowledgeBaseFrameGMTalk then KnowledgeBaseFrameGMTalk:Enable(); end
		else
			if KnowledgeBaseFrameGMTalk then KnowledgeBaseFrameGMTalk:Disable(); end
		end
	elseif ( event ==  "KNOWLEDGE_BASE_SYSTEM_MOTD_UPDATE" ) then
		KnowledgeBaseFrame_UpdateMotd();
	elseif ( event ==  "KNOWLEDGE_BASE_SERVER_MESSAGE" ) then
		KnowledgeBaseFrame_UpdateServerMessage();
	end
end

function KnowledgeBaseFrame_OnLoad(self)
	self:RegisterEvent("UPDATE_GM_STATUS");
	self:RegisterEvent("KNOWLEDGE_BASE_SETUP_LOAD_SUCCESS");
	self:RegisterEvent("KNOWLEDGE_BASE_SETUP_LOAD_FAILURE");
	self:RegisterEvent("KNOWLEDGE_BASE_QUERY_LOAD_SUCCESS");
	self:RegisterEvent("KNOWLEDGE_BASE_QUERY_LOAD_FAILURE");
	self:RegisterEvent("KNOWLEDGE_BASE_ARTICLE_LOAD_SUCCESS");
	self:RegisterEvent("KNOWLEDGE_BASE_ARTICLE_LOAD_FAILURE");
	self:RegisterEvent("KNOWLEDGE_BASE_SYSTEM_MOTD_UPDATE");
	self:RegisterEvent("KNOWLEDGE_BASE_SERVER_MESSAGE");

	-- ADDITIONAL LAYOUT
	KnowledgeBaseFrame_DisableButtons();

	KnowledgeBaseMotdText:SetWidth(KnowledgeBaseFrame:GetWidth() - KnowledgeBaseMotdLabel:GetWidth() - 80);
	KnowledgeBaseMotdTextFrame:SetWidth(KnowledgeBaseMotdText:GetWidth())

	KnowledgeBaseServerMessageText:SetWidth(KnowledgeBaseFrame:GetWidth() - KnowledgeBaseServerMessageLabel:GetWidth() - 80);
	KnowledgeBaseServerMessageTextFrame:SetWidth(KnowledgeBaseServerMessageText:GetWidth())

	KnowledgeBaseFrameEditBox:SetMaxBytes(128);
	KnowledgeBaseFrameEditBox:SetText(KBASE_DEFAULT_SEARCH_TEXT);

	KnowledgeBaseArticleListFrameCount:ClearAndSetNewPoint("TOPRIGHT", KnowledgeBaseArticleListFramePreviousButton, "TOPLEFT", -6, -7);

	KnowledgeBaseArticleScrollChildFrameTitle:SetWidth(KnowledgeBaseArticleScrollChildFrame:GetWidth() - KnowledgeBaseArticleScrollChildFrameBackButton:GetWidth() - 10);
	KnowledgeBaseArticleScrollChildFrameText:SetWidth(KnowledgeBaseArticleScrollChildFrame:GetWidth() - 10);
	KnowledgeBaseArticleListFramePreviousButton:ClearAndSetNewPoint("RIGHT", KnowledgeBaseArticleListFrameNextButton, "LEFT", -(KnowledgeBaseArticleListFramePreviousButtonText:GetWidth() + KnowledgeBaseArticleListFrameNextButtonText:GetWidth() + 5), 0);
	if GMChatOpenLog then GMChatOpenLog:Hide(); end

	HelpPanel_InitAll();
	if HelpAnnouncements and HelpAnnouncements.Attach then
		HelpFrameAnnouncementCarousel = HelpAnnouncements:Attach(self, KnowledgeBaseArticleListFrame);
	end
end

function KnowledgeBaseFrame_OnShow(self)
	if ( KBASE_SETUP_LOADED == 0 ) then
		KBSetup_BeginLoading(KBASE_NUM_ARTICLES_PER_PAGE, KBASE_CURRENT_PAGE);
	end

	GetGMStatus();
	GetGMTicket();
	KnowledgeBaseFrame_UpdateMotd();
	KnowledgeBaseFrame_UpdateServerMessage();

	HelpFrame.back = KnowledgeBaseFrameCancel;
	HelpPanel_Show("Info");
	if HelpFrameAnnouncementCarousel and HelpFrameAnnouncementCarousel.OnInfoShown then
		HelpFrameAnnouncementCarousel:OnInfoShown();
	end
end

function KnowledgeBaseArticleListFrame_PopulateArticleList(articleCount, totalArticleCount, dataFunc)
	KnowledgeBaseArticleListFrame_HideArticleList();
	for i=1, articleCount do
		local articleId, articleHeader, isArticleHot, isArticleUpdated = dataFunc(i);
		local frame = _G["KnowledgeBaseArticleListItem" .. i];
		if not frame then break; end
		frame.number = i + ((KBASE_CURRENT_PAGE -1) * KBASE_NUM_ARTICLES_PER_PAGE);
		frame.articleId = articleId;
		frame.articleHeader = articleHeader;
		frame.isArticleHot = isArticleHot;
		frame.isArticleUpdated = isArticleUpdated;

		KnowledgeBaseArticleListItem_Update(frame);
		frame:Show();
	end

	local pageOffset = (KBASE_CURRENT_PAGE - 1) * KBASE_NUM_ARTICLES_PER_PAGE;
	KnowledgeBaseArticleListFrameCount:SetFormattedText(KBASE_ARTICLE_COUNT,
		pageOffset + 1,
		pageOffset + articleCount,
		totalArticleCount);
end

function KnowledgeBaseArticleListFrame_PreviousPage()

	if ( KBASE_CURRENT_PAGE == 1 ) then
		return;
	end

	KBASE_CURRENT_PAGE = KBASE_CURRENT_PAGE  - 1;

	KnowledgeBaseFrame_DisableButtons();

	if ( KBASE_SEARCH_PERFORMED == 1 ) then
		KnowledgeBaseFrame_Search(false);
	else
		KBASE_SETUP_LOADED = 0;
		KBSetup_BeginLoading(KBASE_NUM_ARTICLES_PER_PAGE, KBASE_CURRENT_PAGE);
	end
end

function KnowledgeBaseArticleListFrame_NextPage()

	KBASE_CURRENT_PAGE = KBASE_CURRENT_PAGE  + 1;

	KnowledgeBaseFrame_DisableButtons();

	if ( KBASE_SEARCH_PERFORMED == 1 ) then
		KnowledgeBaseFrame_Search(false);
	else
		KBASE_SETUP_LOADED = 0;
		KBSetup_BeginLoading(KBASE_NUM_ARTICLES_PER_PAGE, KBASE_CURRENT_PAGE);
	end
end


function KnowledgeBaseArticleListItem_OnClick(self)
	PlaySound("igMainMenuOptionCheckBoxOn");
	local searchText = KnowledgeBaseFrameEditBox:GetText();
	local searchType = 2;
	if (searchText == KBASE_DEFAULT_SEARCH_TEXT or searchText == "") then
		searchType = 1;
	end
	KBArticle_BeginLoading(self.articleId, searchType);
end

function KnowledgeBaseArticleListItem_OnEnter(self)
	self.tooltipDelay = KBASE_TOOLTIP_DELAY;
end

function KnowledgeBaseArticleListItem_OnUpdate(self, elapsed)
	if ( not self.tooltipDelay ) then
		return;
	end

	self.tooltipDelay = self.tooltipDelay - elapsed;
	if ( self.tooltipDelay > 0 ) then
		return;
	end

	self.tooltipDelay = nil;
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 15);
	GameTooltip:SetText(self.articleHeader, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b, 1);

	if ( self.isArticleHot ) then
		GameTooltip:AddLine(KBASE_HOT_ISSUE);
		GameTooltip:AddTexture("Interface\\HelpFrame\\HotIssueIcon");
	end

	if ( self.isArticleUpdated ) then
		GameTooltip:AddLine(KBASE_RECENTLY_UPDATED);
		GameTooltip:AddTexture("Interface\\GossipFrame\\AvailableQuestIcon");
	end

	GameTooltip:SetMinimumWidth(220);
	GameTooltip:Show();
end

function KnowledgeBaseArticleListItem_OnLeave(self)
	self.tooltipDelay = nil;
	GameTooltip:SetMinimumWidth(0);
	GameTooltip:Hide();
end

function KnowledgeBaseServerMessageTextFrame_OnEnter(self)
	self.tooltipDelay = KBASE_TOOLTIP_DELAY;
end

function KnowledgeBaseServerMessageTextFrame_OnUpdate(self, elapsed)
	if ( not self.tooltipDelay ) then
		return;
	end

	self.tooltipDelay = self.tooltipDelay - elapsed;
	if ( self.tooltipDelay > 0 ) then
		return;
	end

	self.tooltipDelay = nil;
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 15);
	GameTooltip:SetText(KnowledgeBaseServerMessageText:GetText(), HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b, 1);
	GameTooltip:SetMinimumWidth(220);
	GameTooltip:Show();
end

function KnowledgeBaseServerMessageTextFrame_OnLeave(self)
	self.tooltipDelay = nil;
	GameTooltip:SetMinimumWidth(0);
	GameTooltip:Hide();
end

function KnowledgeBaseMotdTextFrame_OnEnter(self)
	self.tooltipDelay = KBASE_TOOLTIP_DELAY;
end

function KnowledgeBaseMotdTextFrame_OnUpdate(self, elapsed)
	if ( not self.tooltipDelay ) then
		return;
	end

	self.tooltipDelay = self.tooltipDelay - elapsed;
	if ( self.tooltipDelay > 0 ) then
		return;
	end

	self.tooltipDelay = nil;
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 15);
	GameTooltip:SetText(KnowledgeBaseMotdText:GetText(), HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b, 1);
	GameTooltip:SetMinimumWidth(220);
	GameTooltip:Show();
end

function KnowledgeBaseMotdTextFrame_OnLeave(self)
	self.tooltipDelay = nil;
	GameTooltip:SetMinimumWidth(0);
	GameTooltip:Hide();
end

function SearchButton_OnUpdate(self, elapsed)
	if ( not self.enableDelay ) then
		return;
	end

	self.enableDelay = self.enableDelay - elapsed;
	if ( self.enableDelay > 0 ) then
		return;
	end

	self.enableDelay = nil;
	KBASE_ENABLE_SEARCH = 1;
	self:Enable();
end
-- Función para el botón Información (panel 1 = pantalla KB con buscador)
-- KnowledgeBaseFrameInfo_OnClick es un alias para compatibilidad con el XML
local function ShowInfoPanel()
	ShowUIPanel(HelpFrame);
	if KnowledgeBaseFrame and not KnowledgeBaseFrame:IsShown() then
		KnowledgeBaseFrame:Show();
	end
	HelpPanel_Show("Info");
end

function HelpFrame_ShowInfoPanel()
	ShowInfoPanel();
end

function KnowledgeBaseFrameInfo_OnClick()
	ShowInfoPanel();
end

-- Helper: ejecuta callback tras 'delay' segundos (compatible con WoW 3.3.5)
do
	local delayQueue = {};
	local ticker = CreateFrame("Frame");
	ticker:SetScript("OnUpdate", function(self, elapsed)
		for i = #delayQueue, 1, -1 do
			delayQueue[i].t = delayQueue[i].t - elapsed;
			if delayQueue[i].t <= 0 then
				delayQueue[i].fn();
				tremove(delayQueue, i);
			end
		end
		if #delayQueue == 0 then self:Hide(); end
	end);
	ticker:Hide();
	function HelpFrame_DelayCall(delay, fn)
		tinsert(delayQueue, { t = delay, fn = fn });
		ticker:Show();
	end
end