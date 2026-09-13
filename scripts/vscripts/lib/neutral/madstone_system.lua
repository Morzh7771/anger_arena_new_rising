--[[
	БЕЗУМРУДЫ И КРАФТ НЕЙТРАЛОК - СВОЯ СИСТЕМА

	Логика один в один дотовская, отличие ровно одно: разряд открывается не
	по минуте матча, а после дуэли. Разряд N - после N-й дуэли, первая
	дуэль та, что на 0:30.

	Почему пришлось писать своё, а не крутить дотовское: движок открывает
	разряд только по start_time из neutral_items.txt, lua-хука для этого в
	API нет вообще. Поэтому дотовская связка безумрудов и её крафт не
	используются, всё своё - предмет item_madstone_aa, счётчик, меню.

	Как играется, всё как в доте:
		зачистил лагерь целиком -> упали безумруды (рядом нет врагов -
		летят сами, есть - лежат на земле) -> набралось на цену разряда ->
		у слота нейтралки загорелся молоточек -> открыл меню, выбрал один
		предмет и одну чару из предложенных -> взял.
		Пока разряд текущий, крафтить можно сколько угодно раз: первый крафт
		разряда по полной цене, каждый следующий - реролл по своей цене.
		Открылся новый разряд - накопленное сгорает, его надо фармить заново.

	Настройки - scripts/npc/neutral_madstone.kv.
	Списки предметов и чар - scripts/npc/neutral_items.txt.
]]

if not IsServer() then return end

require('lib/timers')
require('lib/attentions')
require('lib/spawners/creep_spawner')

local CONFIG_PATH = "scripts/npc/neutral_madstone.kv"
local TIERS_PATH  = "scripts/npc/neutral_items.txt"
local MADSTONE_ITEM = "item_madstone_aa"
local NET_TABLE = "madstone_progress"

-- Нейтралки, чей эффект в доте делает её крафт - у нас его делаем сами.
-- Модификаторы - modifiers/modifier_aa_neutral_potency.lua, линкуются в
-- addon_init.lua (нужны и клиенту).
local CURIO_ITEM       = "item_dormant_curio"
local BAUBLE_ITEM      = "item_enchanters_bauble"
local POTENCY_MODIFIER = "modifier_aa_neutral_potency"
local BAUBLE_MODIFIER  = "modifier_aa_enchanters_bauble"

-- слоты нейтралки: предмет и чара
local SLOT_ITEM        = DOTA_ITEM_NEUTRAL_ACTIVE_SLOT or 16
local SLOT_ENHANCEMENT = DOTA_ITEM_NEUTRAL_PASSIVE_SLOT or 17

MadstoneSystem = MadstoneSystem or class({})

--------------------------------------------------------------------------------
-- ИНИЦИАЛИЗАЦИЯ
--------------------------------------------------------------------------------

function MadstoneSystem:Init()
	if self.inited then return end
	self.inited = true

	self.duelsFinished = 0
	self.madstones     = {}
	self.offers        = {}
	self.craftedTier   = {}	-- [playerID] = разряд, на котором уже был крафт
	self.baubleCrafts  = {}	-- [playerID] = сколько раз создавал Enchanter's Bauble

	self:_LoadConfig()
	self:_LoadTiers()
	self:_LoadCampCreeps()

	if not self.enabled then
		print("[Madstone] система выключена в " .. CONFIG_PATH)
		return
	end

	-- Зачистку лагеря ловим сами, а не через коллбэк спавнера: спавнер
	-- считает своё внутреннее состояние по волнам, и любая правка кемпов
	-- может это состояние сломать. Нам же достаточно факта: умер крип из
	-- лагеря и рядом больше нет живых крипов лагеря.
	ListenToGameEvent("entity_killed", function(event)
		self:_OnEntityKilled(event)
	end, nil)

	CustomGameEventManager:RegisterListener("aa_madstone_craft", function(_, event)
		self:OnCraftRequest(event)
	end)

	-- первые полминуты раздаём стартовые значения: игроки могли ещё не
	-- подключиться на момент Init, а счётчик должен показывать 0 сразу
	local pushes = 0

	Timers:CreateTimer(2, function()
		self:_PushAll()

		pushes = pushes + 1

		if pushes < 15 then return 2 end
	end)

	print("[Madstone] готово, разрядов:", self.maxTier)
end

