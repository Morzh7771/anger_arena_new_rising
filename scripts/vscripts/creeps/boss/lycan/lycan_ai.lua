require('lib/ai/simple_ai')
require('creeps/boss/boss_kit')

-- Ликан: волки, если их нет; вой, когда рядом герои; в форме волка - прыжок.

local function Heroes(enemies)
	local res = {}
	for _, e in pairs(enemies) do if e:IsHero() then table.insert(res, e) end end
	return res
end

local function Wolves(caster, ability, enemies)
	if #Heroes(enemies) == 0 then return false end
	for _, w in pairs(caster.aa_wolves or {}) do
		if w and not w:IsNull() and w:IsAlive() then return false end
	end
	caster:CastAbilityNoTarget(ability, -1)
	return true
end

local function Howl(caster, ability, enemies)
	local r = ability:GetSpecialValueFor("radius")
	for _, h in pairs(Heroes(enemies)) do
		if (h:GetAbsOrigin() - caster:GetAbsOrigin()):Length2D() <= r then
			caster:CastAbilityNoTarget(ability, -1)
			return true
		end
	end
	return false
end

local function Pounce(caster, ability, enemies)
	if not caster:HasModifier("modifier_lycan_boss_shapeshift") then return false end
	for _, h in pairs(Heroes(enemies)) do
		local d = (h:GetAbsOrigin() - caster:GetAbsOrigin()):Length2D()
		if d > 250 and d <= ability:GetCastRange(caster:GetAbsOrigin(), h) then
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
		SimpleAIActions.Ability:Make(unit, unit:FindAbilityByName("lycan_boss_wolves"), Wolves),
		SimpleAIActions.Ability:Make(unit, unit:FindAbilityByName("lycan_boss_pounce"), Pounce),
		SimpleAIActions.Ability:Make(unit, unit:FindAbilityByName("lycan_boss_howl"),   Howl),
		SimpleAIActions.Attack:Make(unit),
		SimpleAIActions.Back:Make(unit),
	})
end
