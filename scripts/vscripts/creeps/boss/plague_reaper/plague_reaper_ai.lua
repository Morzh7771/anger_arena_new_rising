require('lib/ai/simple_ai')
require('creeps/boss/boss_kit')

-- Чумной Жнец: метка на самом слабом, волна, когда герои рядом.

local TICK = 0.1
local AOI  = 800

local function Mark(caster, ability, enemies)
	if not ability:HasVictim() then return false end
	caster:CastAbilityNoTarget(ability, -1)
	return true
end

-- покров - только когда на нём висят дебафы
local function Shroud(caster, ability, enemies)
	if not BossKit:HasDebuffs(caster) then return false end
	caster:CastAbilityNoTarget(ability, -1)
	return true
end

local function Wave(caster, ability, enemies)
	local range = ability:GetSpecialValueFor("range")
	for _, e in pairs(enemies) do
		if e:IsHero() and (e:GetAbsOrigin() - caster:GetAbsOrigin()):Length2D() <= range then
			caster:FaceTowards(e:GetAbsOrigin())
			caster:CastAbilityNoTarget(ability, -1)
			return true
		end
	end
	return false
end

function Spawn(entityKeyValues)
	if not IsServer() then return end
	local unit = thisEntity

	SimpleAI:Make(unit, TICK, AOI, {
		SimpleAIActions.ForceBack:Make(unit),
		SimpleAIActions.Ability:Make(unit, unit:FindAbilityByName("plague_reaper_shroud"), Shroud),
		SimpleAIActions.Ability:Make(unit, unit:FindAbilityByName("plague_reaper_mark"), Mark),
		SimpleAIActions.Ability:Make(unit, unit:FindAbilityByName("plague_reaper_wave"), Wave),
		SimpleAIActions.Attack:Make(unit),
		SimpleAIActions.Back:Make(unit),
	})
end
