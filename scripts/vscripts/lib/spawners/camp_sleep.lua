--[[
	Спящие лагеря.

	ЗАЧЕМ.
	К 8-10 минуте лагеря выходят на потолок стака: 50 лагерей * до 3 волн *
	~3 крипа = под 480 нейтралов, живых одновременно. Число крипов - это
	баланс, и трогать его нельзя. Но подавляющее большинство из них в любой
	момент времени просто стоит дома, и рядом с ними никого нет.

	Самая частая периодическая работа на юните в движке - поиск цели
	(acquisition): каждый юнит регулярно сканирует вокруг себя врагов. 480
	юнитов, которые круглые сутки ищут, кого бы заагрить, - это заметная
	постоянная нагрузка на серверный тик, а просадка тика видна игроку как
	микрофризы и "фпс упал".

	ЧТО ДЕЛАЕМ.
	Раз в полсекунды на каждый лагерь делаем ОДИН поиск: есть ли в радиусе
	WAKE_RADIUS хоть кто-то чужой. Нет - ставим крипам лагеря acquisition
	range 0, и движок перестаёт их сканировать. Появился кто-то - возвращаем
	исходный радиус.

	ПОЧЕМУ ЭТО НЕ МЕНЯЕТ ГЕЙМПЛЕЙ.
	1) WAKE_RADIUS (2000) заметно больше любого acquisition range нейтралов
	   (у ванильных ~500-800). То есть к моменту, когда крип В ПРИНЦИПЕ мог бы
	   кого-то заагрить сам, он уже давно разбужен.
	2) Спящий крип не перестаёт быть крипом: если его ударить, он ответит -
	   реакция на атаку идёт не через acquisition. Плюс атакующий по
	   определению находится внутри WAKE_RADIUS, так что лагерь всё равно
	   проснётся на ближайшем тике.
	3) Крипа, которого увели от лагеря (ручной пул), не усыпляем вовсе -
	   см. LEASH.

	Систему можно выключить на лету: -campsleep 0 (чит-лобби).
]]

require('lib/timers')

CampSleep = CampSleep or class({})

-- Радиус пробуждения. Держим с большим запасом над acquisition range
-- нейтралов: лучше разбудить лишний лагерь, чем не разбудить нужный.
--
-- Игрок НЕ должен заметить, что лагерь прятали. Поэтому радиус считаем от
-- обзора, а не от агра: дневной обзор героя 1800 + блинк 1200 + запас.
-- Пока герой дальше, лагерь он увидеть не может ни ногами, ни блинком, а
-- юниты, созданные вне обзора, клиенту вообще не приходят - появление не видно.
local WAKE_RADIUS = 3500

-- Как часто проверяем. Поиск один на тик на всю карту (_CollectWakers), дальше
-- только расстояния в Lua - 4 поиска в секунду на все лагеря.
local TICK = 0.25

-- Крип дальше этого расстояния от точки спавна считается уведённым и не спит.
local LEASH = 900

local TIMER_NAME = "CampSleepTick"

-- СПЯЧКА. Лагерь, который спит дольше HIBERNATE_DELAY, не виден ни одной
-- команде и все крипы в нём дома с полным здоровьем, убираем с карты
-- целиком: юниты удаляются, а CreepSpawner держит учёт лагеря как есть
-- (живые, волны, стак). Нет юнита - нет ни ИИ, ни аур, ни событий, ни
-- сетевого трафика. Кто-то подошёл или появился обзор - крипы создаются
-- заново на тех же местах, с актуальными статами (CreepLeveling).
local HIBERNATE_DELAY = 10

CampSleep._enabled = true

function CampSleep:Init()
	if self._inited then return end

	self._inited = true
	self._camps = self._camps or {}

	-- Блинк, ТП, прыжки и прочее с точкой: будим лагеря у точки назначения
	-- сразу, в момент применения, не дожидаясь тика. ТП ещё и канализуется,
	-- так что крипы успевают появиться задолго до прибытия.
	ListenToGameEvent("dota_player_used_ability", function(event)
		self:_OnAbilityUsed(event)
	end, nil)

	Timers:CreateTimer(TIMER_NAME, {
		useGameTime = true,
		endTime = TICK,
		callback = function()
			self:_Tick()
			return TICK
		end
	})
end

