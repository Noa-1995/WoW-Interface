-- Hermandad se ensancha sólo mientras esa pestaña está activa.
local SOCIAL_COMPACT_WIDTH = 430
local SOCIAL_GUILD_WIDTH = 900
local SOCIAL_RAID_WIDTH = 540
local SOCIAL_HEIGHT = 490
local SOCIAL_ROW_HEIGHT = 40
local SOCIAL_SMALL_ROW = 22

local FriendsFrameSocial = { panels = {}, friendMode = "FRIENDS", selectedWho = nil }

local function ShowIf(frame, show)
	if not frame then return end
	if show then frame:Show() else frame:Hide() end
end

local function NewInset(parent, name)
	local frame = CreateFrame("Frame", name, parent, "InsetFrameTemplateNoBackground")
	frame:SetFrameLevel(parent:GetFrameLevel() + 2)
	frame:EnableMouse(false)
	return frame
end

local function AddRockBackground(panel, insetName)
	local texture = panel:CreateTexture(nil, "BACKGROUND")
	texture:SetAllPoints(panel)
	texture:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock")
	texture:SetVertexColor(0.32, 0.30, 0.27, 0.88)
	panel.Background = texture
	local shade = panel:CreateTexture(nil, "BORDER")
	shade:SetAllPoints(panel)
	shade:SetTexture("Interface\\Buttons\\WHITE8X8")
	shade:SetVertexColor(0.04, 0.035, 0.03, 0.34)
	panel.Shade = shade
	local inset = NewInset(panel, insetName)
	inset:SetAllPoints(panel)
	panel.Inset = inset
end

local function NewPanel(parent, name)
	local panel = CreateFrame("Frame", name, parent)
	panel:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -66)
	panel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -16, 42)
	panel:SetFrameLevel(parent:GetFrameLevel() + 4)
	panel:Hide()
	AddRockBackground(panel)
	return panel
end

local function NewButton(parent, text, width)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(width or 112, 22)
	button:SetText(text or "")
	return button
end

local function NewEdgeEditBox(parent, multiline)
	local edit=CreateFrame("EditBox",nil,parent)
	edit:SetAutoFocus(false); edit:SetFontObject(multiline and ChatFontNormal or GameFontHighlight)
	edit:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=12,insets={left=4,right=4,top=4,bottom=4}})
	edit:SetBackdropColor(.02,.02,.02,.86); edit:SetBackdropBorderColor(.55,.55,.55,1); edit:SetTextInsets(7,7,5,5)
	if multiline then edit:SetMultiLine(true); edit:SetJustifyH("LEFT"); edit:SetJustifyV("TOP") end
	edit:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
	return edit
end

local function NewHeader(parent, text, x, width, justify)
	local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -9)
	label:SetWidth(width)
	label:SetJustifyH(justify or "LEFT")
	label:SetText(text or "")
	return label
end

local function NewSelection(row)
	local stripe = row:CreateTexture(nil, "BACKGROUND")
	stripe:SetAllPoints(row)
	stripe:SetTexture("Interface\\Buttons\\WHITE8X8")
	stripe:SetVertexColor(1, 1, 1, row:GetID() % 2 == 0 and 0.035 or 0)
	local selected = row:CreateTexture(nil, "ARTWORK")
	selected:SetAllPoints(row)
	selected:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
	selected:SetBlendMode("ADD")
	selected:SetAlpha(0.38)
	selected:Hide()
	row.Selected = selected
	row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
end

local function GetClassColor(className)
	if not className then return 1,.82,0,nil end
	for classFile,localized in pairs(LOCALIZED_CLASS_NAMES_MALE or {}) do if localized==className then local c=RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]; if c then return c.r,c.g,c.b,classFile end end end
	for classFile,localized in pairs(LOCALIZED_CLASS_NAMES_FEMALE or {}) do if localized==className then local c=RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]; if c then return c.r,c.g,c.b,classFile end end end
	return 1,.82,0,nil
end

local function SetupScroll(scroll, rowHeight, update)
	scroll:SetScript("OnVerticalScroll", function(self, offset)
		FauxScrollFrame_OnVerticalScroll(self, offset, rowHeight, update)
	end)
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		local bar = _G[self:GetName().."ScrollBar"]
		if bar then bar:SetValue(bar:GetValue() - delta * rowHeight * 3) end
	end)
	if SidebarScrollFrame_Initialize then
		SidebarScrollFrame_Initialize(scroll, { minThumbHeight = 20, width = 8 })
	end
end

local function RestoreMainTab(tab)
	if not tab then return end
	local name = tab:GetName()
	local pieces = {
		LeftDisabled={"Interface\\PaperDollInfoFrame\\UI-Character-ActiveTab",0,0.15625,0,0.546875,20,35},
		MiddleDisabled={"Interface\\PaperDollInfoFrame\\UI-Character-ActiveTab",0.15625,0.84375,0,0.546875,nil,35},
		RightDisabled={"Interface\\PaperDollInfoFrame\\UI-Character-ActiveTab",0.84375,1,0,0.546875,20,35},
		Left={"Interface\\PaperDollInfoFrame\\UI-Character-InActiveTab",0,0.15625,0,1,20,32},
		Middle={"Interface\\PaperDollInfoFrame\\UI-Character-InActiveTab",0.15625,0.84375,0,1,nil,32},
		Right={"Interface\\PaperDollInfoFrame\\UI-Character-InActiveTab",0.84375,1,0,1,20,32},
	}
	for suffix,data in pairs(pieces) do
		local texture=_G[name..suffix]
		if texture then texture:SetTexture(data[1]); texture:SetTexCoord(data[2],data[3],data[4],data[5]); if data[6] then texture:SetWidth(data[6]) end; texture:SetHeight(data[7]) end
	end
	local leftD,middleD,rightD=_G[name.."LeftDisabled"],_G[name.."MiddleDisabled"],_G[name.."RightDisabled"]
	local left,middle,right=_G[name.."Left"],_G[name.."Middle"],_G[name.."Right"]
	if leftD then leftD:ClearAllPoints(); leftD:SetPoint("TOPLEFT",tab,"TOPLEFT",0,0) end
	if middleD then middleD:ClearAllPoints(); middleD:SetPoint("LEFT",leftD,"RIGHT",0,0) end
	if rightD then rightD:ClearAllPoints(); rightD:SetPoint("LEFT",middleD,"RIGHT",0,0) end
	if left then left:ClearAllPoints(); left:SetPoint("TOPLEFT",tab,"TOPLEFT",0,-1) end
	if middle then middle:ClearAllPoints(); middle:SetPoint("LEFT",left,"RIGHT",0,0) end
	if right then right:ClearAllPoints(); right:SetPoint("LEFT",middle,"RIGHT",0,0) end
	if tab.SocialNormal then tab.SocialNormal:Hide() end
	if tab.SocialBorder then tab.SocialBorder:Hide() end
	if tab.SocialSelected then tab.SocialSelected:Hide() end
	local highlight=tab:GetHighlightTexture()
	if highlight then highlight:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-Tab-RealHighlight"); highlight:SetBlendMode("ADD"); highlight:Show() end
	tab.FriendsFrameSocialSkin=nil
end

local function UpdateMainTabs()
	if not FriendsFrame then return end
	local previous
	for i = 1, 5 do
		local tab = _G["FriendsFrameTab"..i]
		if tab then
			RestoreMainTab(tab)
			tab:ClearAllPoints()
			if previous then tab:SetPoint("LEFT",previous,"RIGHT",-15,0)
			else tab:SetPoint("TOPLEFT",FriendsFrame,"BOTTOMLEFT",11,4) end
			previous=tab
		end
	end
end

local function SetTopTabSelected(tab, selected)
	if not tab then return end
	local name=tab:GetName()
	for _,suffix in ipairs({"Left","Middle","Right"}) do ShowIf(_G[name..suffix],not selected) end
	for _,suffix in ipairs({"LeftDisabled","MiddleDisabled","RightDisabled"}) do ShowIf(_G[name..suffix],selected) end
end

local function FlipTopTab(tab)
	if not tab then return end
	local name=tab:GetName()
	local coords={
		Left={0,0.15625,1,0}, Middle={0.15625,0.84375,1,0}, Right={0.84375,1,1,0},
		LeftDisabled={0,0.15625,0.546875,0}, MiddleDisabled={0.15625,0.84375,0.546875,0}, RightDisabled={0.84375,1,0.546875,0},
	}
	for suffix,c in pairs(coords) do local texture=_G[name..suffix]; if texture then texture:SetTexCoord(c[1],c[2],c[3],c[4]) end end
	local text=_G[name.."Text"]
	if text then text:ClearAllPoints(); text:SetPoint("CENTER",tab,"CENTER",0,-2) end
end

