-- Native Wrath compatibility layer for the three-tree talent interface.
local NativeGetActiveTalentGroup = GetActiveTalentGroup
local NativeGetNumTalentGroups = GetNumTalentGroups
local NativeSetActiveTalentGroup = SetActiveTalentGroup

S_RESET_FRAME_STATE_TIME = S_RESET_FRAME_STATE_TIME or 900
TALENT_LOADING_LABEL = TALENT_LOADING_LABEL or "Loading talents..."
TALENT_FRAME_PET_HELPBOX = TALENT_FRAME_PET_HELPBOX or "This page displays your pet's talents."
TALENT_TAB_NAME = TALENT_TAB_NAME or "Talent Specialization %d"
CLICK_TALENT_TAB_SETTING = "Click to view this specialization."
TALENTS_SECOND_SPEC_HINT = TALENTS_SECOND_SPEC_HINT or "Dual Specialization"
TALENTS_SECOND_SPEC_LOW_LEVEL_HINT = TALENTS_SECOND_SPEC_LOW_LEVEL_HINT or "Reach level 40 to unlock Dual Specialization."
TALENTS_SECOND_SPEC_LEARN_HINT = TALENTS_SECOND_SPEC_LEARN_HINT or "Dual Specialization lets you switch between two talent and glyph sets."
TALENTS_SECOND_SPEC_CLICK_HINT = TALENTS_SECOND_SPEC_CLICK_HINT or "Visit a class trainer to learn Dual Specialization."
TALENTS_SHOW_SUMMARIES = TALENTS_SHOW_SUMMARIES or "Summaries"
TALENT_FRAME_POPUP_TEXT = TALENT_FRAME_POPUP_TEXT or "Enter a name for this talent set:"
TALENT_LOADING_LABEL = TALENT_LOADING_LABEL or "Loading talents..."
TALENT_SPEC_RESET = TALENT_SPEC_RESET or RESET
TALENT_TOOLTIP_RESET_LEARNED_TALENTGROUP = TALENT_TOOLTIP_RESET_LEARNED_TALENTGROUP or "Reset learned talents."
TALENT_TOOLTIP_RESET_LEARNED_TALENTGROUP_NOT_ENOUGH_MONEY = TALENT_TOOLTIP_RESET_LEARNED_TALENTGROUP_NOT_ENOUGH_MONEY or "Talents can only be reset through a class trainer."
TALENT_TOOLTIP_RESET_LEARNED_TALENTGROUP_PRICE = TALENT_TOOLTIP_RESET_LEARNED_TALENTGROUP_PRICE or "Reset cost: %s"
TALENT_HEADER_SUMMARY_TOOLTIP_HEADER = TALENT_HEADER_SUMMARY_TOOLTIP_HEADER or "Specialization Summary"
TALENT_HEADER_SUMMARY_TOOLTIP = TALENT_HEADER_SUMMARY_TOOLTIP or "Show or hide the specialization summary."
TALENT_IMPORT_TOOLTIP_NAME = TALENT_IMPORT_TOOLTIP_NAME or "Import build"
TALENT_IMPORT_TOOLTIP_TEXT = TALENT_IMPORT_TOOLTIP_TEXT or "Build import is unavailable on this realm."
TALENT_GET_HYPERLINK_DROPDOWN_TITLE = TALENT_GET_HYPERLINK_DROPDOWN_TITLE or "Link talents"
TALENT_GET_URL_ADRESS_DROPDOWN_TITLE = TALENT_GET_URL_ADRESS_DROPDOWN_TITLE or "Web link"
TALENTS_ACTIVE_BUTTON_DESC = TALENTS_ACTIVE_BUTTON_DESC or "Activate this specialization."
TALENTS_ACTIVE_BUTTON_DISABLE_REASON_1 = TALENTS_ACTIVE_BUTTON_DISABLE_REASON_1 or "This specialization cannot be activated right now."
TALENTS_ACTIVE_BUTTON_DISABLE_REASON_2 = TALENTS_ACTIVE_BUTTON_DISABLE_REASON_2 or TALENTS_ACTIVE_BUTTON_DISABLE_REASON_1
TALENTS_EXPORT_INGAMELINK_POPUP = TALENTS_EXPORT_INGAMELINK_POPUP or "Talent link"
TALENTS_EXPORT_URL_POPUP = TALENTS_EXPORT_URL_POPUP or "Talent URL"
PLAYER_TALENT_PREVIEW_TITLE = PLAYER_TALENT_PREVIEW_TITLE or "Talent Preview"
PLAYER_TALENT_PREVIEW_PLAYER_TITLE = PLAYER_TALENT_PREVIEW_PLAYER_TITLE or "%s's Talent Preview"
PLAYER_TALENT_LEARN_PREVIEW_TEXT_NO_PAY = PLAYER_TALENT_LEARN_PREVIEW_TEXT_NO_PAY or "Learn these talents?"
PLAYER_TALENT_LEARN_PREVIEW_TEXT_PAY = PLAYER_TALENT_LEARN_PREVIEW_TEXT_PAY or PLAYER_TALENT_LEARN_PREVIEW_TEXT_NO_PAY
LINK_TALENTS_PREVIEW_TOOLTIP = LINK_TALENTS_PREVIEW_TOOLTIP or "Preview this talent build."
PLAYER_UNSPENT_TALENT_POINTS = PLAYER_UNSPENT_TALENT_POINTS or "Unspent Talent Points: %d"
PET_UNSPENT_TALENT_POINTS = PET_UNSPENT_TALENT_POINTS or "Pet Unspent Talent Points: %d"
PREVIEW_UNSPENT_TALENT_POINTS = PREVIEW_UNSPENT_TALENT_POINTS or "Preview Points Remaining: %d"
MAJOR_GLYPHS = MAJOR_GLYPHS or "Major Glyphs"
MINOR_GLYPHS = MINOR_GLYPHS or "Minor Glyphs"
PET_TALENTS = PET_TALENTS or "Pet Talents"
TRADESKILL_POST = TRADESKILL_POST or "Post in Chat"
CONFIRM_TALENT_WIPE_DIRECT = CONFIRM_TALENT_WIPE_DIRECT or "Are you sure you want to unlearn all of your talents?"

