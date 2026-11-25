require("lib/boss/boss_class")
require("lib/spawners/camp_respawn_ring")
require("lib/boss/tormentor_gates")

local TORMENTOR_UNIT = "npc_dota_miniboss_aa"

-- ротация: канал телепорта и как часто проверяем, пора ли
local ROTATION_CHANNEL = 5
local ROTATION_TICK = 1

local function IsTormentor(boss)
	return boss.unitName == TORMENTOR_UNIT
end

BossSpawner = BossSpawner or class({})

local CONFIG_PATH = "scripts/npc/boss_spawners.kv"

-- круг респавна на точке убитого босса; босс крупнее кемпа, круг тоже
local RESPAWN_RING_RADIUS = 300

local function RingName(boss)
	return "boss_" .. boss.name
end

function BossSpawner:Init()
	if self.inited then return end

	self.bossClasses = self.bossClasses or {}
	self.bossCurrent = self.bossCurrent or {}
	self.currentSpawning = self.currentSpawning or {}

	self.inited = false

	local data = LoadKeyValues(CONFIG_PATH)

	if not data then 
		print("[BossSpawner] Failed to parse config", CONFIG_PATH)
		return
	end

	for bossName, bossData in pairs(data) do
		local boss = BossClass:Create(bossName, bossData, data)

		if not boss then 
			return
		end

		local oldBoss = self.bossClasses[bossName]

		self.bossClasses[bossName] = boss

		if oldBoss then
			boss.unit = oldBoss.unit
		end
	end

	LinkLuaModifier("modifier_boss_power", 'lib/boss/modifier_boss_power', LUA_MODIFIER_MOTION_NONE)
	LinkLuaModifier("modifier_boss_cast_alert", 'lib/boss/modifier_boss_cast_alert', LUA_MODIFIER_MOTION_NONE)
	LinkLuaModifier("modifier_boss_rotation", 'lib/boss/modifier_boss_rotation', LUA_MODIFIER_MOTION_NONE)
	LinkLuaModifier("modifier_boss_true_sight", 'lib/boss/modifier_boss_true_sight', LUA_MODIFIER_MOTION_NONE)

	-- группы ротации: боссы с одним набором точек
	self.rotationGroups = {}
	for _, boss in pairs(self.bossClasses) do
		if boss.rotation then
			local key = boss.rotation.group
			self.rotationGroups[key] = self.rotationGroups[key] or { bosses = {} }
			table.insert(self.rotationGroups[key].bosses, boss)
		end
	end

	-- боссов в группе не больше, чем точек, и стартовые точки разные -
	-- иначе на одном споте окажутся двое
	for key, group in pairs(self.rotationGroups) do
		local start = {}
		for _, b in pairs(group.bosses) do
			if start[b.pointName] then
				print("[BossSpawner] ОШИБКА КОНФИГА: у", b.name, "и", start[b.pointName], "одна стартовая точка", b.pointName)
			end
			start[b.pointName] = b.name
		end
		if #group.bosses > #group.bosses[1].rotation.points then
			print("[BossSpawner] ОШИБКА КОНФИГА: в ротации", key, "боссов больше, чем точек")
		end
	end

	self.inited = true
end

function BossSpawner:ForBossClass(functor)
	for _, boss in pairs(self.bossClasses) do
		if functor(boss) then return end
	end
end

function BossSpawner:OnGameStart()
	if not self.inited then return end

	for _, boss in pairs(self.bossClasses) do
		if IsTormentor(boss) then
			TormentorGates:Create(boss.name, boss.point)
		end
		self:CheckSpawn(boss, true)
	end

	if next(self.rotationGroups or {}) then
		Timers:CreateTimer(ROTATION_TICK, function()
			self:_RotationTick()
			return ROTATION_TICK
		end)
	end
end

