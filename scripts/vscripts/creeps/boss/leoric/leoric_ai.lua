require('lib/ai/simple_ai')

-- Король-Мертвец: удар по тем, кто вплотную, кольцо костей, когда рядом
-- враги, веер черепов в цель подальше.

local TICK = 0.1
local AOI  = 800

local function Slam(caster, ability, enemies)
	local r = ability:GetSpecialValueFor("offset") + ability:GetSpecialValueFor("radius")
	for _, e in pairs(enemies) do
		if e:IsHero() and (e:GetAbsOrigin() - caster:GetAbsOrigin()):Length2D() <= r then
			caster:FaceTowards(e:GetAbsOrigin())
			caster:CastAbilityNoTarget(ability, -1)
			return true
		end
	end
	return false
end

local function Ring(caster, ability, enemies)
	local heroes = 0
	for _, e in pairs(enemies) do
		if e:IsHero() then heroes = heroes + 1 end
	end
	if heroes == 0 then return false end
	caster:CastAbilityNoTarget(ability, -1)
	return true
end

local function Fan(caster, ability, enemies)
	local range = ability:GetSpecialValueFor("range")
	for _, e in pairs(enemies) do
		if e:IsHero() and (e:GetAbsOrigin() - caster:GetAbsOrigin()):Length2D() <= range then
			caster:CastAbilityOnPosition(e:GetAbsOrigin(), ability, -1)
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
		SimpleAIActions.Ability:Make(unit, unit:FindAbilityByName("leoric_grave_slam"), Slam),
		SimpleAIActions.Ability:Make(unit, unit:FindAbilityByName("leoric_bone_ring"),  Ring),
		SimpleAIActions.Ability:Make(unit, unit:FindAbilityByName("leoric_hellfire_fan"), Fan),
		SimpleAIActions.Attack:Make(unit),
		SimpleAIActions.Back:Make(unit),
	})
end
