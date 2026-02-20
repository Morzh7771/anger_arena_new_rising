--[[
 Creep Spawner System. Causer - CryDeS

 UPDATED:
 1) Random respawn per spawner after FULL camp clear:
    - When the last creep on a camp dies -> schedule next spawn in random time [30..60] seconds
    - When timer fires:
        * if camp is BLOCKED (hero/ward/unit inside trigger) -> DO NOT SPAWN, schedule AGAIN [30..60]
        * if camp is UNBLOCKED -> spawn

 2) Camp stacking system (WAVE-BASED, YOUR RULES):
    - Each spawned pack is a "wave" (waveId).
    - waveCount (stack count) = number of ACTIVE waves (wave alive > 0).
      Wave stays active as long as at least 1 creep of that wave is alive.
    - Every 60 seconds, if waveCount < 3 and there is at least 1 creep on camp AND camp not blocked:
        roll 25% chance -> spawn ONE additional wave (pack).
    - If waveCount == 3 -> stacking stops.
    - If any wave dies completely -> waveCount decreases -> stacking can resume.

 3) "touched/untouched" here means CAMP BLOCKED STATUS:
    - blocked = spawnbox has any valid unit (hero/creep/ward/allowed "other")
    - unblocked = empty
]]

CreepSpawner = CreepSpawner or class({})

LinkLuaModifier("modifier_dominate_protection", 'lib/spawners/modifier_dominate_protection', LUA_MODIFIER_MOTION_NONE)

require("lib/timers")

local DEBUG = IsInToolsMode()
local FORCE_DEBUG = false
local CONFIG_PATH = "scripts/npc/creep_spawners.kv"
local CHANCE_ELITE = 10

local CREEP_SPAWN_TIME = 60 -- kept for compatibility
local CREEP_RANDOM_OFFSET = 50

local SPAWN_DELAY_PER_UNIT = 0.005
local SPAWN_DELAY_LIMIT = 0.25

-- per-spawner respawn delay after full clear
local RESPAWN_MIN = 30
local RESPAWN_MAX = 60

-- stacking config
local STACK_INTERVAL = 60
local STACK_CHANCE = 25
local STACK_MAX = 3

-------------------------------------------- HELPERS ----------------------------------------------------------------

local function TableCount(t)
	local c = 0
	for _, _ in pairs(t) do c = c + 1 end
	return c
end

function emptyFunc(...) end

-------------------------------------------- PUBLIC -----------------------------------------------------------------

function CreepSpawner:Init()
	self.onSpawnCallbacks = {}
	self.onDeathCallbacks = {}

	self.spawnTime = CREEP_SPAWN_TIME
	self.spawnEnabled = true

	self.spawners, self.creepCount = self:_parseSpawners(CONFIG_PATH)

	if DEBUG then self.preacachedCount = 0 end

	-- "blocked" map via triggers (spawnbox style)
	-- _spawnerCounts[name][unit] = true if unit is inside the camp trigger
	self._spawnerCounts = self._spawnerCounts or {}

	-- total alive per camp
	self._spawnerAlive = self._spawnerAlive or {}

	-- respawn timer flags (avoid multiple timers)
	self._spawnerRespawnTimer = self._spawnerRespawnTimer or {}

	-- spawner_info lookup
	self._spawnerInfoByName = self._spawnerInfoByName or {}

	-- entindex -> { spawnerName=..., waveId=... }
	self._unitMetaByEntindex = self._unitMetaByEntindex or {}

	-- waves per spawner:
	-- _spawnerWaves[name] = { [waveId] = { alive=int, expected=int } }
	self._spawnerWaves = self._spawnerWaves or {}
	self._spawnerNextWaveId = self._spawnerNextWaveId or {}

	-- stack timer state
	self._spawnerStackTimerActive = self._spawnerStackTimerActive or {}

	self:StopSpawning()

	for spawner_info, creeps in pairs(self.spawners) do
		for _, creepname in pairs(creeps) do
			if DEBUG then
				PrecacheUnitByNameAsync(creepname, function(...)
					self.preacachedCount = self.preacachedCount + 1
					if FORCE_DEBUG then
						print("Precached unit ", creepname, tostring(self.preacachedCount) .. "/" .. tostring(self.creepCount))
					end
				end)
			else
				PrecacheUnitByNameAsync(creepname, emptyFunc)
			end
		end

		local name = spawner_info.name

		self._spawnerCounts[name] = self._spawnerCounts[name] or {}
		self._spawnerAlive[name] = self._spawnerAlive[name] or 0
		self._spawnerRespawnTimer[name] = self._spawnerRespawnTimer[name] or false

		self._spawnerInfoByName[name] = spawner_info

		self._spawnerWaves[name] = self._spawnerWaves[name] or {}
		self._spawnerNextWaveId[name] = self._spawnerNextWaveId[name] or 0

		self._spawnerStackTimerActive[name] = self._spawnerStackTimerActive[name] or false
	end

	-- Listen for deaths of spawned creeps (registered once)
	if not self._deathListenerRegistered then
		self._deathListenerRegistered = true

		ListenToGameEvent("entity_killed", function(event)
			local entindex = event and event.entindex_killed
			if not entindex then return end

			local meta = self._unitMetaByEntindex[entindex]
			if not meta then return end

			local killed = EntIndexToHScript(entindex)
			self:_OnCreepKilled(entindex, meta.spawnerName, meta.waveId, killed)
		end, nil)
	end
