-- ============================================================
--  AddonList - Noa –  WoW 3.3.5a
-- ============================================================
ADDON_BUTTON_HEIGHT  = 16
MAX_ADDONS_DISPLAYED = 16

-- ──────────────────────────────────────────────
--  Colores de estado (DEFINICIÓN CENTRALIZADA)
-- ──────────────────────────────────────────────
local COLOR_WHITE = {1.0, 1.0, 1.0}
local COLOR_RED   = {0.59, 0.26, 0.26}      -- Banned/Error
local COLOR_GREY  = {0.48, 0.48, 0.48}       -- Disabled/Not loadable
local COLOR_GREEN = {0.2, 0.8, 0.2}          -- Enabled
local COLOR_ORANGE = {0.8, 0.5, 0.2}         -- Load issue

local selectedAddonIndex = nil
-- ───────────────────────────────────────────────
--  Lista ordenada (cache, se invalida al cambiar)
-- ───────────────────────────────────────────────
local sortedList    = {}
local sortedCount   = 0
local lastNumAddons = -1
-- ═══════════════════════════════════════════════════════════
--  FUNCIONES AUXILIARES
-- ═══════════════════════════════════════════════════════════
local function RebuildSortedList()
    local n = GetNumAddOns()
    if n == lastNumAddons then return end
    lastNumAddons = n

    table.wipe(sortedList)
    for i = 1, n do
        local name, title = GetAddOnInfo(i)
        if name then
            sortedList[#sortedList + 1] = {
                index = i,
                name  = name,
                title = title or name,
            }
        end
    end

    table.sort(sortedList, function(a, b)
        return a.title:lower() < b.title:lower()
    end)

    sortedCount = #sortedList
end

local function GetSortedEntry(pos)
    RebuildSortedList()
    return sortedList[pos]
end
-- ═══════════════════════════════════════════════════════════
--  FUNCIÓN PARA OBTENER TEXTO Y COLOR DE ESTADO
-- ═══════════════════════════════════════════════════════════
local function GetAddonStatusInfo(enabled, loadable, reason)
    local statusText = ""
    local statusColor = COLOR_WHITE
    
    if reason then
        if reason == "BANNED" then
            statusText = ADDON_LIST_BANNED
            statusColor = COLOR_RED
        elseif reason == "DISABLED" then
            statusText = ADDON_LIST_DISABLED
            statusColor = COLOR_GREY
        elseif not loadable then
            statusText = _G["ADDON_" .. reason] or reason
            statusColor = COLOR_ORANGE
        else
            statusText = ""
            statusColor = COLOR_WHITE
        end
    else
        if enabled then
            statusText = ADDON_LIST_ENABLED
            statusColor = COLOR_GREEN
        else
            statusText = ""
            statusColor = COLOR_WHITE
        end
    end
    
    return statusText, statusColor
end
-- ═══════════════════════════════════════════════════════════
--  FUNCIONES PRINCIPALES DEL FRAME
-- ═══════════════════════════════════════════════════════════
function AddonList_OnLoad(self)
    self.offset = 0
end

function AddonList_OnShow()
    lastNumAddons = -1
    AddonList.offset = 0
    selectedAddonIndex = nil
    AddonList_Update()
    AddonList_UpdateInfoPanel()
end

function AddonList_OnKeyDown(key)
    if key == "ESCAPE" then
        HideUIPanel(AddonList)
    end
end
-- ──────────────────────────────────────────────
--  Función para seleccionar un addon
-- ──────────────────────────────────────────────
function AddonList_SelectAddon(index)
    if selectedAddonIndex == index then
        selectedAddonIndex = nil
    else
        selectedAddonIndex = index
    end
    AddonList_Update()
    AddonList_UpdateInfoPanel()
end
-- ──────────────────────────────────────────────
--  Función para actualizar el panel de información
-- ──────────────────────────────────────────────
function AddonList_UpdateInfoPanel()
    if not AddonInfoPanel then return end

    if not selectedAddonIndex or selectedAddonIndex == 0 then
        AddonInfoPanelTitle:SetText(ADDON_LIST_INFO)
        AddonInfoPanelAddonName:SetText("")
        AddonInfoPanelStatus:SetText("")
        AddonInfoPanelAuthor:SetText("")
        AddonInfoPanelVersion:SetText("")
        AddonInfoPanelNotes:SetText("")
        AddonInfoPanelDeps:SetText("")
        return
    end
    
    local name, title, notes, enabled, loadable, reason, security = GetAddOnInfo(selectedAddonIndex)

    AddonInfoPanelAddonName:SetText(title or name or "No name")

    local statusText, statusColor = GetAddonStatusInfo(enabled, loadable, reason)
    if statusText == "" then
        statusText = enabled and ADDON_LIST_ENABLED or ADDON_LIST_DISABLED
        statusColor = enabled and COLOR_GREEN or COLOR_GREY
    end
    AddonInfoPanelStatus:SetText(ADDON_LIST_STATUS .. ": " .. statusText)
    AddonInfoPanelStatus:SetTextColor(unpack(statusColor))

    if notes and notes ~= "" then
        AddonInfoPanelNotes:SetText(notes)
    else
        AddonInfoPanelNotes:SetText(ADDON_LIST_NO_DESC)
    end

    local deps = ""
    local depArgs = { GetAddOnDependencies(selectedAddonIndex) }
    if #depArgs > 0 then
        deps = "Requires: " .. table.concat(depArgs, ", ")
        AddonInfoPanelDeps:SetText(deps)
    else
        AddonInfoPanelDeps:SetText(ADDON_LIST_NO_DEPS)
    end

    local author = GetAddOnMetadata(selectedAddonIndex, "Author") or ADDON_LIST_UNKNOWN
    local version = GetAddOnMetadata(selectedAddonIndex, "Version") or ADDON_LIST_UNKNOWN
    
    AddonInfoPanelAuthor:SetText(ADDON_LIST_AUTHOR .. ": " .. author)
    AddonInfoPanelVersion:SetText(ADDON_LIST_VERSION .. ": " .. version)
    
    AddonInfoPanel:Show()
