-- Generated from template
_G.inited = false
if AngelArena == nil then
	_G.AngelArena = class({})
end
print("[AA] addon_game_mode loaded (top of file)")

-- То же, что в addon_init.lua: без библиотеки debug валвовский обработчик
-- ошибок падает сам и вместо текста ошибки в консоль летит
-- "error in error handling". Порядок загрузки двух файлов не гарантирован,
-- поэтому заглушка стоит в обоих; rawget - чтобы не затереть настоящую.
if not rawget(_G, "debug") then
    _G.debug = {
        traceback = function(msg, level) return msg end,
        getinfo   = function() return nil end,
    }
end

-- Поиск просадки FPS: если есть scripts/vscripts/aa_safe_mode.lua (в мастерскую
-- не заливать), перечисленные в нём модули не грузятся вовсе. Файл возвращает
-- таблицу { ["lib/cosmetics/core"] = true, ... } или true - пропустить все новые.
local AA_SKIP = nil
do
    local okSkip, skip = pcall(require, "aa_safe_mode")
    if okSkip and skip then
        AA_SKIP = (skip == true) and {
            ["lib/match_tracker"] = true, ["lib/match_telemetry"] = true,
            ["lib/lobby_leader"] = true, ["lib/admin_panel"] = true,
            ["lib/cosmetics/core"] = true, ["lib/cosmetics/social"] = true,
            ["lib/cosmetics/caster"] = true, ["lib/damage_log"] = true,
            ["lib/perf_toggle"] = true, ["precache_cosmetics"] = true,
        } or skip
        print("[AA] SAFE MODE: новые модули отключены")
    end
end
_G.AA_SKIP = AA_SKIP

local function safe_require(name)
    if AA_SKIP and AA_SKIP[name] then
        print("[AA] safe mode, пропущен:", name)
        return nil
    end
    local ok, res = xpcall(function()
        return require(name)
    end, function(msg)
        print("!!! safe_require FAILED:", name)
        print(tostring(msg))
        -- на боевом сервере debug == nil, и сам обработчик ошибки падал тут же,
        -- съедая сообщение о том, какой файл на самом деле не загрузился
        if debug and debug.traceback then
            print(debug.traceback("Traceback:", 2))
        end
        return msg
    end)

    if not ok then
        error("safe_require failed: " .. name)
    end
    return res
end

-- защита ивентов панорамы - первой: оборачивает RegisterListener, а слушатели,
-- зарегистрированные раньше неё, остаются без защиты
safe_require('lib/events_protector')

-- ивент при подключении игрока (OnPlayerConnected) уходит раньше, чем его
-- интерфейс получил ключ, и выбрасывается - повторяем после рукопожатия
if RegisterLoadListener then
	RegisterLoadListener(function(player)
		CustomGameEventManager:Send_ServerToPlayer(player, "MakeNeutralItemsInShopColored", {})
	end)
end

safe_require('tp_s')
safe_require('lib/utils')
-- статистика для финального экрана; хуки ниже по файлу и в системах мода
safe_require('lib/end_game_stats')
safe_require('lib/teleport')
-- бесплатный свиток телепортации на смерть, как в доте
safe_require('lib/stick_self_charge')
safe_require('lib/summon_power')
safe_require('lib/urn_charges')
safe_require('lib/stats_tooltip')
safe_require('lib/duel/duel_controller')
safe_require('lib/gpm_lib')
safe_require('lib/percent_damage')
safe_require('lib/boss/boss_spawner')
safe_require('lib/panorama_pings')
safe_require('lib/spawners/creep_spawner')
safe_require('lib/spawners/creep_leveling')
safe_require('lib/spawners/camp_sleep')
safe_require('lib/neutral/madstone_system')
safe_require('lib/timers')
safe_require('lib/attentions')
safe_require('lib/team_helper')
safe_require('lib/chat_listener')
safe_require('lib/comeback_system')
safe_require('lib/move_limiter')
safe_require('lib/spawners/bear_spawner')
safe_require('lib/bounty')
safe_require('lib/capture_points/capture_points')
safe_require('lib/minimap_spots')
safe_require('lib/shift_buy')
safe_require('lib/game_ender')
safe_require('lib/repick_menu')
safe_require('lib/tip_manager')
safe_require('lib/special_bonus_base_aa/Special_bonus_base_aa')
safe_require('lib/diag_log')
safe_require('lib/item_precache')
safe_require('lib/team_gold_share')
safe_require('lib/hero_kill_bounty')
safe_require('lib/kill_feed')
safe_require('lib/ping_modifiers') -- alt-клик по баффу -> чат команды (lib/ping_modifiers.lua)
safe_require('lib/channel_bar')
safe_require('lib/match_tracker') -- телеметрия матча, только наблюдение (lib/match_tracker.lua)
safe_require('lib/match_telemetry') -- события сверх трекера: дуэль, нейтралки, золото по источникам (lib/match_telemetry.lua)
-- лидер лобби на выборе команд, когда хоста нет (lib/lobby_leader.lua)
safe_require('lib/lobby_leader')
safe_require('lib/admin_panel')
-- премиум-косметика: состояние, экипировка, эффекты (lib/cosmetics/core.lua)
safe_require('lib/cosmetics/core')
-- социальная косметика: колесо фраз, смайлики, спреи, хай-файвы (SOCIAL_CATALOG в lib/cosmetics/social_catalog.lua)
safe_require('lib/cosmetics/social')
-- косметические умения: невидимый юнит-кастер с ванильными сезонными способностями,
-- граффити и "Дай пять" (lib/cosmetics/caster.lua)
safe_require('lib/cosmetics/caster')
-- косметика на событиях: уровень, фонтан, скин героя, снаряд, мультикиллы, победа в дуэли
safe_require('lib/cosmetics/events_fx')
-- прогресс: пасс, осколки, сундуки, задания (бэкенд progression.py)
safe_require('lib/progression')
-- таблица рейтинга для меню (бэкенд leaderboard_api.py)
safe_require('lib/leaderboard')
-- свой выбор героя: премиум-пик -> баны -> общий пик
safe_require('lib/pick_stages')
-- бронь зон фарма на стадии стратегии (lib/farm_claims.lua, panorama strategy_farm.js)
safe_require('lib/farm_claims')
-- премиум: точное время респавна боссов по Alt
safe_require('lib/boss_timers_premium')
-- замер FPS: консольная команда aa_perf (lib/perf_toggle.lua)
safe_require('lib/perf_toggle')
safe_require('lib/damage_log') -- журнал урона премиум-игрокам (lib/damage_log.lua)

function CEntityInstance:SetNetworkableEntityInfo(key, value)
    local t = CustomNetTables:GetTableValue("custom_entity_values", tostring(self:GetEntityIndex())) or {}
    t[key] = value
    CustomNetTables:SetTableValue("custom_entity_values", tostring(self:GetEntityIndex()), t)
end
-- local function forPrecache(kv, context)
--     if type(kv) ~= "table" then return end

--     for unitname, unit_kv in pairs(kv) do
--         if type(unit_kv) == "table" and unit_kv.Model then
--             PrecacheModel(unit_kv.Model, context)
--         end

--         -- unitname тут ключ из KV: npc_xxx
--         if type(unitname) == "string" then
--             PrecacheUnitByNameSync(unitname, context)
--         end
--     end
-- end

-- ДИАГНОСТИКА ЛИМИТА 32767.
--
-- true  - Precache() не грузит вообще ничего.
-- false - обычное поведение.
--
-- Смысл: если с true карта запускается (пусть без эффектов и с error-моделями),
-- значит лимит выбивает именно Precache и дальше режем его дальше. Если с true
-- карта падает точно так же - Precache ни при чём, виноват сам контент карты
-- или KV, и копать надо там. Без этой развилки любой следующий шаг - гадание.
PRECACHE_MINIMAL = false

