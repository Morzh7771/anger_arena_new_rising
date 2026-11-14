if RepickMenu then return end 

RepickMenu = class({})

require('lib/utils')
require('lib/hero_change')
require('lib/kv_preloaded_data')
require('lib/boss/boss_spawner')
require('lib/duel/duel_controller')

-- I hate this hardcode, but we cannon access that stats WITHOUT unit and WITHOUT GameMode entity
local HP_PER_STR 		= 20
local HP_REGEN_PER_STR  = 0.09
local MP_PER_INT 		= 12
local MP_REGEN_PER_INT  = 0.05
local ARMOR_PER_AGI     = 0.16

local DUEL_CANT_PICK_PERIOD = 30 -- держать синхронно с scripts/custom_game/repick_menu.js

local BOSS_FOR_REPICK = "boss_mid_bott"

-- hero_data доходит до Ability25: врождённые и аганим/шард живут в слотах
-- заметно дальше шестого.
local MAX_ABILITY_SLOT = 25

-- Таланты (special_bonus_*) в ряд иконок не идут - для них отдельный значок с
-- тултипом дерева. Пустые слоты и заглушки тоже отбрасываем.
function RepickMenu:_IsRealAbility(name)
	if name == nil or #name == 0 then return false end
	if name == "generic_hidden" then return false end
	if string.find(name, "special_bonus", 1, true) then return false end
	if string.find(name, "_tallent", 1, true) then return false end
	if string.find(name, "_talent", 1, true) then return false end

	return true
end


-- Способности от фасетов и служебные подспособности помечены HIDDEN: дота их в
-- выборе героя не рисует. У Медузы так спрятан medusa_venomed_volley.
function IsHiddenAbility(kv)
	if type(kv) ~= "table" then return false end

	local behavior = tostring(kv["AbilityBehavior"] or "")

	return string.find(behavior, "HIDDEN", 1, true) ~= nil
end


-- Улучшение от аганима или шарда в KV помечают четырьмя разными способами, и в
-- этом аддоне встречаются все, кроме первого:
--
--   "AbilityHasScepterUpgrade" "1"   - ванильный ключ, тут не используется
--   "HasScepterUpgrade"        "1"   - так помечено у нас (178 мест)
--   "RequiresScepter"          "1"   - внутри блока AbilityValues, у значения,
--                                      которое работает только с аганимом
--   "special_bonus_scepter"    "+5"  - псевдоталант там же
--
-- kind - "Scepter" или "Shard".
function HasUpgrade(kv, kind)
	if type(kv) ~= "table" then return false end

	if tonumber(kv["AbilityHas" .. kind .. "Upgrade"]) == 1 then return true end
	if tonumber(kv["Has" .. kind .. "Upgrade"]) == 1 then return true end

	local requires = "Requires" .. kind
	local bonus = "special_bonus_" .. string.lower(kind)
	local values = kv["AbilityValues"]

	if type(values) == "table" then
		for _, block in pairs(values) do
			if type(block) == "table" then
				if tonumber(block[requires]) == 1 then return true end
				if block[bonus] ~= nil then return true end
			end
		end
	end

	return false
end
-- KV хранит дробные числа во float: "0.8" приходит сюда как 0.800000011920929,
-- и tostring печатает "0.80000001192093" - так в дереве талантов вылезло
-- "через 0.80000001192093 сек.". Округляем до 4 знаков и срезаем нули в хвосте.
local function CleanNumber(word)
	local n = tonumber(word)

	if n == nil then return word end

	local text = string.format("%.4f", n)

	text = text:gsub("0+$", "")
	text = text:gsub("%.$", "")

	return text
end

-- Дота показывает значения по уровням через слэш: "60/70/80". Из KV они
-- приходят строкой "60 70 80". Все числа, которые меню вставляет в текст,
-- проходят здесь - и только здесь, чтобы float больше нигде не протёк.
local function FormatAbilityValue(text)
	local parts = {}

	-- знак ("+", "-", "=") в описании уже стоит своим текстом, из числа его
	-- убираем; уровни дота пишет через слэш
	for word in tostring(text):gmatch("%S+") do
		table.insert(parts, CleanNumber((word:gsub("^[%+%-=]", ""))))
	end

	return table.concat(parts, "/")