end

function CreepSpawner:StartSpawning()
	self:SpawnCreeps()
end

function CreepSpawner:StopSpawning()
	Timers:RemoveTimer("CreepSpawner")

	if self.spawners then
		for spawner_info, _ in pairs(self.spawners) do
			local name = spawner_info.name
			Timers:RemoveTimer("CreepSpawnerRespawn_" .. name)
			Timers:RemoveTimer("CreepSpawnerStack_" .. name)
			self._spawnerRespawnTimer[name] = false
			self._spawnerStackTimerActive[name] = false
		end
	end
end

function CreepSpawner:SetEnable(bVal) self.spawnEnabled = bVal end
function CreepSpawner:GetEnable() return self.spawnEnabled end

-- initial spawn for camps that are empty
function CreepSpawner:SpawnCreeps()
	if not self.spawnEnabled then return end

	for spawner_info, _ in pairs(self.spawners) do
		local name = spawner_info.name
		if (self._spawnerAlive[name] or 0) <= 0 then
			self:_SpawnFreshCamp(spawner_info)
		end
	end
end

function CreepSpawner:RegisterOnSpawnCallback(func) table.insert(self.onSpawnCallbacks, func) end
function CreepSpawner:UnregisterOnSpawnCallback(func) table.remove(self.onSpawnCallbacks, func) end

function CreepSpawner:RegisterOnDeathCallback(func) table.insert(self.onDeathCallbacks, func) end
function CreepSpawner:UnregisterOnDeathCallback(func) table.remove(self.onDeathCallbacks, func) end

-------------------------------------------- PRIVATE -----------------------------------------------------------------

function CreepSpawner:_parseSpawners(sSettingsFile)
	local temp = LoadKeyValues(sSettingsFile)
	local ret = {}

	local creepCount = 0

	for spawner_name, spawner_table in pairs(temp) do
		local entity = Entities:FindByName(nil, spawner_name)

		if not entity then
			print("Failed to parse point, there is not point on map, point =", spawner_name)
		else
			local spawner_info = {
				name = spawner_name,
				pos = entity:GetAbsOrigin(),
				direction = entity:GetForwardVector(),
				spawner_type = spawner_table["type"]
			}

			local creeps = spawner_table["creeps"]
			ret[spawner_info] = creeps

			for _, _ in pairs(creeps) do
				creepCount = creepCount + 1
			end
		end
	end

	return ret, creepCount
end

function CreepSpawner:_notifyCallbackList(callback_list, arg_kv)
	for _, callback in pairs(callback_list) do
		xpcall(function()
			callback(arg_kv)
		end, function(msg)
			print("Error notify callback in CreepSpawner:_notifyCallbacks + \n" .. msg .. " traceback:\n" .. debug.traceback())
		end)
	end
end

-- camp is blocked if any valid unit is in spawnbox map
function CreepSpawner:_IsCampBlocked(spawnerName)
	local t = self._spawnerCounts[spawnerName]
	if not t then return false end

	for unit, _ in pairs(t) do
		if unit and not unit:IsNull() and unit.IsAlive and unit:IsAlive() then
			return true
		end
	end
	return false
end

