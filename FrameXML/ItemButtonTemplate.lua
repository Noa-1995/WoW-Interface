local ItemQuality = {
	Poor = 0,
	Common = 1,
	Uncommon = 2,
	Rare = 3,
	Epic = 4,
	Legendary = 5,
	Artifact = 6,
}

function SetItemButtonQuality(button, quality)
	if button:GetAttribute("useCircularIconBorder") then
		button.IconBorder:Show();

		if quality == ItemQuality.Poor then
			button.IconBorder:SetAtlasTex("auctionhouse-itemicon-border-gray");
		elseif quality == ItemQuality.Common then
			button.IconBorder:SetAtlasTex("auctionhouse-itemicon-border-white");
		elseif quality == ItemQuality.Uncommon then
			button.IconBorder:SetAtlasTex("auctionhouse-itemicon-border-green");
		elseif quality == ItemQuality.Rare then
			button.IconBorder:SetAtlasTex("auctionhouse-itemicon-border-blue");
		elseif quality == ItemQuality.Epic then
			button.IconBorder:SetAtlasTex("auctionhouse-itemicon-border-purple");
		elseif quality == ItemQuality.Legendary then
			button.IconBorder:SetAtlasTex("auctionhouse-itemicon-border-orange");
		elseif quality == ItemQuality.Artifact then
			button.IconBorder:SetAtlasTex("auctionhouse-itemicon-border-artifact");
		else
			button.IconBorder:Hide();
		end

		return;
	end

	if quality then
		if BAG_ITEM_QUALITY_COLORS[quality] then
			if button.IconBorder then
				button.IconBorder:Show();
				button.IconBorder:SetVertexColor(BAG_ITEM_QUALITY_COLORS[quality].r, BAG_ITEM_QUALITY_COLORS[quality].g, BAG_ITEM_QUALITY_COLORS[quality].b);
			end
		else
			button.IconBorder:Hide();
		end
	else
		button.IconBorder:Hide();
	end
end

function SetItemButtonCount(button, count)
	if ( not button ) then
		return;
	end

	if ( not count ) then
		count = 0;
	end

	button.count = count;
	local countString = button.Count or _G[button:GetName().."Count"];
	if ( count > 1 or (button.isBag and count > 0) ) then
		if ( count > (button.maxDisplayCount or 9999) ) then
			count = "*";
		end
		countString:SetText(count);
		countString:Show();
	else
		countString:Hide();
	end
end

function SetItemButtonStock(button, numInStock)
	if ( not button ) then
		return;
	end

	if ( not numInStock ) then
		numInStock = "";
	end

	button.numInStock = numInStock;
	if ( numInStock > 0 ) then
		_G[button:GetName().."Stock"]:SetFormattedText(MERCHANT_STOCK, numInStock);
		_G[button:GetName().."Stock"]:Show();
	else
		_G[button:GetName().."Stock"]:Hide();
	end
end

function SetItemButtonTexture(button, texture)
	if ( not button ) then
		return;
	end

	local icon = button.Icon or button.icon or _G[button:GetName().."IconTexture"];
	if ( texture ) then
		icon:Show();
	else
		icon:Hide();
	end

	if button:GetAttribute("useCircularIconBorder") then
		SetPortraitToTexture(icon, texture);
	else
		SetPortraitToTexture(icon, "");
		icon:SetTexture(texture);
	end
end

function SetItemButtonTextureVertexColor(button, r, g, b)
	if ( not button ) then
		return;
	end

	local icon = button.Icon or button.icon or _G[button:GetName().."IconTexture"];
	icon:SetVertexColor(r, g, b);
end

function SetItemButtonDesaturated(button, desaturated, r, g, b)
	if ( not button ) then
		return;
	end
	local icon = button.Icon or button.icon or _G[button:GetName().."IconTexture"];
	if ( not icon ) then
		return;
	end
	local shaderSupported = icon:SetDesaturated(desaturated);

	if ( not desaturated ) then
		r = 1.0;
		g = 1.0;
		b = 1.0;
	elseif ( not r or not shaderSupported ) then
		r = 0.5;
		g = 0.5;
		b = 0.5;
	end
	
	icon:SetVertexColor(r, g, b);
end

function SetItemButtonNormalTextureVertexColor(button, r, g, b)
	if ( not button ) then
		return;
	end
	
	_G[button:GetName().."NormalTexture"]:SetVertexColor(r, g, b);
end

function SetItemButtonNameFrameVertexColor(button, r, g, b)
	if ( not button ) then
		return;
	end

	local nameFrame = button.NameFrame or _G[button:GetName().."NameFrame"];
	nameFrame:SetVertexColor(r, g, b);
end

function SetItemButtonSlotVertexColor(button, r, g, b)
	if ( not button ) then
		return;
	end
	
	_G[button:GetName().."SlotTexture"]:SetVertexColor(r, g, b);
end

function HandleModifiedItemClick(link)
	if ( IsModifiedClick("CHATLINK") ) then
		if ( ChatEdit_InsertLink(link) ) then
			return true;
		end
	end
	if ( IsModifiedClick("DRESSUP") ) then
		DressUpItemLink(link);
		return true;
	end
	return false;
end
