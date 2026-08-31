-- C_Specialization.lua
-- Get specialization name for all classes

local CLASS_SPECIALIZATION_TITLE = {
	DEATHKNIGHT = { DEATHKNIGHT_SPEC_BLOOD_TITLE, DEATHKNIGHT_SPEC_FROST_TITLE, DEATHKNIGHT_SPEC_UNHOLY_TITLE },
	DRUID = { DRUID_SPEC_BALANCE_TITLE, DRUID_SPEC_FERAL_TITLE, DRUID_SPEC_RESTORATION_TITLE },
	HUNTER = { HUNTER_SPEC_BEASTMASTERY_TITLE, HUNTER_SPEC_MARKSMANSHIP_TITLE, HUNTER_SPEC_SURVIVAL_TITLE },
	MAGE = { MAGE_SPEC_ARCANE_TITLE, MAGE_SPEC_FIRE_TITLE, MAGE_SPEC_FROST_TITLE },
	PALADIN = { PALADIN_SPEC_HOLY_TITLE, PALADIN_SPEC_PROTECTION_TITLE, PALADIN_SPEC_RETRIBUTION_TITLE },
	PRIEST = { PRIEST_SPEC_DISCIPLINE_TITLE, PRIEST_SPEC_HOLY_TITLE, PRIEST_SPEC_SHADOW_TITLE },
	ROGUE = { ROGUE_SPEC_ASSASSINATION_TITLE, ROGUE_SPEC_COMBAT_TITLE, ROGUE_SPEC_SUBTLETY_TITLE },
	SHAMAN = { SHAMAN_SPEC_ELEMENTAL_TITLE, SHAMAN_SPEC_ENHANCEMENT_TITLE, SHAMAN_SPEC_RESTORATION_TITLE },
	WARLOCK = { WARLOCK_SPEC_AFFLICTION_TITLE, WARLOCK_SPEC_DEMONOLOGY_TITLE, WARLOCK_SPEC_DESTRUCTION_TITLE },
	WARRIOR = { WARRIOR_SPEC_ARMS_TITLE, WARRIOR_SPEC_FURY_TITLE, WARRIOR_SPEC_PROTECTION_TITLE }
};

local function GetTalentSpecInfo(isInspect)
	local talantGroup = GetActiveTalentGroup(isInspect);
	local maxPoints, specIndex, specName, specIcon = 0, 0;

	for index=1, MAX_TALENT_TABS do
		local name, icon, pointsSpent = GetTalentTabInfo(index, isInspect, nil, talantGroup);
		if (maxPoints < pointsSpent) then
			maxPoints = pointsSpent;
			specIndex = index;
			specName = name;
			specIcon = icon;
		end
	end

	if (not specName) then specName = "" end
	if (not specIcon) then specIcon = nil end

	return specIndex, specName, specIcon;
end

function GetSpecName()
	local specIndex, specName = GetTalentSpecInfo();
	local class, classFileName = UnitClass("player");
	if (specIndex and specIndex ~= 0) and (specName and specName ~= "") then
		return CLASS_SPECIALIZATION_TITLE[classFileName][specIndex]
	else
		return ""
	end
end

function GetInspectSpecName(unit)
	local specIndex, specName = GetTalentSpecInfo(true);
	local class, classFileName = UnitClass(unit);
	if (specIndex and specIndex ~= 0) and (specName and specName ~= "") then
		return CLASS_SPECIALIZATION_TITLE[classFileName][specIndex]
	else
		return ""
	end
end

-- override some icons like in retail
local function ConvertIconBySpecName()
	local name = GetSpecName();
	local _,_,icon = GetTalentSpecInfo();
	if name == SHAMAN_SPEC_ENHANCEMENT_TITLE then
		icon = "Interface\\Icons\\spell_shaman_improvedstormstrike"
	elseif name == HUNTER_SPEC_BEASTMASTERY_TITLE then
		icon = "Interface\\Icons\\ability_hunter_bestialdiscipline"
	elseif name == HUNTER_SPEC_MARKSMANSHIP_TITLE then
		icon = "Interface\\Icons\\ability_hunter_focusedaim"
	elseif name == HUNTER_SPEC_SURVIVAL_TITLE then
		icon = "Interface\\Icons\\ability_hunter_camouflage"
	elseif name == ROGUE_SPEC_ASSASSINATION_TITLE then
		icon = "Interface\\Icons\\ability_rogue_deadlybrew"
	elseif name == ROGUE_SPEC_COMBAT_TITLE then
		icon = "Interface\\Icons\\ability_rogue_waylay"
	elseif name == PALADIN_SPEC_PROTECTION_TITLE then
		icon = "Interface\\Icons\\ability_paladin_shieldofthetemplar"
	elseif name == WARRIOR_SPEC_ARMS_TITLE then
		icon = "Interface\\Icons\\ability_warrior_savageblow"
	end
	return icon;
end

function SetSpecializationTexturePortrait()
 	local specIndex, specName = GetTalentSpecInfo();
	if (specIndex and specIndex ~= 0) and (specName and specName ~= "") then
		local icon = ConvertIconBySpecName()
		CharacterFramePortrait:SetTexCoord(0, 1, 0, 1);
		SetPortraitToTexture(CharacterFramePortrait, icon);	
	else
		SetPortraitTexture(CharacterFrame.portrait, "player");
	end
end