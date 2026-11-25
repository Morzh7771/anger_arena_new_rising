require('lib/ai/simple_ai')
require('creeps/boss/boss_kit')

-- Хускар: Vitality, когда на нём дебафы; Inner Fire, если вплотную;
-- Life Break в героя поодаль.

local function Heroes(enemies)
	local res = {}
	for _, e in pairs(enemies) do if e:IsHero() then table.insert(res, e) end end
	return res
end

local function Vitality(caster, ability, enemies)
	if not BossKit:HasDebuffs(caster) then return false end
	caster:CastAbilityNoTarget(ability, -1)
	return true
end

local function InnerFire(caster, ability, enemies)
	local r = ability:GetSpecialValueFor("radius") - 50
	for _, h in pairs(Heroes(enemies)) do
		if (h:GetAbsOrigin() - caster:GetAbsOrigin()):Length2D() <= r then
			caster:CastAbilityNoTarget(ability, -1)
			return true
		end
	end
	return false
end

local function LifeBreak(caster, ability, enemies)
	for _, h in pairs(Heroes(enemies)) do
		local d = (h:GetAbsOrigin() - caster:GetAbsOrigin()):Length2D()
		if d > 300 and d <= ability:GetCastRange(caster:GetAbsOrigin(), h) then
			caster:CastAbilityOnTarget(h, ability, -1)
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
		SimpleAIActions.Ability:Make(unit, unit:FindAbilityByName("huskar_boss_inner_vitality"), Vitality),
		SimpleAIActions.Ability:Make(unit, unit:FindAbilityByName("huskar_boss_inner_fire"),     InnerFire),
		SimpleAIActions.Ability:Make(unit, unit:FindAbilityByName("huskar_boss_life_break"),     LifeBreak),
		SimpleAIActions.Attack:Make(unit),
		SimpleAIActions.Back:Make(unit),
	})
end
