require('lib/ai/simple_ai')
require('creeps/boss/boss_kit')

-- Пудж: хук в дальнего; Dismember вплотную (он же еда и диспел).

local function Heroes(enemies)
	local res = {}
	for _, e in pairs(enemies) do if e:IsHero() then table.insert(res, e) end end
	return res
end

local function Hook(caster, ability, enemies)
	local range = ability:GetSpecialValueFor("range")
	local heroes = Heroes(enemies)
	for i = #heroes, 1, -1 do
		local h = heroes[i]
		local d = (h:GetAbsOrigin() - caster:GetAbsOrigin()):Length2D()
		if d > 300 and d < range then
			caster:CastAbilityOnPosition(h:GetAbsOrigin(), ability, -1)
			return true
		end
	end
	return false
end

local function Dismember(caster, ability, enemies)
	for _, h in pairs(Heroes(enemies)) do
		if (h:GetAbsOrigin() - caster:GetAbsOrigin()):Length2D() <= 200 then
			caster:CastAbilityOnTarget(h, ability, -1)
			return true
		end
	end
	return false
end

function Spawn(entityKeyValues)
	if not IsServer() then return end
	local unit = thisEntity
	SimpleAI:Make(unit, 0.1, 900, {
		SimpleAIActions.ForceBack:Make(unit),
		SimpleAIActions.Ability:Make(unit, unit:FindAbilityByName("pudge_boss_hook"),      Hook),
		SimpleAIActions.Ability:Make(unit, unit:FindAbilityByName("pudge_boss_dismember"), Dismember),
		SimpleAIActions.Attack:Make(unit),
		SimpleAIActions.Back:Make(unit),
	})
end