-- time multiplier: +1 pack each 25 minutes (kept from your old idea)
function CreepSpawner:_GetPackMultiplier()
	local time_min = GameRules:GetDOTATime(false, false) / 60
	return math.floor(time_min / 25) + 1
end

function CreepSpawner:_GetActiveWaveCount(spawnerName)
	local waves = self._spawnerWaves[spawnerName]
	if not waves then return 0 end

	local c = 0
	for _, w in pairs(waves) do
		if w and w.alive and w.alive > 0 then
			c = c + 1
		end
	end
	return c
end

function CreepSpawner:_ResetCampState(spawnerName)
	self._spawnerWaves[spawnerName] = {}
	self._spawnerAlive[spawnerName] = 0

	Timers:RemoveTimer("CreepSpawnerStack_" .. spawnerName)
	self._spawnerStackTimerActive[spawnerName] = false
end

-- Stack timer:
-- does NOT spawn if camp blocked; just waits next tick
function CreepSpawner:_EnsureStackTimer(spawner_info)
	local name = spawner_info.name
	if self._spawnerStackTimerActive[name] then return end

	self._spawnerStackTimerActive[name] = true

	Timers:CreateTimer("CreepSpawnerStack_" .. name, {
		useGameTime = true,
		endTime = STACK_INTERVAL,
		callback = function()
			if not self.spawnEnabled then
				self._spawnerStackTimerActive[name] = false
				return nil
			end

			local totalAlive = self._spawnerAlive[name] or 0
			if totalAlive <= 0 then
				self._spawnerStackTimerActive[name] = false
				return nil
			end

			local waveCount = self:_GetActiveWaveCount(name)
			if waveCount >= STACK_MAX then
				self._spawnerStackTimerActive[name] = false
				return nil
			end

			-- if camp blocked -> do nothing now, wait next minute
			if self:_IsCampBlocked(name) then
				return STACK_INTERVAL
			end

			if RandomInt(1, 100) <= STACK_CHANCE then
				self:_SpawnExtraWave(spawner_info)
			end

			return STACK_INTERVAL
		end
	})
end

-- Respawn timer after full clear:
-- if blocked at fire moment -> schedule AGAIN 30..60 (no instant spawn)
function CreepSpawner:_ScheduleRespawn(spawner_info)
	local name = spawner_info.name

	if not self.spawnEnabled then return end
	if self._spawnerRespawnTimer[name] then return end

	self._spawnerRespawnTimer[name] = true
	local delay = RandomFloat(RESPAWN_MIN, RESPAWN_MAX)

	Timers:CreateTimer("CreepSpawnerRespawn_" .. name, {
		useGameTime = true,
		endTime = delay,
		callback = function()
			self._spawnerRespawnTimer[name] = false

			if not self.spawnEnabled then return nil end
			if (self._spawnerAlive[name] or 0) > 0 then return nil end

			-- BLOCK CHECK HERE
			if self:_IsCampBlocked(name) then
				-- blocked -> re-roll new timer 30..60
				self:_ScheduleRespawn(spawner_info)
				return nil
			end

			-- unblocked -> spawn
			self:_SpawnFreshCamp(spawner_info)
			return nil
		end
	})
end

-- Creates wave record and returns waveId
function CreepSpawner:_CreateNewWave(spawner_info)
	local name = spawner_info.name
	self._spawnerNextWaveId[name] = (self._spawnerNextWaveId[name] or 0) + 1
	local waveId = self._spawnerNextWaveId[name]

	local creep_names = self.spawners[spawner_info]
	if not creep_names then return nil end

	local mult = self:_GetPackMultiplier()
	local baseCount = TableCount(creep_names)
	local expected = baseCount * mult

	self._spawnerWaves[name][waveId] = {
		alive = expected,
		expected = expected
	}

	return waveId
end

