-- Generated from template

if AngelArena == nil then
	_G.AngelArena = class({})
end
require('lib/teleport')
require('lib/boss/boss_spawner')
require('lib/timers')
require('lib/team_helper')
require('lib/spawners/creep_spawner')
require('lib/spawners/creep_leveling')
require('lib/spawners/bear_spawner')
require('lib/duel/duel_controller')
require('lib/attentions')
require('lib/gpm_lib')
require('lib/game_ender')
require('lib/move_limiter')
require('lib/comeback_system')
require('lib/percent_damage')
function Precache( context )
	--[[
		Precache things we know we'll use.  Possible file types include (but not limited to):
			PrecacheResource( "model", "*.vmdl", context )
			PrecacheResource( "soundfile", "*.vsndevts", context )
			PrecacheResource( "particle", "*.vpcf", context )
			PrecacheResource( "particle_folder", "particles/folder", context )
	]]
	DuelController:Precache(context)
	--ItemPrecache:Precache(context)
end

local postRequireList = {
	'lib/base/player',
	'lib/base/base_npc'
}
local armor_table = require('creeps/armor_table_summon') -- armor to units
local Constants = require('consts')
local cheat = false
local is_game_start = false
local is_game_end = false
local game_start_for_courier = false

GOLD_PER_TICK = 4

KILL_LIMIT = 100

GOLD_FOR_COUR = 350

local teleport_range = 350

_G.Kills = {}
_G.KILL_LIMIT  = KILL_LIMIT

RESPAWN_MODIFER = 0.135
function Activate()
	GameRules.AddonTemplate = AngelArena()
	GameRules.AddonTemplate:InitGameMode()
	local fountains = Entities:FindAllByClassname('ent_dota_fountain')
    for _, fountain in pairs(fountains) do 
    if ability then
        ability:SetLevel(100)
    end
    end
end

function UpdatePlayersCount()
	if is_game_end then return end

	local teamsData = 
	{
		[DOTA_TEAM_GOODGUYS] = 0,
		[DOTA_TEAM_BADGUYS]  = 0,
	}

	local nPlayersConnected = 0

	TeamHelper:ApplyForPlayers(nil, function(playerid)
		if IsAbadonedPlayerID(playerid) then return end

		local team = PlayerResource:GetTeam(playerid)

		-- ignore invalid team
		if team == 0 then return end

		teamsData[team] = (teamsData[team] or 0) + 1
		nPlayersConnected = nPlayersConnected + 1
	end)

	local nRadiants = teamsData[DOTA_TEAM_GOODGUYS]
	local nDire = teamsData[DOTA_TEAM_BADGUYS]

	if nPlayersConnected == 0 or (nRadiants == 0 or nDire == 0 and not GameRules:IsCheatMode()) then
		local team

		if nPlayersConnected == 0 then
			team = DOTA_TEAM_NEUTRALS -- creeps is the best
		elseif nRadiants == 0 then
			team = DOTA_TEAM_BADGUYS
		else
			team = DOTA_TEAM_GOODGUYS
		end

		DuelController:SetFreezeTimer( true )
		GameEnder:StartGameEnd( team )
		is_game_end = true
	end
end
function BackPlayersToMap()
	local heroes = HeroList:GetAllHeroes()

	for _, hero in pairs(heroes) do
		if hero and hero:IsAlive() then

			if not hero._info then
				function CheckPos(unit, pos)
					return pos[3] >= -2500
				end

				function GetBasePosition(team)
					if team == DOTA_TEAM_GOODGUYS then
						return Entities:FindByName(nil, "RADIANT_BASE"):GetAbsOrigin()
					elseif team == DOTA_TEAM_BADGUYS then
						return Entities:FindByName(nil, "DIRE_BASE"):GetAbsOrigin()
					end
				end

				local nSaveSteps = 20
				local fMinDist = 100
				hero._info = MakeMoveLimiter(hero, CheckPos, nSaveSteps, fMinDist, GetBasePosition(hero:GetTeamNumber()) )
			end

			hero._info:tick()
		end
	end