-- Имена крипов лагерей берём прямо из конфига спавнера, поэтому список
-- всегда совпадает с тем, что реально стоит на карте.
function MadstoneSystem:_LoadCampCreeps()
	self.campCreeps = {}

	local kv = LoadKeyValues("scripts/npc/creep_spawners.kv") or {}
	local count = 0

	for _, spawner in pairs(kv) do
		if type(spawner) == "table" then
			for _, creepName in pairs(spawner["creeps"] or {}) do
				if type(creepName) == "string" and not self.campCreeps[creepName] then
					self.campCreeps[creepName] = true
					count = count + 1
				end
			end
		end
	end

	print("[Madstone] крипов лагерей в списке:", count)
end

function MadstoneSystem:_OnEntityKilled(event)
	if not self.enabled then return end
	if not event or not event.entindex_killed then return end

	local killed = EntIndexToHScript(event.entindex_killed)

	if not killed or killed:IsNull() then return end
	if not killed.GetUnitName then return end
	if not self.campCreeps[killed:GetUnitName()] then return end

	local pos = killed:GetAbsOrigin()
	local attacker = event.entindex_attacker and EntIndexToHScript(event.entindex_attacker)

	-- Смерть последнего крипа обрабатываем через кадр: на момент события
	-- он ещё числится живым, да и остальные могли умереть в тот же тик.
	Timers:CreateTimer(0.1, function()
		if self:_CampHasAliveCreeps(pos) then return end
		if self:_AlreadyPaid(pos) then return end

		self:OnCampClear({ pos = pos, attacker = attacker })
	end)
end

-- Если последние крипы лагеря умерли в один тик (например от аое), проверка
-- запускается на каждого из них, и каждая видит пустой лагерь - выдача
-- задваивалась. Поэтому помним, когда и где уже платили.
function MadstoneSystem:_AlreadyPaid(pos)
	self.lastPayouts = self.lastPayouts or {}

	local now = GameRules:GetGameTime()
	local fresh = {}
	local paid = false

	for _, entry in pairs(self.lastPayouts) do
		if now - entry.time < self.payoutCooldown then
			table.insert(fresh, entry)

			if (entry.pos - pos):Length2D() <= self.campRadius then
				paid = true
			end
		end
	end

	if not paid then
		table.insert(fresh, { pos = pos, time = now })
	end

	self.lastPayouts = fresh

	return paid
end

function MadstoneSystem:_CampHasAliveCreeps(pos)
	local units = FindUnitsInRadius(
		DOTA_TEAM_NEUTRALS, pos, nil, self.campRadius,
		DOTA_UNIT_TARGET_TEAM_FRIENDLY, DOTA_UNIT_TARGET_ALL,
		DOTA_UNIT_TARGET_FLAG_INVULNERABLE + DOTA_UNIT_TARGET_FLAG_OUT_OF_WORLD,
		FIND_ANY_ORDER, false)

	for _, unit in pairs(units) do
		if unit and not unit:IsNull() and unit:IsAlive()
			and unit.GetUnitName and self.campCreeps[unit:GetUnitName()] then
			return true
		end
	end

	return false
end

function MadstoneSystem:_LoadConfig()
	local kv = LoadKeyValues(CONFIG_PATH) or {}

	self.enabled = tonumber(kv["enabled"] or "1") == 1
	self.maxTier = tonumber(kv["max_tier"] or "5")

	self.tierByDuel = {}

	for duels, tier in pairs(kv["tier_by_duel"] or {}) do
		self.tierByDuel[tonumber(duels)] = tonumber(tier)
	end

	local drop = kv["drop"] or {}

	-- как в доте: зачистивший лагерь получает primary, случайный союзник -
	-- secondary
	self.madstonePrimary   = tonumber(drop["madstone_primary"] or "2")
	self.madstoneSecondary = tonumber(drop["madstone_secondary"] or "1")

	self.dropRadius       = tonumber(drop["radius"] or "80")

	-- в каком радиусе считать, что это один лагерь
	self.campRadius       = tonumber(drop["camp_radius"] or "900")

	-- сколько секунд после выдачи не платить за тот же лагерь ещё раз
	self.payoutCooldown   = tonumber(drop["payout_cooldown"] or "5")
	self.enemyCheckRadius = tonumber(drop["enemy_check_radius"] or "1200")
	self.madstoneLifetime = tonumber(drop["madstone_lifetime"] or "20")

	-- мидас по нейтралу: сколько безумрудов владельцу и сколько каждому
	-- союзнику
	self.midasPrimary   = tonumber(drop["midas_primary"] or "2")
	self.midasSecondary = tonumber(drop["midas_secondary"] or "2")

	local craft = kv["craft"] or {}

	self.costByTier = {}

	for tier, cost in pairs(craft["cost_by_tier"] or {}) do
		self.costByTier[tonumber(tier)] = tonumber(cost)
	end

	-- Повторный крафт того же разряда - реролл, у него своя цена. Разряда
	-- тут нет - берётся цена первого крафта.
	self.rerollCostByTier = {}

	for tier, cost in pairs(craft["reroll_cost_by_tier"] or {}) do
		self.rerollCostByTier[tonumber(tier)] = tonumber(cost)
	end

	-- Новый разряд - безумруды копятся заново. Без этого накопленное на
	-- старом разряде сразу оплачивало новый: молоток горел в момент
	-- открытия, и новый разряд не надо было фармить.
	self.resetOnNewTier = tonumber(craft["reset_on_new_tier"] or "1") == 1

	-- Сколько НОВЫХ вариантов катать. То, что уже надето, показывается
	-- сверх этого и идёт первым - как в доте, чтобы можно было оставить
	-- своё. 0 - брать trinket_options и enhancement_options из
	-- neutral_items.txt.
	self.itemOptionsOverride = tonumber(craft["new_item_options"] or "0")
	self.enhOptionsOverride  = tonumber(craft["new_enhancement_options"] or "0")
