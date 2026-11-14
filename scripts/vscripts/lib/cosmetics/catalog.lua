-- Каталог премиум-косметики.
--
-- Только ванильные ассеты Dota 2 (VPK), пути без суффикса _c.
-- COSMETICS_CATALOG[slot] = список предметов:
--   id       - уникальный id (уходит в сеть и в бэкенд)
--   name_ru  - название в меню
--   rarity   - common / rare / mythical / legendary / immortal / arcana
--   particles - { {path, attach, cps?} }   attach - PATTACH_*
--               cps - контрольные точки { [номер] = число | Vector }; число = Vector(число, 0, 0)
--   model    - модель (только для петов, курьер)
--   flying   - пет летает (MODIFIER_STATE_FLYING), см. modifier_aa_cosmetic_pet.lua
--   target   - для радианса: партикл на враге под дебаффом радианса
--
-- Пути без суффикса _c. Список vanilla-ассетов: scratchpad vpk_files.txt.
--
-- Слоты, которые ведёт модуль социалки (wheel, emote_set, high_five, spray),
-- лежат в глобальном SOCIAL_CATALOG и подмешиваются в core.lua.

COSMETICS_CATALOG = {}
COSMETICS_CATALOG.wings = {}   -- крылья и нимбы за спиной (заполняет catalog_extra.lua)

