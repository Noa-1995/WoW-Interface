-- Home announcements module for HelpFrame
-- Keep all announcement data and animation logic here so HelpFrame.lua only handles help-system logic.

HelpAnnouncements = HelpAnnouncements or {};

local DEFAULT_ANNOUNCEMENTS = {
    {
        title = "Noticias y novedades",
        description = "Mantente al dia con eventos, cambios y avisos importantes del servidor.",
        image = "Interface\\HELPFRAME\\UI-FullBackground",
        actionText = "Mas informacion",
        action = function()
            if KnowledgeBaseFrameEditBox then
                KnowledgeBaseFrameEditBox:SetText("");
                KnowledgeBaseFrame_Search(true);
            end
        end,
    },
    {
        title = "Hablar con un MJ",
        description = "Contacta con un MJ si necesitas ayuda con problemas dentro del juego.",
        image = "Interface\\HELPFRAME\\UI-FullBackground",
        actionText = KBASE_GMTALK,
        action = function() HelpFrame_ShowFrame("GMTalk"); end,
    },
    {
        title = "Personaje atascado",
        description = "Usa la herramienta de desbloqueo si tu personaje se ha quedado atrapado.",
        image = "Interface\\HELPFRAME\\UI-FullBackground",
        actionText = KBASE_CHARSTUCK,
        action = function() HelpFrame_ShowFrame("Stuck"); end,
    },
    {
        title = "Contactanos",
        description = "Accede rapidamente a nuestros enlaces y canales oficiales.",
        image = "Interface\\HELPFRAME\\UI-FullBackground",
        actionText = HELPFRAME_CONTACT_TITLE,
        action = function() HelpFrame_ShowFrame("Red"); end,
    },
};

local AnnouncementCarouselMixin = {};

function HelpAnnouncements:GetData()
    return self.data or DEFAULT_ANNOUNCEMENTS;
end

function HelpAnnouncements:SetData(data)
    self.data = data;
    if self.carousel then
        self.carousel:SetAnnouncements(data);
    end
end

function AnnouncementCarouselMixin:SetAnnouncements(data)
    self.announcements = data or DEFAULT_ANNOUNCEMENTS;
    self.currentIndex = math.min(self.currentIndex or 1, #self.announcements);
    self:RefreshCurrent();
end

function AnnouncementCarouselMixin:Init(parent, articleListFrame)
    self.parentFrame = parent;
    self.articleListFrame = articleListFrame;
    self.width = 560;
    self.imageHeight = 190;
    self.footerHeight = 84;
    self.height = self.imageHeight + self.footerHeight;
    self.currentIndex = 1;
    self.pendingIndex = nil;
    self.animationDuration = 0.42;
    self.autoAdvanceSeconds = 10;
    self.animating = false;
    self.ticker = nil;
    self.announcements = HelpAnnouncements:GetData();

    self:SetSize(self.width, self.height + 34);
    self:SetPoint("TOPLEFT", parent, "TOPLEFT", 285, -118);

    self.viewport = CreateFrame("ScrollFrame", nil, self);
    self.viewport:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0);
    self.viewport:SetSize(self.width, self.height);
    if self.viewport.SetClipsChildren then
        self.viewport:SetClipsChildren(true);
    end

    self.track = CreateFrame("Frame", nil, self.viewport);
    self.track:SetSize(self.width * 3, self.height);
    self.viewport:SetScrollChild(self.track);

    self.slideA = self:CreateSlide(self.track);
    self.slideB = self:CreateSlide(self.track);
    self.slideA:SetPoint("TOPLEFT", self.track, "TOPLEFT", 0, 0);
    self.slideB:SetPoint("TOPLEFT", self.track, "TOPLEFT", self.width, 0);
    self.currentSlide = self.slideA;
    self.incomingSlide = self.slideB;

    self.leftButton = self:CreateArrowButton("<");
    self.leftButton:SetPoint("LEFT", self.viewport, "LEFT", 8, -(self.footerHeight * 0.5));
    self.leftButton:SetScript("OnClick", function() self:Step(-1); end);

    self.rightButton = self:CreateArrowButton(">");
    self.rightButton:SetPoint("RIGHT", self.viewport, "RIGHT", -8, -(self.footerHeight * 0.5));
    self.rightButton:SetScript("OnClick", function() self:Step(1); end);

    self.dotsFrame = CreateFrame("Frame", nil, self);
    self.dotsFrame:SetPoint("TOP", self.viewport, "BOTTOM", 0, -10);
    self.dotsFrame:SetSize(self.width, 16);
    self.dots = {};

    self:BuildDots();
    self:RefreshCurrent();

    self:SetScript("OnHide", function() self:OnInfoHidden(); end);

    if self.articleListFrame then
        self.articleListFrame:ClearAllPoints();
        self.articleListFrame:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -18);
        self.articleListFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -52, 48);
    end