function BossSpawner:CheckSpawn(boss, firstTime)
	local spawnDelay
	local minDelay, maxDelay

	if firstTime then
		spawnDelay = boss:GetInitialSpawnDelay()
		minDelay, maxDelay = spawnDelay, spawnDelay
	else
		spawnDelay = boss:GetSpawnTime()
		minDelay, maxDelay = boss:GetSpawnTimeRange()
	end

	local wasTimer = self.currentSpawning[boss]
	
	if wasTimer then
		Timers:RemoveTimer(wasTimer)
		print("[BossSpawner] Boss", boss.name, "spawning canceled because have new request for spawntime")
	end

	print("[BossSpawner] Boss", boss.name, "spawning after", spawnDelay, "seconds")
	print(spawnDelay)

	-- ротация: встанет там, где по сетке будет стоять к максимальному времени
	if not firstTime and boss.rotation then
		boss:SetRotationIndex(boss:RotationTarget(GameRules:GetDOTATime(false, false) + maxDelay))
	end

	-- премиум: точное время респавна (lib/boss_timers_premium.lua)
	if AABossTimers then pcall(AABossTimers.Scheduled, AABossTimers, boss.name, boss.point, spawnDelay) end

	-- После смерти на точке встаёт серый круг. Время респавна у босса
	-- случайное, поэтому часы идут до максимального, а жёлтая дуга - от
	-- минимального: заливка дошла до дуги - босс может встать в любой момент,
	-- круг полный - он точно стоит. До первого спавна круга нет.
	if not firstTime then
		local windowFrom = maxDelay > 0 and minDelay / maxDelay or nil

		CampRespawnRing:Start(RingName(boss), boss.point, maxDelay, RESPAWN_RING_RADIUS, windowFrom)
	end

	self:_ScheduleGuaranteed(boss, maxDelay)

	local timer = Timers:CreateTimer( spawnDelay, function()
		self:_RemoveTimer(boss, true)
		self:SpawnBoss(boss)
	end)

	self.currentSpawning[boss] = timer
end

function BossSpawner:_RemoveTimer(boss)
	local wasTimer = self.currentSpawning[boss]
	
	if wasTimer then
		Timers:RemoveTimer(wasTimer)

		self.currentSpawning[boss] = nil
	end
end

-- К максимальному времени респавна босс стоит точно: иконка на миникарте
-- загорается всем. До этого её видит только команда, которая сама видела
-- босса живым (lib/minimap_spots.lua).
function BossSpawner:_ScheduleGuaranteed(boss, delay)
	self.guaranteeTimers = self.guaranteeTimers or {}

	local old = self.guaranteeTimers[boss]

	if old then
		Timers:RemoveTimer(old)
	end

	self.guaranteeTimers[boss] = Timers:CreateTimer(delay, function()
		self.guaranteeTimers[boss] = nil

		if MinimapSpots then MinimapSpots:OnBossGuaranteed(boss.name) end
	end)
end

function BossSpawner:SpawnBoss(boss)
	self:_RemoveTimer(boss, true)

	-- круг вспыхивает и уходит ровно на появлении босса
	CampRespawnRing:Stop(RingName(boss))

	-- спот занят живым напарником (его переход задержали боем) - встаём на
	-- свободный, ротация потом разведёт по сетке
	-- Встаёт посреди канала телепорта пары - канал сбиваем: иначе он выбрал
	-- бы как свободную точку ту, куда сейчас прилетит напарник. Пара
	-- переедет заново, когда снова будет 30 с тишины.
	if boss.rotation then
		self:_CancelRotation(boss)
		self:_FreeRotationSpot(boss)
	end

	-- случайный юнит из пула, не тот, что сейчас стоит у напарника
	if boss.unitPool then boss:SetUnitName(self:_PickPoolUnit(boss)) end

	local unit = boss:Spawn()

	if AABossTimers then pcall(AABossTimers.Spawned, AABossTimers, boss.name) end

	-- имя конфига (miniboss_radiant / miniboss_dire): по нему торментор
	-- выбирает цвет партиклов
	unit.aa_boss_name = boss.name

	if IsTormentor(boss) then
		TormentorGates:Open(boss.name)

		-- Здоровье из конфига у торментора - это прочность его щита
		-- (механика 1х6), а настоящего ХП у него 1.
		local hp = unit:GetMaxHealth()
		local shield = unit:FindModifierByName("modifier_tormentor_unyielding_shielda_aa")
		if shield and shield.SetMaxShield and hp > 1 then
			shield:SetMaxShield(hp)
			unit:SetBaseMaxHealth(1)
			unit:SetMaxHealth(1)
			unit:SetHealth(1)
		end
	end

	unit:AddNewModifier(unit, nil, "modifier_boss_power", { duration = -1 })

	if not IsTormentor(boss) then
		unit:AddNewModifier(unit, nil, "modifier_boss_cast_alert", { duration = -1 })
	end

	-- видит невидимых, как с гемом
	unit:AddNewModifier(unit, nil, "modifier_boss_true_sight", { duration = -1 })

	-- сколько раз уже убили этот слот: от этого растут скиллы (BossKit:Deaths)
	unit.aa_boss_deaths = boss.deathCount + 1

	-- после спавна ротация ждёт обычные rotation_quiet секунд
	boss.lastDamageTime = GameRules:GetGameTime()

	unit.IsAngelArenaBoss = true
	
	self.bossCurrent[unit] = boss
	self.currentSpawning[boss] = nil
end

function BossSpawner:IsBoss(unit)
	if not unit then return nil end
	
	return unit.IsAngelArenaBoss