end

-- разбираем neutral_items.txt: что лежит в разрядах, почём крафт и сколько
-- вариантов показывать в меню
function MadstoneSystem:_LoadTiers()
	self.tierItems        = {}	-- [разряд] = список имён
	self.tierEnhancements = {}	-- [разряд][группа] = список { имя, уровень }
	self.craftCost        = {}
	self.itemOptions      = {}
	self.enhOptions       = {}

	local kv = LoadKeyValues(TIERS_PATH) or {}

	for tierKey, tierData in pairs(kv["neutral_tiers"] or {}) do
		local tier = tonumber(tierKey)

		if tier and type(tierData) == "table" then
			self.craftCost[tier]   = tonumber(tierData["craft_cost"] or "10")
			self.itemOptions[tier] = tonumber(tierData["trinket_options"] or "4")
			self.enhOptions[tier]  = tonumber(tierData["enhancement_options"] or "4")

			local items = {}

			for itemName, _ in pairs(tierData["items"] or {}) do
				table.insert(items, itemName)
			end

			self.tierItems[tier] = items

			local groups = {}

			for groupName, groupData in pairs(tierData["enhancements"] or {}) do
				if type(groupData) == "table" then
					local list = {}

					for enhName, enhLevel in pairs(groupData) do
						table.insert(list, { enhName, tonumber(enhLevel) or 1 })
					end

					groups[groupName] = list
				end
			end

			self.tierEnhancements[tier] = groups
		end
	end
end

--------------------------------------------------------------------------------
-- РАЗРЯДЫ
--------------------------------------------------------------------------------

-- 0 - первая дуэль ещё не кончилась, крафтить нечего
function MadstoneSystem:GetAllowedTier()
	local best = 0

	for duels, tier in pairs(self.tierByDuel) do
		if duels <= self.duelsFinished and tier > best then
			best = tier
		end
	end

	return math.min(best, self.maxTier)
end

function MadstoneSystem:GetCraftCost(tier)
	return self.costByTier[tier] or self.craftCost[tier] or 10
end

function MadstoneSystem:GetRerollCost(tier)
	return self.rerollCostByTier[tier] or self:GetCraftCost(tier)
end

-- на этом разряде игрок уже крафтил - значит следующий крафт это реролл
function MadstoneSystem:IsReroll(playerID, tier)
	return self.craftedTier[playerID] == tier
end

function MadstoneSystem:GetPlayerCraftCost(playerID, tier)
	if self:IsReroll(playerID, tier) then
		return self:GetRerollCost(tier)
	end

	return self:GetCraftCost(tier)
end

-- зовётся из DuelController в конце каждой дуэли (в том числе пропущенной)
function MadstoneSystem:OnDuelEnd(duelCount)
	if not self.enabled then return end

	local oldTier = self:GetAllowedTier()

	self.duelsFinished = duelCount or (self.duelsFinished + 1)

	local newTier = self:GetAllowedTier()

	if newTier > oldTier then
		Attentions:SendChatMessage("#aa_madstone_tier_" .. newTier)

		-- разряд сменился: старые предложения больше не годятся
		self.offers = {}

		-- и копить на него надо с нуля
		if self.resetOnNewTier then
			for playerID, _ in pairs(self.madstones) do
				self.madstones[playerID] = 0
			end
		end

		for playerID, _ in pairs(self.madstones) do
			self:_TryMakeOffer(playerID)
		end
	end

	self:_PushAll()
end

--------------------------------------------------------------------------------
-- ДРОП С ЛАГЕРЯ
--------------------------------------------------------------------------------

