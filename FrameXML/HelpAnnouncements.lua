-- Home announcements module for HelpFrame - Noa

HelpAnnouncements = HelpAnnouncements or {};

local DEFAULT_ANNOUNCEMENTS = {
    {
        title = HELPFRAME_ANNOUNCEMENT_NEWS_TITLE,
        description = HELPFRAME_ANNOUNCEMENT_NEWS_DESC,
        image = "Interface\\HELPFRAME\\Information\\news-and-updates",
        actionText = HELPFRAME_ANNOUNCEMENT_NEWS_ACTION, -- here
        action = function()
            KnowledgeBaseFrame_Search(true);
        end,
    },
    {
        title = HELPFRAME_ANNOUNCEMENT_GMTALK_TITLE,
        description = HELPFRAME_ANNOUNCEMENT_GMTALK_DESC,
        image = "Interface\\HELPFRAME\\Information\\talk-to-mj",
        actionText = KBASE_GMTALK,
        action = function() HelpFrame_ShowFrame("GMTalk"); end,
    },
    {
        title = HELPFRAME_ANNOUNCEMENT_STUCK_TITLE,
        description = HELPFRAME_ANNOUNCEMENT_STUCK_DESC,
        image = "Interface\\HELPFRAME\\Information\\stuck-character",
        actionText = KBASE_CHARSTUCK,
        action = function() HelpFrame_ShowFrame("Stuck"); end,
    },
    {
        title = HELPFRAME_ANNOUNCEMENT_CONTACT_TITLE,
        description = HELPFRAME_ANNOUNCEMENT_CONTACT_DESC,
        image = "Interface\\HELPFRAME\\Information\\contact-us",
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
    local count = #self.announcements;
    self.currentIndex = count > 0 and math.min(self.currentIndex or 1, count) or 1;
    self:BuildDots();
    self:RefreshCurrent();
end

function AnnouncementCarouselMixin:Init(parent, articleListFrame)
    self.articleListFrame = articleListFrame;
    self.width = 685;
    self.imageHeight = 350;
    self.footerHeight = 96;
    self.height = self.imageHeight + self.footerHeight;
    self.currentIndex = 1;
    self.pendingIndex = nil;
    self.animationDuration = 0.42;
    self.autoAdvanceSeconds = 10;
    self.animating = false;
    self.ticker = nil;
    self.announcements = HelpAnnouncements:GetData();

    self:SetSize(self.width, self.height + 54);
    self:SetPoint("TOPLEFT", parent, "TOPLEFT", 255, -74);

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

    self.leftButton = self:CreateArrowButton(-1);
    self.leftButton:SetPoint("LEFT", self.viewport, "LEFT", 10, self.footerHeight * 0.5);
    self.leftButton:SetScript("OnClick", function() self:Step(-1); end);

    self.rightButton = self:CreateArrowButton(1);
    self.rightButton:SetPoint("RIGHT", self.viewport, "RIGHT", -10, self.footerHeight * 0.5);
    self.rightButton:SetScript("OnClick", function() self:Step(1); end);

    self.dotsFrame = CreateFrame("Frame", nil, self);
    self.dotsFrame:SetPoint("TOP", self.viewport, "TOP", 0, -(self.imageHeight - 22));
    self.dotsFrame:SetSize(self.width, 20);
    self.dotsFrame:SetFrameLevel(self.viewport:GetFrameLevel() + 25);
    self.dots = {};

    self.helpContainer = CreateFrame("Frame", nil, self);
    self.helpContainer:SetWidth(self.width);
    self.helpContainer:SetHeight(28);

    self.helpIcon = self.helpContainer:CreateTexture(nil, "OVERLAY");
    self.helpIcon:SetSize(52, 52);
    self.helpIcon:SetPoint("LEFT", self.helpContainer, "LEFT", 8, 0);
    self.helpIcon:SetTexture("Interface\\Common\\help-i");
    self.helpIcon:SetVertexColor(1, 0.82, 0, 1);

    self.helpText = self.helpContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
    self.helpText:SetPoint("LEFT", self.helpIcon, "RIGHT", 6, 0);
    self.helpText:SetPoint("RIGHT", self.helpContainer, "RIGHT", -8, 0);
    self.helpText:SetJustifyH("LEFT");
    self.helpText:SetJustifyV("CENTER");
    self.helpText:SetText(HELPFRAME_ANNOUNCEMENT_HELP_TEXT);

    local function UpdateHelpTextLayout()
        local width = self.helpText:GetWidth();
        if width and width > 0 then
            local textWidth = self.helpText:GetStringWidth();
            if textWidth and textWidth > width then
                self.helpText:SetHeight(0);
                self.helpText:SetJustifyH("CENTER");
                self.helpText:SetJustifyV("MIDDLE");
                self.helpContainer:SetHeight(self.helpText:GetHeight() + 8);
            else
                self.helpText:SetJustifyH("LEFT");
                self.helpText:SetJustifyV("CENTER");
                self.helpContainer:SetHeight(28);
            end
        end
    end

    self:SetScript("OnShow", function()
        UpdateHelpTextLayout();
    end);

    self:SetScript("OnUpdate", function()
        if not self._helpTextUpdated then
            self._helpTextUpdated = true;
            UpdateHelpTextLayout();
        end
    end);

    self:BuildDots();
    self:RefreshCurrent();

    self:SetScript("OnHide", function() self:OnInfoHidden(); end);

    if self.articleListFrame then
        self.articleListFrame:ClearAllPoints();
        self.articleListFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 320, -500);
        self.articleListFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -70, 34);

        self.helpContainer:ClearAllPoints();
        self.helpContainer:SetPoint("TOPLEFT", self.articleListFrame, "TOPLEFT", 10, -14);
        self.helpContainer:SetPoint("RIGHT", self.articleListFrame, "RIGHT", -10, 0);
    else
        self.helpContainer:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 10, -14);
        self.helpContainer:SetPoint("RIGHT", self, "RIGHT", -10, 0);
    end