-- Friends / Ignore ----------------------------------------------------------
local function RefreshFriendsPanel()
	local panel = FriendsFrameSocial.panels[1]
	if not panel or not panel:IsShown() then return end
	local friends = FriendsFrameSocial.friendMode == "FRIENDS"
	local total = friends and (GetNumFriends and GetNumFriends() or 0) or (GetNumIgnores and GetNumIgnores() or 0)
	local entries = {}
	if friends then
		local online, away, offline = {}, {}, {}
		for index=1,total do
			local name, level, class, area, connected, status = GetFriendInfo(index)
			local entry={index=index,name=name,level=level,class=class,area=area,connected=connected,status=status}
			if not connected then table.insert(offline,entry) elseif status and status~="" then table.insert(away,entry) else table.insert(online,entry) end
		end
		for _,group in ipairs({online,away,offline}) do if #group>0 then if #entries>0 then group[1].separator=true end; for _,entry in ipairs(group) do table.insert(entries,entry) end end end
	else
		for index=1,total do table.insert(entries,{index=index,name=GetIgnoreName(index),ignored=true}) end
	end
	local offset = FauxScrollFrame_GetOffset(panel.Scroll)
	for i, row in ipairs(panel.Rows) do
		local entry = entries[offset+i]
		if entry then
			row.Name:ClearAllPoints()
			if friends then
				local r,g,b,classFile=GetClassColor(entry.class); ShowIf(row.Divider,entry.separator); row.Icon:Show(); row.ClassIcon:Show(); row.Name:SetPoint("TOPLEFT",row.ClassIcon,"TOPRIGHT",5,0); row.Name:SetPoint("RIGHT",row,"RIGHT",-58,0); row.Name:SetText(entry.name or ""); row.Info:SetText((entry.level and entry.level>0 and ((LEVEL or "Nivel").." "..entry.level.." "..(entry.class or "").." - ") or "")..(entry.connected and (entry.area or "") or (PLAYER_OFFLINE or "Desconectado"))); row.Icon:SetTexture(entry.connected and (FRIENDS_TEXTURE_ONLINE or "Interface\\FriendsFrame\\StatusIcon-Online") or (FRIENDS_TEXTURE_OFFLINE or "Interface\\FriendsFrame\\StatusIcon-Offline")); row.ClassIcon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"); local c=classFile and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile]; if c then row.ClassIcon:SetTexCoord(c[1],c[2],c[3],c[4]) else row.ClassIcon:SetTexCoord(0,1,0,1) end; if entry.connected then row.ClassIcon:SetVertexColor(1,1,1); row.ClassIcon:SetAlpha(1); row.Name:SetTextColor(r,g,b); row.Info:SetTextColor(.58,.58,.58) else row.ClassIcon:SetVertexColor(.3,.3,.3); row.ClassIcon:SetAlpha(.62); row.Name:SetTextColor(.34,.34,.34); row.Info:SetTextColor(.28,.28,.28) end; row.Header=nil; row.Index=entry.index; row.FriendName=entry.name; ShowIf(row.Whisper,entry.connected); ShowIf(row.Invite,entry.connected)
			else
				row.Divider:Hide(); row.Icon:Show(); row.ClassIcon:Hide(); row.Name:SetPoint("TOPLEFT",row.Icon,"TOPRIGHT",6,2); row.Name:SetPoint("RIGHT",row,"RIGHT",-58,0); row.Name:SetText(entry.name or ""); row.Info:SetText(IGNORED or IGNORE or "Ignorado"); row.Icon:SetTexture("Interface\\FriendsFrame\\StatusIcon-Offline"); row.Name:SetTextColor(1,.82,0); row.Header=nil; row.Index=entry.index; row.Whisper:Hide(); row.Invite:Hide()
			end
			row:Show()
		else
			row.Index = nil; row:Hide()
		end
	end
	FauxScrollFrame_Update(panel.Scroll, #entries, #panel.Rows, SOCIAL_ROW_HEIGHT)
	ShowIf(panel.AddFriend, friends)
	ShowIf(panel.IgnorePlayer, not friends)
	ShowIf(panel.FriendTabSelected, friends)
	ShowIf(panel.IgnoreTabSelected, not friends)
	SetTopTabSelected(panel.FriendTab,friends)
	SetTopTabSelected(panel.IgnoreTab,not friends)
	if panel.StatusDropDown then
		local status=UnitIsAFK("player") and 2 or UnitIsDND("player") and 3 or 1
		UIDropDownMenu_SetSelectedID(panel.StatusDropDown,status)
		UIDropDownMenu_SetText(panel.StatusDropDown,status==2 and (FRIENDS_LIST_AWAY or "Ausente") or status==3 and (FRIENDS_LIST_BUSY or "Ocupado") or (FRIENDS_LIST_AVAILABLE or "Disponible"))
		panel.StatusIcon:SetTexture(status==2 and FRIENDS_TEXTURE_AFK or status==3 and FRIENDS_TEXTURE_DND or FRIENDS_TEXTURE_ONLINE)
	end
end

local function BuildFriendsPanel(parent)
	local panel = NewPanel(parent, "FriendsFrameSocialFriends")
	local function subTab(id, text, x)
    	local tabName = "FriendsFrameSocialFriendsTab"..id
    	local b = CreateFrame("Button", tabName, panel, "CharacterFrameTabButtonTemplate")
    	b:SetSize(124, 32)
    	b:SetText(text)
    	b:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", x, 0)
    	FlipTopTab(b)

    	local highlight = _G[tabName.."HighlightTexture"]
    	if highlight then
        	highlight:SetTexCoord(1, 0, 1, 0)

        	highlight:ClearAllPoints()
        	highlight:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
        	highlight:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, -10)
    	end
    	return b, nil
	end
	panel.FriendTab, panel.FriendTabSelected = subTab(1,FRIENDS,42)
	panel.IgnoreTab, panel.IgnoreTabSelected = subTab(2,IGNORE,106)
	panel.FriendTab:SetScript("OnClick", function() FriendsFrameSocial.friendMode="FRIENDS"; RefreshFriendsPanel() end)
	panel.IgnoreTab:SetScript("OnClick", function() FriendsFrameSocial.friendMode="IGNORE"; RefreshFriendsPanel() end)
	panel.StatusDropDown=CreateFrame("Frame","FriendsFrameSocialStatusDropDown",panel,"UIDropDownMenuTemplate")
	panel.StatusDropDown:SetPoint("BOTTOMRIGHT",panel,"TOPRIGHT",8,3); UIDropDownMenu_SetWidth(panel.StatusDropDown,105)
	panel.StatusIcon=panel.StatusDropDown:CreateTexture(nil,"OVERLAY"); panel.StatusIcon:SetSize(12,12); panel.StatusIcon:SetPoint("LEFT",panel.StatusDropDown,"LEFT",23,1)
	UIDropDownMenu_Initialize(panel.StatusDropDown,function()
		local labels={FRIENDS_LIST_AVAILABLE,FRIENDS_LIST_AWAY,FRIENDS_LIST_BUSY}
		local icons={FRIENDS_TEXTURE_ONLINE,FRIENDS_TEXTURE_AFK,FRIENDS_TEXTURE_DND}
		for id,label in ipairs(labels) do local statusID=id; local info=UIDropDownMenu_CreateInfo(); info.text=label; info.icon=icons[id]; info.value=statusID; info.func=function() if FriendsFrame_SetOnlineStatus then FriendsFrame_SetOnlineStatus(nil,statusID) end; RefreshFriendsPanel() end; UIDropDownMenu_AddButton(info) end
	end)

	local scroll = CreateFrame("ScrollFrame", "FriendsFrameSocialFriendsScroll", panel, "FauxScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -12); scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -26, 42)
	panel.Scroll = scroll
	SetupScroll(scroll, SOCIAL_ROW_HEIGHT, RefreshFriendsPanel)
	panel.Rows = {}
	for i=1,8 do
		local row=CreateFrame("Button",nil,panel); row:SetID(i); row:SetHeight(SOCIAL_ROW_HEIGHT)
		if i==1 then row:SetPoint("TOPLEFT",scroll,"TOPLEFT",4,-5) else row:SetPoint("TOPLEFT",panel.Rows[i-1],"BOTTOMLEFT") end
		row:SetPoint("RIGHT",scroll,"RIGHT",-2,0); NewSelection(row)
		row.Icon=row:CreateTexture(nil,"OVERLAY"); row.Icon:SetSize(12,12); row.Icon:SetPoint("TOPLEFT",5,-5)
		row.ClassIcon=row:CreateTexture(nil,"OVERLAY"); row.ClassIcon:SetSize(18,18); row.ClassIcon:SetPoint("TOPLEFT",row.Icon,"TOPRIGHT",4,3)
		row.Name=row:CreateFontString(nil,"OVERLAY","GameFontNormalLarge"); row.Name:SetPoint("TOPLEFT",row.Icon,"TOPRIGHT",6,2); row.Name:SetPoint("RIGHT",-58,0); row.Name:SetJustifyH("LEFT")
		row.Info=row:CreateFontString(nil,"OVERLAY","GameFontHighlight"); row.Info:SetPoint("TOPLEFT",row.Name,"BOTTOMLEFT",0,-1); row.Info:SetPoint("RIGHT",-58,0); row.Info:SetJustifyH("LEFT")
		row.Divider=row:CreateTexture(nil,"ARTWORK"); row.Divider:SetTexture("Interface\\Buttons\\WHITE8X8"); row.Divider:SetVertexColor(1,.82,0,.28); row.Divider:SetHeight(1); row.Divider:SetPoint("TOPLEFT",6,0); row.Divider:SetPoint("TOPRIGHT",-6,0); row.Divider:Hide()
		row.BottomLine=row:CreateTexture(nil,"ARTWORK"); row.BottomLine:SetTexture("Interface\\Buttons\\WHITE8X8"); row.BottomLine:SetVertexColor(1,1,1,.07); row.BottomLine:SetHeight(1); row.BottomLine:SetPoint("BOTTOMLEFT",6,1); row.BottomLine:SetPoint("BOTTOMRIGHT",-6,1)
		row.Whisper=CreateFrame("Button",nil,row); row.Whisper:SetSize(22,22); row.Whisper:SetPoint("RIGHT",-27,0); row.Whisper:SetNormalTexture("Interface\\FriendsFrame\\BroadcastIcon"); row.Whisper:SetHighlightTexture("Interface\\FriendsFrame\\BroadcastIcon","ADD"); row.Whisper:SetScript("OnClick",function(self) local name=self:GetParent().FriendName; if name and ChatFrame_SendTell then ChatFrame_SendTell(name) end end)
		row.Invite=CreateFrame("Button",nil,row); row.Invite:SetSize(28,28); row.Invite:SetPoint("RIGHT",-3,0); row.Invite:SetNormalTexture("Interface\\FriendsFrame\\UI-Toast-FriendRequestIcon"); row.Invite:SetHighlightTexture("Interface\\FriendsFrame\\UI-Toast-FriendRequestIcon","ADD"); row.Invite:SetScript("OnClick",function(self) local name=self:GetParent().FriendName; if name and InviteUnit then InviteUnit(name) end end)
		panel.Rows[i]=row
	end
	panel.Search=CreateFrame("EditBox",nil,panel,"InputBoxTemplate"); panel.Search:SetSize(220,22); panel.Search:SetPoint("BOTTOMLEFT",panel,"BOTTOMLEFT",10,12); panel.Search:SetAutoFocus(false); panel.Search:SetText("")
	panel.AddFriend=NewButton(panel,ADD_FRIEND or "Añadir amigo",126); panel.AddFriend:SetPoint("BOTTOMRIGHT",panel,"BOTTOMRIGHT",-10,10)
	local function AddTypedFriend() local name=panel.Search:GetText(); if name and name~="" and AddFriend then AddFriend(name); panel.Search:SetText(""); panel.Search:ClearFocus() end end
	panel.Search:SetScript("OnEnterPressed",AddTypedFriend); panel.AddFriend:SetScript("OnClick",AddTypedFriend)
	panel.IgnorePlayer=NewButton(panel,IGNORE_PLAYER or "Ignorar jugador",126); panel.IgnorePlayer:SetPoint("BOTTOMRIGHT",panel,"BOTTOMRIGHT",-10,10)
	panel.IgnorePlayer:SetScript("OnClick",function()
		if UnitCanCooperate("player","target") then AddIgnore(UnitName("target")); PlaySound("UChatScrollButton") else StaticPopup_Show("ADD_IGNORE") end
	end)
	return panel
end

-- Who ----------------------------------------------------------------------
local function RefreshWhoPanel()
	local panel=FriendsFrameSocial.panels[2]; if not panel or not panel:IsShown() then return end
	local displayed,total=GetNumWhoResults and GetNumWhoResults() or 0,0
	if GetNumWhoResults then displayed,total=GetNumWhoResults() end
	if not panel.HasRequested then displayed,total=0,0 end
	total=total or displayed or 0; displayed=displayed or 0
	local offset=FauxScrollFrame_GetOffset(panel.Scroll)
	for i,row in ipairs(panel.Rows) do
		local index=offset+i
		if index<=displayed then
			local name,guild,level,race,class,zone=GetWhoInfo(index)
			local r,g,b=GetClassColor(class); row.Cells[1]:SetText(name or ""); row.Cells[1]:SetTextColor(r,g,b); row.Cells[2]:SetText(zone or ""); row.Cells[2]:SetTextColor(.68,.68,.68); row.Cells[3]:SetText(level or ""); row.Cells[3]:SetTextColor(1,1,1); row.Cells[4]:SetText(class or ""); row.Cells[4]:SetTextColor(r,g,b)
			row.Index=index; row.NameValue=name; row.Whisper:Show(); row.Invite:Show(); row:Show()
		else row.NameValue=nil; row:Hide() end
	end
	panel.Total:SetText(tostring(displayed).." / "..tostring(total))
	FauxScrollFrame_Update(panel.Scroll,displayed,#panel.Rows,SOCIAL_SMALL_ROW)
end

local function BuildWhoPanel(parent)
	local panel=NewPanel(parent,"FriendsFrameSocialWho")
	NewHeader(panel,NAME or "Name",12,92); NewHeader(panel,ZONE or "Zone",106,82); NewHeader(panel,LEVEL_ABBR or "Lvl",190,30,"CENTER"); NewHeader(panel,CLASS or "Class",222,78)
	local line=panel:CreateTexture(nil,"ARTWORK"); line:SetTexture("Interface\\Buttons\\WHITE8X8"); line:SetVertexColor(1,1,1,.12); line:SetHeight(1); line:SetPoint("TOPLEFT",8,-28); line:SetPoint("TOPRIGHT",-8,-28)
	local scroll=CreateFrame("ScrollFrame","FriendsFrameSocialWhoScroll",panel,"FauxScrollFrameTemplate"); scroll:SetPoint("TOPLEFT",8,-32); scroll:SetPoint("BOTTOMRIGHT",-26,42); panel.Scroll=scroll; SetupScroll(scroll,SOCIAL_SMALL_ROW,RefreshWhoPanel)
	panel.Rows={}
	for i=1,14 do local row=CreateFrame("Button",nil,panel); row:SetID(i); row:SetHeight(SOCIAL_SMALL_ROW); if i==1 then row:SetPoint("TOPLEFT",scroll,"TOPLEFT") else row:SetPoint("TOPLEFT",panel.Rows[i-1],"BOTTOMLEFT") end; row:SetPoint("RIGHT",scroll,"RIGHT"); NewSelection(row); row.Cells={}; local xs={4,98,182,214}; local ws={90,80,30,74}; for c=1,4 do local fs=row:CreateFontString(nil,"OVERLAY",c==1 and "GameFontNormal" or "GameFontHighlightSmall"); fs:SetPoint("LEFT",xs[c],0); fs:SetWidth(ws[c]); fs:SetJustifyH(c==3 and "CENTER" or "LEFT"); row.Cells[c]=fs end; row.Whisper=CreateFrame("Button",nil,row); row.Whisper:SetSize(20,20); row.Whisper:SetPoint("RIGHT",-25,0); row.Whisper:SetNormalTexture("Interface\\FriendsFrame\\BroadcastIcon"); row.Whisper:SetHighlightTexture("Interface\\FriendsFrame\\BroadcastIcon","ADD"); row.Whisper:SetScript("OnClick",function(self) local name=self:GetParent().NameValue; if name and ChatFrame_SendTell then ChatFrame_SendTell(name) end end); row.Invite=CreateFrame("Button",nil,row); row.Invite:SetSize(24,24); row.Invite:SetPoint("RIGHT",-3,0); row.Invite:SetNormalTexture("Interface\\FriendsFrame\\UI-Toast-FriendRequestIcon"); row.Invite:SetHighlightTexture("Interface\\FriendsFrame\\UI-Toast-FriendRequestIcon","ADD"); row.Invite:SetScript("OnClick",function(self) local name=self:GetParent().NameValue; if name and InviteUnit then InviteUnit(name) end end); row:SetScript("OnClick",function(self) FriendsFrameSocial.selectedWho=self.NameValue; RefreshWhoPanel() end); panel.Rows[i]=row end
	panel.Search=CreateFrame("EditBox",nil,panel,"InputBoxTemplate"); panel.Search:SetSize(285,22); panel.Search:SetPoint("BOTTOMLEFT",panel,"BOTTOMLEFT",8,10); panel.Search:SetAutoFocus(false); panel.Search:SetText("")
	local function RequestWho() panel.HasRequested=true; if SetWhoToUI then SetWhoToUI(1) end; if SendWho then SendWho(panel.Search:GetText() or "") end; panel.Search:ClearFocus() end
	panel.Search:SetScript("OnEnterPressed",RequestWho)
	panel.Refresh=NewButton(panel,REFRESH or "Actualizar",80); panel.Refresh:SetPoint("BOTTOMRIGHT",panel,"BOTTOMRIGHT",-8,10); panel.Refresh:SetScript("OnClick",RequestWho)
	panel.Total=panel:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); panel.Total:Hide()
	return panel
end

-- Guild --------------------------------------------------------------------
local function RefreshGuildPanel()
	local panel=FriendsFrameSocial.panels[3]; if not panel or not panel:IsShown() then return end
	-- El panel padre nunca debe dibujar un marco común alrededor de los dos containers.
	if panel.Background then panel.Background:Hide() end; if panel.Shade then panel.Shade:Hide() end; if panel.Inset then panel.Inset:Hide() end
	local total=GetNumGuildMembers and GetNumGuildMembers() or 0; local offset=FauxScrollFrame_GetOffset(panel.Scroll); local online=0
	local classCounts={}
	for n=1,total do local _,_,_,_,_,_,_,_,isOnline=GetGuildRosterInfo(n); if isOnline then online=online+1 end end
	panel.Count:SetText(online.." / "..total.." "..(GUILD_MEMBERS or "Members")); panel.GuildName:SetText((GetGuildInfo and GetGuildInfo("player")) or (GUILD or "Guild"))
	if panel.MOTD and not panel.MOTD:HasFocus() then panel.MOTD:SetText((GetGuildRosterMOTD and GetGuildRosterMOTD()) or "") end
	for n=1,total do local _,_,_,_,_,_,_,_,_,_,classFile=GetGuildRosterInfo(n); if classFile then classCounts[classFile]=(classCounts[classFile] or 0)+1 end end
	for i,row in ipairs(panel.Rows) do
		local index=offset+i
		if index<=total then
			local name,rank,_,level,class,zone,note,officerNote,isOnline,_,classFile=GetGuildRosterInfo(index)
			local color=(RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]) or {r=1,g=.82,b=0}; local alpha=isOnline and 1 or .42
			row.Name:SetText(name or ""); row.Name:SetTextColor(color.r*alpha,color.g*alpha,color.b*alpha)
			row.Level:SetText(level or ""); row.Level:SetTextColor(alpha,alpha,alpha)
			row.ClassIcon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"); local tc=CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile]; if tc then row.ClassIcon:SetTexCoord(tc[1],tc[2],tc[3],tc[4]) end; row.ClassIcon:SetDesaturated(not isOnline); row.ClassIcon:SetAlpha(alpha)
			row.Zone:SetText(zone or ""); row.Rank:SetText(rank or ""); row.Note:SetText(note or ""); row.Zone:SetAlpha(alpha); row.Rank:SetAlpha(alpha); row.Note:SetAlpha(alpha)
			row.GuildIndex=index; row.PlayerName=name; row.PublicNote=note or ""; row.OfficerNote=officerNote or ""; ShowIf(row.Selected,panel.SelectedGuildIndex==index); row:Show()
		else row:Hide() end
	end
	for classFile,button in pairs(panel.ClassButtons) do local count=classCounts[classFile] or 0; button.Count:SetText(count>0 and count or ""); button:SetAlpha(count>0 and 1 or .3) end
	local onlineMembers={}; for index=1,total do local name,_,_,_,_,_,_,_,isOnline,_,classFile=GetGuildRosterInfo(index); if name and isOnline then table.insert(onlineMembers,{name=name,classFile=classFile}) end end
	local chatOffset=panel.ChatScroll and FauxScrollFrame_GetOffset(panel.ChatScroll) or 0
	for i,row in ipairs(panel.ChatRows or {}) do
		local member=onlineMembers[chatOffset+i]
		if member then local color=(RAID_CLASS_COLORS and RAID_CLASS_COLORS[member.classFile]) or {r=1,g=.82,b=0}; row:SetText(member.name); row:SetTextColor(color.r,color.g,color.b); row:Show() else row:Hide() end
	end
	if panel.ChatScroll then FauxScrollFrame_Update(panel.ChatScroll,#onlineMembers,#panel.ChatRows,18) end
	local settingsOffset=panel.SettingsScroll and FauxScrollFrame_GetOffset(panel.SettingsScroll) or 0
	for i,row in ipairs(panel.SettingsRows or {}) do
		local index=settingsOffset+i; local name,_,_,_,_,_,_,_,isOnline,_,classFile=GetGuildRosterInfo(index)
		if name then local color=(RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]) or {r=1,g=.82,b=0}; local alpha=isOnline and 1 or .4; row.Name:SetText(name); row.Name:SetTextColor(color.r*alpha,color.g*alpha,color.b*alpha); row.GuildIndex=index; row.PlayerName=name; ShowIf(row.Selected,panel.SelectedGuildIndex==index); row:Show() else row:Hide() end
	end
	if panel.SettingsScroll then FauxScrollFrame_Update(panel.SettingsScroll,total,#panel.SettingsRows,20) end
	if panel.SelectedGuildIndex and panel.SelectedGuildIndex<=total then
		local name,_,_,_,_,_,note,officerNote=GetGuildRosterInfo(panel.SelectedGuildIndex); panel.SelectedName=name; panel.PublicNote:SetText(note or ""); panel.OfficerNote:SetText(officerNote or ""); panel.Selection:SetText(name or (SELECT_TARGET or "Selecciona un miembro"))
	else panel.SelectedGuildIndex=nil; panel.SelectedName=nil; panel.Selection:SetText(SELECT_TARGET or "Selecciona un miembro") end
	FauxScrollFrame_Update(panel.Scroll,total,#panel.Rows,SOCIAL_SMALL_ROW)
	local mode=panel.GuildMode or "MEMBERS"
	if mode~="SETTINGS" and GuildControlPopupFrame and GuildControlPopupFrame:GetParent()==panel.SettingsPage then GuildControlPopupFrame:Hide() end
	for _,object in ipairs(panel.MemberObjects or {}) do ShowIf(object,mode=="MEMBERS") end
	for _,row in ipairs(panel.Rows) do ShowIf(row,mode=="MEMBERS" and row.GuildIndex~=nil) end
	ShowIf(panel.MemberTools,mode=="SETTINGS"); ShowIf(panel.ChatPage,mode=="CHAT"); ShowIf(panel.SettingsPage,mode=="SETTINGS")
	if mode=="SETTINGS" and panel.RankDropDown and not UIDropDownMenu_GetSelectedValue(panel.RankDropDown) and GuildControlGetNumRanks and GuildControlGetNumRanks()>0 then UIDropDownMenu_SetSelectedValue(panel.RankDropDown,1); UIDropDownMenu_SetText(panel.RankDropDown,GuildControlGetRankName(1) or ""); panel.RankName:SetText(GuildControlGetRankName(1) or "") end
	if mode=="SETTINGS" and panel.PermissionChecks and GuildControlGetRankFlags then local flags={GuildControlGetRankFlags()}; for id,check in ipairs(panel.PermissionChecks) do check:SetChecked(flags[id] and true or false) end end
	for key,button in pairs(panel.ModeButtons or {}) do button:SetChecked(key==mode); if key==mode then button:LockHighlight() else button:UnlockHighlight() end end
end

local function BuildGuildPanel(parent)
	local panel=NewPanel(parent,"FriendsFrameSocialGuild")
	panel:ClearAllPoints(); panel:SetPoint("TOPLEFT",parent,"TOPLEFT",16,-66); panel:SetPoint("BOTTOMRIGHT",parent,"BOTTOMRIGHT",-16,42)
	-- Hermandad usa dos superficies independientes; el panel padre no pinta un tercer fondo común.
	panel.Background:Hide(); panel.Shade:Hide(); panel.Inset:Hide()
	local identity=CreateFrame("Frame","FriendsFrameSocialGuildIdentityContainer",panel); identity:SetPoint("TOPLEFT",8,10); identity:SetPoint("BOTTOMLEFT",8,-20); identity:SetWidth(230); AddRockBackground(identity,"FriendsFrameSocialGuildIdentityInset"); panel.IdentityContainer=identity; identity.Inset:SetFrameLevel(identity:GetFrameLevel()+10)
	local guildBlue=identity:CreateTexture(nil,"ARTWORK"); guildBlue:SetTexture("Interface\\COMMON\\bluemenu-main"); guildBlue:SetTexCoord(0.00390625,0.82421875,0.18554688,0.58984375); guildBlue:SetPoint("TOPLEFT",identity,"TOPLEFT",3,-2); guildBlue:SetPoint("BOTTOMRIGHT",identity,"BOTTOMRIGHT",-3,2); guildBlue:SetVertexColor(1,1,1,.82)
	local goldTop=identity:CreateTexture(nil,"OVERLAY"); goldTop:SetTexture("Interface\\COMMON\\bluemenu-goldborder-horiz"); goldTop:SetTexCoord(0,1,0.0078125,0.34375); goldTop:SetHeight(43); goldTop:SetPoint("TOPLEFT",identity,"TOPLEFT",3,1); goldTop:SetPoint("TOPRIGHT",identity,"TOPRIGHT",-3,1); goldTop:SetHorizTile(true)
	local goldBottom=identity:CreateTexture(nil,"OVERLAY"); goldBottom:SetTexture("Interface\\COMMON\\bluemenu-goldborder-horiz"); goldBottom:SetTexCoord(0,1,0.359375,0.6953125); goldBottom:SetHeight(43); goldBottom:SetPoint("BOTTOMLEFT",identity,"BOTTOMLEFT",3,-1); goldBottom:SetPoint("BOTTOMRIGHT",identity,"BOTTOMRIGHT",-3,-1); goldBottom:SetHorizTile(true)
	local crest=identity:CreateTexture(nil,"ARTWORK"); crest:SetTexture("Interface\\GuildFrame\\GuildLogo-NoLogo"); crest:SetSize(76,76); crest:SetPoint("TOP",0,-18)
	panel.GuildName=identity:CreateFontString(nil,"OVERLAY","GameFontNormalLarge"); panel.GuildName:SetPoint("TOP",crest,"BOTTOM",0,-5); panel.GuildName:SetWidth(194)
	panel.Count=identity:CreateFontString(nil,"OVERLAY","GameFontHighlight"); panel.Count:SetPoint("TOP",panel.GuildName,"BOTTOM",0,-6)
	local roster=CreateFrame("Frame","FriendsFrameSocialGuildContentContainer",panel); roster:SetPoint("TOPLEFT",identity,"TOPRIGHT",10,0); roster:SetPoint("BOTTOMRIGHT",panel,"BOTTOMRIGHT",-8,8); AddRockBackground(roster,"FriendsFrameSocialGuildContentInset"); panel.RosterContainer=roster; roster.Inset:SetFrameLevel(roster:GetFrameLevel()+10)
	-- Fila independiente: evita que el checkbox se mezcle con Nivel/Clase/Nombre.
	panel.ShowOffline=CreateFrame("CheckButton",nil,roster,"UICheckButtonTemplate"); panel.ShowOffline:SetSize(22,22); panel.ShowOffline:SetPoint("TOPLEFT",10,-5); local cbText=panel.ShowOffline:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); cbText:SetPoint("LEFT",panel.ShowOffline,"RIGHT",3,0); cbText:SetText(SHOW_OFFLINE_MEMBERS or "Show Offline"); panel.ShowOffline:SetScript("OnClick",function(self) if SetGuildRosterShowOffline then SetGuildRosterShowOffline(self:GetChecked() and true or false) end; if GuildRoster then GuildRoster() end end)
	panel.Count:SetText("")
	local rosterCount=roster:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); rosterCount:SetPoint("TOPRIGHT",roster,"TOPRIGHT",-14,-11); rosterCount:SetText(GUILD_ROSTER or "Lista de miembros")
	local headers={{NAME or "Nombre",6,150},{LEVEL_ABBR or "Niv",158,34},{CLASS or "Clase",194,34},{ZONE or "Zona",230,135},{RANK or "Rango",367,105},{NOTE or "Nota pública",474,150}}
	panel.MemberObjects={panel.ShowOffline,rosterCount}
	for _,h in ipairs(headers) do local label=NewHeader(roster,h[1],h[2],h[3]); label:ClearAllPoints(); label:SetPoint("TOPLEFT",roster,"TOPLEFT",h[2],-35); table.insert(panel.MemberObjects,label) end
	local headerLine=roster:CreateTexture(nil,"ARTWORK"); headerLine:SetTexture("Interface\\Buttons\\WHITE8X8"); headerLine:SetVertexColor(1,1,1,.14); headerLine:SetHeight(1); headerLine:SetPoint("TOPLEFT",roster,"TOPLEFT",6,-51); headerLine:SetPoint("TOPRIGHT",roster,"TOPRIGHT",-6,-51); table.insert(panel.MemberObjects,headerLine)
	local scroll=CreateFrame("ScrollFrame","FriendsFrameSocialGuildScroll",roster,"FauxScrollFrameTemplate"); scroll:SetPoint("TOPLEFT",8,-55); scroll:SetPoint("BOTTOMRIGHT",-26,8); panel.Scroll=scroll; SetupScroll(scroll,SOCIAL_SMALL_ROW,RefreshGuildPanel); table.insert(panel.MemberObjects,scroll)
	panel.Rows={}; for i=1,10 do
		local row=CreateFrame("Button",nil,roster); row:SetID(i); row:SetHeight(SOCIAL_SMALL_ROW); if i==1 then row:SetPoint("TOPLEFT",scroll,"TOPLEFT") else row:SetPoint("TOPLEFT",panel.Rows[i-1],"BOTTOMLEFT") end; row:SetPoint("RIGHT",scroll,"RIGHT"); NewSelection(row)
		row.Name=row:CreateFontString(nil,"OVERLAY","GameFontNormal"); row.Name:SetPoint("LEFT",6,0); row.Name:SetWidth(150); row.Name:SetJustifyH("LEFT")
		row.Level=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); row.Level:SetPoint("LEFT",158,0); row.Level:SetWidth(34); row.Level:SetJustifyH("CENTER")
		row.ClassIcon=row:CreateTexture(nil,"OVERLAY"); row.ClassIcon:SetSize(17,17); row.ClassIcon:SetPoint("LEFT",202,0)
		row.Zone=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); row.Zone:SetPoint("LEFT",230,0); row.Zone:SetWidth(135); row.Zone:SetJustifyH("LEFT")
		row.Rank=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); row.Rank:SetPoint("LEFT",367,0); row.Rank:SetWidth(105); row.Rank:SetJustifyH("LEFT")
		row.Note=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); row.Note:SetPoint("LEFT",474,0); row.Note:SetPoint("RIGHT",-5,0); row.Note:SetJustifyH("LEFT")
		row:SetScript("OnClick",function(self) panel.SelectedGuildIndex=self.GuildIndex; if SetGuildRosterSelection then SetGuildRosterSelection(self.GuildIndex or 0) end; RefreshGuildPanel() end); panel.Rows[i]=row
	end
	local tools=CreateFrame("Frame",nil,roster); tools:SetPoint("BOTTOMLEFT",8,34); tools:SetPoint("BOTTOMRIGHT",-8,8); tools:SetHeight(72); panel.MemberTools=tools
	panel.Selection=tools:CreateFontString(nil,"OVERLAY","GameFontNormal"); panel.Selection:SetPoint("TOPLEFT",8,-8); panel.Selection:SetWidth(135); panel.Selection:SetJustifyH("LEFT"); panel.Selection:SetText(SELECT_TARGET or "Selecciona un miembro")
	panel.PublicNote=NewEdgeEditBox(tools,false); panel.PublicNote:SetSize(160,22); panel.PublicNote:SetPoint("TOPLEFT",150,-5)
	panel.OfficerNote=NewEdgeEditBox(tools,false); panel.OfficerNote:SetSize(160,22); panel.OfficerNote:SetPoint("LEFT",panel.PublicNote,"RIGHT",8,0)
	local publicLabel=tools:CreateFontString(nil,"OVERLAY","GameFontDisableSmall"); publicLabel:SetPoint("TOPLEFT",panel.PublicNote,"BOTTOMLEFT",5,-1); publicLabel:SetText(NOTE or "Nota pública")
	local officerLabel=tools:CreateFontString(nil,"OVERLAY","GameFontDisableSmall"); officerLabel:SetPoint("TOPLEFT",panel.OfficerNote,"BOTTOMLEFT",5,-1); officerLabel:SetText(OFFICER_NOTE or "Nota de oficial")
	panel.SaveNotes=NewButton(tools,SAVE or "Guardar",76); panel.SaveNotes:SetPoint("TOPRIGHT",-8,-5); panel.SaveNotes:SetScript("OnClick",function() local index=panel.SelectedGuildIndex; if not index then return end; if GuildRosterSetPublicNote then GuildRosterSetPublicNote(index,panel.PublicNote:GetText() or "") end; if GuildRosterSetOfficerNote then GuildRosterSetOfficerNote(index,panel.OfficerNote:GetText() or "") end end)
	panel.Promote=NewButton(tools,PROMOTE or "Ascender",78); panel.Promote:SetPoint("BOTTOMLEFT",8,5); panel.Promote:SetScript("OnClick",function() if panel.SelectedName and GuildPromote then GuildPromote(panel.SelectedName) end end)
	panel.Demote=NewButton(tools,DEMOTE or "Degradar",78); panel.Demote:SetPoint("LEFT",panel.Promote,"RIGHT",5,0); panel.Demote:SetScript("OnClick",function() if panel.SelectedName and GuildDemote then GuildDemote(panel.SelectedName) end end)
	panel.Remove=NewButton(tools,REMOVE or "Expulsar",78); panel.Remove:SetPoint("LEFT",panel.Demote,"RIGHT",5,0); panel.Remove:SetScript("OnClick",function() if panel.SelectedName and GuildUninvite then GuildUninvite(panel.SelectedName) end end)
	panel.Invite=NewButton(tools,ADDMEMBER or INVITE or "Invitar",78); panel.Invite:SetPoint("LEFT",panel.Remove,"RIGHT",5,0); panel.Invite:SetScript("OnClick",function() StaticPopup_Show("ADD_GUILDMEMBER") end)
	panel.Control=NewButton(tools,GUILDCONTROL or "Control",92); panel.Control:SetPoint("BOTTOMRIGHT",tools,"BOTTOMRIGHT",-8,5); panel.Control:SetScript("OnClick",function() panel.GuildMode="SETTINGS"; RefreshGuildPanel() end)
	-- Resumen de clases con el mismo aro empleado por las bolsas.
	panel.ClassButtons={}; local classes={"WARRIOR","PALADIN","HUNTER","ROGUE","PRIEST","DEATHKNIGHT","SHAMAN","MAGE","WARLOCK","DRUID"}
	for i,classFile in ipairs(classes) do local button=CreateFrame("Button",nil,identity); button:SetSize(24,24); button:SetPoint("BOTTOMLEFT",identity,"BOTTOMLEFT",24+((i-1)%5)*38,170-math.floor((i-1)/5)*32); local icon=button:CreateTexture(nil,"ARTWORK"); icon:SetPoint("TOPLEFT",3,-3); icon:SetPoint("BOTTOMRIGHT",-3,3); icon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"); local tc=CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile]; if tc then icon:SetTexCoord(tc[1],tc[2],tc[3],tc[4]) end; local ring=button:CreateTexture(nil,"OVERLAY"); ring:SetTexture("Interface\\ContainerFrame\\BagSlots2x"); ring:SetSize(31,31); ring:SetTexCoord(.57421875,.693359375,0,.4911875); ring:SetPoint("CENTER"); button.Count=button:CreateFontString(nil,"OVERLAY","NumberFontNormalSmall"); button.Count:SetPoint("BOTTOMRIGHT",2,-1); button.ClassFile=classFile; button:SetScript("OnEnter",function(self) GameTooltip:SetOwner(self,"ANCHOR_TOP"); GameTooltip:SetText((LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[self.ClassFile]) or self.ClassFile); GameTooltip:Show() end); button:SetScript("OnLeave",function() GameTooltip:Hide() end); panel.ClassButtons[classFile]=button end
	panel.MOTD=NewEdgeEditBox(identity,true); panel.MOTD:SetPoint("BOTTOMLEFT",10,47); panel.MOTD:SetPoint("BOTTOMRIGHT",-10,47); panel.MOTD:SetHeight(72); panel.MOTD:SetMaxLetters(128); panel.MOTD:EnableMouse(false)
	panel.EditMOTD=NewButton(identity,EDIT or "Editar mensaje",100); panel.EditMOTD:SetPoint("BOTTOMLEFT",identity,"BOTTOMLEFT",10,13); panel.EditMOTD:SetScript("OnClick",function() panel.MOTD:EnableMouse(true); panel.MOTD:SetFocus(); panel.MOTD:HighlightText() end)
	panel.SaveMOTD=NewButton(identity,SAVE or "Guardar",92); panel.SaveMOTD:SetPoint("BOTTOMRIGHT",identity,"BOTTOMRIGHT",-10,13); panel.SaveMOTD:SetScript("OnClick",function() if GuildSetMOTD then GuildSetMOTD(panel.MOTD:GetText() or "") end; panel.MOTD:ClearFocus(); panel.MOTD:EnableMouse(false) end)
	-- Chat de hermandad integrado en el container izquierdo.
	-- Vistas del container derecho.
	panel.ChatPage=CreateFrame("Frame",nil,roster); panel.ChatPage:SetAllPoints(roster); panel.ChatPage:SetFrameLevel(roster:GetFrameLevel()+4); panel.ChatPage:Hide()
	local chatMain=CreateFrame("Frame",nil,panel.ChatPage); chatMain:SetPoint("TOPLEFT",8,-8); chatMain:SetPoint("BOTTOMRIGHT",-174,8)
	local chatMembers=CreateFrame("Frame",nil,panel.ChatPage); chatMembers:SetPoint("TOPLEFT",chatMain,"TOPRIGHT",8,0); chatMembers:SetPoint("BOTTOMRIGHT",-8,8)
	panel.GuildChat=CreateFrame("ScrollingMessageFrame",nil,chatMain); panel.GuildChat:SetPoint("TOPLEFT",8,-8); panel.GuildChat:SetPoint("BOTTOMRIGHT",-8,38); panel.GuildChat:SetFontObject(GameFontHighlightSmall); panel.GuildChat:SetJustifyH("LEFT"); panel.GuildChat:SetFading(false); panel.GuildChat:SetMaxLines(120)
	panel.ChatInput=NewEdgeEditBox(chatMain,false); panel.ChatInput:SetPoint("BOTTOMLEFT",8,10); panel.ChatInput:SetPoint("BOTTOMRIGHT",-8,10); panel.ChatInput:SetHeight(24); panel.ChatInput:SetScript("OnEnterPressed",function(self) local text=self:GetText(); if text and text~="" and SendChatMessage then SendChatMessage(text,"GUILD") end; self:SetText(""); self:ClearFocus() end)
	local onlineTitle=chatMembers:CreateFontString(nil,"OVERLAY","GameFontNormal"); onlineTitle:SetPoint("TOPLEFT",8,-9); onlineTitle:SetText(GUILD_ONLINE_LABEL or "Conectados")
	panel.ChatScroll=CreateFrame("ScrollFrame","FriendsFrameSocialGuildChatScroll",chatMembers,"FauxScrollFrameTemplate"); panel.ChatScroll:SetPoint("TOPLEFT",6,-27); panel.ChatScroll:SetPoint("BOTTOMRIGHT",-25,8); SetupScroll(panel.ChatScroll,18,RefreshGuildPanel)
	panel.ChatRows={}; for i=1,18 do local row=chatMembers:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); if i==1 then row:SetPoint("TOPLEFT",panel.ChatScroll,"TOPLEFT",2,0) else row:SetPoint("TOPLEFT",panel.ChatRows[i-1],"BOTTOMLEFT",0,-2) end; row:SetPoint("RIGHT",panel.ChatScroll,"RIGHT",-2,0); row:SetHeight(16); row:SetJustifyH("LEFT"); panel.ChatRows[i]=row end
	panel.SettingsPage=CreateFrame("Frame",nil,roster); panel.SettingsPage:SetAllPoints(roster); panel.SettingsPage:SetFrameLevel(roster:GetFrameLevel()+4); panel.SettingsPage:Hide()
	local rankPane=CreateFrame("Frame",nil,panel.SettingsPage); rankPane:SetPoint("TOPLEFT",8,-8); rankPane:SetPoint("BOTTOMRIGHT",panel.SettingsPage,"BOTTOM",-4,8)
	local memberPane=CreateFrame("Frame",nil,panel.SettingsPage); memberPane:SetPoint("TOPLEFT",panel.SettingsPage,"TOP",4,-8); memberPane:SetPoint("BOTTOMRIGHT",-8,8)
	local rankTitle=rankPane:CreateFontString(nil,"OVERLAY","GameFontNormalLarge"); rankTitle:SetPoint("TOPLEFT",12,-14); rankTitle:SetText(GUILDCONTROL)
	panel.RankDropDown=CreateFrame("Frame","FriendsFrameSocialGuildRankDropDown",rankPane,"UIDropDownMenuTemplate"); panel.RankDropDown:SetPoint("TOPLEFT",-2,-42); UIDropDownMenu_SetWidth(panel.RankDropDown,180)
	UIDropDownMenu_Initialize(panel.RankDropDown,function() for i=1,(GuildControlGetNumRanks and GuildControlGetNumRanks() or 0) do local rankIndex=i; local info=UIDropDownMenu_CreateInfo(); info.text=GuildControlGetRankName(rankIndex) or ""; info.value=rankIndex; info.func=function(self) UIDropDownMenu_SetSelectedValue(panel.RankDropDown,self.value); UIDropDownMenu_SetText(panel.RankDropDown,GuildControlGetRankName(self.value) or ""); panel.RankName:SetText(GuildControlGetRankName(self.value) or ""); if GuildControlSetRank then GuildControlSetRank(self.value) end; RefreshGuildPanel() end; UIDropDownMenu_AddButton(info) end end)
	panel.RankName=NewEdgeEditBox(rankPane,false); panel.RankName:SetPoint("TOPLEFT",14,-82); panel.RankName:SetSize(190,24)
	panel.SaveRank=NewButton(rankPane,SAVE or "Guardar rango",110); panel.SaveRank:SetPoint("TOPLEFT",14,-112); panel.SaveRank:SetScript("OnClick",function() if GuildControlSaveRank then GuildControlSaveRank(panel.RankName:GetText() or "") end end)
	panel.AddRank=NewButton(rankPane,ADD or "Añadir rango",110); panel.AddRank:SetPoint("LEFT",panel.SaveRank,"RIGHT",6,0); panel.AddRank:SetScript("OnClick",function() StaticPopup_Show("ADD_GUILDRANK") end)
	panel.RemoveRank=NewButton(rankPane,REMOVE or "Eliminar rango",110); panel.RemoveRank:SetPoint("TOPLEFT",14,-140); panel.RemoveRank:SetScript("OnClick",function() local id=UIDropDownMenu_GetSelectedValue(panel.RankDropDown); if id and GuildControlDelRank then GuildControlDelRank(GuildControlGetRankName(id)) end end)
	panel.PermissionChecks={}; for id=1,17 do local check=CreateFrame("CheckButton",nil,rankPane,"UICheckButtonTemplate"); check:SetID(id); check:SetSize(20,20); local column=(id-1)%2; local row=math.floor((id-1)/2); check:SetPoint("TOPLEFT",14+column*145,-180-row*22); local label=check:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); label:SetPoint("LEFT",check,"RIGHT",2,0); label:SetWidth(116); label:SetJustifyH("LEFT"); label:SetText(_G["GUILDCONTROL_OPTION"..id] or ((PERMISSION or "Permiso").." "..id)); check:SetScript("OnClick",function(self) if GuildControlSetRankFlag then GuildControlSetRankFlag(self:GetID(),self:GetChecked() and true or false) end end); panel.PermissionChecks[id]=check end
	local memberTitle=memberPane:CreateFontString(nil,"OVERLAY","GameFontNormalLarge"); memberTitle:SetPoint("TOPLEFT",148,-14); memberTitle:SetText(GUILD_MEMBERS or "Miembros")
	panel.SettingsScroll=CreateFrame("ScrollFrame","FriendsFrameSocialGuildSettingsScroll",memberPane,"FauxScrollFrameTemplate"); panel.SettingsScroll:SetPoint("TOPLEFT",140,-40); panel.SettingsScroll:SetPoint("BOTTOMRIGHT",-25,8); SetupScroll(panel.SettingsScroll,20,RefreshGuildPanel)
	panel.SettingsRows={}; for i=1,12 do local row=CreateFrame("Button",nil,memberPane); row:SetID(i); row:SetHeight(20); if i==1 then row:SetPoint("TOPLEFT",panel.SettingsScroll,"TOPLEFT") else row:SetPoint("TOPLEFT",panel.SettingsRows[i-1],"BOTTOMLEFT") end; row:SetPoint("RIGHT",panel.SettingsScroll,"RIGHT"); NewSelection(row); row.Name=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); row.Name:SetPoint("LEFT",5,0); row.Name:SetPoint("RIGHT",-4,0); row.Name:SetJustifyH("LEFT"); row:SetScript("OnClick",function(self) panel.SelectedGuildIndex=self.GuildIndex; if SetGuildRosterSelection then SetGuildRosterSelection(self.GuildIndex or 0) end; RefreshGuildPanel() end); panel.SettingsRows[i]=row end
	tools:SetParent(memberPane); tools:ClearAllPoints(); tools:SetPoint("TOPLEFT",8,-40); tools:SetPoint("BOTTOMLEFT",8,8); tools:SetWidth(124); tools:Show()
	panel.Selection:ClearAllPoints(); panel.Selection:SetPoint("TOPLEFT",tools,"TOPLEFT",8,-10); panel.Selection:SetWidth(108)
	panel.Promote:ClearAllPoints(); panel.Promote:SetPoint("TOPLEFT",tools,"TOPLEFT",8,-42); panel.Promote:SetWidth(108)
	panel.Demote:ClearAllPoints(); panel.Demote:SetPoint("TOPLEFT",panel.Promote,"BOTTOMLEFT",0,-5); panel.Demote:SetWidth(108)
	panel.Remove:ClearAllPoints(); panel.Remove:SetPoint("TOPLEFT",panel.Demote,"BOTTOMLEFT",0,-5); panel.Remove:SetWidth(108)
	panel.Invite:ClearAllPoints(); panel.Invite:SetPoint("TOPLEFT",panel.Remove,"BOTTOMLEFT",0,-5); panel.Invite:SetWidth(108)
	panel.PublicNote:ClearAllPoints(); panel.PublicNote:SetPoint("BOTTOMLEFT",tools,"BOTTOMLEFT",8,86); panel.PublicNote:SetSize(108,20); publicLabel:ClearAllPoints(); publicLabel:SetPoint("BOTTOMLEFT",panel.PublicNote,"TOPLEFT",3,1)
	panel.OfficerNote:ClearAllPoints(); panel.OfficerNote:SetPoint("BOTTOMLEFT",tools,"BOTTOMLEFT",8,45); panel.OfficerNote:SetSize(108,20); officerLabel:ClearAllPoints(); officerLabel:SetPoint("BOTTOMLEFT",panel.OfficerNote,"TOPLEFT",3,1)
	panel.SaveNotes:ClearAllPoints(); panel.SaveNotes:SetPoint("BOTTOMLEFT",tools,"BOTTOMLEFT",8,8); panel.SaveNotes:SetWidth(108)
	panel.Control:Hide()
	-- Notas dentro de una zona desplazable para que los textos largos no rompan el panel.
	panel.NotesScroll=CreateFrame("ScrollFrame","FriendsFrameSocialGuildNotesScroll",tools,"UIPanelScrollFrameTemplate"); panel.NotesScroll:SetPoint("BOTTOMLEFT",4,35); panel.NotesScroll:SetPoint("BOTTOMRIGHT",-22,35); panel.NotesScroll:SetHeight(92)
	local notesChild=CreateFrame("Frame","FriendsFrameSocialGuildNotesScrollChild",panel.NotesScroll); notesChild:SetSize(94,118); panel.NotesScroll:SetScrollChild(notesChild)
	panel.PublicNote:SetParent(notesChild); panel.PublicNote:ClearAllPoints(); panel.PublicNote:SetPoint("TOPLEFT",2,-18); panel.PublicNote:SetSize(88,20); publicLabel:SetParent(notesChild); publicLabel:ClearAllPoints(); publicLabel:SetPoint("TOPLEFT",2,-2)
	panel.OfficerNote:SetParent(notesChild); panel.OfficerNote:ClearAllPoints(); panel.OfficerNote:SetPoint("TOPLEFT",2,-72); panel.OfficerNote:SetSize(88,20); officerLabel:SetParent(notesChild); officerLabel:ClearAllPoints(); officerLabel:SetPoint("TOPLEFT",2,-56)
	panel.ModeButtons={}; local modes={{"MEMBERS","Interface\\Icons\\INV_Misc_GroupLooking",GUILD_ROSTER or "Miembros"},{"CHAT","Interface\\Icons\\INV_Letter_15",CHAT or "Chat"},{"SETTINGS","Interface\\Icons\\INV_Misc_Gear_01",SETTINGS or "Configuración"}}
	for i,data in ipairs(modes) do local mode=data[1]; local tooltip=data[3]; local button=CreateFrame("CheckButton",nil,parent); button:SetSize(32,32); button:SetPoint("TOPLEFT",parent,"TOPRIGHT",3,-120-(i-1)*66); button:SetFrameStrata(parent:GetFrameStrata()); button:SetFrameLevel(parent:GetFrameLevel()+20); local tabBg=button:CreateTexture(nil,"BACKGROUND"); tabBg:SetTexture("Interface\\SpellBook\\SpellBook-SkillLineTab"); tabBg:SetSize(64,64); tabBg:SetPoint("TOPLEFT",button,"TOPLEFT",-3,11); local icon=button:CreateTexture(nil,"ARTWORK"); icon:SetSize(28,28); icon:SetPoint("CENTER"); icon:SetTexture(data[2]); button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square","ADD"); button:SetCheckedTexture("Interface\\Buttons\\CheckButtonHilight","ADD"); button:SetScript("OnClick",function() panel.GuildMode=mode; RefreshGuildPanel() end); button:SetScript("OnEnter",function(self) GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:SetText(tooltip); GameTooltip:Show() end); button:SetScript("OnLeave",function() GameTooltip:Hide() end); panel.ModeButtons[mode]=button end
	panel.GuildMode="MEMBERS"
	return panel