function MadstoneSystem:OnCampClear(event)
	if not self.enabled then return end

	local pos = event and event.pos

	if not pos then return end

	-- До конца первой дуэли безумруды не падают вообще: разряда ещё нет,
	-- крафтить нечего.
	local tier = self:GetAllowedTier()

	if tier <= 0 then
		-- Самая частая причина "безумруды вообще не падают": первая дуэль
		-- ещё не кончилась. Пишем в консоль, чтобы это было видно сразу.
		print("[Madstone] лагерь зачищен, но разряд ещё не открыт. дуэлей закончилось:", self.duelsFinished)
		return
	end

	print("[Madstone] лагерь зачищен, разряд", tier)

	local hero = self:_GetOwnerHero(event.attacker)

	-- Врагов рядом нет - безумруды сразу уходят в счётчик тому, кто добил
	-- лагерь. Физический предмет тут не нужен: подбор с земли движок делает
	-- только когда герой наступает на предмет, из-за этого приходилось
	-- бегать и кликать.
	if hero and not self:_IsEnemyNearby(hero, pos) then
		self:AddMadstones(hero, 1)
		return
	end

	-- Враг рядом - связка падает на землю, как в доте: подберёт тот, кто
	-- удержит лагерь.
	self:_DropMadstone(pos)
end

function MadstoneSystem:_DropMadstone(pos)
	local item = CreateItem(MADSTONE_ITEM, nil, nil)

	if not item then
		print("[Madstone] не удалось создать", MADSTONE_ITEM)
		return
	end

	item:SetPurchaseTime(0)

	local dropPos = pos + RandomVector(self.dropRadius)
	local drop = CreateItemOnPositionSync(dropPos, item)

	self:_ScheduleCleanup(item, drop)
end

function MadstoneSystem:_ScheduleCleanup(item, drop)
	if self.madstoneLifetime <= 0 then return end

	Timers:CreateTimer(self.madstoneLifetime, function()
		if item and IsValidEntity(item) and not item:GetOwnerEntity() then
			if drop and IsValidEntity(drop) then
				UTIL_Remove(drop)
			end

			UTIL_Remove(item)
		end
	end)
end

--------------------------------------------------------------------------------
-- СЧЁТЧИК
--------------------------------------------------------------------------------

-- зовётся из items/item_madstone_aa.lua в момент подбора
function MadstoneSystem:AddMadstones(unit, count)
	if not self.enabled then return end
	if not unit or unit:IsNull() then return end

	local playerID = unit:GetPlayerOwnerID()

	if not playerID or playerID < 0 then return end

	local bundles = count or 1

	self:_Grant(playerID, self.madstonePrimary * bundles)

	-- как в доте: столько же раз капает случайному союзнику
	for i = 1, bundles do
		local allyID = self:_PickRandomAlly(unit, playerID)

		if allyID then
			self:_Grant(allyID, self.madstoneSecondary)
		end
	end
end

function MadstoneSystem:_Grant(playerID, amount)
	if amount <= 0 then return end

	-- Копить впрок нельзя: набралось на крафт - молоток горит, и новые
	-- безумруды не идут, пока не скрафтишь. Каждый крафт фармится заново.
	local tier = self:GetAllowedTier()

	if tier > 0 then
		local room = self:GetPlayerCraftCost(playerID, tier) - self:GetMadstones(playerID)

		amount = math.min(amount, room)
	end

	if amount <= 0 then return end

	self.madstones[playerID] = (self.madstones[playerID] or 0) + amount

	self:_TryMakeOffer(playerID)
	self:_Push(playerID)
end

