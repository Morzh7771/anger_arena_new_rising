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
local WAKE_RADIUS = 2000

-- Как часто проверяем. 50 лагерей * 2 раза в секунду = 100 поисков в секунду,
-- против 480 юнитов, которые ищут цель каждый сам за себя.
local TICK = 0.5

-- Крип дальше этого расстояния от точки спавна считается уведённым и не спит.
local LEASH = 900

local TIMER_NAME = "CampSleepTick"

CampSleep._enabled = true

function CampSleep:Init()
	if self._inited then return end

	self._inited = true
	self._camps = self._camps or {}

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
		camp = { pos = spawner_info.pos, units = {}, asleep = false }
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

function CampSleep:_Tick()
	if not self._enabled then return end

	for name, camp in pairs(self._camps) do
		local alive = self:_Prune(camp)

		if alive == 0 then
			self._camps[name] = nil
		else
			local shouldSleep = not self:_HasOutsidersNear(camp)

			if shouldSleep ~= camp.asleep then
				camp.asleep = shouldSleep

				for _, unit in pairs(camp.units) do
					if shouldSleep then
						self:_Sleep(unit, camp)
					else
						self:_Wake(unit)
					end
				end
			end
		end
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

function CampSleep:_HasOutsidersNear(camp)
	if not camp.pos then return true end

	-- Ищем героев и обычных юнитов (суммоны, задоминированные крипы), но НЕ
	-- здания: часть лагерей стоит в двух тысячах от вышки, и с
	-- DOTA_UNIT_TARGET_ALL такой лагерь не заснул бы никогда.
	local near = FindUnitsInRadius(
		DOTA_TEAM_NEUTRALS,
		camp.pos,
		nil,
		WAKE_RADIUS,
		DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_INVULNERABLE + DOTA_UNIT_TARGET_FLAG_OUT_OF_WORLD + DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES,
		FIND_ANY_ORDER,
		false
	)

	return #near > 0
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