end

-- Chat channels -------------------------------------------------------------
local function RefreshChatPanel()
	local panel=FriendsFrameSocial.panels[4]; if not panel or not panel:IsShown() then return end
	local data=GetChannelList and {GetChannelList()} or {}; local count=math.floor(#data/3); local offset=FauxScrollFrame_GetOffset(panel.Scroll)
	for i,row in ipairs(panel.Rows) do
		local index=offset+i
		if index<=count then
			local base=(index-1)*3; local channelID,name,disabled=data[base+1],data[base+2],data[base+3]
			row.Name:SetText(name or ""); row.Number:SetText(channelID or ""); row.ChannelName=name; row.ChannelID=channelID; ShowIf(row.Selected,panel.SelectedChannelID==channelID); row:Show()
		else row:Hide() end
	end
	FauxScrollFrame_Update(panel.Scroll,count,#panel.Rows,SOCIAL_SMALL_ROW)
	local members=(panel.SelectedChannelID and GetNumChannelMembers and GetNumChannelMembers(panel.SelectedChannelID)) or 0
	local playerOffset=FauxScrollFrame_GetOffset(panel.PlayerScroll)
	panel.PlayerTitle:SetText((PLAYERS or "Jugadores").." ("..members..")")
	for i,row in ipairs(panel.PlayerRows) do
		local index=playerOffset+i
		if index<=members and GetChannelRosterInfo then
			local name,owner,moderator=GetChannelRosterInfo(panel.SelectedChannelID,index)
			row.Name:SetText(name or ""); row.Icon:SetTexture(owner and "Interface\\GroupFrame\\UI-Group-LeaderIcon" or moderator and "Interface\\GroupFrame\\UI-Group-AssistantIcon" or nil); ShowIf(row.Icon,owner or moderator); row:Show()
		else row:Hide() end
	end
	FauxScrollFrame_Update(panel.PlayerScroll,members,#panel.PlayerRows,SOCIAL_SMALL_ROW)
end

local function BuildChatPanel(parent)
	local panel=NewPanel(parent,"FriendsFrameSocialChat")
	local channels=CreateFrame("Frame",nil,panel); channels:SetPoint("TOPLEFT",8,-8); channels:SetPoint("BOTTOMLEFT",8,8); channels:SetWidth(190); AddRockBackground(channels)
	local players=CreateFrame("Frame",nil,panel); players:SetPoint("TOPLEFT",channels,"TOPRIGHT",8,0); players:SetPoint("BOTTOMRIGHT",panel,"BOTTOMRIGHT",-8,8); AddRockBackground(players)
	local title=channels:CreateFontString(nil,"OVERLAY","GameFontNormal"); title:SetPoint("TOPLEFT",10,-9); title:SetText(CHANNELS or "Canales")
	panel.PlayerTitle=players:CreateFontString(nil,"OVERLAY","GameFontNormal"); panel.PlayerTitle:SetPoint("TOPLEFT",10,-9); panel.PlayerTitle:SetText(PLAYERS or "Jugadores")
	local scroll=CreateFrame("ScrollFrame","FriendsFrameSocialChatScroll",channels,"FauxScrollFrameTemplate"); scroll:SetPoint("TOPLEFT",8,-32); scroll:SetPoint("BOTTOMRIGHT",-24,42); panel.Scroll=scroll; SetupScroll(scroll,SOCIAL_SMALL_ROW,RefreshChatPanel)
	panel.Rows={}; for i=1,15 do local row=CreateFrame("Button",nil,channels); row:SetID(i); row:SetHeight(SOCIAL_SMALL_ROW); if i==1 then row:SetPoint("TOPLEFT",scroll,"TOPLEFT") else row:SetPoint("TOPLEFT",panel.Rows[i-1],"BOTTOMLEFT") end; row:SetPoint("RIGHT",scroll,"RIGHT"); NewSelection(row); row.Number=row:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); row.Number:SetPoint("LEFT",5,0); row.Number:SetWidth(20); row.Name=row:CreateFontString(nil,"OVERLAY","GameFontHighlight"); row.Name:SetPoint("LEFT",28,0); row.Name:SetPoint("RIGHT",-4,0); row.Name:SetJustifyH("LEFT"); row:SetScript("OnClick",function(self) panel.SelectedChannel=self.ChannelName; panel.SelectedChannelID=self.ChannelID; RefreshChatPanel() end); panel.Rows[i]=row end
	panel.Input=CreateFrame("EditBox",nil,channels,"InputBoxTemplate"); panel.Input:SetPoint("BOTTOMLEFT",channels,"BOTTOMLEFT",8,12); panel.Input:SetPoint("BOTTOMRIGHT",channels,"BOTTOMRIGHT",-58,12); panel.Input:SetHeight(22); panel.Input:SetAutoFocus(false)
	panel.Join=NewButton(channels,"+",42); panel.Join:SetPoint("BOTTOMRIGHT",channels,"BOTTOMRIGHT",-8,10); panel.Join:SetScript("OnClick",function() local name=panel.Input:GetText(); if name and name~="" and JoinTemporaryChannel then JoinTemporaryChannel(name) end end)
	local playerScroll=CreateFrame("ScrollFrame","FriendsFrameSocialChatPlayerScroll",players,"FauxScrollFrameTemplate"); playerScroll:SetPoint("TOPLEFT",8,-32); playerScroll:SetPoint("BOTTOMRIGHT",-24,42); panel.PlayerScroll=playerScroll; SetupScroll(playerScroll,SOCIAL_SMALL_ROW,RefreshChatPanel)
	panel.PlayerRows={}; for i=1,15 do local row=CreateFrame("Button",nil,players); row:SetHeight(SOCIAL_SMALL_ROW); if i==1 then row:SetPoint("TOPLEFT",playerScroll,"TOPLEFT") else row:SetPoint("TOPLEFT",panel.PlayerRows[i-1],"BOTTOMLEFT") end; row:SetPoint("RIGHT",playerScroll,"RIGHT"); NewSelection(row); row.Icon=row:CreateTexture(nil,"OVERLAY"); row.Icon:SetSize(14,14); row.Icon:SetPoint("LEFT",5,0); row.Name=row:CreateFontString(nil,"OVERLAY","GameFontHighlight"); row.Name:SetPoint("LEFT",24,0); row.Name:SetPoint("RIGHT",-4,0); row.Name:SetJustifyH("LEFT"); panel.PlayerRows[i]=row end
	panel.Leave=NewButton(players,LEAVE_CHANNEL or "Abandonar",100); panel.Leave:SetPoint("BOTTOMRIGHT",players,"BOTTOMRIGHT",-8,10); panel.Leave:SetScript("OnClick",function() if panel.SelectedChannel and LeaveChannelByName then LeaveChannelByName(panel.SelectedChannel) end end)
	return panel
end

-- Raid groups ---------------------------------------------------------------
local raidDragSource, raidDropTarget, raidDragGhost

local function CanManageRaidGroups()
	return ((IsRaidLeader and IsRaidLeader()) or (IsRaidOfficer and IsRaidOfficer())) and true or false
end

local function GetRaidDragGhost()
	if raidDragGhost then return raidDragGhost end
	local ghost=CreateFrame("Frame",nil,UIParent); ghost:SetFrameStrata("TOOLTIP"); ghost:SetHeight(18); ghost:EnableMouse(false); ghost:Hide()
	local bg=ghost:CreateTexture(nil,"BACKGROUND"); bg:SetAllPoints(); bg:SetTexture("Interface\\Buttons\\WHITE8X8"); bg:SetVertexColor(0,0,0,.75)
	ghost.Text=ghost:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); ghost.Text:SetPoint("CENTER")
	ghost:SetScript("OnUpdate",function(self) local x,y=GetCursorPosition(); local scale=self:GetEffectiveScale(); self:ClearAllPoints(); self:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",x/scale+14,y/scale-8) end)
	raidDragGhost=ghost; return ghost
end

local function SetRaidDropTarget(slot)
	if raidDropTarget==slot then return end
	if raidDropTarget and raidDropTarget.DropGlow then raidDropTarget.DropGlow:Hide() end
	raidDropTarget=slot
	if slot and slot.DropGlow then slot.DropGlow:Show() end
end

local function EndRaidDrag()
	SetRaidDropTarget(nil)
	if raidDragSource then raidDragSource:SetAlpha(1); raidDragSource=nil end
	if raidDragGhost then raidDragGhost:Hide() end
end

local function RaidIndexStillMatches(slot)
	if not slot or not slot.RaidIndex or not slot.PlayerName then return false end
	local name=GetRaidRosterInfo and GetRaidRosterInfo(slot.RaidIndex)
	return name==slot.PlayerName
end

local function RaidSlotDragStart(slot)
	if not slot.PlayerName or not CanManageRaidGroups() then return end
	raidDragSource=slot; slot:SetAlpha(.4)
	local ghost=GetRaidDragGhost(); ghost.Text:SetText(slot.PlayerName); ghost:SetWidth(ghost.Text:GetStringWidth()+16); ghost:Show()
end

local function RaidSlotDragStop()
	local source=raidDragSource; local target=GetMouseFocus and GetMouseFocus(); EndRaidDrag()
	if not source or not target or not target.IsRaidSlot or target.Group==source.Group or not RaidIndexStillMatches(source) then return end
	if target.PlayerName then
		if RaidIndexStillMatches(target) and SwapRaidSubgroup then SwapRaidSubgroup(source.RaidIndex,target.RaidIndex) end
	elseif SetRaidSubgroup then SetRaidSubgroup(source.RaidIndex,target.Group) end
end

local function RefreshRaidPanel()
	local panel=FriendsFrameSocial.panels[5]; if not panel or not panel:IsShown() then return end
	for _,button in pairs(panel.ClassButtons) do button.Count:SetText("") end
	for _,box in ipairs(panel.Groups) do for _,slot in ipairs(box.Slots) do slot.Name:SetText(EMPTY or "Vacío"); slot.Name:SetTextColor(.45,.45,.45); slot.Level:SetText(""); slot.Class:SetText(""); slot.Role:Hide(); slot.Ready:Hide(); slot.Selected:Hide(); slot.Unit=nil; slot.PlayerName=nil; slot.RaidIndex=nil end end
	local total=GetNumRaidMembers and GetNumRaidMembers() or 0; local positions={}; local classCounts={}
	for index=1,total do
		local name,rank,subgroup,level,class,classFile,zone,online=GetRaidRosterInfo(index)
		if subgroup and panel.Groups[subgroup] then
			positions[subgroup]=(positions[subgroup] or 0)+1; local slot=panel.Groups[subgroup].Slots[positions[subgroup]]
			if slot then
				local color=(RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]) or {r=1,g=.82,b=0}; local alpha=online and 1 or .48
				classCounts[classFile]=(classCounts[classFile] or 0)+1; slot.Unit="raid"..index; slot.PlayerName=name; slot.RaidIndex=index; slot.Rank=rank; ShowIf(slot.Selected,panel.SelectedName==name)
				slot.Name:SetText(name or ""); slot.Name:SetTextColor(color.r*alpha,color.g*alpha,color.b*alpha)
				slot.Level:SetText(level or ""); slot.Level:SetTextColor(alpha,alpha,alpha)
				slot.Class:SetText(class or ""); slot.Class:SetTextColor(color.r*alpha,color.g*alpha,color.b*alpha)
				if rank==2 then slot.Role:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon"); slot.Role:Show() elseif rank==1 then slot.Role:SetTexture("Interface\\GroupFrame\\UI-Group-AssistantIcon"); slot.Role:Show() end
				local ready=GetReadyCheckStatus and GetReadyCheckStatus(slot.Unit); if ready then slot.LastReady=ready end; ready=ready or slot.LastReady
				if ready then slot.Ready:SetTexture(ready=="ready" and (READY_CHECK_READY_TEXTURE or "Interface\\RaidFrame\\ReadyCheck-Ready") or ready=="notready" and (READY_CHECK_NOT_READY_TEXTURE or "Interface\\RaidFrame\\ReadyCheck-NotReady") or (READY_CHECK_WAITING_TEXTURE or "Interface\\RaidFrame\\ReadyCheck-Waiting")); slot.Ready:Show() end
			end
		end
	end
	for classFile,count in pairs(classCounts) do if panel.ClassButtons[classFile] then panel.ClassButtons[classFile].Count:SetText(count) end end
	panel.SelectedText:SetText(panel.SelectedName and ((PLAYER or "Jugador")..": "..panel.SelectedName) or (SELECT_TARGET or "Selecciona un miembro"))
	if panel.Convert then if total==0 and GetNumPartyMembers and GetNumPartyMembers()>0 and IsPartyLeader and IsPartyLeader() then panel.Convert:Enable() else panel.Convert:Disable() end end
end

local function NewRaidIcon(parent,texture,tooltip,onClick)
	local button=CreateFrame("Button",nil,parent); button:SetSize(24,24)
	local bg=button:CreateTexture(nil,"BACKGROUND"); bg:SetAllPoints(button); bg:SetTexture("Interface\\Buttons\\UI-Quickslot2")
	local icon=button:CreateTexture(nil,"ARTWORK"); icon:SetPoint("TOPLEFT",3,-3); icon:SetPoint("BOTTOMRIGHT",-3,3); icon:SetTexture(texture); button.Icon=icon
	button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square","ADD"); button:SetScript("OnClick",onClick)
	button:SetScript("OnEnter",function(self) GameTooltip:SetOwner(self,"ANCHOR_TOP"); GameTooltip:SetText(tooltip or ""); GameTooltip:Show() end); button:SetScript("OnLeave",function() GameTooltip:Hide() end)
	return button
end

local function BuildRaidPanel(parent)
	local panel=NewPanel(parent,"FriendsFrameSocialRaid")
	panel.InviteName=CreateFrame("EditBox",nil,panel,"InputBoxTemplate"); panel.InviteName:SetSize(112,20); panel.InviteName:SetPoint("TOPLEFT",12,-10); panel.InviteName:SetAutoFocus(false)
	panel.Invite=NewRaidIcon(panel,"Interface\\Buttons\\UI-PlusButton-Up",INVITE or "Invitar",function() local name=panel.InviteName:GetText(); if name and name~="" and InviteUnit then InviteUnit(name); panel.InviteName:SetText("") end end); panel.Invite:SetPoint("LEFT",panel.InviteName,"RIGHT",4,0); panel.InviteName:SetScript("OnEnterPressed",function() panel.Invite:Click() end)
	panel.SelectedText=panel:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); panel.SelectedText:SetPoint("TOP",panel,"TOP",-55,-13); panel.SelectedText:SetWidth(120); panel.SelectedText:SetJustifyH("CENTER")
	panel.Leader=NewRaidIcon(panel,"Interface\\GroupFrame\\UI-Group-LeaderIcon",SET_RAID_LEADER or "Convertir en líder",function() if panel.SelectedName and PromoteToLeader then PromoteToLeader(panel.SelectedName) end end); panel.Leader:SetPoint("TOP",panel,"TOP",30,-7)
	panel.Assistant=NewRaidIcon(panel,"Interface\\GroupFrame\\UI-Group-AssistantIcon",PROMOTE_TO_ASSISTANT or "Nombrar ayudante",function() if panel.SelectedName and PromoteToAssistant then PromoteToAssistant(panel.SelectedName) end end); panel.Assistant:SetPoint("LEFT",panel.Leader,"RIGHT",4,0)
	panel.Demote=NewRaidIcon(panel,"Interface\\Buttons\\UI-MinusButton-Up",DEMOTE or "Retirar ayudante",function() if panel.SelectedName and DemoteAssistant then DemoteAssistant(panel.SelectedName) end end); panel.Demote:SetPoint("LEFT",panel.Assistant,"RIGHT",4,0)
	panel.Kick=NewRaidIcon(panel,"Interface\\Buttons\\UI-GroupLoot-Pass-Up",UNINVITE or "Expulsar",function() if panel.SelectedName and UninviteUnit then UninviteUnit(panel.SelectedName) end end); panel.Kick:SetPoint("LEFT",panel.Demote,"RIGHT",4,0)
	panel.Convert=NewRaidIcon(panel,"Interface\\GroupFrame\\UI-Group-LeaderIcon",CONVERT_TO_RAID or "Convertir en banda",function() if ConvertToRaid then ConvertToRaid() end end); panel.Convert:SetPoint("BOTTOM",panel,"TOP",-30,4)
	panel.Ready=NewRaidIcon(panel,READY_CHECK_READY_TEXTURE or "Interface\\RaidFrame\\ReadyCheck-Ready",READY_CHECK or "Comprobación de banda",function() for _,box in ipairs(panel.Groups) do for _,slot in ipairs(box.Slots) do slot.LastReady=slot.Unit and "waiting" or nil end end; if DoReadyCheck then DoReadyCheck() end; RefreshRaidPanel() end); panel.Ready:SetPoint("LEFT",panel.Convert,"RIGHT",5,0)
	panel.Leave=NewRaidIcon(panel,"Interface\\Buttons\\UI-Panel-MinimizeButton-Up",LEAVE_PARTY or "Abandonar grupo",function() if LeaveParty then LeaveParty() end end); panel.Leave:SetPoint("LEFT",panel.Ready,"RIGHT",5,0)
	panel.Groups={}
	for group=1,8 do
		local box=CreateFrame("Frame",nil,panel); local column=(group-1)%2; local rowIndex=math.floor((group-1)/2); box:SetPoint("TOPLEFT",panel,"TOPLEFT",10+column*247,-44-rowIndex*82); box:SetSize(239,76); AddRockBackground(box)
		box.Header=box:CreateTexture(nil,"ARTWORK"); box.Header:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight"); box.Header:SetBlendMode("ADD"); box.Header:SetVertexColor(1,.72,0,.42); box.Header:SetPoint("TOPLEFT",2,-2); box.Header:SetPoint("TOPRIGHT",-2,-2); box.Header:SetHeight(18)
		box.Title=box:CreateFontString(nil,"OVERLAY","GameFontNormal"); box.Title:SetPoint("TOPLEFT",8,-4); box.Title:SetText((GROUP or "Grupo").." "..group); box.Slots={}
		for slotIndex=1,5 do
			local slot=CreateFrame("Button",nil,box); slot:SetPoint("TOPLEFT",box,"TOPLEFT",6,-20-(slotIndex-1)*11); slot:SetPoint("RIGHT",box,"RIGHT",-6,0); slot:SetHeight(11); slot.Group=group; slot.IsRaidSlot=true; slot:RegisterForDrag("LeftButton"); NewSelection(slot); slot:SetScript("OnClick",function(self) if self.PlayerName then panel.SelectedName=self.PlayerName; RefreshRaidPanel() end end); slot:SetScript("OnDragStart",RaidSlotDragStart); slot:SetScript("OnDragStop",RaidSlotDragStop); slot:SetScript("OnEnter",function(self) if raidDragSource and raidDragSource.Group~=self.Group then SetRaidDropTarget(self) end end); slot:SetScript("OnLeave",function(self) if raidDropTarget==self then SetRaidDropTarget(nil) end end)
			slot.DropGlow=slot:CreateTexture(nil,"OVERLAY"); slot.DropGlow:SetAllPoints(); slot.DropGlow:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight"); slot.DropGlow:SetBlendMode("ADD"); slot.DropGlow:SetVertexColor(.2,1,.25,.65); slot.DropGlow:Hide()
			slot.Role=slot:CreateTexture(nil,"OVERLAY"); slot.Role:SetSize(11,11); slot.Role:SetPoint("LEFT",0,0); slot.Role:Hide()
			slot.Name=slot:CreateFontString(nil,"OVERLAY","GameFontHighlight"); slot.Name:SetPoint("LEFT",slot.Role,"RIGHT",3,0); slot.Name:SetWidth(105); slot.Name:SetJustifyH("LEFT"); slot.Name:SetText(EMPTY or "Vacío")
			slot.Level=slot:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); slot.Level:SetPoint("LEFT",125,0); slot.Level:SetWidth(22); slot.Level:SetJustifyH("RIGHT")
			slot.Class=slot:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); slot.Class:SetPoint("LEFT",153,0); slot.Class:SetPoint("RIGHT",-14,0); slot.Class:SetJustifyH("LEFT")
			slot.Ready=slot:CreateTexture(nil,"OVERLAY"); slot.Ready:SetSize(12,12); slot.Ready:SetPoint("RIGHT",0,0); slot.Ready:Hide()
			box.Slots[slotIndex]=slot
		end
		panel.Groups[group]=box
	end
	panel.ClassButtons={}; local classes={"WARRIOR","PALADIN","HUNTER","ROGUE","PRIEST","DEATHKNIGHT","SHAMAN","MAGE","WARLOCK","DRUID"}
	for i,classFile in ipairs(classes) do local button=CreateFrame("Button",nil,panel); button:SetSize(24,24); button:SetPoint("TOPLEFT",panel,"BOTTOMLEFT",116+(i-1)*29,-8); local icon=button:CreateTexture(nil,"ARTWORK"); icon:SetPoint("TOPLEFT",3,-3); icon:SetPoint("BOTTOMRIGHT",-3,3); icon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"); local c=CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile]; if c then icon:SetTexCoord(c[1],c[2],c[3],c[4]) end; local ring=button:CreateTexture(nil,"OVERLAY"); ring:SetTexture("Interface\\ContainerFrame\\BagSlots2x"); ring:SetSize(31,31); ring:SetTexCoord(.57421875,.693359375,0,.4911875); ring:SetPoint("CENTER"); button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Round","ADD"); button.Count=button:CreateFontString(nil,"OVERLAY","NumberFontNormalSmall"); button.Count:SetPoint("BOTTOMRIGHT",2,-1); button.ClassFile=classFile; button:SetScript("OnEnter",function(self) GameTooltip:SetOwner(self,"ANCHOR_TOP"); GameTooltip:SetText((LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[self.ClassFile]) or self.ClassFile); GameTooltip:Show() end); button:SetScript("OnLeave",function() GameTooltip:Hide() end); panel.ClassButtons[classFile]=button end
	return panel
