-- Generated from template
_G.inited = false
if AngelArena == nil then
	_G.AngelArena = class({})
end
print("[AA] addon_game_mode loaded (top of file)")

local function safe_require(name)
    local ok, res = xpcall(function()
        return require(name)
    end, function(msg)
        print("!!! safe_require FAILED:", name)
        print(tostring(msg))
        print(debug.traceback("Traceback:", 2))
        return msg
    end)

    if not ok then
        error("safe_require failed: " .. name)
    end
    return res
end

safe_require('tp_s')
safe_require('lib/utils')
safe_require('lib/teleport')
safe_require('lib/duel/duel_controller')
safe_require('lib/gpm_lib')
safe_require('lib/percent_damage')
safe_require('lib/boss/boss_spawner')
safe_require('lib/panorama_pings')
safe_require('lib/spawners/creep_spawner')
safe_require('lib/spawners/creep_leveling')
safe_require('lib/timers')
safe_require('lib/attentions')
safe_require('lib/team_helper')
safe_require('lib/chat_listener')
safe_require('lib/comeback_system')
safe_require('lib/move_limiter')
safe_require('lib/spawners/bear_spawner')
safe_require('lib/bounty')
safe_require('lib/game_ender')
safe_require('lib/repick_menu')
safe_require('lib/special_bonus_base_aa/Special_bonus_base_aa')
--safe_require('lib/events_protector')

function CEntityInstance:SetNetworkableEntityInfo(key, value)
    local t = CustomNetTables:GetTableValue("custom_entity_values", tostring(self:GetEntityIndex())) or {}
    t[key] = value
    CustomNetTables:SetTableValue("custom_entity_values", tostring(self:GetEntityIndex()), t)
end
-- local function forPrecache(kv, context)
--     if type(kv) ~= "table" then return end

--     for unitname, unit_kv in pairs(kv) do
--         if type(unit_kv) == "table" and unit_kv.Model then
--             PrecacheModel(unit_kv.Model, context)
--         end

--         -- unitname тут ключ из KV: npc_xxx
--         if type(unitname) == "string" then
--             PrecacheUnitByNameSync(unitname, context)
--         end
--     end
-- end

function Precache(context)
    -- Партиклы
    --PrecacheResource("particle_folder", "particles", context)

    -- Юниты/герои
    -- local units_kv = LoadKeyValues("scripts/npc/npc_units_custom.txt") or {}
    -- local hero_kv  = LoadKeyValues("scripts/npc/npc_heroes_custom.txt") or {}

    -- forPrecache(units_kv, context)
    -- forPrecache(hero_kv, context)

    -- Остальное
    DuelController:Precache(context)
    PrecacheResource("soundfile", "soundevents/game_sounds.vsndevts", context)
    PrecacheResource("soundfile", "soundevents/game_sounds_items.vsndevts", context)
    PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_shadowshaman.vsndevts", context)
    PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_axe.vsndevts", context)
    PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_techies.vsndevts", context)
    PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_gyrocopter.vsndevts", context)
    PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_lich.vsndevts", context)
	

	-- PrecacheResource("particle", "particles/items2_fx/teleport_end.vpcf", context)
	-- PrecacheResource("particle", "particles/new_charone/charone_spepcter.vpcf", context)

	-- precacheResource("model", "models/props_gameplay/donkey.vmdl", context)
	-- precacheResource("model", "models/props_gameplay/dummy/dummy.vmdl", context)
	-- precacheResource("model", "models/props_gameplay/dummy/dummy_large.vmdl", context)
	-- PrecacheResource("model", "models/items/hex/sheep_hex/sheep_hex_gold.vmdl", context)
	-- PrecacheResource("model", "models/items/hex/sheep_hex/sheep_hex.vmdl", context)
	-- precacheResource("model", "models/props_gameplay/donkey.vmdl", context)
	-- PrecacheResource("model", "models/tomes/tome_agi.vmdl", context)
	-- PrecacheResource("model", "models/tomes/tome_int.vmdl", context)
	-- PrecacheResource("model", "models/tomes/tome_str.vmdl", context)
	-- PrecacheResource("model", "models/tomes/tome_all.vmdl", context)
	-- PrecacheResource("model", "models/tomes/tome_level.vmdl", context)
	-- PrecacheResource("model", "models/tomes/tome_medical.vmdl", context)
		