end

function BossSpawner:GetDeathCount(bossName)
	local bossClass = self.bossClasses[bossName]

	if not bossClass then
		return false
	end

	return bossClass:GetDeathCount()	
end

function BossSpawner:IsBossAlive(bossName)
	local bossClass = self.bossClasses[bossName]

	if not bossClass then
		return false
	end

	local unit = bossClass.unit

	if not unit then
		return false
	end

	return unit:IsAlive()
end

function BossSpawner:HandleUnitKill(unit, killer)
	if not unit.IsAngelArenaBoss then
		return false
	end

	local boss = self.bossCurrent[unit]

	if not boss then 
		print("[BossSpawner] Failed to handle unit, unit is boss but he doesn't not contains in boss table, unit is", unit:GetUnitName())
		return 
	end

	self.bossCurrent[unit] = nil

	if IsTormentor(boss) then
		TormentorGates:Close(boss.name)
	end

	boss:OnDeath( killer:GetTeamNumber(),killer )

	self:CheckSpawn(boss, false)

	return true
end

-- зовёт modifier_boss_power на каждый урон по боссу
function BossSpawner:OnBossDamaged(unit, attacker)
	local boss = self.bossCurrent[unit]

	if boss then
		boss:OnDamaged(attacker)

		if attacker and not attacker:IsNull() and attacker.GetTeamNumber
			and attacker:GetTeamNumber() ~= unit:GetTeamNumber() then
			boss.lastDamageTime = GameRules:GetGameTime()
			self:_CancelRotation(boss)
		end
	end
end

--------------------------------------------------------------------------------
-- Ротация. Раз в ROTATION_TICK смотрим каждую группу: если кто-то из живых
-- стоит не на своей точке по сетке, а всю группу rotation_quiet секунд никто
-- не бил, - канал телепорта ROTATION_CHANNEL секунд, потом все меняются.
-- Удар по любому из группы сбивает канал. Сетка общая, поэтому задержанный
-- переход не сдвигает следующий: на 15:00 босс всё равно пойдёт назад.
--------------------------------------------------------------------------------
local function Alive(boss)
	local u = boss.unit
	return u and not u:IsNull() and u:IsAlive()
end

function BossSpawner:_RotationTick()
	local now = GameRules:GetDOTATime(false, false)
	local game = GameRules:GetGameTime()

	for _, group in pairs(self.rotationGroups) do
		if not group.channel then
			local movers, blocked = {}, false

			for _, boss in pairs(group.bosses) do
				if Alive(boss) then
					local target = boss:RotationTarget(now)
					if target ~= boss.rotationIndex then
						table.insert(movers, { boss = boss, index = target })
					end
					if game - (boss.lastDamageTime or 0) < boss.rotation.quiet then blocked = true end
					-- лежит под реинкарнацией - не трогаем
					if boss.unit:HasModifier("modifier_leoric_fallen") then blocked = true end
				end
			end

			if #movers > 0 and not blocked then
				self:_StartRotation(group, movers)
			end
		end

		self:_FixCollisions(group)
	end
end

-- Кто из живых какую точку занимает (имя точки -> босс).
function BossSpawner:_Occupied(group)
	local res = {}
	for _, b in pairs(group.bosses) do
		if Alive(b) then
			if res[b.pointName] then return res, b end  -- второй на той же точке
			res[b.pointName] = b
		end
	end
	return res
end

-- Страховка: если всё-таки двое живых стоят на одной точке, второго сразу
-- (без канала) переносим на свободную. Сюда не должно попадать - пишем в лог.
function BossSpawner:_FixCollisions(group)
	if group.channel then return end
	local occupied, extra = self:_Occupied(group)
	if not extra then return end

	for i, pt in ipairs(extra.rotation.points) do
		if not occupied[pt.name] then
			print("[BossSpawner] два босса на точке", extra.pointName, "- переношу", extra.name, "на", pt.name)
			local from = extra.point
			self:_TeleportBoss(extra, i, from)
			return
		end
	end
end

function BossSpawner:_TeleportBoss(boss, index, from)
	local unit = boss.unit
	boss:SetRotationIndex(index)

	-- тень Хранителя и прочие откаты не должны вернуть его назад
	unit.aa_rotated_at = GameRules:GetGameTime()

	FindClearSpaceForUnit(unit, boss.point, true)
	unit:SetForwardVector(boss.forward)
	unit:Stop()

	if unit.aa_simple_ai then unit.aa_simple_ai.spawnPos = boss.point end

	-- свита (волки Ликана) идёт следом
	for _, w in pairs(unit.aa_wolves or {}) do
		if w and not w:IsNull() and w:IsAlive() then
			FindClearSpaceForUnit(w, boss.point + RandomVector(150), true)
			w:Stop()
		end
	end

	unit:EmitSound("Portal.Hero_Appear")

	if MinimapSpots and MinimapSpots.OnBossMoved then
		pcall(MinimapSpots.OnBossMoved, MinimapSpots, from, boss.point)
	end