function CreepSpawner:_SpawnWaveUnits(spawner_info, waveId)
	local name = spawner_info.name
	local base_spawner_pos = spawner_info.pos
	local spawner_dir = spawner_info.direction

	local creep_names = self.spawners[spawner_info]
	if not creep_names then return end

	local mult = self:_GetPackMultiplier()
	local spawnDelay = 0.0

	for _, creep_name in pairs(creep_names) do
		local offset = RandomVector(CREEP_RANDOM_OFFSET)
		local spawner_pos = base_spawner_pos + offset

		spawnDelay = spawnDelay + SPAWN_DELAY_PER_UNIT
		if spawnDelay > SPAWN_DELAY_LIMIT then
			spawnDelay = SPAWN_DELAY_LIMIT
		end

		Timers:CreateTimer(spawnDelay, function()
			if not self.spawnEnabled then return nil end

			local elite = false

			for i = 1, mult do
				local time_min = GameRules:GetDOTATime(false, false) / 60
				if time_min > 0.10 and RandomInt(0, 100) < CHANCE_ELITE then
					elite = true
				end

				local creep = CreateUnitByName(creep_name, spawner_pos, true, nil, nil, DOTA_TEAM_NEUTRALS)
				if not creep then
					print("Error handled, no unit with name", creep_name, " exists. Trying to spawn it on spawner ", name)
					return nil
				end

				creep:SetForwardVector(spawner_dir)
				creep:Stop()

				self._spawnerAlive[name] = (self._spawnerAlive[name] or 0) + 1

				local idx = creep:GetEntityIndex()
				self._unitMetaByEntindex[idx] = { spawnerName = name, waveId = waveId }

				-- NOTE: comment if modifier missing in your project
				creep:AddNewModifier(creep, nil, "modifier_dominate_protection", { duration = -1 })

				creep.spawner_info = spawner_info
				self:_notifyCallbackList(self.onSpawnCallbacks, { creep = creep, spawner_info = spawner_info, elite = elite })
			end

			return nil
		end)
	end
end

function CreepSpawner:_SpawnFreshCamp(spawner_info)
	local name = spawner_info.name

	-- reset camp state
	self:_ResetCampState(name)

	-- create and spawn first wave
	local waveId = self:_CreateNewWave(spawner_info)
	if not waveId then return end

	self:_SpawnWaveUnits(spawner_info, waveId)

	-- start stacking timer
	self:_EnsureStackTimer(spawner_info)
end

function CreepSpawner:_SpawnExtraWave(spawner_info)
	local name = spawner_info.name

	local waveCount = self:_GetActiveWaveCount(name)
	if waveCount >= STACK_MAX then return end

	-- do not stack spawn while camp blocked
	if self:_IsCampBlocked(name) then return end

	local waveId = self:_CreateNewWave(spawner_info)
	if not waveId then return end

	self:_SpawnWaveUnits(spawner_info, waveId)
end

function CreepSpawner:_OnCreepKilled(entindex, spawnerName, waveId, unit)
	self._unitMetaByEntindex[entindex] = nil

	-- total alive--
	local beforeTotal = self._spawnerAlive[spawnerName] or 0
	self._spawnerAlive[spawnerName] = math.max(0, beforeTotal - 1)

	-- wave alive--
	local waves = self._spawnerWaves[spawnerName]
	local w = waves and waves[waveId] or nil
	if w then
		w.alive = math.max(0, (w.alive or 0) - 1)

		if w.alive <= 0 then
			waves[waveId] = nil

			-- if now waveCount < 3 and still have creeps -> stacking can resume
			local info = self._spawnerInfoByName[spawnerName]
			if info then
				local totalAlive = self._spawnerAlive[spawnerName] or 0
				local waveCount = self:_GetActiveWaveCount(spawnerName)
				if totalAlive > 0 and waveCount > 0 and waveCount < STACK_MAX then
					self:_EnsureStackTimer(info)
				end
			end
		end
	end

	-- callbacks
	if unit then
		self:_notifyCallbackList(self.onDeathCallbacks, { creep = unit, spawner_info = unit.spawner_info })
		unit.spawner_info = nil
	end

	-- if camp fully cleared -> schedule respawn
	if (self._spawnerAlive[spawnerName] or 0) <= 0 then
		self:_ResetCampState(spawnerName)

		local spawner_info = self._spawnerInfoByName and self._spawnerInfoByName[spawnerName]
		if spawner_info then
			self:_ScheduleRespawn(spawner_info)
		end
	end
end

-------------------------------------------- TRIGGERS (spawnbox) -----------------------------------------------------

-- NOTE: these triggers must be placed/linked on map with correct names matching spawners
-- They maintain "blocked" state in self._spawnerCounts[spawnName].