end

-- Числа талантов лежат не в самом таланте (у special_bonus_* в KV пусто), а в
-- AbilityValues той способности, которую талант улучшает:
--
--     "duration"
--     {
--         "value"                                              "1.5 1.7 1.9"
--         "special_bonus_unique_juggernaut_omnislash_duration" "+0.7"
--     }
--
-- Перевод подставляет число через {s:value} или {s:<имя_ключа>}, поэтому отдаём
-- клиенту оба имени. Знак ("+"/"-") уже стоит в самой строке перевода - из
-- значения его убираем, иначе выйдет "+-3".
local function CollectLinkedTalentValues(ability_data, ability_names, out)
	-- ipairs, а не pairs: один и тот же талант бывает прописан в двух
	-- способностях, и порядок обхода должен быть предсказуемым.
	for _, ability_name in ipairs(ability_names) do
		local kv = ability_data[ability_name]
		local values = kv and kv["AbilityValues"]

		if type(values) == "table" then
			for value_name, block in pairs(values) do
				if type(block) == "table" then
					for key, bonus in pairs(block) do
						if type(key) == "string" and type(bonus) ~= "table" and string.find(key, "special_bonus", 1, true) then
							-- знак ("+", "-", "=") уже стоит в строке перевода, а
							-- многоуровневые бонусы дота пишет через слэш
							local text = FormatAbilityValue(bonus)

							out[key] = out[key] or {}
							if out[key]["value"] == nil then out[key]["value"] = text end
							if out[key]["bonus_value"] == nil then out[key]["bonus_value"] = text end
							out[key]["bonus_" .. value_name] = text
							out[key][value_name] = text
						end
					end
				end
			end
		end
	end
end

-- Плоский список значений способности: и новый формат AbilityValues, и старый
-- AbilitySpecial. Нужен для талантов вроде special_bonus_base_aa_* (число лежит
-- у них самих) и для описаний аганима/шарда с %подстановками%.
-- Плоский список значений из KV способности: и новый формат AbilityValues, и
-- старый AbilitySpecial.
local function CollectValuesFromKV(kv)
	local vals = {}

	if type(kv) ~= "table" then return vals end

	local values = kv["AbilityValues"]

	if type(values) == "table" then
		for key, entry in pairs(values) do
			local text = entry

			if type(entry) == "table" then
				text = entry["value"]

				-- У значений, которые даёт аганим или шард, база нулевая, а само
				-- число лежит рядом:
				--     "cooldown_reduction_on_hero_hit"
				--     {
				--         "value"               "0"
				--         "special_bonus_shard" "+2.0"
				--     }
				-- В описании улучшения показывать надо именно бонус, иначе в
				-- тексте выходит "уменьшается на 0 сек.".
				local bonus = entry["special_bonus_shard"] or entry["special_bonus_scepter"]

				if bonus ~= nil and type(bonus) ~= "table" then
					local base = tonumber(text)

					if text == nil or base == nil or base == 0 then text = bonus end
				end
			end

			if text ~= nil and type(text) ~= "table" then
				vals[key] = FormatAbilityValue(text)

				-- ванильные таланты пишут переменную с приставкой: {s:bonus_duration}
				vals["bonus_" .. key] = vals[key]
			end
		end
	end

	local special = kv["AbilitySpecial"]

	if type(special) == "table" then
		for _, block in pairs(special) do
			if type(block) == "table" then
				for key, entry in pairs(block) do
					if key ~= "var_type" and key ~= "LinkedSpecialBonus" and type(entry) ~= "table" then
						vals[key] = FormatAbilityValue(entry)
					end
				end
			end
		end
	end

	for _, key in pairs({ "AbilityCooldown", "AbilityManaCost", "AbilityCastRange", "AbilityDamage" }) do
		if vals[key] == nil and kv[key] ~= nil and type(kv[key]) ~= "table" then
			vals[key] = FormatAbilityValue(kv[key])
		end
	end

	return vals
