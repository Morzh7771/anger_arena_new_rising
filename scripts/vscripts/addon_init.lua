-- Вне tools mode движок не отдаёт библиотеку debug - ни на сервере, ни на
-- клиенте. Обработчик ошибок у самого движка зовёт debug.traceback, поэтому
-- ЛЮБАЯ ошибка луа превращалась в глухое "Script Runtime Error: error in error
-- handling": ни файла, ни строки, ни текста. Ставим минимальную заглушку -
-- стека в ней нет, но сообщение об ошибке снова видно в консоли.
if not rawget(_G, "debug") then
    _G.debug = {
        traceback = function(msg, level) return msg end,
        getinfo   = function() return nil end,
    }
end

local function safe_require(name)
    local ok, res = xpcall(function()
        return require(name)
    end, function(err)
        err = tostring(err)
        print("!!! require FAILED:", name)
        print(err)
        -- debug на боевом сервере nil, без проверки падает сам обработчик
        if debug and debug.traceback then
            print(debug.traceback("Traceback:", 2))
        end
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

-- Усиления нейтралок от Dormant Curio и Enchanter's Bauble (их вешает
-- lib/neutral/madstone_system.lua). Линкуем тут, а не в lib-модуле: этот
-- файл грузится и на клиенте, иначе клиент пишет "unknown modifier type" и
-- тултипы предметов показывают старые числа.
LinkLuaModifier("modifier_aa_neutral_potency", "modifiers/modifier_aa_neutral_potency", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_aa_enchanters_bauble", "modifiers/modifier_aa_neutral_potency", LUA_MODIFIER_MOTION_NONE)

-- Модификатор круга захвата рун (lib/capture_points). Линкуем здесь, а не в
-- самом lib-файле: тот серверный, и клиент без этого модификатор не знает -
-- а состояния круга (нет полоски здоровья, не выделяется, нет на миникарте)
-- нужны именно клиенту.
LinkLuaModifier("capture_point_area", "lib/capture_points/capture_point_area", LUA_MODIFIER_MOTION_NONE)

function CEntityInstance:GetNetworkableEntityInfo(key)
    local t = CustomNetTables:GetTableValue("custom_entity_values", tostring(self:GetEntityIndex())) or {}
    return t[key]
end
