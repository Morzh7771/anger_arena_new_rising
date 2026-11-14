-- Премиум-косметика: кто премиум, что надето, применение на герое, сохранение в бэкенд.
--
-- Эффекты - lib/cosmetics/effects.lua, каталог и названия слотов - catalog.lua,
-- пет-юнит - scripts/npc/npc_units_custom.txt + modifiers/modifier_aa_cosmetic_pet.lua.
--
-- Премиум:
--   - из ответов бэкенда на поиск в лобби / старт матча (MatchTracker вызывает
--     CosmeticsCore:OnPlayersInfo(rows));
--   - аккаунт владельца мода всегда премиум (OWNER_ACCOUNT), на случай если бэкенд
--     ещё не знает про косметику.
--
-- Нет-таблицы:
--   aa_cosmetics[pid]  = { premium = 0/1, <слот> = id или "" ... }
--   aa_cos_catalog[слот] = { [порядок] = { id, name, rarity, slot, icon, order } }
--
-- Ивенты (через защиту events_protector.lua):
--   клиент -> сервер  aa_cos_equip   { slot, item_id }  повторный клик = снять
--   сервер -> клиент  aa_cos_result  { ok, msg, slot }

if not IsServer() then return end

require('lib/cosmetics/catalog')
require('lib/cosmetics/precache')
require('lib/cosmetics/effects')

CosmeticsCore = CosmeticsCore or {}

local C = CosmeticsCore

local OWNER_ACCOUNT = 960329385 -- Steam account id владельца мода
local PET_UNIT = "npc_dota_aa_cosmetic_pet"
local MAX_PID = 23
local PET_OFFSET = 120
local RAD_TICK_INTERVAL = 0.25 -- дебафф радианса на врагах (CosmeticsEffects.TickRadiance)

local SLOT_SET = {}

for _, s in ipairs(COSMETIC_SLOTS) do
	SLOT_SET[s.slot] = true
end

C.premium = C.premium or {}   -- pid -> true, если бэкенд выдал премиум
C.equipped = C.equipped or {} -- pid -> { [слот] = item_id }
C.loaded = C.loaded or {}     -- pid -> true, когда экипировка пришла с бэкенда
C.pets = C.pets or {}         -- pid -> юнит пета
C.pet_fx = C.pet_fx or {}     -- pid -> индексы партиклов пета (гасятся вместе с петом)
C.sig = C.sig or {}          -- pid -> строка последнего опубликованного состояния

-- ------------------------------------------------------------------ steam id

-- Как SteamIdOf в lib/match_tracker.lua: 64-битный id склеиваем строкой
local function SteamIdString(acc)
	local x = 960265728 + acc
	local q = math.floor(x / 1000000000)
	local r = x - q * 1000000000

	return tostring(76561197 + q) .. string.format("%09d", r)
end

local function AccountOf(pid)
	if pid == nil or pid < 0 or not PlayerResource:IsValidPlayerID(pid) then return 0 end

	return PlayerResource:GetSteamAccountID(pid) or 0
end

function C:PidOfSteamId(sid)
	for pid = 0, MAX_PID do
		if PlayerResource:IsValidPlayerID(pid) and SteamIdString(AccountOf(pid)) == sid then
			return pid
		end
	end

	return nil
end

-- ------------------------------------------------------------------ премиум и экипировка

-- 64-битный steam id строкой (для social.lua: запись слотов колеса)
function C:SteamIdOf(pid)
	return SteamIdString(AccountOf(pid))
end

function C:IsPremium(pid)
	if pid == nil or pid < 0 then return false end
	if self.premium[pid] then return true end

	-- премиум владельца теперь только с бэкенда (как у всех): можно снять и посмотреть игру без него
	return false
end

-- Есть ли предмет в инвентаре игрока (сундуки, пасс - progression.py, профиль в AAProgression)
function C:Owns(pid, id)
	local prog = AAProgression and AAProgression.data and AAProgression.data[pid]
	local inv = prog and prog.inventory

	if type(inv) ~= "table" then return false end

	for _, v in pairs(inv) do
		if v == id then return true end
	end

	return false
end

-- Предмет (таблица из каталога), если слот надет и игрок может его носить: премиум или предмет в инвентаре
function C:GetEquipped(pid, slot)
	local e = self.equipped[pid]
	local id = e and e[slot]

	if not id then return nil end
	if not self:Owns(pid, id) then return nil end

	return CosmeticsFindItem(slot, id)
