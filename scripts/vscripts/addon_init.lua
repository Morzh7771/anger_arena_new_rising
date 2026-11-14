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
LinkLuaModifier("modifier_boss_slayer_fatigue", "modifiers/modifier_boss_slayer_fatigue", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_aa_neutral_potency", "modifiers/modifier_aa_neutral_potency", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_aa_enchanters_bauble", "modifiers/modifier_aa_neutral_potency", LUA_MODIFIER_MOTION_NONE)

-- Модификатор круга захвата рун (lib/capture_points). Линкуем здесь, а не в
-- самом lib-файле: тот серверный, и клиент без этого модификатор не знает -
-- а состояния круга (нет полоски здоровья, не выделяется, нет на миникарте)
-- нужны именно клиенту.
LinkLuaModifier("capture_point_area", "lib/capture_points/capture_point_area", LUA_MODIFIER_MOTION_NONE)

-- Защита крипов от доминейта (lib/spawners/creep_spawner). Та же история:
-- линк только в серверном lib-файле, и клиент спамил "Attempted to create
-- unknown modifier type modifier_dominate_protection" на каждый спавн крипа.
LinkLuaModifier("modifier_dominate_protection", "lib/spawners/modifier_dominate_protection", LUA_MODIFIER_MOTION_NONE)
-- то же у медведей (lib/spawners/bear_spawner): иконка счётчика смертей
LinkLuaModifier("modifier_stuck_count", "lib/spawners/modifier_stuck_count", LUA_MODIFIER_MOTION_NONE)

-- брейк Silver Edge 3 (items/item_dark_edge): клиенту для тултипа и иконки
LinkLuaModifier("modifier_item_dark_edge_debuff", "items/item_dark_edge", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_dark_edge_cold", "items/item_dark_edge", LUA_MODIFIER_MOTION_NONE)

-- Модификаторы суммонов по имени юнита (creeps/armor_table_summon): линк был
-- только на сервере, клиент спамил "unknown modifier type" и не видел их статы
for _, name in ipairs({
	"modifier_summon", "modifier_broodmother_spiders", "modifier_shadowshaman_wards",
	"modifier_warlock_golems", "modifier_witch_doctor_ward", "modifier_summon_undying",
	"modifier_visage_familiars", "modifier_summon_plague_ward", "modifier_summon_eidolon",
	"modifier_lycan_wolfes",
}) do
	LinkLuaModifier(name, "modifiers/heroes/" .. name, LUA_MODIFIER_MOTION_NONE)
end

-- Фамильяры Визажа на Lua (heroes/visage/visage_familiars)
for _, name in ipairs({
	"modifier_visage_familiar_lua",
	"modifier_visage_familiar_invis_lua",
	"modifier_visage_familiar_stone_lua",
	"modifier_visage_familiar_recall_lua",
	"modifier_visage_familiar_armor_reduction_lua",
}) do
	LinkLuaModifier(name, "heroes/visage/visage_familiars", LUA_MODIFIER_MOTION_NONE)
end

-- Баффы портала (abilities/mid_teleport). Способность выдаётся и снимается
-- на лету, так что клиент может не успеть загрузить её скрипт - без линка
-- тут у иконок баффов не было ни названия, ни описания.
LinkLuaModifier("modifier_mid_teleport_cd", "abilities/mid_teleport", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_mid_teleport_speed", "abilities/mid_teleport", LUA_MODIFIER_MOTION_NONE)
-- усиление суммонов от хозяина (lib/summon_power)
-- бонусы героя от статов: клиенту нужен для панели статов и тултипов
LinkLuaModifier("modifier_aa_hero", "modifiers/modifier_aa_hero", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_summon_power", "modifiers/modifier_summon_power", LUA_MODIFIER_MOTION_NONE)
-- урна/вессел на Lua (items/item_urn_aa) и их стаки за убийства (lib/urn_charges)
LinkLuaModifier("modifier_urn_soul_stacks", "modifiers/modifier_urn_soul_stacks", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_urn_aa_passive", "items/item_urn_aa", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_urn_aa_heal", "items/item_urn_aa", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_urn_aa_damage", "items/item_urn_aa", LUA_MODIFIER_MOTION_NONE)

-- Сларк: кража ловкости с крипов и вечная ловкость за убийства (heroes/slark/slark_essence_shift_creeps)
LinkLuaModifier("modifier_slark_essence_shift_creeps", "heroes/slark/slark_essence_shift_creeps", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_slark_essence_shift_creeps_buff", "heroes/slark/slark_essence_shift_creeps", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_slark_essence_shift_creeps_permanent", "heroes/slark/slark_essence_shift_creeps", LUA_MODIFIER_MOTION_NONE)
-- Witch Doctor: Voodoo Restoration на Lua
LinkLuaModifier("modifier_witch_doctor_voodoo_restoration_lua", "heroes/witch_doctor/witch_doctor_voodoo_restoration", LUA_MODIFIER_MOTION_NONE)
-- пет премиум-косметики (lib/cosmetics/core.lua): клиент видит состояние пета
LinkLuaModifier("modifier_aa_cosmetic_pet", "modifiers/modifier_aa_cosmetic_pet", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_aa_cos_body", "modifiers/modifier_aa_cos_body", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_aa_cos_hex_model", "modifiers/modifier_aa_cos_hex_model", LUA_MODIFIER_MOTION_NONE)
-- невидимый юнит-кастер косметических умений (lib/cosmetics/caster.lua)
LinkLuaModifier("modifier_aa_cosmetic_caster", "modifiers/modifier_aa_cosmetic_caster", LUA_MODIFIER_MOTION_NONE)

function CEntityInstance:GetNetworkableEntityInfo(key)
    local t = CustomNetTables:GetTableValue("custom_entity_values", tostring(self:GetEntityIndex())) or {}
    return t[key]
end