end

function AnnouncementCarouselMixin:BuildDots()
    for i, existing in ipairs(self.dots) do
        existing:Hide();
    end

    self.dots = {};
    for i = 1, #self.announcements do
        local dot = CreateFrame("Button", nil, self.dotsFrame);
        dot:SetSize(12, 12);
        if i == 1 then
            dot:SetPoint("CENTER", self.dotsFrame, "CENTER", -((#self.announcements - 1) * 10), 0);
        else
            dot:SetPoint("LEFT", self.dots[i - 1], "RIGHT", 8, 0);
        end

        dot.normalTex = dot:CreateTexture(nil, "BACKGROUND");
        dot.normalTex:SetAllPoints();
        dot.normalTex:SetTexture("Interface\\Buttons\\UI-Quickslot2");

        dot.highlightTex = dot:CreateTexture(nil, "HIGHLIGHT");
        dot.highlightTex:SetAllPoints();
        dot.highlightTex:SetTexture("Interface\\Buttons\\CheckButtonHilight");
        dot.highlightTex:SetBlendMode("ADD");

        dot.index = i;
        dot:SetScript("OnClick", function(button) self:GoTo(button.index); end);
        self.dots[i] = dot;
    end
end

function AnnouncementCarouselMixin:CreateSlide(parent)
    local slide = CreateFrame("Frame", nil, parent);
    slide:SetSize(self.width, self.height);

    slide.image = slide:CreateTexture(nil, "BACKGROUND");
    slide.image:SetPoint("TOPLEFT", slide, "TOPLEFT", 0, 0);
    slide.image:SetPoint("TOPRIGHT", slide, "TOPRIGHT", 0, 0);
    slide.image:SetHeight(self.imageHeight);
    slide.image:SetTexture("Interface\\HELPFRAME\\UI-FullBackground");
    slide.image:SetTexCoord(0.12, 0.90, 0.12, 0.46);

    slide.imageBorder = CreateFrame("Frame", nil, slide);
    slide.imageBorder:SetPoint("TOPLEFT", slide.image, "TOPLEFT", 0, 0);
    slide.imageBorder:SetPoint("BOTTOMRIGHT", slide.image, "BOTTOMRIGHT", 0, 0);

    slide.footer = CreateFrame("Frame", nil, slide);
    slide.footer:SetPoint("TOPLEFT", slide.image, "BOTTOMLEFT", 0, 0);
    slide.footer:SetPoint("TOPRIGHT", slide.image, "BOTTOMRIGHT", 0, 0);
    slide.footer:SetHeight(self.footerHeight);
    slide.title = slide.footer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
    slide.title:SetPoint("TOPLEFT", slide.footer, "TOPLEFT", 14, -12);
    slide.title:SetWidth(340);
    slide.title:SetJustifyH("LEFT");

    slide.description = slide.footer:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
    slide.description:SetPoint("TOPLEFT", slide.title, "BOTTOMLEFT", 0, -6);
    slide.description:SetWidth(340);
    slide.description:SetJustifyH("LEFT");
    slide.description:SetJustifyV("TOP");

    slide.actionButton = CreateFrame("Button", nil, slide.footer, "GameMenuButtonTemplate");
    slide.actionButton:SetSize(170, 26);
    slide.actionButton:SetPoint("RIGHT", slide.footer, "RIGHT", -14, 0);

    local buttonText = slide.actionButton:GetFontString();
    if buttonText then
        buttonText:ClearAllPoints();
        buttonText:SetPoint("CENTER", slide.actionButton, "CENTER", 0, 0);
        buttonText:SetJustifyH("CENTER");
    end

    return slide;
end

function AnnouncementCarouselMixin:CreateArrowButton(label)
    local button = CreateFrame("Button", nil, self, "GameMenuButtonTemplate");
    button:SetSize(34, 34);
    button:SetText(label);
    button:SetFrameStrata(self:GetFrameStrata());
    button:SetFrameLevel((self.viewport and self.viewport:GetFrameLevel() or self:GetFrameLevel()) + 20);

    local text = button:GetFontString();
    if text then
        text:ClearAllPoints();
        text:SetPoint("CENTER", button, "CENTER", 0, 0);
        text:SetJustifyH("CENTER");
    end

    return button;
end

function AnnouncementCarouselMixin:PopulateSlide(slide, data)
    slide.data = data;
    slide.image:SetTexture(data.image or "Interface\\HELPFRAME\\UI-FullBackground");
    slide.image:SetTexCoord(0.12, 0.90, 0.12, 0.46);
    slide.title:SetText(data.title or "");
    slide.description:SetText(data.description or "");
    slide.actionButton:SetText(data.actionText or MORE);
    slide.actionButton:SetScript("OnClick", function()
        if data.action then
            data.action();
        end
    end);
end

function AnnouncementCarouselMixin:RefreshCurrent()
    if not self.announcements or #self.announcements == 0 then
        self:Hide();
        return;
    end

    self.currentIndex = math.max(1, math.min(self.currentIndex, #self.announcements));
    self:PopulateSlide(self.currentSlide, self.announcements[self.currentIndex]);
    self.currentSlide:Show();
    self.incomingSlide:Hide();
    self:UpdateDots();
end

function AnnouncementCarouselMixin:UpdateDots()
    for i, dot in ipairs(self.dots) do
        if i == self.currentIndex then
            dot.normalTex:SetVertexColor(1, 0.82, 0, 1);
        else
            dot.normalTex:SetVertexColor(0.65, 0.65, 0.65, 1);
        end
    end
end

function AnnouncementCarouselMixin:RestartTicker()
    if self.ticker and self.ticker.Cancel then
        self.ticker:Cancel();
        self.ticker = nil;
    end

    if not self:IsShown() or not C_Timer or not C_Timer.NewTicker or #self.announcements <= 1 then
        return;
    end

    self.ticker = C_Timer:NewTicker(self.autoAdvanceSeconds, function()
        if self:IsShown() and not self.animating then
            self:Step(1);
        end
    end);
end

function AnnouncementCarouselMixin:OnInfoShown()
    self:Show();
    self:RestartTicker();
end

function AnnouncementCarouselMixin:OnInfoHidden()
    if self.ticker and self.ticker.Cancel then
        self.ticker:Cancel();
        self.ticker = nil;
    end
    self.animating = false;
    self.pendingIndex = nil;
    self:SetScript("OnUpdate", nil);
end

function AnnouncementCarouselMixin:GetWrappedIndex(index)
    local count = #self.announcements;
    if index < 1 then
        return count;
    elseif index > count then
        return 1;
    end
    return index;
end

function AnnouncementCarouselMixin:Step(direction)
    self:GoTo(self:GetWrappedIndex(self.currentIndex + direction), direction);
end

function AnnouncementCarouselMixin:GoTo(index, direction)
    if self.animating or index == self.currentIndex or not self.announcements[index] then
        return;
    end

    if not direction then
        direction = (index > self.currentIndex) and 1 or -1;
        if self.currentIndex == #self.announcements and index == 1 then
            direction = 1;
        elseif self.currentIndex == 1 and index == #self.announcements then
            direction = -1;
        end
    end

    self.pendingIndex = index;
    self.animating = true;
    self:RestartTicker();

    local outgoing = self.currentSlide;
    local incoming = self.incomingSlide;
    local offset = (direction >= 0) and self.width or -self.width;
    self:PopulateSlide(incoming, self.announcements[index]);
    incoming:Show();

    incoming:ClearAllPoints();
    incoming:SetPoint("TOPLEFT", self.track, "TOPLEFT", offset, 0);

    local elapsedTotal = 0;
    self:SetScript("OnUpdate", function(_, elapsed)
        elapsedTotal = elapsedTotal + elapsed;
        local progress = math.min(elapsedTotal / self.animationDuration, 1);
        local eased = progress * progress * (3 - 2 * progress);

        outgoing:ClearAllPoints();
        outgoing:SetPoint("TOPLEFT", self.track, "TOPLEFT", -offset * eased, 0);

        incoming:ClearAllPoints();
        incoming:SetPoint("TOPLEFT", self.track, "TOPLEFT", offset - (offset * eased), 0);

        if progress >= 1 then
            self:SetScript("OnUpdate", nil);
            outgoing:Hide();
            outgoing:ClearAllPoints();
            outgoing:SetPoint("TOPLEFT", self.track, "TOPLEFT", self.width, 0);

            incoming:ClearAllPoints();
            incoming:SetPoint("TOPLEFT", self.track, "TOPLEFT", 0, 0);

            self.currentSlide = incoming;
            self.incomingSlide = outgoing;
            self.currentIndex = self.pendingIndex or index;
            self.pendingIndex = nil;
            self.animating = false;
            self:UpdateDots();
            self:RestartTicker();
        end
    end);
end

function HelpAnnouncements:Attach(parent, articleListFrame)
    if self.carousel then
        return self.carousel;
    end

    local frame = CreateFrame("Frame", "HelpFrameAnnouncementCarousel", parent);
    Mixin(frame, AnnouncementCarouselMixin);
    frame:Init(parent, articleListFrame);
    self.carousel = frame;
    return frame;
end