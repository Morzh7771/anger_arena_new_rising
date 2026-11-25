-- Hola: Divine Retribution (врождённая). Когда Хола лечит союзника, ближайший к нему враг
-- (в радиусе radius) получает чистый урон: (damage_pct + damage_per_level × уровень)% от лечения.
-- Зовётся из hola_grace.lua и hola_stomp.lua через HolaRetribution(caster, target, heal).

hola_divine_retribution = class({})

function hola_divine_retribution:Precache(context)
	PrecacheResource("particle", "particles/units/heroes/hero_omniknight/omniknight_purification_hit.vpcf", context)
end

function HolaRetribution(caster, target, heal)
	if not caster or caster:IsNull() or not target or target:IsNull() or not heal or heal <= 0 then return end

	local ability = caster:FindAbilityByName("hola_divine_retribution")
	if not ability or caster:PassivesDisabled() then return end

	local enemies = FindUnitsInRadius(caster:GetTeamNumber(), target:GetAbsOrigin(), nil, ability:GetSpecialValueFor("radius"),
		DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC, DOTA_UNIT_TARGET_FLAG_NONE, FIND_CLOSEST, false)

	local enemy = enemies[1]
	if not enemy then return end

	local pct = ability:GetSpecialValueFor("damage_pct") + ability:GetSpecialValueFor("damage_per_level") * caster:GetLevel()

	ApplyDamage({
		victim		= enemy,
		attacker	= caster,
		damage		= heal * pct / 100,
		damage_type	= DAMAGE_TYPE_PURE,
		ability		= ability,
	})

	local pfx = ParticleManager:CreateParticle("particles/units/heroes/hero_omniknight/omniknight_purification_hit.vpcf", PATTACH_ABSORIGIN_FOLLOW, enemy)
	ParticleManager:ReleaseParticleIndex(pfx)
end