-- Вешается на CreepSpawner:RegisterOnSpawnCallback
function CampSleep:OnCreepSpawned(event)
	local creep = event and event.creep
	local spawner_info = event and event.spawner_info

	if not creep or creep:IsNull() then return end
	if not spawner_info or not spawner_info.name then return end

	local name = spawner_info.name
	local camp = self._camps[name]

	if not camp then
		camp = { name = name, pos = spawner_info.pos, units = {}, asleep = false }
		self._camps[name] = camp
	end

	-- позиция лагеря могла не приехать в spawner_info - берём по первому крипу
	if not camp.pos then camp.pos = creep:GetAbsOrigin() end

	camp.units[creep:GetEntityIndex()] = creep

	-- лагерь спавнится только когда в боксе никого нет, так что свежий крип
	-- спокойно наследует состояние лагеря
	if camp.asleep and self._enabled then
		self:_Sleep(creep, camp)
	end
end

function CampSleep:SetEnabled(bVal)
	self._enabled = bVal and true or false

	if self._enabled then return end

	-- выключили - будим всех, чтобы не оставить лагеря глухими
	for _, camp in pairs(self._camps or {}) do
		camp.asleep = false
		self:_Restore(camp)

		for _, unit in pairs(camp.units) do
			self:_Wake(unit)
		end
	end
end

function CampSleep:GetEnabled()
	return self._enabled
end

-- для -perf: сколько лагерей сейчас спит и сколько крипов под учётом
function CampSleep:GetStats()
	local camps, sleeping, units, asleepUnits = 0, 0, 0, 0

	for _, camp in pairs(self._camps or {}) do
		camps = camps + 1
		if camp.asleep then sleeping = sleeping + 1 end

		for _, unit in pairs(camp.units) do
			units = units + 1
			if unit._aa_asleep then asleepUnits = asleepUnits + 1 end
		end
	end

	return camps, sleeping, units, asleepUnits
end

--------------------------------------------------------------------------------

-- Мгновенно вернуть спрятанные лагеря в радиусе от точки. Зовут телепорты
-- мода (lib/teleport.lua, mid_teleport) и применение способностей.
function CampSleep:WakeNear(pos)
	if not pos or not self._camps then return end

	local now = GameRules:GetGameTime()

	for _, camp in pairs(self._camps) do
		if camp.hibernated and camp.pos and (camp.pos - pos):Length2D() <= WAKE_RADIUS then
			camp.asleep = false
			camp.sleepSince = now

			self:_Restore(camp)

			for _, unit in pairs(camp.units) do
				self:_Wake(unit)
			end
		end
	end
end

function CampSleep:_OnAbilityUsed(event)
	local playerID = event and event.PlayerID
	local abilityName = event and event.abilityname

	if playerID == nil or not abilityName then return end

	local hero = PlayerResource:GetSelectedHeroEntity(playerID)
	if not hero or hero:IsNull() then return end

	local ability = hero:FindAbilityByName(abilityName) or hero:FindItemInInventory(abilityName)

	if ability and ability.GetCursorPosition then
		local target = ability:GetCursorPosition()

		if target and target:Length2D() > 0 then
			self:WakeNear(target)
		end
	end
end

-- для сводки [AA.perf]: сколько лагерей спрятано и сколько в них крипов
function CampSleep:GetHibernatedStats()
	local camps, units = 0, 0

	for _, camp in pairs(self._camps or {}) do
		if camp.hibernated then
			camps = camps + 1
			units = units + #camp.hibernated
		end
	end

	return camps, units
end

function CampSleep:_Tick()
	if not self._enabled then return end

	local now = GameRules:GetGameTime()
	-- кто сейчас на карте может разбудить лагерь - один поиск на весь тик
	local wakers = self:_CollectWakers()

	for name, camp in pairs(self._camps) do
		local alive = self:_Prune(camp)

		if alive == 0 and not camp.hibernated then
			self._camps[name] = nil
		else
			local shouldSleep = not self:_HasOutsidersNear(camp, wakers) and not self:_IsCampVisible(camp)

			if shouldSleep ~= camp.asleep then
				camp.asleep = shouldSleep
				camp.sleepSince = now

				-- просыпаемся - сначала возвращаем спрятанных крипов
				if not shouldSleep then
					self:_Restore(camp)
				end

				for _, unit in pairs(camp.units) do
					if shouldSleep then
						self:_Sleep(unit, camp)
					else
						self:_Wake(unit)
					end
				end
			end

			if camp.asleep and alive > 0 and now - (camp.sleepSince or now) >= HIBERNATE_DELAY
				and self:_CanHibernate(camp) then
				self:_Hibernate(camp)
			end
		end
	end
end