EasingUtil = EasingUtil or {}
EasingUtil.OutSine = EasingUtil.OutSine or function(elapsed, startValue, change, duration)
    return change * math.sin(elapsed / duration * (math.pi / 2)) + startValue
end

if not UIDropDownMenu_AddSeparator then
    function UIDropDownMenu_AddSeparator()
    end
end

if not SetParentFrameLevel then
    function SetParentFrameLevel(frame, offset)
        if frame and frame.GetParent and frame:GetParent() then
            frame:SetFrameLevel(frame:GetParent():GetFrameLevel() + (offset or 1))
        end
    end
end

function TalentRetail_SetShown(frame, shown)
    if not frame then
        return
    end

    if shown then
        frame:Show()
    else
        frame:Hide()
    end
end

function TalentRetail_SetEnabled(frame, enabled)
    if not frame then
        return
    end

    if enabled then
        frame:Enable()
    else
        frame:Disable()
    end
end

function TalentRetail_GetClassColoredText(classFilename)
    local text = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classFilename]) or classFilename or ""
    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFilename]
    if not color then
        return text
    end

    local colorCode = color.colorStr
    if not colorCode then
        colorCode = string.format(
            "ff%02x%02x%02x",
            math.floor((color.r or 1) * 255 + 0.5),
            math.floor((color.g or 1) * 255 + 0.5),
            math.floor((color.b or 1) * 255 + 0.5)
        )
    elseif string.len(colorCode) == 6 then
        colorCode = "ff" .. colorCode
    end

    return "|c" .. colorCode .. text .. "|r"
end

