shadowsong_magic_fire = class({})

-- Сгенерировано: ресурсы, на которые ссылается этот скрипт.
-- Движок зовёт этот метод при прекеше юнита со способностью, поэтому
-- партиклы приезжают вместе с героем (пик/репик), а не на старте карты.
function shadowsong_magic_fire:Precache(context)
	PrecacheResource("particle", "particles/econ/items/abaddon/abaddon_alliance/abaddon_death_coil_alliance.vpcf", context)
	PrecacheResource("particle", "particles/econ/items/antimage/antimage_weapon_basher_ti5/antimage_manavoid_explode_b_basher_cast.vpcf", context)
	PrecacheResource("particle", "particles/econ/items/antimage/antimage_weapon_basher_ti5_gold/antimage_manavoid_ti_5_gold.vpcf", context)
end


local ability 		= shadowsong_magic_fire
local talentNameAOE	= "shadowsong_talent_magic_fire_aoe"
local talentNameCD  = "shadowsong_talent_magic_fire_cd_decrease"
local modifierName 	= "modifier_shadowsond_magic_fire_debuff"

LinkLuaModifier( modifierName, "heroes/shadowsong/modifiers/modifier_shadowsond_magic_fire_debuff", LUA_MODIFIER_MOTION_NONE )

function ability:GetCooldown(iLevel)
	return self.BaseClass.GetCooldown(self, iLevel) - self:GetCaster():GetTalentSpecialValueFor(talentNameCD)
end

function ability:GetBehavior()
	local caster = self:GetCaster()

	if caster and caster:GetTalentSpecialValueFor(talentNameAOE) ~= 0 then
		return DOTA_ABILITY_BEHAVIOR_NO_TARGET
	else
		return DOTA_ABILITY_BEHAVIOR_UNIT_TARGET
	end
end

function ability:IsHiddenWhenStolen() return false end

function ability:OnProjectileHit(target, targetPos)
	if not IsServer() then return end
	if not target then return end
	if not target:IsAlive() then return end
	if target:IsMagicImmune() then return end

	local caster = self:GetCaster()

	local duration = self:GetSpecialValueFor("debuff_duration")
	local mod = target:AddNewModifier(caster, self, modifierName, { duration = duration })

	mod:IncrementStackCount()

	local stackCount = mod:GetStackCount()

	local burnAmmount = (self:GetSpecialValueFor("manaburn") + target:GetMaxMana() * self:GetSpecialValueFor("manaburn_pct") / 100) * stackCount

	target:Script_ReduceMana(burnAmmount,self)

	SendOverheadEventMessage(caster, OVERHEAD_ALERT_MANA_LOSS, target, burnAmmount, nil)

	-- Врождёнка: Эхо теней - лечение за сожжённую ману
	local shadowEchoAbility = caster:FindAbilityByName("shadowsong_shadow_echo")
	if shadowEchoAbility then
		local healPerMana = shadowEchoAbility:GetSpecialValueFor("heal_per_mana")
		local healAmount = burnAmmount * healPerMana / 100
		if healAmount > 0 then
			caster:Heal(healAmount, caster)
			SendOverheadEventMessage(caster, OVERHEAD_ALERT_HEAL, caster, healAmount, nil)
		end
	end

	ApplyDamage({
		victim 		= target,
		attacker 	= caster,
		damage 		= burnAmmount + caster:GetAgility() * self:GetSpecialValueFor("damage_pct") / 100,
		damage_type = self:GetAbilityDamageType(),
		ability 	= self,
	})

	target:EmitSound("Hero_Antimage.ManaVoid")

	ParticleManager:ReleaseParticleIndex(ParticleManager:CreateParticle("particles/econ/items/antimage/antimage_weapon_basher_ti5/antimage_manavoid_explode_b_basher_cast.vpcf", PATTACH_ABSORIGIN_FOLLOW, target))
end

function ability:LaunchProjectile( caster, target, speed )
	local projectileInfo = {
		Source 				= caster,
		Target 				= target,
		Ability 			= self,
		EffectName 			= "particles/econ/items/abaddon/abaddon_alliance/abaddon_death_coil_alliance.vpcf",
		bDodgeable 			= true,
		bProvidesVision 	= false,
		iMoveSpeed 			= speed,
		iSourceAttachment 	= DOTA_PROJECTILE_ATTACHMENT_ATTACK_1
	}

	ProjectileManager:CreateTrackingProjectile( projectileInfo )
end

function ability:OnSpellStart( ... )
	if not IsServer() then return end

	local caster = self:GetCaster()

	local isAOE = caster:GetTalentSpecialValueFor(talentNameAOE) ~= 0

	local speed = self:GetSpecialValueFor("projectile_speed")

	if not isAOE then
		local target = self:GetCursorTarget()

		target:TriggerSpellReflect(self)

		if target:TriggerSpellAbsorb(self) then
			return
		end

		self:LaunchProjectile(caster, target, speed)
	else
		local casterPos = caster:GetAbsOrigin()

		local units = FindUnitsInRadius( caster:GetTeamNumber(),
										 casterPos,
										 caster,
										 self:GetCastRange(casterPos, nil) + caster:GetCastRangeBonus(),
										 self:GetAbilityTargetTeam(),
										 self:GetAbilityTargetType(),
										 self:GetAbilityTargetFlags(),
										 FIND_ANY_ORDER,
										 false )

		for _, target in pairs(units) do
			self:LaunchProjectile(caster, target, speed)
		end

		ParticleManager:ReleaseParticleIndex(ParticleManager:CreateParticle("particles/econ/items/antimage/antimage_weapon_basher_ti5_gold/antimage_manavoid_ti_5_gold.vpcf", PATTACH_ABSORIGIN_FOLLOW, caster))
	end

	caster:EmitSound("Hero_Antimage.ManaBreak")
end