function Precache(context)
    if PRECACHE_MINIMAL then
        print("[AA] PRECACHE_MINIMAL: прекеш пропущен целиком")
        return
    end

    -- Партиклы.
    --
    -- Раньше тут было PrecacheResource("particle_folder", "particles", context) -
    -- вся папка целиком, 501 система, каждая со своими детьми, материалами и
    -- текстурами. Именно это выбивало лимит загружаемых ресурсов (32767) и роняло
    -- карту на старте.
    --
    -- Теперь на старте грузим только то, что стоит на карте с первой секунды.
    -- Геройское и предметное подтягивается само в момент, когда оно нужно:
    --   - particles/units/heroes/hero_* лежат по ванильным путям и перекрывают
    --     оригиналы, движок берёт их вместе с героем;
    --   - остальное объявлено в методах <ability>:Precache(context) у самих
    --     способностей - движок зовёт их, когда прекешит юнита с этой
    --     способностью, то есть на пике и на репике через PrecacheUnitByNameAsync.
    local PARTICLE_FOLDERS_AT_LOAD = {
        "particles/basic_ambient",
        "particles/basic_explosion",
        "particles/basic_projectile",
        "particles/basic_rope",
        "particles/basic_trail",
        "particles/creep_elite",
        "particles/lane_creeps",
        "particles/shrine_restore_radiant",
        "particles/damned_eye",
        -- круги захвата рун и круги респавна кемпов (lib/capture_points,
        -- lib/spawners/camp_respawn_ring)
        "particles/capture_point_ring",
        "particles/capture_points",
        "particles/camp_respawn",
    }

    for _, folder in ipairs(PARTICLE_FOLDERS_AT_LOAD) do
        PrecacheResource("particle_folder", folder, context)
    end

    -- Отдельные партиклы у того, что выдаётся через AddAbility посреди игры:
    -- Precache таких способностей движок не зовёт. Кольцо портала у
    -- mid_teleport иначе было "invalid particle definition".
    PrecacheResource("particle", "particles/portal_ring.vpcf", context)

    -- Свиток телепортации. Предмет движковый, но папка particles/items2_fx в
    -- список выше не входит (грузить её целиком нельзя - лимит ресурсов), и без
    -- этих строк телепорт шёл вообще без эффектов: ни круга под героем, ни
    -- силуэта на точке прибытия.
    PrecacheResource("particle", "particles/items2_fx/teleport_start.vpcf", context)
    PrecacheResource("particle", "particles/items2_fx/teleport_end.vpcf", context)
    -- третий эффект свитка: имена всех трёх взяты прямо из server.dll, это
    -- ровно то, что создаёт движковый item_tpscroll
    PrecacheResource("particle", "particles/items2_fx/teleport_origin.vpcf", context)

    -- Партиклы и модели, на которые ссылается только lua: смена модели через
    -- MODIFIER_PROPERTY_MODEL_CHANGE/SetModel, econ-эффекты и партиклы чужих героев.
    -- Ничего из этого движок сам не грузит - без прекеша получаются error-модели
    -- (например башня у ульты guardian_of_the_ancients) и пропавшие эффекты.
    -- не через safe_require: он кидает error, а падать в Precache нельзя
    local ok, precacheList = pcall(require, 'lib/precache_list')

    if not ok then
        print("[AA] precache_list not loaded:", tostring(precacheList))
        precacheList = nil
    end

    if precacheList then
        -- ВНИМАНИЕ: список партиклов отсюда прекешить нельзя.
        --
        -- Движок держит загружаемые ресурсы в списке с индексом unsigned short,
        -- то есть максимум 32767 штук. Одна только папка particles (~500 файлов)
        -- съедает большую часть бюджета.
        -- precacheList.particles добавляет 318 путей, из которых 124 ведут в
        -- particles/units (ванильные геройские партиклы) и 59 в particles/econ -
        -- каждый такой партикл тянет за собой дерево детей, материалов и текстур.
        -- С ними карта падает на старте с
        --   CUtlBlockVector<...CLoadingResource*...>::GrowCount:
        --   unable to grow count by 1 (currently 32767)
        --
        -- Модели оставляем: их всего 21, они дешёвые и именно они чинили
        -- error-модель (башня у ульты guardian_of_the_ancients).
        for _, modelName in pairs(precacheList.models or {}) do
            PrecacheResource("model", modelName, context)
        end
    end

    -- Кастомные юниты.
    --
    -- Раньше тут синхронно прекешились ВСЕ юниты из npc_units_custom.txt (31
    -- штука). Каждый тянет модель, все свои способности и их партиклы со
    -- звуками - вместе с папкой particles это выбивало лимит загружаемых
    -- ресурсов (32767) ещё до входа в игру.
    --
    -- Поэтому на старте грузим только то, что стоит на карте с первой секунды.
    -- Остальное прекешится асинхронно по месту, и это уже написано:
    --   боссы          - lib/boss/boss_class.lua:84
    --   крипы          - lib/spawners/creep_spawner.lua:103
    -- Некрономикон и сова появляются только после покупки/каста, им хватает
    -- асинхронного прекеша в момент использования.
    local PRECACHE_AT_LOAD = {
        npc_dota_custom_tower = true,
        npc_dota_watch_tower = true,
        npc_aa_bulding_shrine_dire = true,
        npc_aa_bulding_shrine_radiant = true,
        npc_dota_lantern = true,
        npc_tree_thinker = true,
        npc_teleport = true,
        npc_aa_minimap_ancient_stack = true,
        npc_aa_minimap_big_stack = true,
        npc_aa_minimap_mid = true,
        npc_aa_minimap_portal = true,
        npc_aa_minimap_boss = true,
        npc_aa_minimap_cobold = true,
        npc_aa_minimap_neutral_stack = true,
        -- иконки рун, их создаёт lib/minimap_spots.lua
        npc_aa_minimap_rune_bounty = true,
        npc_aa_minimap_rune_xp = true,
        npc_aa_minimap_rune_unknown = true,
        npc_aa_minimap_icon_camp = true,
        npc_aa_minimap_icon_camp_big = true,
        npc_aa_minimap_icon_camp_mid = true,
        npc_aa_minimap_icon_camp_ancient = true,
        npc_aa_minimap_icon_death = true,
        npc_aa_minimap_icon_boss = true,
        -- круг захвата руны, lib/capture_points
        npc_aa_capture_point = true,
    }

    local units_kv = LoadKeyValues("scripts/npc/npc_units_custom.txt") or {}

    for unitname, unit_kv in pairs(units_kv) do
        if type(unit_kv) == "table" and type(unitname) == "string" and PRECACHE_AT_LOAD[unitname] then
            PrecacheUnitByNameSync(unitname, context)
        end
    end

    -- Модели дропа нейтралки: связка безумрудов и коробка, в которой лежат
    -- сами нейтральные предметы. Обе кладём руками - на них ссылаются только
    -- KV предметов (neutral_items_stat.txt), сами по себе они не подтянутся.
    PrecacheResource("model", "models/props_gameplay/crystal_shards/crystal_shards.vmdl", context)
    PrecacheResource("model", "models/props_gameplay/neutral_box.vmdl", context)

    -- Остальное
    DuelController:Precache(context)

    -- партиклы и модели премиум-косметики (lib/cosmetics/catalog.lua), не через safe_require
    -- премиум-косметика НЕ прекешится на карте: каталог грузится по запросу (lib/cosmetics/precache.lua,
    -- юниты npc_aa_cos_<id> в npc/cosmetic_precache_units.txt). Иначе FPS падал вдвое.

    -- партиклы спреев и хай-файвов (lib/cosmetics/social.lua), не через safe_require
    local okSoc, socErr = pcall(function()
        if AA_SKIP and AA_SKIP["precache_cosmetics"] then return end
        -- грузятся по требованию: юниты npc_aa_cos_<id> надетых спрея и хай-файва
        do return end
        CosmeticsSocial:Precache(context)
    end)

    if not okSoc then print("[AA] social cosmetics precache failed:", tostring(socErr)) end

    -- косметика грузится по требованию (lib/cosmetics/precache.lua)
    PrecacheResource("soundfile", "soundevents/game_sounds.vsndevts", context)
    PrecacheResource("soundfile", "soundevents/game_sounds_items.vsndevts", context)
    PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_shadowshaman.vsndevts", context)
    PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_axe.vsndevts", context)
    PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_techies.vsndevts", context)
    PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_gyrocopter.vsndevts", context)
    PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_lich.vsndevts", context)
    -- звуки кругов захвата рун, lib/capture_points
    PrecacheResource("soundfile", "soundevents/aa_capture_points.vsndevts", context)
    -- алерты: рёв рошана на атаку босса; звуки дуэли легионки на старт и победу
    PrecacheResource("soundfile", "soundevents/aa_alerts.vsndevts", context)
    -- свои звуки колеса фраз (sounds/aa_wheel, build_wheel_sounds.js); пустой файл тоже ок
    PrecacheResource("soundfile", "soundevents/aa_wheel.vsndevts", context)
    -- фразы колеса из 1x6 (gen_wheel_x6.js): ванильный soundboard и фан-контент + свои mp3 1x6
    PrecacheResource("soundfile", "soundevents/aa_wheel_x6.vsndevts", context)
    PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_legion_commander.vsndevts", context)
    -- крики боссов "атакуют" (lib/boss/boss_class ATTACK_ALERT_SOUNDS): это
    -- геройские звуки, без прекеша они молчат, если этих героев нет в матче
    PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_omniknight.vsndevts", context)
    PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_warlock.vsndevts", context)
	

	-- PrecacheResource("particle", "particles/items2_fx/teleport_end.vpcf", context)
	-- PrecacheResource("particle", "particles/new_charone/charone_spepcter.vpcf", context)

	-- precacheResource("model", "models/props_gameplay/donkey.vmdl", context)
	-- precacheResource("model", "models/props_gameplay/dummy/dummy.vmdl", context)
	-- precacheResource("model", "models/props_gameplay/dummy/dummy_large.vmdl", context)
	-- PrecacheResource("model", "models/items/hex/sheep_hex/sheep_hex_gold.vmdl", context)
	-- PrecacheResource("model", "models/items/hex/sheep_hex/sheep_hex.vmdl", context)
	-- precacheResource("model", "models/props_gameplay/donkey.vmdl", context)
	-- PrecacheResource("model", "models/tomes/tome_agi.vmdl", context)
	-- PrecacheResource("model", "models/tomes/tome_int.vmdl", context)
	-- PrecacheResource("model", "models/tomes/tome_str.vmdl", context)
	-- PrecacheResource("model", "models/tomes/tome_all.vmdl", context)
	-- PrecacheResource("model", "models/tomes/tome_level.vmdl", context)
	-- PrecacheResource("model", "models/tomes/tome_medical.vmdl", context)
		
end
local hero_table = safe_require('lib/hero_table')
local postsafe_requireList = {
	'lib/base/player',
	'lib/base/base_npc'
}
local forbidden_ability_boss = {
	["life_stealer_infest"] = 1,
	["chen_holy_persuasion"] = 1,
	["enchantress_enchant"] = 1,
	["item_devour_helm"] = 1,
	["item_iron_talon"] = 1,
	["night_stalker_hunter_in_the_night"] = 1,
	["snapfire_spit_creep"] = 1,
	["juggernaut_omni_slash"] = 1,
	["juggernaut_swift_slash"] = 1,
	["snapfire_gobble_up"] = 1,
	['item_bloodthorn'] = 1,
	['item_bloodthorn_2'] = 1,
	['item_bloodthorn_3'] = 1,
	['item_orchid'] = 1,
}
local crash_abilities = {
	["shadow_demon_disruption"] = 1,
	["obsidian_destroyer_astral_imprisonment"] = 1,
	["rubick_telekinesis"] = 1,
	["disruptor_thunder_strike"] = 1,
}

local illusion_bug_crash =
{
	["npc_dota_hero_dawnbreaker"] = 1,
	["npc_dota_hero_visage"] = 1,
	["npc_dota_hero_weaver"] = 1,
}
local forbidden_items_for_clones = {
	["item_refresher"] = 1,
	["item_recovery_orb"] = 1,
	["item_devour_helm"] = 1,
}
local armor_table = safe_require('creeps/armor_table_summon') -- armor to units
local Constants = safe_require('consts')
local cheat = false
local is_game_start = false
local is_game_end = false
local game_start_for_courier = false
local had_players_on_both_teams = false
KILL_LIMIT_CONST = 120
GOLD_PER_TICK = 0

KILL_LIMIT = 80

GOLD_FOR_COUR = 350

-- Сколько золота держим в дотовском кошельке. Всё сверх уходит в запас
-- (SaveGoldForPlayerId), иначе упрёмся в дотовский потолок 99999; игрок
-- видит кошелёк + запас через нет-таблицу gold.
local GOLD_WALLET_LIMIT = 50000

local teleport_range = 350

_G.Kills = {}
_G.KILL_LIMIT = KILL_LIMIT

RESPAWN_MODIFER = 0.135
SUMMON_MINUTE_SCALING = false -- старый скейл суммонов от минуты (creeps/armor_table_summon)
function Activate()
	print("[AA] Activate() called")
	GameRules.AngelArena = AngelArena()
	GameRules.AngelArena:InitGameMode()
	local fountains = Entities:FindAllByClassname('ent_dota_fountain')
    for _, fountain in pairs(fountains) do
    if ability then
        ability:SetLevel(100)
    end
    end
end

function UpdatePlayersCount()
    if is_game_end then return end

    local teamsData = {
        [DOTA_TEAM_GOODGUYS] = 0,
        [DOTA_TEAM_BADGUYS]  = 0,
    }

    local nPlayersConnected = 0

    TeamHelper:ApplyForPlayers(nil, function(playerid)
        if IsAbadonedPlayerID(playerid) then return end

        local team = PlayerResource:GetTeam(playerid)
        if team == 0 then return end -- invalid

        teamsData[team] = (teamsData[team] or 0) + 1
        nPlayersConnected = nPlayersConnected + 1
    end)

    local nRadiants = teamsData[DOTA_TEAM_GOODGUYS]
    local nDire     = teamsData[DOTA_TEAM_BADGUYS]

    if nRadiants > 0 and nDire > 0 then
        had_players_on_both_teams = true
    end

    -- Пока в игре ни разу не было двух команд, это одиночное лобби - завершать нечего.
    -- Без этой проверки хост, зашедший один, получал конец игры через 30 секунд.
    if not had_players_on_both_teams then return end

    if nPlayersConnected == 0 then
        DuelController:SetFreezeTimer(true)
        GameEnder:StartGameEnd(DOTA_TEAM_NEUTRALS)
        is_game_end = true
        return
    end

    local cheat = GameRules:IsCheatMode()
    if had_players_on_both_teams and (not cheat) and (nRadiants == 0 or nDire == 0) then
        local team = (nRadiants == 0) and DOTA_TEAM_BADGUYS or DOTA_TEAM_GOODGUYS
        DuelController:SetFreezeTimer(true)
        GameEnder:StartGameEnd(team)
        is_game_end = true
    end