end
local hero_table = safe_require('lib/hero_table')
local postsafe_requireList = {
	'lib/base/player',
	'lib/base/base_npc'
}
local forbidden_ability_boss = {
	["life_stealer_infest"] = 1,
	["chen_holy_persuasion"] = 1,
	["enchantress_enchant"] = 1,
	["item_devour_helm"] = 1,
	["item_iron_talon"] = 1,
	["night_stalker_hunter_in_the_night"] = 1,
	["snapfire_spit_creep"] = 1,
	["juggernaut_omni_slash"] = 1,
	["juggernaut_swift_slash"] = 1,
	["snapfire_gobble_up"] = 1,
	['item_bloodthorn'] = 1,
	['item_bloodthorn_2'] = 1,
	['item_bloodthorn_3'] = 1,
	['item_orchid'] = 1,
}
local crash_abilities = {
	["shadow_demon_disruption"] = 1,
	["obsidian_destroyer_astral_imprisonment"] = 1,
	["rubick_telekinesis"] = 1,
	["disruptor_thunder_strike"] = 1,
}

local illusion_bug_crash =
{
	["npc_dota_hero_dawnbreaker"] = 1,
	["npc_dota_hero_visage"] = 1,
	["npc_dota_hero_weaver"] = 1,
}
local forbidden_items_for_clones = {
	["item_refresher"] = 1,
	["item_recovery_orb"] = 1,
	["item_devour_helm"] = 1,
}
local armor_table = safe_require('creeps/armor_table_summon') -- armor to units
local Constants = safe_require('consts')
local cheat = false
local is_game_start = false
local is_game_end = false
local game_start_for_courier = false
local had_players_on_both_teams = false
KILL_LIMIT_CONST = 120
GOLD_PER_TICK = 0

KILL_LIMIT = 80

GOLD_FOR_COUR = 350

local teleport_range = 350

_G.Kills = {}
_G.KILL_LIMIT = KILL_LIMIT

RESPAWN_MODIFER = 0.135
function Activate()
	print("[AA] Activate() called")
	GameRules.AngelArena = AngelArena()
	GameRules.AngelArena:InitGameMode()
	local fountains = Entities:FindAllByClassname('ent_dota_fountain')
    for _, fountain in pairs(fountains) do
    if ability then
        ability:SetLevel(100)
    end
    end
end

