require('lib/talent_support')
require('lib/base_lua_helpers')
require('lib/special_bonus_base_aa/Special_bonus_base_aa')
function CEntityInstance:GetNetworkableEntityInfo(key)
    local t = CustomNetTables:GetTableValue("custom_entity_values", tostring(self:GetEntityIndex())) or {}
    return t[key]
end