end

function AnnouncementCarouselMixin:BuildDots()
    for _, existing in ipairs(self.dots) do
        existing:Hide();
    end

    self.dots = {};
    local count = self.announcements and #self.announcements or 0;
    if count == 0 then return; end

    local spacing = 7;
    local dotSize = 18;
    local totalWidth = (count * dotSize) + ((count - 1) * spacing);
    local startX = -(totalWidth * 0.5) + (dotSize * 0.5);

    for i = 1, count do
        local dot = CreateFrame("Button", nil, self.dotsFrame);
        dot:SetSize(dotSize, dotSize);
        dot:SetPoint("CENTER", self.dotsFrame, "CENTER", startX + ((i - 1) * (dotSize + spacing)), 0);

        -- RadioButton unchecked frame: visible for all announcement pages.
        dot.frameTex = dot:CreateTexture(nil, "ARTWORK");
        dot.frameTex:SetAllPoints();
        dot.frameTex:SetTexture("Interface\\Buttons\\UI-RadioButton");
        dot.frameTex:SetTexCoord(0.00, 0.25, 0, 1);

        -- RadioButton checked circle: only visible for the current page.
        dot.selectedTex = dot:CreateTexture(nil, "OVERLAY");
        dot.selectedTex:SetAllPoints();
        dot.selectedTex:SetTexture("Interface\\Buttons\\UI-RadioButton");
        dot.selectedTex:SetTexCoord(0.25, 0.50, 0, 1);
        dot.selectedTex:Hide();

        dot.highlightTex = dot:CreateTexture(nil, "HIGHLIGHT");
        dot.highlightTex:SetAllPoints();
        dot.highlightTex:SetTexture("Interface\\Buttons\\UI-RadioButton");
        dot.highlightTex:SetTexCoord(0.25, 0.50, 0, 1);
        dot.highlightTex:SetBlendMode("ADD");
        dot.highlightTex:SetAlpha(0.45);

        dot.index = i;
        dot:SetScript("OnClick", function(button)
            self:GoTo(button.index);
        end);

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


    slide.footer = CreateFrame("Frame", nil, slide);
    slide.footer:SetPoint("TOPLEFT", slide.image, "BOTTOMLEFT", 0, 0);
    slide.footer:SetPoint("TOPRIGHT", slide.image, "BOTTOMRIGHT", 0, 0);
    slide.footer:SetHeight(self.footerHeight);
    slide.title = slide.footer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
    slide.title:SetPoint("TOPLEFT", slide.footer, "TOPLEFT", 14, -12);
    slide.title:SetWidth(455);
    slide.title:SetJustifyH("LEFT");

    slide.description = slide.footer:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
    slide.description:SetPoint("TOPLEFT", slide.title, "BOTTOMLEFT", 0, -6);
    slide.description:SetWidth(455);
    slide.description:SetJustifyH("LEFT");
    slide.description:SetJustifyV("TOP");

    slide.actionButton = CreateFrame("Button", nil, slide.footer, "GameMenuButtonTemplate");
    slide.actionButton:SetSize(170, 26);
    slide.actionButton:SetPoint("RIGHT", slide.footer, "RIGHT", -18, 0);

    local buttonText = slide.actionButton:GetFontString();
    if buttonText then
        buttonText:ClearAllPoints();
        buttonText:SetPoint("CENTER", slide.actionButton, "CENTER", 0, 0);
        buttonText:SetJustifyH("CENTER");
    end

    return slide;
