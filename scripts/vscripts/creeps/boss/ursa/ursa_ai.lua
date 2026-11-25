require('lib/ai/simple_ai')
require('creeps/boss/boss_kit')

-- Урса: Enrage, когда на ней дебафы; Earthshock, когда герои вплотную.

local function Enrage(caster, ability, enemies)
	if not BossKit:HasDebuffs(caster) then return false end
	caster:CastAbilityNoTarget(ability, -1)
	return true
end

local function Earthshock(caster, ability, enemies)
	local r = ability:GetSpecialValueFor("radius") - 50
	for _, e in pairs(enemies) do
		if e:IsHero() and (e:GetAbsOrigin() - caster:GetAbsOrigin()):Length2D() <= r then
			caster:CastAbilityNoTarget(ability, -1)
			return true
		end
	end
	return false
end

function Spawn(entityKeyValues)
	if not IsServer() then return end
	local unit = thisEntity
	SimpleAI:Make(unit, 0.1, 800, {
		SimpleAIActions.ForceBack:Make(unit),
		SimpleAIActions.Ability:Make(unit, unit:FindAbilityByName("ursa_boss_enrage"),     Enrage),
		SimpleAIActions.Ability:Make(unit, unit:FindAbilityByName("ursa_boss_earthshock"), Earthshock),
		SimpleAIActions.Attack:Make(unit),
		SimpleAIActions.Back:Make(unit),
	})
end
