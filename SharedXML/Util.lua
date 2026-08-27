function SetClampedTextureRotation(texture, rotationDegrees)
	if (rotationDegrees ~= 0 and rotationDegrees ~= 90 and rotationDegrees ~= 180 and rotationDegrees ~= 270) then
		error("SetRotation: rotationDegrees must be 0, 90, 180, or 270");
		return;
	end

	if not (texture.rotationDegrees) then
		texture.origTexCoords = {texture:GetTexCoord()};
		texture.origWidth = texture:GetWidth();
		texture.origHeight = texture:GetHeight();
	end

	if (texture.rotationDegrees == rotationDegrees) then
		return;
	end

	texture.rotationDegrees = rotationDegrees;

	if (rotationDegrees == 0 or rotationDegrees == 180) then
		texture:SetWidth(texture.origWidth);
		texture:SetHeight(texture.origHeight);
	else
		texture:SetWidth(texture.origHeight);
		texture:SetHeight(texture.origWidth);
	end

	if (rotationDegrees == 0) then
		texture:SetTexCoord( texture.origTexCoords[1], texture.origTexCoords[2],
											texture.origTexCoords[3], texture.origTexCoords[4],
											texture.origTexCoords[5], texture.origTexCoords[6],
											texture.origTexCoords[7], texture.origTexCoords[8] );
	elseif (rotationDegrees == 90) then
		texture:SetTexCoord( texture.origTexCoords[3], texture.origTexCoords[4],
											texture.origTexCoords[7], texture.origTexCoords[8],
											texture.origTexCoords[1], texture.origTexCoords[2],
											texture.origTexCoords[5], texture.origTexCoords[6] );
	elseif (rotationDegrees == 180) then
		texture:SetTexCoord( texture.origTexCoords[7], texture.origTexCoords[8],
											texture.origTexCoords[5], texture.origTexCoords[6],
											texture.origTexCoords[3], texture.origTexCoords[4],
											texture.origTexCoords[1], texture.origTexCoords[2] );
	elseif (rotationDegrees == 270) then
		texture:SetTexCoord( texture.origTexCoords[5], texture.origTexCoords[6],
											texture.origTexCoords[1], texture.origTexCoords[2],
											texture.origTexCoords[7], texture.origTexCoords[8],
											texture.origTexCoords[3], texture.origTexCoords[4] );
	end
end

function tCount( t )
	t = t or {}
	local i = 0
	for k in pairs(t) do i = i + 1 end
	return i
end

function tContains(table, item)
	local index = 1;
	while table[index] do
		if (item and item == table[index] ) then
			return true;
		end
		index = index + 1;
	end
	return false;
end

-- Round to the nearest interger
function math.Round( num, idp )
	local mult = 10 ^ ( idp or 0 )
	return math.floor( num * mult + 0.5 ) / mult
end

-- https://gist.github.com/gdeglin/4128882
-- returns the number of bytes used by the UTF-8 character at byte i in s
-- also doubles as a UTF-8 character validator
function utf8charbytes(s, i)
    -- argument defaults
    i = i or 1
    local c = string.byte(s, i)
    -- determine bytes needed for character, based on RFC 3629
    if c > 0 and c <= 127 then
        -- UTF8-1
        return 1
    elseif c >= 194 and c <= 223 then
        -- UTF8-2
        local c2 = string.byte(s, i + 1)
        return 2
    elseif c >= 224 and c <= 239 then
        -- UTF8-3
        local c2 = s:byte(i + 1)
        local c3 = s:byte(i + 2)
        return 3
    elseif c >= 240 and c <= 244 then
        -- UTF8-4
        local c2 = s:byte(i + 1)
        local c3 = s:byte(i + 2)
        local c4 = s:byte(i + 3)
        return 4
    end
end

-- returns the number of characters in a UTF-8 string
function utf8len(s)
    local pos = 1
    local bytes = string.len(s)
    local len = 0

    while pos <= bytes and len ~= chars do
        local c = string.byte(s,pos)
        len = len + 1

        pos = pos + utf8charbytes(s, pos)
    end

    if chars ~= nil then
        return pos - 1
    end

    return len
end

local string = string
local math = math

function string.ToTable( str )
	local tbl = {}

	for i = 1, string.len( str ) do
		tbl[i] = string.sub( str, i, i )
	end

	return tbl
end

local totable = string.ToTable
local string_sub = string.sub
local string_find = string.find
local string_len = string.len