if not MagicButton_OnLoad then
    function MagicButton_OnLoad(button)
        local leftHandled = false
        local rightHandled = false

        for index = 1, button:GetNumPoints() do
            local point, relativeTo, relativePoint, offsetX, offsetY = button:GetPoint(index)
            local relativeType = relativeTo and relativeTo.GetObjectType and relativeTo:GetObjectType()

            if relativeType == "Button" and (point == "TOPLEFT" or point == "LEFT") then
                if offsetX == 0 and offsetY == 0 then
                    button:SetPoint(point, relativeTo, relativePoint, 1, 0)
                end

                button.LeftSeparator = relativeTo.RightSeparator or button:CreateTexture(button:GetName() and button:GetName() .. "_LeftSeparator" or nil, "BORDER")
                relativeTo.RightSeparator = button.LeftSeparator
                button.LeftSeparator:SetTexture("Interface\\TalentRetail\\TalentRetailFrameParts")
                button.LeftSeparator:SetTexCoord(0.00781250, 0.10937500, 0.75781250, 0.95312500)
                button.LeftSeparator:SetWidth(13)
                button.LeftSeparator:SetHeight(25)
                button.LeftSeparator:SetPoint("TOPRIGHT", button, "TOPLEFT", 5, 1)
                leftHandled = true
            elseif relativeType == "Button" and (point == "TOPRIGHT" or point == "RIGHT") then
                if offsetX == 0 and offsetY == 0 then
                    button:SetPoint(point, relativeTo, relativePoint, -1, 0)
                end

                button.RightSeparator = relativeTo.LeftSeparator or button:CreateTexture(button:GetName() and button:GetName() .. "_RightSeparator" or nil, "BORDER")
                relativeTo.LeftSeparator = button.RightSeparator
                button.RightSeparator:SetTexture("Interface\\TalentRetail\\TalentRetailFrameParts")
                button.RightSeparator:SetTexCoord(0.00781250, 0.10937500, 0.75781250, 0.95312500)
                button.RightSeparator:SetWidth(13)
                button.RightSeparator:SetHeight(25)
                button.RightSeparator:SetPoint("TOPLEFT", button, "TOPRIGHT", -5, 1)
                rightHandled = true
            elseif point == "BOTTOMLEFT" then
                if offsetX == 0 and offsetY == 0 then
                    button:SetPoint(point, relativeTo, relativePoint, 4, 4)
                end
                leftHandled = true
            elseif point == "BOTTOMRIGHT" then
                if offsetX == 0 and offsetY == 0 then
                    button:SetPoint(point, relativeTo, relativePoint, -6, 4)
                end
                rightHandled = true
            elseif point == "BOTTOM" and offsetY == 0 then
                button:SetPoint(point, relativeTo, relativePoint, 0, 4)
            end
        end

        if not leftHandled and not button.LeftSeparator then
            button.LeftSeparator = button:CreateTexture(button:GetName() and button:GetName() .. "_LeftSeparator" or nil, "BORDER")
            button.LeftSeparator:SetTexture("Interface\\TalentRetail\\TalentRetailFrameParts")
            button.LeftSeparator:SetTexCoord(0.24218750, 0.32812500, 0.63281250, 0.82812500)
            button.LeftSeparator:SetWidth(11)
            button.LeftSeparator:SetHeight(25)
            button.LeftSeparator:SetPoint("TOPRIGHT", button, "TOPLEFT", 6, 1)
        end

        if not rightHandled and not button.RightSeparator then
            button.RightSeparator = button:CreateTexture(button:GetName() and button:GetName() .. "_RightSeparator" or nil, "BORDER")
            button.RightSeparator:SetTexture("Interface\\TalentRetail\\TalentRetailFrameParts")
            button.RightSeparator:SetTexCoord(0.90625000, 0.99218750, 0.00781250, 0.20312500)
            button.RightSeparator:SetWidth(11)
            button.RightSeparator:SetHeight(25)
            button.RightSeparator:SetPoint("TOPLEFT", button, "TOPRIGHT", -6, 1)
        end
    end
end

if not ButtonFrameTemplate_HideButtonBar then
    function ButtonFrameTemplate_HideButtonBar(frame)
        if not frame then
            return
        end

        local inset = frame.Inset or _G[frame:GetName() .. "Inset"]
        if inset then
            inset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 4)
        end

        TalentRetail_SetShown(_G[frame:GetName() .. "BtnCornerLeft"], false)
        TalentRetail_SetShown(_G[frame:GetName() .. "BtnCornerRight"], false)
        TalentRetail_SetShown(_G[frame:GetName() .. "ButtonBottomBorder"], false)
    end
end