-- порядок и названия вкладок меню; kind определяет, как эффект применяется
COSMETIC_SLOTS = {
	{ slot = "aura",           title = "Эмблемы",         kind = "particle" },
	{ slot = "wings",          title = "Крылья",          kind = "particle" },
	{ slot = "pet",            title = "Петы",            kind = "pet" },
	{ slot = "kill_effect",    title = "Эффекты убийства", kind = "kill" },
	{ slot = "tp_effect",      title = "Телепорт",        kind = "tp" },
	{ slot = "radiance_effect", title = "Радианс",        kind = "radiance" },
	-- 2026-11-12: эффекты предметов и событий (lib/cosmetics/events_fx.lua, items/*)
	{ slot = "blink_effect",   title = "Блинк",           kind = "event" },
	{ slot = "phase_effect",   title = "Фазы",            kind = "event" },
	{ slot = "mjollnir_effect", title = "Мьёльнир",       kind = "event" },
	{ slot = "hex_skin",       title = "Хекс",            kind = "event" },
	{ slot = "levelup_effect", title = "Новый уровень",   kind = "event" },
	{ slot = "fountain_effect", title = "Фонтан",         kind = "event" },
	{ slot = "kill_banner",    title = "Мультикиллы",     kind = "event" },
	{ slot = "duel_win",       title = "Победа в дуэли",  kind = "event" },
	-- { slot = "hero_skin",   title = "Скин героя",      kind = "event" },   -- выключен 2026-11-12, вернём позже
	{ slot = "projectile",     title = "Снаряд атаки",    kind = "event" },
	{ slot = "high_five",      title = "Хай-файвы",       kind = "social" },
	{ slot = "spray",          title = "Спреи",           kind = "social" },
	{ slot = "wheel",          title = "Колесо фраз",     kind = "social" },
	{ slot = "tip",            title = "Похвала",         kind = "social" },
}

local EMBLEM = PATTACH_ABSORIGIN_FOLLOW

local function P(path, attach, cps)
	return { path = path, attach = attach or EMBLEM, cps = cps }
end

-- ------------------------------------------------------------------ ауры (эмблемы под героем)
COSMETICS_CATALOG.aura = {
	{ id = "aura_ti9", name_ru = "Эмблема TI9", rarity = "rare",
		particles = { P("particles/econ/events/ti9/ti9_emblem_effect.vpcf") } },
	{ id = "aura_ti10", name_ru = "Эмблема TI10", rarity = "mythical",
		particles = { P("particles/econ/events/ti10/emblem/ti10_emblem_effect.vpcf") } },
	{ id = "aura_fall20", name_ru = "Эмблема Diretide 2020", rarity = "rare",
		particles = { P("particles/econ/events/diretide_2020/emblem/fall20_emblem_effect.vpcf") } },
	{ id = "aura_fall20_v1", name_ru = "Эмблема Diretide 2020 v1", rarity = "rare",
		particles = { P("particles/econ/events/diretide_2020/emblem/fall20_emblem_v1_effect.vpcf") } },
	{ id = "aura_fall20_v2", name_ru = "Эмблема Diretide 2020 v2", rarity = "mythical",
		particles = { P("particles/econ/events/diretide_2020/emblem/fall20_emblem_v2_effect.vpcf") } },
	{ id = "aura_fall20_v3", name_ru = "Эмблема Diretide 2020 v3", rarity = "legendary",
		particles = { P("particles/econ/events/diretide_2020/emblem/fall20_emblem_v3_effect.vpcf") } },
	{ id = "aura_fall21", name_ru = "Осенняя эмблема 2021", rarity = "legendary",
		particles = { P("particles/econ/events/fall_2021/fall_2021_emblem_game_effect.vpcf") } },
	{ id = "aura_summer21", name_ru = "Летняя эмблема 2021", rarity = "rare",
		particles = { P("particles/econ/events/summer_2021/summer_2021_emblem_effect.vpcf") } },
	{ id = "aura_agh21", name_ru = "Аура Аганима 2021", rarity = "legendary",
		particles = { P("particles/econ/events/fall_2021/agh_aura_fall_2021.vpcf") } },
	{ id = "aura_agh21_lvl2", name_ru = "Аура Аганима 2021 ур. 2", rarity = "immortal",
		particles = { P("particles/econ/events/fall_2021/agh_aura_fall_2021_lvl2.vpcf") } },
	{ id = "aura_nian", name_ru = "Щит Ниана", rarity = "common",
		particles = { P("particles/econ/events/newbloom_2015/nian_aegis_aura.vpcf") } },
}

-- ------------------------------------------------------------------ петы (курьеры)
-- Модель меняем на юните npc_dota_aa_cosmetic_pet. Партикл - ambient курьера, если он есть.
-- flying - пет летает: модель должна быть курьером, которого движок видит как летающего
-- (для этого есть *_flying.vmdl варианты в ассетах, например faceless_rex_flying).
local function Pet(id, name_ru, rarity, model, particle, flying)
	local item = { id = id, name_ru = name_ru, rarity = rarity, model = model, flying = flying == true, particles = {} }

	if particle then
		item.particles = { P(particle, PATTACH_ABSORIGIN_FOLLOW) }
	end

	return item
end

COSMETICS_CATALOG.pet = {
	Pet("pet_amaterasu", "Аматерасу", "legendary", "models/items/courier/amaterasu/amaterasu.vmdl",
		"particles/econ/courier/courier_amaterasu/courier_amaterasu_ambient.vpcf"),
	Pet("pet_bookwyrm", "Книжный змей", "rare", "models/items/courier/bookwyrm/bookwyrm.vmdl",
		"particles/econ/courier/courier_bookwyrm/courier_bookwyrm.vpcf"),
	Pet("pet_boris", "Борис Баумхауэр", "mythical", "models/items/courier/boris_baumhauer/boris_baumhauer.vmdl",
		"particles/econ/courier/courier_boris_baumhauer/courier_boris_baumhauer_ambient.vpcf"),
	Pet("pet_devourling", "Пожиратель", "common", "models/items/courier/devourling/devourling.vmdl",
		"particles/econ/courier/courier_devourling/courier_devourling_ambient.vpcf"),
	Pet("pet_rex", "Безликий Рекс", "rare", "models/items/courier/faceless_rex/faceless_rex.vmdl", nil),
	Pet("pet_rex_fly", "Безликий Рекс (полёт)", "rare", "models/items/courier/faceless_rex/faceless_rex_flying.vmdl", nil, true),
	Pet("pet_fall20", "Курьер Diretide 2020", "rare", "models/items/courier/courier_fall20/courier_fall20.vmdl",
		"particles/econ/courier/courier_fall20/courier_fall20_ambient.vpcf"),
	Pet("pet_ti9", "Курьер TI9", "legendary", "models/items/courier/courier_ti9/courier_ti9.vmdl", nil),
	Pet("pet_dragon_gold", "Дракон 2024 (золото)", "immortal", "models/items/courier/dragon_courier_2024_gold/dragon_courier_2024_gold.vmdl", nil),
	Pet("pet_krobeling", "Кроблинг", "common", "models/items/courier/krobeling/krobeling.vmdl", nil),
	Pet("pet_tinkbot", "Тинкбот", "rare", "models/items/courier/tinkbot/tinkbot.vmdl", nil),
	Pet("pet_snail", "Улитка", "common", "models/items/courier/snail/courier_snail.vmdl", nil),
	Pet("pet_baekho", "Бэкхо", "rare", "models/items/courier/baekho/baekho.vmdl",
		"particles/econ/courier/courier_baekho/courier_baekho_ambient.vpcf"),
}


-- ------------------------------------------------------------------ эффекты убийства
-- Бурст (effects.lua PlayKill): каждый фейерверк запускается 6 раз вокруг точки гибели,
-- плюс вспышка COSMETIC_KILL_FLASH в центре. Всё гаснет через 4 с после старта.
local WORLD = PATTACH_WORLDORIGIN

COSMETIC_KILL_FLASH = "particles/base_attacks/generic_projectile_explosion_flash.vpcf"

COSMETICS_CATALOG.kill_effect = {
	{ id = "kill_frostivus", name_ru = "Фейерверк Frostivus", rarity = "rare",
		particles = { P("particles/econ/events/frostivus/frostivus_fireworks.vpcf", WORLD) } },
	{ id = "kill_frostivus_snow", name_ru = "Снежный взрыв", rarity = "common",
		particles = { P("particles/econ/events/frostivus/frostivus_fireworks_explosion_snow.vpcf", WORLD) } },
	{ id = "kill_frostivus_sparkles", name_ru = "Искры Frostivus", rarity = "common",
		particles = { P("particles/econ/events/frostivus/frostivus_fireworks_explosion_sparkles.vpcf", WORLD) } },
	{ id = "kill_darkcarnival", name_ru = "Фейерверк Тёмного карнавала", rarity = "rare",
		particles = { P("particles/econ/events/dark_carnival/dark_carnival_fireworks.vpcf", WORLD) } },
	{ id = "kill_darkcarnival_smoke", name_ru = "Дым карнавала", rarity = "common",
		particles = { P("particles/econ/events/dark_carnival/dark_carnival_fireworks_explosion_smoke.vpcf", WORLD) } },
	{ id = "kill_consolation", name_ru = "Фейерверк утешения", rarity = "common",
		particles = { P("particles/econ/events/consolation/consolation_fireworks_1.vpcf", WORLD) } },
	{ id = "kill_cny_boom", name_ru = "Салют", rarity = "rare",
		particles = { P("particles/econ/events/consolation/cny_fireworks_boom_a_consolation.vpcf", WORLD) } },
	{ id = "kill_cny_confetti", name_ru = "Конфетти", rarity = "common",
		particles = { P("particles/econ/events/consolation/cny_fireworks_confetti_consolation.vpcf", WORLD) } },
}

-- ------------------------------------------------------------------ телепорт
-- start проигрывается в точке каста, end - в точке прибытия (TP-watch в effects.lua).
local function Tp(id, name_ru, rarity, start_path, end_path)
	return {
		id = id, name_ru = name_ru, rarity = rarity,
		particles = { P(start_path, WORLD) },
		end_particles = { P(end_path, WORLD) },
	}
end

COSMETICS_CATALOG.tp_effect = {
	Tp("tp_fall21_ground", "Телепорт: Осень 2021 (земля)", "rare",
		"particles/econ/events/fall_2021/teleport_start_fall_2021_ground.vpcf",
		"particles/econ/events/fall_2021/teleport_end_fall_2021_ground.vpcf"),
	Tp("tp_fall21_core", "Телепорт: Осень 2021 (ядро)", "rare",
		"particles/econ/events/fall_2021/teleport_start_fall_2021_core.vpcf",
		"particles/econ/events/fall_2021/teleport_end_fall_2021_core.vpcf"),
	Tp("tp_fall21_magic", "Телепорт: Осень 2021 (магия)", "legendary",
		"particles/econ/events/fall_2021/teleport_start_fall_2021_magic.vpcf",
		"particles/econ/events/fall_2021/teleport_end_fall_2021_magic.vpcf"),
	Tp("tp_fall21_lvl2", "Телепорт: Осень 2021 ур. 2", "mythical",
		"particles/econ/events/fall_2021/teleport_start_fall_2021_lvl2.vpcf",
		"particles/econ/events/fall_2021/teleport_end_fall_2021_lvl2.vpcf"),
	Tp("tp_fallmjr15", "Телепорт: Major 2015", "rare",
		"particles/econ/events/fall_major_2015/teleport_start_fallmjr_2015.vpcf",
		"particles/econ/events/fall_major_2015/teleport_end_fallmjr_2015.vpcf"),
	Tp("tp_fallmjr15_dust", "Телепорт: Major 2015 (пыль)", "common",
		"particles/econ/events/fall_major_2015/teleport_start_fallmjr_2015_dust.vpcf",
		"particles/econ/events/fall_major_2015/teleport_end_fallmjr_2015_dust.vpcf"),
	Tp("tp_ti9", "Телепорт: TI9", "legendary",
		"particles/econ/events/ti9/teleport_start_ti9.vpcf",
		"particles/econ/events/ti9/teleport_end_ti9.vpcf"),
	Tp("tp_ti9_lvl2", "Телепорт: TI9 ур. 2", "mythical",
		"particles/econ/events/ti9/teleport_start_ti9_lvl2.vpcf",
		"particles/econ/events/ti9/teleport_end_ti9_lvl2.vpcf"),
}

-- ------------------------------------------------------------------ радианс
-- Owner-партикл накладывается на героя, пока у него есть предмет radiance (см. effects.lua).
-- target - партикл на каждом враге под дебаффом радианса этого владельца (TickRadiance).
local RAD_TARGET_FALL22 = "particles/econ/events/fall_2022/radiance_target_fall2022.vpcf"

local function Rad(id, name_ru, rarity, path, target)
	return { id = id, name_ru = name_ru, rarity = rarity,
		particles = { P(path, PATTACH_ABSORIGIN_FOLLOW) },
		target = target or RAD_TARGET_FALL22 }
end

COSMETICS_CATALOG.radiance_effect = {
	Rad("rad_fall21", "Радианс: Осень 2021", "rare", "particles/econ/events/fall_2021/radiance_owner_fall_2021.vpcf"),
	Rad("rad_fall21_dark", "Радианс: Осень 2021 (тьма)", "rare", "particles/econ/events/fall_2021/radiance_owner_fall_2021_dark.vpcf"),
	Rad("rad_fall21_magic", "Радианс: Осень 2021 (магия)", "rare", "particles/econ/events/fall_2021/radiance_owner_fall_2021_magic.vpcf"),
	Rad("rad_fall22", "Радианс: Осень 2022", "mythical", "particles/econ/events/fall_2022/radiance/radiance_owner_fall2022.vpcf"),
	Rad("rad_fall22_ash", "Радианс: Осень 2022 (пепел)", "mythical", "particles/econ/events/fall_2022/radiance/radiance_owner_ash_close_fall2022.vpcf",
		"particles/econ/events/fall_2022/radiance/radiance_target_ash_fall2022.vpcf"),
	Rad("rad_fall22_fire", "Радианс: Осень 2022 (огонь)", "legendary", "particles/econ/events/fall_2022/radiance/radiance_owner_fire_fall2022.vpcf"),
	Rad("rad_fall22_black", "Радианс: Осень 2022 (чёрный)", "legendary", "particles/econ/events/fall_2022/radiance/radiance_owner_black_fall2022.vpcf"),
	Rad("rad_reward25", "Радианс: Осенняя линейка 2025", "immortal", "particles/econ/events/seasonal_reward_line_fall_2025/radiance_owner_fallrewardline_2025.vpcf",
		"particles/econ/events/seasonal_reward_line_fall_2025/radiance_target_fallrewardline_2025.vpcf"),
}

-- ------------------------------------------------------------------ предметы по id

-- Поиск предмета в каталоге слота (и в социальном каталоге, если модуль загружен)
function CosmeticsFindItem(slot, id)
	if slot == nil or id == nil or id == "" then return nil end

	for _, list in ipairs({ COSMETICS_CATALOG[slot] or {}, (SOCIAL_CATALOG and SOCIAL_CATALOG[slot]) or {} }) do
		for _, item in ipairs(list) do
			if item.id == id then return item end
		end
	end

	return nil
end

-- Прекеш не здесь: см. lib/cosmetics/precache.lua (по запросу, по предметам)

return COSMETICS_CATALOG