end
function BackPlayersToMap()
	local heroes = HeroList:GetAllHeroes()

	for _, hero in pairs(heroes) do
		if hero and hero:IsAlive() then

			if not hero._info then
				function CheckPos(unit, pos)
					return pos[3] >= -2500
				end

				function GetBasePosition(team)
					if team == DOTA_TEAM_GOODGUYS then
						return Entities:FindByName(nil, "RADIANT_BASE"):GetAbsOrigin()
					elseif team == DOTA_TEAM_BADGUYS then
						return Entities:FindByName(nil, "DIRE_BASE"):GetAbsOrigin()
					end
				end

				local nSaveSteps = 20
				local fMinDist = 100
				hero._info = MakeMoveLimiter(hero, CheckPos, nSaveSteps, fMinDist, GetBasePosition(hero:GetTeamNumber()) )
			end

			hero._info:tick()
		end
	end
end
function AngelArena:InitGameMode()
	-- диагностика змеек Расты: какие юниты змеек движок знает
	for i = 1, 7 do
		local kv = GetUnitKeyValuesByName and GetUnitKeyValuesByName("npc_dota_shadow_shaman_ward_" .. i)
		print("[AA.wards] npc_dota_shadow_shaman_ward_" .. i .. ": " .. (kv and "есть" or "НЕТ"))
	end
	for _, moduleName in pairs(postsafe_requireList) do
		safe_require(moduleName)
	end
	local GameMode = GameRules:GetGameModeEntity()
	Convars:SetInt("dota_max_physical_items_purchase_limit", 100)
	GameRules:SetCustomVictoryMessage("#aa_on_win_message")

	-- Ванильный баннер победы (большой зелёный текст с частицами) иначе висит
	-- поверх итогового экрана и перекрывает таблицу. Даём ему отыграть
	-- появление и убираем - заголовок победы есть и на самом итоговом экране.
	GameRules:SetCustomVictoryMessageDuration(3)


	BossSpawner:Init()
	CreepSpawner:Init()

	CreepSpawner:RegisterOnSpawnCallback(function(arg) CreepLeveling:OnSpawnCallback(arg); end)
	CreepSpawner:RegisterOnDeathCallback(function(arg) CreepLeveling:OnDeathCallback(arg); end)

	-- лагеря, рядом с которыми никого нет, перестают сканировать карту в
	-- поисках цели: к 10 минуте таких почти все, а крипов на карте под 480
	CampSleep:Init()
	CreepSpawner:RegisterOnSpawnCallback(function(arg) CampSleep:OnCreepSpawned(arg); end)

	-- безумруды с зачищенных кемпов + гейт тиров нейтралок по дуэлям
	MadstoneSystem:Init()

	-- книги с зажатым Shift применяются сразу после покупки
	ShiftBuy:Init()
	if GameRules:IsCheatMode()then
		cheat = true
	end
	GameMode:SetCustomXPRequiredToReachNextLevel(Constants.XP_PER_LEVEL_TABLE)
	GameMode:SetUseCustomHeroLevels(true)

	GameMode:SetFountainPercentageHealthRegen(7)
	GameMode:SetFountainPercentageManaRegen(10)
	GameMode:SetFountainConstantManaRegen(20)

	GameMode:SetFreeCourierModeEnabled( true )
	GameMode:SetBuybackEnabled(true)
	GameMode:SetStashPurchasingDisabled(false)
	GameMode:SetLoseGoldOnDeath(true)
	GameRules:GetGameModeEntity():SetFriendlyBuildingMoveToEnabled(true);
	-- 2026-11-12: выбор героя ванильный (баны -> общий пик). Премиум-стадия перед банами -
	-- lib/pick_stages.lua: если в лобби есть премиум, она удлиняет стадию банов (P:PlanBanTime).
	GameRules:SetCustomGameBansPerTeam( 5 )
	GameRules:SetHeroSelectionTime(90)
	GameRules:SetPreGameTime(60)
	if GameRules:IsCheatMode() then
		GameRules:SetStrategyTime(1)
		GameMode:SetDraftingHeroPickSelectTimeOverride(25)
		GameMode:SetDraftingBanningTimeOverride(0)
	else
		GameMode:SetDraftingBanningTimeOverride(AAPICK_BAN_TIME or 20)
		GameMode:SetDraftingHeroPickSelectTimeOverride(60)
	end
	--GameRules:SetSameHeroSelectionEnabled(true)
	GameRules:SetGoldPerTick(GOLD_PER_TICK)
	GameRules:SetHeroRespawnEnabled(true)
	GameRules:SetPostGameTime(30)
	GameRules:SetStrategyTime(15.0)

	GameRules:SetCreepSpawningEnabled( false )

	GameRules:SetGoldTickTime(1)
	GameRules:SetTreeRegrowTime(180)
	GameRules:SetUseBaseGoldBountyOnHeroes(true)
	GameMode:SetBountyRuneSpawnInterval(120.0)
	GameRules:SetRuneSpawnTime(120)
	GameMode:SetCustomBackpackSwapCooldown(4.0)
	GameRules:SetStartingGold(750)

	GameRules:SetUseUniversalShopMode(true)

	-- свиток телепортации ванильный (item_tpscroll), поэтому слот телепорта,
	-- прицел и выдача свитка на смерть работают движком, без наших правок


	ListenToGameEvent("npc_spawned", Dynamic_Wrap( AngelArena, "OnNPCSpawned" ), self )
	ListenToGameEvent('game_rules_state_change', Safe_Wrap(AngelArena, 'OnGameStateChange'), self)
	ListenToGameEvent("entity_killed", Dynamic_Wrap(AngelArena, "OnEntityKilled"), self)
	ListenToGameEvent('dota_player_gained_level', Safe_Wrap(AngelArena, 'OnLevelUp'), self)
	ListenToGameEvent('dota_rune_activated_server', Safe_Wrap(AngelArena, 'OnRuneActivate'), self)
	ListenToGameEvent('dota_player_used_ability', Safe_Wrap(AngelArena, 'OnPlayerUsedAbility'), self)
	ListenToGameEvent('player_connect_full', Safe_Wrap(AngelArena, 'OnConnectFull'), self)
	ListenToGameEvent('player_disconnect', Safe_Wrap(AngelArena, 'OnPlayerDisconnect'), self)
	ListenToGameEvent("player_chat", Safe_Wrap(ChatListener, 'OnPlayerChat'), ChatListener)
	ListenToGameEvent('dota_item_purchased', Safe_Wrap(AngelArena, 'OnPlayerBuyItem'), self)
	ListenToGameEvent( "dota_player_learned_ability", Dynamic_Wrap( Special_bonus_base_aa, "OnAbilityLearned" ), self )

	GameRules:GetGameModeEntity():SetExecuteOrderFilter( Dynamic_Wrap( AngelArena, "ExecuteOrderFilterCustom" ), self )
	PlayerResource:ClearOnAbandonedCallbacks()
	PlayerResource:RegisterOnAbandonedCallback(function(arg) AngelArena:OnAbandoned(arg) end)
	LinkLuaModifier("modifier_godmode", 'modifiers/modifier_godmode', LUA_MODIFIER_MOTION_NONE)
	LinkLuaModifier("modifier_aa_hero", 'modifiers/modifier_aa_hero', LUA_MODIFIER_MOTION_NONE)
	LinkLuaModifier("bonus_str_tome", "modifiers/modifier_aa_hero", LUA_MODIFIER_MOTION_NONE)
	LinkLuaModifier("bonus_agi_tome", "modifiers/modifier_aa_hero", LUA_MODIFIER_MOTION_NONE)
	LinkLuaModifier("bonus_int_tome", "modifiers/modifier_aa_hero", LUA_MODIFIER_MOTION_NONE)
	LinkLuaModifier("modifier_full_disable_stun", 'modifiers/modifier_full_disable_stun', LUA_MODIFIER_MOTION_NONE)
	LinkLuaModifier("modifier_mid_teleport", "modifiers/modifier_mid_teleport", LUA_MODIFIER_MOTION_NONE)
	LinkLuaModifier("modifier_medical_tractate", 'modifiers/modifier_medical_tractate', LUA_MODIFIER_MOTION_NONE)
	LinkLuaModifier("modifier_medical_tractate_2", 'modifiers/modifier_medical_tractate', LUA_MODIFIER_MOTION_NONE)
	LinkLuaModifier("modifier_duel_vision", 'modifiers/modifier_duel_vision', LUA_MODIFIER_MOTION_NONE)
	LinkLuaModifier("modifier_repick", 'modifiers/modifier_repick', LUA_MODIFIER_MOTION_NONE)
	LinkLuaModifier('modifier_bat', 'modifiers/modifier_bat', LUA_MODIFIER_MOTION_NONE)
	LinkLuaModifier("modifier_dissapear", 'modifiers/modifier_dissapear', LUA_MODIFIER_MOTION_NONE)

	-- телеметрия: обёртки фильтров золота и урона ставим до регистрации (lib/match_tracker.lua)
	if MatchTracker then pcall(MatchTracker.WrapFilters, MatchTracker, AngelArena) end

	GameMode:SetDamageFilter(Safe_Wrap(AngelArena, "DamageFilter"), self)
	GameMode:SetRuneSpawnFilter(Safe_Wrap(AngelArena, "ModifierRuneSpawn"), self)
	GameMode:SetModifyGoldFilter(Safe_Wrap(AngelArena, "GoldFilter"), self)
	GameMode:SetModifyExperienceFilter(Safe_Wrap(AngelArena, "ExperienceFilter"), self)
	-- AttributeDerivedStats
	--GameMode:SetCustomAttributeDerivedStatValue(DOTA_ATTRIBUTE_STRENGTH_MAGIC_RESISTANCE_PERCENT, 0)
	--GameMode:SetCustomAttributeDerivedStatValue(DOTA_ATTRIBUTE_STRENGTH_STATUS_RESISTANCE_PERCENT, 0)
	--GameMode:SetCustomAttributeDerivedStatValue(DOTA_ATTRIBUTE_STRENGTH_HP_REGEN, 0)
	--GameMode:SetCustomAttributeDerivedStatValue(DOTA_ATTRIBUTE_AGILITY_MOVE_SPEED_PERCENT, 0.2)
	--GameMode:SetCustomAttributeDerivedStatValue(DOTA_ATTRIBUTE_AGILITY_DAMAGE , 1.2)
	--GameMode:SetCustomAttributeDerivedStatValue(DOTA_ATTRIBUTE_AGILITY_ARMOR , 0.112)
	--GameMode:SetCustomAttributeDerivedStatValue(DOTA_ATTRIBUTE_INTELLIGENCE_MANA_REGEN, 0)
	--GameMode:SetCustomAttributeDerivedStatValue(DOTA_ATTRIBUTE_INTELLIGENCE_MAGIC_RESIST, 0)

	GameRules:GetGameModeEntity():SetThink( "OnThink", self, "GlobalThink", 2 )

	GameMode:SetCustomRadiantScore(0)
	GameMode:SetCustomDireScore(0)
	_G.Kills[DOTA_TEAM_GOODGUYS] = _G.Kills[DOTA_TEAM_GOODGUYS] or 0
	_G.Kills[DOTA_TEAM_BADGUYS] = _G.Kills[DOTA_TEAM_BADGUYS] or 0

	AngelArena:OnGameStateChange()

	if GameRules:IsCheatMode() then
		safe_require('lib/debug/keyexec')
		KeyExec:Init()
	end

