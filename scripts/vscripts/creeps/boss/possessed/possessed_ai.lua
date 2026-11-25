require('lib/ai/simple_ai')

-- Possessed (Дум). Пассивные обратки убраны, всё через скиллы с разметкой:
-- рывок во врага поодаль, отброс тех, кто вплотную, огненные стены
-- в сторону героев, огненные круги под всеми, проклятие "беги".

TICK_TIME 			= 0.1
AOI_RANGE 			= 950

local function Heroes(enemies)
	local res = {}
	for _, e in pairs(enemies) do
		if e:IsHero() then table.insert(res, e) end
	end
	return res
end

local function Dist(a, b)
	return (a:GetAbsOrigin() - b:GetAbsOrigin()):Length2D()
end

function Spawn( entityKeyValues )
	if not IsServer() then return end

	local function PerformCurse(caster, ability, aoiEnemies)
		local casterPos = caster:GetAbsOrigin()
		local castRange = ability:GetCastRange(casterPos, nil) + caster:GetCastRangeBonus() - 25

		return AIHelpers:CastRangeFilter( aoiEnemies, casterPos, castRange, function(unit)
			if not AIHelpers:IsCastable(ability, unit) then return false end
			caster:CastAbilityOnTarget(unit, ability, -1)
			return true
		end)
	end

	local function PerformMagmaTrails(caster, ability, aoiEnemies)
		local casterPos = caster:GetAbsOrigin()
		local castRange = ability:GetCastRange(casterPos, nil) + caster:GetCastRangeBonus() - 50

		local nTargets = 0
		local casterHealth = caster:GetHealthPercent()

		return AIHelpers:CastRangeFilter( aoiEnemies, casterPos, castRange, function(unit)
			if not AIHelpers:IsCastable(ability, unit) then return false end

			nTargets = nTargets + 1

			if nTargets > 2 or casterHealth < 80 then
				caster:CastAbilityNoTarget(ability, -1)
				return true
			end

			return false
		end)
	end

	-- отброс: кто-то стоит вплотную
	local function PerformSweep(caster, ability, aoiEnemies)
		local r = ability:GetSpecialValueFor("radius") - 50
		for _, h in pairs(Heroes(aoiEnemies)) do
			if Dist(caster, h) <= r then
				caster:CastAbilityNoTarget(ability, -1)
				return true
			end
		end
		return false
	end

	-- рывок: в героя поодаль
	local function PerformCharge(caster, ability, aoiEnemies)
		local far = ability:GetSpecialValueFor("distance")
		for _, h in pairs(Heroes(aoiEnemies)) do
			local d = Dist(caster, h)
			if d >= 350 and d <= far then
				caster:CastAbilityOnPosition(h:GetAbsOrigin(), ability, -1)
				return true
			end
		end
		return false
	end

	-- стены: развернуться к ближайшему герою и пустить волны
	local function PerformFlameWall(caster, ability, aoiEnemies)
		local heroes = Heroes(aoiEnemies)
		if #heroes == 0 then return false end
		caster:FaceTowards(heroes[1]:GetAbsOrigin())
		caster:CastAbilityNoTarget(ability, -1)
		return true
	end

	local unit = thisEntity

	local function Act(name, fn)
		local ab = unit:FindAbilityByName(name)
		if ab then return SimpleAIActions.Ability:Make(unit, ab, fn) end
	end

	local actions = { SimpleAIActions.ForceBack:Make(unit) }

	-- порядок важен: первым проверяется отброс, последним проклятие
	local order = {
		{ "possessed_sweep",        PerformSweep },
		{ "possessed_charge",       PerformCharge },
		{ "possessed_flame_wall",   PerformFlameWall },
		{ "possessed_magma_trails", PerformMagmaTrails },
		{ "possessed_curse",        PerformCurse },
	}

	for i = 1, #order do
		local a = Act(order[i][1], order[i][2])
		if a then table.insert(actions, a) end
	end

	table.insert(actions, SimpleAIActions.Attack:Make(unit))
	table.insert(actions, SimpleAIActions.Back:Make(unit))

	SimpleAI:Make( unit, TICK_TIME, AOI_RANGE, actions )
end