function UpdatePlayersCount()
    if is_game_end then return end

    local teamsData = {
        [DOTA_TEAM_GOODGUYS] = 0,
        [DOTA_TEAM_BADGUYS]  = 0,
    }

    local nPlayersConnected = 0

    TeamHelper:ApplyForPlayers(nil, function(playerid)
        if IsAbadonedPlayerID(playerid) then return end

        local team = PlayerResource:GetTeam(playerid)
        if team == 0 then return end -- invalid

        teamsData[team] = (teamsData[team] or 0) + 1
        nPlayersConnected = nPlayersConnected + 1
    end)

    local nRadiants = teamsData[DOTA_TEAM_GOODGUYS]
    local nDire     = teamsData[DOTA_TEAM_BADGUYS]

    if nRadiants > 0 and nDire > 0 then
        had_players_on_both_teams = true
    end

    if nPlayersConnected == 0 then
        DuelController:SetFreezeTimer(true)
        GameEnder:StartGameEnd(DOTA_TEAM_NEUTRALS)
        is_game_end = true
        return
    end

    local cheat = GameRules:IsCheatMode()
    if had_players_on_both_teams and (not cheat) and (nRadiants == 0 or nDire == 0) then
        local team = (nRadiants == 0) and DOTA_TEAM_BADGUYS or DOTA_TEAM_GOODGUYS
        DuelController:SetFreezeTimer(true)
        GameEnder:StartGameEnd(team)
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
	for _, moduleName in pairs(postsafe_requireList) do
		safe_require(moduleName)
	end
	local GameMode = GameRules:GetGameModeEntity()
	Convars:SetInt("dota_max_physical_items_purchase_limit", 100)
	GameRules:SetCustomVictoryMessage("#aa_on_win_message")


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
	GameRules:GetGameModeEntity():SetFriendlyBuildingMoveToEnabled(true);
	if GameRules:IsCheatMode() then
		GameRules:SetHeroSelectionTime(90)
		GameRules:SetStrategyTime(1)
		GameMode:SetDraftingHeroPickSelectTimeOverride(25)
		GameMode:SetDraftingBanningTimeOverride(0)
		GameRules:SetPreGameTime(60)
	else
		GameRules:SetCustomGameBansPerTeam( 5 )
		GameMode:SetDraftingBanningTimeOverride(20)
		GameRules:SetHeroSelectionTime(90)
		GameMode:SetDraftingHeroPickSelectTimeOverride(60)
		GameRules:SetPreGameTime(60)
	end
	--GameRules:SetSameHeroSelectionEnabled(true)
	GameRules:SetGoldPerTick(GOLD_PER_TICK)
	GameRules:SetHeroRespawnEnabled(true)
	GameRules:SetPostGameTime(30)
	GameRules:SetStrategyTime(15.0)

	GameRules:SetCreepSpawningEnabled( false )

	GameRules:SetGoldTickTime(1)
	GameRules:SetTreeRegrowTime(180)
	GameRules:SetUseBaseGoldBountyOnHeroes(true)
	GameMode:SetBountyRuneSpawnInterval(120.0)
	GameRules:SetRuneSpawnTime(120)
	GameMode:SetCustomBackpackSwapCooldown(4.0)
	GameRules:SetStartingGold(750)

	GameRules:SetUseUniversalShopMode(true)


	ListenToGameEvent("npc_spawned", Dynamic_Wrap( AngelArena, "OnNPCSpawned" ), self )
	ListenToGameEvent('game_rules_state_change', Safe_Wrap(AngelArena, 'OnGameStateChange'), self)
	ListenToGameEvent("entity_killed", Dynamic_Wrap(AngelArena, "OnEntityKilled"), self)
	ListenToGameEvent('dota_player_gained_level', Safe_Wrap(AngelArena, 'OnLevelUp'), self)
	ListenToGameEvent('dota_rune_activated_server', Safe_Wrap(AngelArena, 'OnRuneActivate'), self)
	ListenToGameEvent('dota_player_used_ability', Safe_Wrap(AngelArena, 'OnPlayerUsedAbility'), self)
	ListenToGameEvent('player_connect_full', Safe_Wrap(AngelArena, 'OnConnectFull'), self)
	ListenToGameEvent('player_disconnect', Safe_Wrap(AngelArena, 'OnPlayerDisconnect'), self)
	ListenToGameEvent("player_chat", Safe_Wrap(ChatListener, 'OnPlayerChat'), ChatListener)
	ListenToGameEvent('dota_item_purchased', Safe_Wrap(AngelArena, 'OnPlayerBuyItem'), self)
	ListenToGameEvent( "dota_player_learned_ability", Dynamic_Wrap( Special_bonus_base_aa, "OnAbilityLearned" ), self )

	GameRules:GetGameModeEntity():SetExecuteOrderFilter( Dynamic_Wrap( AngelArena, "ExecuteOrderFilterCustom" ), self )
	PlayerResource:ClearOnAbandonedCallbacks()
	PlayerResource:RegisterOnAbandonedCallback(function(arg) AngelArena:OnAbandoned(arg) end)
	LinkLuaModifier("modifier_godmode", 'modifiers/modifier_godmode', LUA_MODIFIER_MOTION_NONE)
	LinkLuaModifier("modifier_aa_hero", 'modifiers/modifier_aa_hero', LUA_MODIFIER_MOTION_NONE)
	LinkLuaModifier("bonus_str_tome", "modifiers/modifier_aa_hero", LUA_MODIFIER_MOTION_NONE)
	LinkLuaModifier("bonus_agi_tome", "modifiers/modifier_aa_hero", LUA_MODIFIER_MOTION_NONE)
	LinkLuaModifier("bonus_int_tome", "modifiers/modifier_aa_hero", LUA_MODIFIER_MOTION_NONE)
	LinkLuaModifier("modifier_full_disable_stun", 'modifiers/modifier_full_disable_stun', LUA_MODIFIER_MOTION_NONE)
	LinkLuaModifier("modifier_mid_teleport", "modifiers/modifier_mid_teleport", LUA_MODIFIER_MOTION_NONE)
	LinkLuaModifier("modifier_medical_tractate", 'modifiers/modifier_medical_tractate', LUA_MODIFIER_MOTION_NONE)
	LinkLuaModifier("modifier_medical_tractate_2", 'modifiers/modifier_medical_tractate', LUA_MODIFIER_MOTION_NONE)
	LinkLuaModifier("modifier_duel_vision", 'modifiers/modifier_duel_vision', LUA_MODIFIER_MOTION_NONE)
	LinkLuaModifier("modifier_repick", 'modifiers/modifier_repick', LUA_MODIFIER_MOTION_NONE)
	LinkLuaModifier('modifier_bat', 'modifiers/modifier_bat', LUA_MODIFIER_MOTION_NONE)
	LinkLuaModifier("modifier_dissapear", 'modifiers/modifier_dissapear', LUA_MODIFIER_MOTION_NONE)

	GameMode:SetDamageFilter(Safe_Wrap(AngelArena, "DamageFilter"), self)
	GameMode:SetRuneSpawnFilter(Safe_Wrap(AngelArena, "ModifierRuneSpawn"), self)
	GameMode:SetModifyGoldFilter(Safe_Wrap(AngelArena, "GoldFilter"), self)
	-- AttributeDerivedStats
	--GameMode:SetCustomAttributeDerivedStatValue(DOTA_ATTRIBUTE_STRENGTH_MAGIC_RESISTANCE_PERCENT, 0)
	--GameMode:SetCustomAttributeDerivedStatValue(DOTA_ATTRIBUTE_STRENGTH_STATUS_RESISTANCE_PERCENT, 0)
	--GameMode:SetCustomAttributeDerivedStatValue(DOTA_ATTRIBUTE_STRENGTH_HP_REGEN, 0)
	--GameMode:SetCustomAttributeDerivedStatValue(DOTA_ATTRIBUTE_AGILITY_MOVE_SPEED_PERCENT, 0.2)
	--GameMode:SetCustomAttributeDerivedStatValue(DOTA_ATTRIBUTE_AGILITY_DAMAGE , 1.2)
	--GameMode:SetCustomAttributeDerivedStatValue(DOTA_ATTRIBUTE_AGILITY_ARMOR , 0.112)
	--GameMode:SetCustomAttributeDerivedStatValue(DOTA_ATTRIBUTE_INTELLIGENCE_MANA_REGEN, 0)
	--GameMode:SetCustomAttributeDerivedStatValue(DOTA_ATTRIBUTE_INTELLIGENCE_MAGIC_RESIST, 0)

	GameRules:GetGameModeEntity():SetThink( "OnThink", self, "GlobalThink", 2 )

	GameMode:SetCustomRadiantScore(0)
	GameMode:SetCustomDireScore(0)
	_G.Kills[DOTA_TEAM_GOODGUYS] = _G.Kills[DOTA_TEAM_GOODGUYS] or 0
	_G.Kills[DOTA_TEAM_BADGUYS] = _G.Kills[DOTA_TEAM_BADGUYS] or 0

	AngelArena:OnGameStateChange()

	if GameRules:IsCheatMode() then
		safe_require('lib/debug/keyexec')
		KeyExec:Init()
	end

