--[[
Cheat lobby commands
 -spawnCreeps, -sc      	-- spawn creeps on map. 
 -enableCreepSpawn			-- enable creep spawning 
 -disableCreepSpawn			-- disable creep spawning 
 -is_cheats 				-- is cheats enabled 
 -addmod modifier_name 10 	-- adding modifier with name 'modifier_name' and duration '10'sec
 -remmod modifier_name		-- removing modifier with name 'modifier_name'
 -str 100					-- set base hero strength to 100
 -agi 100					-- set base hero agility to 100
 -int 100					-- set base hero intellect to 100 
 -cb 
]]

Commands = Commands or class({})

function Commands:is_cheats( player, arg )
	force_print("Cheats enable state is:", GameRules:IsCheatMode())
end 

------------------------------------------------------------------------------------------------------------

if not GameRules:IsCheatMode() then 
	return 
end 

require('lib/attentions')
require('lib/utils')
require('lib/duel/duel_controller')
require("lib/spawners/creep_spawner")
require('lib/boss/boss_spawner')

function Commands:ds(player, arg)
	DuelController:StartDuel()
end

function Commands:duel_start(player, arg)
	DuelController:StartDuel()
end

function Commands:de(player, arg)
	DuelController:StopDuel()
end
function Commands:duel_end(player, arg)
	DuelController:StopDuel()
end

function Commands:dt(player, arg)
	DuelController:ToggleDuel()
end

function Commands:duel_toggle(player, arg)
	DuelController:ToggleDuel()
end

function Commands:df( player, arg )
	local val = arg[1]

	if val == nil then
		val = not DuelController:GetFreezeTimer()
	else
		val = val == "1"
	end

	DuelController:SetFreezeTimer( val )
end

function Commands:duel_freeze( player, arg )
	local val = arg[1]

	if val == nil then
		val = not DuelController:GetFreezeTimer()
	else
		val = val == "1"
	end

	DuelController:SetFreezeTimer( val )
end

function Commands:dtime( player, arg )
	local time = arg[1]

	if not time then
		Attentions:SendChatMessage( "Time until duel event: " .. tostring(DuelController:GetTime()) )
	else
		DuelController:SetTime( tonumber(time) )
	end
end

function Commands:duel_time( player, arg )
	local time = arg[1]

	if not time then
		Attentions:SendChatMessage( "Time until duel event: " .. tostring(DuelController:GetTime()) )
	else
		DuelController:SetTime( tonumber(time) )
	end
end

function Commands:spawn_creeps( player, arg )
	CreepSpawner:SpawnCreeps() 
end

function Commands:sc( player, arg ) self:spawn_creeps( player, arg ); end 


function Commands:disable_creeps_spawn(player, arg)
	CreepSpawner:SetEnable(false) 
end 

function Commands:spawn_bosses( player, arg )
	BossSpawner:ForBossClass(function(boss)
		if BossSpawner:IsBossAlive(boss.name) then return end

		BossSpawner:SpawnBoss(boss)
	end)
end

Commands.sb = Commands.spawn_bosses

function Commands:enable_creeps_spawn(player, arg)
	CreepSpawner:SetEnable(true) 
end 

function Commands:addmod(player, arg)
	local hero 			= player:GetAssignedHero() 
	local modifierName 	= arg[1]
	local duration 		= arg[2]

	hero:AddNewModifier(hero, nil, modifierName, { duration = duration }) 
end

function Commands:dev(player, arg)
	local hero 			= player:GetAssignedHero()
	hero:SetBaseIntellect( 10000 ) -- :kekw:
	hero:SetBaseAgility( 10000 )
	hero:SetBaseStrength( 10000 )
	hero:CalculateStatBonus( true )
	hero:AddItemByName("item_boss_soul")
	hero:AddItemByName("item_boss_soul")
	hero:AddItemByName("item_boss_soul")
end
function Commands:fb(player, arg)
	local hero 			= player:GetAssignedHero()
	hero:SetBaseIntellect( 100000 )
	hero:SetBaseAgility( 100000 )
	hero:SetBaseStrength( 100000 )
	hero:AddItemByName("item_desolator_aa_3")
	hero:AddItemByName("item_trisula")
	hero:AddItemByName("item_satanic_3")
end
function Commands:ggf(player, arg)
	local hero 			= player:GetAssignedHero()
	hero:AddItemByName("item_burning_butterfly")
	hero:AddItemByName("item_trisula")
	hero:AddItemByName("item_disperser_aa_3")
	hero:AddItemByName("item_snake_boots")
	hero:AddItemByName("item_trident_aa")
	hero:AddItemByName("item_swift_blink_2")
	hero:AddItemByName("item_pirate_hat")
