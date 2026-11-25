-- Hola: Holy Rage. Порт из Angel Arena Frontier, цифры Angel Arena Global.
-- Бьёт врагов вокруг и лечит союзников (база + % интеллекта). Талант: Холу лечит на весь нанесённый урон.

require("heroes/hola/hola_divine_retribution")

hola_stomp = class({})

function hola_stomp:Precache(context)
	PrecacheResource("particle", "particles/econ/items/centaur/centaur_ti6/centaur_ti6_warstomp.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_earthshaker/earthshaker_echoslam_start_c.vpcf", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_earthshaker.vsndevts", context)
end

function hola_stomp:GetAOERadius()
	return self:GetSpecialValueFor("radius")
end

function hola_stomp:OnSpellStart()
	local caster = self:GetCaster()
	local origin = caster:GetAbsOrigin()
	local radius = self:GetSpecialValueFor("radius")

	local heal_amount = self:GetSpecialValueFor("heal") + caster:GetStrength() * self:GetSpecialValueFor("heal_percent") / 100

	local allies = FindUnitsInRadius(caster:GetTeamNumber(), origin, nil, radius,
		DOTA_UNIT_TARGET_TEAM_FRIENDLY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)

	for _, ally in pairs(allies) do
		ally:Heal(heal_amount, self)
		HolaRetribution(caster, ally, heal_amount)
		SendOverheadEventMessage(nil, OVERHEAD_ALERT_HEAL, ally, heal_amount, nil)
	end

	local enemies = FindUnitsInRadius(caster:GetTeamNumber(), origin, nil, radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)

	local damage_info = {
		attacker	= caster,
		damage		= self:GetSpecialValueFor("damage") + caster:GetStrength() * self:GetSpecialValueFor("damage_pct") / 100,
		damage_type	= self:GetAbilityDamageType(),
		ability		= self,
	}

	local heal_from_damage = self:GetSpecialValueFor("heal_from_damage") > 0
	local dealt_total = 0

	for _, enemy in pairs(enemies) do
		damage_info.victim = enemy
		dealt_total = dealt_total + ApplyDamage(damage_info)
	end

	if heal_from_damage and dealt_total > 0 then
		caster:Heal(dealt_total, self)
		SendOverheadEventMessage(nil, OVERHEAD_ALERT_HEAL, caster, dealt_total, nil)
	end

	caster:EmitSound("Hero_EarthShaker.EchoSlam")

	local pfx = ParticleManager:CreateParticle("particles/econ/items/centaur/centaur_ti6/centaur_ti6_warstomp.vpcf", PATTACH_ABSORIGIN_FOLLOW, caster)
	ParticleManager:SetParticleControl(pfx, 1, Vector(radius, 1, 1))
	ParticleManager:ReleaseParticleIndex(pfx)

	pfx = ParticleManager:CreateParticle("particles/units/heroes/hero_earthshaker/earthshaker_echoslam_start_c.vpcf", PATTACH_ABSORIGIN_FOLLOW, caster)
	ParticleManager:SetParticleControl(pfx, 1, Vector(radius, 1, 1))
	ParticleManager:ReleaseParticleIndex(pfx)
end
