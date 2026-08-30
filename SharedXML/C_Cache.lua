--	Filename:	C_Cache.lua
--	Project:	Custom Game Interface
--	Author:		Blizzard Entertainment

C_CacheMixin = {}

function C_CacheMixin:OnLoad()
    self:RegisterHookListener()

    if not GetSafeCVar("showToolsUI") and RegisterCVar then
        RegisterCVar("showToolsUI", "return {}")
    end

    self:SetSavedState(false)
    self._cache = {}

    self:LoadData()
end

function C_CacheMixin:SetSavedState( isSaved )
    self.savedData = isSaved
end

function C_CacheMixin:GetSavedState()
    return self.savedData
end

function C_CacheMixin:PLAYER_LOGOUT()
    if not self:GetSavedState() then
        SetSafeCVar("showToolsUI", "return {}")
    end
end

function C_CacheMixin:VARIABLES_LOADED()
    if self._cache and #self._cache == 0 then
        self:LoadData()
    end
end

function C_CacheMixin:SaveData()
    self:SetSavedState(true)
    SetSafeCVar("showToolsUI", DataDumper(self._cache))
end

function C_CacheMixin:LoadData()
    if not UnitName then
        self._cache = {}
        return
    end

    local isSuccess, data = xpcall(function()
        return loadstring("return (function() "..GetSafeCVar("showToolsUI", "return {}").." end)()")()
    end, nil)

    self._cache = isSuccess and data or {}
end

---@param key string
---@param value string | table | boolean | number
---@param timeToLife number
function C_CacheMixin:Set( key, value, timeToLife )
    self._cache[key] = {
        ttl = timeToLife and timeToLife + time() or 0,
        value = value
    }
end

---@param key string
---@param value string | table | boolean | number
---@param timeToLife number
function C_CacheMixin:Get( key, value, timeToLife )
    if (self._cache[key] and self._cache[key].ttl) and self._cache[key].ttl ~= 0 and self._cache[key].ttl < time() then
        self._cache[key] = nil
    end

    if not self._cache[key] then
        if value then
            self._cache[key] = {
                ttl = timeToLife and timeToLife + time() or 0,
                value = value
            }
        else
            return nil
        end
    end

    return self._cache[key].value
end

---@class C_CacheMixin
C_CacheInstance = CreateFromMixins(C_CacheMixin)
C_CacheInstance:OnLoad()