end

-- Только из PreloadCache. GetAbilityKeyValuesByName тут звать нельзя: каждый
-- вызов регистрирует имена ключей в общей таблице строк KeyValues, а она на
-- весь аддон всего 128 КБ. На 127 героях это тысячи вызовов, и игра падает с
-- "CKeyValuesSystem::m_Strings ran out of reserved memory" на старте.
local function CollectAbilityValues(ability_data, ability_name)
	return CollectValuesFromKV(ability_data[ability_name])
end

-- Значение таланта ищем в трёх местах, по убыванию надёжности:
--
--   1. движковый KV - туда попадают и ванильные таланты доты; у кастомных
--      героев вроде Сатаны половина талантов ванильные (special_bonus_cleave_*,
--      special_bonus_strength_*), и в наших файлах их просто нет;
--   2. наш npc_abilities_custom.txt - для талантов аддона;
--   3. хвост имени: у ванильных generic-талантов число прямо в названии
--      (special_bonus_strength_10 - это +10 к силе).

-- Восемь талантов, у которых числа нет ни в наших KV, ни в конце имени. Держим
-- их здесь, а не отдельным KV-файлом: таблица строк KeyValues в доте всего
-- 128 КБ на весь аддон, и лишний #base её переполняет
-- ("CKeyValuesSystem::m_Strings ran out of reserved memory").
--
-- Имя ключа должно совпадать с переменной из перевода: в строке стоит {s:имя}.
-- Приставку bonus_ дописывать не нужно, сервер добавляет алиас сам.
local MANUAL_TALENT_VALUES = {
	-- наш талант: "+{s:pct}% ко всем атрибутам"
	special_bonus_base_aa_all_20pct = { pct = "20" },

	-- ванильные: числа из последнего патча доты, правь если менял баланс
	special_bonus_unique_enigma = { value = "1" },
	special_bonus_unique_rubick_fade_bolt_spell_reduction = { value = "8" },
	special_bonus_unique_techies_tazer_duration = { value = "1" },
	special_bonus_unique_tinker = { value = "90" },
	special_bonus_unique_tinker_rearm_channel_time = { value = "0.5", AbilityChannelTime = "0.5" },
	special_bonus_unique_witch_doctor_damage_pct = { value = "20" },
	special_bonus_unique_witch_doctor_ticks = { value = "1" },
}

local function CollectOwnTalentValues(ability_data, talent_names, out)
	for _, talent_name in pairs(talent_names) do
		if out[talent_name] == nil then
			-- тоже только PreloadCache, без движкового KV: см. комментарий выше
			local vals = CollectValuesFromKV(ability_data[talent_name])

			if vals["value"] == nil then
				local tail = string.match(talent_name, "_(%d+)$")

				if tail then
					vals["value"] = tail
					vals["bonus_value"] = tail
				end
			end

			-- последний рубеж: значения, вписанные руками выше
			local manual = MANUAL_TALENT_VALUES[talent_name]

			if manual ~= nil then
				for key, value in pairs(manual) do
					if vals[key] == nil then vals[key] = value end
					if vals["bonus_" .. key] == nil then vals["bonus_" .. key] = value end
				end
			end

			if next(vals) ~= nil then out[talent_name] = vals end
		end
	end
end

local attribute_table = {
	["DOTA_ATTRIBUTE_STRENGTH"] = DOTA_ATTRIBUTE_STRENGTH,
	["DOTA_ATTRIBUTE_AGILITY"] = DOTA_ATTRIBUTE_AGILITY,
	["DOTA_ATTRIBUTE_INTELLECT"] = DOTA_ATTRIBUTE_INTELLECT,
	["DOTA_ATTRIBUTE_ALL"] = DOTA_ATTRIBUTE_ALL,
}