end

function BossSpawner:_PickPoolUnit(boss)
	local busy = {}
	local group = boss.rotation and self.rotationGroups and self.rotationGroups[boss.rotation.group]
	for _, other in pairs(group and group.bosses or {}) do
		if other ~= boss and Alive(other) then busy[other.unit:GetUnitName()] = true end
	end

	local free = {}
	for _, u in pairs(boss.unitPool) do
		if not busy[u] then table.insert(free, u) end
	end
	if #free == 0 then free = boss.unitPool end

	return free[RandomInt(1, #free)]
end

function BossSpawner:_FreeRotationSpot(boss)
	local group = self.rotationGroups and self.rotationGroups[boss.rotation.group]
	if not group then return end

	-- Сравниваем по имени точки: порядок rotation_points у каждого босса
	-- свой (у Леорика первая - свет, у Жнеца - тьма), номер точки одного
	-- босса ничего не значит для другого. По номерам Жнец уходил к Леорику.
	local taken = {}
	for _, other in pairs(group.bosses) do
		if other ~= boss and Alive(other) then taken[other.pointName] = true end
	end
	if not taken[boss.pointName] then return end

	for i, pt in ipairs(boss.rotation.points) do
		if not taken[pt.name] then
			boss:SetRotationIndex(i)
			return
		end
	end
end

-- тест (aa_boss_rotate): сдвинуть сетку на шаг, будто прошло 5 минут
function BossSpawner:ShiftRotation()
	self.rotationShift = (self.rotationShift or 0) + 1
	-- тишина тоже считается заново от команды, бой по-прежнему её сбивает
	for _, group in pairs(self.rotationGroups or {}) do
		for _, boss in pairs(group.bosses) do boss.lastDamageTime = 0 end
	end
end

function BossSpawner:RotationInfo()
	local now = GameRules:GetDOTATime(false, false)
	local game = GameRules:GetGameTime()
	local res = {}
	for key, group in pairs(self.rotationGroups or {}) do
		for _, boss in pairs(group.bosses) do
			table.insert(res, string.format("%s: alive=%s at=%s target=%s quiet=%.0f channel=%s",
				boss.name, tostring(Alive(boss) and true or false), tostring(boss.pointName),
				tostring(boss.rotation.points[boss:RotationTarget(now)].name),
				game - (boss.lastDamageTime or 0), tostring(group.channel ~= nil)))
		end
	end
	return res
end

function BossSpawner:_StartRotation(group, movers)
	-- Проверка итога: после переезда никакие двое живых не должны оказаться
	-- на одной точке (уезжающие освобождают свои). Иначе не едем вовсе.
	local final = {}
	for _, b in pairs(group.bosses) do
		if Alive(b) then final[b] = b.pointName end
	end
	for _, m in pairs(movers) do
		final[m.boss] = m.boss.rotation.points[m.index].name
	end
	local seen = {}
	for _, name in pairs(final) do
		if seen[name] then return end
		seen[name] = true
	end

	group.channel = { movers = movers }

	for _, m in pairs(movers) do
		local dest = m.boss.rotation.points[m.index].pos
		m.boss.unit:AddNewModifier(m.boss.unit, nil, "modifier_boss_rotation", {
			duration = ROTATION_CHANNEL + 0.1, x = dest.x, y = dest.y, z = dest.z,
		})
	end

	group.channel.timer = Timers:CreateTimer(ROTATION_CHANNEL, function()
		self:_FinishRotation(group)
	end)
end

function BossSpawner:_CancelRotation(boss)
	if not boss.rotation then return end
	local group = self.rotationGroups and self.rotationGroups[boss.rotation.group]
	if not group or not group.channel then return end

	Timers:RemoveTimer(group.channel.timer)

	for _, m in pairs(group.channel.movers) do
		if Alive(m.boss) then m.boss.unit:RemoveModifierByName("modifier_boss_rotation") end
	end

	group.channel = nil
end

function BossSpawner:_FinishRotation(group)
	local channel = group.channel
	group.channel = nil
	if not channel then return end

	for _, m in pairs(channel.movers) do
		local boss = m.boss

		if Alive(boss) then
			boss.unit:RemoveModifierByName("modifier_boss_rotation")
			self:_TeleportBoss(boss, m.index, boss.point)
		end
	end
end