end
function Commands:alls(player, arg)
	if not player then return end
	MouseCursor:OnNearestUnit(player, function(unit)
		unit:SetBaseStrength( tonumber(arg[1]) )
		unit:SetBaseAgility( tonumber(arg[1]) )
		unit:SetBaseIntellect( tonumber(arg[1]) )
		unit:CalculateStatBonus( true )
	end)
end 

function Commands:remmod(player, arg)
	local hero 			= player:GetAssignedHero() 
	local modifierName 	= arg[1]
	hero:RemoveModifierByName(modifierName)
end 

function Commands:cd(player, arg)
	if not player then return end
	MouseCursor:OnCursorPosition(player:GetPlayerID(), function(position)
		-- double check cause call time is unknown, player might abandon
		if not player then return end
		local hero = player:GetAssignedHero()
		local target = CreateUnitByName( "npc_dota_hero_target_dummy", position, true, nil, nil, hero:GetOpposingTeamNumber() )
		target:SetAbilityPoints( 0 )
		target:SetControllableByPlayer( hero:GetPlayerOwnerID(), false )
		target:Hold()
		target:SetIdleAcquire( false )
		target:SetAcquisitionRange( 0 )
	end)
end

function Commands:create_dummy(player, arg)
	if not player then return end
	MouseCursor:OnCursorPosition(player:GetPlayerID(), function(position)
		-- double check cause call time is unknown, player might abandon
		if not player then return end
		local hero = player:GetAssignedHero()
		local target = CreateUnitByName( "npc_dota_hero_target_dummy", position, true, nil, nil, hero:GetOpposingTeamNumber() )
		target:SetAbilityPoints( 0 )
		target:SetControllableByPlayer( hero:GetPlayerOwnerID(), false )
		target:Hold()
		target:SetIdleAcquire( false )
		target:SetAcquisitionRange( 0 )
	end)
end


function Commands:str(player, arg)
	if not player then return end
	MouseCursor:OnNearestUnit(player, function(unit)
		unit:SetBaseStrength( tonumber(arg[1]) )
		unit:CalculateStatBonus( true )
	end)
end 

function Commands:agi(player, arg)
	if not player then return end
	MouseCursor:OnNearestUnit(player, function(unit)
		unit:SetBaseAgility( tonumber(arg[1]) )
		unit:CalculateStatBonus( true )
	end)
end 

function Commands:int(player, arg)
	if not player then return end
	MouseCursor:OnNearestUnit(player, function(unit)
		unit:SetBaseIntellect( tonumber(arg[1]) )
		unit:CalculateStatBonus( true )
	end)
end 
function Commands:sbd(player, arg)
	if not player then return end
	BearSpawner:SetDeath(tonumber(arg[1]))
end 

function Commands:rmana(player, arg)
	if not player then return end
	MouseCursor:OnNearestUnit(player, function(unit)
		unit:ReduceMana( tonumber(arg[1]) )
	end) 	
end

function Commands:nofog(player, arg)
	local GameMode = GameRules:GetGameModeEntity()
	GameMode:SetFogOfWarDisabled(true)
end

function Commands:sh(player, arg)
	PlayerResource:ReplaceHeroWith( player:GetPlayerID(), "npc_dota_hero_" .. arg[1], player:GetAssignedHero():GetGold(), 0 )
end
function Commands:switchhero(player, arg)
	PlayerResource:ReplaceHeroWith( player:GetPlayerID(), "npc_dota_hero_" .. arg[1], player:GetAssignedHero():GetGold(), 0 )
end

function Commands:fog(player, arg)
	local GameMode = GameRules:GetGameModeEntity()
	GameMode:SetFogOfWarDisabled(false)
end

function Commands:q(player, arg)
	local hero 			= player:GetAssignedHero()
	hero:AddItemByName("item_boss_soul")
	hero:AddItemByName("item_boss_soul")
	hero:AddItemByName("item_boss_soul")
	hero:AddItemByName("item_boss_soul")
	hero:AddItemByName("item_boss_soul")
	hero:AddItemByName("item_boss_soul")
	hero:AddItemByName("item_boss_soul")
	hero:AddItemByName("item_boss_soul")
	hero:SetGold(99999,false)
end

function Commands:cb(player, arg)
	if not player then return end
	MouseCursor:OnCursorPosition(player:GetPlayerID(), function(position)
		-- double check cause call time is unknown, player might abandon
		if not player then return end
		local hero = player:GetAssignedHero()
		hero:AddExperience(999999,0,true,true)
		hero:SetGold(9999999,false)
		local target = CreateUnitByName( "npc_dota_hero_axe", position, true, nil, nil, hero:GetOpposingTeamNumber() )
		target:SetControllableByPlayer( hero:GetPlayerOwnerID(), false )
		target:AddExperience(999999,0,true,true)
	end)
end