end

local function InitializeFriendsFrameSocial()
	local frame=FriendsFrame; if not frame or frame.FriendsFrameSocialInitialized then return end
	if frame.NoaBackground then frame.NoaBackground:Hide() end
	if frame.NoaListFill then frame.NoaListFill:Hide() end; if frame.NoaListInset then frame.NoaListInset:Hide() end; if frame.NoaGuildDetailFill then frame.NoaGuildDetailFill:Hide() end; if frame.NoaGuildDetailInset then frame.NoaGuildDetailInset:Hide() end
	for i=1,5 do RestoreMainTab(_G["FriendsFrameTab"..i]) end
	FriendsFrameSocial.panels[1]=BuildFriendsPanel(frame); FriendsFrameSocial.panels[2]=BuildWhoPanel(frame); FriendsFrameSocial.panels[3]=BuildGuildPanel(frame)
	FriendsFrameSocial.panels[4]=BuildChatPanel(frame)
	FriendsFrameSocial.panels[5]=BuildRaidPanel(frame)
	-- Estos controles nativos eran responsables de los botones duplicados y
	-- de restos flotantes cuando otra actualización intentaba mostrarlos.
	local nativeNames={"FriendsListFrame","IgnoreListFrame","PendingListFrame","WhoFrame","GuildFrame","ChannelFrame","RaidFrame","RaidInfoFrame","FriendsFrameStatusDropDown","FriendsFrameAddFriendButton","FriendsFrameSendMessageButton","FriendsFrameIgnorePlayerButton","FriendsFrameUnsquelchButton","WhoFrameGroupInviteButton","WhoFrameAddFriendButton"}
	for _,nativeName in ipairs(nativeNames) do local native=_G[nativeName]
		if native and native.HookScript then native:HookScript("OnShow",function(self) self:Hide() end); native:Hide() end
	end
	frame:HookScript("OnShow",function() FriendsFrameSocial.Update() end)
	-- Marcar al final: si alguna dependencia falta, un nuevo intento puede
	-- completar la construcción en lugar de dejar el frame a medias.
	frame.FriendsFrameSocialInitialized=true