-- лагерь видит хоть одна из команд (варды, обзор издалека)
function CampSleep:_IsCampVisible(camp)
	if not camp.pos then return true end

	return IsLocationVisible(DOTA_TEAM_GOODGUYS, camp.pos) or IsLocationVisible(DOTA_TEAM_BADGUYS, camp.pos)
end

-- прятать можно, только если все крипы дома и целые: иначе после возврата
-- у недобитого крипа было бы полное здоровье, а уведённый вернулся бы домой
function CampSleep:_CanHibernate(camp)
	for _, unit in pairs(camp.units) do
		if unit:IsDominated() then return false end
		if unit:GetHealth() < unit:GetMaxHealth() then return false end
		if camp.pos and (unit:GetAbsOrigin() - camp.pos):Length2D() > LEASH then return false end
	end

	return true
end

function CampSleep:_Hibernate(camp)
	camp.hibernated = camp.hibernated or {}

	for idx, unit in pairs(camp.units) do
		local rec = CreepSpawner:HibernateUnit(unit)

		if rec then
			table.insert(camp.hibernated, rec)
			camp.units[idx] = nil
			unit:RemoveSelf()
		end
	end

	CreepSpawner:SetCampHibernated(camp.name, true)
end

function CampSleep:_Restore(camp)
	local list = camp.hibernated
	if not list then return end

	-- флаги снимаем до создания: OnCreepSpawned не должен снова усыплять
	camp.hibernated = nil
	CreepSpawner:SetCampHibernated(camp.name, false)

	for _, rec in ipairs(list) do
		CreepSpawner:RestoreHibernatedUnit(rec)
	end
end

-- убираем из учёта мёртвых и удалённых, возвращаем сколько живых осталось
function CampSleep:_Prune(camp)
	local alive = 0

	for idx, unit in pairs(camp.units) do
		if not unit or unit:IsNull() or not unit:IsAlive() then
			camp.units[idx] = nil
		else
			alive = alive + 1
		end
	end

	return alive
end

-- Кто будит лагеря - один поиск на всю карту за тик, а не по поиску на каждый
-- лагерь: 50 лагерей x 4 тика в секунду x радиус 3500 давали 200 тяжёлых
-- поисков в секунду, и каждый возвращал ещё и всех миньонов вокруг.
--
-- Будят только герои и то, чем управляет игрок (суммоны, задоминированные
-- крипы, иллюзии). На точке КАЖДОГО лагеря стоят служебные юниты иконок
-- миникарты (lib/minimap_spots.lua) команд Radiant и Dire - для нейтралов это
-- "враги рядом", поэтому юниты без владельца не считаются. Здания и варды не
-- ищем: варды будят лагерь через обзор (_IsCampVisible).
function CampSleep:_CollectWakers()
	local units = FindUnitsInRadius(
		DOTA_TEAM_NEUTRALS,
		Vector(0, 0, 0),
		nil,
		FIND_UNITS_EVERYWHERE,
		DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_INVULNERABLE + DOTA_UNIT_TARGET_FLAG_OUT_OF_WORLD + DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES,
		FIND_ANY_ORDER,
		false
	)

	local points = {}

	for _, unit in pairs(units) do
		if unit:IsHero() or unit:GetPlayerOwnerID() >= 0 then
			local p = unit:GetAbsOrigin()
			points[#points + 1] = p
		end
	end

	return points
end

function CampSleep:_HasOutsidersNear(camp, wakers)
	if not camp.pos then return true end

	local cx, cy = camp.pos.x, camp.pos.y
	local r2 = WAKE_RADIUS * WAKE_RADIUS

	for i = 1, #wakers do
		local dx = wakers[i].x - cx
		local dy = wakers[i].y - cy

		if dx * dx + dy * dy <= r2 then return true end
	end

	return false
end

function CampSleep:_Sleep(unit, camp)
	if unit._aa_asleep then return end
	if not unit.SetAcquisitionRange then return end

	-- уведённого от лагеря не трогаем: он в работе у игрока
	if camp.pos and (unit:GetAbsOrigin() - camp.pos):Length2D() > LEASH then return end

	if unit._aa_acq == nil then
		unit._aa_acq = unit.GetAcquisitionRange and unit:GetAcquisitionRange() or 0
	end

	unit:SetAcquisitionRange(0)
	unit._aa_asleep = true
end

function CampSleep:_Wake(unit)
	if not unit or unit:IsNull() then return end
	if not unit._aa_asleep then return end
	if not unit.SetAcquisitionRange then return end

	-- если исходного значения нет (не должно случаться), ставим дефолт нейтрала
	unit:SetAcquisitionRange(unit._aa_acq or 500)
	unit._aa_asleep = false
end
