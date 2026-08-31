-- Keep the native talent button, but stop it from loading Blizzard_TalentUI over this frame.
function TalentFrame_LoadUI()
    return true
end

-- GlyphFrame is bundled with TalentRetail, so the stock load-on-demand addon
-- must not create a second copy of the same global frames.
function GlyphFrame_LoadUI()
    return true
end

local function DisableUnsupportedTalentRetailControls()
    if not PlayerTalentFrame then
        return
    end

    local controls = {
        PlayerTalentFrame.CurrencySelectFrame,
        PlayerTalentFrame.ResetTalentGroupButton,
        PlayerTalentFrame.ScreenshotButton,
        PlayerTalentFrame.ImportFrameButton,
        PlayerTalentPopupFrame,
    }

    for _, control in ipairs(controls) do
        if control then
            control:Hide()
        end
    end

    if PlayerTalentFrame.specPurchaseButton then
        PlayerTalentFrame.specPurchaseButton:Hide()
        PlayerTalentFrame.specPurchaseButton:SetScript("OnShow", function(self) self:Hide() end)
    end
end

DisableUnsupportedTalentRetailControls()

if PlayerTalentPopupFrame then
    PlayerTalentPopupFrame:SetScript("OnShow", function(self)
        self:Hide()
    end)
end

if PlayerTalentFrame then
    PlayerTalentFrame:HookScript("OnShow", DisableUnsupportedTalentRetailControls)
end