-- Разбор способностей одного героя.
--
-- Раньше это крутилось для всех 127 героев сразу в RepickMenu:init(), то есть в
-- момент старта игры. На таком объёме переполнялась общая таблица строк
-- KeyValues (128 КБ на аддон) и игра падала на 00:00 с
-- "CKeyValuesSystem::m_Strings ran out of reserved memory".
--
-- Теперь считаем строго по запросу клиента - когда игрок выбрал героя в меню, и
-- только для него. Результат кэшируем: второй раз тот же герой не считается.
function RepickMenu:BuildHeroInfo(hero_name)
	if self.hero_cache == nil then self.hero_cache = {} end
	if self.hero_cache[hero_name] then return self.hero_cache[hero_name] end

	local hero_info = PreloadCache:GetHeroData()[hero_name]

	if hero_info == nil then return nil end

	local ability_data = PreloadCache:GetAbilityData()

	local abilities = {}
	local innate = {}
	local scepter = {}
	local shard = {}
	local talents = {}

	for i = 1, MAX_ABILITY_SLOT do
		local ability_name = hero_info["Ability" .. tostring(i)]

		if ability_name ~= nil and #ability_name ~= 0 and ability_name ~= "generic_hidden" then
			if not RepickMenu:_IsRealAbility(ability_name) then
				-- таланты показываем отдельным значком с подсказкой
				table.insert(talents, ability_name)
			else
				-- сначала наши файлы: движковый KV зовём только если способности
				-- у нас нет вовсе, иначе вызовы переполняют таблицу строк
				local kv = ability_data[ability_name] or GetAbilityKeyValuesByName(ability_name)

				if kv == nil then
					table.insert(abilities, ability_name)
				elseif tonumber(kv["Innate"]) == 1 then
					table.insert(innate, ability_name)
				elseif tonumber(kv["IsGrantedByScepter"]) == 1 then
					-- аганим даёт НОВУЮ способность
					table.insert(scepter, { name = ability_name, new = 1 })
				elseif tonumber(kv["IsGrantedByShard"]) == 1 then
					table.insert(shard, { name = ability_name, new = 1 })
				elseif IsHiddenAbility(kv) then
					-- Способности от фасетов и прочие служебные помечены HIDDEN
					-- (у Медузы это medusa_venomed_volley). Дота их в выборе
					-- героя не показывает - и мы не показываем.
				else
					table.insert(abilities, ability_name)

					-- Аганим и шард могут не давать новую способность, а
					-- УЛУЧШАТЬ существующую. В KV аддона это помечено ключами
					-- HasScepterUpgrade / HasShardUpgrade, а не
					-- AbilityHasScepterUpgrade - последних тут нет ни у одного
					-- героя, поэтому улучшения и не находились.
					if HasUpgrade(kv, "Scepter") then
						table.insert(scepter, { name = ability_name, new = 0 })
					end

					if HasUpgrade(kv, "Shard") then
						table.insert(shard, { name = ability_name, new = 0 })
					end
				end
			end
		end
	end

	local talent_values = {}
	local linked_sources = {}

	for _, name in ipairs(abilities) do table.insert(linked_sources, name) end
	for _, name in ipairs(innate) do table.insert(linked_sources, name) end
	for _, entry in ipairs(scepter) do table.insert(linked_sources, entry.name) end
	for _, entry in ipairs(shard) do table.insert(linked_sources, entry.name) end

	CollectLinkedTalentValues(ability_data, linked_sources, talent_values)
	CollectOwnTalentValues(ability_data, talents, talent_values)

	local upgrade_values = {}

	for _, entry in ipairs(scepter) do
		local vals = CollectAbilityValues(ability_data, entry.name)

		if next(vals) ~= nil then upgrade_values[entry.name] = vals end
	end

	for _, entry in ipairs(shard) do
		local vals = CollectAbilityValues(ability_data, entry.name)

		if next(vals) ~= nil then upgrade_values[entry.name] = vals end
	end

	for _, name in ipairs(innate) do
		local vals = CollectAbilityValues(ability_data, name)

		if next(vals) ~= nil then upgrade_values[name] = vals end
	end

	self.hero_cache[hero_name] = {
		hero_name = hero_name,
		abilities = abilities,
		innate = innate,
		scepter = scepter,
		shard = shard,
		talents = talents,
		values = {
			talents = talent_values,
			upgrades = upgrade_values,
		},
	}

	return self.hero_cache[hero_name]