if not ButtonFrameTemplate_ShowButtonBar then
    function ButtonFrameTemplate_ShowButtonBar(frame)
        if not frame then
            return
        end

        local inset = frame.Inset or _G[frame:GetName() .. "Inset"]
        if inset then
            inset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 26)
        end

        TalentRetail_SetShown(_G[frame:GetName() .. "BtnCornerLeft"], true)
        TalentRetail_SetShown(_G[frame:GetName() .. "BtnCornerRight"], true)
        TalentRetail_SetShown(_G[frame:GetName() .. "ButtonBottomBorder"], true)
    end
end

if not MicroButtonPulseStop then
    function MicroButtonPulseStop()
    end
end

if not SearchBoxTemplate_OnTextChanged then
    function SearchBoxTemplate_OnTextChanged()
    end
end

if not GetTexCoordsForRoleSmallCircle then
    function GetTexCoordsForRoleSmallCircle(role)
        if role == "TANK" then
            return 0, 19 / 64, 22 / 64, 41 / 64
        elseif role == "HEALER" then
            return 20 / 64, 39 / 64, 1 / 64, 20 / 64
        elseif role == "DAMAGER" then
            return 20 / 64, 39 / 64, 22 / 64, 41 / 64
        end

        error("Unknown role: " .. tostring(role))
    end
end

if not GetTexCoordsForRoleSmall then
    function GetTexCoordsForRoleSmall(role)
        if role == "TANK" then
            return 0.5, 0.75, 0, 1
        elseif role == "HEALER" then
            return 0.75, 1, 0, 1
        elseif role == "DAMAGER" then
            return 0.25, 0.5, 0, 1
        end

        error("Unknown role: " .. tostring(role))
    end
end

