PortraitFrameMixin = {};

function PortraitFrameMixin:SetBorder(layoutName)
	local layout = NineSliceUtils.GetLayout(layoutName);
	NineSliceUtils.ApplyLayout(self.NineSlice, layout);
end

function PortraitFrameMixin:SetPortraitToAsset(texture)
	SetPortraitToTexture(self.portrait, texture);
end

function PortraitFrameMixin:SetPortraitToUnit(unit)
	SetPortraitTexture(self.portrait, unit);
end

function PortraitFrameMixin:SetPortraitTextureRaw(texture)
	self.portrait:SetTexture(texture);
end

function PortraitFrameMixin:SetPortraitAtlasRaw(atlas, ...)
	self.portrait:SetAtlasTex(atlas, ...);
end

function PortraitFrameMixin:SetPortraitTexCoord(...)
	self.portrait:SetTexCoord(...);
end

function PortraitFrameMixin:SetPortraitShown(shown)
	self.portrait:SetFrameShown(shown);
end

function PortraitFrameMixin:SetTitleColor(color)
	self.TitleText:SetTextColor(color:GetRGBA());
end

function PortraitFrameMixin:SetTitle(title)
	self.TitleText:SetText(title);
end

function PortraitFrameMixin:SetTitleFormatted(fmt, ...)
	self.TitleText:SetFormattedText(fmt, ...);
end

function PortraitFrameMixin:SetTitleMaxLinesAndHeight(maxLines, height)
	self.TitleText:SetMaxLines(maxLines);
	self.TitleText:SetHeight(height);
end