local AvailableUnits = {
	["npc_dota_juggernaut_healing_ward"] = 1,
	["npc_dota_zeus_cloud"] = 1,
	["npc_dota_tusk_frozen_sigil1"] = 1,
	["npc_dota_tusk_frozen_sigil2"] = 1,
	["npc_dota_tusk_frozen_sigil3"] = 1,
	["npc_dota_tusk_frozen_sigil4"] = 1,
	["npc_dota_tusk_frozen_sigil5"] = 1,
	["npc_dota_tusk_frozen_sigil6"] = 1,
	["npc_dota_tusk_frozen_sigil7"] = 1,
	["npc_dota_observer_wards"] = 1,
	["npc_dota_sentry_wards"] = 1,
	["npc_dota_witch_doctor_death_ward"] = 1,
	["npc_dota_shadow_shaman_ward_1"] = 1,
	["npc_dota_shadow_shaman_ward_2"] = 1,
	["npc_dota_shadow_shaman_ward_3"] = 1,
	["npc_dota_shadow_shaman_ward_4"] = 1,
	["npc_dota_shadow_shaman_ward_5"] = 1,
	["npc_dota_shadow_shaman_ward_6"] = 1,
	["npc_dota_shadow_shaman_ward_7"] = 1,
	["npc_dota_venomancer_plague_ward_1"] = 1,
	["npc_dota_venomancer_plague_ward_2"] = 1,
	["npc_dota_venomancer_plague_ward_3"] = 1,
	["npc_dota_venomancer_plague_ward_4"] = 1,
	["npc_dota_venomancer_plague_ward_5"] = 1,
	["npc_dota_venomancer_plague_ward_6"] = 1,
	["npc_dota_venomancer_plague_ward_7"] = 1,
	["npc_dota_clinkz_skeleton_archer"] = 1,
	["npc_dota_unit_tombstone1"] = 1,
	["npc_dota_unit_tombstone2"] = 1,
	["npc_dota_unit_tombstone3"] = 1,
	["npc_dota_unit_tombstone4"] = 1,
	["npc_dota_unit_tombstone5"] = 1,
	["npc_dota_unit_tombstone6"] = 1,
	["npc_dota_unit_tombstone7"] = 1,
	["npc_dota_pugna_nether_ward_1"] = 1,
	["npc_dota_pugna_nether_ward_2"] = 1,
	["npc_dota_pugna_nether_ward_3"] = 1,
	["npc_dota_pugna_nether_ward_4"] = 1,
	["npc_dota_pugna_nether_ward_5"] = 1,
	["npc_dota_pugna_nether_ward_6"] = 1,
	["npc_dota_pugna_nether_ward_7"] = 1,
	["npc_dota_lich_ice_spire"] = 1,
	["npc_dota_rattletrap_cog"] = 1,
}

function CreepSpawner:_OnEnterTrigger(spawnName, trigger)
	if self._spawnerCounts[spawnName] == nil then return end
	self._spawnerCounts[spawnName][trigger] = true
end

function CreepSpawner:_OnLeaveTrigger(spawnName, trigger)
	if self._spawnerCounts[spawnName] == nil then return end
	self._spawnerCounts[spawnName][trigger] = nil
end

function creep_spawner_on_start_touch(trigger, data)
	if not trigger or not trigger.GetName then return end

	local spawnName = trigger:GetName()
	local activator = data.activator
	if not activator then return end

	if not activator.IsCreature or not activator.IsHero or not activator.IsCourier or not activator.IsOther then return end
	if activator:IsCourier() then return end

	local must = activator:IsCreature() or activator:IsCreep() or activator:IsHero() or activator:IsOther()
	if not must then return end

	if activator:IsOther() and not AvailableUnits[activator:GetUnitName()] then return end

	CreepSpawner:_OnEnterTrigger(spawnName, activator)
end

function creep_spawner_on_end_touch(trigger, data)
	if not trigger or not trigger.GetName then return end

	local spawnName = trigger:GetName()
	local activator = data.activator
	if not activator then return end

	if not activator.IsCreature or not activator.IsHero or not activator.IsCourier or not activator.IsCourier or not activator.IsOther then return end
	if activator:IsCourier() then return end

	local must = activator:IsCreature() or activator:IsCreep() or activator:IsHero() or activator:IsOther()
	if activator:IsOther() and not AvailableUnits[activator:GetUnitName()] then return end
	if not must then return end

	CreepSpawner:_OnLeaveTrigger(spawnName, activator)
end