end
function AngelArena:InitGameMode()
	for _, moduleName in pairs(postRequireList) do
		require(moduleName)
	end
	local GameMode = GameRules:GetGameModeEntity()

	GameRules:SetCustomVictoryMessage("#aa_on_win_message")

	GameRules:SetPreGameTime(60) -- old 9
	
	BossSpawner:Init()
	CreepSpawner:Init()
	
	CreepSpawner:RegisterOnSpawnCallback(function(arg) CreepLeveling:OnSpawnCallback(arg); end)
	CreepSpawner:RegisterOnDeathCallback(function(arg) CreepLeveling:OnDeathCallback(arg); end)
	if GameRules:IsCheatMode()then
		cheat = true
	end
	GameMode:SetCustomXPRequiredToReachNextLevel(Constants.XP_PER_LEVEL_TABLE)
	GameMode:SetUseCustomHeroLevels(true)

	GameMode:SetFountainPercentageHealthRegen(7)
	GameMode:SetFountainPercentageManaRegen(10)
	GameMode:SetFountainConstantManaRegen(20)

	GameMode:SetFreeCourierModeEnabled( true )
	GameMode:SetBuybackEnabled(true)
	GameMode:SetStashPurchasingDisabled(false)
	GameMode:SetLoseGoldOnDeath(true)

	GameMode:SetDraftingHeroPickSelectTimeOverride(60)
	GameMode:SetDraftingBanningTimeOverride(20)
	GameRules:SetPostGameTime(30)
	GameRules:SetStrategyTime(15.0)
	GameRules:SetHeroSelectionTime(90)
	GameRules:SetCreepSpawningEnabled( false )

	GameMode:SetCustomBackpackSwapCooldown(4.0)
	GameRules:SetStartingGold(750)
	
	GameRules:SetUseUniversalShopMode(true)


	ListenToGameEvent( "npc_spawned", Dynamic_Wrap( AngelArena, "OnNPCSpawned" ), self )
	ListenToGameEvent('game_rules_state_change', Safe_Wrap(AngelArena, 'OnGameStateChange'), self)
	ListenToGameEvent("entity_killed", Dynamic_Wrap(AngelArena, "OnEntityKilled"), self)
	ListenToGameEvent('dota_player_gained_level', Safe_Wrap(AngelArena, 'OnLevelUp'), self)
	GameRules:GetGameModeEntity():SetExecuteOrderFilter( Dynamic_Wrap( AngelArena, "ExecuteOrderFilterCustom" ), self )

	LinkLuaModifier("modifier_godmode", 'modifiers/modifier_godmode', LUA_MODIFIER_MOTION_NONE)
	LinkLuaModifier("modifier_full_disable_stun", 'modifiers/modifier_full_disable_stun', LUA_MODIFIER_MOTION_NONE)
	LinkLuaModifier("modifier_mid_teleport", "modifiers/modifier_mid_teleport", LUA_MODIFIER_MOTION_NONE)

	GameMode:SetDamageFilter(Safe_Wrap(AngelArena, "DamageFilter"), self)
	-- AttributeDerivedStats
	--GameMode:SetCustomAttributeDerivedStatValue(DOTA_ATTRIBUTE_STRENGTH_MAGIC_RESISTANCE_PERCENT, 0)
	--GameMode:SetCustomAttributeDerivedStatValue(DOTA_ATTRIBUTE_STRENGTH_STATUS_RESISTANCE_PERCENT, 0)
	--GameMode:SetCustomAttributeDerivedStatValue(DOTA_ATTRIBUTE_STRENGTH_HP_REGEN, 0)
	--GameMode:SetCustomAttributeDerivedStatValue(DOTA_ATTRIBUTE_AGILITY_MOVE_SPEED_PERCENT, 0.2)
	--GameMode:SetCustomAttributeDerivedStatValue(DOTA_ATTRIBUTE_INTELLIGENCE_MANA_REGEN, 0)
	--GameMode:SetCustomAttributeDerivedStatValue(DOTA_ATTRIBUTE_INTELLIGENCE_MAGIC_RESISTANCE_PERCENT, 0)

	GameRules:GetGameModeEntity():SetThink( "OnThink", self, "GlobalThink", 2 )

	GameMode:SetCustomRadiantScore(0)
	GameMode:SetCustomDireScore(0)
	_G.Kills[DOTA_TEAM_GOODGUYS] = _G.Kills[DOTA_TEAM_GOODGUYS] or 0
	_G.Kills[DOTA_TEAM_BADGUYS] = _G.Kills[DOTA_TEAM_BADGUYS] or 0

	AngelArena:OnGameStateChange()
	Attentions:SetKillLimit( KILL_LIMIT )

