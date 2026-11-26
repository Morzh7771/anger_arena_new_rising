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
-- действенность атаки (Item Potency) для наших проков, нужна и клиенту (тултипы дебафов)
safe_require('lib/attack_potency')
safe_require('lib/special_bonus_base_aa/Special_bonus_base_aa')

-- Усиления нейтралок от Dormant Curio и Enchanter's Bauble (их вешает
-- lib/neutral/madstone_system.lua). Линкуем тут, а не в lib-модуле: этот
-- файл грузится и на клиенте, иначе клиент пишет "unknown modifier type" и
-- тултипы предметов показывают старые числа.
LinkLuaModifier("modifier_boss_slayer_fatigue", "modifiers/modifier_boss_slayer_fatigue", LUA_MODIFIER_MOTION_NONE)
-- "Отстающая команда" - механика камбэка (lib/underdog.lua)
LinkLuaModifier("modifier_aa_underdog", "modifiers/modifier_aa_underdog", LUA_MODIFIER_MOTION_NONE)
-- Фарм героев: эффекты способностей против крипов (lib/hero_farm.lua)
LinkLuaModifier("modifier_aa_hero_farm", "modifiers/modifier_aa_hero_farm", LUA_MODIFIER_MOTION_NONE)
-- замах крипов перед скиллом (2026-11-22)
LinkLuaModifier("modifier_aa_creep_telegraph", "modifiers/modifier_aa_creep_telegraph", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_aa_creep_windup", "modifiers/modifier_aa_creep_telegraph", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_aa_creep_telegraph_hub", "modifiers/modifier_aa_creep_telegraph", LUA_MODIFIER_MOTION_NONE)
-- боссы: "!" на замахе и канал телепорта ротации (lib/boss/boss_spawner.lua)
LinkLuaModifier("modifier_boss_cast_alert", "lib/boss/modifier_boss_cast_alert", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_boss_rotation", "lib/boss/modifier_boss_rotation", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_boss_true_sight", "lib/boss/modifier_boss_true_sight", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_boss_leash", "lib/boss/modifier_boss_leash", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_aa_farm_burn", "modifiers/modifier_aa_hero_farm", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_aa_farm_jingu", "modifiers/modifier_aa_hero_farm", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_aa_farm_flux", "modifiers/modifier_aa_hero_farm", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_aa_neutral_potency", "modifiers/modifier_aa_neutral_potency", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_creep_shard_haste", "modifiers/modifier_creep_shard", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_creep_shard_damage", "modifiers/modifier_creep_shard", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_creep_shard_regen", "modifiers/modifier_creep_shard", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_aa_enchanters_bauble", "modifiers/modifier_aa_neutral_potency", LUA_MODIFIER_MOTION_NONE)
-- Общий модификатор статов всех чар (item_aa_enhancement_*)
LinkLuaModifier("modifier_item_aa_enhancement", "items/item_aa_enhancement", LUA_MODIFIER_MOTION_NONE)

-- Модификатор круга захвата рун (lib/capture_points). Линкуем здесь, а не в
-- самом lib-файле: тот серверный, и клиент без этого модификатор не знает -
-- а состояния круга (нет полоски здоровья, не выделяется, нет на миникарте)
-- нужны именно клиенту.
LinkLuaModifier("capture_point_area", "lib/capture_points/capture_point_area", LUA_MODIFIER_MOTION_NONE)

-- Защита крипов от доминейта (lib/spawners/creep_spawner). Та же история:
-- линк только в серверном lib-файле, и клиент спамил "Attempted to create
-- unknown modifier type modifier_dominate_protection" на каждый спавн крипа.
LinkLuaModifier("modifier_dominate_protection", "lib/spawners/modifier_dominate_protection", LUA_MODIFIER_MOTION_NONE)
-- активки нейтралов (abilities/creeps_neutral_active): замедление/броня, клиенту для тултипа
LinkLuaModifier("modifier_neutral_creep_active", "abilities/creeps_neutral_active/modifier_neutral_creep_active", LUA_MODIFIER_MOTION_NONE)
-- то же у медведей (lib/spawners/bear_spawner): иконка счётчика смертей
LinkLuaModifier("modifier_stuck_count", "lib/spawners/modifier_stuck_count", LUA_MODIFIER_MOTION_NONE)

-- брейк Silver Edge 3 (items/item_dark_edge): клиенту для тултипа и иконки
LinkLuaModifier("modifier_item_dark_edge_debuff", "items/item_dark_edge", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_chainmail_eaten", "items/item_chainmail_aa", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_dark_edge_cold", "items/item_dark_edge", LUA_MODIFIER_MOTION_NONE)

-- Fallen Sky, Vile Phial, Rattlecage (items/item_*): клиенту для тултипов и иконок статусов
LinkLuaModifier("modifier_item_fallen_sky_land", "items/item_fallen_sky", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_fallen_sky_stun", "items/item_fallen_sky", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_fallen_sky_burn", "items/item_fallen_sky", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_vile_phial_counter", "items/item_vile_phial", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_vile_phial_poison", "items/item_vile_phial", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_rattlecage_slow", "items/item_rattlecage", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_desolator_2_disarmor", "items/item_desolator_2", LUA_MODIFIER_MOTION_NONE)

-- Void Shackles, Rebels Sword: клиенту для тултипов, иконок и партиклов дебафов
LinkLuaModifier("modifier_item_void_shackles_passive", "items/item_void_shackles", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_void_shackles_root", "items/item_void_shackles", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_void_shackles_nullify", "items/item_void_shackles", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_rebels_sword_disarmor", "items/rebels_sword/rebels_sword", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_rebels_sword_leash", "items/rebels_sword/rebels_sword", LUA_MODIFIER_MOTION_NONE)

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
LinkLuaModifier("modifier_tiny_insurmountable_lua", "heroes/tiny/tiny_insurmountable", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_bat", "modifiers/modifier_bat", LUA_MODIFIER_MOTION_NONE)
