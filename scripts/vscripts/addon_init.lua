local function safe_require(name)
    local ok, res = xpcall(function()
        return require(name)
    end, function(err)
        err = tostring(err)
        print("!!! require FAILED:", name)
        print(err)
        print(debug.traceback("Traceback:", 2))
        return err
    end)

    if not ok then
        error("safe_require failed: " .. name .. " | " .. tostring(res))
    end

    return res
end

safe_require('lib/talent_support')
safe_require('lib/base_lua_helpers')
safe_require('lib/special_bonus_base_aa/Special_bonus_base_aa')

function CEntityInstance:GetNetworkableEntityInfo(key)
    local t = CustomNetTables:GetTableValue("custom_entity_values", tostring(self:GetEntityIndex())) or {}
    return t[key]
end