end

-- Evaluate the state of the game
function AngelArena:OnThink()
	if GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
	end
	if GameRules:State_Get() >= DOTA_GAMERULES_STATE_POST_GAME then
		return nil
	end
	return 1
end
function AngelArena:ShareGold()
	local teamGolds = {}

	TeamHelper:ApplyForPlayers(nil, function(playerID)
		local team = PlayerResource:GetTeam(playerID)

		local teamData = teamGolds[team] or {
			nPlayers = 0,
			freeGold = 0,
		}

		if PlayerResource:IsConnected( playerID ) then
			teamData.nPlayers = teamData.nPlayers + 1
		end

		if not PlayerResource:IsAbandoned( playerID ) then return end

		teamData.freeGold = teamData.freeGold + PlayerResource:GetGold( playerID )

		PlayerResource:SetGold(playerID, 0, false)
		PlayerResource:SetGold(playerID, 0, true)
	end)


	TeamHelper:ApplyForPlayers(nil, function(playerID)
		local team = PlayerResource:GetTeam(playerID)

		local teamData = teamGolds[team]

		if not teamData then return end

		local newGold = teamData.freeGold / teamData.nPlayers

		PlayerResource:ModifyGold(playerID, newGold, true, 0)
	end)
end
function AngelArena:OnGameStateChange()
	if GetMapName() ~= "map_5x5_cm" then
		if GameRules:State_Get() == DOTA_GAMERULES_STATE_TEAM_SHOWCASE then

			TeamHelper:ApplyForPlayers(team, function(ply_id)
				local player = PlayerResource:GetPlayer(ply_id)

				if player and PlayerResource:IsValidPlayer(ply_id) and PlayerResource:GetSelectedHeroName(ply_id) == "" then
					player:MakeRandomHeroSelection()
				end
			end)
		end
	end

	if GameRules:State_Get() == DOTA_GAMERULES_STATE_PRE_GAME then
		local portals = {
			"teleport_radiant_top",
			"teleport_radiant_bot",
			"teleport_dire_top",
			"teleport_dire_bot",
		}
		for _,name in pairs(portals) do
			local spawnpoint = Entities:FindByName( nil, name )
			local creep = CreateUnitByName("npc_teleport", spawnpoint:GetAbsOrigin(), true, nil, nil, DOTA_TEAM_GOODGUYS)
			creep:AddNewModifier(creep, nil,'modifier_mid_teleport', {duration = -1} )
		end
		

		PauseGame(true)
		CustomGameEventManager:Send_ServerToAllClients("MakeNeutralItemsInShopColored", {})

		local spawners = Entities:FindAllByClassname("npc_dota_neutral_spawner")

		for _, spawner in pairs(spawners) do
			UTIL_Remove(spawner)
		end
	end

	if GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
		if not is_game_start then
			CreepSpawner:StartSpawning()
			BossSpawner:OnGameStart()
			BearSpawner:SpawnBear()
			
			Timers:CreateTimer(0.1, function()
				GPM_Init()
			end)

			Timers:CreateTimer(10, function() -- таймер для шаринга голды
				AngelArena:ShareGold()
				UpdatePlayersCount()
				return 10
			end)

			Timers:CreateTimer(0.5, function()
				BackPlayersToMap()
				return 0.5
			end)

			DuelController:OnGameStart(function(winnerTeam)
				is_game_end = true
				DuelController:SetFreezeTimer(true)
				GameEnder:ForceEnd(winnerTeam)
			end)

			is_game_start = true
		end
	end
end
function AngelArena:OnNPCSpawned(keys)
	local npc = EntIndexToHScript(keys.entindex)
	if npc.bFirstSpawned == nil then
		npc.bFirstSpawned = true
		if cheat == true then
			if npc:IsRealHero() then
				--npc:AddExperience(999999, 0, false, true)
				--npc:SetGold(99999999,true)
			end
		end
	end
end

