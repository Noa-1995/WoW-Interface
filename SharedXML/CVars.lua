local bitband, bitbnot, bitbor, bitlshift = bit.band, bit.bnot, bit.bor, bit.lshift

local GetCVar = GetCVar
local SetCVar = SetCVar

function GetCVarBitfield(name, index)
	local value = GetCVar(name)
	if value then
		value = tonumber(value) or 0
		return bitband(value, bitlshift(1, index - 1)) ~= 0
	end
end

function SetCVarBitfield(name, index, value, scriptCvar)
	local currentValue = tonumber(GetCVar(name)) or 0
	if ValueToBoolean(value) then
		value = bitbor(currentValue, bitlshift(1, index - 1))
	else
		value = bitband(currentValue, bitbnot(bitlshift(1, index - 1)))
	end

	SetCVar(name, value, scriptCvar)
end

if IsOnGlueScreen() then
	RegisterCVar2("Sound_EnableGluaMusic", "1", 0x40)
else
	RegisterCVar2("showCustomTutorials", "1", 0x20)
	RegisterCVar2("tutorialsFlagged", "", 0x20)
	RegisterCVar2("tutorialsFlagged2", "", 0x20)
	RegisterCVar2("lastSeenBrawlID", "", 0x20)
end