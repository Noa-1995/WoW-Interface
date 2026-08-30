-- C_Traits Stub API for WotLK HD Client
-- Returns empty/default data so TalentUI loads without errors
-- Will be replaced with actual WotLK talent data integration later

C_Traits = C_Traits or {};

function C_Traits.GetNodeInfo(configID, nodeID)
	return {
		ID = nodeID or 0,
		posX = 0,
		posY = 0,
		type = 0,
		maxRanks = 1,
		activeRank = 0,
		currentRank = 0,
		flags = 0,
		entryIDs = {},
		entryIDsWithCommittedRanks = {},
		activeEntry = nil,
		nextEntry = nil,
		isAvailable = false,
		canPurchaseRank = false,
		canRefundRank = false,
		isVisible = true,
		isCascadeRepurchasable = false,
		cascadeRepurchaseEntryID = nil,
		subTreeID = nil,
		subTreeActive = false,
		meetsEdgeRequirements = true,
		conditionIDs = {},
		edgeIDs = {},
		groupIDs = {},
		visibleEdges = {},
		ranksPurchased = 0,
		isGhosted = false,
	};
end

function C_Traits.GetDefinitionInfo(definitionID)
	return {
		spellID = 0,
		overrideName = "",
		overrideSubtext = "",
		overrideDescription = "",
		overrideIcon = nil,
		subType = nil,
	};
end

function C_Traits.GetEntryInfo(configID, entryID)
	return {
		definitionID = 0,
		type = 0,
		maxRanks = 1,
		isAvailable = false,
		entryCost = {},
	};
end

function C_Traits.GetConditionInfo(configID, condID, ignoreFontColor)
	return {
		isAlwaysMet = false,
		isMet = false,
		isSufficient = false,
		type = 0,
		questID = nil,
		achievementID = nil,
		specSetID = nil,
		playerLevel = nil,
		spentAmountRequired = 0,
		tooltipFormat = "",
	};
end

function C_Traits.GetSubTreeInfo(configID, subTreeID)
	return {
		ID = subTreeID or 0,
		name = "",
		description = "",
		iconElementID = "",
		traitCurrencyID = 0,
		isActive = false,
	};
end

function C_Traits.GetTreeInfo(configID, treeID)
	return {
		ID = treeID or 0,
		minZoom = 1,
		maxZoom = 1,
		buttonSize = 40,
	};
end

function C_Traits.GetTreeCurrencyInfo(configID, treeID, excludeStagedChanges)
	return {};
end

function C_Traits.GetTreeNodes(treeID)
	return {};
end

function C_Traits.CommitConfig(configID)
	return true;
end

function C_Traits.RollbackConfig(configID)
	return true;
end

function C_Traits.PurchaseRank(configID, nodeID)
	return true;
end

function C_Traits.CascadeRepurchaseRanks(configID, nodeID)
	return true;
end

function C_Traits.RefundRank(configID, nodeID)
	return true;
end

function C_Traits.RefundAllRanks(configID, nodeID)
	return true;
end

function C_Traits.SetSelection(configID, nodeID, entryID)
	return true;
end

function C_Traits.ClearCascadeRepurchaseHistory(configID)
end

function C_Traits.GetNodeCost(configID, nodeID)
	return {};
end

function C_Traits.GetIncreasedTraitData(nodeID, entryID)
	return {};
end

function C_Traits.ConfigHasStagedChanges(configID)
	return false;
end
