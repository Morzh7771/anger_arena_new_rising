if not IsServer() then return end

require('lib/dropbox')
require('lib/base_lua_helpers')
local Constants = require('consts') -- XP TABLE
require('lib/random/generators')
require('lib/random/weighted_list')
require('lib/connection_helpers')

-- Configurables
local CONFIG_PATH = "scripts/npc/creep_stats.kv"
local RANDOM_GENERATOR_TYPE = "uniform"
local LOOT_RADIUS = 80
local AMPLIFY_STAT_ELITE = 1
local AMPLIFY_BOUNTY_ELITE = 1
local AMPLIFY_STAT_ELITE_HEALTH = 1
local AMPLIFY_STAT_ELITE_DAMAGE = 1
LinkLuaModifier("modifier_creep_elite", 'lib/spawners/modifier_creep_elite', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_creep_level", 'lib/spawners/modifier_creep_level', LUA_MODIFIER_MOTION_NONE)
CreepLeveling = CreepLeveling or class({})

function CreepLeveling:Init()
	if self.inited then
		return
	end

	local RAND_GEN = RandomGeneratorFactory:GetGenerator(RANDOM_GENERATOR_TYPE)

	local kv = LoadKeyValues(CONFIG_PATH)

	local base_stats = kv.base_stats
	local stats = kv.stats

	self.inited = true

	for spawner_type, spawners in pairs(stats) do
		
		merge_table(spawners, base_stats)

		for spawner_level, spawner_info in pairs(spawners) do
		--[[	local tbl = {
				hp 		= tonumber(spawner_info["hp"]),
				mp 		= tonumber(spawner_info["mp"]),
				bat 	= tonumber(spawner_info["bat"]),
				armor 	= tonumber(spawner_info["armor"]),
				dmg_max = tonumber(spawner_info["dmg_min"]) + (tonumber(spawner_info["dmg_max"]) - tonumber(spawner_info["dmg_min"])) / 2,
			}
			]]

			local drops = spawner_info['drops']

			-- после отключения старой системы нейтралок у части уровней в
			-- creep_stats.kv может не остаться ни одного бокса, тогда движок
			-- отдаёт сюда не таблицу
			if type(drops) ~= "table" then
				drops = {}
			end

			local newDrops = {}

			for key, chance in pairs(drops) do
				chance = tonumber(chance)
				local box = DropBox:GetDropbox(key)

				if box then
					table.insert(newDrops, { chance, box } )
				else
					print("[CreepLeveling] Failed to get dropbox", key, "for creep spawner", spawner_type, "for creep levels", spawner_level)
				end
			end

			spawner_info['drops'] 	 = WeightedList:Create(newDrops, RAND_GEN)

			spawner_info.hp 	  = tonumber( spawner_info.hp or "100" )
			spawner_info.mp 	  = tonumber( spawner_info.mp or "100" )
			spawner_info.bat 	  = tonumber( spawner_info.bat or "1.7" )
			
			spawner_info.armor 	  = tonumber( spawner_info.armor or "0" )
			spawner_info.dmg_min  = tonumber( spawner_info.dmg_min or "0" )
			spawner_info.dmg_max  = tonumber( spawner_info.dmg_max or "0" )

			spawner_info.exp 	  = tonumber( spawner_info.exp or "0" )
			spawner_info.gold_min = tonumber( spawner_info.gold_min or "0" )
			spawner_info.gold_max = tonumber( spawner_info.gold_max or "0" )
		end 
	end

	self.stats = stats
end 

function CreepLeveling:OnSpawnCallback( event )
	local creep 		= event.creep 
	local spawner_info 	= event.spawner_info
	local elite = event.elite

	local spawner_type 	= spawner_info.spawner_type 

	-- тип кемпа для телеметрии золота по кемпам (lib/match_telemetry.lua, camp_gold)
	creep._aa_camp = spawner_type

	local seek_spawn_info = nil
	local seek_creep_level = -1000

	local level = self:_calculateHeroesAverageLevel() 

	for creep_level, info in pairs(self.stats[spawner_type]) do
		local newSpawnLevel = tonumber(info["hero_avg_level"])
		if newSpawnLevel <= level and newSpawnLevel > seek_creep_level then
			seek_spawn_info  = info 
			seek_creep_level = newSpawnLevel
		end 
	end

	if not seek_spawn_info then
		print("[CreepLeveling] No spawn information to this level, level = " .. tostring( level ))
		return 
	end 
	
	AMPLIFY_STAT_ELITE = 1
	AMPLIFY_BOUNTY_ELITE = 1
	AMPLIFY_STAT_ELITE_HEALTH = 1
	AMPLIFY_STAT_ELITE_DAMAGE = 1
	creep._leveling_drop = seek_spawn_info['drops']
	if elite then
		AMPLIFY_STAT_ELITE = 2
		AMPLIFY_BOUNTY_ELITE = 2.2
		AMPLIFY_STAT_ELITE_HEALTH = 1.1
		AMPLIFY_STAT_ELITE_DAMAGE = 0.8
		creep:AddNewModifier(nil,nil,"modifier_creep_elite",{duration = -1})
	end
	-- поздняя игра: вместо двойных паков (см. CreepSpawner:_GetPackMultiplier) крип даёт больше
	local timeMult = CreepLeveling:BountyTimeMult()

	creep:SetDeathXP( seek_spawn_info.exp * AMPLIFY_BOUNTY_ELITE * timeMult )
	creep:SetMinimumGoldBounty( seek_spawn_info.gold_min * AMPLIFY_BOUNTY_ELITE * timeMult )
	creep:SetMaximumGoldBounty( seek_spawn_info.gold_max * AMPLIFY_BOUNTY_ELITE * timeMult )

	creep:SetBaseMaxHealth( seek_spawn_info.hp * AMPLIFY_STAT_ELITE * AMPLIFY_STAT_ELITE_HEALTH)
	creep:SetMaxHealth( seek_spawn_info.hp * AMPLIFY_STAT_ELITE * AMPLIFY_STAT_ELITE_HEALTH)
	creep:SetMaxMana( seek_spawn_info.mp * AMPLIFY_STAT_ELITE * AMPLIFY_STAT_ELITE_HEALTH)

	creep:SetPhysicalArmorBaseValue( seek_spawn_info.armor * AMPLIFY_STAT_ELITE)
	creep:SetBaseAttackTime( seek_spawn_info.bat * AMPLIFY_STAT_ELITE_DAMAGE)
	creep:SetBaseDamageMin( seek_spawn_info.dmg_min * AMPLIFY_STAT_ELITE * AMPLIFY_STAT_ELITE_DAMAGE)
	creep:SetBaseDamageMax( seek_spawn_info.dmg_max * AMPLIFY_STAT_ELITE * AMPLIFY_STAT_ELITE_DAMAGE)

	creep:SetMana( creep:GetMaxMana() )
	creep:SetHealth( creep:GetMaxHealth() )

	--creep:AddNewModifier(nil,nil,"modifier_creep_level",{duration = -1}):SetStackCount(level)
end

-- Множитель награды (золото и опыт) по игровому времени на момент спавна крипа.
-- Замена двойных паков с 25-й минуты; стартовые значения - на пробу, потом смотрим по логам.
local BOUNTY_TIME_STEPS = {
	{ min = 50, mult = 1.6 },
	{ min = 25, mult = 1.3 },
}

function CreepLeveling:BountyTimeMult()
	local time_min = GameRules:GetDOTATime(false, false) / 60

	for _, s in ipairs(BOUNTY_TIME_STEPS) do
		if time_min >= s.min then return s.mult end
	end

	return 1
end

function CreepLeveling:OnDeathCallback( event )
	local creep = event.creep

	local dropList = creep._leveling_drop

	creep._leveling_drop = nil

	if not dropList then return end

	local dropbox = dropList:Get()

	-- книги из дропа сразу достаются тому, кто убил (см. DropBox:DropAtPos)
	dropbox:DropAtPos(creep:GetAbsOrigin(), LOOT_RADIUS, nil, self:_KillerHero(event.attacker))
end

-- Герой того, кто убил крипа: сам герой, его иллюзия, суммон и т.п. У вышек
-- и нейтралов героя нет - тогда nil, и дроп падает на землю, как раньше.
function CreepLeveling:_KillerHero(attacker)
	if not attacker or attacker:IsNull() or not attacker.GetPlayerOwnerID then return nil end

	local playerId = attacker:GetPlayerOwnerID()
	if not playerId or playerId < 0 then return nil end

	return PlayerResource:GetSelectedHeroEntity(playerId)
end

function CreepLeveling:_calculateHeroesAverageLevel()
	local summ_level = 0
	local connected_count = 0
	local heroes = PlayerResource:GetAllHeroes()

	for _, x in pairs(heroes) do
		if x and IsConnected(x) and IsValidEntity(x) and x:IsRealHero() then
			summ_level = summ_level + x:GetLevel()
			connected_count = connected_count + 1
		end
	end

	return summ_level/connected_count
end 

CreepLeveling:Init()