TALENT_RETAIL_INFO = TALENT_RETAIL_INFO or {
    default = {
        [1] = { color = { r = 1.0, g = 0.72, b = 0.1 }, Description = "Develop this talent tree to unlock its defining abilities and bonuses." },
        [2] = { color = { r = 1.0, g = 0.0, b = 0.0 }, Description = "Develop this talent tree to unlock its defining abilities and bonuses." },
        [3] = { color = { r = 0.3, g = 0.5, b = 1.0 }, Description = "Develop this talent tree to unlock its defining abilities and bonuses." },
    },
    PET_409 = {
        [1] = { color = { r = 1.0, g = 0.1, b = 1.0 } },
    },
    PET_410 = {
        [1] = { color = { r = 1.0, g = 0.0, b = 0.0 } },
    },
    PET_411 = {
        [1] = { color = { r = 0.0, g = 0.6, b = 1.0 } },
    },
    DEATHKNIGHT = {
        [1] = {
            ActiveBonus = { 55262 },
            PassiveBonus = { 50029, 49395, 53138 },
            Description = "A dark guardian who withstands enemy attacks or strikes with brutal weapons while sustaining himself with stolen life energy.",
            color = { r = 1.0, g = 0.0, b = 0.0 },
            role1 = "TANK", role2 = "DAMAGER",
        },
        [2] = {
            ActiveBonus = { 55268 },
            PassiveBonus = { 54637, 66192, 51130 },
            Description = "An icy harbinger of doom who channels runic power into relentless weapon strikes and freezing attacks.",
            color = { r = 0.3, g = 0.5, b = 1.0 },
            role1 = "TANK", role2 = "DAMAGER",
        },
        [3] = {
            ActiveBonus = { 55271 },
            PassiveBonus = { 51161, 56835, 49655 },
            Description = "A master of death and decay who spreads disease and commands undead minions.",
            color = { r = 0.2, g = 0.8, b = 0.2 },
            role1 = "DAMAGER",
        },
    },
    DRUID = {
        [1] = {
            ActiveBonus = { 53201 },
            PassiveBonus = { 48525, 33607, 48393 },
            Description = "Takes the form of a powerful moonkin and balances Arcane and Nature magic to destroy enemies from afar.",
            color = { r = 0.8, g = 0.3, b = 0.8 },
            role1 = "DAMAGER",
        },
        [2] = {
            ActiveBonus = { 50334 },
            PassiveBonus = { 51269, 33856, 24894 },
            Description = "Takes the form of a great cat to bleed enemies or a mighty bear to protect allies from harm.",
            color = { r = 1.0, g = 0.0, b = 0.0 },
            role1 = "TANK", role2 = "DAMAGER",
        },
        [3] = {
            ActiveBonus = { 18562 },
            PassiveBonus = { 48537, 51183, 34153 },
            Description = "Uses potent heal-over-time spells and the form of the Tree of Life to keep allies alive.",
            color = { r = 0.4, g = 0.8, b = 0.2 },
            role1 = "HEALER",
        },
    },
    HUNTER = {
        [1] = {
            ActiveBonus = { 19574 },
            PassiveBonus = { 19556, 19620, 34470 },
            Description = "A master of the wild who can tame a wide variety of beasts and empower them in battle.",
            color = { r = 1.0, g = 0.0, b = 0.3 },
            role1 = "DAMAGER",
        },
        [2] = {
            ActiveBonus = { 49050 },
            PassiveBonus = { 53217, 53224, 53238 },
            Description = "A peerless sharpshooter who excels at bringing down enemies from long range.",
            color = { r = 0.3, g = 0.6, b = 1.0 },
            role1 = "DAMAGER",
        },
        [3] = {
            ActiveBonus = { 60053 },
            PassiveBonus = { 56341, 56344, 53304 },
            Description = "A rugged tracker who favors venom, explosives, and traps as deadly weapons.",
            color = { r = 1.0, g = 0.6, b = 0.0 },
            role1 = "DAMAGER",
        },
    },
    MAGE = {
        [1] = {
            ActiveBonus = { 12042 },
            PassiveBonus = { 31588, 54490, 31583 },
            Description = "Manipulates raw Arcane energy and bends time and space to overwhelm enemies.",
            color = { r = 0.7, g = 0.2, b = 1.0 },
            role1 = "DAMAGER",
        },
        [2] = {
            ActiveBonus = { 42891 },
            PassiveBonus = { 44448, 34296, 31658 },
            Description = "Ignites enemies with explosive fireballs and the scorching breath of dragons.",
            color = { r = 1.0, g = 0.5, b = 0.0 },
            role1 = "DAMAGER",
        },
        [3] = {
            ActiveBonus = { 44572 },
            PassiveBonus = { 44549, 44545, 28593 },
            Description = "Freezes enemies in place and shatters them with devastating Frost magic.",
            color = { r = 0.3, g = 0.6, b = 1.0 },
            role1 = "DAMAGER",
        },
    },
    PALADIN = {
        [1] = {
            ActiveBonus = { 48825 },
            PassiveBonus = { 53576, 31841, 31836 },
            Description = "Invokes the power of the Light to protect allies and heal their wounds.",
            color = { r = 1.0, g = 0.5, b = 0.0 },
            role1 = "HEALER",
        },
        [2] = {
            ActiveBonus = { 48827 },
            PassiveBonus = { 53592, 53585, 33776 },
            Description = "Uses Holy magic and a shield to defend himself and his allies from enemy attacks.",
            color = { r = 0.3, g = 0.5, b = 1.0 },
            role1 = "TANK",
        },
        [3] = {
            ActiveBonus = { 53385 },
            PassiveBonus = { 53503, 53488, 31878 },
            Description = "A righteous crusader who judges and punishes opponents with weapons and Holy magic.",
            color = { r = 1.0, g = 0.0, b = 0.0 },
            role1 = "DAMAGER",
        },
    },
    PRIEST = {
        [1] = {
            ActiveBonus = { 53007 },
            PassiveBonus = { 33202, 47515, 14777 },
            Description = "Uses magic to shield allies from harm and mend their wounds before they become fatal.",
            color = { r = 1.0, g = 0.5, b = 0.0 },
            role1 = "HEALER",
        },
        [2] = {
            ActiveBonus = { 48089 },
            PassiveBonus = { 47560, 63543, 15031 },
            Description = "A versatile healer who can restore individuals or groups and continue healing beyond death.",
            color = { r = 0.6, g = 0.6, b = 1.0 },
            role1 = "HEALER",
        },
        [3] = {
            ActiveBonus = { 48156 },
            PassiveBonus = { 15332, 33371, 27840 },
            Description = "Uses sinister Shadow magic and damage-over-time spells to eliminate enemies.",
            color = { r = 0.7, g = 0.4, b = 0.8 },
            role1 = "DAMAGER",
        },
    },
    ROGUE = {
        [1] = {
            ActiveBonus = { 48666 },
            PassiveBonus = { 51636, 51669, 58410 },
            Description = "A deadly poison master who dispatches enemies with vicious finishing moves.",
            color = { r = 0.5, g = 0.8, b = 0.5 },
            role1 = "DAMAGER",
        },
        [2] = {
            ActiveBonus = { 13877 },
            PassiveBonus = { 61329, 35553, 32601 },
            Description = "A swashbuckler who uses agility and guile to stand toe-to-toe with enemies.",
            color = { r = 1.0, g = 0.5, b = 0.0 },
            role1 = "DAMAGER",
        },
        [3] = {
            ActiveBonus = { 36554 },
            PassiveBonus = { 31223, 31220 },
            Description = "A dark stalker who leaps from the shadows to ambush unsuspecting prey.",
            color = { r = 0.3, g = 0.5, b = 1.0 },
            role1 = "DAMAGER",
        },
    },
    SHAMAN = {
        [1] = {
            ActiveBonus = { 59159 },
            PassiveBonus = { 60188, 62101, 51486 },
            Description = "A spellcaster who harnesses the destructive forces of the elements.",
            color = { r = 0.8, g = 0.2, b = 0.8 },
            role1 = "DAMAGER",
        },
        [2] = {
            ActiveBonus = { 60103 },
            PassiveBonus = { 30798, 30814, 30809 },
            Description = "A totemic warrior who strikes with weapons imbued by elemental spirits.",
            color = { r = 0.3, g = 0.5, b = 1.0 },
            role1 = "DAMAGER",
        },
        [3] = {
            ActiveBonus = { 49284 },
            PassiveBonus = { 16213, 51558, 51566 },
            Description = "A healer who calls upon ancestral spirits and the cleansing power of water.",
            color = { r = 0.2, g = 0.8, b = 0.4 },
            role1 = "HEALER",
        },
    },
    WARLOCK = {
        [1] = {
            ActiveBonus = { 47843 },
            PassiveBonus = { 17814, 18829, 63108 },
            Description = "A master of Shadow magic who drains life and inflicts persistent agony upon enemies.",
            color = { r = 0.0, g = 1.0, b = 0.6 },
            role1 = "DAMAGER",
        },
        [2] = {
            ActiveBonus = { 30146 },
            PassiveBonus = { 23825, 18768 },
            Description = "Commands powerful demons while wielding both Fire and Shadow magic.",
            color = { r = 1.0, g = 0.0, b = 0.0 },
            role1 = "DAMAGER",
        },
        [3] = {
            ActiveBonus = { 17962 },
            PassiveBonus = { 63245, 17834 },
            Description = "Calls down demonic fire to burn and demolish enemies.",
            color = { r = 1.0, g = 0.5, b = 0.0 },
            role1 = "DAMAGER",
        },
    },
    WARRIOR = {
        [1] = {
            ActiveBonus = { 47486 },
            PassiveBonus = { 12712, 46855 },
            Description = "A battle-hardened master of two-handed weapons who relies on mobility and overpowering attacks.",
            color = { r = 1.0, g = 0.72, b = 0.1 },
            role1 = "DAMAGER",
        },
        [2] = {
            ActiveBonus = { 23881 },
            PassiveBonus = { 23588, 46917 },
            Description = "A furious berserker who wields a weapon in each hand and unleashes a relentless assault.",
            color = { r = 1.0, g = 0.0, b = 0.0 },
            role1 = "DAMAGER",
        },
        [3] = {
            ActiveBonus = { 23922 },
            PassiveBonus = { 29144, 12727, 47296 },
            Description = "Uses a shield and battlefield control to protect himself and his allies from enemy attacks.",
            color = { r = 0.3, g = 0.5, b = 1.0 },
            role1 = "TANK",
        },
    },
}

