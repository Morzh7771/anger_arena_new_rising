require('lib/ai/simple_ai')

-- Хранитель Часов: тень, как только начался бой и он ранен; хроносфера
-- в гущу героев; рывок сквозь дальнего героя.

local TICK = 0.1
local AOI  = 800

local function Heroes(enemies)
	local res = {}
	for _, e in pairs(enemies) do
		if e:IsHero() then table.insert(res, e) end
	end
	return res
end

local function Shadow(caster, ability, enemies)
	if #Heroes(enemies) == 0 then return false end
	if caster:GetHealthPercent() > 97 then return false end
	caster:CastAbilityNoTarget(ability, -1)
	return true
end

-- центр самой густой группы: герой, вокруг которого больше всего других
local function Sphere(caster, ability, enemies)
	local heroes = Heroes(enemies)
	if #heroes == 0 then return false end

	local r = ability:GetSpecialValueFor("radius")
	local best, bestN = nil, 0
	for _, h in pairs(heroes) do
		local n = 0
		for _, o in pairs(heroes) do
			if (o:GetAbsOrigin() - h:GetAbsOrigin()):Length2D() <= r then n = n + 1 end
		end
		if n > bestN then best, bestN = h, n end
	end

	caster:CastAbilityOnPosition(best:GetAbsOrigin(), ability, -1)
	return true
end

local function Walk(caster, ability, enemies)
	local heroes = Heroes(enemies)
	local far, farD
	for _, h in pairs(heroes) do
		local d = (h:GetAbsOrigin() - caster:GetAbsOrigin()):Length2D()
		if d > 250 and (not farD or d > farD) then far, farD = h, d end
	end
	if not far then return false end

	-- целимся чуть за героя, чтобы линия прошла сквозь него
	local dir = (far:GetAbsOrigin() - caster:GetAbsOrigin()):Normalized()
	caster:CastAbilityOnPosition(far:GetAbsOrigin() + dir * 150, ability, -1)
	return true
end

function Spawn(entityKeyValues)
	if not IsServer() then return end
	local unit = thisEntity

	SimpleAI:Make(unit, TICK, AOI, {
		SimpleAIActions.ForceBack:Make(unit),
		SimpleAIActions.Ability:Make(unit, unit:FindAbilityByName("chronokeeper_shadow"), Shadow),
		SimpleAIActions.Ability:Make(unit, unit:FindAbilityByName("chronokeeper_sphere"), Sphere),
		SimpleAIActions.Ability:Make(unit, unit:FindAbilityByName("chronokeeper_walk"),   Walk),
		SimpleAIActions.Attack:Make(unit),
		SimpleAIActions.Back:Make(unit),
	})
end