function MadstoneSystem:_PickRandomAlly(unit, playerID)
	local team = unit:GetTeamNumber()
	local allies = {}

	for id = 0, 23 do
		if id ~= playerID and PlayerResource:IsValidPlayerID(id)
			and PlayerResource:GetTeam(id) == team
			and PlayerResource:GetConnectionState(id) == DOTA_CONNECTION_STATE_CONNECTED then
			table.insert(allies, id)
		end
	end

	if #allies == 0 then return nil end

	return allies[RandomInt(1, #allies)]
end

-- зовётся из items/item_midas.lua, когда мидасом съели нейтрала
function MadstoneSystem:OnMidasUsed(hero)
	if not self.enabled then return end
	if not hero or hero:IsNull() then return end

	-- до конца первой дуэли разряда нет, безумруды не капают
	if self:GetAllowedTier() <= 0 then return end

	local playerID = hero:GetPlayerOwnerID()

	if not playerID or playerID < 0 then return end

	self:_Grant(playerID, self.midasPrimary)

	if self.midasSecondary <= 0 then return end

	local team = hero:GetTeamNumber()

	for id = 0, 23 do
		if id ~= playerID and PlayerResource:IsValidPlayerID(id)
			and PlayerResource:GetTeam(id) == team
			and PlayerResource:GetConnectionState(id) == DOTA_CONNECTION_STATE_CONNECTED then
			self:_Grant(id, self.midasSecondary)
		end
	end
end

function MadstoneSystem:GetMadstones(playerID)
	return self.madstones[playerID] or 0
end

--------------------------------------------------------------------------------
-- ПРЕДЛОЖЕНИЕ И КРАФТ
--------------------------------------------------------------------------------

-- Набралось на разряд - готовим варианты, как дотовское меню крафта:
-- trinket_options предметов и enhancement_options чар из текущего разряда.
function MadstoneSystem:_TryMakeOffer(playerID)
	local tier = self:GetAllowedTier()

	if tier <= 0 then
		self.offers[playerID] = nil
		return
	end

	if self:GetMadstones(playerID) < self:GetPlayerCraftCost(playerID, tier) then
		self.offers[playerID] = nil
		return
	end

	local offer = self.offers[playerID]

	-- уже есть актуальное предложение - не перекатываем его
	if offer and offer.tier == tier then return end

	local hero = PlayerResource:GetSelectedHeroEntity(playerID)

	local itemCount = self.itemOptionsOverride
	local enhCount  = self.enhOptionsOverride

	if itemCount <= 0 then itemCount = self.itemOptions[tier] or 4 end
	if enhCount  <= 0 then enhCount  = self.enhOptions[tier] or 4 end

	-- то, что уже надето, показываем первым и не тратим на него слот
	local ownedItem = hero and hero:GetItemInSlot(SLOT_ITEM)
	local ownedEnh  = hero and hero:GetItemInSlot(SLOT_ENHANCEMENT)

	local ownedItemName = ownedItem and ownedItem:GetAbilityName() or nil
	local ownedEnhName  = ownedEnh and ownedEnh:GetAbilityName() or nil
	local ownedEnhLevel = ownedEnh and ownedEnh:GetLevel() or 1

	-- Уровень чары всегда по текущему разряду. Взял ту же чару на разряде
	-- выше - она апнулась. Если этой чары в разряде нет вообще, оставляем
	-- её как есть, чтобы можно было забрать своё назад.
	if ownedEnhName then
		local tierLevel = self:_GetEnhancementLevel(tier, ownedEnhName)

		if tierLevel then
			ownedEnhLevel = tierLevel
		end
	end

	local items = self:_RollItems(tier, itemCount, ownedItemName)
	local enhancements = self:_RollEnhancements(hero, tier, enhCount, ownedEnhName)

	if ownedItemName then
		table.insert(items, 1, ownedItemName)
	end

	if ownedEnhName then
		table.insert(enhancements, 1, { ownedEnhName, ownedEnhLevel })
	end

	self.offers[playerID] = {
		tier          = tier,
		items         = items,
		enhancements  = enhancements,
		ownedItem     = ownedItemName,
		ownedEnh      = ownedEnhName,
	}
end

-- Числа чары на её уровне - для строки "+15 к скорости передвижения" в меню,
-- как у доты. Нулевые (свойство открывается на уровне повыше) не шлём.
-- KV чары движковый: GetAbilityKeyValuesByName зовём один раз на имя - в
-- цикле он забивает общую таблицу строк KeyValues (см. doc/repick_menu.md).
function MadstoneSystem:_EnhancementStats(name, level)
	self.enhancementKV = self.enhancementKV or {}

	local kv = self.enhancementKV[name]

	if kv == nil then
		kv = GetAbilityKeyValuesByName(name) or false
		self.enhancementKV[name] = kv
	end

	local values = kv and kv["AbilityValues"]

	if type(values) ~= "table" then return "" end

	local parts = {}

	for key, entry in pairs(values) do
		local text = type(entry) == "table" and entry["value"] or entry

		if text ~= nil and type(text) ~= "table" then
			local list = {}

			for word in tostring(text):gmatch("%S+") do
				table.insert(list, tonumber(word))
			end

			local value = list[math.max(1, math.min(level or 1, #list))]

			if value and value ~= 0 then
				table.insert(parts, key .. "=" .. string.format("%g", value))
			end
		end
	end

	table.sort(parts)

	return table.concat(parts, ";")
end

-- какой уровень у этой чары в этом разряде
function MadstoneSystem:_GetEnhancementLevel(tier, name)
	for _, list in pairs(self.tierEnhancements[tier] or {}) do
		for _, entry in pairs(list) do
			if entry[1] == name then
				return entry[2]
			end
		end
	end

	return nil
end

function MadstoneSystem:_RollItems(tier, count, exclude)
	local pool = {}

	for _, name in pairs(self.tierItems[tier] or {}) do
		if name ~= exclude then
			table.insert(pool, name)
		end
	end

	local result = {}

	while #result < count and #pool > 0 do
		local index = RandomInt(1, #pool)

		table.insert(result, pool[index])
		table.remove(pool, index)
	end

	return result
end

-- Врождёнка Chaos Knight: его чары катятся из всего разряда, а не только из
-- своей группы, и выбирает их не игрок, а рандом.
function MadstoneSystem:_HasFundamentalForging(hero)
	if not hero or hero:IsNull() then return false end
	if not hero.HasAbility then return false end

	return hero:HasAbility("chaos_knight_fundamental_forging")
end

-- чары берём из группы global и группы основного атрибута героя,
-- как это делает дота. allGroups - взять вообще все группы разряда.
function MadstoneSystem:_RollEnhancements(hero, tier, count, exclude, allGroups)
	local groups = self.tierEnhancements[tier] or {}

	if allGroups then
		local pool = {}

		for _, list in pairs(groups) do
			for _, entry in pairs(list) do
				if entry[1] ~= exclude then
					table.insert(pool, entry)
				end
			end
		end

		local result = {}

		while #result < count and #pool > 0 do
			local index = RandomInt(1, #pool)

			table.insert(result, { pool[index][1], pool[index][2] })
			table.remove(pool, index)
		end

		return result
	end

	-- числами, а не константами: DOTA_ATTRIBUTE_ALL есть не во всех сборках
	local attributeGroups = {
		[0] = "strength",
		[1] = "agility",
		[2] = "intelligence",
		[3] = "universal",
	}

	local pool = {}

	for _, entry in pairs(groups["global"] or {}) do
		if entry[1] ~= exclude then
			table.insert(pool, entry)
		end
	end

	local attributeGroup = hero and hero.GetPrimaryAttribute and attributeGroups[hero:GetPrimaryAttribute()]

	if attributeGroup then
		for _, entry in pairs(groups[attributeGroup] or {}) do
			if entry[1] ~= exclude then
				table.insert(pool, entry)
			end
		end
	end

	local result = {}
	local taken = {}

	local function take(from)
		while #result < count and #from > 0 do
			local index = RandomInt(1, #from)
			local entry = from[index]

			table.remove(from, index)

			if not taken[entry[1]] then
				taken[entry[1]] = true
				table.insert(result, { entry[1], entry[2] })
			end
		end
	end

	take(pool)

	-- На героя в разряде бывает всего 4 чары (2 общих + 2 атрибута), и
	-- минус надетая выходило 3 новых вместо 4. Недостающие добираем из
	-- остальных групп разряда - после своих и без повторов.
	if #result < count then
		local extra = {}

		for _, list in pairs(groups) do
			for _, entry in pairs(list) do
				if entry[1] ~= exclude and not taken[entry[1]] then
					table.insert(extra, entry)
				end
			end
		end

		take(extra)
	end

	return result
end

-- Клиент прислал выбор из меню. Как в доте, один крафт - это сразу пара:
-- предмет и чара к нему, оба списываются одной ценой.
function MadstoneSystem:OnCraftRequest(event)
	if not self.enabled then return end

	local playerID = event.PlayerID

	if not playerID or playerID < 0 then return end

	local offer = self.offers[playerID]

	if not offer then return end

	local tier = self:GetAllowedTier()

	if offer.tier ~= tier then
		self.offers[playerID] = nil
		return
	end

	local cost = self:GetPlayerCraftCost(playerID, tier)

	if self:GetMadstones(playerID) < cost then return end

	local hero = PlayerResource:GetSelectedHeroEntity(playerID)

	if not hero or hero:IsNull() then return end

	local wantedItem = tostring(event.item or "")
	local wantedEnh  = tostring(event.enhancement or "")

	-- выбранное должно быть из своего же предложения, иначе это не наш клиент
	local itemOk = false

	for _, name in pairs(offer.items) do
		if name == wantedItem then
			itemOk = true
			break
		end
	end

	local enhLevel = nil

	for _, entry in pairs(offer.enhancements) do
		if entry[1] == wantedEnh then
			enhLevel = entry[2]
			break
		end
	end

	-- если в разряде чар нет вообще, крафтим один предмет
	local enhRequired = #offer.enhancements > 0

	local forging = self:_HasFundamentalForging(hero)

	if not itemOk then return end
	if enhRequired and not enhLevel and not forging then return end

	self.madstones[playerID] = self:GetMadstones(playerID) - cost
	self.offers[playerID] = nil

	-- дальше на этом разряде - уже реролл
	self.craftedTier[playerID] = tier

	-- Dormant Curio: артефакт, который её заменит, получает скрытый
	-- потенциал. Смотрим до замены - потом курио в слоте уже не будет.
	local potency = wantedItem ~= CURIO_ITEM and self:_GetCurioPotency(hero) or 0

	self:_EquipNeutral(hero, wantedItem, nil, SLOT_ITEM)

	if potency > 0 then
		self:_ApplyCurio(hero, potency)
	end

	-- Fundamental Forging: чару за игрока катает рандом, зато из всего разряда
	if forging then
		local rolled = self:_RollEnhancements(hero, tier, 1, nil, true)[1]

		if rolled then
			wantedEnh = rolled[1]
			enhLevel  = rolled[2]
		end
	end

	if enhLevel then
		self:_EquipNeutral(hero, wantedEnh, enhLevel, SLOT_ENHANCEMENT)
	end

	-- Enchanter's Bauble: чары сильнее, и с каждым её созданием ещё сильнее
	self:_UpdateBauble(hero, playerID, wantedItem)

	-- хватает ещё на один крафт - сразу катим новые варианты
	self:_TryMakeOffer(playerID)
	self:_Push(playerID)
end

-- сколько процентов даёт курио, если она сейчас надета
function MadstoneSystem:_GetCurioPotency(hero)
	local old = hero:GetItemInSlot(SLOT_ITEM)

	if not old or old:GetAbilityName() ~= CURIO_ITEM then return 0 end

	return old:GetSpecialValueFor("item_potency") or 0
end

-- Какие свойства артефакта усиливает курио - в доте это ключи с флагом
-- apply_curio_bonus в KV предмета. Читаем KV один раз на имя.
function MadstoneSystem:_CurioKeys(itemName)
	self.curioKeys = self.curioKeys or {}

	if self.curioKeys[itemName] == nil then
		local kv = GetAbilityKeyValuesByName(itemName)
		local keys = {}

		for key, entry in pairs(kv and kv["AbilityValues"] or {}) do
			if type(entry) == "table" and tonumber(entry["apply_curio_bonus"]) == 1 then
				table.insert(keys, key)
			end
		end

		table.sort(keys)

		self.curioKeys[itemName] = table.concat(keys, ";")
	end

	return self.curioKeys[itemName]
end

-- Вешаем скрытый потенциал на только что надетый артефакт. Список ключей
-- кладём в custom_entity_values предмета: модификатор читает его и на
-- клиенте, чтобы тултип показывал усиленные числа.
function MadstoneSystem:_ApplyCurio(hero, potency)
	local item = hero:GetItemInSlot(SLOT_ITEM)

	if not item then return end

	local keys = self:_CurioKeys(item:GetAbilityName())

	-- у предмета нет свойств под курио - как и в доте, усиливать нечего
	if keys == "" then return end

	local id = tostring(item:GetEntityIndex())
	local info = CustomNetTables:GetTableValue("custom_entity_values", id) or {}

	info.curio_keys = keys
	CustomNetTables:SetTableValue("custom_entity_values", id, info)

	hero:AddNewModifier(hero, item, POTENCY_MODIFIER, { potency = potency })
end

-- Enchanter's Bauble: пока она надета, чары сильнее на enchantment_bonus_base
-- процентов, и за каждое повторное её создание - ещё на
-- enchantment_bonus_growth. Созданием считается и "оставил свою" на реролле.
-- Процент пересчитываем после каждого крафта: рост мог усилить курио.
function MadstoneSystem:_UpdateBauble(hero, playerID, craftedItem)
	hero:RemoveModifierByName(BAUBLE_MODIFIER)

	local bauble = hero:GetItemInSlot(SLOT_ITEM)

	if not bauble or bauble:GetAbilityName() ~= BAUBLE_ITEM then return end

	if craftedItem == BAUBLE_ITEM then
		self.baubleCrafts[playerID] = (self.baubleCrafts[playerID] or 0) + 1
	end

	local crafts = math.max(1, self.baubleCrafts[playerID] or 1)
	local bonus = bauble:GetSpecialValueFor("enchantment_bonus_base")
		+ bauble:GetSpecialValueFor("enchantment_bonus_growth") * (crafts - 1)

	if bonus > 0 then
		hero:AddNewModifier(hero, bauble, BAUBLE_MODIFIER, { potency = math.floor(bonus + 0.5) })
	end
end

-- кладём предмет в слот нейтралки, старый оттуда убираем - это и есть
-- дотовский реролл
function MadstoneSystem:_EquipNeutral(hero, itemName, level, slot)
	local old = hero:GetItemInSlot(slot)

	-- Оставил своё - не пересоздаём: иначе сбрасывались бы кулдаун, заряды и
	-- усиление от курио. Чару того же имени только поднимаем до уровня разряда.
	if old and old:GetAbilityName() == itemName then
		if level and level > old:GetLevel() then
			old:SetLevel(level)
		end

		return
	end

	-- усиления от курио и безделушки жили на старом артефакте - уходят с ним
	if slot == SLOT_ITEM then
		hero:RemoveModifierByName(POTENCY_MODIFIER)
		hero:RemoveModifierByName(BAUBLE_MODIFIER)
	end

	if old then
		hero:RemoveItem(old)
	end

	local item = CreateItem(itemName, hero, hero)

	if not item then
		print("[Madstone] не удалось создать", itemName)
		return
	end

	if level and level > 1 then
		item:SetLevel(level)
	end

	item:SetPurchaseTime(0)

	hero:AddItem(item)

	-- движок кладёт нейтралку в её слот сам, но если слот был занят или
	-- предмет уехал в рюкзак - двигаем руками
	if hero:GetItemInSlot(slot) ~= item then
		for i = 0, 8 do
			if hero:GetItemInSlot(i) == item then
				hero:SwapItems(i, slot)
				break
			end
		end
	end
end

--------------------------------------------------------------------------------
-- НЕТ-ТАБЛИЦА ДЛЯ ИНТЕРФЕЙСА
--------------------------------------------------------------------------------

function MadstoneSystem:_Push(playerID)
	local tier  = self:GetAllowedTier()
	local offer = self.offers[playerID]

	local items = {}
	local enhancements = {}

	if offer then
		for _, name in pairs(offer.items) do
			table.insert(items, name)
		end

		-- "имя:уровень:ключ=число;ключ=число" - числа для строки статов в меню
		for _, entry in pairs(offer.enhancements) do
			table.insert(enhancements, entry[1] .. ":" .. tostring(entry[2]) .. ":"
				.. self:_EnhancementStats(entry[1], entry[2]))
		end
	end

	CustomNetTables:SetTableValue(NET_TABLE, tostring(playerID), {
		madstones    = self:GetMadstones(playerID),
		tier         = tier,
		cost         = tier > 0 and self:GetPlayerCraftCost(playerID, tier) or 0,
		first_cost   = tier > 0 and self:GetCraftCost(tier) or 0,
		reroll_cost  = tier > 0 and self:GetRerollCost(tier) or 0,
		reroll       = (tier > 0 and self:IsReroll(playerID, tier)) and 1 or 0,
		can_craft    = offer and 1 or 0,
		items        = table.concat(items, "|"),
		enhancements = table.concat(enhancements, "|"),
		owned_item   = offer and offer.ownedItem or "",
		owned_enh    = offer and offer.ownedEnh or "",
		duels        = self.duelsFinished,
	})
end

function MadstoneSystem:_PushAll()
	for playerID = 0, 23 do
		if PlayerResource:IsValidPlayerID(playerID) then
			self:_Push(playerID)
		end
	end
end

--------------------------------------------------------------------------------
-- ВСПОМОГАТЕЛЬНОЕ
--------------------------------------------------------------------------------

-- герой, которому засчитывать зачистку лагеря (сам герой, либо владелец
-- иллюзии/сумона, который нанёс последний удар)
function MadstoneSystem:_GetOwnerHero(attacker)
	if not attacker or attacker:IsNull() then return nil end
	if not attacker.GetPlayerOwnerID then return nil end

	local playerID = attacker:GetPlayerOwnerID()

	if not playerID or playerID < 0 then return nil end

	local hero = PlayerResource:GetSelectedHeroEntity(playerID)

	if not hero or hero:IsNull() or not hero:IsAlive() then return nil end

	return hero
end

function MadstoneSystem:_IsEnemyNearby(hero, pos)
	if self.enemyCheckRadius <= 0 then return false end

	local enemies = FindUnitsInRadius(
		hero:GetTeamNumber(), pos, nil, self.enemyCheckRadius,
		DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO,
		DOTA_UNIT_TARGET_FLAG_NO_INVIS + DOTA_UNIT_TARGET_FLAG_FOW_VISIBLE,
		FIND_ANY_ORDER, false)

	for _, enemy in pairs(enemies) do
		if enemy and not enemy:IsNull() and enemy:IsRealHero() and enemy:IsAlive() then
			return true
		end
	end

	return false
end

--------------------------------------------------------------------------------

return MadstoneSystem