local selectedTalentGroup = NativeGetActiveTalentGroup and NativeGetActiveTalentGroup() or 1

C_Talent = C_Talent or {}

function C_Talent.IsSpecInfoLoaded()
    return true
end

function C_Talent.GetActiveTalentGroup(isInspect, isPet)
    return NativeGetActiveTalentGroup(isInspect, isPet)
end

function C_Talent.GetNumTalentGroups(isInspect, isPet)
    return NativeGetNumTalentGroups(isInspect, isPet)
end

function C_Talent.GetSelectedTalentGroup()
    return selectedTalentGroup or NativeGetActiveTalentGroup()
end

function C_Talent.SelectTalentGroup(talentGroupID)
    selectedTalentGroup = talentGroupID or NativeGetActiveTalentGroup()
    if PlayerTalentFrame and PlayerTalentFrame_OnEvent then
        PlayerTalentFrame_OnEvent(PlayerTalentFrame, "PLAYER_TALENT_ACTIVE_GROUP_CHANGED", selectedTalentGroup, selectedTalentGroup, true)
    end
end

function C_Talent.SetActiveTalentGroup(talentGroupID)
    if NativeSetActiveTalentGroup then
        NativeSetActiveTalentGroup(talentGroupID)
    end
end

function C_Talent.GetTalentGroupPointSpent(talentGroupID)
    local points = {}
    for tabIndex = 1, 3 do
        local _, _, spent, _, preview = GetTalentTabInfo(tabIndex, false, false, talentGroupID)
        points[tabIndex] = (spent or 0) + (preview or 0)
    end
    return points[1], points[2], points[3]