end

function AngelArena:ModifierRuneSpawn(keys)
	--print(EntIndexToHScript(keys.spawner_entindex_const):GetName())
	--print(keys.rune_type)
	function Almostequal(value1, value2, epsilon)
		return math.abs(value1 - value2) < epsilon
	end
	local rune_type = keys.rune_type

	local runes = { 0, 1, 2, 3, 4, 6, 9}

	local Dotatime = GameRules:GetDOTATime(false, false)
		keys.rune_type = runes[RandomInt(1, #runes)]
	return true
end
function AngelArena:OnRuneActivate(event)
	local runeid = event.rune
	local playerid = event.PlayerID
	local hero = PlayerResource:GetPlayer(playerid):GetAssignedHero()

	if not hero then return end

	if runeid == DOTA_RUNE_BOUNTY then
		local cur_min = GameRules:GetGameTime() / 60

		local item_mod_table = {
			{ "item_hand_of_midas",  40 + 18 * cur_min },
			{ "item_advanced_midas", 60 + 27 * cur_min }
		}

		local hero_mod_table = {
			["npc_dota_hero_alchemist"] = 2,
		}

		local gold_without_mods = 40 + 14 * cur_min

		function CalcBountyGold( hero )
			local hero_mult = hero_mod_table[ hero:GetUnitName() ] or 1

			local item_gold = 0
			for _, data in pairs(item_mod_table) do
				local item = data[1]
				local gold = data[2]

				if hero:HasItemInInventory(item) and gold > item_gold then
					item_gold = gold
				end
			end

			return hero_mult * ( gold_without_mods + item_gold )
		end

		local team = hero:GetTeamNumber()

		TeamHelper:ApplyForHeroes(team, function(playerid, unit)
			unit:ModifyGold(CalcBountyGold( unit ), false, 0)
			SendOverheadEventMessage(unit, OVERHEAD_ALERT_GOLD, unit, CalcBountyGold( unit ),nil)
		end)
	end
	if runeid == DOTA_RUNE_XP then
		local cur_min = GameRules:GetGameTime() / 60

		local item_mod_table = {
			{"item_talisman_of_mastery", 20 * cur_min },
		}
		local xp_without_mods = 70 + 18 * cur_min

		function CalcWisdomXp(hero )
			local item_xp = 0
			for _, data in pairs(item_mod_table) do
				local item = data[1]
				local xp = data[2]

				if hero:HasItemInInventory(item) and xp > item_xp then
					item_xp = xp
				end
			end

			return 1 * ( xp_without_mods + item_xp )
		end

		local team = hero:GetTeamNumber()

		TeamHelper:ApplyForHeroes(team, function(playerid, unit)
			unit:AddExperience(CalcWisdomXp( unit ), 0, true,true)
			SendOverheadEventMessage(unit, OVERHEAD_ALERT_XP, unit, CalcWisdomXp( unit ),nil)
		end)
	end
	local item
	for i = 0, 5 do
		item = hero:GetItemInSlot(i)
		if item and item:GetPurchaser() == hero then
			if item and (item:GetName() == "item_unknown_amulet")then
				if item:GetCurrentCharges() < 4 then
					item:SetCurrentCharges(item:GetCurrentCharges() + 2)
				else
					item:SetCurrentCharges(item:GetCurrentCharges() + 1)
				return 
				end 
			end
		end
	end
end
function AngelArena:OnPlayerDisconnect(event)
	local name = event.name
	local networkid = event.networkid
	local reason = event.reason
	local userid = event.userid
end
function AngelArena:OnAbandoned(arg)
	local playerid = arg.playerid

	local abaddonTeam = PlayerResource:GetTeam(playerid)
	local heroTeam = nil

	if abaddonTeam == DOTA_TEAM_GOODGUYS then
		heroTeam = DOTA_TEAM_BADGUYS
	elseif abaddonTeam == DOTA_TEAM_BADGUYS then
		heroTeam = DOTA_TEAM_GOODGUYS
	else
		return
	end

	local kills = _G.Kills[heroTeam] or 0
	local diff = (KILL_LIMIT - kills)

	local heroes = PlayerResource:GetHeroes(abaddonTeam)

	local connectedHeroes = 0

	for pid, hero in pairs(heroes) do
		if not (PlayerResource:IsAbandoned(pid) and hero:GetTeamNumber() == abaddonTeam) then
			connectedHeroes = connectedHeroes + 1
		end
	end
	if connectedHeroes == 0 then return end

	kills = kills + math.ceil(diff / (connectedHeroes + 1))

	if kills > KILL_LIMIT then return end

	_G.Kills[heroTeam] = kills

	local GameMode = GameRules:GetGameModeEntity()

	GameMode:SetCustomDireScore( _G.Kills[DOTA_TEAM_BADGUYS] )
	GameMode:SetCustomRadiantScore( _G.Kills[DOTA_TEAM_GOODGUYS] )
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

function AngelArena:OnConnectFull(event)
	local entIndex = event.index + 1
	local player = EntIndexToHScript(entIndex)
	local playerID = player:GetPlayerID()

	CustomGameEventManager:Send_ServerToAllClients("MakeNeutralItemsInShopColored", {})
	PlayerResource:OnPlayerConnected(playerID, event.userid)
end
function AngelArena:GoldFilter(event)
	print(event.gold)
	ComebackSystem:OnGiveGold( event.player_id_const, event.gold, event.reliable, event.reason_const )
	AngelArena:SaveGold(event.gold)
	return true
end
function AngelArena:OnPlayerBuyItem(event)
	local playerid = event.PlayerID

	AngelArena:SaveGoldForPlayerId(playerid,0)
end
function AngelArena:SaveGold(gold)
	TeamHelper:ApplyForPlayers( nil, function(pid)
		AngelArena:SaveGoldForPlayerId(pid,gold)
	end)
end
function AngelArena:SaveGoldForPlayerId(playerid,gold)
	if not PlayerResource:IsValidPlayerID(playerid) then return end

	local player_gold = PlayerResource:GetGold(playerid)

	local tPlayers = self.tPlayers

	if not tPlayers then
	  tPlayers = {}
	  self.tPlayers = tPlayers
	end

	if not IsAbadonedPlayerID(playerid) then
	  	tPlayers[playerid] = tPlayers[playerid] or {} -- nil error exception
	  	tPlayers[playerid].gold = tPlayers[playerid].gold or 0 -- nil error exception

	  	if player_gold > 50000 then
			local gold_to_save = player_gold - 50000
			tPlayers[playerid].gold = tPlayers[playerid].gold + gold_to_save
			PlayerResource:SpendGold(playerid, gold_to_save, 0)
	  	end

	  	if player_gold < 50000 then
			local free_gold = 50000 - player_gold
			local total_saved_gold = tPlayers[playerid].gold
			if total_saved_gold > free_gold then
			  tPlayers[playerid].gold = tPlayers[playerid].gold - free_gold
			  PlayerResource:ModifyGold(playerid, free_gold, true, 0)
			else
			  PlayerResource:ModifyGold(playerid, total_saved_gold, true, 0)
			  tPlayers[playerid].gold = 0
			end
	  	end

	  	local total_gold = PlayerResource:GetGold(playerid) + tPlayers[playerid].gold -- почему не player_gold? потому что золото игрока изменилось, а эта переменная нет :c

	  	CustomNetTables:SetTableValue("gold", "player_id_" .. playerid, { gold = total_gold })
	end
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
	if GameRules:State_Get() == DOTA_GAMERULES_STATE_PRE_GAME then
		print('DOTA_GAMERULES_STATE_PRE_GAME')
		local portals = {
			"teleport_radiant_top",
			"teleport_radiant_bot",
			"teleport_dire_top",
			"teleport_dire_bot",
		}
		
		
		local spawners = Entities:FindAllByClassname("npc_dota_neutral_spawner")

		for _, spawner in pairs(spawners) do
			UTIL_Remove(spawner)
		end
		print('remove spawner')

		for number,name in pairs(portals) do
			local spawnpoint = Entities:FindByName( nil, name )
			self.creep = nil
			if number <= 2 then
				self.creep = CreateUnitByName("npc_teleport", spawnpoint:GetAbsOrigin(), false, nil, nil, DOTA_TEAM_GOODGUYS)
				self.creep:SetMaterialGroup("0")
			end
			if number >= 3 then
				self.creep = CreateUnitByName("npc_teleport", spawnpoint:GetAbsOrigin(), false, nil, nil, DOTA_TEAM_BADGUYS)
				self.creep:SetMaterialGroup("1")
			end
			AddFOWViewer(DOTA_TEAM_GOODGUYS, self.creep:GetAbsOrigin(), 8, -1, true)
			AddFOWViewer(DOTA_TEAM_BADGUYS, self.creep:GetAbsOrigin(), 8, -1, true)
			self.creep:AddNewModifier(self.creep, nil,'modifier_mid_teleport', {duration = -1} )
		end
		print('initrotal')
		local player = PlayerResource:GetPlayerCount()
		local needkill = KILL_LIMIT_CONST / 10 * player
		KILL_LIMIT = needkill
		_G.KILL_LIMIT = needkill
		print('kl')
		CustomGameEventManager:Send_ServerToAllClients("MakeNeutralItemsInShopColored", {})

		Attentions:SetKillLimit( KILL_LIMIT )
		Bounty:Init()
		PauseGame(true)
		local towers = Entities:FindAllByClassname("npc_dota_tower")
		for _, tower in pairs(towers) do
			--print('1')
			tower:RemoveModifierByName("modifier_invulnerable")
			--local ability
			--for _,v in ipairs(tower:FindAllModifiers()) do
			--	print(v:GetName())
			--end
		end
		local teleports = Entities:FindAllByClassname("npc_dota_unit_twin_gate")
		print('telepooooooooort')
		for _, teleport in pairs(teleports) do
			print('telepooooooooort')
			teleport:RemoveModifierByName("modifier_invulnerable")
		end
	end

	if GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
		if not is_game_start then
			GameRules:SetTimeOfDay( 0.251 )
			CreepSpawner:StartSpawning()
			BossSpawner:OnGameStart()
			BearSpawner:SpawnBear()
			RepickMenu:init()
			Timers:CreateTimer(0.1, function()
				GPM_Init()
			end)
			Timers:CreateTimer(0.5, function()
				AngelArena:SaveGold(0)
				return 0.5
			end)
			Timers:CreateTimer(10, function()
				AngelArena:ShareGold()
				UpdatePlayersCount()
				return 10
			end)

			Timers:CreateTimer(0.5, function()
				BackPlayersToMap()
				return 0.5
			end)

			local rad, dire, total = GetActivePlayersPerTeam()

			had_players_on_both_teams = (rad > 0 and dire > 0)

			if (not duel_inited) and had_players_on_both_teams then
				DuelController:OnGameStart(function(winnerTeam)
					is_game_end = true
					DuelController:SetFreezeTimer(true)
					GameEnder:ForceEnd(winnerTeam)
				end)
				duel_inited = true
			else
				print(string.format("[Duel] not started: rad=%d dire=%d total=%d", rad, dire, total))
			end

			is_game_start = true
		end
	end
end
function AngelArena:IsUnitBear(unit)
	if not unit or not IsValidEntity(unit) then return false end
	local unit_name = unit:GetUnitName()
	if unit_name == "npc_dota_lone_druid_bear1" or unit_name == "npc_dota_lone_druid_bear2"
			or unit_name == "npc_dota_lone_druid_bear3" or unit_name == "npc_dota_lone_druid_bear4"
			 or unit_name == "npc_dota_lone_druid_bear5" or unit_name == "npc_dota_lone_druid_bear6"
			 or unit_name == "npc_dota_lone_druid_bear7" then
		return true
	end

	return false
end
local pickedCustomHero= {}
function AngelArena:OnNPCSpawned(keys)
	local npc = EntIndexToHScript(keys.entindex)
	local spawnedUnit = EntIndexToHScript(keys.entindex)
	if not npc then return end
	local unitname = npc:GetUnitName()
	local unit_owner = npc:GetOwnerEntity()
	if npc.bFirstSpawned == nil then
		npc.bFirstSpawned = true
		if hero_table[unitname]then
			--npc:AddItemByName("item_repick_hero")
		end
		if npc:IsRealHero()then
			npc:AddNewModifier(npc, nil, "modifier_aa_hero", {duration = -1})
			npc:AddAbility("divine_intervention")
			if npc:HasAbility("twin_gate_portal_warp") == true then
                npc:RemoveAbility("twin_gate_portal_warp");
            end
			--npc:AddNewModifier(npc, nil, "modifier_bat", {duration = -1})
		end
		if npc:IsIllusion() then
			local player = PlayerResource:GetSelectedHeroEntity( npc:GetPlayerOwnerID() )
			npc:AddNewModifier(npc, nil, "modifier_aa_hero", {duration = -1})
			npc:AddNewModifier(npc, nil, "bonus_str_tome", {duration = -1}):SetStackCount(player:FindModifierByName('bonus_str_tome'):GetStackCount())
			npc:AddNewModifier(npc, nil, "bonus_agi_tome", {duration = -1}):SetStackCount(player:FindModifierByName('bonus_agi_tome'):GetStackCount())
			npc:AddNewModifier(npc, nil, "bonus_int_tome", {duration = -1}):SetStackCount(player:FindModifierByName('bonus_int_tome'):GetStackCount())

		end
	end
	if npc:IsRealHero() then
		Timers:CreateTimer(10, function()
			if npc:HasModifier("modifier_fountain_invulnerability") then
				npc:RemoveAllModifiersByName("modifier_fountain_invulnerability")
			end
		end)
	end
	if spawnedUnit:IsIllusion() and spawnedUnit:IsHero() then
		local playerid = spawnedUnit:GetPlayerOwnerID()

		if playerid ~= nil and playerid ~= -1 then
			local original_hero = PlayerResource:GetSelectedHeroEntity( playerid )

			if original_hero and not original_hero:IsNull() then
				if not illusion_bug_crash[spawnedUnit:GetUnitName()] then
					local ability
					for i = 0, spawnedUnit:GetAbilityCount() - 1 do
						ability = spawnedUnit:GetAbilityByIndex(i)
						if ability then spawnedUnit:RemoveAbility(ability:GetAbilityName()) end
					end

					for i = 0, original_hero:GetAbilityCount() - 1 do
						ability = original_hero:GetAbilityByIndex(i)
						if ability then spawnedUnit:AddAbility(ability:GetAbilityName()) end
					end
				end

				local str = original_hero:GetBaseStrength() - (original_hero:GetLevel() - 1) * original_hero:GetStrengthGain()
				local agi = original_hero:GetBaseAgility() - (original_hero:GetLevel() - 1) * original_hero:GetAgilityGain()
				local int = original_hero:GetBaseIntellect() - (original_hero:GetLevel() - 1) * original_hero:GetIntellectGain()

				spawnedUnit:SetBaseStrength(str)
				spawnedUnit:SetBaseIntellect(int)
				spawnedUnit:SetBaseAgility(agi)
				spawnedUnit:AddNewModifier(npc, nil, "modifier_intelect", {duration = -1})
				if original_hero.medical_tractates then
					spawnedUnit.medical_tractates = original_hero.medical_tractates
					spawnedUnit:AddNewModifier(spawnedUnit, nil, "modifier_medical_tractate", { duration = -1})
				end
			end
		end
	end

	for i = 1, 7 do
		local f_name = "npc_dota_venomancer_plague_ward_" .. tostring(i)
		if unitname == f_name then
			local poison_ability_venom = spawnedUnit:GetOwner():FindAbilityByName("venomancer_poison_sting")
			if poison_ability_venom:GetLevel() > 0 then
				local poison_ability = spawnedUnit:FindAbilityByName("venomancer_poison_sting")
				if poison_ability then
					poison_ability:SetLevel(poison_ability_venom:GetLevel())
				end
			end
		end
	end

	if AngelArena:IsUnitBear(spawnedUnit) then
		spawnedUnit:AddNewModifier(npc, nil, "modifier_intelect", {duration = -1})
		local ability

		local bear_abilities =
		{
			["separation_of_souls_bear"] = 1,
			["lone_druid_spirit_bear_defender"] = 1,
		}

		for i = 0, spawnedUnit:GetAbilityCount() - 1 do
			ability = spawnedUnit:GetAbilityByIndex(i)

			if ability and bear_abilities[ability:GetName()] then
				ability:SetLevel(1)
			end
		end
	end

	if armor_table[unitname] then -- see file creeps/armor_table_summon.lua for details
		spawnedUnit:AddNewModifier(spawnedUnit, nil, armor_table[unitname], {})
		spawnedUnit:AddAbility("summon_cleave")
		local ability = spawnedUnit:FindAbilityByName("summon_cleave")
		ability:SetLevel(1)
	end

	if spawnedUnit:IsRealHero() then --print(spawnedUnit:GetUnitName())
		Timers:CreateTimer(0.15, function()
			if not spawnedUnit or spawnedUnit:IsNull() or not IsValidEntity(spawnedUnit) or not spawnedUnit:IsRealHero() then return nil end
			if spawnedUnit:GetUnitName() == "npc_dota_hero_arc_warden" then
				if spawnedUnit:HasModifier("modifier_arc_warden_tempest_double") then

					if not spawnedUnit:HasModifier("modifier_kill") then
						UTIL_Remove(spawnedUnit)
					else

						local real_hero = spawnedUnit:GetPlayerOwner():GetAssignedHero()

						if not spawnedUnit:HasModifier("modifier_kill") then
							UTIL_Remove(spawnedUnit)
						end

						if real_hero then
							local att = real_hero:GetBaseStrength()
							spawnedUnit:SetBaseStrength(att)
							att = real_hero:GetBaseAgility()
							spawnedUnit:SetBaseAgility(att)
							att = real_hero:GetBaseIntellect()
							spawnedUnit:SetBaseIntellect(att)

							local owner_team = real_hero:GetTeamNumber()

							if owner_team then spawnedUnit:SetTeam(owner_team) end

							for i = 0, 5 do
								if spawnedUnit:GetItemInSlot(i) and forbidden_items_for_clones[spawnedUnit:GetItemInSlot(i):GetName()] then
									spawnedUnit:RemoveItem(spawnedUnit:GetItemInSlot(i))
								end
							end

							if real_hero.medical_tractates then
								spawnedUnit.medical_tractates = real_hero.medical_tractates
								spawnedUnit:RemoveModifierByName("modifier_medical_tractate")
								spawnedUnit:AddNewModifier(spawnedUnit, nil, "modifier_medical_tractate", { duration = -1 })
							end
						end
					end
				end
			end
			return nil
		end)
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
		BearSpawner:InitDeath()
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

	if dead_hero:HasInventory() and dead_hero.IsReincarnating and not dead_hero:IsReincarnating() then
		local item
		for i = 0, 8 do
			item = dead_hero:GetItemInSlot(i)

			if item and (item:GetName() == "item_unknown_amulet") then
					item:SetCurrentCharges(item:GetCurrentCharges() - (item:GetCurrentCharges() * 0.3) )
			end
		end
	end
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

				local divine_intervention = attacker:FindAbilityByName("divine_intervention")

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
					inflictor = divine_intervention
				}

				local status, res = pcall(callback, callback_data)
				if victim ~= attacker then
					if status and res then
						ApplyDamage({
                            victim = victim,
                            attacker = attacker,
                            damage = res,
                            damage_type = damagetype_const,
                            ability = divine_intervention
						})
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
	local player_id = ord.issuer_player_id_const
	local unit

	if ord.units and ord.units["0"] then
        unit = EntIndexToHScript(ord.units["0"])
    end

	if not player then return true end

    local hero = player:GetAssignedHero()

    if not hero then return true end
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
					else
						print('cd')
						CustomGameEventManager:Send_ServerToPlayer(player, "CreateIngameErrorMessage", {message = "#midteleport_cd"})
					end
				else
					print("range")
					CustomGameEventManager:Send_ServerToPlayer(player, "CreateIngameErrorMessage", {message = "#midteleport_distance"})
				end
				return false
			end

			if ord.order_type == DOTA_UNIT_ORDER_CAST_TARGET  then
				if target:GetUnitName() == "npc_teleport" then
					print('error2')
					return false
				end
			end
		end

		if ord.order_type == DOTA_UNIT_ORDER_CAST_TARGET then
			local ability = EntIndexToHScript(ord.entindex_ability)
			local target = EntIndexToHScript(ord.entindex_target)
			local target_id = target:GetPlayerOwnerID()

			if PlayerResource:IsDisableHelpSetForPlayerID(target_id, player_id) then
				return UF_FAIL_DISABLE_HELP
			end

			if forbidden_ability_boss[ability:GetName()] and BossSpawner:IsBoss(target) then
				return UF_FAIL_DISABLE_HELP
			end

			if target:HasAbility("wisp_tether") and ability:GetName() == "wisp_tether" then return end

			if unit and target == unit and ability:GetName() == "rubick_spell_steal" then
				return UF_FAIL_DISABLE_HELP
			end
		end
	return true
end


function AngelArena:OnPlayerUsedAbility(event)
	local player = PlayerResource:GetPlayer(event.PlayerID)
	local ability_name = event.abilityname
	if not player or not ability_name or not IsValidEntity(player) then return end
	local hero = PlayerResource:GetSelectedHeroEntity(event.PlayerID)

	if not hero then return end

	if crash_abilities[ability_name] then
		player.crash_timer = 6.0
		Timers:CreateTimer(1.0, function()

			if player.crash_timer == nil or player.crash_timer <= 0 then
				player.crash_timer = nil;
				return nil;
			end
			player.crash_timer = player.crash_timer - 1

			return 1.0
		end)
	end
end

local function GetActivePlayersPerTeam()
    local rad = 0
    local dire = 0
    local total = 0

    TeamHelper:ApplyForPlayers(nil, function(playerid)
        if IsAbadonedPlayerID(playerid) then return end
        if not PlayerResource:IsConnected(playerid) then return end

        local team = PlayerResource:GetTeam(playerid)
        if team == DOTA_TEAM_GOODGUYS then
            rad = rad + 1
            total = total + 1
        elseif team == DOTA_TEAM_BADGUYS then
            dire = dire + 1
            total = total + 1
        end
    end)

    return rad, dire, total
end

_G.inited = true