end

function AnnouncementCarouselMixin:CreateArrowButton(direction)
    local button = CreateFrame("Button", nil, self);
    button:SetSize(32, 32);
    button:SetFrameStrata(self:GetFrameStrata());
    button:SetFrameLevel((self.viewport and self.viewport:GetFrameLevel() or self:GetFrameLevel()) + 20);

    if direction < 0 then
        button:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up");
        button:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down");
        button:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Disabled");
    else
        button:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up");
        button:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down");
        button:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Disabled");
    end

    local highlight = button:CreateTexture(nil, "HIGHLIGHT");
    highlight:SetAllPoints(button);
    highlight:SetTexture("Interface\\Buttons\\UI-Common-MouseHilight");
    highlight:SetBlendMode("ADD");
    button:SetHighlightTexture(highlight);

    return button;
end

function AnnouncementCarouselMixin:PopulateSlide(slide, data)
    slide.data = data;
    slide.image:SetTexture(data.image);
    slide.title:SetText(data.title);
    slide.description:SetText(data.description);
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
        if dot.selectedTex then
            dot.selectedTex:SetShown(i == self.currentIndex);
        end
        if dot.frameTex then
            if i == self.currentIndex then
                dot.frameTex:SetVertexColor(1, 0.82, 0, 1);
            else
                dot.frameTex:SetVertexColor(0.75, 0.75, 0.75, 1);
            end
        end
    end
end

function AnnouncementCarouselMixin:RestartTicker()
    if self.ticker then
        self.ticker:Hide();
        self.ticker:SetScript("OnUpdate", nil);
        self.ticker = nil;
    end
    
    if not self:IsShown() or not self.announcements or #self.announcements <= 1 then
        return;
    end

    self.ticker = CreateFrame("Frame");
    self.ticker.elapsed = 0;
    self.ticker.interval = 5;
    self.ticker:SetScript("OnUpdate", function(frame, elapsed)
        frame.elapsed = frame.elapsed + elapsed;
        if frame.elapsed >= frame.interval then
            frame.elapsed = 0;
            if self:IsShown() and not self.animating then
                self:Step(1);
            end
        end
    end);
    self.ticker:Show();
end

function AnnouncementCarouselMixin:OnInfoShown()
    self:Show();
    self:RestartTicker();
end

function AnnouncementCarouselMixin:OnInfoHidden()
    if self.ticker then
        self.ticker:Hide();
        self.ticker:SetScript("OnUpdate", nil);
        self.ticker = nil;
    end
    self:SetScript("OnUpdate", nil);
    self.animating = false;
    self.pendingIndex = nil;
end

function AnnouncementCarouselMixin:GetWrappedIndex(index)
    local count = self.announcements and #self.announcements or 0;
    if count == 0 then return 1; end
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