function string.Explode(separator, str, withpattern)
    if ( separator == "" ) then return totable( str ) end
    if ( withpattern == nil ) then withpattern = false end

    local ret = {}
    local current_pos = 1

    for i = 1, string_len( str ) do
        local start_pos, end_pos = string_find( str, separator, current_pos, not withpattern )
        if ( not start_pos ) then break end
        ret[ i ] = string_sub( str, current_pos, start_pos - 1 )
        if ret[ i ] == "" then
            ret[ i ] = nil
        end
        current_pos = end_pos + 1
    end

    ret[ #ret + 1 ] = string_sub( str, current_pos )
    if ret[ #ret ] == "" then
        ret[ #ret ] = nil
    end

    return ret
end

function C_Split( str, delimiter )
    return string.Explode( delimiter, str )
end

function C_InRange( value, min, max )
	return value and value >= min and value <= max or false
end

function Lerp(startValue, endValue, amount)
	return (1 - amount) * startValue + amount * endValue;
end

function Clamp(value, min, max)
	if value > max then
		return max;
	elseif value < min then
		return min;
	end
	return value;
end

function Saturate(value)
	return Clamp(value, 0.0, 1.0);
end

function GetClassFile( classFileLocale )
	local classFileName

	for classfileMale, classlocaleMale in pairs(LOCALIZED_CLASS_NAMES_MALE) do
		if classfileMale and classlocaleMale == classFileLocale then
			classFileName = classfileMale
			break
		end
	end

	for classfileFemale, classlocaleFemale in pairs(LOCALIZED_CLASS_NAMES_FEMALE) do
		if classfileFemale and classlocaleFemale == classFileLocale then
			classFileName = classfileFemale
			break
		end
	end

	return classFileName
end

function WrapTextInColorTableCode(text, colorHexString)
	return ("|c%s%s|r"):format(colorHexString, text);
end

-- Colors
ColorMixinTable = {}
function CreateColorRGB(r, g, b, a)
	local color = CreateFromMixins(ColorMixinTable)
	color:OnLoad(r, g, b, a)
	return color
end

function AreColorsEqual(left, right)
	if left and right then
		return left:IsEqualTo(right)
	end
	return left == right
end

function ColorMixinTable:OnLoad(r, g, b, a)
	self:SetRGBA(r, g, b, a)
end

function ColorMixinTable:IsEqualTo(otherColor)
	return self.r == otherColor.r
		and self.g == otherColor.g
		and self.b == otherColor.b
		and self.a == otherColor.a
end

function ColorMixinTable:GetRGB()
	return self.r, self.g, self.b
end

function ColorMixinTable:GetRGBAsBytes()
	return math.Round(self.r * 255), math.Round(self.g * 255), math.Round(self.b * 255)
end

function ColorMixinTable:GetRGBA()
	return self.r, self.g, self.b, self.a
end

function ColorMixinTable:GetRGBAAsBytes()
	return math.Round(self.r * 255), math.Round(self.g * 255), math.Round(self.b * 255), math.Round((self.a or 1) * 255)
end

function ColorMixinTable:SetRGBA(r, g, b, a)
	self.r = r
	self.g = g
	self.b = b
	self.a = a
end

function ColorMixinTable:SetRGB(r, g, b)
	self:SetRGBA(r, g, b, nil)
end

function ColorMixinTable:ConvertToGameRGB()
	self:SetRGBA(self.r / 255, self.g / 255, self.b / 255, self.a)
	return self
end

function ColorMixinTable:GenerateHexColors()
	return ("ff%.2x%.2x%.2x"):format(self:GetRGBAsBytes())
end

function ColorMixinTable:GenerateHexColorMarkup()
	return "|c"..self:GenerateHexColors()
end

function ColorMixinTable:WrapTextInColorTableCode(text)
	return WrapTextInColorTableCode(text, self:GenerateHexColors())
end

local RAID_CLASS_COLORS = {
	["HUNTER"] = CreateColorRGB(0.67, 0.83, 0.45),
	["WARLOCK"] = CreateColorRGB(0.58, 0.51, 0.79),
	["PRIEST"] = CreateColorRGB(1.0, 1.0, 1.0),
	["PALADIN"] = CreateColorRGB(0.96, 0.55, 0.73),
	["MAGE"] = CreateColorRGB(0.41, 0.8, 0.94),
	["ROGUE"] = CreateColorRGB(1.0, 0.96, 0.41),
	["DRUID"] = CreateColorRGB(1.0, 0.49, 0.04),
	["SHAMAN"] = CreateColorRGB(0.0, 0.44, 0.87),
	["WARRIOR"] = CreateColorRGB(0.78, 0.61, 0.43),
	["DEATHKNIGHT"] = CreateColorRGB(0.77, 0.12 , 0.23),
};

for _, v in pairs(RAID_CLASS_COLORS) do
	v.colorStr = v:GenerateHexColors()
end

function GetClassColor(classFilename)
	local color = RAID_CLASS_COLORS[classFilename]
	if color then
		return color.r, color.g, color.b, color.colorStr
	end

	return 1, 1, 1, "ffffffff";
end

function GetClassColorObj(classFilename)
	return RAID_CLASS_COLORS[classFilename]
end

function SetParentArrayFrame(frame, parentArray, value)
	assert(frame)

	if not frame:GetParent()[parentArray] then
		frame:GetParent()[parentArray] = {}
	end

	table.insert(frame:GetParent()[parentArray], value)
	return frame:GetParent()[parentArray]
end