end

function FriendsFrameSocial.Update()
	InitializeFriendsFrameSocial()
	local frame=FriendsFrame; if not frame then return end
	local selected=frame.selectedTab or 1
	frame:SetSize(selected==3 and SOCIAL_GUILD_WIDTH or selected==5 and SOCIAL_RAID_WIDTH or SOCIAL_COMPACT_WIDTH,SOCIAL_HEIGHT)
	-- Neutraliza la primera capa experimental anterior; no debe reaparecer
	-- cuando el actualizador nativo cambia de pestaña.
	if frame.NoaListFill then frame.NoaListFill:Hide() end
	if frame.NoaBackground then frame.NoaBackground:Hide() end
	if frame.NoaListInset then frame.NoaListInset:Hide() end
	if frame.NoaGuildDetailFill then frame.NoaGuildDetailFill:Hide() end
	if frame.NoaGuildDetailInset then frame.NoaGuildDetailInset:Hide() end
	if GuildMemberDetailFrame then GuildMemberDetailFrame:Hide() end
	-- Las páginas nativas conservan sus funciones, pero no deben dibujarse
	-- debajo de las reconstrucciones (especialmente ChannelFrame/RaidFrame).
	ShowIf(ChannelFrame,false); ShowIf(RaidFrame,false); ShowIf(RaidInfoFrame,false)
	ShowIf(FriendsFrameAddFriendButton,false); ShowIf(FriendsFrameSendMessageButton,false); ShowIf(FriendsFrameUnsquelchButton,false)
	ShowIf(WhoFrameGroupInviteButton,false); ShowIf(WhoFrameAddFriendButton,false)
	ShowIf(FriendsFrameStatusDropDown,false)
	local titles={FRIENDS_LIST or FRIENDS or "Friends List",WHO_LIST or WHO or "Who",GUILD or "Guild",CHAT_CHANNELS or CHAT or "Chat",RAID or "Raid"}
	local title=frame.TitleText or _G[frame:GetName().."TitleText"]
	if title then title:SetText(titles[selected] or SOCIALS or "Social") end
	for i,panel in ipairs(FriendsFrameSocial.panels) do ShowIf(panel,i==selected) end
	local guildPanel=FriendsFrameSocial.panels[3]
	if guildPanel then for _,button in pairs(guildPanel.ModeButtons or {}) do ShowIf(button,selected==3) end end
	-- Native pages stay alive for their handlers but do not paint behind the NewEra pages.
	ShowIf(FriendsTabHeader,false); ShowIf(WhoFrame,false); ShowIf(GuildFrame,false); ShowIf(ChannelFrame,false); ShowIf(RaidFrame,false); ShowIf(RaidInfoFrame,false)
	UpdateMainTabs()
	if selected==1 then RefreshFriendsPanel()
	elseif selected==2 then RefreshWhoPanel()
	elseif selected==3 then
		if FriendsFrameSocial.lastSelectedTab~=3 and GuildRoster then GuildRoster() end
		RefreshGuildPanel()
	elseif selected==4 then RefreshChatPanel()
	elseif selected==5 then RefreshRaidPanel()
	end
	if selected~=3 and GuildControlPopupFrame and FriendsFrameSocial.panels[3] and GuildControlPopupFrame:GetParent()==FriendsFrameSocial.panels[3].SettingsPage then GuildControlPopupFrame:Hide() end
	-- Algunas actualizaciones nativas vuelven a mostrar sus controles durante
	-- ShowFriends/RaidFrame_Update; se neutralizan al final del mismo ciclo.
	ShowIf(FriendsListFrame,false); ShowIf(IgnoreListFrame,false); ShowIf(PendingListFrame,false)
	ShowIf(WhoFrame,false); ShowIf(GuildFrame,false); ShowIf(ChannelFrame,false); ShowIf(RaidFrame,false); ShowIf(RaidInfoFrame,false)
	ShowIf(FriendsFrameAddFriendButton,false); ShowIf(FriendsFrameSendMessageButton,false); ShowIf(FriendsFrameIgnorePlayerButton,false); ShowIf(FriendsFrameUnsquelchButton,false)
	ShowIf(WhoFrameGroupInviteButton,false); ShowIf(WhoFrameAddFriendButton,false); ShowIf(FriendsFrameStatusDropDown,false)
	FriendsFrameSocial.lastSelectedTab=selected