local no_points_levels = {
	[17] = 1,
	[19] = 1,
	[21] = 1,
	[22] = 1,
	[23] = 1,
	[24] = 1,
	[25] = 1,
	[26] = 1,
	[27] = 1,
	[28] = 1,
	[29] = 1,
}
function AngelArena:OnLevelUp(keys)
	local hero = EntIndexToHScript(keys.hero_entindex)
    local level = keys.level
    if no_points_levels[level] and hero:GetUnitName() ~= "npc_dota_hero_invoker" or level >= 30 then
		hero:SetAbilityPoints(hero:GetAbilityPoints() + 1)
	end
end

function AngelArena:OnEntityKilled(event)
	local killedUnit = EntIndexToHScript(event.entindex_killed)
	local killedTeam = killedUnit:GetTeam()
	local hero = EntIndexToHScript(event.entindex_attacker)
	local heroTeam = hero:GetTeam()

	_G.Kills[heroTeam] = _G.Kills[heroTeam] or 0
	_G.Kills[DOTA_TEAM_BADGUYS] = _G.Kills[DOTA_TEAM_BADGUYS] or 0
	_G.Kills[DOTA_TEAM_GOODGUYS] = _G.Kills[DOTA_TEAM_GOODGUYS] or 0
	local GameMode = GameRules:GetGameModeEntity()

	if not killedUnit or not IsValidEntity(killedUnit) then return end

	if killedUnit:GetUnitName() == 'npc_aa_creep_centaur_big'then
		Timers:CreateTimer(1.5, function()
			BearSpawner:ReSpawnBear()
		end)
		
	end

	if BossSpawner:HandleUnitKill( killedUnit, hero ) then
		return
	end

	if IsValidEntity(killedUnit) and not killedUnit:IsAlive() and killedUnit:IsRealHero() then
		local timeLeft = killedUnit:GetLevel() * 3.8 + 5
		timeLeft = timeLeft * RESPAWN_MODIFER
		if timeLeft < 5.0 then
			timeLeft = 5.0
		end

		if killedUnit:IsReincarnating() == false then
			killedUnit:SetTimeUntilRespawn(timeLeft)
		end
	end

	if killedUnit:IsRealHero() and not killedUnit:IsReincarnating() and heroTeam and heroTeam ~= killedTeam and _G.Kills[heroTeam] then
		_G.Kills[heroTeam] = _G.Kills[heroTeam] + 1
	end

	if (killedUnit:HasAbility("skeleton_king_reincarnation") or killedUnit:HasAbility("angel_arena_reincarnation")) then
		local rein_ability = killedUnit:FindAbilityByName("skeleton_king_reincarnation") or killedUnit:FindAbilityByName("angel_arena_reincarnation")
		local ability_level = rein_ability:GetLevel()
		local current_cooldown = rein_ability:GetCooldownTimeRemaining()
		local cooldown = Util:GetReallyCooldown(killedUnit, rein_ability)

		if (current_cooldown ~= cooldown) then
			while (killedUnit:HasModifier("modifier_item_aegis")) do
				killedUnit:RemoveModifierByName("modifier_item_aegis")
			end
		end
	else
		while (killedUnit:HasModifier("modifier_item_aegis")) do
			killedUnit:RemoveModifierByName("modifier_item_aegis")
		end
	end

	if killedUnit:IsRealHero() and not killedUnit:IsReincarnating() then
		self:OnHeroDeath(killedUnit, hero)
	end

	local allowedTeams = {
		DOTA_TEAM_GOODGUYS,
		DOTA_TEAM_BADGUYS,
	}

	for _, teamNumber in pairs(allowedTeams) do
		if _G.Kills[teamNumber] >= KILL_LIMIT and not DuelController:IsLastDuelTeam(teamNumber) then
			DuelController:AddLastDuelTeam( teamNumber )
			Attentions:SendAttentionText("#aa_last_duel_coming", 10, 2)
			Attentions:SendChatMessage("#aa_last_duel_coming")
		end
	end

	GameMode:SetCustomDireScore( _G.Kills[DOTA_TEAM_BADGUYS] )
	GameMode:SetCustomRadiantScore( _G.Kills[DOTA_TEAM_GOODGUYS] )

	if hero and hero:GetPlayerOwnerID() ~= nil and killedUnit:IsCourier() then
		PlayerResource:ModifyGold(hero:GetPlayerOwnerID(), GOLD_FOR_COUR, false, 0)
	end
