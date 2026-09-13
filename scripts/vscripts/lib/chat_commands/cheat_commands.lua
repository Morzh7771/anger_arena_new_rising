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
 -perf                  -- счётчики нагрузки: крипы, лагеря, таймеры
 -wipeCreeps, -wc       -- убить всех крипов лагерей (A/B тест по фпс)
 -campsleep 0|1         -- вкл/выкл сон лагерей
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
require("lib/spawners/camp_sleep")
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

-- ReplaceHeroWith без прекеша даёт error-модель и способности без партиклов:
-- ресурсы нового героя на этот момент ещё не загружены. Ждём PrecacheUnitByNameAsync,
-- как это уже сделано в lib/hero_change.lua
local function _SwitchHeroPrecached(player, heroName)
	if not player then return end

	local hero = player:GetAssignedHero()

	if not hero or hero:IsNull() then return end

	local playerid = player:GetPlayerID()
	local gold = hero:GetGold()
	-- Четвёртый аргумент ReplaceHeroWith - опыт: без него герой первого уровня.
	local xp = hero:GetCurrentXP() or 0

	PrecacheUnitByNameAsync(heroName, function()
		PlayerResource:ReplaceHeroWith( playerid, heroName, gold, xp )
	end, playerid)
end

function Commands:sh(player, arg)
	_SwitchHeroPrecached( player, "npc_dota_hero_" .. arg[1] )
end
function Commands:switchhero(player, arg)
	_SwitchHeroPrecached( player, "npc_dota_hero_" .. arg[1] )
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
------------------------------------------------------------------------------------------------------------
-- ЗАМЕРЫ ПРОИЗВОДИТЕЛЬНОСТИ
--
-- Нужны, чтобы не гадать, откуда просадка. Порядок работы:
--   1) доиграть до момента, когда фпс просел (обычно 8-10 минута);
--   2) -perf   - записать числа;
--   3) -wc     - выпилить всех крипов лагерей и посмотреть на фпс;
--   4) если фпс вернулся - виноваты крипы, дальше крутим -campsleep;
--      если нет - копать надо не там, крипы ни при чём.
------------------------------------------------------------------------------------------------------------

function Commands:perf(player, arg)
	local aliveCreeps = 0

	for idx, _ in pairs(CreepSpawner._unitMetaByEntindex or {}) do
		local u = EntIndexToHScript(idx)
		if u and not u:IsNull() and u:IsAlive() then
			aliveCreeps = aliveCreeps + 1
		end
	end

	local timers = 0
	for _, _ in pairs(Timers.timers or {}) do timers = timers + 1 end

	local camps, sleeping, tracked, asleepUnits = CampSleep:GetStats()

	force_print("[perf] ---------------------------------------")
	force_print("[perf] время:", string.format("%.1f", GameRules:GetDOTATime(false, false) / 60), "мин")
	force_print("[perf] живых крипов лагерей:", aliveCreeps)
	force_print("[perf] лагерей под учётом:", camps, "из них спят:", sleeping)
	force_print("[perf] крипов под учётом:", tracked, "из них спят:", asleepUnits)
	force_print("[perf] активных lua-таймеров:", timers)
	force_print("[perf] сон лагерей включён:", tostring(CampSleep:GetEnabled()))
	force_print("[perf] ---------------------------------------")
end

-- убить всех крипов лагерей: A/B-тест "виноваты ли крипы"
function Commands:wipe_creeps(player, arg)
	-- снимок индексов: ForceKill дёргает entity_killed, который правит
	-- ту самую таблицу, по которой мы идём
	local indexes = {}
	for idx, _ in pairs(CreepSpawner._unitMetaByEntindex or {}) do
		indexes[#indexes + 1] = idx
	end

	local killed = 0
	for _, idx in pairs(indexes) do
		local u = EntIndexToHScript(idx)
		if u and not u:IsNull() and u:IsAlive() then
			u:ForceKill(false)
			killed = killed + 1
		end
	end

	force_print("[perf] убито крипов лагерей:", killed)
end

function Commands:wc(player, arg) self:wipe_creeps(player, arg); end

-- -campsleep 0 / -campsleep 1
function Commands:campsleep(player, arg)
	local val = arg and arg[1]

	if val == nil then
		CampSleep:SetEnabled(not CampSleep:GetEnabled())
	else
		CampSleep:SetEnabled(val ~= "0" and val ~= "false")
	end

	force_print("[perf] сон лагерей:", tostring(CampSleep:GetEnabled()))
end