end
-- ──────────────────────────────────────────────
--  Actualización del frame
-- ──────────────────────────────────────────────
function AddonList_Update()
    RebuildSortedList()
    local total  = sortedCount
    local offset = AddonList.offset or 0

    for i = 1, MAX_ADDONS_DISPLAYED do
        local pos    = offset + i
        local button = _G["AddonListEntry" .. i]

        if not button then break end
        
        if pos > total then
            button:Hide()
        else
            local entry = GetSortedEntry(pos)
            if not entry then button:Hide(); break end

            local realIdx = entry.index
            local name, title, notes, enabled, loadable, reason, security =
                GetAddOnInfo(realIdx)

            local cb = button.StatusCheckBox
            if cb then
                cb:SetChecked(enabled and true or false)
                cb:SetEnabled(reason ~= "BANNED")
            end

            button.Title:SetText(title or name)

            local titleColor
            if loadable or (enabled and (reason == "DEP_DEMAND_LOADED" or reason == "DEMAND_LOADED")) then
                titleColor = COLOR_WHITE
            elseif enabled and reason and reason ~= "DEP_DISABLED" then
                titleColor = COLOR_RED
            else
                titleColor = COLOR_GREY
            end
            button.Title:SetTextColor(unpack(titleColor))

            local statusText, statusColor = GetAddonStatusInfo(enabled, loadable, reason)
            button.Status:SetText(statusText)
            if statusText ~= "" then
                button.Status:SetTextColor(unpack(statusColor))
            end

            button:SetID(realIdx)

            if realIdx == selectedAddonIndex then
                button.Highlight:Show()
            else
                button.Highlight:Hide()
            end
            
            button:Show()
        end
    end

    FauxScrollFrame_Update(
        AddonListScrollFrame,
        total,
        MAX_ADDONS_DISPLAYED,
        ADDON_BUTTON_HEIGHT,
        nil, nil, nil, nil, nil, nil, true
    )

    AddonList_UpdateInfoPanel()
end
-- ──────────────────────────────────────────────
--  Activar / desactivar addon
-- ──────────────────────────────────────────────
function AddonList_Enable(realIndex, enable)
    if enable then
        EnableAddOn(realIndex)
    else
        DisableAddOn(realIndex)
    end
    AddonList_Update()
end
-- ──────────────────────────────────────────────
--  Enable All / Disable All
-- ──────────────────────────────────────────────
function AddonList_EnableAll()
    EnableAllAddOns()
    AddonList_Update()
end

function AddonList_DisableAll()
    DisableAllAddOns()
    AddonList_Update()
end
-- ──────────────────────────────────────────────
--  Reload UI
-- ──────────────────────────────────────────────
function AddonList_DoReload()
    ReloadUI()
end
-- ──────────────────────────────────────────────
--  ScrollFrame
-- ──────────────────────────────────────────────
function AddonListScrollFrame_OnVerticalScroll(self, offset)
    local scrollbar = _G[self:GetName() .. "ScrollBar"]
    if scrollbar then scrollbar:SetValue(offset) end
    AddonList.offset = math.floor((offset / ADDON_BUTTON_HEIGHT) + 0.5)
    AddonList_Update()
end
-- ═══════════════════════════════════════════════════════════
--  FUNCIÓN GLOBAL PARA ABRIR EL FRAME DE ADDONS
-- ═══════════════════════════════════════════════════════════
function ToggleAddonList()
    if not AddonList then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[Error]|r AddonList not loaded!", 1, 0, 0)
        return
    end
    
    if AddonList:IsShown() then
        HideUIPanel(AddonList)
    else
        ShowUIPanel(AddonList)
    end
end

-- ═══════════════════════════════════════════════════════════
--  REGISTRO DEL COMANDO /reload
-- ═══════════════════════════════════════════════════════════
if SlashCmdList["RELOADUI"] then
    SlashCmdList["RELOADUI"] = nil
end

SLASH_RELOADUI1 = "/reload"
SLASH_RELOADUI2 = "/rl"

SlashCmdList["RELOADUI"] = function(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[AddonList]|r Reloading UI...", 0, 1, 0)
    ReloadUI()
end
-- ============================================================