end

-- Клиент просит данные по одному герою - тому, на который навёлся в меню.
function RepickMenu:_retriveHeroInfo(data)
	local player_id = data['PlayerID']
	local hero_name = data['hero_name']

	if not player_id or not hero_name then return end

	local player = PlayerResource:GetPlayer(player_id)

	if not player then return end

	local info = RepickMenu:BuildHeroInfo(hero_name)

	if info == nil then return end

	CustomGameEventManager:Send_ServerToPlayer(player, "aa_repick_menu_set_hero_info", {
		hero_name = info.hero_name,
		abilities = info.abilities,
		innate = info.innate,
		scepter = info.scepter,
		shard = info.shard,
		talents = info.talents,
		values = info.values,
	})
end

function RepickMenu:init()
	if self.gods_data then return end

	local hero_data = PreloadCache:GetHeroData()
	local ability_data = PreloadCache:GetAbilityData()
	print("RepickMenu:init")

	DeepPrintTable(self.gods_data)
	print('dasdsadasdasdasdasdd')
	
	self.gods_data = {}
	local banned = GameRules:GetBannedHeroes()
	for int,_ in pairs(banned) do
		--print('roll')
		if RollPercentage(20) then
			--print('unbanned')
			--Attentions:SendChatMessage(banned[int].." #un_banned")
			table.remove(banned,int)
		end
		--DeepPrintTable(banned)
	end

	-- ВНЕ цикла: раньше herolist грузился заново на каждого героя, 127 раз за
	-- старт. Каждый LoadKeyValues заново регистрирует имена ключей в общей
	-- таблице строк KeyValues (128 КБ на весь аддон), и она переполнялась -
	-- игра падала на 00:00 с CKeyValuesSystem::m_Strings ran out of memory.
	local togledHero = LoadKeyValues("scripts/npc/herolist.txt")

	for hero_name, hero_info in pairs(hero_data) do
		local data = {}

		local str = hero_info['AttributeBaseStrength'] or 0
		local agi = hero_info['AttributeBaseAgility'] or 0
		local int = hero_info['AttributeBaseIntelligence'] or 0

		local primary_attribute = attribute_table[ hero_info['AttributePrimary'] ]

		local main_att = 0

		if primary_attribute == DOTA_ATTRIBUTE_STRENGTH then
			main_att = str
		elseif primary_attribute == DOTA_ATTRIBUTE_AGILITY then
			main_att = agi
		elseif primary_attribute == DOTA_ATTRIBUTE_INTELLECT then
			main_att = int
		end

		-- Способности и цифры тут больше НЕ считаются: на 127 героях это
		-- переполняло таблицу строк KeyValues и роняло игру на старте.
		-- Клиент запросит их отдельно, по одному герою, когда игрок его
		-- выберет - см. RepickMenu:BuildHeroInfo.

		data['base_att'] 	= primary_attribute

		data['str'] 	 	= str
		data['agi'] 	 	= agi
		data['int'] 	 	= int

		data['str_gain'] 	= hero_info['AttributeStrengthGain'] or 0
		data['agi_gain'] 	= hero_info['AttributeAgilityGain'] or 0
		data['int_gain'] 	= hero_info['AttributeIntelligenceGain'] or 0

		data['bat'] 		= hero_info['AttackRate'] or 0
		data['movespeed'] 	= hero_info['MovementSpeed'] or 0

		-- для карточки героя в меню: дальность атаки и подпись "ближний/дальний бой"
		data['attack_range'] = hero_info['AttackRange'] or 0
		data['attack_type'] 	= hero_info['AttackCapabilities'] or ""

		data['dmg_min'] 	= (hero_info['AttackDamageMin'] or 0) + main_att
		data['dmg_max'] 	= (hero_info['AttackDamageMax'] or 0) + main_att

		data['hp'] 			= (hero_info['StatusHealth'] or 100) + str * HP_PER_STR
		data['mp'] 			= (hero_info['StatusMana']   or 0  ) + int * MP_PER_INT

		data['hp_reg'] 		= (hero_info['StatusHealthRegen'] or 0) + str * HP_REGEN_PER_STR
		data['mp_reg'] 		= (hero_info['StatusManaRegen']   or 0) + int * MP_REGEN_PER_INT

		data['armor'] 		= (hero_info['ArmorPhysical'] or 0) + agi * ARMOR_PER_AGI
		data['item_name']	= hero_info['GodRepickItem'] or "item_invalid"

		data['id'] = DOTAGameManager:GetHeroIDByName(hero_name)
		
		self.isPicked = 0
		for i,heroOnMap in pairs(HeroList:GetAllHeroes()) do
			if heroOnMap:GetUnitName() == hero_name then
				self.isPicked = 1
				--print(self.isPicked)
			end
		end
		data['picked'] = self.isPicked
		--print(data['picked'])
		self.isBan = false
		for _,ban in pairs(banned) do
			if "npc_dota_hero_"..ban == hero_name then
				self.isBan = true
			end
		end
		-- Забаненных больше не выбрасываем из списка: клиент показывает их с
		-- крестиком, как в доте, а не прячет. Иначе список молча менялся от
		-- игры к игре и было непонятно, куда делся герой.
		data['banned'] = self.isBan and 1 or 0

		for name,toggleState in pairs(togledHero) do
			if name == hero_name then
				if toggleState ~= 0 then
					self.gods_data[hero_name] = data
				end
			end
		end
	end
	
	
	CustomGameEventManager:RegisterListener("aa_repick_menu_retrive_data", Dynamic_Wrap(self, '_retriveHeroData'))
	CustomGameEventManager:RegisterListener("aa_repick_menu_retrive_hero", Dynamic_Wrap(self, "_retriveHeroInfo"))
	CustomGameEventManager:RegisterListener("aa_repick_menu_start_repick", Dynamic_Wrap(self, '_repickHero'))
	CustomGameEventManager:Send_ServerToAllClients("aa_repick_menu_set_data", self.gods_data )
	
