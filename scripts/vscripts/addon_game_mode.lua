-- Generated from template

if AngelArena == nil then
	_G.AngelArena = class({})
end

function Precache( context )
	--[[
		Precache things we know we'll use.  Possible file types include (but not limited to):
			PrecacheResource( "model", "*.vmdl", context )
			PrecacheResource( "soundfile", "*.vsndevts", context )
			PrecacheResource( "particle", "*.vpcf", context )
			PrecacheResource( "particle_folder", "particles/folder", context )
	]]
end
local Constants = require('consts')
local killToWin = 10
local cheat = false
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

function AngelArena:InitGameMode()
	local GameMode = GameRules:GetGameModeEntity()
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

	GameMode:SetCustomBackpackSwapCooldown(4.0)
	GameRules:SetStartingGold(750)
	
	GameRules:SetUseUniversalShopMode(true)

	ListenToGameEvent( "dota_team_kill_credit", Dynamic_Wrap( AngelArena, 'OnTeamKillCredit' ), self )
	ListenToGameEvent( "npc_spawned", Dynamic_Wrap( AngelArena, "OnNPCSpawned" ), self )
	ListenToGameEvent("entity_killed", Dynamic_Wrap(AngelArena, "OnEntityKilled"), self)
	-- AttributeDerivedStats
	--GameMode:SetCustomAttributeDerivedStatValue(DOTA_ATTRIBUTE_STRENGTH_MAGIC_RESISTANCE_PERCENT, 0)
	--GameMode:SetCustomAttributeDerivedStatValue(DOTA_ATTRIBUTE_STRENGTH_STATUS_RESISTANCE_PERCENT, 0)
	--GameMode:SetCustomAttributeDerivedStatValue(DOTA_ATTRIBUTE_STRENGTH_HP_REGEN, 0)
	--GameMode:SetCustomAttributeDerivedStatValue(DOTA_ATTRIBUTE_AGILITY_MOVE_SPEED_PERCENT, 0)
	--GameMode:SetCustomAttributeDerivedStatValue(DOTA_ATTRIBUTE_INTELLIGENCE_MANA_REGEN, 0)
	--GameMode:SetCustomAttributeDerivedStatValue(DOTA_ATTRIBUTE_INTELLIGENCE_MAGIC_RESISTANCE_PERCENT, 0)

	GameRules:GetGameModeEntity():SetThink( "OnThink", self, "GlobalThink", 2 )
end

-- Evaluate the state of the game
function AngelArena:OnThink()
	if GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
		--print( "Template addon script is running." )
	elseif GameRules:State_Get() >= DOTA_GAMERULES_STATE_POST_GAME then
		return nil
	end
	return 1
end
function AngelArena:EndGame( victoryTeam )
	GameRules:SetGameWinner( victoryTeam )
	GameRules:SetCustomVictoryMessage('Мамут Рахал')
end

function AngelArena:OnTeamKillCredit(event)
	DeepPrintTable(event)
	print(killToWin)
	print(GetTeamHeroKills(DOTA_TEAM_GOODGUYS))
	print(GetTeamHeroKills(DOTA_TEAM_BADGUYS))
	if killToWin <= GetTeamHeroKills(DOTA_TEAM_GOODGUYS) then 
		AngelArena:EndGame( DOTA_TEAM_GOODGUYS )
	else

	end
	if killToWin <= GetTeamHeroKills(DOTA_TEAM_BADGUYS) then
		AngelArena:EndGame( DOTA_TEAM_BADGUYS )
	end
end
function AngelArena:OnNPCSpawned(keys)
	local npc = EntIndexToHScript(keys.entindex)
	if npc.bFirstSpawned == nil then
		npc.bFirstSpawned = true
		if cheat == true then
			if npc:IsRealHero() then
				
				npc:AddExperience(999999, 0, false, true)
				npc:SetGold(99999999,true)
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
	if IsValidEntity(killedUnit) and not killedUnit:IsAlive() and killedUnit:IsRealHero() then
		local timeLeft = killedUnit:GetLevel() * 3.8 + 5
		timeLeft = timeLeft * RESPAWN_MODIFER
		if timeLeft < 5.0 then
			timeLeft = 5.0
		end
		if killedUnit:IsReincarnating() == false then
			print(timeLeft)
			killedUnit:SetTimeUntilRespawn(timeLeft)
		end
	end
end