end

local NativeFriendsFrameUpdate=FriendsFrame_Update
function FriendsFrame_Update(...)
	NativeFriendsFrameUpdate(...)
	FriendsFrameSocial.Update()
end

local events=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_LOGIN","FRIENDLIST_UPDATE","IGNORELIST_UPDATE","WHO_LIST_UPDATE","GUILD_ROSTER_UPDATE","PLAYER_GUILD_UPDATE","CHAT_MSG_GUILD","CHAT_MSG_OFFICER","RAID_ROSTER_UPDATE","PARTY_MEMBERS_CHANGED","CHANNEL_UI_UPDATE","READY_CHECK","READY_CHECK_CONFIRM","READY_CHECK_FINISHED"}) do pcall(events.RegisterEvent,events,event) end
events:SetScript("OnEvent",function(_,event,message,sender)
	if event=="PLAYER_LOGIN" then InitializeFriendsFrameSocial() end
	if (event=="CHAT_MSG_GUILD" or event=="CHAT_MSG_OFFICER") and FriendsFrameSocial.panels[3] and FriendsFrameSocial.panels[3].GuildChat then
		local prefix=event=="CHAT_MSG_OFFICER" and "|cff40c040[O]|r " or "|cff40ff40[H]|r "
		FriendsFrameSocial.panels[3].GuildChat:AddMessage(prefix..(sender or "")..": "..(message or ""))
	end
	if FriendsFrame and FriendsFrame:IsShown() then FriendsFrameSocial.Update() end
end)