end

function C_Talent.GetTabPointSpent(talentGroupID)
    return { C_Talent.GetTalentGroupPointSpent(talentGroupID) }
end

function C_Talent.GetTalentGroupTotalPointSpent(talentGroupID)
    local a, b, c = C_Talent.GetTalentGroupPointSpent(talentGroupID)
    return a + b + c
end

function C_Talent.GetPrimaryTabIndexForTalentGroup(talentGroupID)
    local points = { C_Talent.GetTalentGroupPointSpent(talentGroupID) }
    local bestIndex, bestValue = 0, 0
    for index = 1, 3 do
        if points[index] > bestValue then
            bestIndex, bestValue = index, points[index]
        end
    end
    return bestIndex
end

function C_Talent.GetLastSecondTalentGroup()
    if NativeGetNumTalentGroups() > 1 then
        return NativeGetActiveTalentGroup() == 1 and 2 or 1
    end
end

function C_Talent.GetTalentGroupNote()
    return nil
end

function C_Talent.SetTalentGroupNote()
    return false
end

function C_Talent.GetClassSpecRole(className, talentTreeIndex)
    local classInfo = TALENT_RETAIL_INFO[className]
    local treeInfo = classInfo and classInfo[talentTreeIndex]
    if not treeInfo then
        return nil
    end

    return treeInfo.role1, treeInfo.role2
end

function C_Talent.GetSelectedCurrency()
    return nil
end

function C_Talent.SelectedCurrency()
end

function C_Talent.GetCurrencyInfo()
    return nil
end

function C_Talent.GetResetCost()
    return nil
end

function C_Talent.CanResetTalents()
    return false
end

function C_Talent.CanPurchaseSecondSpec()
    return false
end

function C_Talent.GetSecondSpecPrice()
    return nil
end

function C_Talent.GetPreviewTalents()
    return { {}, {}, {} }
end

function C_Talent.GetPreviewGlyphs()
    return {}, {}
end

function C_Talent.GetPreviewName()
    return nil
end

function C_Talent.SetPreviewEnabled()
end

function C_Talent.GenerateTalentHyperlink()
    return nil
end

function C_Talent.HasPlayerAnyTalentInfo(includePreview)
    for tabIndex = 1, 3 do
        local _, _, spent, _, preview = GetTalentTabInfo(tabIndex, false, false, C_Talent.GetSelectedTalentGroup())
        if (spent or 0) > 0 or (includePreview and (preview or 0) > 0) then
            return true
        end
    end
    return false
end

if not GetNumTalentPoints then
    function GetNumTalentPoints()
        local total = GetUnspentTalentPoints(false, false, C_Talent.GetSelectedTalentGroup()) or 0
        for tabIndex = 1, 3 do
            local _, _, spent = GetTalentTabInfo(tabIndex, false, false, C_Talent.GetSelectedTalentGroup())
            total = total + (spent or 0)
        end
        return total
    end
end
