if not IsServer() then return end
require('lib/base_lua_helpers')
LinkLuaModifier("modifier_stuck_count", 'lib/spawners/modifier_stuck_count', LUA_MODIFIER_MOTION_NONE)
BearSpawner = BearSpawner or class({})
local spawner_name = 'target_mark_spawner_jungle_type0'
local CREEP_RANDOM_OFFSET = 50
local death = 0
function emptyFunc(...)
end 

function BearSpawner:Init()
	self.onDeathCallbacks = {}
    
end 
function BearSpawner:GetSpawner()
    local entity = Entities:FindByName( nil, spawner_name )
    if not entity then 
        print( "Failed to parse point, there is not point on map, point =", spawner_name )
    else 
        local spawner_info = { 	name = spawner_name, 
                                pos = entity:GetAbsOrigin(),
                                direction = entity:GetForwardVector(),
                                spawner_type = 'bear' }
        return spawner_info
    end
    return nil
end
function BearSpawner:SpawnBear()
    local spawner = BearSpawner:GetSpawner()
    if spawner == nil then
        print('error404notfound')
    end
    for i=1,3 do
        local offset = RandomVector( CREEP_RANDOM_OFFSET )
        local spawner_pos = spawner.pos + offset
        local creep = CreateUnitByName("npc_aa_creep_centaur_big", spawner_pos, true, nil, nil, DOTA_TEAM_NEUTRALS)
        creep:AddNewModifier(creep, nil,'modifier_stuck_count', {duration = -1} ):SetStackCount(death)
    end
end
function BearSpawner:ReSpawnBear()
    local spawner = BearSpawner:GetSpawner()
    if spawner == nil then
        print('error404notfound')
    end
    local offset = RandomVector( CREEP_RANDOM_OFFSET )
    local spawner_pos = spawner.pos + offset
    local creep = CreateUnitByName("npc_aa_creep_centaur_big", spawner_pos, true, nil, nil, DOTA_TEAM_NEUTRALS)
    creep:AddNewModifier(creep, nil,'modifier_stuck_count', {duration = -1} ):SetStackCount(death)
    if death < math.floor(GameRules:GetDOTATime( false, false ) / 60 * 5) then
        death = death + 1
    end
    print(death)
    creep:SetDeathXP( death * 2 )
	creep:SetMinimumGoldBounty( death * 0.4 )
	creep:SetMaximumGoldBounty( death * 0.5 )

	creep:SetBaseMaxHealth( creep:GetMaxHealth() + death * 25 )
	creep:SetMaxHealth( creep:GetMaxHealth() + death * 25 )
	--creep:SetMaxMana( death * 5 )

	creep:SetPhysicalArmorBaseValue( death * 0.2 )
	--creep:SetBaseAttackTime( death * 10 )
	creep:SetBaseDamageMin( death * 1.3 )
	creep:SetBaseDamageMax( death * 1.5 )

	--creep:SetMana( creep:GetMaxMana() )
	creep:SetHealth( creep:GetMaxHealth() )
end