end

-- Дуэль невозможна, если одна из команд пуста: соло-лобби или все игроки
-- собрались на одной стороне. Таймер дуэли при этом всё равно тикает по кругу,
-- поэтому проверку "скоро дуэль" в таких играх надо просто не применять -
-- иначе репик заблокирован большую часть времени без всякой причины.
local function IsDuelPossible()
	local radiant = 0
	local dire = 0

	for _, hero in pairs(HeroList:GetAllHeroes()) do
		if hero:IsTempestDouble() then
			-- клоны и солдаты Wukong's Command - не игроки
		elseif hero:GetTeamNumber() == DOTA_TEAM_GOODGUYS then
			radiant = radiant + 1
		elseif hero:GetTeamNumber() == DOTA_TEAM_BADGUYS then
			dire = dire + 1
		end
	end

	return radiant > 0 and dire > 0
end

-- Репик запрещён, если: босса ещё ни разу не убили за игру, он сейчас жив,
-- или идёт дуэль / до неё меньше DUEL_CANT_PICK_PERIOD. Возвращает токен
-- причины для красной строки ошибки, как у доты "нет маны"; nil - можно.
function RepickMenu:GetBlockReason()
	if BossSpawner:GetDeathCount(BOSS_FOR_REPICK) == 0 then
		return "#aa_repick_locked_boss_never"
	end

	if BossSpawner:IsBossAlive(BOSS_FOR_REPICK) then
		return "#aa_repick_locked_boss_alive"
	end

	if IsDuelPossible() then
		local timeToDuel = DuelController:GetTimeToDuel()

		-- -1 - дуэль идёт прямо сейчас
		if timeToDuel < 0 then
			return "#aa_repick_locked_duel_active"
		end

		if timeToDuel <= DUEL_CANT_PICK_PERIOD then
			return "#aa_repick_locked_duel"
		end
	end

	return nil
end

function RepickMenu:CanPickNow()
	return self:GetBlockReason() == nil
