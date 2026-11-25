-- Hola: Stunhammer. Порт из Angel Arena Frontier (abilities/hero/hola), цифры Angel Arena Global.
-- Молот летит в цель, оглушает и бьёт всех в радиусе. Талант: молот отскакивает на дальнюю цель рядом.

hola_stunhammer = class({})

function hola_stunhammer:Precache(context)
	PrecacheResource("particle", "particles/units/heroes/hero_sven/sven_spell_storm_bolt.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_sven/sven_storm_bolt_projectile_explosion.vpcf", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_sven.vsndevts", context)
end

function hola_stunhammer:GetAOERadius()
	return self:GetSpecialValueFor("bolt_aoe")
end

function hola_stunhammer:OnSpellStart()
	local caster = self:GetCaster()
	local target = self:GetCursorTarget()

	self:LaunchStunHammer(caster, target, self:GetSpecialValueFor("bounce_count"))
end

function hola_stunhammer:LaunchStunHammer(source, target, bounces)
	source:EmitSound("Hero_Sven.StormBolt")

	ProjectileManager:CreateTrackingProjectile({
		EffectName			= "particles/units/heroes/hero_sven/sven_spell_storm_bolt.vpcf",
		Ability				= self,
		iMoveSpeed			= self:GetSpecialValueFor("bolt_speed"),
		Source				= source,
		Target				= target,
		bDodgeable			= true,
		bProvidesVision		= true,
		iVisionRadius		= 225,
		iVisionTeamNumber	= self:GetCaster():GetTeamNumber(),
		iSourceAttachment	= DOTA_PROJECTILE_ATTACHMENT_ATTACK_2,
		ExtraData			= { bounces_left = bounces },
	})
end

function hola_stunhammer:OnProjectileHit_ExtraData(target, location, extra_data)
	if not target or target:IsNull() then return end

	local caster = self:GetCaster()
	local is_first = extra_data.bounces_left == self:GetSpecialValueFor("bounce_count")

	-- Linken/отражение срабатывают только на первую цель, отскоки идут от неё
	if is_first and (target:TriggerSpellAbsorb(self) or target:TriggerSpellReflect(self)) then return end
	if target:IsMagicImmune() or target:IsInvulnerable() then return end

	target:EmitSound("Hero_Sven.StormBoltImpact")

	local bolt_aoe = self:GetSpecialValueFor("bolt_aoe")
	local stun_duration = self:GetSpecialValueFor("bolt_stun_duration")

	local damage_info = {
		attacker	= caster,
		damage		= self:GetSpecialValueFor("bolt_damage") + caster:GetStrength() * self:GetSpecialValueFor("damage_pct") / 100,
		damage_type	= self:GetAbilityDamageType(),
		ability		= self,
	}

	local enemies = FindUnitsInRadius(caster:GetTeamNumber(), target:GetAbsOrigin(), nil, bolt_aoe,
		DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)

	local dealt = 0
	for _, enemy in pairs(enemies) do
		damage_info.victim = enemy
		dealt = dealt + ApplyDamage(damage_info)
		enemy:AddNewModifier(caster, self, "modifier_stunned", { duration = stun_duration })
	end

	-- шард: союзники в зоне удара лечатся на часть нанесённого урона
	local heal_pct = self:GetSpecialValueFor("shard_heal_pct")
	if heal_pct > 0 and dealt > 0 then
		local allies = FindUnitsInRadius(caster:GetTeamNumber(), target:GetAbsOrigin(), nil, bolt_aoe,
			DOTA_UNIT_TARGET_TEAM_FRIENDLY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)
		local heal = dealt * heal_pct / 100
		for _, ally in pairs(allies) do
			ally:Heal(heal, self)
			SendOverheadEventMessage(nil, OVERHEAD_ALERT_HEAL, ally, heal, nil)
		end
	end

	local pfx = ParticleManager:CreateParticle("particles/units/heroes/hero_sven/sven_storm_bolt_projectile_explosion.vpcf", PATTACH_ABSORIGIN, target)
	ParticleManager:SetParticleControl(pfx, 3, target:GetAbsOrigin())
	ParticleManager:ReleaseParticleIndex(pfx)

	local bounces_left = extra_data.bounces_left or 0
	if bounces_left <= 0 then return end

	local candidates = FindUnitsInRadius(caster:GetTeamNumber(), target:GetAbsOrigin(), nil, self:GetSpecialValueFor("bounce_radius"),
		DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC, DOTA_UNIT_TARGET_FLAG_NO_INVIS, FIND_FARTHEST, false)

	for _, new_target in pairs(candidates) do
		if new_target ~= target then
			self:LaunchStunHammer(target, new_target, bounces_left - 1)
			break
		end
	end
end