end

-- ------------------------------------------------------------------ нет-таблицы

-- Публикуем только если состояние поменялось: таймер ниже дёргает это часто
function C:Publish(pid)
	if pid == nil or pid < 0 then return end

	local out = { premium = self:IsPremium(pid) and 1 or 0 }
	local parts = { tostring(out.premium) }

	for _, s in ipairs(COSMETIC_SLOTS) do
		local item = self:GetEquipped(pid, s.slot)

		out[s.slot] = item and item.id or ""
		parts[#parts + 1] = out[s.slot]
	end

	local sig = table.concat(parts, "|")

	if self.sig[pid] == sig then return end

	self.sig[pid] = sig
	CustomNetTables:SetTableValue("aa_cosmetics", tostring(pid), out)
end

function C:PublishAll()
	for pid = 0, MAX_PID do
		if PlayerResource:IsValidPlayerID(pid) then self:Publish(pid) end
	end
end

-- Каталог для меню: один раз, после загрузки всех модулей (социалка подмешивается здесь)
function C:PublishCatalog()
	for _, s in ipairs(COSMETIC_SLOTS) do
		local items = {}

		for _, it in ipairs(COSMETICS_CATALOG[s.slot] or {}) do items[#items + 1] = it end
		for _, it in ipairs((SOCIAL_CATALOG and SOCIAL_CATALOG[s.slot]) or {}) do items[#items + 1] = it end

		local list = {}

		for i, it in ipairs(items) do
			list[tostring(i)] = {
				id = it.id,
				name = it.name_ru or it.name or it.id,
				rarity = it.rarity or "common",
				slot = s.slot,
				icon = it.icon or "",
				-- превью для хаба, если у предмета нет записи в PREVIEW клиента (контент aaf/1x6)
				def = it.def or 0,   -- item def курьера доты: 3D-превью пета в хабе
				preview = it.particle or it.overhead or (it.particles and it.particles[1] and it.particles[1].path) or "",
				order = i,
			}
		end

		CustomNetTables:SetTableValue("aa_cos_catalog", s.slot, list)
	end
end

-- ------------------------------------------------------------------ бэкенд

-- Ответ бэкенда на поиск в лобби / старт матча. rows - players[] с steam_id, premium, equipped
function C:OnPlayersInfo(rows)
	if type(rows) ~= "table" then return end

	for _, row in ipairs(rows) do
		if type(row) == "table" and row.steam_id ~= nil then
			local pid = self:PidOfSteamId(tostring(row.steam_id))

			if pid ~= nil then
				local was_premium = self:IsPremium(pid)
				local was_loaded = self.loaded[pid] == true

				self.premium[pid] = (row.premium == true or tonumber(row.premium) == 1) or nil

				-- экипировку берём один раз: дальше игрок меняет её сам, и поздний ответ
				-- поиска не должен откатить его выбор
				if not was_loaded and type(row.equipped) == "table" then
					local eq = {}

					for _, s in ipairs(COSMETIC_SLOTS) do
						local id = row.equipped[s.slot]

						if id ~= nil and id ~= "" and CosmeticsFindItem(s.slot, tostring(id)) then
							eq[s.slot] = tostring(id)
						end
					end

					self.equipped[pid] = eq
					self.loaded[pid] = true

					-- слоты колеса фраз (бэкенд: wheel_slots[8]), проверка id - в social.lua
					if type(row.wheel_slots) == "table" and CosmeticsSocial and CosmeticsSocial.LoadWheelSlots then
						pcall(CosmeticsSocial.LoadWheelSlots, CosmeticsSocial, pid, row.wheel_slots)
					end
				end

				-- надетое грузим сразу (ответ приходит в лобби / пре-гейме), а не на первом
				-- спавне: асинхронная загрузка посреди боя даёт фриз у всех клиентов
				if self:IsPremium(pid) then pcall(self.PrefetchHero, self, pid) end

				-- прогресс (пасс, осколки, сундуки, задания) приходит в том же ответе (progression.py)
				if type(row.progress) == "table" and AAProgression then pcall(AAProgression.Set, AAProgression, pid, row.progress) end

				self:Publish(pid)

				local hero = PlayerResource:GetSelectedHeroEntity(pid)

				if hero and hero:IsRealHero() and (was_premium ~= self:IsPremium(pid) or (not was_loaded and self.loaded[pid])) then
					pcall(self.ApplyToHero, self, hero)
				end
			end
		end
	end
end

function C:Persist(pid, slot, item_id)
	if not MatchTracker or not MatchTracker.SignedPost then return end

	pcall(function()
		MatchTracker:SignedPost("/api/cosmetics/equip", {
			steam_id = SteamIdString(AccountOf(pid)),
			slot = slot,
			item_id = item_id or "",
		}, nil)
	end)
end

-- ------------------------------------------------------------------ применение

-- Ауры и эффекты героя из экипировки. Ресурсы догружаются по запросу (precache.lua),
-- поэтому применяем, когда все предметы готовы. token: поздний колбэк от старой экипировки игнорируем.
function C:ApplyHeroFx(hero)
	local pid = hero:GetPlayerOwnerID()

	if pid < 0 then return end

	self.fx_req = self.fx_req or {}

	local token = {}

	self.fx_req[pid] = token

	local wanted = {}

	for _, slot in ipairs({ "aura", "wings" }) do
		wanted[#wanted + 1] = self:GetEquipped(pid, slot)
	end

	CosmeticsLoader.EnsureAll(wanted, function()
		if self.fx_req[pid] ~= token then return end
		if not hero or hero:IsNull() or not hero:IsAlive() then return end

		local items = {}

		for _, slot in ipairs({ "aura", "wings" }) do
			local it = self:GetEquipped(pid, slot)

			if it then items[#items + 1] = it end
		end

		CosmeticsEffects.ApplyHeroFx(hero, pid, items)
	end)
end

-- Предметы, которые нужны на спавне и в бою: прекеш заранее (не social - его модуль свой)
function C:PrefetchHero(pid)
	local wanted = {}

	for _, s in ipairs(COSMETIC_SLOTS) do
		-- из социальных ресурсы есть только у спрея и хай-файва (юниты npc_aa_cos_<id>)
		if s.kind ~= "social" or s.slot == "spray" or s.slot == "high_five" then
			wanted[#wanted + 1] = self:GetEquipped(pid, s.slot)
		end
	end

	CosmeticsLoader.EnsureAll(wanted, nil)
end

-- Убрать пета и его партиклы (смена, смерть владельца, дисконнект)
function C:RemovePet(pid)
	local pet = self.pets[pid]

	self.pets[pid] = nil

	CosmeticsEffects.FreeList(self.pet_fx[pid])
	self.pet_fx[pid] = nil

	if pet and not pet:IsNull() then
		pcall(function() pet:RemoveSelf() end)
	end
end

-- Пет: старого убираем сразу, нового создаём, когда курьер прекешен (token от гонок)
function C:SpawnPet(hero)
	local pid = hero:GetPlayerOwnerID()

	if pid < 0 then return end

	self.pet_req = self.pet_req or {}

	local token = {}

	self.pet_req[pid] = token

	self:RemovePet(pid)

	local item = self:GetEquipped(pid, "pet")

	if not item then return end

	CosmeticsLoader.Ensure(item, function()
		if self.pet_req[pid] ~= token then return end
		if not hero or hero:IsNull() or not hero:IsAlive() then return end

		self:CreatePet(hero, item)
	end)
end

function C:CreatePet(hero, item)
	local pid = hero:GetPlayerOwnerID()

	self:RemovePet(pid)

	local pos = hero:GetAbsOrigin() - hero:GetForwardVector() * PET_OFFSET
	local pet = CreateUnitByName(PET_UNIT, pos, true, hero, hero, hero:GetTeamNumber())

	if not pet then return end

	pet:SetOwner(hero)

	if item.model then
		pet:SetModel(item.model)
		pet:SetOriginalModel(item.model)
	end

	-- масштаб модели (петы из aaf, например волк Ликана 0.5)
	if item.scale then pet:SetModelScale(item.scale) end

	pet:AddNewModifier(hero, nil, "modifier_aa_cosmetic_pet", { flying = item.flying and 1 or 0 })

	self.pet_fx[pid] = CosmeticsEffects.SpawnUnitFx(pet, item.particles)
	self.pets[pid] = pet
end

-- Всё для героя игрока: ауры, пет (радианс синхронизируется таймером)
function C:ApplyToHero(hero)
	if not hero or hero:IsNull() or not hero:IsRealHero() or not hero:IsAlive() then return end

	local pid = hero:GetPlayerOwnerID()

	if pid < 0 then return end

	self:Publish(pid)
	self:PrefetchHero(pid)
	self:ApplyHeroFx(hero)
	self:SpawnPet(hero)
end

-- Экипировка поменялась на живом герое: применяем только затронутый слот
function C:ApplyLive(pid, slot)
	local hero = PlayerResource:GetSelectedHeroEntity(pid)

	if not hero or hero:IsNull() or not hero:IsRealHero() or not hero:IsAlive() then return end

	if slot == "pet" then
		self:SpawnPet(hero)
	elseif slot == "aura" or slot == "wings" then
		self:ApplyHeroFx(hero)
	elseif slot == "spray" or slot == "high_five" then
		-- ресурсы только надетого спрея / хай-файва, заранее, до первого использования
		CosmeticsLoader.Ensure(self:GetEquipped(pid, slot), nil)
	end
	-- радианс, телепорт и убийство берут выбор из GetEquipped при событии
end

-- ------------------------------------------------------------------ обмен с панелью

local function Result(player, ok, msg, slot)
	if not player then return end

	CustomGameEventManager:Send_ServerToPlayer(player, "aa_cos_result", {
		ok = ok and 1 or 0,
		msg = msg or "",
		slot = slot or "",
	})
end

function C:OnEquip(data)
	local pid = tonumber(data.PlayerID)

	if pid == nil or pid < 0 then return end

	local player = PlayerResource:GetPlayer(pid)

	if not player then return end

	local slot = data.slot

	if type(slot) ~= "string" or not SLOT_SET[slot] then return Result(player, false, "slot", "") end

	local item_id = tostring(data.item_id or "")

	if not CosmeticsFindItem(slot, item_id) then return Result(player, false, "item", slot) end

	-- носить можно только то, что есть в инвентаре (премиум ничего не открывает) (снять - всегда)
	local current = self.equipped[pid] and self.equipped[pid][slot]

	if current ~= item_id and not self:Owns(pid, item_id) then
		return Result(player, false, "premium", slot)
	end

	self.equipped[pid] = self.equipped[pid] or {}

	local new_id

	-- повторный клик по надетому предмету снимает его
	if self.equipped[pid][slot] == item_id then
		self.equipped[pid][slot] = nil
		new_id = ""
	else
		self.equipped[pid][slot] = item_id
		new_id = item_id
	end

	self:Publish(pid)
	self:Persist(pid, slot, new_id)

	-- надели - сразу догружаем ресурсы предмета (один раз на предмет)
	if new_id ~= "" then CosmeticsLoader.Ensure(CosmeticsFindItem(slot, new_id)) end

	self:ApplyLive(pid, slot)

	Result(player, true, new_id == "" and "unequip" or "equip", slot)
end

CustomGameEventManager:RegisterListener("aa_cos_equip", function(_, data)
	local ok, err = pcall(C.OnEquip, C, data)

	if not ok then print("[Cosmetics] equip failed: " .. tostring(err)) end
end)

-- ------------------------------------------------------------------ события игры

-- Радианс владельца: раз в секунду сверяем предметы у героев с выбранным вариантом
-- (пересоздаёт партикл только при смене варианта или героя, см. effects.lua)
function C:RadianceTick()
	for pid = 0, MAX_PID do
		if PlayerResource:IsValidPlayerID(pid) then
			local hero = PlayerResource:GetSelectedHeroEntity(pid)

			if hero and hero:IsRealHero() then
				local item = self:GetEquipped(pid, "radiance_effect")

				pcall(CosmeticsEffects.SyncRadiance, hero, pid, item)
			end
		end
	end
end

function C:OnDisconnect(pid)
	if pid == nil or pid < 0 then return end

	self:RemovePet(pid)
	CosmeticsEffects.ClearHero(pid)
end

ListenToGameEvent("npc_spawned", function(event)
	pcall(function()
		local u = event.entindex and EntIndexToHScript(event.entindex) or nil

		if not u or not u:IsRealHero() then return end

		-- герой на следующем тике, модель и предметы уже на месте
		Timers:CreateTimer(0.1, function()
			pcall(C.ApplyToHero, C, u)

			return nil
		end)
	end)
end, nil)

ListenToGameEvent("entity_killed", function(event)
	pcall(function()
		local killed = event.entindex_killed and EntIndexToHScript(event.entindex_killed) or nil

		if not killed or not killed:IsRealHero() then return end

		-- аура и эффекты героя уходят со смертью, пет прячется сам (модификатор)
		local kpid = killed:GetPlayerOwnerID()

		CosmeticsEffects.ClearHero(kpid)
		C:RemovePet(kpid)

		local attacker = event.entindex_attacker and EntIndexToHScript(event.entindex_attacker) or nil

		if not attacker or not attacker:IsRealHero() then return end

		local apid = attacker:GetPlayerOwnerID()

		if apid < 0 or not C:IsPremium(apid) then return end

		CosmeticsEffects.PlayKill(C:GetEquipped(apid, "kill_effect"), killed:GetAbsOrigin(), killed)
	end)
end, nil)

ListenToGameEvent("dota_player_used_ability", function(event)
	pcall(function()
		local name = event.abilityname

		if not name or not CosmeticsEffects.TP_ITEMS[name] then return end

		local pid = event.PlayerID

		if pid == nil or not C:IsPremium(pid) then return end

		local item = C:GetEquipped(pid, "tp_effect")

		if not item then return end

		local hero = PlayerResource:GetSelectedHeroEntity(pid)

		if not hero then return end

		CosmeticsEffects.BeginTp(item, hero, pid)
	end)
end, nil)

ListenToGameEvent("player_disconnect", function(event)
	pcall(function()
		C:OnDisconnect(event.PlayerID or event.player_id)
	end)
end, nil)

ListenToGameEvent("player_reconnected", function(event)
	pcall(function()
		local pid = event.PlayerID or event.player_id

		if pid == nil or pid < 0 then return end

		Timers:CreateTimer(0.5, function()
			local hero = PlayerResource:GetSelectedHeroEntity(pid)

			if hero then pcall(C.ApplyToHero, C, hero) end

			return nil
		end)
	end)
end, nil)

-- ------------------------------------------------------------------ запуск

Timers:CreateTimer(0.5, function()
	pcall(PrecacheUnitByNameAsync, PET_UNIT, function() end)

	return nil
end)

Timers:CreateTimer(3, function()
	pcall(C.PublishCatalog, C)

	return nil
end)

-- состояние игроков: тикает раз в 2 с, в сеть уходит только изменившееся
Timers:CreateTimer(2, function()
	pcall(C.PublishAll, C)

	return 2
end)

Timers:CreateTimer(1, function()
	pcall(C.RadianceTick, C)

	return 1
end)

-- дебафф радианса на врагах: 0.25 с, партикл создаётся один раз на врага и гаснет при снятии
Timers:CreateTimer(RAD_TICK_INTERVAL, function()
	pcall(CosmeticsEffects.TickRadiance)

	return RAD_TICK_INTERVAL
end)


-- ------------------------------------------------------------------ эффекты предметов (2026-11-12)
-- Надетый предмет слота у владельца юнита (блинк, фазы, мьёльнир, хекс, снаряд...). nil - нет премиума,
-- ничего не надето или ресурсы ещё не загружены (тогда грузим и в этот раз даём ванильный эффект).
-- Зовут предметы: items/item_blinks.lua, item_phase_boots_aa.lua, item_mjolnir.lua, item_sheepstick_aa.lua.
function AACosmeticItem(unit, slot)
	if not unit or unit:IsNull() or not unit.GetPlayerOwnerID then return nil end

	local pid = unit:GetPlayerOwnerID()

	if pid == nil or pid < 0 then return nil end

	local ok, item = pcall(C.GetEquipped, C, pid, slot)

	if not ok or not item then return nil end

	if CosmeticsLoader and not CosmeticsLoader.IsReady(item) then
		CosmeticsLoader.Ensure(item)

		return nil
	end

	return item
end

-- путь n-го партикла надетого предмета или fallback
function AACosmeticPath(unit, slot, n, fallback)
	local item = AACosmeticItem(unit, slot)
	local p = item and item.particles and item.particles[n or 1]

	return (p and p.path) or fallback
end

return C