end
function AngelArena:OnHeroDeath(dead_hero, killer)
	if not dead_hero or dead_hero:IsNull() or not IsValidEntity(dead_hero) then return end
	if not killer or killer:IsNull() or not IsValidEntity(killer) then return end

	ComebackSystem:OnKill( killer:GetPlayerOwnerID(), killer:GetTeamNumber(), dead_hero:GetPlayerOwnerID(), dead_hero:GetTeamNumber() )
end
function AngelArena:DamageFilter(event)
	local damage = event.damage
	local entindex_inflictor_const = event.entindex_inflictor_const
	local entindex_victim_const = event.entindex_victim_const
	local entindex_attacker_const = event.entindex_attacker_const
	local damagetype_const = event.damagetype_const
	local skill_name = ""
	local victim
	local attacker

	if (entindex_inflictor_const) then skill_name = EntIndexToHScript(entindex_inflictor_const):GetName() end
	if (entindex_victim_const) then victim = EntIndexToHScript(entindex_victim_const) end
	if (entindex_attacker_const) then attacker = EntIndexToHScript(entindex_attacker_const) end

	-----------------------------------------------------------------------------------------------------
	------------------------------ Костыль для ланаи ----------------------------------------------------
	-----------------------------------------------------------------------------------------------------
	
	if attacker and victim:HasModifier("modifier_templar_assassin_refraction_absorb") then
		if skill_name ~= "item_helm_of_the_undying" and skill_name ~= "skeleton_king_reincarnation" then
			return
		end
	end

	-----------------------------------------------------------------------------------------------------
	--------------------------------- Procent damage enable for some skills -----------------------------
	-----------------------------------------------------------------------------------------------------

	if skill_name and _G.skill_callback and _G.skill_callback[skill_name] then
		if victim and (victim:IsHero() or victim:IsCreep() or victim:IsAncient()) then

			for callback_id, callback in pairs(_G.skill_callback[skill_name]) do
				local ability = attacker:FindAbilityByName(skill_name)

				if not ability then
					ability = attacker:FindItemInInventory(skill_name)
				end

				if attacker and (skill_name == "batrider_sticky_napalm") then
					return
				end

				local callback_data = {
					caster = attacker,
					target = victim,
					skill_name = skill_name,
					ability = ability,
					damage = damage,
					damage_type = damagetype_const,
				}

				local status, res = pcall(callback, callback_data)
				if victim ~= attacker then
					if status and res then
						ApplyDamage({ victim = victim, attacker = attacker, damage = res, damage_type = damagetype_const })
					end
				end
			end
		end
	end

	return true
end

function AngelArena:ExecuteOrderFilterCustom( ord )

	local target = ord.entindex_target ~= 0 and EntIndexToHScript(ord.entindex_target) or nil
	local player = PlayerResource:GetPlayer(ord["issuer_player_id_const"])

	local unit

	if ord.units and ord.units["0"] then
        unit = EntIndexToHScript(ord.units["0"])
    end

	
	if not player then return false end

    local hero = player:GetAssignedHero()


    if not hero then return end

	if ord.order_type == DOTA_UNIT_ORDER_ATTACK_TARGET or ord.order_type == DOTA_UNIT_ORDER_MOVE_TO_TARGET  then
		
		if target and not target:IsNull() and  target:IsBaseNPC() and target:GetUnitName() == "npc_teleport" and unit:IsRealHero() then
			if teleport_range >= ( hero:GetOrigin() - target:GetOrigin() ):Length2D() then 
				if not hero:HasModifier("modifier_mid_teleport_cd") then
					hero:Interrupt() 
					hero:Stop()
				   	hero:AddAbility("mid_teleport")
					local ability = hero:FindAbilityByName("mid_teleport")
					ability:SetLevel(1)
				  	hero:CastAbilityNoTarget(ability, hero:GetPlayerOwnerID())
				end
				return false
			else 
				return true
			end
			
		  end
		end
	
		if ord.order_type == DOTA_UNIT_ORDER_CAST_TARGET  then
			if target:GetUnitName() == "npc_teleport" then 
				return false
			end
		end
	return true
end