end

function RepickMenu:PickHero(player, newHeroName)
	local hero = player:GetAssignedHero() -- is we need to allow repick other team-mate heroes(or just controlled heroes)?

	-- no old hero - no repick
	if not hero or not IsConnected(hero) then 
		return false 
	end

	-- if hero already picked, ignore second pick
	if self.gods_data[newHeroName]['picked'] ~= 0 then
		return true
	end

	-- Забаненные теперь видны в списке, поэтому запрет должен стоять и на
	-- сервере: раньше их просто не было в gods_data и проверка не требовалась.
	if self.gods_data[newHeroName]['banned'] == 1 then
		return true
	end

	local checkFunction = function()
		-- админ-панель открыла меню в обход запретов: один выбор без проверок
		local pid = player:GetPlayerID()
		if self.admin_bypass and self.admin_bypass[pid] then
			self.admin_bypass[pid] = nil
			return true
		end
		if not self:CanPickNow() then return false end
		return true
	end

	-- меню открыто, но пока выбирали, репик закрылся (босс встал, подошла
	-- дуэль) - говорим почему
	if not checkFunction() then
		local reason = self:GetBlockReason()

		if reason then
			CustomGameEventManager:Send_ServerToPlayer(player, "CreateIngameErrorMessage", { message = reason })
		end

		return false
	end

	-- all is ok, lets inform all clients about it
	local oldHeroName = hero:GetUnitName()

	-- say to everybody: that player now owns a new hero
	self.gods_data[newHeroName]['picked'] = 1

	CustomGameEventManager:Send_ServerToAllClients("aa_repick_menu_set_hero_picked", { 
		["hero_name"] = newHeroName, 
		["picked"]    = 1, 
	})
	print("1")

	-- and close menu for player that request repick
	self:Close(player)

	-- if repick was ok -> lets free old hero if someone can repick to it
	local onSuccess = function()
		-- телеметрия: смена героя, только наблюдение (lib/match_tracker.lua)
		if MatchTracker then pcall(MatchTracker.OnHeroChanged, MatchTracker, player, newHeroName) end

		if self.gods_data[oldHeroName] then
			self.gods_data[oldHeroName]['picked'] = 0

			CustomGameEventManager:Send_ServerToAllClients("aa_repick_menu_set_hero_picked", { 
				["hero_name"] = oldHeroName, 
				["picked"]    = 0,
			})
			print("2")
		end
	end

	-- if repick failed -> free new hero to allow any another player repick to it
	local onFailed = function()
		self.gods_data[newHeroName]['picked'] = 0
	
		CustomGameEventManager:Send_ServerToAllClients("aa_repick_menu_set_hero_picked", { 
			["hero_name"] = newHeroName, 
			["picked"]    = 0,
		})
		print("3")
	end

	-- and finally start real repicking
	ChangeHero(player, hero, newHeroName, onSuccess, onFailed, checkFunction)

	return true
end

function RepickMenu:GetData()
	--print(self.gods_data)
	return self.gods_data
end

function RepickMenu:Open(player, bypass)
	CustomGameEventManager:Send_ServerToPlayer(player, "aa_repick_menu_open", { bypass = bypass and 1 or 0 } )
	print('aa_repick_menu_open')
end

function RepickMenu:Close(player)

	CustomGameEventManager:Send_ServerToPlayer(player, "aa_repick_menu_close", {} )
	print('aa_repick_menu_close')
end

function RepickMenu:_repickHero(data)
	
	local player_id = data['PlayerID']

	if not player_id then return end

	local player = PlayerResource:GetPlayer(player_id)

	if not player then return end

	local hero_name = data['hero_name']

	RepickMenu:PickHero( player, hero_name )
end

function RepickMenu:_retriveHeroData(data)
	local player_id = data['PlayerID']

	if not player_id then return end

	local player = PlayerResource:GetPlayer(player_id)

	if not player then return end

	local data = RepickMenu:GetData()

	CustomGameEventManager:Send_ServerToPlayer(player, "aa_repick_menu_set_data", data )
end

