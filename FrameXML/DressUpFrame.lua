UIPanelWindows["DressUpFrame"] = { area = "left", pushable = 2, xOffset = "15", yOffset = "-15" };

function DressUpItemLink(link)
	if IsAddOnLoaded("ezCollections") then return; end
	if ( not link or not IsDressableItem(link) ) then
		return;
	end
	
	if ( DressUpModel.isCreature ) then
		pretty_DressUpFrame.ResetButton:SetText(RESET);
		DressUpModel.disabledZooming = nil;
		DressUpModel:SetUnit("player", true);
		DressUpModel.isCreature = false;
		DressUpModel.petID = nil;
		DressUpModel.index = nil;
	end

	if ( not DressUpFrame:IsShown() ) then
		ShowUIPanel(DressUpFrame);
		DressUpModel:SetUnit("player", true);
	end
	DressUpModel:TryOn(link);
end

function DressUpTexturePath()
	return GetDressUpTexturePath("player")
end

function GetDressUpTexturePath( unit )
	local race, fileName = UnitRace(unit or "player")

	if not fileName then
		fileName = "Orc"
	end

	return "Interface\\DressUpFrame\\DressUpBackground-"..fileName;
end

function GetDressUpTextureAlpha( unit )
	local race, fileName = UnitRace(unit or "player")

	if string.upper(fileName) == "BLOODELF" then
		return 0.8
	elseif string.upper(fileName) == "NIGHTELF" then
		return 0.6
	elseif string.upper(fileName) == "SCOURGE" then
		return 0.3
	elseif string.upper(fileName) == "TROLL" or string.upper(fileName) == "ORC" then
		return 0.6
	else
		return 0.7
	end
end

function DressUpFrame_OnLoad(self, ...)
	local _, classFileName = UnitClass("player")
	DressUpModel.ModelBackground:SetAtlasTex("dressingroom-background-"..string.lower(classFileName), true)
	
	self.TitleText:SetText(DRESSUP_FRAME)
end