end

function AngelArena:ModifierRuneSpawn(keys)
	--print(EntIndexToHScript(keys.spawner_entindex_const):GetName())
	--print(keys.rune_type)
	function Almostequal(value1, value2, epsilon)
		return math.abs(value1 - value2) < epsilon
	end
	local rune_type = keys.rune_type

	local runes = { 0, 1, 2, 3, 4, 6, 9}

	local Dotatime = GameRules:GetDOTATime(false, false)
		keys.rune_type = runes[RandomInt(1, #runes)]

	-- Фильтр срабатывает на каждом спавне руны усиления. Запоминаем, когда
	-- будет следующая: интервал задан через GameRules:SetRuneSpawnTime(120).
	-- Отсюда это читает lib/bounty.lua и кладёт в нет-таблицу rune_timers,
	-- по которой панорама рисует кружки под таймером.
	_G.NEXT_POWER_RUNE_TIME = Dotatime + 120
	-- сразу в нет-таблицу: раньше кружок ждал следующей публикации баунти и показывал старое время
	if Bounty and Bounty.PublishTimers then pcall(Bounty.PublishTimers, Bounty) end

	-- Заодно запоминаем сам спавнер: по нему alt-клик по кружку руны усиления
	-- ставит пинги (lib/bounty.lua -> lib/panorama_pings.lua). До первой руны
	-- точки ищутся по классу энтити, дальше берутся отсюда.
	if Bounty then
		Bounty:RememberPowerSpawner(keys.spawner_entindex_const)
	end
	if MinimapSpots then
		MinimapSpots:OnRuneSpawn("power")
	end

	return true
end
function AngelArena:OnRuneActivate(event)
	local runeid = event.rune
	local playerid = event.PlayerID

	EndGameStats:OnRune(playerid, runeid)
	local hero = PlayerResource:GetPlayer(playerid):GetAssignedHero()

	if not hero then return end

	if runeid == DOTA_RUNE_BOUNTY then
		-- игровые часы, а не время с запуска сервера: GetGameTime включал загрузку
		-- и пик, и руна на 2-й минуте давала по 1500
		local cur_min = math.max(0, GameRules:GetDOTATime(false, false)) / 60

		local item_mod_table = {
			{ "item_hand_of_midas",  40 + 18 * cur_min },
			-- мидас из нашего магазина (ванильный item_hand_of_midas выключен, бонус раньше не работал)
			{ "item_midas_aa",       40 + 18 * cur_min },
			{ "item_advanced_midas", 60 + 27 * cur_min }
		}

		local hero_mod_table = {
			["npc_dota_hero_alchemist"] = 2,
		}

		local gold_without_mods = 40 + 14 * cur_min

		function CalcBountyGold( hero )
			local hero_mult = hero_mod_table[ hero:GetUnitName() ] or 1

			local item_gold = 0
			for _, data in pairs(item_mod_table) do
				local item = data[1]
				local gold = data[2]

				if hero:HasItemInInventory(item) and gold > item_gold then
					item_gold = gold
				end
			end

			return hero_mult * ( gold_without_mods + item_gold )
		end

		local team = hero:GetTeamNumber()

		TeamHelper:ApplyForHeroes(team, function(pid, unit)
			local gold = CalcBountyGold( unit )
			local before = unit:GetGold()
			local _ = (AATagGold or function(_, f) f() end)("rune", function() unit:ModifyGold(gold, false, 0) end)
			-- диагностика руны: сколько начислили и сколько реально пришло
			print(string.format("[AA.rune] bounty %s: min=%.2f game_time=%.1f gold=%d got=%d",
				unit:GetUnitName(), cur_min, GameRules:GetGameTime(), gold, unit:GetGold() - before))
			SendOverheadEventMessage(unit, OVERHEAD_ALERT_GOLD, unit, gold,nil)
		end)

		-- в фиде, как в доте, только база "+N всем героям", без бонусов мидаса и алхимика
		if KillFeed then KillFeed:Rune("bounty", playerid, team, gold_without_mods) end
	end
	if runeid == DOTA_RUNE_XP then
		-- игровые часы, а не время с запуска сервера: GetGameTime включал загрузку
		-- и пик, и руна на 2-й минуте давала по 1500
		local cur_min = math.max(0, GameRules:GetDOTATime(false, false)) / 60

		local item_mod_table = {
			{"item_talisman_of_mastery", 20 * cur_min },
			-- и всё, что из него собирается (talisman_of_heal.txt): раньше бонус терялся после апгрейда
			{"item_talisman_of_heal", 20 * cur_min },
			{"item_talisman_of_heal_2", 20 * cur_min },
		}
		local xp_without_mods = 70 + 18 * cur_min

		function CalcWisdomXp(hero )
			local item_xp = 0
			for _, data in pairs(item_mod_table) do
				local item = data[1]
				local xp = data[2]

				if hero:HasItemInInventory(item) and xp > item_xp then
					item_xp = xp
				end
			end

			return 1 * ( xp_without_mods + item_xp )
		end

		local team = hero:GetTeamNumber()

		TeamHelper:ApplyForHeroes(team, function(pid, unit)
			local xp = CalcWisdomXp( unit )
			unit:AddExperience(xp, 0, true,true)
			SendOverheadEventMessage(unit, OVERHEAD_ALERT_XP, unit, xp,nil)
		end)

		if KillFeed then KillFeed:Rune("wisdom", playerid, team, xp_without_mods) end
	end
	local item
	for i = 0, 5 do
		item = hero:GetItemInSlot(i)
		if item and item:GetPurchaser() == hero then
			if item and (item:GetName() == "item_unknown_amulet")then
				if item:GetCurrentCharges() < 4 then
					item:SetCurrentCharges(item:GetCurrentCharges() + 2)
				else
					item:SetCurrentCharges(item:GetCurrentCharges() + 1)
				return 
				end 
			end
		end
	end
end
function AngelArena:OnPlayerDisconnect(event)
	local name = event.name
	local networkid = event.networkid
	local reason = event.reason
	local userid = event.userid
end
function AngelArena:OnAbandoned(arg)
	local playerid = arg.playerid

	if KillFeed then KillFeed:Abandon(playerid) end

	local abaddonTeam = PlayerResource:GetTeam(playerid)
	local heroTeam = nil

	if abaddonTeam == DOTA_TEAM_GOODGUYS then
		heroTeam = DOTA_TEAM_BADGUYS
	elseif abaddonTeam == DOTA_TEAM_BADGUYS then
		heroTeam = DOTA_TEAM_GOODGUYS
	else
		return
	end

	local kills = _G.Kills[heroTeam] or 0
	local diff = (KILL_LIMIT - kills)

	local heroes = PlayerResource:GetHeroes(abaddonTeam)

	local connectedHeroes = 0

	for pid, hero in pairs(heroes) do
		if not (PlayerResource:IsAbandoned(pid) and hero:GetTeamNumber() == abaddonTeam) then
			connectedHeroes = connectedHeroes + 1
		end
	end
	if connectedHeroes == 0 then return end

	kills = kills + math.ceil(diff / (connectedHeroes + 1))

	if kills > KILL_LIMIT then return end

	_G.Kills[heroTeam] = kills

	local GameMode = GameRules:GetGameModeEntity()

	GameMode:SetCustomDireScore( _G.Kills[DOTA_TEAM_BADGUYS] )
	GameMode:SetCustomRadiantScore( _G.Kills[DOTA_TEAM_GOODGUYS] )
	Attentions:SetTeamKills( _G.Kills[DOTA_TEAM_GOODGUYS], _G.Kills[DOTA_TEAM_BADGUYS] )
end
-- Evaluate the state of the game
function AngelArena:OnThink()
	if GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
	end
	if GameRules:State_Get() >= DOTA_GAMERULES_STATE_POST_GAME then
		return nil
	end
	return 1
end

function AngelArena:OnConnectFull(event)
	-- в player_connect_full есть PlayerID; сущность игрока по index+1 на этот
	-- момент бывает ещё не создана (player = nil), тогда userid не запоминался
	local playerID = event.PlayerID
	if playerID == nil and event.index then
		local player = EntIndexToHScript(event.index + 1)
		if player and player.GetPlayerID then playerID = player:GetPlayerID() end
	end
	if playerID == nil or playerID < 0 then return end

	CustomGameEventManager:Send_ServerToAllClients("MakeNeutralItemsInShopColored", {})
	PlayerResource:OnPlayerConnected(playerID, event.userid)
end
function AngelArena:GoldFilter(event)
	-- доля, которую богатый герой отдал тимейту: в золото команды она уже
	-- попала один раз, когда её получил сам герой
	if TeamGoldShare and TeamGoldShare._paying then
		AngelArena:SaveGoldForPlayerId(event.player_id_const, event.gold)
		return true
	end

	-- Золото за убийство героя платит только lib/hero_kill_bounty.lua по своим
	-- формулам. Движковое (база героя, копейки ассистам, первая кровь)
	-- выбрасываем; наши выплаты и камбэк идут под флагами.
	if event.reason_const == DOTA_ModifyGold_HeroKill
		and not (KillFeed and KillFeed.ourPayout)
		and not (HeroKillBounty and HeroKillBounty.ourPayout)
		and not (TeamGoldShare and TeamGoldShare._bypass)
	then
		return false
	end

	-- золото за убийство героя для своего килфида (lib/kill_feed.lua), до
	-- командной делёжки: в фиде - сколько герой заработал убийством
	if KillFeed then
		KillFeed:OnGold(event.player_id_const, event.gold, event.reason_const, TeamGoldShare and TeamGoldShare._bypass)
	end

	ComebackSystem:OnGiveGold( event.player_id_const, event.gold, event.reliable, event.reason_const )

	-- командная делёжка (lib/team_gold_share.lua); камбек и внутренние
	-- переносы мода идут под TeamGoldShare._bypass и не делятся
	if TeamGoldShare and not TeamGoldShare._bypass then
		event.gold = TeamGoldShare:OnGold(event.player_id_const, event.gold, event.reason_const)
	end
	-- фильтр дёргается на каждый голд-тик и каждое убийство, так что обрабатываем
	-- только того игрока, чьё золото изменилось, а не всех сразу
	AngelArena:SaveGoldForPlayerId(event.player_id_const, event.gold)
	return true
end
function AngelArena:ExperienceFilter(event)
	-- опыт движковой руны мудрости для своего килфида (lib/kill_feed.lua)
	if KillFeed then KillFeed:OnXp(event.player_id_const, event.experience, event.reason_const) end

	-- опыт за убийство героя тоже только наш (lib/hero_kill_bounty.lua)
	if event.reason_const == DOTA_ModifyXP_HeroKill and not (HeroKillBounty and HeroKillBounty.ourPayout) then
		return false
	end

	return true
end
function AngelArena:OnPlayerBuyItem(event)
	local playerid = event.PlayerID

	EndGameStats:OnItemPurchased(playerid, event.itemname, event.itemcost)

	AngelArena:SaveGoldForPlayerId(playerid,0)
end
-- Счётчик золота (нет-таблица gold = кошелёк + запас) сверяем по таймеру. Раньше его писали
-- только из GoldFilter и покупки: фильтр срабатывает ДО зачисления (в таблице оставалась старая
-- сумма), а продажа не писала совсем - в начале игры показывало 250, после покупки/продажи
-- не то. SaveGoldForPlayerId пишет таблицу только при изменении, так что тик дешёвый.
local GOLD_SYNC_PERIOD = 0.2

Timers:CreateTimer({ endTime = GOLD_SYNC_PERIOD, useGameTime = false, callback = function()
	if GameRules:State_Get() >= DOTA_GAMERULES_STATE_HERO_SELECTION and GameRules:State_Get() <= DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
		for pid = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
			if PlayerResource:IsValidPlayerID(pid) then
				local ok, err = pcall(AngelArena.SaveGoldForPlayerId, AngelArena, pid, 0)

				if not ok then print("[AA.gold] sync: " .. tostring(err)) end
			end
		end
	end

	return GOLD_SYNC_PERIOD
end })

function AngelArena:SaveGold(gold)
	TeamHelper:ApplyForPlayers( nil, function(pid)
		AngelArena:SaveGoldForPlayerId(pid,gold)
	end)
end
function AngelArena:SaveGoldForPlayerId(playerid,gold)
	if not PlayerResource:IsValidPlayerID(playerid) then return end

	local player_gold = PlayerResource:GetGold(playerid)

	local tPlayers = self.tPlayers

	if not tPlayers then
	  tPlayers = {}
	  self.tPlayers = tPlayers
	end

	if not IsAbadonedPlayerID(playerid) then
	  	tPlayers[playerid] = tPlayers[playerid] or {} -- nil error exception
	  	tPlayers[playerid].gold = tPlayers[playerid].gold or 0 -- nil error exception

	  	if player_gold > GOLD_WALLET_LIMIT then
			local gold_to_save = player_gold - GOLD_WALLET_LIMIT
			tPlayers[playerid].gold = tPlayers[playerid].gold + gold_to_save
			PlayerResource:SpendGold(playerid, gold_to_save, 0)
	  	end

	  	if player_gold < GOLD_WALLET_LIMIT then
			local free_gold = GOLD_WALLET_LIMIT - player_gold
			local total_saved_gold = tPlayers[playerid].gold
			if total_saved_gold > free_gold then
			  tPlayers[playerid].gold = tPlayers[playerid].gold - free_gold
			  -- перенос из копилки - не доход, не делим
			  local _ = (AATagGold or function(_, f) f() end)("stash_move", function() if TeamGoldShare then TeamGoldShare:Bypass(PlayerResource.ModifyGold, PlayerResource, playerid, free_gold, true, 0) else PlayerResource:ModifyGold(playerid, free_gold, true, 0) end end)
			else
			  local _ = (AATagGold or function(_, f) f() end)("stash_move", function() if TeamGoldShare then TeamGoldShare:Bypass(PlayerResource.ModifyGold, PlayerResource, playerid, total_saved_gold, true, 0) else PlayerResource:ModifyGold(playerid, total_saved_gold, true, 0) end end)
			  tPlayers[playerid].gold = 0
			end
	  	end

	  	local total_gold = PlayerResource:GetGold(playerid) + tPlayers[playerid].gold -- почему не player_gold? потому что золото игрока изменилось, а эта переменная нет :c

		-- неттейбл рассылается всем клиентам, поэтому пишем только при изменении
		if tPlayers[playerid].netGold ~= total_gold then
			tPlayers[playerid].netGold = total_gold
			CustomNetTables:SetTableValue("gold", "player_id_" .. playerid, { gold = total_gold })
		end
	end
end

-- Выдать крупную сумму так, чтобы она не упёрлась в дотовские 99999. В
-- кошелёк через ModifyGold кладём только то, что влезает до
-- GOLD_WALLET_LIMIT, остальное сразу в запас: SaveGoldForPlayerId докладывает
-- его в кошелёк по мере трат, а нет-таблица gold показывает кошелёк + запас.
-- Запас идёт мимо GoldFilter, поэтому в золото команды для камбэка его
-- записываем сами - как и обычный доход сверх лимита, который GoldFilter
-- видит целиком до того, как излишек уедет в запас.
-- Монетки над героем и звук при наградах мода (дуэль, боссы, башни и т.д.),
-- без цифр - надписи над героем выглядят плохо. Видит только сам игрок.
function AngelArena:ShowGoldPopup(playerid, gold)
	if math.floor(gold or 0) <= 0 then return end

	local hero = PlayerResource:GetSelectedHeroEntity(playerid)
	if not hero or hero:IsNull() or not IsValidEntity(hero) then return end

	local player = PlayerResource:GetPlayer(playerid)
	if not player then return end

	-- монетки летят от CP0 к CP1: без CP1 они уходят в начало карты и их не
	-- видно, поэтому обе точки на самом герое
	local fx = ParticleManager:CreateParticleForPlayer("particles/generic_gameplay/lasthit_coins.vpcf", PATTACH_ABSORIGIN_FOLLOW, hero, player)
	ParticleManager:SetParticleControlEnt(fx, 1, hero, PATTACH_POINT_FOLLOW, "attach_hitloc", hero:GetAbsOrigin(), true)
	ParticleManager:ReleaseParticleIndex(fx)

	-- летящая цифра, как при подборе баунти-руны
	SendOverheadEventMessage(player, OVERHEAD_ALERT_GOLD, hero, math.floor(gold), nil)

	EmitSoundOnClient("General.Coins", player)
end

function AngelArena:GiveGold(playerid, gold, reliable, reason)
	if not PlayerResource:IsValidPlayerID(playerid) then return end

	gold = math.floor(gold)

	if gold <= 0 then return end

	-- у вышедшего запаса нет, его кошелёк раздаёт ShareGold
	if IsAbadonedPlayerID(playerid) then
		local room = math.max(0, 99999 - PlayerResource:GetGold(playerid))

		PlayerResource:ModifyGold(playerid, math.min(gold, room), reliable, reason)
		return
	end

	local room = math.max(0, GOLD_WALLET_LIMIT - PlayerResource:GetGold(playerid))
	local now = math.min(gold, room)

	if now > 0 then
		PlayerResource:ModifyGold(playerid, now, reliable, reason)
	end

	local rest = gold - now

	if rest > 0 then
		self.tPlayers = self.tPlayers or {}
		self.tPlayers[playerid] = self.tPlayers[playerid] or {}
		self.tPlayers[playerid].gold = (self.tPlayers[playerid].gold or 0) + rest

		ComebackSystem:OnGiveGold(playerid, rest)

		-- запас идёт мимо GoldFilter, килфиду докладываем сами
		if KillFeed then
			KillFeed:OnGold(playerid, rest, reason, TeamGoldShare and TeamGoldShare._bypass)
		end
	end

	-- пересчитать и разослать кошелёк + запас
	self:SaveGoldForPlayerId(playerid, 0)
end

function AngelArena:ShareGold()
	local teamGolds = {}

	TeamHelper:ApplyForPlayers(nil, function(playerID)
		local team = PlayerResource:GetTeam(playerID)

		local teamData = teamGolds[team] or {
			nPlayers = 0,
			freeGold = 0,
		}

		if PlayerResource:IsConnected( playerID ) then
			teamData.nPlayers = teamData.nPlayers + 1
		end

		if not PlayerResource:IsAbandoned( playerID ) then return end

		teamData.freeGold = teamData.freeGold + PlayerResource:GetGold( playerID )

		PlayerResource:SetGold(playerID, 0, false)
		PlayerResource:SetGold(playerID, 0, true)
	end)


	TeamHelper:ApplyForPlayers(nil, function(playerID)
		local team = PlayerResource:GetTeam(playerID)

		local teamData = teamGolds[team]

		if not teamData then return end

		local newGold = teamData.freeGold / teamData.nPlayers

		local _ = (AATagGold or function(_, f) f() end)("abandon", function() PlayerResource:ModifyGold(playerID, newGold, true, 0) end)
	end)
end
-- Запуск контроллера дуэлей ровно один раз (из PRE_GAME, а при необходимости -
-- из GAME_IN_PROGRESS). firstInterval - секунды до первой дуэли, nil = 30.
function AngelArena:_StartDuelController(firstInterval)
	if duel_inited then return end
	duel_inited = true

	DuelController:OnGameStart(function(winnerTeam)
		is_game_end = true
		DuelController:SetFreezeTimer(true)
		GameEnder:ForceEnd(winnerTeam)
	end, firstInterval)
end

function AngelArena:OnGameStateChange()
	if GameRules:State_Get() == DOTA_GAMERULES_STATE_PRE_GAME then
		print('DOTA_GAMERULES_STATE_PRE_GAME')
		local portals = {
			"teleport_radiant_top",
			"teleport_radiant_bot",
			"teleport_dire_top",
			"teleport_dire_bot",
		}
		
		
		local spawners = Entities:FindAllByClassname("npc_dota_neutral_spawner")

		for _, spawner in pairs(spawners) do
			UTIL_Remove(spawner)
		end
		print('remove spawner')

		-- Невидимые юниты-иконки (npc_aa_minimap_*) стоят на карте ради значков
		-- кемпов, боссов и порталов на миникарте. modifier_hidden_from_map приходит
		-- врождённой способностью, но на здания из Hammer она может и не
		-- навеситься - поэтому проверяем и при нужде вешаем сами. Сквозь туман
		-- юнит показывает отдельный modifier_minimap_icon_fow.
		local icons = 0

		-- часть иконок стоит не зданиями, а существами (npc_aa_minimap_icon_camp*),
		-- и раньше цикл их не видел: модификатор не вешался, и эти невидимые
		-- юниты на кемпах можно было выделить мышкой
		local icon_units = {}

		for _, classname in pairs({"npc_dota_building", "npc_dota_creature", "npc_dota_creep"}) do
			for _, unit in pairs(Entities:FindAllByClassname(classname)) do
				table.insert(icon_units, unit)
			end
		end

		for _, unit in pairs(icon_units) do
			local unitname = unit.GetUnitName and unit:GetUnitName() or ""

			if unitname:sub(1, 15) == "npc_aa_minimap_" then
				if not unit:HasModifier("modifier_hidden_from_map") then
					unit:AddNewModifier(unit, nil, "modifier_hidden_from_map", {})
				end

				-- видно сквозь туман; кемпы, которые перерисует lib/minimap_spots.lua,
				-- его потом снимут
				if not unit:HasModifier("modifier_minimap_icon_fow") then
					unit:AddNewModifier(unit, nil, "modifier_minimap_icon_fow", {})
				end

				icons = icons + 1
			end
		end

		print('[AA] minimap icons:', icons)

		for number,name in pairs(portals) do
			local spawnpoint = Entities:FindByName( nil, name )
			self.creep = nil
			if number <= 2 then
				self.creep = CreateUnitByName("npc_teleport", spawnpoint:GetAbsOrigin(), false, nil, nil, DOTA_TEAM_GOODGUYS)
				self.creep:SetMaterialGroup("0")
			end
			if number >= 3 then
				self.creep = CreateUnitByName("npc_teleport", spawnpoint:GetAbsOrigin(), false, nil, nil, DOTA_TEAM_BADGUYS)
				self.creep:SetMaterialGroup("1")
			end
			AddFOWViewer(DOTA_TEAM_GOODGUYS, self.creep:GetAbsOrigin(), 8, -1, true)
			AddFOWViewer(DOTA_TEAM_BADGUYS, self.creep:GetAbsOrigin(), 8, -1, true)
			self.creep:AddNewModifier(self.creep, nil,'modifier_mid_teleport', {duration = -1} )
		end
		print('initrotal')
		local player = PlayerResource:GetPlayerCount()
		local needkill = KILL_LIMIT_CONST / 10 * player
		KILL_LIMIT = needkill
		_G.KILL_LIMIT = needkill
		print('kl')
		CustomGameEventManager:Send_ServerToAllClients("MakeNeutralItemsInShopColored", {})

		Attentions:SetKillLimit( KILL_LIMIT )
		Bounty:Init()
		MinimapSpots:Init()

		-- Дуэльный таймер стартуем уже в PRE_GAME, чтобы отсчёт был виден сразу.
		-- Первая дуэль всё равно в 0:30 игрового времени: первый интервал =
		-- (секунд до горна) + 30. Время до горна - отрицательное DOTA-время;
		-- если его не удалось прочитать - берём 60 с пре-игры + 30.
		local dotaTime = GameRules:GetDOTATime(false, true)
		local toHorn = 60
		if dotaTime < 0 then
			toHorn = math.ceil(-dotaTime)
		end
		AngelArena:_StartDuelController(toHorn + 30)

		PauseGame(true)
		local towers = Entities:FindAllByClassname("npc_dota_tower")
		for _, tower in pairs(towers) do
			--print('1')
			tower:RemoveModifierByName("modifier_invulnerable")
			--local ability
			--for _,v in ipairs(tower:FindAllModifiers()) do
			--	print(v:GetName())
			--end
		end
		local teleports = Entities:FindAllByClassname("npc_dota_unit_twin_gate")
		print('telepooooooooort')
		for _, teleport in pairs(teleports) do
			print('telepooooooooort')
			teleport:RemoveModifierByName("modifier_invulnerable")
		end
	end

	if GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
		if not is_game_start then
			GameRules:SetTimeOfDay( 0.251 )
			CreepSpawner:StartSpawning()
			BossSpawner:OnGameStart()
			BearSpawner:SpawnBear()
			RepickMenu:init()
			Timers:CreateTimer(0.1, function()
				GPM_Init()
			end)
			Timers:CreateTimer(0.5, function()
				AngelArena:SaveGold(0)
				return 0.5
			end)
			Timers:CreateTimer(10, function()
				AngelArena:ShareGold()
				UpdatePlayersCount()
				return 10
			end)

			Timers:CreateTimer(0.5, function()
				BackPlayersToMap()
				return 0.5
			end)

			-- Двери арены открываем здесь, как и раньше (не в PRE_GAME).
			DuelController:SetDoorsState(true)

			-- Таймер дуэлей обычно уже запущен в PRE_GAME (см. выше). Этот вызов -
			-- страховка на случай, если PRE_GAME не прошёл; внутри стоит тот же
			-- guard duel_inited, поэтому дважды таймер не поднимется.
			AngelArena:_StartDuelController(nil)

			local ok, rad, dire = pcall(GetActivePlayersPerTeam)

			if ok then
				had_players_on_both_teams = (rad > 0 and dire > 0)
			end

			is_game_start = true
		end
	end
end
function AngelArena:IsUnitBear(unit)
	if not unit or not IsValidEntity(unit) then return false end
	local unit_name = unit:GetUnitName()
	if unit_name == "npc_dota_lone_druid_bear1" or unit_name == "npc_dota_lone_druid_bear2"
			or unit_name == "npc_dota_lone_druid_bear3" or unit_name == "npc_dota_lone_druid_bear4"
			 or unit_name == "npc_dota_lone_druid_bear5" or unit_name == "npc_dota_lone_druid_bear6"
			 or unit_name == "npc_dota_lone_druid_bear7" then
		return true
	end

	return false
end
local pickedCustomHero= {}
function AngelArena:OnNPCSpawned(keys)
	local npc = EntIndexToHScript(keys.entindex)
	local spawnedUnit = EntIndexToHScript(keys.entindex)
	if not npc then return end
	-- Змейки Расты - и из ульты, и шардовые от Shackles (их создаёт ванильная
	-- способность): сплэш суммонов и бафф от статов хозяина. Хозяин
	-- ставится кадром позже - ждём, как у медведя.
	if npc.GetUnitName and (string.find(npc:GetUnitName(), "shadow_shaman_ward", 1, true)
		or npc:GetClassname() == "npc_dota_shadowshaman_serpentward") then
		print("[AA.wards] заспавнилась " .. npc:GetUnitName() .. " hp=" .. tostring(npc:GetMaxHealth()))

		local ward = npc
		local tries = 0
		Timers:CreateTimer(FrameTime(), function()
			if not ward or ward:IsNull() or not ward:IsAlive() then return nil end

			local cleave = ward:FindAbilityByName("summon_cleave") or ward:AddAbility("summon_cleave")
			if cleave and cleave:GetLevel() < 1 then cleave:SetLevel(1) end

			local hero = SummonUtils and SummonUtils:GetOwnerHero(ward)

			if hero and not hero:IsNull() and hero ~= ward then
				local mod = ward:FindModifierByName("modifier_summon_power")
				if mod and mod:GetCaster() ~= hero then mod:Destroy() mod = nil end
				if not mod then ward:AddNewModifier(hero, nil, "modifier_summon_power", {}) end
				return nil
			end

			tries = tries + 1
			if tries >= 30 then
				print("[AA.wards] не нашёл хозяина у " .. ward:GetUnitName())
				return nil
			end
			return FrameTime()
		end)
	end
	-- солдаты Wukong's Command из пула - герои-юниты MK, но не игроки:
	-- никакой героической логики (heroes/monkey_king/monkey_king_wukongs_command_aa)
	if AA_SPAWNING_MK_SOLDIER or npc.aa_mk_soldier then return end
	EndGameStats:OnHeroSpawned(npc)
	local unitname = npc:GetUnitName()
	local unit_owner = npc:GetOwnerEntity()
	if npc.bFirstSpawned == nil then
		npc.bFirstSpawned = true
		if hero_table[unitname]then
			--npc:AddItemByName("item_repick_hero")
		end
		if npc:IsRealHero()then
			npc:AddNewModifier(npc, nil, "modifier_aa_hero", {duration = -1})
			npc:AddAbility("divine_intervention")
			if npc:HasAbility("twin_gate_portal_warp") == true then
                npc:RemoveAbility("twin_gate_portal_warp");
            end
			--npc:AddNewModifier(npc, nil, "modifier_bat", {duration = -1})
		end
		if npc:IsIllusion() then
			local player = PlayerResource:GetSelectedHeroEntity( npc:GetPlayerOwnerID() )
			npc:AddNewModifier(npc, nil, "modifier_aa_hero", {duration = -1})
			npc:AddNewModifier(npc, nil, "bonus_str_tome", {duration = -1}):SetStackCount(player:FindModifierByName('bonus_str_tome'):GetStackCount())
			npc:AddNewModifier(npc, nil, "bonus_agi_tome", {duration = -1}):SetStackCount(player:FindModifierByName('bonus_agi_tome'):GetStackCount())
			npc:AddNewModifier(npc, nil, "bonus_int_tome", {duration = -1}):SetStackCount(player:FindModifierByName('bonus_int_tome'):GetStackCount())

		end
	end
	if npc:IsRealHero() then
		Timers:CreateTimer(10, function()
			if npc:HasModifier("modifier_fountain_invulnerability") then
				npc:RemoveAllModifiersByName("modifier_fountain_invulnerability")
			end
		end)
	end
	if spawnedUnit:IsIllusion() and spawnedUnit:IsHero() then
		local playerid = spawnedUnit:GetPlayerOwnerID()

		if playerid ~= nil and playerid ~= -1 then
			local original_hero = PlayerResource:GetSelectedHeroEntity( playerid )

			-- Копируем способности и статы только если иллюзия - копия САМОГО героя игрока.
			-- Dark Portrait гримстроука и подобные делают иллюзию чужого героя: для них
			-- эта ветка затирала бы способности и атрибуты копией владельца.
			local is_self_copy = original_hero and not original_hero:IsNull()
				and spawnedUnit:GetUnitName() == original_hero:GetUnitName()

			if is_self_copy then
				if not illusion_bug_crash[spawnedUnit:GetUnitName()] then
					local ability
					for i = 0, spawnedUnit:GetAbilityCount() - 1 do
						ability = spawnedUnit:GetAbilityByIndex(i)
						if ability then spawnedUnit:RemoveAbility(ability:GetAbilityName()) end
					end

					for i = 0, original_hero:GetAbilityCount() - 1 do
						ability = original_hero:GetAbilityByIndex(i)
						if ability then spawnedUnit:AddAbility(ability:GetAbilityName()) end
					end
				end

				-- Раньше отсюда вычитался прирост за уровни, из-за чего иллюзия
				-- получала атрибуты героя 1 уровня. Копируем базу как есть.
				spawnedUnit:SetBaseStrength(original_hero:GetBaseStrength())
				spawnedUnit:SetBaseIntellect(original_hero:GetBaseIntellect())
				spawnedUnit:SetBaseAgility(original_hero:GetBaseAgility())
				spawnedUnit:AddNewModifier(npc, nil, "modifier_intelect", {duration = -1})
				if original_hero.medical_tractates then
					spawnedUnit.medical_tractates = original_hero.medical_tractates
					spawnedUnit:AddNewModifier(spawnedUnit, nil, "modifier_medical_tractate", { duration = -1})
				end
			end
		end
	end

	for i = 1, 7 do
		local f_name = "npc_dota_venomancer_plague_ward_" .. tostring(i)
		if unitname == f_name then
			local poison_ability_venom = spawnedUnit:GetOwner():FindAbilityByName("venomancer_poison_sting")
			if poison_ability_venom:GetLevel() > 0 then
				local poison_ability = spawnedUnit:FindAbilityByName("venomancer_poison_sting")
				if poison_ability then
					poison_ability:SetLevel(poison_ability_venom:GetLevel())
				end
			end
		end
	end

	if AngelArena:IsUnitBear(spawnedUnit) then
		spawnedUnit:AddNewModifier(npc, nil, "modifier_intelect", {duration = -1})
		local ability

		local bear_abilities =
		{
			["separation_of_souls_bear"] = 1,
			["lone_druid_spirit_bear_defender"] = 1,
		}

		for i = 0, spawnedUnit:GetAbilityCount() - 1 do
			ability = spawnedUnit:GetAbilityByIndex(i)

			if ability and bear_abilities[ability:GetName()] then
				ability:SetLevel(1)
			end
		end

		-- бафф суммонов от статов друида. Через summon_power_passive медведь его
		-- не получал: он "как герой" (ConsideredHero), проверка суммона его
		-- отсеивала и модификатор удалял сам себя. Кастер - герой, тогда
		-- хозяин берётся сразу. Владелец ставится кадром позже - ждём.
		local bear = spawnedUnit
		local tries = 0
		Timers:CreateTimer(FrameTime(), function()
			if not bear or bear:IsNull() or not bear:IsAlive() then return nil end

			local hero = SummonUtils and SummonUtils:GetOwnerHero(bear)

			if hero and not hero:IsNull() and hero ~= bear then
				local mod = bear:FindModifierByName("modifier_summon_power")
				if mod and mod:GetCaster() ~= hero then mod:Destroy() mod = nil end
				if not mod then bear:AddNewModifier(hero, nil, "modifier_summon_power", {}) end
				return nil
			end

			tries = tries + 1
			if tries >= 30 then return nil end
			return FrameTime()
		end)
	end

	if armor_table[unitname] ~= nil then -- see file creeps/armor_table_summon.lua for details
		-- npc_spawned приходит и на каждое возрождение суммона (медведь и т.п.):
		-- раньше каждый раз добавлялась ещё одна копия сплэша и модификатора
		-- false в таблице - суммон без модификатора скейла, только сплэш
		-- скейл суммонов от минуты выключен: суммоны теперь растут от статов
		-- хозяина (summon_power). Модификаторы не удалены, чтобы вернуть -
		-- поставить SUMMON_MINUTE_SCALING = true
		if SUMMON_MINUTE_SCALING and armor_table[unitname] and not spawnedUnit:HasModifier(armor_table[unitname]) then
			spawnedUnit:AddNewModifier(spawnedUnit, nil, armor_table[unitname], {})
		end

		local ability = spawnedUnit:FindAbilityByName("summon_cleave") or spawnedUnit:AddAbility("summon_cleave")

		if ability then ability:SetLevel(1) end
	end

	if spawnedUnit:IsRealHero() then --print(spawnedUnit:GetUnitName())
		Timers:CreateTimer(0.15, function()
			if not spawnedUnit or spawnedUnit:IsNull() or not IsValidEntity(spawnedUnit) or not spawnedUnit:IsRealHero() then return nil end
			if spawnedUnit:GetUnitName() == "npc_dota_hero_arc_warden" then
				if spawnedUnit:HasModifier("modifier_arc_warden_tempest_double") then

					if not spawnedUnit:HasModifier("modifier_kill") then
						UTIL_Remove(spawnedUnit)
					else

						local real_hero = spawnedUnit:GetPlayerOwner():GetAssignedHero()

						if not spawnedUnit:HasModifier("modifier_kill") then
							UTIL_Remove(spawnedUnit)
						end

						if real_hero then
							local att = real_hero:GetBaseStrength()
							spawnedUnit:SetBaseStrength(att)
							att = real_hero:GetBaseAgility()
							spawnedUnit:SetBaseAgility(att)
							att = real_hero:GetBaseIntellect()
							spawnedUnit:SetBaseIntellect(att)

							local owner_team = real_hero:GetTeamNumber()

							if owner_team then spawnedUnit:SetTeam(owner_team) end

							for i = 0, 5 do
								if spawnedUnit:GetItemInSlot(i) and forbidden_items_for_clones[spawnedUnit:GetItemInSlot(i):GetName()] then
									spawnedUnit:RemoveItem(spawnedUnit:GetItemInSlot(i))
								end
							end

							if real_hero.medical_tractates then
								spawnedUnit.medical_tractates = real_hero.medical_tractates
								spawnedUnit:RemoveModifierByName("modifier_medical_tractate")
								spawnedUnit:AddNewModifier(spawnedUnit, nil, "modifier_medical_tractate", { duration = -1 })
							end
						end
					end
				end
			end
			return nil
		end)
	end
end

local no_points_levels = {
	[17] = 1,
	[19] = 1,
	[21] = 1,
	[22] = 1,
	[23] = 1,
	[24] = 1,
	[25] = 1,
	[26] = 1,
	[27] = 1,
	[28] = 1,
	[29] = 1,
}
function AngelArena:OnLevelUp(keys)
	local hero = EntIndexToHScript(keys.hero_entindex)
    local level = keys.level
    if no_points_levels[level] and hero:GetUnitName() ~= "npc_dota_hero_invoker" or level >= 30 then
		hero:SetAbilityPoints(hero:GetAbilityPoints() + 1)
	end
end

function AngelArena:OnEntityKilled(event)
	local killedUnit = EntIndexToHScript(event.entindex_killed)
	local killedTeam = killedUnit:GetTeam()
	local hero = EntIndexToHScript(event.entindex_attacker)
	local heroTeam = hero:GetTeam()

	_G.Kills[heroTeam] = _G.Kills[heroTeam] or 0
	_G.Kills[DOTA_TEAM_BADGUYS] = _G.Kills[DOTA_TEAM_BADGUYS] or 0
	_G.Kills[DOTA_TEAM_GOODGUYS] = _G.Kills[DOTA_TEAM_GOODGUYS] or 0
	local GameMode = GameRules:GetGameModeEntity()

	if not killedUnit or not IsValidEntity(killedUnit) then return end

	EndGameStats:OnEntityKilled(killedUnit, hero)

	if killedUnit:GetUnitName() == 'npc_aa_creep_centaur_big'then
		BearSpawner:InitDeath()
	end

	if BossSpawner:HandleUnitKill( killedUnit, hero ) then
		return
	end

	if IsValidEntity(killedUnit) and not killedUnit:IsAlive() and killedUnit:IsRealHero() then
		local timeLeft = killedUnit:GetLevel() * 3.8 + 5
		timeLeft = timeLeft * RESPAWN_MODIFER - 12
		if timeLeft < 5.0 then
			timeLeft = 5.0
		end

		-- +3 секунды за каждого тиммейта, который не ливнул и сейчас в игре:
		-- в неполной команде умирать дешевле
		local team = killedUnit:GetTeamNumber()
		local ownerID = killedUnit:GetPlayerOwnerID()
		for pid = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
			if pid ~= ownerID and PlayerResource:IsValidPlayerID(pid)
				and PlayerResource:GetTeam(pid) == team
				and PlayerResource:GetConnectionState(pid) == DOTA_CONNECTION_STATE_CONNECTED then
				timeLeft = timeLeft + 3
			end
		end

		if killedUnit:IsReincarnating() == false then
			killedUnit:SetTimeUntilRespawn(timeLeft)
		end
	end

	if killedUnit:IsRealHero() and not killedUnit:IsReincarnating() and heroTeam and heroTeam ~= killedTeam and _G.Kills[heroTeam] then
		_G.Kills[heroTeam] = _G.Kills[heroTeam] + 1
	end

	if (killedUnit:HasAbility("skeleton_king_reincarnation") or killedUnit:HasAbility("angel_arena_reincarnation")) then
		local rein_ability = killedUnit:FindAbilityByName("skeleton_king_reincarnation") or killedUnit:FindAbilityByName("angel_arena_reincarnation")
		local ability_level = rein_ability:GetLevel()
		local current_cooldown = rein_ability:GetCooldownTimeRemaining()
		local cooldown = Util:GetReallyCooldown(killedUnit, rein_ability)

		if (current_cooldown ~= cooldown) then
			while (killedUnit:HasModifier("modifier_item_aegis")) do
				killedUnit:RemoveModifierByName("modifier_item_aegis")
			end
		end
	else
		while (killedUnit:HasModifier("modifier_item_aegis")) do
			killedUnit:RemoveModifierByName("modifier_item_aegis")
		end
	end

	if killedUnit:IsRealHero() and not killedUnit:IsReincarnating() then
		self:OnHeroDeath(killedUnit, hero)
	end

	local allowedTeams = {
		DOTA_TEAM_GOODGUYS,
		DOTA_TEAM_BADGUYS,
	}

	for _, teamNumber in pairs(allowedTeams) do
		if _G.Kills[teamNumber] >= KILL_LIMIT and not DuelController:IsLastDuelTeam(teamNumber) then
			DuelController:AddLastDuelTeam( teamNumber )
			Attentions:SendAttentionText("#aa_last_duel_coming", 10, 3)
			if KillFeed then KillFeed:LastDuel() end
		end
	end

	GameMode:SetCustomDireScore( _G.Kills[DOTA_TEAM_BADGUYS] )
	GameMode:SetCustomRadiantScore( _G.Kills[DOTA_TEAM_GOODGUYS] )
	Attentions:SetTeamKills( _G.Kills[DOTA_TEAM_GOODGUYS], _G.Kills[DOTA_TEAM_BADGUYS] )

	if hero and hero:GetPlayerOwnerID() ~= nil and killedUnit:IsCourier() then
		local _ = (AATagGold or function(_, f) f() end)("courier", function() PlayerResource:ModifyGold(hero:GetPlayerOwnerID(), GOLD_FOR_COUR, false, 0) end)
		AngelArena:ShowGoldPopup(hero:GetPlayerOwnerID(), GOLD_FOR_COUR)
		if KillFeed then KillFeed:Courier(hero:GetPlayerOwnerID(), GOLD_FOR_COUR) end
	end
end
function AngelArena:OnHeroDeath(dead_hero, killer)
	if not dead_hero or dead_hero:IsNull() or not IsValidEntity(dead_hero) then return end
	if not killer or killer:IsNull() or not IsValidEntity(killer) then return end

	ComebackSystem:OnKill( killer:GetPlayerOwnerID(), killer:GetTeamNumber(), dead_hero:GetPlayerOwnerID(), dead_hero:GetTeamNumber() )

	if dead_hero:HasInventory() and dead_hero.IsReincarnating and not dead_hero:IsReincarnating() then
		local item
		for i = 0, 8 do
			item = dead_hero:GetItemInSlot(i)

			if item and (item:GetName() == "item_unknown_amulet") then
					item:SetCurrentCharges(item:GetCurrentCharges() - (item:GetCurrentCharges() * 0.3) )
			end
		end
	end
end
-- Ключ способности для журнала урона и статистики: доп. урон колбэков идёт от
-- divine_intervention, вместо него пишем "<настоящий скилл или предмет>#bonus".
function AA_DamageKey(name)
	if name == "divine_intervention" and type(_G.AA_DMG_ORIGIN) == "string" and _G.AA_DMG_ORIGIN ~= ""
		and _G.AA_DMG_ORIGIN ~= "divine_intervention" then
		return _G.AA_DMG_ORIGIN .. "#bonus"
	end

	return name
end

function AngelArena:DamageFilter(event)
	local damage = event.damage
	local entindex_inflictor_const = event.entindex_inflictor_const
	local entindex_victim_const = event.entindex_victim_const
	local entindex_attacker_const = event.entindex_attacker_const
	local damagetype_const = event.damagetype_const
	local skill_name = ""
	local victim
	local attacker

	if (entindex_inflictor_const) then skill_name = EntIndexToHScript(entindex_inflictor_const):GetName() end
	if (entindex_victim_const) then victim = EntIndexToHScript(entindex_victim_const) end
	if (entindex_attacker_const) then attacker = EntIndexToHScript(entindex_attacker_const) end


	-----------------------------------------------------------------------------------------------------
	------------------------------ Костыль для ланаи ----------------------------------------------------
	-----------------------------------------------------------------------------------------------------
	-- victim обязательно проверять: раньше проверялся attacker, а разыменовывался
	-- victim, и урон без жертвы ронял весь фильтр
	if attacker and victim and victim:HasModifier("modifier_templar_assassin_refraction_absorb") then
		if skill_name ~= "item_helm_of_the_undying" and skill_name ~= "skeleton_king_reincarnation" then
			return
		end
	end

	-- Инвиз Трента (Nature's Guise) в ванили уроном не сбивается - у нас
	-- сбивается любым уроном от врага
	if attacker and victim and damage > 0 and victim:HasModifier("modifier_treant_natures_guise_invis")
		and attacker:GetTeamNumber() ~= victim:GetTeamNumber() then
		victim:RemoveModifierByName("modifier_treant_natures_guise_invis")
	end

	-----------------------------------------------------------------------------------------------------
	--------------------------------- Procent damage enable for some skills -----------------------------
	-----------------------------------------------------------------------------------------------------

	if attacker and skill_name and _G.skill_callback and _G.skill_callback[skill_name] then
		if victim and (victim:IsHero() or victim:IsCreep() or victim:IsAncient()) then

			-- Доп. урон колбэков наносится от имени divine_intervention. Пока колбэк работает,
			-- помним настоящий источник: журнал урона и статистика пишут его (AA_DamageKey).
			-- ApplyDamage синхронный, вложенный фильтр и запись урона идут внутри этого окна.
			local prevOrigin = _G.AA_DMG_ORIGIN

			_G.AA_DMG_ORIGIN = skill_name

			for callback_id, callback in pairs(_G.skill_callback[skill_name]) do
				local ability = attacker:FindAbilityByName(skill_name)

				if not ability then
					ability = attacker:FindItemInInventory(skill_name)
				end

				local divine_intervention = attacker:FindAbilityByName("divine_intervention")

				if attacker and (skill_name == "batrider_sticky_napalm") then
					_G.AA_DMG_ORIGIN = prevOrigin

					return
				end

				local callback_data = {
					caster = attacker,
					target = victim,
					skill_name = skill_name,
					ability = ability,
					damage = damage,
					damage_type = damagetype_const,
					inflictor = divine_intervention
				}

				local status, res = pcall(callback, callback_data)
				if victim ~= attacker then
					if status and res then
						ApplyDamage({
                            victim = victim,
                            attacker = attacker,
                            damage = res,
                            damage_type = damagetype_const,
                            ability = divine_intervention
						})
					end
				end
			end

			_G.AA_DMG_ORIGIN = prevOrigin
		end
	end

	-- урон по героям и боссам и втанченное для финального экрана
	EndGameStats:OnDamage(attacker, victim, event.damage)

	return true
end

-- Портал в центр: способность mid_teleport даётся герою на один каст.
function AngelArena:_StartPortalCast(hero)
	hero:Interrupt()
	hero:Stop()
	hero:AddAbility("mid_teleport")
	local ability = hero:FindAbilityByName("mid_teleport")
	ability:SetLevel(1)
	hero:CastAbilityNoTarget(ability, hero:GetPlayerOwnerID())
end

-- есть ли юнит среди тех, кому отдан приказ
function AngelArena:_OrderHasUnit(ord, unit)
	local index = unit:entindex()

	for _, entindex in pairs(ord.units or {}) do
		if entindex == index then return true end
	end

	return false
end

-- Клик по далёкому порталу - как в доте: герой бежит к нему и, добежав,
-- входит сам. Любой следующий приказ герою пробежку отменяет (см. фильтр).
local PORTAL_WALK_TIMEOUT = 30

-- Приказы, после которых герой к порталу уже не идёт: новое движение, атака,
-- каст в точку или цель, стоп. Мгновенное (палка, фазы, тоггл) героя с пути
-- не сбивает - если отменять пробежку и на нём, герой добегал до портала и
-- просто вставал.
local PORTAL_WALK_BREAKERS = {
	[DOTA_UNIT_ORDER_MOVE_TO_POSITION] = true,
	[DOTA_UNIT_ORDER_MOVE_TO_TARGET]   = true,
	[DOTA_UNIT_ORDER_ATTACK_MOVE]      = true,
	[DOTA_UNIT_ORDER_ATTACK_TARGET]    = true,
	[DOTA_UNIT_ORDER_CAST_POSITION]    = true,
	[DOTA_UNIT_ORDER_CAST_TARGET]      = true,
	[DOTA_UNIT_ORDER_CAST_TARGET_TREE] = true,
	[DOTA_UNIT_ORDER_HOLD_POSITION]    = true,
	[DOTA_UNIT_ORDER_STOP]             = true,
	[DOTA_UNIT_ORDER_PICKUP_ITEM]      = true,
	[DOTA_UNIT_ORDER_PICKUP_RUNE]      = true,
}

function AngelArena:_WalkToPortal(hero, portal, player)
	local walk = {}
	local started = GameRules:GetGameTime()

	hero._portalWalk = walk

	Timers:CreateTimer(0.1, function()
		if hero:IsNull() or hero._portalWalk ~= walk then return nil end

		if not hero:IsAlive() or portal:IsNull() or GameRules:GetGameTime() - started > PORTAL_WALK_TIMEOUT then
			hero._portalWalk = nil
			return nil
		end

		if ( hero:GetOrigin() - portal:GetOrigin() ):Length2D() > teleport_range then return 0.1 end

		hero._portalWalk = nil

		if hero:HasModifier("modifier_mid_teleport_cd") then
			if player and not player:IsNull() then
				CustomGameEventManager:Send_ServerToPlayer(player, "CreateIngameErrorMessage", {message = "#midteleport_cd"})
			end

			return nil
		end

		AngelArena:_StartPortalCast(hero)

		return nil
	end)
end

-- предметы на Lua с каналом, который не сбивается движением (как в доте)
local NO_MOVE_BREAK_CHANNEL = {
	item_meteor_hammer_aa   = true,
	item_meteor_hammer_aa_2 = true,
	item_meteor_hammer_aa_3 = true,
}

local CHANNEL_BREAK_ALLOWED_ORDERS = {
	[DOTA_UNIT_ORDER_STOP] = true,
	[DOTA_UNIT_ORDER_HOLD_POSITION] = true,
}

function AngelArena:_BlocksChannelBreak(ord)
	if CHANNEL_BREAK_ALLOWED_ORDERS[ord.order_type] then return false end
	if ord.queue == 1 or ord.queue == true then return false end
	if not ord.units then return false end

	for _, entindex in pairs(ord.units) do
		local u = EntIndexToHScript(entindex)

		if u and not u:IsNull() and u.IsChanneling and u:IsChanneling() then
			local ability = u:GetCurrentActiveAbility()

			if ability and not ability:IsNull() and NO_MOVE_BREAK_CHANNEL[ability:GetAbilityName()] then
				return true
			end
		end
	end

	return false
end

function AngelArena:ExecuteOrderFilterCustom( ord )

	local target = ord.entindex_target ~= 0 and EntIndexToHScript(ord.entindex_target) or nil
	local player = PlayerResource:GetPlayer(ord["issuer_player_id_const"])
	local player_id = ord.issuer_player_id_const
	local unit

	if ord.units and ord.units["0"] then
        unit = EntIndexToHScript(ord.units["0"])
    end

	-- Meteor Hammer (item_lua) сбивался любым приказом движения. Как в доте:
	-- канал прерывает только Stop / Hold, приказы с Shift встают в очередь.
	if AngelArena:_BlocksChannelBreak(ord) then return false end

	if not player then return true end

    local hero = player:GetAssignedHero()

    if not hero then return true end

	-- приказ, сбивающий героя с пути, отменяет пробежку к порталу
	-- (_WalkToPortal); если это снова клик по порталу, пробежка ниже начнётся
	-- заново. Приказы с Shift встают в очередь и путь не сбивают.
	local queued = ord.queue == 1 or ord.queue == true

	if hero._portalWalk and not queued and PORTAL_WALK_BREAKERS[ord.order_type] and AngelArena:_OrderHasUnit(ord, hero) then
		hero._portalWalk = nil
	end

		if ord.order_type == DOTA_UNIT_ORDER_ATTACK_TARGET or ord.order_type == DOTA_UNIT_ORDER_MOVE_TO_TARGET  then
			if target and not target:IsNull() and  target:IsBaseNPC() and target:GetUnitName() == "npc_teleport" and unit:IsRealHero() then
				if teleport_range >= ( hero:GetOrigin() - target:GetOrigin() ):Length2D() then
					if not hero:HasModifier("modifier_mid_teleport_cd") then
						AngelArena:_StartPortalCast(hero)
					else
						print('cd')
						CustomGameEventManager:Send_ServerToPlayer(player, "CreateIngameErrorMessage", {message = "#midteleport_cd"})
					end
				else
					-- Далеко - как в доте: герой бежит к порталу и, добежав, входит
					-- сам. Раньше тут был отказ "слишком далеко", и герой вставал.
					AngelArena:_WalkToPortal(hero, target, player)
					ord.order_type = DOTA_UNIT_ORDER_MOVE_TO_TARGET

					return true
				end
				return false
			end

			if ord.order_type == DOTA_UNIT_ORDER_CAST_TARGET  then
				if target:GetUnitName() == "npc_teleport" then
					print('error2')
					return false
				end
			end
		end

		if ord.order_type == DOTA_UNIT_ORDER_CAST_TARGET then
			local ability = EntIndexToHScript(ord.entindex_ability)
			local target = EntIndexToHScript(ord.entindex_target)
			local target_id = target:GetPlayerOwnerID()

			if PlayerResource:IsDisableHelpSetForPlayerID(target_id, player_id) then
				return UF_FAIL_DISABLE_HELP
			end

			if forbidden_ability_boss[ability:GetName()] and BossSpawner:IsBoss(target) then
				return UF_FAIL_DISABLE_HELP
			end

			if target:HasAbility("wisp_tether") and ability:GetName() == "wisp_tether" then return end

			if unit and target == unit and ability:GetName() == "rubick_spell_steal" then
				return UF_FAIL_DISABLE_HELP
			end
		end
	return true
end


function AngelArena:OnPlayerUsedAbility(event)
	local player = PlayerResource:GetPlayer(event.PlayerID)
	local ability_name = event.abilityname
	if not player or not ability_name or not IsValidEntity(player) then return end
	local hero = PlayerResource:GetSelectedHeroEntity(event.PlayerID)

	if not hero then return end

	if crash_abilities[ability_name] then
		player.crash_timer = 6.0
		Timers:CreateTimer(1.0, function()

			if player.crash_timer == nil or player.crash_timer <= 0 then
				player.crash_timer = nil;
				return nil;
			end
			player.crash_timer = player.crash_timer - 1

			return 1.0
		end)
	end
end

-- Не local: зовётся из OnGameRulesStateChange выше по файлу, где локальная
-- версия ещё не в области видимости (был вызов nil - и весь блок старта игры
-- падал с ошибкой, не доходя до запуска DuelController).
function GetActivePlayersPerTeam()
    local rad = 0
    local dire = 0
    local total = 0

    TeamHelper:ApplyForPlayers(nil, function(playerid)
        if IsAbadonedPlayerID(playerid) then return end
        if not PlayerResource:IsConnected(playerid) then return end

        local team = PlayerResource:GetTeam(playerid)
        if team == DOTA_TEAM_GOODGUYS then
            rad = rad + 1
            total = total + 1
        elseif team == DOTA_TEAM_BADGUYS then
            dire = dire + 1
            total = total + 1
        end
    end)

    return rad, dire, total
end

_G.inited = true