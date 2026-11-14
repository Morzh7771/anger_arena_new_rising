require("lib/boss/boss_class")
require("lib/spawners/camp_respawn_ring")
require("lib/boss/tormentor_gates")

local TORMENTOR_UNIT = "npc_dota_miniboss_aa"

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
	end
end