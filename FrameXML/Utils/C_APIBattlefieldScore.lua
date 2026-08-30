C_BattlefieldScoreManagerMixin = {};

function C_BattlefieldScoreManagerMixin:OnLoad()
	self._GetBattlefieldScore = GetBattlefieldScore;
	self._GetNumBattlefieldScores = GetNumBattlefieldScores;
	self._SetBattlefieldScoreFaction = SetBattlefieldScoreFaction;

	self.scoreData = {};
	self.selectedFaction = nil;
end

---@return boolean isValidation
function C_BattlefieldScoreManagerMixin:IsValidation()
	local inInstance, instanceType = IsInInstance()
	local isArena = IsActiveBattlefieldArena()
	return ((inInstance == 1 and instanceType == "pvp") and not isArena)
end

local factions = { ["Horde"] = 67, ["Alliance"] = 469 };

function C_BattlefieldScoreManagerMixin:GenerateScoreData()
	self.scoreData = {};
	for i = 1, self._GetNumBattlefieldScores() do
		local name, killingBlows, honorableKills, deaths, honorGained, faction, rank, race, class, classToken, damageDone, healingDone = self._GetBattlefieldScore(i);
		local additionalStatData = {}

		if self:IsValidation() then
			local factionID = unpack(factions);
			for statID = 1, GetNumBattlefieldStats() do
				table.insert(additionalStatData, GetBattlefieldStatData(i, statID));
			end

			if factionID then
				local GUID = UnitGUID(name);
				if GUID then
					faction = factionID;
				else
					faction = factionID == PLAYER_FACTION_GROUP.Alliance and PLAYER_FACTION_GROUP.Horde or PLAYER_FACTION_GROUP.Alliance
				end
			end
		end

		if not self.selectedFaction or self.selectedFaction == faction then
			table.insert(self.scoreData, {name, killingBlows, honorableKills, deaths, honorGained, faction, rank, race, class, classToken, damageDone, healingDone, additionalStatData})
		end
	end
end

---@return number numScoreData
function C_BattlefieldScoreManagerMixin:GetNumScoreData()
	return #self.scoreData
end

---@param factionID number
function C_BattlefieldScoreManagerMixin:SetFaction( factionID )
	self.selectedFaction = factionID
	self:GenerateScoreData()

	self._SetBattlefieldScoreFaction(nil)
end

---@param index number
---@return table scoreData
function C_BattlefieldScoreManagerMixin:GetScoreData( index )
	if #self.scoreData == 0 then
		self:GenerateScoreData()
	end

	if index and self.scoreData[index] then
		return self.scoreData[index]
	end
end

function C_BattlefieldScoreManagerMixin:UPDATE_BATTLEFIELD_SCORE()
	self:GenerateScoreData();
end

---@class C_BattlefieldScoreManagerMixin
C_BattlefieldScoreManager = CreateFromMixins(C_BattlefieldScoreManagerMixin)
C_BattlefieldScoreManager:OnLoad();

local _SetBattlefieldScoreFaction = _SetBattlefieldScoreFaction or SetBattlefieldScoreFaction;

function SetBattlefieldScoreFaction( factionID )
	if C_BattlefieldScoreManager:IsValidation() then
		C_BattlefieldScoreManager:SetFaction( factionID )
	else
		_SetBattlefieldScoreFaction( factionID )
	end
end

local _GetNumBattlefieldScores = _GetNumBattlefieldScores or GetNumBattlefieldScores;

function GetNumBattlefieldScores()
	if C_BattlefieldScoreManager:IsValidation() then
		return C_BattlefieldScoreManager:GetNumScoreData();
	else
		return _GetNumBattlefieldScores();
	end
end

local _GetBattlefieldScore = _GetBattlefieldScore or GetBattlefieldScore;

function GetBattlefieldScore( index )
	if C_BattlefieldScoreManager:IsValidation() then
		return unpack(C_BattlefieldScoreManager:GetScoreData( index ) or {})
	else
		return _GetBattlefieldScore( index )
	end
end